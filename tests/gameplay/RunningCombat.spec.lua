return function(Source,Director,Session,Core,Combat,GameConfig,Base,Level,FakeWorld)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function fixture(legacy,kind)
        local cfg=legacy and Base or GameConfig(Base,Level)
        if not legacy then
            cfg.Level={zones={{enemies={{id=-1,kind=kind or 'Walker',x=0,y=3,z=0,rawLife=31}},exit={}}}}
        end
        local w=FakeWorld.new();w.positions={[1]={x=4,y=3,z=0},[2]={x=20,y=3,z=0}};w.pursuits={}
        function w:spawnEnemy(id,species,p) self.actors[id]={id=id,kind=species,alive=true};self.positions[id]=table.clone(p);return true end
        function w:position(id) return self.positions[id] end
        function w:enemyIdentity() end
        function w:stage() end
        function w:progress() end
        function w:reached() return false end
        function w:face() end
        function w:enemyHealth() end
        function w:cue() end
        function w:enemyMove(id,target,speed) self.pursuits[id]={target=target,speed=speed} end
        function w:enemyRetreat() end
        local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'running',w)
        s:step(0)
        local d=not legacy and Director.new(s,w,Combat,cfg)
        if d then
            Source.bind(s,d,cfg);s.contextualAttack=function(slot,now,action) return d:interact(slot,now,action) end
            local hit=s._hit
            s._hit=function(self,a,t,action,tuning) if t<0 then return d:hit(a,t,action,tuning) end;return hit(self,a,t,action,tuning) end
        end
        local seq=0
        local function packet(kind,fields,slot)
            slot=slot or 1;seq+=1;local h=s.state.heroes[slot]
            local p={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
                levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq}
            for k,v in pairs(fields or {}) do p[k]=v end
            return p
        end
        local function tick(now) if d then d.now=now end;s:step(now);if d then d:step(now,.05) end end
        return s,w,d,packet,tick,cfg
    end
    test('Move permits only an optional boolean run and retains strict action authority',function()
        local s,w,d,p=fixture()
        assert(s:intent(1,p('Move',{x=1,z=0,run=true}),.1)=='OK','A bounded run request must use the ordinary Move schema')
        assert(w.lastMove[4]==true)
        assert(s:intent(1,p('Move',{x=1,z=0,run=false}),.2)=='OK' and w.lastMove[4]==false)
        for _,fields in ipairs({{x=1,z=0,run=1},{x=1,z=0,run='true'},{x=1,z=0,run=true,speed=100},
            {x=1,z=0,run=true,profile=21}}) do assert(s:intent(1,p('Move',fields),.3)=='INVALID_INTENT') end
        assert(s:intent(1,p('Attack',{attack='Punch',run=true}),.3)=='INVALID_INTENT')
        assert(s:intent(1,p('Jump',{run=true}),.3)=='INVALID_INTENT')
        assert(s:intent(1,p('Attack',{attack='EnemyRunStrike'}),.3)=='INVALID_INTENT')
    end)
    test('stale actor connection and sequence cannot start or stop another accepted run',function()
        local s,w,d,p=fixture();local stale=p('Move',{x=1,z=0,run=true});stale.actorId='old-body'
        local moves=w.moves;assert(s:intent(1,stale,.1)=='STALE_ACTOR' and w.moves==moves)
        stale=p('Move',{x=1,z=0,run=true});stale.connectionEpoch+=1
        assert(s:intent(1,stale,.1)=='STALE_CONNECTION' and w.moves==moves)
        local accepted=p('Move',{x=1,z=0,run=true});assert(s:intent(1,accepted,.2)=='OK')
        accepted.run=false;assert(s:intent(1,accepted,.3)=='STALE_SEQUENCE' and w.lastMove[4]==true)
    end)
    test('stationary requested run and knockback alone cannot promote primary or standing R',function()
        local s,w,d,p=fixture();w.targetsFor[1]={-1}
        assert(s:intent(1,p('Move',{x=1,z=0,run=true}),.1)=='OK')
        assert(s:intent(1,p('Attack',{attack='Dash'}),.2)=='NOT_RUNNING' and not s.combat[1].attack)
        assert(s:intent(1,p('Attack',{attack='Punch'}),.3)=='OK' and s.combat[1].attack.action=='HeroJab')
        local s2,w2,d2,p2=fixture();w2.observedKnockbackSpeed=32
        assert(s2:intent(1,p2('Attack',{attack='Dash'}),.1)=='NOT_RUNNING')
    end)
    test('actual running primary bypasses opportunistic interactions and freezes Dash before stopping',function()
        local s,w,d,p,tick=fixture();w.targetsFor[1]={-1};w.actualRuns[1]=true
        local opportunities=0;s.contextualAttack=function() opportunities+=1;return 'OK' end
        assert(s:intent(1,p('Attack',{attack='Punch'}),.1)=='OK')
        local a=s.combat[1].attack
        assert(a and a.action=='Dash' and a.inputAction=='Punch' and a.tuning.reach==8 and opportunities==0)
        assert(not w:isRunning(1),'Accepted strike must stop the run intent')
        assert(s:intent(1,p('Move',{x=0,z=0,run=false}),.11)=='OK')
        s.config.Attacks=table.clone(s.config.Attacks);s.config.Attacks.Dash=table.clone(s.config.Attacks.Dash)
        s.config.Attacks.Dash.reach=1;tick(a.at)
        assert(d.enemies[-1].rawLife==15 and w.lastProfile==4 and s.combat[1].attack==nil)
    end)
    test('running hero still selects Boot against a heavy target and Dash finisher at actual low Life',function()
        local s,w,d,p=fixture();w.targetsFor[1]={-1};w.actualRuns[1]=true
        d.enemies[-1].reactionUntil=2;d.enemies[-1].heavyReaction=true
        assert(s:intent(1,p('Attack',{attack='Punch'}),.1)=='OK' and s.combat[1].attack.action=='HeroBoot')
        local s2,w2,d2,p2,tick2=fixture();w2.actualRuns[1]=true;w2.targetsFor[1]={2};s2.combat[2].rawLife=15
        assert(s2:intent(1,p2('Attack',{attack='Punch'}),.1)=='OK');tick2(s2.combat[1].attack.at)
        assert(w2.lastProfile==21 and s2.combat[2].deathAt,'Only hero Dash retains the existing source finisher')
    end)
    test('mandatory Pig and guardian held actions retain priority even when physical run is reported',function()
        for _,kind in ipairs({'Pig','Guardian','Dragon'}) do
            local s,w,d,p=fixture();w.actualRuns[1]=true
            if kind=='Pig' then d.carry={interaction=function()return {carrying=true}end}
            elseif kind=='Guardian' then d.stage='Boss';d.guardian={interaction=function()return {carrying=true}end}
            else d.dragons={heroes={[1]={mode='Mounted'}}} end
            s.contextualAttack=function() return 'HELD_ACTION' end
            assert(s:intent(1,p('Attack',{attack='Punch'}),.1)=='HELD_ACTION' and not s.combat[1].attack,kind)
        end
    end)
    test('standing ordinary primary retains opportunistic interaction priority',function()
        local s,w,d,p=fixture();s.contextualAttack=function()return 'OK'end
        assert(s:intent(1,p('Attack',{attack='Punch'}),.1)=='OK' and not s.combat[1].attack)
    end)
    test('held guardian movement strips the client run request before it reaches physical control',function()
        local s,w,d,p=fixture();d.guardian={interaction=function()return {carrying=true}end};w.actualRuns[1]=true
        assert(s:intent(1,p('Move',{x=1,z=0,run=true}),.1)=='OK')
        assert(w.lastMove[4]==false and not w:isRunning(1))
    end)
    test('legacy stand keeps standing Dash and ignores the main-game running shortcut guard',function()
        local s,w,d,p=fixture(true);assert(s:intent(1,p('Attack',{attack='Dash'}),.1)=='OK')
        assert(s.combat[1].attack.action=='Dash' and not Base.Movement)
    end)
    test('incoming impulse timeout disconnect and new appearance clear accepted run state',function()
        local s,w,d,p,tick=fixture();w.actualRuns[1]=true;assert(s:_hit(2,1,'HeroJab'))
        assert(not w:isRunning(1) and w.lastReset[2]==w.actors[1])
        local s2,w2,d2,p2,tick2=fixture();assert(s2:intent(1,p2('Move',{x=1,z=0,run=true}),.1)=='OK');w2.actualRuns[1]=true
        tick2(.5);assert(not w2:isRunning(1))
        w2.actualRuns[1]=true;assert(s2:connection(1,false,.6)=='OK' and not w2:isRunning(1))
        w2.actualRuns[1]=true;s2:_die(1,'test');assert(not w2:isRunning(1))
        assert(s2:connection(1,true,.7)=='OK');tick2(.8);assert(not w2:isRunning(1) and s2.state.heroes[1].attempt==2)
    end)
    test('actual impact increments the reset signal while an emergency shield does not',function()
        local s,w,d,p=fixture();assert(s:_hit(2,1,'HeroJab'))
        assert(s:snapshot().heroes[1].reactionEpoch==1)
        w.hazards[2]='Fall';s:step(.1);w.safe=false;s:step(.2)
        local before=s.combat[2].reactionEpoch or 0;assert(s:_hit(1,2,'HeroJab'))
        assert(s:snapshot().heroes[2].reactionEpoch==before)
    end)
    local function enemyPacket(s,e,seq,kind,fields)
        local p={kind=kind,runId=s.state.runId,actorId=e.actorId,attempt=1,levelEpoch=1,connectionEpoch=e.connectionEpoch,seq=seq}
        for k,v in pairs(fields or {}) do p[k]=v end;return p
    end
    test('human ground enemy forwards bounded run and accepts one fixed-profile running strike',function()
        for _,species in ipairs({'Walker','Pig'}) do
            local s,w,d,p,tick=fixture(false,species);assert(d:claim(71,-1)=='OK');local e=d.enemies[-1]
            assert(d:command(71,enemyPacket(s,e,1,'Move',{x=1,z=0,run=true}),.1,Session.validIntent)=='OK' and w.lastMove[4]==true)
            w.actualRuns[-1]=true;w.targetsFor[-1]={1};s.combat[1].rawLife=15
            assert(d:command(71,enemyPacket(s,e,2,'Attack',{attack='Punch'}),.2,Session.validIntent)=='OK')
            assert(e.windup.action=='EnemyRunStrike' and not w:isRunning(-1))
            tick(e.windup.at);assert(w.lastProfile==22 and s.combat[1].deathAt and s.combat[1].rawLife==0)
            assert(e.actorId==d:controlled(71).actorId and d:controlled(71).attempt==1 and e.ownerUserId==71)
        end
    end)
    test('enemy running profile never inherits a hero finisher and preserves exact zero arithmetic',function()
        for _,raw in ipairs({0,3,15,16,31,47}) do
            local h=Combat.hit(raw,'EnemyRunStrike');local e=Combat.hitEnemy(raw,'EnemyRunStrike')
            assert(h.profile==22 and h.rawDamage==16 and e.profile==4 and e.rawDamage==16)
        end
        assert(not Combat.hitEnemy(16,'EnemyRunStrike').dying and Combat.hitEnemy(16,'EnemyRunStrike').rawLife==15)
    end)
    test('Walker NPC run approach latches until actual running attack and resets on claim or impact',function()
        local s,w,d,p,tick=fixture();w.positions[1].x=20;w.positions[2].x=40;tick(.1)
        assert(w.pursuits[-1].speed==16 and d.enemies[-1].runApproach)
        w.positions[1].x=10;tick(.2);assert(w.pursuits[-1].speed==16)
        w.actualRuns[-1]=true;w.positions[1].x=6;tick(.3)
        assert(d.enemies[-1].windup.action=='EnemyRunStrike' and not d.enemies[-1].runApproach)
        local s2,w2,d2,p2,tick2=fixture();w2.positions[1].x=20;tick2(.1);w2.actualRuns[-1]=true
        assert(d2:claim(71,-1)=='OK' and not w2:isRunning(-1) and not d2.enemies[-1].runApproach)
        local s3,w3,d3,p3,tick3=fixture();w3.positions[1].x=20;tick3(.1);w3.actualRuns[-1]=true
        assert(d3:hit(1,-1,'HeroJab') and not w3:isRunning(-1) and not d3.enemies[-1].runApproach)
    end)
    test('requested NPC source rush cannot make a wall-pushing mega and qualified Pig keeps its source action',function()
        local s,w,d=fixture(false,'Pig');local e=d.enemies[-1];e.rushing=true
        d:_beginStrike(-1,e,1);assert(e.windup.action=='PigJab')
        e.windup=nil;e.rushing=true;w.actualRuns[-1]=true;d:_beginStrike(-1,e,1)
        assert(e.windup.action=='PigRush')
        local s2,w2,d2=fixture(false,'Dragon');w2.actualRuns[-1]=true;d2:_beginStrike(-1,d2.enemies[-1],1)
        assert(d2.enemies[-1].windup.action=='DragonHeadbutt')
    end)
    test('running Walker approaches through6.25 before committing its6-stud strike against a stationary hero',function()
        local s,w,d,p,tick=fixture();w.positions[1].x=20;w.positions[2].x=40;tick(.1)
        w.actualRuns[-1]=true;w.positions[1].x=6.25
        function w:targets(id,profile)
            local a,b=self.positions[id],self.positions[1]
            return b.x>=a.x and b.x-a.x<=profile.reach and {1} or {}
        end
        tick(.2)
        assert(not d.enemies[-1].windup and d.enemies[-1].runApproach and w.pursuits[-1].speed==16,
            'A running Walker outside its actual hit reach must keep approaching instead of accepting a guaranteed miss')
        assert(s.combat[1].rawLife==47)
        w.positions[1].x=5.9;tick(.3)
        local pending=d.enemies[-1].windup
        assert(pending and pending.action=='EnemyRunStrike' and pending.tuning.reach==6 and not w:isRunning(-1))
        tick(pending.at)
        assert(s.combat[1].rawLife==31 and w.lastProfile==22,'The accepted stationary target must be reachable at actual effect')
    end)
    test('enemy disconnect and death clear run and publish reaction reset without a new body',function()
        local s,w,d=fixture();assert(d:claim(71,-1)=='OK');local body=w.actors[-1];w.actualRuns[-1]=true
        assert(d:connection(71,false)=='OK' and not w:isRunning(-1) and w.actors[-1]==body)
        assert(d:hit(1,-1,'HeroJab') and d:controlled(71).reactionEpoch==1)
        w.actualRuns[-1]=true;d:_kill(-1,'Combat');assert(not w:isRunning(-1) and w.actors[-1]==body)
    end)
    test('accepted running strikes finish after disconnect without resuming locomotion or changing their action',function()
        local s,w,d,p,tick=fixture();w.actualRuns[1]=true;w.targetsFor[1]={-1}
        assert(s:intent(1,p('Attack',{attack='Punch'}),.1)=='OK');local a=s.combat[1].attack
        assert(s:connection(1,false,.11)=='OK');tick(a.at)
        assert(d.enemies[-1].rawLife==15 and not w:isRunning(1) and a.action=='Dash')
        local s2,w2,d2,p2,tick2=fixture();assert(d2:claim(71,-1)=='OK');local e=d2.enemies[-1]
        w2.actualRuns[-1]=true;w2.targetsFor[-1]={1}
        assert(d2:command(71,enemyPacket(s2,e,1,'Attack',{attack='Punch'}),.1,Session.validIntent)=='OK')
        local pending=e.windup;assert(d2:connection(71,false)=='OK');tick2(pending.at)
        assert(pending.action=='EnemyRunStrike' and s2.combat[1].rawLife==31 and not w2:isRunning(-1)
            and not e.windup and e.ownerUserId==71 and not e.connected)
    end)
    assert(failed==0,tostring(failed)..' running combat cases failed')
    print('RunningCombat: '..passed..' PASS')
end
