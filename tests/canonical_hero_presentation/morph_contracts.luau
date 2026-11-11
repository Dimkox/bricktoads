-- Optional morph resources are preassembled cosmetic geometry. These tests use
-- real rigid transforms for imported rest frames, not an additive Euler mock.
local function morphBaseTemplates()
    local folder=importedTemplates()
    for _,row in ipairs(RotatedRestManifest.parts)do
        local part=folder.CanonicalPlayer2[row.name]
        part.CFrame=matrixCF.new(table.unpack(row.cframe));part.Size=vector(table.unpack(row.size))
        for _,attachment in ipairs(row.attachments)do part[attachment.name].CFrame=matrixCF.new(table.unpack(attachment.cframe))end
    end
    return folder
end
local function morphTemplates()
    local folder=node('Folder','BrickToadsCharacterMorphs')
    for _,hero in ipairs({'Mr. Green','Mr. Yellow'})do
        local prefix=hero=='Mr. Green'and'Green'or'PlayerTwo'
        for _,kind in ipairs({'PowerFist','BigBoot'})do
            local model=node('Model',prefix..kind,folder)
            for name,value in pairs({AppearanceProfile='CanonicalNESHeroMorph',MorphKind=kind,HeroTemplate=hero})do
                local tag=node('StringValue',name,model);tag.Value=value
            end
            local scale=node('NumberValue','AppearanceScale',model);scale.Value=1
            local part=node('MeshPart','Morph',model);part._props.MeshId='rbxassetid://'..(hero=='Mr. Green'and'101'or'202')..(kind=='PowerFist'and'1'or'2')
            part.Size=vector(1.5,2,1.2);part.Transparency=kind=='PowerFist'and.17 or.27
            part.CFrame=matrixCF.new(.15,-.8,-.3)*matrixCF.Angles(.2,math.pi,-.1)
            part.Anchored=true;part.CanCollide=true;part.CanTouch=true;part.CanQuery=true;part.Massless=false
            local origin=node('Attachment','MorphOriginRigAttachment',part);origin.CFrame=part.CFrame:Inverse()
            local surface=node('SurfaceAppearance','SurfaceAppearance',part);surface._props.ColorMapContent=fixtureContent(hero..' '..kind)
        end
    end
    return folder
end
local function morphActor(id,hero,morphs)
    local a=actor(id)
    assert(Appearance.attach(a,hero or'Mr. Green',morphBaseTemplates(),morphs or morphTemplates()))
    return a
end
local function morphMeshCount(a)
    local base,total=0,0
    for _,part in ipairs(a.appearance.model:GetChildren())do if part:IsA('MeshPart')then base+=1 end end
    for _,part in ipairs(a.appearance.model:GetDescendants())do if part:IsA('MeshPart')then total+=1 end end
    return base,total
end
test('two optional morphs are fully preassembled with local visibility metadata and inert physics',function()
    local a=morphActor('morph-preload')
    local base,total=morphMeshCount(a);assert(base==15 and total==17,'Keep15 base meshes plus2 optional preloaded morphs')
    assert(a.appearance.morphs and a.appearance.morphFolder.Parent==a.appearance.model)
    for kind,row in pairs(a.appearance.morphs)do
        assert(kind=='PowerFist'or kind=='BigBoot')
        assert(row.part.Transparency==row.visibleTransparency and not row.part.Anchored and row.part.Massless)
        assert(row.part:GetAttribute('HeroVisibleTransparency')==row.visibleTransparency)
        assert(row.part:GetAttribute('HeroExpectedSurfaceCount')==1 and type(row.part:GetAttribute('HeroExpectedSurfaceMaps'))=='string')
        assert(row.part:GetAttribute('HeroExpectedMeshId')==row.part.MeshId and row.part:GetAttribute('HeroExpectedTextureId')=='')
        assert(row.model:GetAttribute('HeroMorphKind')==kind and row.model.HeroMorphOriginal.Value==row.originalPart)
        assert(not row.part.CanCollide and not row.part.CanTouch and not row.part.CanQuery)
        assert(row.joint.Part0==row.originalPart and row.joint.Part1==row.part)
        local name=kind=='PowerFist'and'RightWristRigAttachment'or'RightAnkleRigAttachment'
        sameFrame(row.joint.C0,row.originalPart[name].CFrame*row.template.Morph.CFrame)
        sameFrame(row.joint.C1,matrixCF.new())
        assert(row.originalPart.Transparency==0)
    end
    assert(a.humanoid.Health==100 and a.model.Torso.CanCollide and not a.root.Anchored)
end)
test('P1 and P2 morphs clone only their own approved hero resource and preserve its source material',function()
    local resources=morphTemplates();local a=morphActor('morph-green','Mr. Green',resources)
    local b=morphActor('morph-yellow','Mr. Yellow',resources)
    for _,kind in ipairs({'PowerFist','BigBoot'})do
        local green,yellow=a.appearance.morphs[kind],b.appearance.morphs[kind]
        assert(green.part~=yellow.part and green.template==resources['Green'..kind]and yellow.template==resources['PlayerTwo'..kind])
        assert(green.part.MeshId~=yellow.part.MeshId and green.part.SurfaceAppearance.ColorMapContent.Uri=='Mr. Green '..kind)
        assert(yellow.part.SurfaceAppearance.ColorMapContent.Uri=='Mr. Yellow '..kind)
        assert(resources['Green'..kind].Morph.Anchored and resources['Green'..kind].Morph.Transparency~=1)
    end
end)
test('missing and independently rejected morph resources leave their original skin visible without failing attachment',function()
    local empty=morphActor('morph-empty','Mr. Green',node('Folder','NoMorphs'))
    local base,total=morphMeshCount(empty);assert(base==15 and total==15)
    for _,invalid in ipairs({'Profile','Hero','Kind','Scale','Origin','ExtraPart','EmptyMesh','UnreadableMap','Script'})do
        local resources=morphTemplates();local model=resources.GreenPowerFist
        if invalid=='Profile'then model.AppearanceProfile.Value='Unapproved'
        elseif invalid=='Hero'then model.HeroTemplate.Value='Mr. Yellow'
        elseif invalid=='Kind'then model.MorphKind.Value='BigBoot'
        elseif invalid=='Scale'then model.AppearanceScale.Value=1.2
        elseif invalid=='Origin'then model.Morph.MorphOriginRigAttachment.CFrame=matrixCF.new(3,0,0)
        elseif invalid=='ExtraPart'then node('MeshPart','SecondMorph',model)
        elseif invalid=='EmptyMesh'then model.Morph._props.MeshId=''
        elseif invalid=='UnreadableMap'then model.Morph.SurfaceAppearance._props.DeniedRead='ColorMapContent'
        elseif invalid=='Script'then node('Script','Unexpected',model.Morph)end
        local a=morphActor('morph-invalid-'..invalid,'Mr. Green',resources)
        assert(a.appearance.morphs.PowerFist==nil and a.appearance.morphs.BigBoot,'Invalid resource rejection is independent')
        assert(a.appearance.model.RightHand.Transparency==0 and a.appearance.model.RightFoot.Transparency==0)
        local _,count=morphMeshCount(a);assert(count==16,'A failed resource cannot leave partial geometry')
    end
end)
print('Morph resource preparation: 3 passed')

local function noRequestedMorphs(a)
    assert(a.appearance.activeMorph==nil and a.appearance.model:GetAttribute('HeroActiveMorph')==nil,'Inactive intent must be cleared')
    for _,row in pairs(a.appearance.morphs or{})do assert(row.part.Transparency==row.visibleTransparency,'Playback must not change server alpha')end
end
test('verified graphics frames publish exactly one morph intent without hiding nonzero neutral alpha',function()
    local a=morphActor('morph-frames');local hand,foot=a.appearance.model.RightHand,a.appearance.model.RightFoot
    hand.Transparency=.36;foot.Transparency=.47
    local c=heroContext('morph-frames');c.attack=heroAttack(c.actorId,'HeroPowerPunch')
    Appearance.update(a,c);noRequestedMorphs(a);assert(hand.Transparency==.36 and foot.Transparency==.47)
    c.now=.5;Appearance.update(a,c)
    local fist,boot=a.appearance.morphs.PowerFist,a.appearance.morphs.BigBoot
    assert(a.appearance.sourcePose.frameId==0x1C and a.appearance.activeMorph=='PowerFist'and hand.Transparency==.36)
    assert(a.appearance.model:GetAttribute('HeroActiveMorph')=='PowerFist'and boot.part.Transparency==.27 and foot.Transparency==.47)
    c.now=65/60;Appearance.update(a,c)
    assert(a.appearance.sourcePose.frameId==0x1D and hand.Transparency==.36);noRequestedMorphs(a)
    c.now=1.2;c.attack=heroAttack(c.actorId,'HeroBoot',1.2);Appearance.update(a,c)
    assert(a.appearance.sourcePose.frameId==0x1F,'The folded source windup must remain distinct');noRequestedMorphs(a)
    c.now=1.7;Appearance.update(a,c)
    assert(a.appearance.sourcePose.frameId==0x1E and a.appearance.activeMorph=='BigBoot'and foot.Transparency==.47)
    assert(a.appearance.model:GetAttribute('HeroActiveMorph')=='BigBoot'and fist.part.Transparency==.17 and hand.Transparency==.36)
    c.now=3;Appearance.update(a,c);noRequestedMorphs(a);assert(hand.Transparency==.36 and foot.Transparency==.47)
end)
test('rerender and repeated attach reuse the preassembled geometry without replacing ownership-sensitive parts',function()
    local a=actor('morph-idempotent');local base,morphs=morphBaseTemplates(),morphTemplates()
    assert(Appearance.attach(a,'Mr. Green',base,morphs));local state=a.appearance
    local fist=state.morphs.PowerFist;local original=fist.originalPart;original.Transparency=.23
    local all=a.appearance.model:GetDescendants();local count=#all
    local c=heroContext('morph-idempotent',.5);c.attack=heroAttack(c.actorId,'HeroPowerPunch')
    for _=1,6 do Appearance.update(a,c);assert(Appearance.attach(a,'Mr. Green',base,morphs))end
    assert(a.appearance==state and #state.model:GetDescendants()==count and fist.part==state.morphs.PowerFist.part)
    for _,part in ipairs(all)do assert(part:IsDescendantOf(state.model),'Playback must not remove or reparent any preassembled object')end
    assert(original.Transparency==.23 and a.appearance.model:GetAttribute('HeroActiveMorph')=='PowerFist'and fist.joint.Part0==original)
    c.now=2;Appearance.update(a,c);assert(original.Transparency==.23)
end)
test('each priority interruption restores exact skin visibility and cannot resume an old oversized limb',function()
    for _,reason in ipairs({'Dead','Reaction','Carrying','Carried','Club','Dragon','Airborne','Paused'})do
        local a=morphActor('morph-block-'..reason);local hand=a.appearance.model.RightHand;hand.Transparency=.31
        local c=heroContext('morph-block-'..reason,.5);c.attack=heroAttack(c.actorId,'HeroPowerPunch')
        Appearance.update(a,c);assert(hand.Transparency==.31 and a.appearance.activeMorph=='PowerFist')
        c.blocked=reason;c.now=.55;Appearance.update(a,c);noRequestedMorphs(a);assert(hand.Transparency==.31)
        c.blocked=nil;c.now=.6;Appearance.update(a,c);noRequestedMorphs(a);assert(hand.Transparency==.31)
    end
end)
test('new action unknown disabled missing context and air clear morphs before restoring fallback',function()
    for _,change in ipairs({'NewAction','Unknown','Disabled','MissingContext','Air'})do
        local id='morph-clear-'..change;local a=morphActor(id);local hand=a.appearance.model.RightHand;hand.Transparency=.42
        local c=heroContext(id,.5);c.attack=heroAttack(id,'HeroPowerPunch');Appearance.update(a,c);assert(hand.Transparency==.42 and a.appearance.activeMorph=='PowerFist')
        c.now=.55
        if change=='NewAction'then c.attack=heroAttack(id,'HeroJab',.55)
        elseif change=='Unknown'then c.attack=heroAttack(id,'UnverifiedAction',.55)
        elseif change=='Disabled'then c.enabled=false
        elseif change=='Air'then c.grounded=false end
        if change=='MissingContext'then Appearance.update(a)else Appearance.update(a,c)end
        noRequestedMorphs(a);assert(hand.Transparency==.42)
    end
end)
test('switching from fist to boot clears the former before the folded-leg windup and preserves independent player materials',function()
    local a,b=morphActor('morph-switch-a'),morphActor('morph-switch-b','Mr. Yellow')
    local first,second=heroContext('morph-switch-a',.5),heroContext('morph-switch-b',.5)
    first.attack=heroAttack(first.actorId,'HeroPowerPunch');second.attack=heroAttack(second.actorId,'HeroBoot')
    Appearance.update(a,first);Appearance.update(b,second)
    assert(a.appearance.activeMorph=='PowerFist'and b.appearance.activeMorph=='BigBoot')
    assert(b.appearance.morphs.BigBoot.part.SurfaceAppearance.ColorMapContent.Uri=='Mr. Yellow BigBoot')
    first.attack=heroAttack(first.actorId,'HeroBoot',.5);Appearance.update(a,first);noRequestedMorphs(a)
    assert(a.appearance.model.RightHand.Transparency==0 and b.appearance.activeMorph=='BigBoot')
    first.now=1;Appearance.update(a,first);assert(a.appearance.activeMorph=='BigBoot')
end)
test('missing or detached morph geometry never hides a normal limb and is never respawned by playback',function()
    local resources=morphTemplates();resources.GreenPowerFist.AppearanceProfile.Value='Unapproved'
    local missing=morphActor('morph-not-approved','Mr. Green',resources)
    local c=heroContext('morph-not-approved',.5);c.attack=heroAttack(c.actorId,'HeroPowerPunch');Appearance.update(missing,c)
    assert(missing.appearance.model.RightHand.Transparency==0);noRequestedMorphs(missing)
    local a=morphActor('morph-removed');local row=a.appearance.morphs.PowerFist;row.originalPart.Transparency=.52
    c=heroContext('morph-removed',.5);c.attack=heroAttack(c.actorId,'HeroPowerPunch');Appearance.update(a,c)
    row.part:Destroy();Appearance.update(a,c)
    assert(row.originalPart.Transparency==.52 and row.part.Parent==nil,'A missing optional resource must restore the original skin')
    local _,total=morphMeshCount(a);assert(total==16,'Playback cannot create replacement assembly geometry')
end)
test('detach resource swap and owner replacement restore saved originals without touching a newer body',function()
    for _,cleanup in ipairs({'Detach','Swap','OwnerReplacement'})do
        local id='morph-cleanup-'..cleanup;local a=morphActor(id);local old=a.appearance
        local original=old.model.RightHand;original.Transparency=.63
        local c=heroContext(id,.5);c.attack=heroAttack(id,'HeroPowerPunch');Appearance.update(a,c);assert(original.Transparency==.63 and old.activeMorph=='PowerFist')
        if cleanup=='Detach'then Appearance.detach(a)
        elseif cleanup=='Swap'then assert(Appearance.attach(a,'Mr. Yellow',morphBaseTemplates(),morphTemplates()));noRequestedMorphs(a)
        else
            local replacement=actor(id..'-new');replacement.model.Torso.Transparency=.71
            a.model=replacement.model;Appearance.update(a,c)
            assert(replacement.model.Torso.Transparency==.71 and replacement.humanoid.Health==100)
        end
        assert(original.Transparency==.63 and old.model.destroyed,'Cleanup must restore exact original visibility before destroying old cosmetics')
        assert(old.morphs.PowerFist.part.destroyed)
    end
end)
print('Morph source frame and lifetime: 7 passed')
