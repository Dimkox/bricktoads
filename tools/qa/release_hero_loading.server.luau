-- Prepared native loading gallery, separate from an actual campaign playthrough.
-- Install this source as SS.BrickToadsReleaseHeroLoadingQA.Fixture (ModuleScript),
-- set Fixture.ExpectedSourceSha256 to the frozen BuildInfo source hash, require().
-- Read:Invoke('summary'|'details'[, 'Green'|'Yellow'|'Brown']) returns bounded JSON.
-- SetMorph:Invoke('Green'|'Yellow'|'Brown'|'all', nil|'PowerFist'|'BigBoot'|
--   'FearBeforeCut'|'FearAfterCut') changes ONLY prepared cosmetic intent.
-- SetMap:Invoke('Green', 'Base'|<morph kind>, 'ColorMap'|'NormalMap'|
--   'RoughnessMap'|'MetalnessMap', <raw content id>|'restore', 'Head' [base only]).
-- SetTexture:Invoke('Green', 'Base'|<morph kind>, <raw content id>|'restore',
--   'Head' [base only]) edits a flat MeshPart.TextureID.
-- Both edit a PRIVATE template and reattach to publish expected-resource metadata.
-- Cleanup:Invoke() destroys only this fixture's owned gallery/resources/controls.
-- No GameWorld, Lighting, Players, camera, HP, progress, source edits or preloads.
assert(game:GetService('RunService'):IsStudio(), 'Studio fixture only')
local SS, Http = game:GetService('ServerStorage'), game:GetService('HttpService')
local owner = script.Parent
assert(owner.Name == 'BrickToadsReleaseHeroLoadingQA' and owner.Parent == SS, 'Use the owned loading QA folder')
assert(not owner:GetAttribute('ReleaseHeroLoadingOwner') and not owner:FindFirstChild('Read'), 'Use a fresh QA folder')
assert(not workspace:FindFirstChild('BrickToadsReleaseHeroLoadingGallery'), 'Prior loading gallery must be cleaned up')
local expected = script:GetAttribute('ExpectedSourceSha256')
assert(type(expected) == 'string' and #expected == 64 and expected:match('^[0-9a-f]+$'), 'ExpectedSourceSha256 required')
local production = assert(game:GetService('ServerScriptService'):FindFirstChild('BrickToads'))
local observed = require(assert(production:FindFirstChild('BuildInfo'))).sourceSha256
assert(observed == expected, 'Fixture source differs from expected frozen source')
-- Reuse the actual factory, including its attachment identity serial and actual
-- dependency modules. Only the resource arguments and actors below are private.
local Appearance = require(assert(production.gameplay:FindFirstChild('CharacterAppearance')))
local characterSources = assert(SS:FindFirstChild('BrickToadsCharacterTemplates'))
local morphSources = assert(SS:FindFirstChild('BrickToadsCharacterMorphs'))
local token = Http:GenerateGUID(false)
owner:SetAttribute('ReleaseHeroLoadingOwner', token)
local resources = Instance.new('Folder'); resources.Name = 'Resources'; resources.Parent = owner
local gallery = Instance.new('Model'); gallery.Name = 'BrickToadsReleaseHeroLoadingGallery'
gallery:SetAttribute('ReleaseHeroLoadingOwner', token)
gallery:SetAttribute('PreparedLoadingFixture', true)
gallery.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
gallery.Parent = workspace
local MAPS = {'ColorMap', 'NormalMap', 'RoughnessMap', 'MetalnessMap'}
local MORPHS = {'PowerFist', 'BigBoot', 'FearBeforeCut', 'FearAfterCut'}
local morphSet, mapSet = {}, {}
for _, kind in ipairs(MORPHS) do morphSet[kind] = true end
for _, property in ipairs(MAPS) do mapSet[property] = true end
local rows, errors, operations = {}, {}, {}
local cleaned = false
local function smallError(problem) return string.sub(tostring(problem), 1, 1000) end
local function encode(value)
    local data = Http:JSONEncode(value)
    assert(#data <= 100000, 'QA response exceeds 100000-byte bound')
    return data
end
local function xyz(value) return {value.X, value.Y, value.Z} end
local function physicalSnapshot(actor)
    local out = {health = actor.humanoid.Health, maxHealth = actor.humanoid.MaxHealth,
        stateMachineEnabled = actor.humanoid.EvaluateStateMachine, parts = {}, motors = {}}
    for _, p in ipairs(actor.model:GetChildren()) do if p:IsA('BasePart') then
        out.parts[p] = {name=p.Name, size=p.Size, frame=p.CFrame, transparency=p.Transparency,
            collide=p.CanCollide, touch=p.CanTouch, query=p.CanQuery, anchored=p.Anchored,
            massless=p.Massless, rootPriority=p.RootPriority}
    end end
    for _, j in ipairs(actor.model:GetDescendants()) do if j:IsA('Motor6D') then
        out.motors[j] = {parent=j.Parent, part0=j.Part0, part1=j.Part1, c0=j.C0, c1=j.C1}
    end end
    return out
end
local function physicalRead(row, details)
    local actor, original = row.actor, row.physical
    local out = {preserved=true, health=actor.humanoid.Health, maxHealth=actor.humanoid.MaxHealth,
        stateMachineEnabled=actor.humanoid.EvaluateStateMachine,
        expectedHealth=original.health, expectedMaxHealth=original.maxHealth, partCount=0,
        motorCount=0, maxPositionDrift=0, maxAngleDrift=0, issues={}}
    if details then out.parts = {} end
    local function issue(message) out.preserved=false; out.issues[#out.issues+1]=message end
    if out.health ~= original.health or out.maxHealth ~= original.maxHealth then issue('Prepared HP changed') end
    if out.stateMachineEnabled ~= original.stateMachineEnabled then issue('Prepared Humanoid state machine changed') end
    local current = 0
    for _, p in ipairs(actor.model:GetChildren()) do if p:IsA('BasePart') then current+=1 end end
    for p, before in pairs(original.parts) do
        out.partCount+=1
        local live = p.Parent == actor.model
        if not live then issue('Physical identity/parent changed: '..before.name)
        else
            local delta = before.frame:ToObjectSpace(p.CFrame)
            local _, angle = delta:ToAxisAngle()
            out.maxPositionDrift=math.max(out.maxPositionDrift, delta.Position.Magnitude)
            out.maxAngleDrift=math.max(out.maxAngleDrift, math.abs(angle))
            if p.Size~=before.size or p.Transparency~=before.transparency or p.CanCollide~=before.collide
                or p.CanTouch~=before.touch or p.CanQuery~=before.query or p.Anchored~=before.anchored
                or p.Massless~=before.massless or p.RootPriority~=before.rootPriority then
                issue('Physical size/flags/source alpha changed: '..before.name)
            end
            if delta.Position.Magnitude>.02 or math.abs(angle)>.002 then issue('Physical frame changed: '..before.name) end
            if details then out.parts[#out.parts+1]={name=p.Name, identityPreserved=true,
                position=xyz(p.Position), originalPosition=xyz(before.frame.Position), transparency=p.Transparency,
                originalTransparency=before.transparency, anchored=p.Anchored, collide=p.CanCollide,
                touch=p.CanTouch, query=p.CanQuery, massless=p.Massless} end
        end
    end
    if current~=out.partCount then issue('Physical direct-part inventory changed') end
    for j, before in pairs(original.motors) do
        out.motorCount+=1
        if j.Parent~=before.parent or j.Part0~=before.part0 or j.Part1~=before.part1
            or j.C0~=before.c0 or j.C1~=before.c1 then issue('Physical motor changed: '..j.Name) end
    end
    if out.parts then table.sort(out.parts, function(a,b) return a.name<b.name end) end
    return out
end
local function part(parent, name, size, frame, collide)
    local p=Instance.new('Part'); p.Name=name; p.Size=size; p.CFrame=frame
    p.Anchored=false; p.CanCollide=collide==true; p.CanTouch=false; p.CanQuery=false; p.Parent=parent
    return p
end
local function actor(index, palette)
    local model=Instance.new('Model'); model.Name=palette
    model:SetAttribute('ActorId', 'prepared-loading:'..palette)
    model:SetAttribute('PreparedLoadingFixture', true)
    local root=part(model, 'HumanoidRootPart', Vector3.new(2,2,1), CFrame.new(18000+(index-1)*12,8,0), false)
    root.Anchored=true; root.Transparency=1
    local torso=part(model, 'Torso', Vector3.new(2,2,1), root.CFrame, true)
    local rootJoint=Instance.new('Motor6D'); rootJoint.Name='RootJoint'; rootJoint.Part0=root; rootJoint.Part1=torso; rootJoint.Parent=root
    for _, d in ipairs({{'Head',Vector3.new(2,1,1),'Neck',Vector3.new(0,1,0),Vector3.new(0,-.5,0)},
        {'Left Arm',Vector3.new(1,2,1),'Left Shoulder',Vector3.new(-1.5,0,0),Vector3.new(0,.5,0)},
        {'Right Arm',Vector3.new(1,2,1),'Right Shoulder',Vector3.new(1.5,0,0),Vector3.new(0,.5,0)},
        {'Left Leg',Vector3.new(1,2,1),'Left Hip',Vector3.new(-.5,-1,0),Vector3.new(0,1,0)},
        {'Right Leg',Vector3.new(1,2,1),'Right Hip',Vector3.new(.5,-1,0),Vector3.new(0,1,0)}}) do
        local c0,c1=CFrame.new(d[4]),CFrame.new(d[5])
        local limb=part(model,d[1],d[2],torso.CFrame*c0*c1:Inverse(),d[1]=='Head')
        local joint=Instance.new('Motor6D'); joint.Name=d[3]; joint.Part0=torso; joint.Part1=limb
        joint.C0=c0; joint.C1=c1; joint.Parent=torso
    end
    local humanoid=Instance.new('Humanoid'); humanoid.BreakJointsOnDeath=false; humanoid.HipHeight=0
    -- The Humanoid state machine can change limb collision flags on startup.
    -- This prepared, anchored rig measures only the cosmetic factory's effects.
    humanoid.EvaluateStateMachine=false
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None; humanoid.Parent=model
    model.PrimaryPart=root; model.Parent=gallery
    return {model=model, root=root, humanoid=humanoid}
end
local function mapContent(surface, property)
    return surface[property..'Content']
end
local function contentUri(content)
    local ok,uri=pcall(function()return content.Uri end)
    return ok and type(uri)=='string' and uri or ''
end
local function rememberSourceResources(container, row)
    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA('SurfaceAppearance') then
            local values={}
            for _, property in ipairs(MAPS) do values[property]=mapContent(descendant,property) end
            row.originalMaps[descendant]=values
        elseif descendant:IsA('MeshPart') then
            row.originalTextures[descendant]=descendant.TextureID
        end
    end
end
local function attachmentRead(row, details)
    local state=row.actor.appearance
    if not state then return {attached=false} end
    local out={attached=true, skin=state.model:GetFullName(), skinId=state.skinId,
        resource=state.sourceTemplate.Name, template=row.template, baseParts=0, morphParts=0, morphs={},
        serverSourceAlphaPreserved=true, cosmeticFlagsPreserved=true,
        expectedBasePartCount=state.model:GetAttribute('HeroExpectedBasePartCount'),
        expectedFallbackCount=state.model:GetAttribute('HeroExpectedFallbackCount'),
        activeMorph=state.model:GetAttribute('HeroActiveMorph') or 'None'}
    if details then out.parts={} end
    local function inspect(p, source, group)
        local same=source and p.Transparency==source.Transparency and p.Transparency==p:GetAttribute('HeroVisibleTransparency')
        out.serverSourceAlphaPreserved=out.serverSourceAlphaPreserved and same==true
        out.cosmeticFlagsPreserved=out.cosmeticFlagsPreserved and p.Massless and not p.Anchored
            and not p.CanCollide and not p.CanTouch and not p.CanQuery
        if details then
            local surfaces={}
            for _, surface in ipairs(p:GetChildren()) do if surface:IsA('SurfaceAppearance') then
                local maps={}
                for _, property in ipairs(MAPS) do maps[property]=contentUri(mapContent(surface,property)) end
                surfaces[#surfaces+1]={name=surface.Name,maps=maps}
            end end
            out.parts[#out.parts+1]={name=p.Name,group=group,transparency=p.Transparency,
                sourceTransparency=source and source.Transparency,alphaMatches=same==true,
                visibleTransparency=p:GetAttribute('HeroVisibleTransparency'),meshId=p.MeshId,textureId=p.TextureID,
                expectedMeshId=p:GetAttribute('HeroExpectedMeshId'),expectedTextureId=p:GetAttribute('HeroExpectedTextureId'),
                expectedSurfaceCount=p:GetAttribute('HeroExpectedSurfaceCount'),
                expectedSurfaceMaps=p:GetAttribute('HeroExpectedSurfaceMaps'),surfaces=surfaces}
        end
    end
    for _, p in ipairs(state.model:GetChildren()) do if p:IsA('MeshPart') then
        out.baseParts+=1; inspect(p,state.sourceTemplate:FindFirstChild(p.Name),'Base')
    end end
    for _, kind in ipairs(MORPHS) do
        local morph=state.morphs[kind]
        if morph then
            out.morphParts+=1; out.morphs[#out.morphs+1]=kind
            inspect(morph.part,morph.template:FindFirstChild('Morph'),kind)
        end
    end
    return out
end
local function findRow(value)
    if type(value)=='number' then return rows[value] end
    for _, row in ipairs(rows) do if value==row.palette or value==row.template then return row end end
end
local function read(kind, selected)
    local details=kind=='details'
    local out={schema=1,status=cleaned and 'Cleaned' or (#errors==0 and #rows==3 and 'Prepared' or 'Incomplete'),
        sourceMatches=observed==expected,expectedSourceSha256=expected,observedSourceSha256=observed,
        ownerToken=token,gallery=gallery:GetFullName(),paletteCount=#rows,errors=errors,operations=operations,
        scope='Three prepared native R6 actors and cosmetic loading intent; separate from campaign/action acceptance',
        renderedProcessedPBRPixels='Not certified by a source-image fetch or this server reader',heroes={}}
    for _, row in ipairs(rows) do if selected==nil or findRow(selected)==row then
        out.heroes[#out.heroes+1]={palette=row.palette,template=row.template,physical=physicalRead(row,details),
            appearance=attachmentRead(row,details),resourceRevision=row.revision}
    end end
    return encode(out)
end
local function control(name, callback)
    local bindable=Instance.new('BindableFunction'); bindable.Name=name; bindable.OnInvoke=callback; bindable.Parent=owner
    return bindable
end
control('Read',read)
for index, palette in ipairs({'Green','Yellow','Brown'}) do
    local ok, problem=xpcall(function()
        local row={palette=palette,template='Mr. '..palette,actor=actor(index,palette),
            originalMaps={},originalTextures={},revision=1}
        rows[#rows+1]=row; row.physical=physicalSnapshot(row.actor)
        local private=Instance.new('Folder'); private.Name=palette; private.Parent=resources
        row.characterTemplates=characterSources:Clone(); row.characterTemplates.Name='CharacterTemplates'; row.characterTemplates.Parent=private
        row.morphTemplates=morphSources:Clone(); row.morphTemplates.Name='MorphTemplates'; row.morphTemplates.Parent=private
        rememberSourceResources(private,row)
        local attached, why=Appearance.attach(row.actor,row.template,row.characterTemplates,row.morphTemplates)
        assert(attached,why)
        local result=attachmentRead(row,false)
        assert(result.baseParts==15 and result.morphParts==4,'Expected actual15 base and4 preassembled morphs')
        assert(result.serverSourceAlphaPreserved and result.cosmeticFlagsPreserved,'Source alpha/cosmetic flags changed')
        assert(physicalRead(row,false).preserved,'Factory changed prepared physical rig')
    end,debug.traceback)
    if not ok then errors[#errors+1]={palette=palette,error=smallError(problem)} end
end
control('SetMorph',function(selected,kind)
    assert(not cleaned,'Fixture cleaned')
    if kind=='' or kind=='None' then kind=nil end
    assert(kind==nil or morphSet[kind],'Unknown prepared morph')
    assert(selected=='all' or findRow(selected),'Unknown prepared palette')
    for _, row in ipairs(rows) do if selected=='all' or findRow(selected)==row then
        local state=assert(row.actor.appearance,'Actor not attached')
        assert(not kind or state.morphs[kind],'Prepared resource unavailable')
        state.model:SetAttribute('HeroActiveMorph',kind)
    end end
    local filter=selected
    if selected=='all' then filter=nil end
    return read('summary',filter)
end)
local function privatePart(selected,group,partName,value)
    assert(not cleaned,'Fixture cleaned')
    local row=assert(findRow(selected),'Unknown prepared palette')
    assert(group=='Base' or morphSet[group],'Unknown prepared resource group')
    assert(type(value)=='string' and #value<=512 and value~='','Raw content ID or restore required')
    local state=assert(row.actor.appearance,'Actor not attached')
    local template=group=='Base' and state.sourceTemplate or assert(state.morphs[group],'Morph unavailable').template
    local p=assert(template:FindFirstChild(group=='Base' and (partName or 'Head') or 'Morph'),'Private source part unavailable')
    assert(p:IsA('MeshPart') and p:IsDescendantOf(resources),'Refusing a shared source mutation')
    return row,state,p
end
local function reattachAfterWrite(row,state,operation,write,rollback)
    local writable,problem=pcall(write)
    operation.nativePropertyWritable=writable
    if writable then
        local intent=state.model:GetAttribute('HeroActiveMorph')
        local function attach()
            local attached,why=Appearance.attach(row.actor,row.template,row.characterTemplates,row.morphTemplates)
            if attached then row.actor.appearance.model:SetAttribute('HeroActiveMorph',intent) end
            return attached,why
        end
        Appearance.detach(row.actor)
        row.revision+=1
        local attached,why=attach()
        operation.attached=attached
        if not attached then
            operation.error=smallError(why)
            local restored,restoreError=pcall(rollback)
            if restored then restored,restoreError=attach() end
            operation.rolledBack=restored
            if not restored then operation.rollbackError=smallError(restoreError) end
        end
    else
        operation.error=smallError(problem)
    end
    operations[#operations+1]=operation
    if #operations>16 then table.remove(operations,1) end
    return encode({operation=operation,hero={palette=row.palette,physical=physicalRead(row,false),
        appearance=attachmentRead(row,false),resourceRevision=row.revision}})
end
local function setMapContent(surface,property,content)
    local field=property..'Content'
    local ok,problem=pcall(function()surface[field]=content end)
    if ok then return field end
    -- This fixture is invoked by the authorized Studio QA context. Legacy
    -- writes are a fallback if the modern setter is restricted there.
    local uri=contentUri(content)
    if uri~='' or content.SourceType==Enum.ContentSourceType.None then
        surface[property]=uri
        return property
    end
    error(problem,0)
end
control('SetMap',function(selected,group,property,value,partName)
    assert(mapSet[property],'Only four source-map properties are supported')
    local row,state,p=privatePart(selected,group,partName,value)
    local surfaces={}; for _, child in ipairs(p:GetChildren()) do if child:IsA('SurfaceAppearance') then surfaces[#surfaces+1]=child end end
    table.sort(surfaces,function(a,b)return a.Name<b.Name end)
    local surface=assert(surfaces[1],'Private source has no SurfaceAppearance')
    local before=mapContent(surface,property)
    local replacement=value=='restore' and assert(row.originalMaps[surface])[property] or Content.fromUri(value)
    local operation={palette=row.palette,group=group,part=p.Name,property=property,before=contentUri(before),
        requested=contentUri(replacement),
        scope='Private template map edit followed by actual factory attachment'}
    return reattachAfterWrite(row,state,operation,function()
        operation.writeProperty=setMapContent(surface,property,replacement)
        operation.stored=contentUri(mapContent(surface,property))
        operation.storedMatchesRequested=operation.stored==operation.requested
    end,function()setMapContent(surface,property,before)end)
end)
control('SetTexture',function(selected,group,value,partName)
    local row,state,p=privatePart(selected,group,partName,value)
    local before=p.TextureID
    local replacement=value=='restore' and assert(row.originalTextures[p]) or value
    local operation={palette=row.palette,group=group,part=p.Name,property='TextureID',before=before,
        requested=replacement,scope='Private flat-texture edit followed by actual factory attachment'}
    return reattachAfterWrite(row,state,operation,function()
        p.TextureID=replacement
        operation.stored=p.TextureID
        operation.storedMatchesRequested=operation.stored==operation.requested
    end,function()p.TextureID=before end)
end)
control('Cleanup',function()
    if cleaned then return encode({status='AlreadyCleaned'}) end
    cleaned=true
    local remaining={}
    for _, row in ipairs(rows) do
        local ok,problem=pcall(function()Appearance.detach(row.actor)end)
        if not ok then remaining[#remaining+1]=smallError(problem) end
    end
    if gallery:GetAttribute('ReleaseHeroLoadingOwner')==token then gallery:Destroy() end
    local result=encode({status='Cleaned',ownedGalleryDestroyed=gallery.Parent==nil,errors=remaining})
    if owner.Parent==SS and owner:GetAttribute('ReleaseHeroLoadingOwner')==token then owner:Destroy() end
    return result
end)
return {read=function(kind,selected)return read(kind,selected)end,ownerToken=token}
