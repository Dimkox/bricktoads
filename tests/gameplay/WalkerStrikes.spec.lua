return function(Director,Session,Core,Combat,Config,FakeWorld,Clubs)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=6.5,y=3,z=0},[2]={x=20,y=3,z=0}}
        w.pursuits={};w.retreats={};w.facing={};w.nextTargets={1};w.items={}
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
        function w:enemyRetreat(id,target,speed) self.retreats[id]={target=target,speed=speed} end
        function w:groundPosition(p) return p and {x=p.x,y=1.2,z=p.z} end
        function w:clubItem(id,p) self.items[id]=p and table.clone(p) or nil end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'walker-test',w)
        s:step(0)
        local cfg=table.clone(Config)
        cfg.Level={zones={{enemies={{id=-1,kind='Walker',x=0,y=3,z=0},{id=-2,kind='Pig',x=-30,y=3,z=0}},exit={}}}}
        local d=Director.new(s,w,Combat,cfg,nil,nil,nil,Clubs)
        local hit=s._hit
        s._hit=function(session,a,t,action) if t<0 then return d:hit(a,t,action) end;return hit(session,a,t,action) end
        local function tick(now) s:step(now);d:step(now,.1) end
        local seq=0
        local function command(now,attack)
            seq+=1;local e=d.enemies[-1]
            return d:command(71,{kind='Attack',attack=attack or 'Punch',runId=s.state.runId,
                levelEpoch=s.state.levelEpoch,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,seq=seq},now,Session.validIntent)
        end
        return d,s,w,tick,command
    end
    test('Walker begins its own light strike beyond the old generic5-stud start distance',function()
        local d,s,w,tick=fixture();tick(.1)
        assert(d.enemies[-1].windup and d.enemies[-1].windup.action=='WalkerLight','Walker must have its own AI attack range')
        tick(.1+Config.Attacks.WalkerLight.windup)
        assert(s.combat[1].rawLife==43 and w.lastProfile==18 and not s.combat[1].heavyReactionEpoch)
        assert(w.lastHitbox.reach==7.5 and w.lastHitbox.width==3.25)
        tick(s.combat[1].reactionEnd);assert(s.combat[1].rawLife==47)
    end)
    test('standing selection uses low nibble3/4 and never mistakes total Life15 for the heavy condition',function()
        for _,raw in ipairs({0,3,4,15,16,19,20,31,32,35,36,47}) do
            local d,s=fixture();s.combat[1].rawLife=raw;d:_beginStrike(-1,d.enemies[-1],1)
            assert(d.enemies[-1].windup.action==(raw%16<4 and 'WalkerHeavy' or 'WalkerLight'),tostring(raw))
        end
    end)
    test('the accepted heavy and its tuning survive health/configuration changes before actual effect',function()
        local d,s,w,tick=fixture();s.combat[1].rawLife=35;d:_beginStrike(-1,d.enemies[-1],1)
        local pending=d.enemies[-1].windup;assert(pending.tuning~=Config.Attacks.WalkerHeavy)
        d.config.Attacks=table.clone(d.config.Attacks);d.config.Attacks.WalkerHeavy=table.clone(d.config.Attacks.WalkerHeavy)
        d.config.Attacks.WalkerHeavy.cooldown=99;d.config.Attacks.WalkerHeavy.reach=1
        s.combat[1].rawLife=47;tick(pending.at)
        assert(s.combat[1].rawLife==31 and w.lastProfile==20 and s.combat[1].heavyReactionEpoch==1)
        assert(w.lastHitbox.reach==7.5,'Accepted geometry must use its captured tuning')
        assert(d.enemies[-1].nextAttack==pending.at+Config.Attacks.WalkerHeavy.cooldown)
        local impulses=w.impulses;tick(pending.at+.01);assert(w.impulses==impulses)
    end)
    test('point-blank AI retreats safely while range boundaries choose pursuit or attack',function()
        for _,distance in ipairs({1,2.49,2.5,6.5,6.51}) do
            local d,s,w,tick=fixture();w.positions[1].x=distance;tick(.1)
            if distance<2.5 then
                assert(not d.enemies[-1].windup and w.retreats[-1].target==1 and w.retreats[-1].speed==7)
                assert(not d.enemies[-1].engaged,'Voluntary positioning is not an accepted attack')
            elseif distance<=6.5 then assert(d.enemies[-1].windup.action=='WalkerLight')
            else assert(not d.enemies[-1].windup and w.pursuits[-1].target==1) end
        end
    end)
    test('AI target selection skips heavy reaction and can capture a light-recovering target',function()
        local d,s,w,tick=fixture();s.combat[1].reactionEnd=2;s.combat[1].rawLife=3;w.positions[2].x=6
        tick(.1);assert(w.facing[-1]==2 and d.enemies[-1].windup.action=='WalkerLight')
        local d2,s2,w2,tick2=fixture();s2.combat[1].rawLife=39;assert(s2:_hit(2,1,'Punch'))
        tick2(.1);assert(d2.enemies[-1].windup.action=='WalkerHeavy')
        tick2(.1+Config.Attacks.WalkerHeavy.windup);assert(s2.combat[1].rawLife==31 and w2.lastProfile==20)
    end)
    test('source height is decided by effect geometry rather than an invented target-grounded prerequisite',function()
        local d,s,w,tick=fixture();w.positions[1]={x=4,y=6,z=0};tick(.1)
        assert(d.enemies[-1].windup.action=='WalkerLight')
        w.nextTargets={};tick(.1+Config.Attacks.WalkerLight.windup)
        assert(s.combat[1].rawLife==47,'A later airborne miss must not deal direct target-locked damage')
    end)
    test('effect geometry may hit another body without reselecting the accepted attack',function()
        local d,s,w,tick=fixture();s.combat[1].rawLife=3;d:_beginStrike(-1,d.enemies[-1],1)
        w.nextTargets={2};tick(Config.Attacks.WalkerHeavy.windup)
        assert(s.combat[1].rawLife==3 and s.combat[2].rawLife==31 and w.lastProfile==20)
    end)
    test('human primary retains the same body and source choice, closes takeover and rejects trusted client names',function()
        local d,s,w,tick,command=fixture();local body=w.actors[-1];local identity=d.enemies[-1].actorId
        assert(d:claim(71,-1)=='OK');s.combat[1].rawLife=35
        assert(command(.1)=='OK' and d.enemies[-1].windup.action=='WalkerHeavy')
        assert(d:claim(72,-1)=='ENEMY_OCCUPIED');tick(.1+Config.Attacks.WalkerHeavy.windup)
        assert(w.actors[-1]==body and d.enemies[-1].actorId==identity and d.enemies[-1].health==3)
        assert(s.combat[1].rawLife==31 and d:controlled(71).attempt==1)
        assert(command(d.now+.01)=='COOLDOWN' and command(d.now+.02,'WalkerHeavy')=='INVALID_INTENT')
        assert(command(d.now+.03,'WalkerLight')=='INVALID_INTENT')
    end)
    test('an accepted human whiff remains engaged and an accepted offline strike finishes once',function()
        local d,s,w,tick,command=fixture();assert(d:claim(71,-1)=='OK');assert(command(.1)=='OK')
        assert(d:connection(71,false)=='OK');tick(.1+Config.Attacks.WalkerLight.windup)
        assert(s.combat[1].rawLife==43 and command(d.now+.01)=='OFFLINE')
        local d2,s2,w2,tick2=fixture();w2.nextTargets={};d2:_beginStrike(-1,d2.enemies[-1])
        assert(d2:claim(71,-1)=='ENEMY_ENGAGED');tick2(Config.Attacks.WalkerLight.windup)
        assert(s2.combat[1].rawLife==47 and not d2.enemies[-1].windup)
    end)
    test('both real respawn shields block damage with the correct light/heavy interrupt policy',function()
        for _,kind in ipairs({'Normal','Emergency'}) do for _,action in ipairs({'WalkerLight','WalkerHeavy'}) do
            local d,s,w,tick=fixture();w.hazards[1]='Fall';s:step(.1);w.safe=kind=='Normal';s:step(.2);d.now=.2
            s.combat[1].rawLife=action=='WalkerHeavy' and 35 or 47
            local before=s.combat[1].rawLife;d:_beginStrike(-1,d.enemies[-1],1)
            tick(.2+Config.Attacks[action].windup)
            assert(s.combat[1].rawLife==before and s.state.heroes[1].respawns==2)
            assert(w.impulses==(kind=='Normal' and 1 or 0))
            assert((s.combat[1].heavyReactionEpoch or 0)==(kind=='Normal' and action=='WalkerHeavy' and 1 or 0))
        end end
    end)
    test('NPC friendly fire uses explicit prototype damage and source0/2 impulses',function()
        for _,action in ipairs({'WalkerLight','WalkerHeavy'}) do
            local d,s,w=fixture();assert(d:hit(-1,-2,action))
            assert(d.enemies[-2].health==(action=='WalkerLight' and 2 or 1))
            assert(w.lastProfile==(action=='WalkerLight' and 0 or 2))
            assert(d.enemies[-2].reactionUntil==Config.Attacks[action].reaction)
        end
    end)
    test('incoming damage cancels a Walker windup before it can hit',function()
        local d,s,w,tick=fixture();d:_beginStrike(-1,d.enemies[-1],1);local old=d.enemies[-1].windup
        assert(d:hit(2,-1,'Punch') and not d.enemies[-1].windup)
        tick(Config.Attacks.WalkerLight.windup);assert(s.combat[1].rawLife==47 and d.enemies[-1].windup~=old)
    end)
    test('combat death during a windup emits exactly one existing club and never a duplicate strike',function()
        local d,s,w,tick=fixture();assert(d:hit(1,-1,'Dash'));tick(.4)
        assert(d.enemies[-1].windup);assert(d:hit(1,-1,'Punch'))
        assert(d.enemies[-1].dead and not d.enemies[-1].windup)
        local count=0;for _ in pairs(w.items) do count+=1 end;assert(count==1)
        assert(not d:hit(1,-1,'Dash'));d:_kill(-1,'Combat');tick(.9)
        local again=0;for _ in pairs(w.items) do again+=1 end;assert(again==1 and s.combat[1].rawLife==47)
    end)
    test('physical death during a windup cancels the effect without granting a safe club',function()
        local d,s,w,tick=fixture();d:_beginStrike(-1,d.enemies[-1],1);w.hazards[-1]='Fall'
        tick(Config.Attacks.WalkerLight.windup);assert(d.enemies[-1].dead and next(w.items)==nil and s.combat[1].rawLife==47)
    end)
    test('a retreating unengaged Walker can be claimed without healing or replacing its body',function()
        local d,s,w,tick=fixture();w.positions[1].x=1;tick(.1);local body=w.actors[-1]
        assert(w.retreats[-1] and d:claim(71,-1)=='OK' and w.actors[-1]==body)
        w.retreats={};tick(.2);assert(not w.retreats[-1] and d.enemies[-1].ownerUserId==71 and d.enemies[-1].health==3)
    end)
    test('Pig standing/running and legacy ordinary profiles remain independent of Walker configuration',function()
        local d,s=fixture();d:_beginStrike(-2,d.enemies[-2],1);assert(d.enemies[-2].windup.action=='PigJab')
        d.route=nil;d:_beginStrike(-1,d.enemies[-1],1);assert(d.enemies[-1].windup.action=='Dash')
    end)
    print('WalkerStrikes: '..passed..' PASS')
end
