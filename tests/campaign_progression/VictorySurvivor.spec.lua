-- Prepared final contacts exercise native Session/Director/Controller ordering.
-- Actor presentation and physical hazard observation use the synchronous world
-- double; health, boss defeat, paid retries and stage advancement use real code.
local Controller=require('../../src/server/gameplay/GameController')
local CampaignDirector=require('../../src/server/gameplay/CampaignDirector')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Modes=require('../../src/server/gameplay/CampaignModes')
local Boss=require('../../src/server/gameplay/CampaignBoss')
local Director=require('../../src/server/gameplay/LevelDirector')
local Session=require('../../src/stand/server/Session')
local Core=require('../../src/server/RunLifecycle')
local Combat=require('../../src/stand/server/Combat')
local GameConfig=require('../../src/server/gameplay/GameConfig')
local Base=require('../../src/stand/server/Config')
local FakeWorld=require('../stand/FakeWorld')
local Registry=require('../../src/stand/server/ConnectionRegistry')
local BossQueue=require('../../src/server/gameplay/BossQueue')
local SourceCombat=require('../../src/server/gameplay/SourceCombat')
local CampaignEnemies=require('../../src/server/gameplay/CampaignEnemies')

return function()
    local function fixture(index,count)
        local route=Definition.build(index,51)
        local f={index=index,count=count,now=0,players={},hazards={},geometryCalls=0}
        local world=FakeWorld.new();world.names={};world.positions={};world.objects={};f.world=world
        local activeRoute=route;local originalSpawn=world.spawn
        function world:findSafe(slot)
            return self.campaignModes and self.campaignModes:respawnPosition(slot) or table.clone(activeRoute.spawn)
        end
        function world:position(slot) return self.positions[slot] end
        function world:spawn(slot,actorId,point,held)
            local ok=originalSpawn(self,slot,actorId,point,held)
            if ok then self.positions[slot]=table.clone(point) end
            return ok
        end
        function world:spawnEnemy(id,kind,point)
            local ok=originalSpawn(self,id,'enemy-'..id,point,false)
            if ok then self.positions[id]=table.clone(point) end
            return ok
        end
        function world:campaignPose(slot,point) self.positions[slot]=table.clone(point) end
        function world:campaignRelease() end
        function world:campaignObject(id,kind,point) self.objects[id]={kind=kind,position=table.clone(point)} end
        function world:campaignRemove(id) self.objects[id]=nil end
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
        function world:projectile() end
        function world:removeProjectile() end
        function world:placeActor(id,point) self.positions[id]=table.clone(point);return true end
        function world:relocate(id,point)
            if not self:isSafe(point,id) then return false end
            self.relocations+=1;self.positions[id]=table.clone(point);return true
        end
        function world:advanceGeometry(definition)
            f.geometryCalls+=1;activeRoute=definition
            for id in pairs(self.actors) do if id<0 then self.actors[id]=nil;self.positions[id]=nil end end
            self.campaignModes=nil;return true
        end
        function world:hazard(slot)
            -- A single observed physical loss after the due attack. Further
            -- attempts are safe; the test cannot manufacture repeated deaths.
            if f.hazards[slot] and f.controller.director.boss and f.controller.director.boss.defeated then
                f.hazards[slot]=nil;return 'EngineDeath'
            end
        end
        local config=GameConfig(Base,route)
        local deps={Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=config,
            Director=Director,CampaignDirector=CampaignDirector,CampaignDefinition=Definition,
            CampaignModes=Modes,CampaignBoss=Boss,CampaignEnemies=CampaignEnemies,
            SourceCombat=SourceCombat,BossQueue=BossQueue,
            clock=function() return f.now end,guid=function() return 'victory-replacement' end}
        local c=Controller.new(deps,world);f.controller=c
        local roster={}
        for slot=1,count do
            local player={UserId=100+slot,DisplayName='Owner '..slot,Name='Owner'..slot,Parent=true}
            f.players[slot]=player;c:join(player)
            c.ownerSlots[player.UserId]=slot;c.owners[slot]={userId=player.UserId,displayName=player.DisplayName,
                username=player.Name,template='Mr. Green'}
            roster[slot]={userId=slot,template='Mr. Green'}
        end
        c.current=Session.new(Core,Combat,config,roster,'victory-'..index..'-'..count,world,nil,{levelId=route.id})
        f.session=c.current;assert(f.session:step(0)=='OK')
        c.campaignIndex=index;c.campaignSeed=51;c.baseSessionHooks={}
        local originalHit=f.session._hit
        f.session._hit=function(session,attacker,target,action,tuning)
            if target<0 then return c.director:hit(attacker,target,action,tuning) end
            return originalHit(session,attacker,target,action,tuning)
        end
        c:_createDirector(0);f.director=c.director;f.bossSlot=c.bossSlot
        local kind=route.boss.kind
        assert(c.bossQueue:select(90,kind,0)=='OK')
        local offer=c.bossQueue:view(90,0)
        assert(c.bossQueue:reply(90,offer.offerId,true,0)=='OK')
        assert(c.bossQueue:connect(90,offer.offerId,0)=='OK')
        -- Explicit earned-course preparation keeps all traversal challenges
        -- outside this final-contact regression. Finish the actual rival too.
        if f.director.modes.race then
            f.director.modes.race.bombIndex=4;f.director.modes.race:_beginRound('BombDefused')
        end
        for slot=1,count do f.director.modes.actors[slot].finished=true end
        f.director.modes.complete=true
        f.now=.1;f.director:step(f.now,.1)
        assert(f.director.boss and f.director.boss.state~='Chase')
        assert(c.bossQueue.slots[f.bossSlot].state=='Human')
        -- Prepared final boss vulnerability; defeat still requires an actual
        -- accepted Session attack, its due effect and CampaignBoss byte damage.
        local enemy=f.director.boss.enemies[-99];enemy.rawLife=1
        if enemy.progress then enemy.progress=240 end
        for slot=1,count do
            world.positions[slot]={x=route.boss.position.x-4,y=route.boss.position.y,z=route.boss.position.z}
            world.targetsFor[slot]={-99}
        end
        return f
    end
    local function tick(f,delta)
        f.now+=delta
        local ok,err=pcall(function() f.controller:step(f.now,delta) end)
        assert(ok,'victory must wait for Session survivor eligibility before closing a director or replacing geometry: '..tostring(err))
    end
    local function attack(f)
        local s=f.session;local hero=s.state.heroes[1]
        assert(s:intent(1,{kind='Attack',attack='Punch',runId=s.state.runId,actorId=hero.actorId,attempt=hero.attempt,
            levelEpoch=s.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=1},f.now)=='OK')
        assert(s.combat[1].attack and not f.director.boss.defeated)
    end
    local function awaiting(f)
        assert(f.controller.current==f.session and f.controller.director==f.director and not f.director.closed
            and f.geometryCalls==0 and not f.controller.finished and f.controller.campaignIndex==f.index,
            'a victory with only retrying or dying bodies must preserve its current stage')
        assert(f.controller.bossQueue.slots[f.bossSlot].state=='Human','pending victory must retain its actual boss assignment')
        local snapshot=f.controller:snapshot(f.players[1],f.players)
        assert(snapshot.status=='Active' and not snapshot.canStart and not snapshot.campaign.complete,
            'pending victory must keep the campaign active and unavailable for replacement')
        assert(f.controller:handle(f.players[1],{kind='Start'},f.players)=='RUN_ACTIVE')
    end
    local function resumed(f,before)
        if f.index<13 then
            assert(f.geometryCalls==1 and f.director.closed and f.controller.director~=f.director
                and f.controller.campaignIndex==f.index+1 and f.session.state.levelEpoch==2 and not f.controller.finished)
        else
            assert(f.geometryCalls==0 and f.controller.finished and f.controller.director.result=='Won'
                and f.session.state.levelEpoch==1)
        end
        for slot=1,f.count do
            local hero=f.session.state.heroes[slot]
            assert(hero.status=='Alive' and hero.attempt==before[slot].attempt+1 and hero.respawns==before[slot].respawns-1
                and hero.actorId~=before[slot].actorId,'only a committed paid spawn can resolve pending victory')
        end
        assert(f.controller.bossQueue.slots[f.bossSlot].state=='Closed')
        local index=f.controller.campaignIndex;tick(f,.1)
        assert(f.controller.campaignIndex==index and f.geometryCalls==(f.index<13 and 1 or 0),'victory advances exactly once')
    end
    local function finalLoss(f)
        assert(f.session.state.status=='Lost' and f.controller.finished and f.controller.director.result=='Lost'
            and f.world.stageName=='Lost' and f.geometryCalls==0 and f.session.state.levelEpoch==1,
            'Session terminal loss must prevail after boss defeat without advancing or healing')
        assert(f.controller.bossQueue.slots[f.bossSlot].state=='Closed')
        tick(f,.1);assert(f.geometryCalls==0 and f.controller.director.result=='Lost')
    end
    local function stock(f)
        local rows={};for slot=1,f.count do rows[slot]=table.clone(f.session.state.heroes[slot]) end;return rows
    end
    local checks=0
    for _,index in ipairs({5,8,10,11,13}) do for count=1,3 do
        local f=fixture(index,count);local before=stock(f)
        attack(f);for slot=1,count do f.hazards[slot]=true end
        tick(f,.15);assert(f.director.boss.defeated);awaiting(f)
        for slot=1,count do local hero=f.session.state.heroes[slot]
            assert(hero.status=='AwaitingRespawn' and hero.actorId==nil and hero.attempt==before[slot].attempt
                and hero.respawns==before[slot].respawns and f.session.combat[slot].rawLife==0)
        end
        -- A failed native spawn must neither spend stock nor tear down the won stage.
        f.world.spawnFails=true;tick(f,.1);awaiting(f)
        for slot=1,count do assert(f.session.state.heroes[slot].respawns==before[slot].respawns) end
        f.world.spawnFails=false;tick(f,.6);resumed(f,before);checks+=1
    end end
    print('PASS pending victory waits for real paid retries across five boss stages and solo/duo/trio')

    for _,index in ipairs({8,13}) do
        local f=fixture(index,1);local before=stock(f);attack(f);f.hazards[1]=true;tick(f,.15);awaiting(f)
        f.controller:leave(f.players[1]);assert(not f.session.state.heroes[1].connected,
            'the owner of a pending retry must still be able to disconnect after boss defeat')
        tick(f,1)
        assert(f.session.state.heroes[1].status=='AwaitingRespawn' and f.session.state.heroes[1].respawns==before[1].respawns
            and f.geometryCalls==0 and not f.controller.finished)
        -- A real reconnect supplies a new Player instance. The registry
        -- deliberately tombstones departed instances against stale events.
        f.players[1]=table.clone(f.players[1]);f.controller:join(f.players[1])
        assert(f.session.state.heroes[1].connected,
            'rejoining must reconnect the existing retry obligation after boss defeat')
        tick(f,.1);resumed(f,before);checks+=1
    end
    print('PASS offline pending victory remains reconnectable and cannot replace the run, including final stage')

    for _,index in ipairs({8,13}) do for _,terminal in ipairs({false,true}) do
        local f=fixture(index,1)
        if terminal then
            for _=1,3 do
                f.session:_die(1,'PreparedStockUse');f.now+=.01;assert(f.session:step(f.now)=='OK')
                f.director.modes:_syncActors()
            end
            assert(f.session.state.heroes[1].respawns==0 and f.session.state.heroes[1].attempt==4)
            local bossPosition=f.director.definition.boss.position
            f.world.positions[1]={x=bossPosition.x-4,y=bossPosition.y,z=bossPosition.z}
        end
        local before=stock(f);attack(f)
        -- Resolve the hero's actual due finisher first, then an accepted lethal
        -- ordinary hit in the same frame, as an existing projectile can do.
        f.now+=.15;assert(f.session:step(f.now)=='OK')
        assert(f.director.boss.defeated,'prepared final contact must resolve before testing pending lethal damage')
        f.session.combat[1].rawLife=0;assert(f.session:_event('SetHealth',1,{health=0})=='OK')
        assert(f.session:_hit(-1,1,'WalkerHeavy',f.controller.deps.Config.Attacks.WalkerHeavy))
        local deadline=f.session.combat[1].deathAt;assert(deadline and deadline>f.now)
        f.director:step(f.now,.15)
        tick(f,.01);awaiting(f)
        assert(f.session.state.heroes[1].status=='Alive' and f.session.combat[1].deathAt==deadline
            and f.session.combat[1].rawLife==0 and f.session.state.heroes[1].respawns==before[1].respawns,
            'victory cannot clear an accepted lethal deadline, heal the dying body or spend its next stock early')
        tick(f,deadline-f.now)
        if terminal then finalLoss(f)
        else
            awaiting(f);assert(f.session.state.heroes[1].status=='AwaitingRespawn' and f.session.state.heroes[1].actorId==nil)
            tick(f,.1);resumed(f,before)
        end
        checks+=1
    end end
    print('PASS accepted lethal deadlines commit before retry; terminal Session loss prevails after boss defeat')
    return checks
end
