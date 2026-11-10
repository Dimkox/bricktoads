local function fearTemplates()
    local folder=morphTemplates()
    for _,hero in ipairs({'Mr. Green','Mr. Yellow'})do
        local prefix=hero=='Mr. Green'and'Green'or'PlayerTwo'
        for _,kind in ipairs({'FearBeforeCut','FearAfterCut'})do
            local model=node('Model',prefix..kind,folder)
            for name,value in pairs({AppearanceProfile='CanonicalNESHeroMorph',MorphKind=kind,HeroTemplate=hero})do
                local t=node('StringValue',name,model);t.Value=value
            end
            local scale=node('NumberValue','AppearanceScale',model);scale.Value=1
            local p=node('MeshPart','Morph',model);p._props.MeshId='rbxassetid://333'
            p.Size=vector(2,3,1.5);p.Transparency=0
            p.CFrame=matrixCF.new(.1,1,-.2)*matrixCF.Angles(0,math.pi,0)
            local origin=node('Attachment','MorphOriginRigAttachment',p);origin.CFrame=p.CFrame:Inverse()
        end
    end
    return folder
end
local function fearActor(id,hero)
    return morphActor(id,hero,fearTemplates())
end
local function fearContext(id,counter)
    local c=heroContext(id,counter/60)
    c.fearIntro={id='run:intro',actorId=id,counter=counter,frameId=counter<=0xE0 and 0x32 or 0x33}
    return c
end
test('fear heads are preassembled at the native neck without new physical parts during playback',function()
    local a=fearActor('fear-preload');local _,count=morphMeshCount(a);assert(count==19)
    for _,kind in ipairs({'FearBeforeCut','FearAfterCut'})do
        local r=assert(a.appearance.morphs[kind]);assert(r.originalPart==a.appearance.model.Head)
        sameFrame(r.joint.C0,r.originalPart.NeckRigAttachment.CFrame*r.template.Morph.CFrame)
        assert(r.part.Transparency==1 and r.part.Massless and not r.part.CanCollide and not r.part.CanQuery)
    end
    Appearance.update(a,fearContext('fear-preload',1))
    local _,after=morphMeshCount(a);assert(after==count and a.appearance.activeMorph=='FearBeforeCut')
end)
test('switching both fear forms on one head restores exactly once regardless of table iteration order',function()
    local a=fearActor('fear-shared-head');local head=a.appearance.model.Head;head.Transparency=.41
    for _,counter in ipairs({1,0xE1,1,0xE1})do
        -- A fresh finite intro identity lets both transition directions be tested.
        local c=fearContext('fear-shared-head',counter);c.now=10+counter/1000
        a.appearance.presentation=nil
        Appearance.update(a,c)
        local expected=counter==1 and'FearBeforeCut'or'FearAfterCut'
        assert(a.appearance.activeMorph==expected and head.Transparency==1,'The active head must hide its original')
        for _,kind in ipairs({'FearBeforeCut','FearAfterCut'})do
            assert(a.appearance.morphs[kind].part.Transparency==(kind==expected and 0 or 1))
        end
    end
    Appearance.update(a,nil);assert(head.Transparency==.41,'Do not cache an already hidden head as the original value')
end)
test('fear cancels attack morphology and interruptions restore only that actor',function()
    local a,b=fearActor('fear-a'),fearActor('fear-b','Mr. Yellow')
    local c=heroContext('fear-a',.5);c.attack=heroAttack('fear-a','HeroPowerPunch');Appearance.update(a,c)
    assert(a.appearance.activeMorph=='PowerFist')
    c=fearContext('fear-a',0x30);c.now=1;Appearance.update(a,c)
    assert(a.appearance.activeMorph=='FearBeforeCut' and a.appearance.model.RightHand.Transparency==0)
    Appearance.update(b,fearContext('fear-b',0xE1));assert(b.appearance.activeMorph=='FearAfterCut')
    c.blocked='Reaction';c.now=2;Appearance.update(a,c)
    assert(a.appearance.activeMorph==nil and a.appearance.model.Head.Transparency==0)
    assert(b.appearance.activeMorph=='FearAfterCut' and b.appearance.model.Head.Transparency==1)
    Appearance.detach(b);assert(b.appearance==nil and a.humanoid.Health==100)
end)
test('missing or detached fear resources leave the original head visible',function()
    local resources=fearTemplates();resources.GreenFearBeforeCut:Destroy()
    local a=morphActor('fear-missing','Mr. Green',resources)
    Appearance.update(a,fearContext('fear-missing',1));assert(a.appearance.activeMorph==nil)
    assert(a.appearance.model.Head.Transparency==0)
    local b=fearActor('fear-removed');Appearance.update(b,fearContext('fear-removed',1))
    b.appearance.morphs.FearBeforeCut.part:Destroy()
    Appearance.update(b,fearContext('fear-removed',2))
    assert(b.appearance.model.Head.Transparency==0 and b.appearance.activeMorph==nil)
end)
print('Fear appearance contracts: 4 passed')
