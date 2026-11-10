-- Prepared native catalog only. Run AFTER the campaign, in owned Studio QA.
-- Install as a fresh ModuleScript under ServerStorage.BrickToadsFullCatalogQA;
-- set ExpectedSourceSha256 before require(). The module returns immediately;
-- poll that folder's Read BindableFunction ('summary' or 'details').
-- Only fresh synthetic bodies, cosmetic module clones and owned gallery change.
-- No live players, campaign, health, resources, input, audio or preload changes.
assert(game:GetService('RunService'):IsStudio(), 'Studio fixture only')
local SS, Http = game:GetService('ServerStorage'), game:GetService('HttpService')
local owner = script.Parent
assert(owner.Name == 'BrickToadsFullCatalogQA' and owner.Parent == SS, 'Use the owned full-catalog QA folder')
local expected = script:GetAttribute('ExpectedSourceSha256')
assert(type(expected) == 'string' and #expected == 64 and expected:match('^[0-9a-f]+$'), 'ExpectedSourceSha256 required')
assert(not owner:FindFirstChild('Modules') and not owner:FindFirstChild('Read'), 'Use a fresh owned QA folder')
assert(not workspace:FindFirstChild('BrickToadsFullCatalogGallery'), 'Prior owned catalog gallery must be removed first')
local production = assert(game:GetService('ServerScriptService'):FindFirstChild('BrickToads'))
local modules = Instance.new('Folder'); modules.Name = 'Modules'; modules.Parent = owner
local build = assert(production:FindFirstChild('BuildInfo')):Clone(); build.Parent = owner
local observed = require(build).sourceSha256
assert(observed == expected, 'Catalog source differs from expected frozen source')
for _, name in ipairs({'CanonicalAnimation', 'CanonicalWalker', 'CanonicalCastProfiles', 'CanonicalCastPresentation',
    'CanonicalCastAppearance', 'CanonicalHeroPresentation', 'CharacterAppearance', 'GuardianAppearance', 'CourseAppearance'}) do
    local clone = assert(production.gameplay:FindFirstChild(name), 'Missing current module ' .. name):Clone()
    clone.Parent = modules
end
local Cast = require(modules.CanonicalCastAppearance)
local CastPresentation = require(modules.CanonicalCastPresentation)
local Hero = require(modules.CharacterAppearance)
local Guardian = require(modules.GuardianAppearance)
local Course = require(modules.CourseAppearance)
local Animation = require(modules.CanonicalAnimation)
local gallery = Instance.new('Folder'); gallery.Name = 'BrickToadsFullCatalogGallery'; gallery.Parent = workspace
local report = {schema = 1, status = 'Running', expectedSourceSha256 = expected, observedSourceSha256 = observed,
    sourceMatches = observed == expected, createdAt = os.time(), placeId = game.PlaceId,
    scope = 'Prepared current native resources and cosmetic source-pose paths; separate from the campaign playthrough',
    limits = {'Cosmetic Motor6D geometry is explicitly solved on fresh anchored synthetic R6 bodies.',
        'No preload requests or client visibility/audio acceptance; native render and client availability remain separate.',
        'Enumerated actions/states are fixture inputs, not claims that gameplay selected every conditional source trace.',
        'Ride sole measurements compare exact posed MeshPart boxes to declared deckY0; pixel hulls may occupy less than those boxes.'},
    cast = {}, heroes = {}, guardian = {}, ride = {}, errors = {}, physicalDrift = {},
    counts = {castFamilies = 0, castMeshParts = 0, heroPalettes = 0, heroMorphResources = 0,
        heroCases = 0, castSamples = 0, guardianMeshParts = 0}}
local read = Instance.new('BindableFunction'); read.Name = 'Read'; read.Parent = owner
read.OnInvoke = function(kind)
    if kind == 'details' then return Http:JSONEncode(report) end
    return Http:JSONEncode({status = report.status, sourceMatches = report.sourceMatches,
        observedSourceSha256 = report.observedSourceSha256, counts = report.counts, errors = report.errors,
        ride = report.ride, gallery = gallery:GetFullName()})
end
local result = Instance.new('StringValue'); result.Name = 'Result'; result.Parent = owner
local function attempt(kind, name, fn)
    local ok, problem = xpcall(fn, debug.traceback)
    if not ok then report.errors[#report.errors + 1] = {kind = kind, name = name, error = string.sub(tostring(problem), 1, 1600)} end
end
local function part(parent, name, size, frame, collide)
    local p = Instance.new('Part'); p.Name = name; p.Size = size; p.CFrame = frame
    p.Anchored = false; p.CanCollide = collide == true; p.CanTouch = false; p.CanQuery = false; p.Parent = parent
    return p
end
local function fixture(name, position)
    local model = Instance.new('Model'); model.Name = name; model:SetAttribute('ActorId', 'catalog:' .. name)
    local root = part(model, 'HumanoidRootPart', Vector3.new(2, 2, 1), CFrame.new(position), false)
    root.Anchored = true; root.Transparency = 1
    local torso = part(model, 'Torso', Vector3.new(2, 2, 1), root.CFrame, true)
    local joint = Instance.new('Motor6D'); joint.Name = 'RootJoint'; joint.Part0 = root; joint.Part1 = torso; joint.Parent = root
    for _, d in ipairs({{'Head', Vector3.new(2, 1, 1), 'Neck', Vector3.new(0, 1, 0), Vector3.new(0, -.5, 0)},
        {'Left Arm', Vector3.new(1, 2, 1), 'Left Shoulder', Vector3.new(-1.5, 0, 0), Vector3.new(0, .5, 0)},
        {'Right Arm', Vector3.new(1, 2, 1), 'Right Shoulder', Vector3.new(1.5, 0, 0), Vector3.new(0, .5, 0)},
        {'Left Leg', Vector3.new(1, 2, 1), 'Left Hip', Vector3.new(-.5, -1, 0), Vector3.new(0, 1, 0)},
        {'Right Leg', Vector3.new(1, 2, 1), 'Right Hip', Vector3.new(.5, -1, 0), Vector3.new(0, 1, 0)}}) do
        local c0, c1 = CFrame.new(d[4]), CFrame.new(d[5])
        local p = part(model, d[1], d[2], torso.CFrame * c0 * c1:Inverse(), d[1] == 'Head')
        local m = Instance.new('Motor6D'); m.Name = d[3]; m.Part0 = torso; m.Part1 = p; m.C0 = c0; m.C1 = c1; m.Parent = torso
    end
    local humanoid = Instance.new('Humanoid'); humanoid.BreakJointsOnDeath = false; humanoid.HipHeight = 0
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None; humanoid.Parent = model
    model.PrimaryPart = root; model.Parent = gallery
    local original = {health = humanoid.Health, parts = {}}
    for _, p in ipairs(model:GetChildren()) do if p:IsA('BasePart') then
        original.parts[p] = {size = p.Size, frame = p.CFrame, collide = p.CanCollide, anchored = p.Anchored}
    end end
    return {model = model, root = root, humanoid = humanoid}, original
end
local function preserved(a, original)
    assert(a.humanoid.Health == original.health, 'Fixture HP changed')
    for p, row in pairs(original.parts) do
        assert(p.Parent == a.model and p.Size == row.size and p.CanCollide == row.collide and p.Anchored == row.anchored,
            'Original physical part changed: ' .. p.Name)
        local delta = (p.Position - row.frame.Position).Magnitude
        if delta >= .02 and #report.physicalDrift < 40 then
            local actual, expectedPosition = p.Position, row.frame.Position
            report.physicalDrift[#report.physicalDrift+1] = {model=a.model.Name, part=p.Name, delta=delta,
                actual={x=actual.X,y=actual.Y,z=actual.Z}, expected={x=expectedPosition.X,y=expectedPosition.Y,z=expectedPosition.Z}}
        end
        assert(delta < .02, 'Original physical position changed: ' .. p.Name .. ' delta=' .. tostring(delta))
    end
end
local function solve(model)
    -- Setting one connected Part1.CFrame can move the native welded assembly.
    -- Capture cosmetic equations, then disconnect ONLY owned cosmetic motors
    -- before placing the prepared Edit geometry. The physical R6 stays intact.
    local rows,frames={},{}
    for _,j in ipairs(model:GetDescendants())do
        if j:IsA('Motor6D') and j.Part0 and j.Part1 and j.Part1:IsA('MeshPart')then
            rows[j.Part1]={part=j.Part1,parent=j.Part0,c0=j.C0,c1=j.C1};j.Part1=nil
        end
    end
    local function pose(p)
        if frames[p]then return frames[p]end
        local row=rows[p]
        frames[p]=row and pose(row.parent)*row.c0*row.c1:Inverse() or p.CFrame
        return frames[p]
    end
    for part in pairs(rows)do part.CFrame=pose(part)end
end
local function geometry(model, direct)
    local count = 0
    for _, p in ipairs(direct and model:GetChildren() or model:GetDescendants()) do if p:IsA('MeshPart') then
        count += 1
        assert(p.MeshId:match('^rbxassetid://[1-9]%d*$'), 'Missing uploaded mesh')
        assert(p.Massless and not p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery, 'Noncosmetic imported mesh')
    end end
    return count
end
local function snapshot(pose)
    assert(pose and pose.joints, 'No actual source/adaptation pose')
    return {state = pose.state or pose.kind, frame = pose.frameId, namespace = pose.namespace,
        frameBasis = pose.frameBasis, animationId = pose.animationId, sourceBranch = pose.sourceBranch,
        actionBinding = pose.actionBinding, morph = pose.morphKind}
end
local function minY(p)
    local low = math.huge
    for _, x in ipairs({-1, 1}) do for _, y in ipairs({-1, 1}) do for _, z in ipairs({-1, 1}) do
        low = math.min(low, p.CFrame:PointToWorldSpace(Vector3.new(p.Size.X*x/2, p.Size.Y*y/2, p.Size.Z*z/2)).Y)
    end end end
    return low
end
local CAST_ACTIONS = {Pig = {'PigJab', 'PigHeavy', 'PigRush', 'EnemyRunStrike'}, Walker = {'WalkerLight', 'WalkerHeavy', 'EnemyRunStrike'},
    Dragon = {'DragonHeadbutt', 'Capture'}, BigBlag = {'Hop', 'BellyDrop'}, GeneralSlaughter = {'Charge', 'Headbutt'},
    RoboManus = {'Burst', 'Jump'}, DarkQueen = {'Sweep', 'Spin'}, Raven = {'Swoop'}, SaturnToadtrap = {'Snap'},
    RetroBlaster = {'Bolt'}, Snowman = {'Snowball'}, Hordhead = {'Roll'}, RocketRat = {'DropObstacle'},
    Hammerfish = {'Lunge'}, Shark = {'Bite'}, Duck = {'Bite'}}
local HERO_ACTIONS = {HeroJab=0x02,HeroJabB=0x04,HeroUppercut=0x06,HeroBigUppercut=0x10,
    HeroPowerPunch=0x0E,HeroKick=0x12,HeroBoot=0x14,HeroElbow=0x36,Dash=0x16,
    Club=0x1A,Tongue=0x18,PickupObject=0x08,PickupEnemy=0x0A,Throw=0x0C,BossBallThrow=0x70,
    JumpAttack=0x26,RopeStrike=0x1C,RopeReverseStrike=0x1E,RopeTongue=0x20,RopeKick=0x22,
    RopeWeight=0x24,RopeFastStrike=0x46,RopeBeakStrike=0x48,RopeCannonWeight=0x4E,
    RopeCannonBoot=0x50,RopeRavenStrike=0x52,RopePropellerKick=0x82,
    ClubOverhead=0x3E,HeroFastPunch=0x72,HeroFastUppercut=0x74,HeroFastBoot=0x76,HeroFastElbow=0x78}
local function run()
    local templates = assert(SS:FindFirstChild('BrickToadsCastTemplates'))
    local native = templates:GetChildren(); assert(#native == 29, 'Expected exactly29 cast templates')
    assert(#CastPresentation.kinds() == 29, 'Expected exactly29 production cast families')
    for index, kind in ipairs(CastPresentation.kinds()) do attempt('Cast', kind, function()
        local source = assert(templates:FindFirstChild(kind), 'Missing cast family ' .. kind)
        local resourceMeshes = 0; for _, p in ipairs(source:GetChildren()) do if p:IsA('MeshPart') then resourceMeshes += 1 end end
        local a, original = fixture(kind, Vector3.new(9000+(index-1)%6*20, 3, math.floor((index-1)/6)*25))
        assert(Cast.attach(a, kind)); local state = a.castAppearance
        local row = {kind = kind, resourceMeshes = resourceMeshes, meshes = geometry(state.model), samples = {}}
        assert(row.meshes == resourceMeshes, 'Attached mesh inventory differs from resource')
        local at = 0
        local function sample(label, fields)
            at += 1
            local c = {kind = kind, actorId = a.model:GetAttribute('ActorId'), levelEpoch = 1, now = at,
                dt = .1, speed = 8, mode = 'Walk'}
            for k, v in pairs(fields or {}) do c[k] = v end
            Cast.update(a, c); local p = snapshot(state.pose); p.label = label; row.samples[#row.samples+1] = p
            preserved(a, original); report.counts.castSamples += 1
        end
        sample('Idle', {mode='Idle', speed=0}); sample('Walk', {}); sample('Run', {mode='Run', speed=12})
        sample('Fly', {mode='Fly'}); sample('Swim', {mode='Swim'})
        sample('LightReactionEarly', {reacting=true, reactionProgress=0}); sample('LightReactionLate', {reacting=true, reactionProgress=1})
        sample('HeavyReaction', {reacting=true, reactionHeavy=true}); sample('Carried', {carried=true}); sample('Dead', {dead=true})
        for _, action in ipairs(CAST_ACTIONS[kind] or {}) do
            local attack = {name=action, actorId=a.model:GetAttribute('ActorId'), levelEpoch=1, start=at+1}
            sample(action..':Tell', {attack=attack, phase='Tell', now=attack.start})
            sample(action..':Active', {attack=attack, phase='Active', now=attack.start+.15})
            sample(action..':Recovery', {attack=attack, phase='Recovery', now=attack.start+.3})
        end
        solve(a.model); preserved(a, original)
        report.cast[#report.cast+1] = row; report.counts.castFamilies += 1; report.counts.castMeshParts += row.meshes
    end); task.wait() end
    attempt('Inventory','CastCounts',function()
        assert(report.counts.castFamilies == 29 and report.counts.castMeshParts == 166, 'Expected29 cast families/166 parts')
    end)
    local forms = {'Idle','Folded1F','Fear32','Fear33','Ride','RideSpeeder','RideSurfboard','RideJet','RideClingerVehicle',
        'Air','Carry','Reaction','Dead','Carried','DragonMounted','DragonCaptured','Swim','Rope','ClubPose','DashTailFixture'}
    for action in pairs(HERO_ACTIONS) do forms[#forms+1] = action end
    table.sort(forms)
    for hi, template in ipairs({'Mr. Green','Mr. Yellow','Mr. Brown'}) do
        local palette = {template=template, cases={}, morphs={}}; report.heroes[#report.heroes+1] = palette
        local morphInventory
        for si, name in ipairs(forms) do attempt('Hero', template..':'..name, function()
            local a, original = fixture(template..'_'..name, Vector3.new(9000+(si-1)%8*14, name=='RideJet' and 8 or 3,
                -40-hi*35-math.floor((si-1)/8)*16))
            assert(Hero.attach(a, template)); local state = a.appearance
            assert(geometry(state.model, true) == 15, 'Expected15 actual hero body meshes')
            local morphCount = 0; for kind in pairs(state.morphs or {}) do morphCount += 1; palette.morphs[kind] = true end
            assert(morphCount == 4, 'Expected all four prepared hero morph resources')
            morphInventory = morphCount
            local c = {enabled=true, actorId=a.model:GetAttribute('ActorId'), body=a.model, levelEpoch=1,
                now=0, dt=0, grounded=true, mode='Idle', speed=0, reactionEpoch=0}
            local row = {name=name, frames={}, states={}, morphs={}, samples=0, resource=state.sourceTemplate.Name}
            local function sample(at)
                c.now=at; Hero.update(a,c); local p=assert(state.sourcePose, 'Missing hero pose: '..tostring(state.sourceFallback))
                row.samples+=1; row.states[p.kind]=true
                if p.frameId then row.frames[tostring(p.frameId)]=true end
                if state.activeMorph then row.morphs[state.activeMorph]=true end
                preserved(a,original)
                return p
            end
            local expectedAnimation=HERO_ACTIONS[name]
            local rideVehicle
            local mountedKind=({RideSpeeder='Speeder',RideSurfboard='Surfboard',RideJet='Jet',RideClingerVehicle='ClingerVehicle'})[name]
            if mountedKind then
                local clinger=mountedKind=='ClingerVehicle'
                local size=clinger and Vector3.new(4,.6,4) or Vector3.new(6,.9,3)
                local position=a.root.Position-Vector3.new(0,clinger and 2.7 or 2.6,0)
                local proxy=part(gallery,'CatalogVehiclePlate_'..hi..'_'..mountedKind,size,CFrame.new(position),false)
                proxy.Anchored=true
                local baseline={size=proxy.Size,frame=proxy.CFrame,collide=proxy.CanCollide,query=proxy.CanQuery,touch=proxy.CanTouch}
                local vehicleRow={id='catalog-'..hi..'-'..mountedKind,kind=mountedKind,part=proxy}
                local waterY=mountedKind=='Surfboard' and 1 or nil
                Course.update(vehicleRow,gallery,{role='Vehicle',collidable=false},waterY)
                local vehicleState=assert(vehicleRow.courseAppearance,'Missing approved course resource '..mountedKind)
                assert(type(vehicleState.deckWorldY)=='number','Missing current native deckWorldY')
                assert(proxy.Size==baseline.size and proxy.CFrame==baseline.frame and proxy.CanCollide==baseline.collide
                    and proxy.CanQuery==baseline.query and proxy.CanTouch==baseline.touch and proxy.Anchored,
                    'Course appearance changed its physical proxy')
                c.visualState='Ride';c.rideDeckY=vehicleState.deckWorldY
                rideVehicle={kind=mountedKind,state=vehicleState,waterY=waterY,plateCenterY=position.Y}
            end
            if expectedAnimation then
                c.attack={action=name, actorId=c.actorId, at=.1, tuning={windup=.1}}
                for call=0,120 do
                    local p=sample(call/60)
                    if p.kind=='Attack' then assert(p.animationId==expectedAnimation, 'Wrong source action mapping') end
                    if call%30==0 then task.wait() end
                end
                -- Re-select an actual visible large form for retained gallery cases.
                if name=='HeroPowerPunch' or name=='HeroBoot' then
                    c.attack={action=name,actorId=c.actorId,at=3.1,tuning={windup=.1}};sample(3.5)
                    assert(state.activeMorph==(name=='HeroBoot' and 'BigBoot' or 'PowerFist'))
                end
            elseif name=='Folded1F' then c.attack={action='HeroBoot',actorId=c.actorId,at=.1,tuning={windup=.1}};assert(sample(0).frameId==0x1F)
            elseif name=='Fear32' or name=='Fear33' then
                c.fearIntro={id='catalogIntro',actorId=c.actorId,counter=name=='Fear32' and 1 or 0xE1,frameId=name=='Fear32' and 0x32 or 0x33}
                sample(0); assert(state.activeMorph==(name=='Fear32' and 'FearBeforeCut' or 'FearAfterCut'))
            elseif name=='Air' then c.visualState='Air';c.grounded=false;c.verticalSpeed=0;sample(0)
            elseif name=='Carry' then c.visualState='Carrying';c.holding=true;c.speed=8;c.mode='Walk';c.dt=.1;sample(0);sample(.1)
            elseif name=='Reaction' then c.visualState='Reaction';c.reaction={heavy=false,timerRaw=24};sample(0)
            elseif name=='ClubPose' then c.visualState='Club';sample(0)
            elseif name=='DashTailFixture' then
                c.attack={action='Dash',actorId=c.actorId,at=.18,tuning={windup=.18}};sample(0)
                c.dashResult={branch='DashLowLifeTail',profile=3,tuning=c.attack.tuning,body=a.model,actorId=c.actorId,levelEpoch=1,at=.2}
                assert(sample(.2).frameId==0x31);row.note='Prepared confirmed-result shape; actual producer is separately covered by real Session/Director regression and campaign.'
            else if name~='Idle' and not mountedKind then c.visualState=name end;sample(.5) end
            row.pose=snapshot(state.sourcePose);solve(a.model);preserved(a,original)
            if name=='Ride' or mountedKind then
                local l,r=assert(state.model:FindFirstChild('LeftFoot')),assert(state.model:FindFirstChild('RightFoot'))
                local left,right=minY(l),minY(r)
                local minimum=math.huge;for _,p in ipairs(state.model:GetChildren())do if p:IsA('MeshPart')then minimum=math.min(minimum,minY(p))end end
                local deck=rideVehicle and rideVehicle.state.deckWorldY or 0
                local measurement={template=template,vehicle=mountedKind,rootY=a.root.Position.Y,
                    coursePlateCenterY=rideVehicle and rideVehicle.plateCenterY or .4,
                    expectedCourseDeckY=deck,leftFootMinY=left,rightFootMinY=right,skinMinY=minimum,
                    leftGapFromDeck=left-deck,rightGapFromDeck=right-deck,
                    note=mountedKind and 'Actual approved vehicle and aligned canonical Ride; native mesh corners, disconnected cosmetic placement only.'
                        or 'Unaligned Ride diagnostic without mount/deck context; original behavior intentionally retained.'}
                if rideVehicle then
                    local vehicleMin=math.huge
                    for _,p in ipairs(rideVehicle.state.skin:GetDescendants())do if p:IsA('MeshPart')then vehicleMin=math.min(vehicleMin,minY(p))end end
                    measurement.vehicleMinY=vehicleMin;measurement.anchorFootPlaneY=rideVehicle.state.groundPlaneY
                    measurement.waterSurfaceY=rideVehicle.waterY
                    assert(math.abs(left-deck)<=.02 and math.abs(right-deck)<=.02,'Actual Ride soles miss actual deck')
                    assert(vehicleMin>=rideVehicle.state.groundPlaneY-.02,'Vehicle clips the anchor foot plane')
                    if rideVehicle.waterY then assert(deck>=rideVehicle.waterY+.08,'Surf deck is below its native water surface')end
                end
                report.ride[#report.ride+1]=measurement
            end
            report.counts.heroCases+=1;palette.cases[#palette.cases+1]=row
            local keep=mountedKind or name=='Idle' or name=='Folded1F' or name=='Fear32' or name=='Fear33' or name=='Ride' or name=='HeroPowerPunch' or name=='HeroBoot'
            if not keep then a.model:Destroy() end
        end);task.wait() end
        report.counts.heroPalettes+=1;report.counts.heroMorphResources+=(morphInventory or 0)
    end
    attempt('Inventory','HeroCounts',function()
        assert(report.counts.heroPalettes==3 and report.counts.heroMorphResources==12, 'Expected3 palettes/12 morph resources')
    end)
    attempt('Guardian','BossWalkerGuardian',function()
        local a, original=fixture('BossWalkerGuardian',Vector3.new(9140,3,100))
        assert(Guardian.attach(a));local state=a.guardianAppearance
        assert(geometry(state.model)==3, 'Expected3 Guardian meshes')
        Guardian.health(a,47,47,0);Guardian.update(a,0)
        local before=state.rows[2].motor.C0;assert(Guardian.shot(a,'Bullet',.1));assert(state.rows[2].motor.C0~=before)
        assert(Guardian.shot(a,'Heavy',.2));assert(state.rows[3].shotAt==.2)
        Guardian.health(a,31,47,.25);Guardian.update(a,.26);assert(state.hurtAt==.25)
        Guardian.update(a,1);solve(a.model);preserved(a,original)
        report.guardian={meshes=3,leftShot=true,rightShot=true,damageTint=true,colliderPreserved=true}
        report.counts.guardianMeshParts=3
    end)
end
task.spawn(function()
    attempt('Catalog','Runner',run)
    report.status=#report.errors==0 and 'Passed' or 'Failed';report.finishedAt=os.time()
    result.Value=Http:JSONEncode(report)
end)
return {status=report.status,read=read:GetFullName(),gallery=gallery:GetFullName(),observedSourceSha256=observed}
