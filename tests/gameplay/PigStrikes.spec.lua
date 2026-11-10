return function(Director,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=4,y=3,z=0},[2]={x=7,y=3,z=0}}
        w.pursuits={};w.facing={};w.nextTargets={1}
        function w:spawnEnemy(id,kind,p) self.actors[id]={id=id,kind=kind,alive=true};self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity(id,identity) self.actors[id].identity=identity end
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress() end
        function w:reached() return false end
        function w:enemyHealth(id,value) self.actors[id].health=value end
        function w:cue() end
        function w:face(id,target) self.facing[id]=target end
        function w:targets(id,profile) self.lastHitbox=profile;return self.nextTargets end
        function w:enemyMove(id,target,speed) self.pursuits[id]={target=target,speed=speed} end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'pig-test',w)
        s:step(0)
        local cfg=table.clone(Config)
        cfg.Level={zones={{enemies={{id=-1,kind='Pig',x=0,y=3,z=0},{id=-2,kind='Walker',x=-30,y=3,z=0}},exit={}}}}
        local d=Director.new(s,w,Combat,cfg)
        -- Same private dispatch used by the production controller.
        local heroHit=s._hit
        s._hit=function(session,a,t,action) if t<0 then return d:hit(a,t,action) end;return heroHit(session,a,t,action) end
        local function tick(now) s:step(now);d:step(now,.1) end
        local seq=0
        local function command(now,attack)
            seq+=1
            local e=d.enemies[-1]
            return d:command(71,{kind='Attack',attack=attack or 'Punch',runId=s.state.runId,
                levelEpoch=s.state.levelEpoch,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,seq=seq},now,Session.validIntent)
        end
        return d,s,w,tick,command
    end
    test('a healthy selected hero receives the standing jab instead of the shared heavy attack',function()
        local d,s,w,tick=fixture();tick(.1)
        assert(d.enemies[-1].windup.action=='PigJab','Pig must choose its source standing attack')
        tick(.1+Config.Attacks.PigJab.windup)
        assert(s.combat[1].rawLife==43 and w.lastProfile==18 and not s.combat[1].heavyReactionEpoch)
        tick(s.combat[1].reactionEnd)
        assert(s.combat[1].rawLife==47,'The light reaction must use actual source recovery arithmetic')
    end)
    test('standing selection uses raw low nibble, including the exact3/4 boundary',function()
        for _,raw in ipairs({0,3,4,15,16,19,20,31,32,35,36,47}) do
            local d,s=fixture();s.combat[1].rawLife=raw;d:_beginStrike(-1,d.enemies[-1],1)
            assert(d.enemies[-1].windup.action==(raw%16<4 and 'PigHeavy' or 'PigJab'),tostring(raw))
        end
    end)
    test('a selected heavy action is immutable when healing changes raw Life during windup',function()
        local d,s,w,tick=fixture();s.combat[1].rawLife=35;d:_beginStrike(-1,d.enemies[-1],1)
        s.combat[1].rawLife=47;tick(Config.Attacks.PigHeavy.windup)
        assert(s.combat[1].rawLife==31 and w.lastProfile==20 and s.combat[1].heavyReactionEpoch==1)
        local hits=w.impulses;tick(d.now+.01);assert(w.impulses==hits)
    end)
    test('effect-time geometry can miss or hit another body without reselecting the action',function()
        local d,s,w,tick=fixture();s.combat[1].rawLife=3;d:_beginStrike(-1,d.enemies[-1],1)
        w.nextTargets={2};tick(Config.Attacks.PigHeavy.windup)
        assert(s.combat[1].rawLife==3 and s.combat[2].rawLife==31 and w.lastProfile==20)
        local d2,s2,w2,tick2=fixture();d2:_beginStrike(-1,d2.enemies[-1],1);w2.nextTargets={}
        tick2(Config.Attacks.PigJab.windup);assert(s2.combat[1].rawLife==47)
    end)
    test('a claimed Pig uses the same basic jab/heavy choice and keeps its body and one-life ledger',function()
        local d,s,w,tick,command=fixture();local body=w.actors[-1];local identity=d.enemies[-1].actorId
        assert(d:claim(71,-1)=='OK');s.combat[1].rawLife=35
        assert(command(.1)=='OK' and d.enemies[-1].windup.action=='PigHeavy')
        assert(d:claim(72,-1)=='ENEMY_OCCUPIED' and d.enemies[-1].engaged)
        tick(.1+Config.Attacks.PigHeavy.windup)
        assert(w.actors[-1]==body and d.enemies[-1].actorId==identity and s.combat[1].rawLife==31)
        assert(d.enemies[-1].health==3 and d:controlled(71).attempt==1)
        assert(command(d.now+.01)=='COOLDOWN' and command(d.now+.02,'PigHeavy')=='INVALID_INTENT')
    end)
    test('a whiff closes takeover at acceptance and disconnect does not cancel the accepted strike',function()
        local d,s,w,tick,command=fixture();assert(d:claim(71,-1)=='OK')
        assert(command(.1)=='OK');assert(d:connection(71,false)=='OK')
        tick(.1+Config.Attacks.PigJab.windup);assert(s.combat[1].rawLife==43)
        assert(command(d.now+.01)=='OFFLINE')
        local d2=fixture();d2.world.nextTargets={};d2:_beginStrike(-1,d2.enemies[-1])
        assert(d2:claim(71,-1)=='ENEMY_ENGAGED')
    end)
    test('normal and emergency protection follow the actual Session reaction path',function()
        for _,kind in ipairs({'Normal','Emergency'}) do
            local d,s,w,tick=fixture();w.hazards[1]='Fall';s:step(.1)
            w.safe=kind=='Normal';s:step(.2);d.now=.2
            assert(s.state.heroes[1].shield.kind==kind)
            d:_beginStrike(-1,d.enemies[-1],1);tick(.2+Config.Attacks.PigJab.windup)
            assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==2)
            assert(w.impulses==(kind=='Normal' and 1 or 0))
            assert(not s.combat[1].heavyReactionEpoch)
        end
    end)
    test('incoming hit or actual death cancels the pending Pig strike',function()
        local d,s,w,tick=fixture();d:_beginStrike(-1,d.enemies[-1],1)
        assert(d:hit(2,-1,'Punch'));tick(Config.Attacks.PigJab.windup)
        assert(s.combat[1].rawLife==47 and not d.enemies[-1].windup)
        local d2,s2,w2,tick2=fixture();d2:_beginStrike(-1,d2.enemies[-1],1);w2.hazards[-1]='Fell'
        tick2(Config.Attacks.PigJab.windup);assert(d2.enemies[-1].dead and s2.combat[1].rawLife==47)
    end)
    test('Pig hits another ordinary enemy with explicit prototype damage and source profile',function()
        for _,action in ipairs({'PigJab','PigHeavy','PigRush'}) do
            local d,s,w=fixture();assert(d:hit(-1,-2,action))
            assert(d.enemies[-2].health==(action=='PigJab' and 2 or 1))
            assert(w.lastProfile==({PigJab=0,PigHeavy=2,PigRush=4})[action])
            assert(d.enemies[-2].reactionUntil==Config.Attacks[action].reaction)
        end
    end)
    test('later aligned NPCs may start a finite running approach, early Pigs cannot',function()
        local d,s,w,tick=fixture();w.positions[1].x=15;w.positions[2].x=30;d.random=function()return 1 end
        tick(.1);assert(not d.enemies[-1].rushing and w.pursuits[-1].speed==Config.Enemy.speed)
        d.zoneIndex=3;tick(.2);assert(d.enemies[-1].rushing and w.pursuits[-1].speed==Config.Pig.rushSpeed)
        -- Entering melee captures the running action and clears the approach flag.
        w.actualRuns[-1]=true -- The physical adapter confirms the approach reached running speed.
        w.positions[1].x=4;tick(.3);assert(d.enemies[-1].windup.action=='PigRush' and not d.enemies[-1].rushing)
        s.combat[1].rawLife=15;tick(.3+Config.Attacks.PigRush.windup)
        assert(w.lastProfile==22 and s.combat[1].rawLife==0 and s.combat[1].deathAt,'Never substitute raw255 profile21')
    end)
    test('running decisions are gated by depth, target validity and a bounded random cadence',function()
        local d,s,w,tick=fixture();d.zoneIndex=3;w.positions[1]={x=15,y=3,z=3};w.positions[2].x=40
        local rolls=0;d.random=function()rolls+=1;return 32 end
        tick(.1);assert(rolls==0 and not d.enemies[-1].rushing)
        w.positions[1].z=0;tick(.2);tick(.21);tick(.22);assert(rolls==1)
        d.random=function()return 1 end;tick(.4);assert(d.enemies[-1].rushing)
        w.positions[1].z=3;tick(.5);assert(not d.enemies[-1].rushing)
        w.positions[1].z=0;s.combat[1].reactionEnd=2;s.combat[2].reactionEnd=2;tick(.6);assert(not d.enemies[-1].rushing)
    end)
    test('claiming an unengaged running Pig stops its approach without changing body or health',function()
        local d,s,w,tick=fixture();d.zoneIndex=3;w.positions[1].x=15;d.random=function()return 1 end
        tick(.1);assert(d.enemies[-1].rushing and not d.enemies[-1].engaged)
        w.actualRuns[-1]=true
        local actor=w.actors[-1];assert(d:claim(71,-1)=='OK' and not w:isRunning(-1))
        assert(not d.enemies[-1].rushing and not d.enemies[-1].windup and w.actors[-1]==actor and d.enemies[-1].health==3)
        tick(.2);assert(not d.enemies[-1].rushing)
    end)
    test('an invalid running target clears rush before the melee action is chosen',function()
        for _,change in ipairs({function(s,w)w.positions[1].z=3 end,
            function(s,w)s.combat[1].reactionEnd=2 end}) do
            local d,s,w,tick=fixture();d.zoneIndex=3;w.positions[1].x=15;d.random=function()return 1 end
            tick(.1);assert(d.enemies[-1].rushing)
            w.actualRuns[-1]=true
            w.positions[1].x=4;change(s,w);tick(.2)
            if s.combat[1].reactionEnd then assert(not d.enemies[-1].windup,'Heavy-reacting target is ineligible')
            else assert(d.enemies[-1].windup and d.enemies[-1].windup.action=='PigJab','Invalid rush must not become a hop') end
        end
    end)
    test('other species retain their existing attack and client schema cannot supply a trusted Pig action',function()
        local d=fixture();d:_beginStrike(-2,d.enemies[-2],1)
        assert(d.enemies[-2].windup.action=='WalkerLight')
        d.enemies[-2].kind='Dragon';d:_beginStrike(-2,d.enemies[-2],1)
        assert(d.enemies[-2].windup.action=='DragonHeadbutt')
        local d2,s2,w2,tick2,command=fixture();assert(d2:claim(71,-1)=='OK')
        assert(command(.1,'PigJab')=='INVALID_INTENT' and command(.2,'PigRush')=='INVALID_INTENT')
    end)
    test('Pig skips a heavy-reacting nearest hero while light reaction can select the heavy standing branch',function()
        local d,s,w,tick=fixture();s.combat[1].reactionEnd=2;s.combat[1].rawLife=3
        w.positions[2].x=4.5;tick(.1)
        assert(w.facing[-1]==2 and d.enemies[-1].windup.action=='PigJab','Heavy-reacting nearest body is not the AI target')
        local d2,s2,w2,tick2,command=fixture();assert(d2:claim(71,-1)=='OK')
        -- The real shared light hit creates raw35 from a fly-healed39; its recovery is still pending.
        s2.combat[1].rawLife=39;assert(s2:_hit(2,1,'Punch') and s2.combat[1].rawLife==35 and s2.combat[1].recover)
        assert(command(.1)=='OK' and d2.enemies[-1].windup.action=='PigHeavy','A light reaction may select the source heavy follow-up')
        tick2(.1+Config.Attacks.PigHeavy.windup)
        assert(s2.combat[1].rawLife==31 and w2.lastProfile==20,'Frozen heavy survives prior light recovery39')
    end)
    print('PigStrikes: '..passed..' PASS')
end
