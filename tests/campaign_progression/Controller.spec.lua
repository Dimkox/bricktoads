return function(Controller,Core,Combat,Session,Registry,Config,FakeWorld,BossQueue)
    local world=FakeWorld.new();world.names={};world.definitions={}
    function world:clearActors() self.actors={} end
    function world:advanceGeometry(definition) self.definitions[#self.definitions+1]=definition;return true end
    function world:cue() end
    local index=0;local clock=1
    local directors={}
    local function make(session)
        index+=1
        local installed=index;local previous=session.beforeHitImpulse
        session.beforeHitImpulse=function(slot)
            session.hookCalls=(session.hookCalls or 0)+1
            session.hookDirector=installed
            if previous then previous(slot) end
        end
        local d={index=index,enemies={},step=function() end,hit=function(self) self.hits=(self.hits or 0)+1;return true end,
            snapshot=function(self) return {stage=self.result or 'Course'} end,
            controlled=function() return nil end,available=function() return {} end,
            closeTargetForAttack=function() end,close=function(self) self.closed=true end}
        directors[#directors+1]=d;return d
    end
    local definitions={count=13,build=function(level,seed)
        assert(type(seed)=='number' and seed>=1 and seed<2147483647,'Campaign layout requires a stable numeric seed')
        local kind=({[5]='BigBlag',[8]='RoboManus',[10]='GeneralSlaughter',[11]='Buzzball',[13]='DarkQueen'})[level]
        return {id='level-'..level,name='Course '..level,campaignIndex=level,seed=seed,boss=kind and {kind=kind} or nil}
    end}
    local c=Controller.new({Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=Config,
        Director={new=make},CampaignDirector={new=make},CampaignDefinition=definitions,BossQueue=BossQueue,
        clock=function() return clock end,guid=function() return 'same-run' end},world)
    local player={UserId=20,DisplayName='Green owner',Name='GreenOwner',Parent=true}
    c:join(player);assert(c:handle(player,{kind='Start'},{player})=='OK')
    local actor=c.current.state.heroes[1].actorId
    c.current.combat[1].rawLife=15;c.current:_event('SetHealth',1,{health=2})
    for level=1,12 do
        local previousBoss=c.bossSlot
        c.director.result='Won'
        assert(c:handle(player,{kind='Start'},{player})=='RUN_ACTIVE','An intermediate win must not permit replacing the run')
        clock+=1;c:step(clock,.1)
        assert(c.campaignIndex==level+1 and c.current.state.levelEpoch==level+1 and not c.finished)
        assert(c.current.state.runId=='same-run' and c.current.state.heroes[1].actorId==actor)
        assert(c.current.state.heroes[1].attempt==1 and c.current.state.heroes[1].respawns==3)
        assert(c.current.combat[1].rawLife==47 and c.owners[1].userId==20)
        assert(directors[level].closed and world.definitions[level].campaignIndex==level+1)
        if previousBoss then assert(c.bossQueue.slots[previousBoss].state=='Closed') end
        local kind=world.definitions[level].boss and world.definitions[level].boss.kind
        if kind then assert(c.bossSlot and c.bossQueue.slots[c.bossSlot].bossId==kind)
        else assert(not c.bossSlot,'Nonboss stages cannot invite a fallback Guardian') end
        c.current.hookCalls=0;c.current.beforeHitImpulse(1)
        assert(c.current.hookCalls==1 and c.current.hookDirector==level+1,'Per-level hooks cannot retain closed directors')
        local oldHits=directors[level].hits
        c.current:_hit(1,-99,'Punch')
        assert(c.director.hits==1 and directors[level].hits==oldHits,'Negative targets must route to the current director')
    end
    c.director.result='Won';clock+=1;c:step(clock,.1)
    assert(c.finished and #world.definitions==12 and c:snapshot(player,{player}).status=='Won')
    print('PASS campaign advances all 13 modes in one fixed run and finalizes only the final victory')
    c.finished=false;c.director.result='Lost';clock+=1;c:step(clock,.1)
    assert(c.finished and #world.definitions==12)
    clock+=1;c:step(clock,.1);assert(#world.definitions==12,'Loss cannot retry or advance automatically')
    print('PASS a defeated campaign remains finished until an explicit new game')
end
