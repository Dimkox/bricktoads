return function(Director,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=4,y=3,z=0},[2]={x=12,y=3,z=0}}
        function w:spawnEnemy(id,kind,p) self.actors[id]={id=id,kind=kind};self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity() end
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress() end
        function w:reached() return false end
        function w:enemyHealth() end
        function w:cue() end
        function w:face() end
        function w:enemyMove() end
        function w:targets(_,profile) self.hitbox=profile;return self.victims or {1} end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'dragon-test',w)
        s:step(0)
        local cfg=table.clone(Config);cfg.Level={zones={{enemies={{id=-1,kind='Dragon',x=0,y=3,z=0},
            {id=-2,kind='Pig',x=-30,y=3,z=0}},exit={}}}}
        s.config=cfg
        local d=Director.new(s,w,Combat,cfg)
        local function tick(now) s:step(now);d:step(now,.1) end
        local seq=0
        local function command(now,attack)
            seq+=1;local e=d.enemies[-1]
            return d:command(71,{kind='Attack',attack=attack or 'Punch',runId=s.state.runId,
                levelEpoch=1,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,seq=seq},now,Session.validIntent)
        end
        return d,s,w,tick,command
    end
    test('Dragon fixed22 differs from hero Dash finisher at low Life',function()
        for _,case in ipairs({{15,0,true},{16,15,false},{31,15,false},{47,31,false}}) do
            local r=Combat.hit(case[1],'DragonHeadbutt')
            assert(r.profile==22 and r.rawDamage==16 and r.rawLife==case[2] and r.dying==case[3])
            assert(r.heavyReaction and not r.recover)
        end
    end)
    test('normal AI selects its own headbutt and resolves once through real Session',function()
        local d,s,w,tick=fixture();tick(.1)
        assert(d.enemies[-1].windup.action=='DragonHeadbutt')
        tick(.1+Config.Attacks.DragonHeadbutt.windup)
        assert(s.combat[1].rawLife==31 and w.lastProfile==22 and w.hitbox.reach==6)
        local impulses=w.impulses;tick(d.now+.01);assert(w.impulses==impulses)
        tick(s.combat[1].reactionEnd);assert(s.combat[1].rawLife==31)
    end)
    test('accepted action and cloned geometry survive configuration and target changes',function()
        local d,s,w,tick=fixture();s.combat[1].rawLife=15;d:_beginStrike(-1,d.enemies[-1],1)
        local a=d.enemies[-1].windup;assert(a.action=='DragonHeadbutt' and a.tuning~=Config.Attacks.DragonHeadbutt)
        d.config.Attacks=table.clone(d.config.Attacks);d.config.Attacks.DragonHeadbutt={reach=1,cooldown=99}
        w.victims={2};tick(a.at)
        assert(s.combat[1].rawLife==15 and s.combat[2].rawLife==31 and w.hitbox.reach==6)
        assert(d.enemies[-1].nextAttack==a.at+1.25)
    end)
    test('effect-time miss does not directly damage the accepted victim',function()
        local d,s,w,tick=fixture();tick(.1);w.victims={};tick(.45)
        assert(s.combat[1].rawLife==47 and w.impulses==0 and not d.enemies[-1].windup)
        local misses=0
        for _,row in ipairs(s.logs) do if row.kind=='EnemyAttackMiss' then misses+=1 end end
        assert(misses==1,'A resolved empty headbutt must emit one confirmed miss')
    end)
    test('human F keeps same body and accepted offline effect without new attack names',function()
        local d,s,w,tick,command=fixture();local body=w.actors[-1];local actor=d.enemies[-1].actorId
        assert(d:claim(71,-1)=='OK' and command(.1)=='OK')
        assert(d:claim(72,-1)=='ENEMY_OCCUPIED' and command(.11,'DragonHeadbutt')=='INVALID_INTENT')
        assert(d:connection(71,false)=='OK');tick(.45)
        assert(s.combat[1].rawLife==31 and w.actors[-1]==body and d.enemies[-1].actorId==actor)
        assert(d.enemies[-1].health==3 and command(.46)=='OFFLINE')
    end)
    test('shields retain their damage and impulse policies',function()
        for _,kind in ipairs({'Normal','Emergency'}) do
            local d,s,w,tick=fixture();w.hazards[1]='Fall';s:step(.1);w.safe=kind=='Normal';s:step(.2)
            d.now=.2;d:_beginStrike(-1,d.enemies[-1],1);tick(.55)
            assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==2)
            assert(w.impulses==(kind=='Normal' and 1 or 0))
        end
    end)
    test('ordinary friendly fire uses explicit2HP and base4',function()
        local d,s,w=fixture();assert(d:hit(-1,-2,'DragonHeadbutt'))
        assert(d.enemies[-2].health==1 and w.lastProfile==4)
    end)
    test('incoming hit cancels the windup and physical death cannot emit a club',function()
        local d,s,w,tick=fixture();d:_beginStrike(-1,d.enemies[-1],1)
        assert(d:hit(2,-1,'Punch') and not d.enemies[-1].windup)
        w.hazards[-1]='Fall';tick(.35)
        assert(d.enemies[-1].dead and s.combat[1].rawLife==47)
    end)
    test('accepted NPC response survives removed live action and changed impulse tuning',function()
        local d,s,w,tick=fixture()
        d.config.Attacks=table.clone(d.config.Attacks)
        d.config.Impulses=table.clone(d.config.Impulses);d.config.Impulses[22]=table.clone(d.config.Impulses[22])
        tick(.1);local at=d.enemies[-1].windup.at
        d.config.Attacks.DragonHeadbutt=nil;d.config.Impulses[22].horizontal=999
        tick(at)
        assert(s.combat[1].rawLife==31 and math.abs(s.combat[1].reactionEnd-s.now-.75)<1e-8)
        assert(w.lastCalibration.horizontal==32)
    end)
    print('DragonStrikes: '..passed..' PASS')
end
