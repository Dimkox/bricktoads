-- Prepared collision boundary: real Session/Core/Combat/Director/Modes/Enemies;
-- only engine actor presentation and entry-patrol setup are replaced. This is
-- not a normal-input route playthrough or native replication acceptance.
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Enemies=require('../../src/server/gameplay/CampaignEnemies')
local Director=require('../../src/server/gameplay/LevelDirector')
local CampaignDirector=require('../../src/server/gameplay/CampaignDirector')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local DT=1/60
local function fixture(count,at,protected)
    at=at or 5
    local route=Definition.build(3,41);local world=FakeWorld.new()
    world.names={};world.positions={};world.shots={};world.objects={};world.spawnCounts={}
    local director
    function world:findSafe(id) return director and director.modes:respawnPosition(id) or table.clone(route.spawn) end
    local spawn=world.spawn
    function world:spawn(id,actorId,p,held)
        local ok=spawn(self,id,actorId,p,held)
        if ok then self.positions[id]=table.clone(p or route.spawn);self.spawnCounts[id]=(self.spawnCounts[id] or 0)+1 end
        return ok
    end
    function world:position(id) return self.positions[id] end
    function world:spawnEnemy(id,kind,p)
        local ok=spawn(self,id,'enemy-'..id,nil,false)
        if ok then self.positions[id]=table.clone(p);self.actors[id].kind=kind end
        return ok
    end
    function world:campaignPose(id,p) self.positions[id]=table.clone(p);self.actors[id].campaignControl=true end
    function world:campaignRelease(id) self.actors[id].campaignControl=nil end
    function world:campaignObject(id,kind,p) self.objects[id]={kind=kind,position=table.clone(p)} end
    function world:campaignRemove(id) self.objects[id]=nil end
    function world:projectile(id,p,_,kind) self.shots[id]={kind=kind,position=table.clone(p)} end
    function world:removeProjectile(id) self.shots[id]=nil end
    function world:campaignProjectileBlocked() return false end
    function world:stage(value) self.stageName=value end
    function world:progress() end
    function world:reached() return false end
    function world:atExit() return false end
    function world:enemyIdentity(id,actorId) self.actors[id].id=actorId end
    function world:enemyHealth() end
    function world:enemyMove() end
    function world:face() end
    function world:aim() end
    function world:cue() end
    local cfg=GameConfig(Base,route);local roster={}
    for id=1,count do roster[id]={userId=id,template='Mr. Green'} end
    local session=Session.new(Core,Combat,cfg,roster,'vehicle-enemy-boundary-'..count,world)
    assert(session:step(0)=='OK')
    director=CampaignDirector.new(session,world,Combat,cfg,{Director=Director,CampaignModes=Modes,
        CampaignDefinition=Definition,CampaignEnemies=Enemies})
    -- The collision starts after the real ordinary lifecycle has cleared entry.
    director.ordinary:_kill(-1,'PreparedEntryClear')
    assert(session:step(at)=='OK');director:step(at,0)
    if protected then
        session:_die(1,'PreparedRespawn');at+=DT
        assert(session:step(at)=='OK');director:step(at,0)
    end
    for _,id in ipairs(session.order) do
        world.positions[id]=table.clone(route.course.mount);assert(director:interact(id,at,'Punch')=='OK')
    end
    return session,world,director,route,at
end
local function primary(d,s,userId,now)
    local role=d:controlled(userId)
    return d:command(userId,{kind='Attack',attack='Punch',runId=s.state.runId,actorId=role.actorId,attempt=1,
        levelEpoch=s.state.levelEpoch,connectionEpoch=role.connectionEpoch,seq=1},now,Session.validIntent)
end
local function crash(count,multiple)
    local s,w,d,route=fixture(count)
    local now=5;local first=d.modes.actors[1]
    -- A source type29 obstacle drops at x138/z12. Starting 21 studs behind it
    -- makes the actually moving hero meet it as it falls; the nearby overhead
    -- obstacle is passed at ground height without changing course geometry.
    first.position={x=117,y=3,z=12};first.progress=117-route.course.mount.x;w:campaignPose(1,first.position)
    local survivors={}
    for id=2,count do
        local other=d.modes.actors[id];other.position={x=117,y=3,z=-12-(id-2)*4};w:campaignPose(id,other.position)
        local h=s.state.heroes[id]
        survivors[id]={actorId=h.actorId,attempt=h.attempt,stock=h.respawns,life=s.combat[id].rawLife,spawns=w.spawnCounts[id]}
    end
    local function unchanged()
        for id,before in pairs(survivors) do local h=s.state.heroes[id]
            assert(h.actorId==before.actorId and h.attempt==before.attempt and h.respawns==before.stock)
            assert(s.combat[id].rawLife==before.life and w.spawnCounts[id]==before.spawns)
        end
    end
    d.modes:_encounters()
    local rat;for id,enemy in pairs(d.enemies) do if enemy.encounter then rat=id end end
    assert(rat and d:claim(99,rat)=='OK')
    if multiple then
        local event=table.clone(route.course.encounters[1]);event.id='prepared-far-rocket-pass'
        event.position={x=250,y=14,z=-12}
        event.trajectory={from=table.clone(event.position),to={x=386,y=14,z=-12},duration=4,dropAt=1.5,dropGroundY=3}
        local far=d.modes.spawnEncounter(event);assert(d:claim(100,far)=='OK')
    end
    d:step(now,0)
    -- Newer projectile IDs sort first. Emit the harmless distant drop first so
    -- the crashing drop resets/removes a later ID in the same iteration list.
    if multiple then assert(primary(d,s,100,now)=='OK') end
    assert(primary(d,s,99,now)=='OK')
    local contact
    for _=1,55 do
        now+=DT;assert(s:step(now)=='OK');d:step(now,DT)
        if s.combat[1].rawLife<47 or s.state.heroes[1].status~='Alive' then contact=true;break end
    end
    assert(contact,'prepared ordinary moving hero must contact the actual RocketRat drop')
    print('RocketRat drop contact: status='..s.state.heroes[1].status..' rawLife='..s.combat[1].rawLife
        ..' phase='..d.modes.vehicleGroup.phase..' serial='..d.modes.vehicleGroup.serial)
    assert(s.state.heroes[1].status=='AwaitingRespawn' and d.modes.vehicleGroup.phase=='Stopped'
        and d.modes.vehicleGroup.serial==1,
        'type29 contact must use the mounted crash lifecycle, not a nonlethal WalkerHeavy hit')
    unchanged()
    assert(next(d.campaignEnemies.projectiles)==nil and next(w.shots)==nil,'rewind removes every active scripted drop during collision dispatch')
    for _=1,65 do now+=DT;assert(s:step(now)=='OK');d:step(now,DT) end
    assert(s.state.heroes[1].attempt==2 and s.state.heroes[1].respawns==2 and w.spawnCounts[1]==2)
    assert(d.modes.vehicleGroup.phase=='Riding' and d.modes.vehicleGroup.serial==1)
    unchanged()
    print('PASS real RocketRat drop crash preserves '..(count-1)..' survivors'..(multiple and ' and safely clears two active drops' or ''))
end
return function()
    crash(2,false)
    crash(3,true)
    local s,w,d,route,now=fixture(1,0,true);local first=d.modes.actors[1]
    local hero=s.state.heroes[1];local shield=hero.shield;assert(shield and shield.deadline>0)
    local actor,deadline,attempt,stock=hero.actorId,shield.deadline,hero.attempt,hero.respawns
    first.position={x=117,y=3,z=12};first.progress=117-route.course.mount.x;w:campaignPose(1,first.position)
    d.modes:_encounters();local rat
    for id,enemy in pairs(d.enemies) do if enemy.encounter then rat=id end end
    assert(rat and d:claim(99,rat)=='OK');d:step(now,0);assert(primary(d,s,99,now)=='OK')
    local consumed=false
    for _=1,55 do
        now+=DT;assert(s:step(now)=='OK');d:step(now,DT)
        if next(d.campaignEnemies.projectiles)==nil then consumed=true;break end
    end
    assert(consumed and now<deadline,'the actual drop must contact while the original shield is active')
    local current=s.state.heroes[1]
    assert(current.status=='Alive' and current.actorId==actor and current.attempt==attempt and current.respawns==stock)
    assert(s.combat[1].rawLife==47 and not s.combat[1].reactionEnd and not s.combat[1].deathAt and w.impulses==0)
    assert(current.shield and current.shield.kind==shield.kind and current.shield.deadline==deadline)
    assert(d.modes.vehicleGroup.phase=='Riding' and d.modes.vehicleGroup.serial==0 and w.spawnCounts[1]==2)
    assert(d.modes:vehicleObstacleHit(999)==false)
    assert(d.modes:vehicleObstacleHit(1)==true and s.combat[1].rawLife==47)
    first.finished=true;assert(d.modes:vehicleObstacleHit(1)==false)
    first.finished=false;first.mounted=false;assert(d.modes:vehicleObstacleHit(1)==false)
    print('PASS protected mounted RocketRat contact consumes the drop without ordinary damage, impulse or shield extension')
    return 3
end
