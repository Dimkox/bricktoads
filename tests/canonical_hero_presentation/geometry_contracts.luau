-- Real imported rest rotations; geometry changes affect only cosmetic meshes.
env.Vector3={new=vector}
local function geometrySnapshot(a)
    local rows={}
    for _,p in ipairs(a.appearance.model:GetChildren())do if p:IsA('MeshPart')then
        local row={part=p,size=p.Size,attachments={}};rows[p.Name]=row
        for _,child in ipairs(p:GetChildren())do if child:IsA('Attachment')then row.attachments[child]=child.CFrame end end
    end end
    return rows
end
local function sameGeometry(rows)
    for _,row in pairs(rows)do
        assert(row.part.Size==row.size,'Saved cosmetic Size must be restored exactly')
        for attachment,original in pairs(row.attachments)do sameFrame(attachment.CFrame,original)end
    end
end
test('folded source1F visibly compresses and thickens its retracted leg then restores before the boot morph',function()
    local a=fearActor('folded-body');local original=geometrySnapshot(a);local physical={}
    for name,row in pairs(a.poseMotors)do physical[name]=row.joint.C0 end
    local c=heroContext('folded-body');c.attack=heroAttack(c.actorId,'HeroBoot')
    Appearance.update(a,c);local state=a.appearance
    assert(state.sourcePose.frameId==0x1F and state.activeMorph==nil)
    assert(state.model.RightUpperLeg.Size.Y<original.RightUpperLeg.size.Y)
    assert(state.model.RightUpperLeg.Size.X>original.RightUpperLeg.size.X)
    assert(state.model.UpperTorso.Size.Y<original.UpperTorso.size.Y)
    local current=state.model.RightUpperLeg.Size;local knee=state.joints.RightKnee.motor.C1
    for _=1,30 do Appearance.update(a,c)end
    assert(state.model.RightUpperLeg.Size.Y==current.Y and state.model.RightUpperLeg.Size.X==current.X)
    sameFrame(state.joints.RightKnee.motor.C1,knee)
    c.now=.5;Appearance.update(a,c);assert(state.sourcePose.frameId==0x1E and state.activeMorph=='BigBoot')
    sameGeometry(original)
    for name,row in pairs(a.poseMotors)do assert(row.joint.C0==physical[name],'Physical '..name..' changed')end
    assert(a.humanoid.Health==100 and a.model.Torso.CanCollide and not a.root.Anchored)
end)
test('both fear frames reshape torso and limbs while wide-mouth heads keep their exact dimensions',function()
    for _,hero in ipairs({'Mr. Green','Mr. Yellow','Mr. Brown'})do
        local a=fearActor('fear-body-'..hero,hero);local original=geometrySnapshot(a)
        local heads={};for _,kind in ipairs({'FearBeforeCut','FearAfterCut'})do heads[kind]=a.appearance.morphs[kind].part.Size end
        local c=fearContext('fear-body-'..hero,1);Appearance.update(a,c)
        local state=a.appearance;assert(state.model.UpperTorso.Size.X<original.UpperTorso.size.X)
        assert(state.model.LeftLowerArm.Size.Y>original.LeftLowerArm.size.Y)
        local width=state.model.UpperTorso.Size.X
        c=fearContext('fear-body-'..hero,0xE1);Appearance.update(a,c)
        assert(state.model.UpperTorso.Size.X<width and state.model.RightLowerLeg.Size.Y>original.RightLowerLeg.size.Y)
        for kind,size in pairs(heads)do assert(state.morphs[kind].part.Size==size,'Wide-mouth mesh was scaled')end
        Appearance.update(a,nil);sameGeometry(original)
        assert(state.activeMorph==nil and state.model.Head.Transparency==0)
    end
end)
test('every interruption and rewind clears body geometry without resurrecting the old windup',function()
    for _,reason in ipairs({'Reaction','Dead','Air','Carried','DragonMounted','Disabled','Rewind','MissingContext'})do
        local a=fearActor('body-cancel-'..reason);local original=geometrySnapshot(a)
        local c=heroContext('body-cancel-'..reason,.1);c.attack=heroAttack(c.actorId,'HeroBoot');local oldAttack=c.attack
        Appearance.update(a,c);assert(a.appearance.model.RightUpperLeg.Size.Y<original.RightUpperLeg.size.Y)
        if reason=='Disabled'then c.enabled=false
        elseif reason=='Rewind'then c.now=0
        elseif reason=='MissingContext'then c=nil
        else c.visualState=reason;c.verticalSpeed=0;c.reaction={heavy=true,grounded=true}end
        Appearance.update(a,c);sameGeometry(original)
        if not c then c=heroContext('body-cancel-'..reason,.2);c.attack=oldAttack end
        c.now=.2;c.enabled=true;c.visualState=nil;Appearance.update(a,c)
        assert(a.appearance.sourcePose.kind=='Idle','Old accepted windup resumed after interruption')
    end
end)
test('detach and actor replacement restore captured sizes attachments and cosmetic motor rest frames',function()
    for _,replace in ipairs({false,true})do
        local a=fearActor('body-detach');local original=geometrySnapshot(a);local state=a.appearance
        local motors={};for name,row in pairs(state.joints)do
            motors[row.motor]={c0=row.motor.Part0[name..'RigAttachment'].CFrame,c1=row.motor.Part1[name..'RigAttachment'].CFrame}
        end
        Appearance.update(a,fearContext('body-detach',0xE1))
        if replace then local newer=actor('body-new');a.model=newer.model;Appearance.update(a,nil);assert(newer.model.Torso.Transparency==0)
        else Appearance.detach(a)end
        assert(not a.appearance);sameGeometry(original)
        for motor,saved in pairs(motors)do sameFrame(motor.C0,saved.c0);sameFrame(motor.C1,saved.c1)end
    end
end)
test('nonfinite zero negative and unknown geometry profiles fail atomically and restore the prior form',function()
    local sampler=CanonicalPresentation.sample
    for _,invalid in ipairs({'NaN','Zero','Negative','Unknown','Offset'})do
        local a=fearActor('body-invalid-'..invalid);local original=geometrySnapshot(a)
        local c=heroContext('body-invalid-'..invalid);c.attack=heroAttack(c.actorId,'HeroBoot')
        Appearance.update(a,c)
        CanonicalPresentation.sample=function(...)
            local row=sampler(...);row.geometry={parts={RightUpperLeg={1,1,1}}}
            if invalid=='Unknown'then row.geometry.parts.MissingPart={1,1,1}
            elseif invalid=='Offset'then row.geometry.offsets={RightKnee={0/0,0,0}}
            else row.geometry.parts.RightUpperLeg[2]=invalid=='NaN'and 0/0 or invalid=='Zero'and 0 or -1 end
            return row
        end
        Appearance.update(a,c);CanonicalPresentation.sample=sampler
        sameGeometry(original);assert(a.appearance.sourcePose==nil and a.appearance.sourceFallback=='InvalidGeometry')
        c.now=.1;Appearance.update(a,c);assert(a.appearance.sourcePose.kind=='Idle')
    end
end)
print('Hero source-silhouette geometry: 5 passed')
