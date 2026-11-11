test('Brown preassembles independent recolored Green morphs and preserves neutral limbs for local readiness',function()
    local resources=fearTemplates();local base=morphBaseTemplates();local a=actor('brown-morphs')
    assert(Appearance.attach(a,'Mr. Brown',base,resources))
    local state=a.appearance;local _,count=morphMeshCount(a);assert(count==19)
    for kind,row in pairs(state.morphs)do
        assert(row.template==resources['Green'..kind] and row.model.HeroTemplate.Value=='Mr. Brown')
        assert(row.part.Color.R==160/255 and row.part.Color.G==112/255)
        assert(row.template.HeroTemplate.Value=='Mr. Green' and row.template.Morph.Color==nil)
    end
    local c=heroContext('brown-morphs',.5);c.attack=heroAttack(c.actorId,'HeroPowerPunch')
    Appearance.update(a,c);assert(state.activeMorph=='PowerFist' and state.model.RightHand.Transparency==0)
    c.now=.6;c.visualState='Reaction';c.reaction={heavy=true,grounded=true}
    Appearance.update(a,c);assert(state.activeMorph==nil and state.model.RightHand.Transparency==0)
    c.now=.7;c.visualState=nil;c.fearIntro={id='brown-intro',actorId=c.actorId,counter=1,frameId=0x32}
    Appearance.update(a,c);assert(state.activeMorph=='FearBeforeCut' and state.model.Head.Transparency==0)
    c.now=.8;c.visualState='Dead';Appearance.update(a,c)
    assert(state.activeMorph==nil and state.model.Head.Transparency==0)
    local _,after=morphMeshCount(a);assert(after==count and a.humanoid.Health==100 and a.model.Torso.CanCollide)
end)

test('dedicated Brown resources retain their authored atlas and material while P1 remains available',function()
    local base=morphBaseTemplates();local native=base.CanonicalPlayer1:Clone()
    native.Name='CanonicalPlayerBrown';native.Parent=base
    native.Head.Color=colors.fromRGB(180,130,90);native.Head.SurfaceAppearance.Color=colors.fromRGB(255,255,255)
    native.Head.SurfaceAppearance._props.ColorMapContent=fixtureContent('dedicated-brown-atlas')
    local resources=fearTemplates();local fist=resources.GreenPowerFist:Clone()
    fist.Name='BrownPowerFist';fist.HeroTemplate.Value='Mr. Brown';fist.Parent=resources
    fist.Morph.Color=colors.fromRGB(180,130,90);fist.Morph.SurfaceAppearance.Color=colors.fromRGB(255,255,255)
    fist.Morph.SurfaceAppearance._props.ColorMapContent=fixtureContent('dedicated-brown-fist-atlas')
    local a=actor('brown-native');assert(Appearance.attach(a,'Mr. Brown',base,resources))
    assert(a.appearance.sourceTemplate==native and a.appearance.model.Head.SurfaceAppearance.ColorMapContent.Uri=='dedicated-brown-atlas')
    assert(a.appearance.model.Head.Color.R==180/255,'A native palette must not receive the fallback tint')
    local row=a.appearance.morphs.PowerFist
    assert(row.template==fist and row.part.SurfaceAppearance.ColorMapContent.Uri=='dedicated-brown-fist-atlas')
    assert(row.part.Color.R==180/255 and row.part.SurfaceAppearance.Color.R==1)
    assert(base.CanonicalPlayer1.Head.Color==nil and resources.GreenPowerFist.HeroTemplate.Value=='Mr. Green')
end)

test('invalid dedicated Brown cannot replace an existing hero or silently substitute another resource',function()
    local base=morphBaseTemplates();local native=base.CanonicalPlayer1:Clone()
    native.Name='CanonicalPlayerBrown';native.Parent=base;native.LeftHand.LeftWristRigAttachment:Destroy()
    local a=actor('brown-invalid');assert(Appearance.attach(a,'Mr. Green',base,fearTemplates()))
    local previous=a.appearance;assert(not Appearance.attach(a,'Mr. Brown',base,fearTemplates()))
    assert(a.appearance==previous and not previous.model.destroyed and a.model:GetAttribute('Template')=='Mr. Green')
end)
print('Brown appearance contracts: 3 passed')
