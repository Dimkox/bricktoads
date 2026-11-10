return function(Presentation,Animation,Director,Combat,Config,Session,Core,FakeWorld,SourceCombat)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function eq(a,b)assert(a==b,tostring(a)..' vs '..tostring(b))end
    local function fixture(raw,action)
        action=action or'Dash'
        local body={Parent=true,GetAttribute=function(_,name)if name=='ActorId'then return'hero' end end}
        local actor={model=body};local hero={actorId='hero',status='Alive'}
        local events={};local session={state={runId='run',levelEpoch=2,heroes={[1]=hero}}}
        function session:_record(kind,slot,data)events[#events+1]={kind=kind,slot=slot,data=data}end
        local world={actors={[1]=actor},kills=0}
        function world:enemyHealth()end
        function world:cue()end
        function world:position()return{x=0,y=3,z=0}end
        function world:kill()self.kills+=1 end
        function world:move()end
        function world:setReaction()end
        function world:resetLocomotion()end
        function world:impulse()end
        local enemy={rawLife=raw or 15,maxRawLife=47,health=3,kind='Pig',actorId='enemy'}
        local director=setmetatable({session=session,world=world,Combat=Combat,config=Config,
            enemies={[-1]=enemy},projectiles={},now=.2},{__index=Director})
        local tuning=Combat.captureAttack(Config,action,Config.Attacks[action])
        local accepted={action=action,actorId='hero',at=tuning.windup,tuning=tuning,order=1}
        local context={enabled=true,actorId='hero',body=body,levelEpoch=2,now=0,dt=0,
            grounded=true,mode='Idle',speed=0,reactionEpoch=0,attack=accepted}
        return director,actor,enemy,context,events,world
    end
    local function result(c,at)
        return{branch='DashLowLifeTail',profile=3,tuning=c.attack.tuning,actorId=c.actorId,
            body=c.body,levelEpoch=c.levelEpoch,at=at or .2}
    end
    test('actual ordinary profile3 effect produces a same-body accepted-tuning result and visible Dash tail',function()
        local d,actor,enemy,c,events,w=fixture()
        local state=Presentation.new();eq(Presentation.sample(state,c).frameId,0x23)
        local accepted=c.attack
        assert(d:hit(1,-1,'Dash',accepted.tuning))
        local outcome=assert(actor.dashPresentationResult,'Confirmed profile3 must publish its cosmetic result')
        eq(outcome.tuning,accepted.tuning);eq(outcome.body,actor.model);eq(outcome.actorId,'hero')
        eq(outcome.levelEpoch,2);eq(outcome.at,.2);eq(outcome.profile,3);eq(outcome.branch,'DashLowLifeTail')
        eq(enemy.rawLife,0);assert(enemy.dead);eq(w.kills,1)
        local hits=0;for _,e in ipairs(events)do if e.kind=='EnemyHit'then hits+=1;eq(e.data.profile,3)end end
        eq(hits,1);eq(accepted.action,'Dash')
        c.now=.2;c.attack=nil;c.recoveryAction='Dash';c.recoveryUntil=.37;c.dashResult=outcome
        local p=assert(Presentation.sample(state,c))
        eq(p.frameId,0x31);eq(p.action,'Dash');eq(p.sourceBranch,'DashLowLifeTail');eq(p.sourceCall,0)
        eq(p.morphKind,nil)
    end)
    test('real Session acceptance and effect emit no early result then drive the same resolved presentation sequence',function()
        local w=FakeWorld.new();w.positions={}
        function w:spawnEnemy(id,kind,p)self.actors[id]={id=id,kind=kind};self.positions[id]=p;return true end
        function w:enemyIdentity()end
        function w:position(id)return self.positions[id]or{x=0,y=3,z=0}end
        function w:stage()end
        function w:progress()end
        function w:enemyHealth()end
        function w:cue()end
        local cfg=table.clone(Config)
        cfg.Level={zones={{enemies={{id=-1,kind='Pig',x=5,y=3,z=0,rawLife=15}},exit={}}}}
        local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'dash-sequence',w)
        s:step(0)
        local d=Director.new(s,w,Combat,cfg);SourceCombat.bind(s,d,cfg)
        local originalHit=s._hit
        s._hit=function(self,a,target,action,tuning)
            if target<0 then return d:hit(a,target,action,tuning)end
            return originalHit(self,a,target,action,tuning)
        end
        local hero=s.state.heroes[1]
        local body={Parent=true,GetAttribute=function(_,name)if name=='ActorId'then return hero.actorId end end}
        w.actors[1].model=body;w.targetsFor[1]={-1};w.actualRuns[1]=true
        eq(s:intent(1,{kind='Attack',attack='Punch',runId=s.state.runId,actorId=hero.actorId,
            attempt=hero.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=1},.1),'OK')
        local accepted=assert(s.combat[1].attack);eq(accepted.action,'Dash')
        local state=Presentation.new()
        local c={enabled=true,actorId=hero.actorId,body=body,levelEpoch=s.state.levelEpoch,now=.1,dt=0,
            grounded=true,mode='Idle',speed=0,reactionEpoch=0,attack=accepted}
        eq(Presentation.sample(state,c).frameId,0x23)
        d.now=.2;s:step(.2);eq(w.actors[1].dashPresentationResult,nil)
        d.now=.3;s:step(.3)
        local combat=s.combat[1];eq(combat.attack,nil)
        c.now=.3;c.attack=combat.attack;c.recoveryAction=combat.lastStrikeAction
        c.recoveryUntil=combat.strikeRecoveryUntil;c.dashResult=w.actors[1].dashPresentationResult
        eq(c.dashResult.tuning,accepted.tuning);eq(c.dashResult.at,.3)
        eq(Presentation.sample(state,c).frameId,0x31)
        eq(s.state.heroes[1].actorId,hero.actorId);eq(d.enemies[-1].rawLife,0)
    end)
    test('producer ignores normal Dash damage, different actions, missing tuning and absent or stale hero bodies',function()
        for _,why in ipairs({'NormalProfile','OtherAction','NoTuning','NoHero','NoBody','StaleBody','InactiveHero'})do
            local d,actor,_,c=fixture(why=='NormalProfile' and 31 or 15,why=='OtherAction'and'HeroBoot'or'Dash')
            local tuning=c.attack.tuning
            if why=='NoTuning'then tuning=nil
            elseif why=='NoHero'then d.session.state.heroes[1]=nil
            elseif why=='NoBody'then d.world.actors[1]=nil
            elseif why=='StaleBody'then actor.model={GetAttribute=function()return'oldHero'end}
            elseif why=='InactiveHero'then d.session.state.heroes[1].status='Eliminated'end
            assert(d:hit(1,-1,c.attack.action,tuning),why)
            eq(actor.dashPresentationResult,nil)
        end
        local d,actor,_,c=fixture();d.enemies[-1].dead=true
        eq(d:hit(1,-1,'Dash',c.attack.tuning),false);eq(actor.dashPresentationResult,nil)
    end)
    test('a confirmed result selects the pinned same-call read and preserves both source caller phases',function()
        for _,effectCall in ipairs({11,12})do
            local _,_,_,c=fixture();local state=Presentation.new();Presentation.sample(state,c)
            local at=effectCall/60;c.dashResult=result(c,at)
            for call=0,32 do
                c.now=at+call/60
                local expected=assert(Animation.sampleClock(0x16,{elapsedCalls=call,callerMask=1,
                    firstFrameCounterPhase=effectCall%2,firstRead='Read',branch='DashLowLifeTail'}))
                local actual=assert(Presentation.sample(state,c))
                if expected.ended then eq(actual.kind,'Idle');break end
                eq(actual.frameId,expected.frameId);eq(actual.sourceCall,call);eq(actual.sourcePhase,effectCall%2)
            end
        end
    end)
    test('tail selection rejects normal profiles and every mismatched or invalid accepted-result scope',function()
        for _,why in ipairs({'Profile','Branch','Tuning','Body','Actor','Epoch','Future','BeforeAcceptance','Nonfinite','NoBody','NoEpoch'})do
            local _,_,_,c=fixture();local state=Presentation.new();Presentation.sample(state,c)
            local r=result(c)
            if why=='Profile'then r.profile=4 elseif why=='Branch'then r.branch='Normal'
            elseif why=='Tuning'then r.tuning=table.clone(r.tuning) elseif why=='Body'then r.body={}
            elseif why=='Actor'then r.actorId='oldHero' elseif why=='Epoch'then r.levelEpoch=1
            elseif why=='Future'then r.at=.3 elseif why=='BeforeAcceptance'then r.at=-.1
            elseif why=='Nonfinite'then r.at=0/0 elseif why=='NoBody'then c.body=nil
            elseif why=='NoEpoch'then c.levelEpoch=nil end
            c.now=.2;c.dashResult=r
            local p=assert(Presentation.sample(state,c));eq(p.frameId,0x23);assert(p.sourceBranch~='DashLowLifeTail',why)
        end
    end)
    test('duplicate result observations cannot restart the tail or replay command markers',function()
        local _,_,_,c=fixture();local state=Presentation.new();Presentation.sample(state,c)
        c.dashResult=result(c);c.now=.2;eq(Presentation.sample(state,c).sourceCall,0)
        c.now=.3;local a=assert(Presentation.sample(state,c));eq(a.sourceCall,6)
        c.dashResult=table.clone(c.dashResult)
        local b=assert(Presentation.sample(state,c));eq(b.sourceCall,6);eq(#b.events,0)
        c.now=.8;eq(Presentation.sample(state,c).kind,'Idle')
        c.now=.9;eq(Presentation.sample(state,c).kind,'Idle')
    end)
    test('new accepted attack, actor body or level epoch cannot inherit an earlier confirmed result',function()
        for _,why in ipairs({'Attack','Actor','Body','Epoch'})do
            local _,_,_,c=fixture();local state=Presentation.new();Presentation.sample(state,c)
            c.dashResult=result(c);c.now=.2;eq(Presentation.sample(state,c).frameId,0x31)
            local nextAttack=table.clone(c.attack);nextAttack.tuning=table.clone(c.attack.tuning);nextAttack.at=.4
            nextAttack.tuning.windup=.1;c.attack=nextAttack;c.now=.3
            if why=='Actor'then c.actorId='newHero';nextAttack.actorId=c.actorId
            elseif why=='Body'then c.body={}
            elseif why=='Epoch'then c.levelEpoch=3 end
            local p=assert(Presentation.sample(state,c));eq(p.frameId,0x23);assert(p.sourceBranch~='DashLowLifeTail')
        end
    end)
    test('priority interruption cancels the pending result and cannot resume it after recovery',function()
        for _,why in ipairs({'Reaction','Air','Paused'})do
            local _,_,_,c=fixture();local state=Presentation.new();Presentation.sample(state,c)
            c.dashResult=result(c);c.now=.2
            if why=='Paused'then c.blocked='Paused'else c.visualState=why;c.verticalSpeed=3 end
            Presentation.sample(state,c)
            c.now=.3;c.blocked=nil;c.visualState=nil;c.attack=nil;c.recoveryAction='Dash';c.recoveryUntil=.5
            eq(Presentation.sample(state,c).kind,'Idle')
        end
    end)
    print(string.format('Dash presentation: %d passed, %d failed',passed,failed))
    assert(failed==0,'Dash presentation contracts failed')
end
