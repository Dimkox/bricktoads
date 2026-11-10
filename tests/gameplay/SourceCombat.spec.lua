return function(Source,Director,Session,Core,Combat,Config,Level,FakeWorld,Carry)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function fixture(raw,kind)
        local w=FakeWorld.new();w.positions={[1]={x=0,y=3,z=0},[2]={x=10,y=3,z=0}}
        function w:spawnEnemy(id,species,p) self.actors[id]={id=id,kind=species};self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity() end
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress() end
        function w:reached() return false end
        function w:enemyHealth(id,h,max) self.lastEnemyHealth={id,h,max} end
        function w:cue() end
        function w:face() end
        function w:enemyMove() end
        function w:targets(id,profile) self.lastProfileShape=profile;return self.targetsFor[id] or {} end
        local cfg=table.clone(Config);cfg.Level={zones={{enemies={{id=-1,kind=kind or 'Walker',x=5,y=3,z=0,rawLife=raw or 31}},exit={}}}}
        local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'source-test',w)
        s:step(0)
        local d=Director.new(s,w,Combat,cfg);Source.bind(s,d,cfg)
        local original=s._hit
        s._hit=function(self,a,t,action,tuning) if t<0 then return d:hit(a,t,action,tuning) end;return original(self,a,t,action,tuning) end
        local function tick(now) d.now=now;s:step(now);d:step(now,.1) end
        local seq=0
        local function punch(now,attack)
            seq+=1;local h=s.state.heroes[1]
            return s:intent(1,{kind='Attack',attack=attack or 'Punch',runId=s.state.runId,actorId=h.actorId,
                attempt=h.attempt,levelEpoch=1,connectionEpoch=h.connectionEpoch,seq=seq},now)
        end
        d.enemies[-1].ownerUserId=71;d.enemies[-1].connected=false
        return d,s,w,tick,punch
    end
    test('all13 original actor Life records are explicit and three displayed hearts stay the same maximum',function()
        local expected={15,15,31,31,31,31,31,31,31,47,31,31,15};local n=0
        for _,zone in ipairs(Level.zones) do for _,e in ipairs(zone.enemies) do
            n+=1;assert(e.rawLife==expected[n],tostring(e.id))
        end end
        assert(n==13)
        local d=fixture(47,'Dragon');assert(d.enemies[-1].rawLife==47 and d.enemies[-1].health==3)
    end)
    test('source NPC arithmetic distinguishes exact zero, underflow and nibble rounding',function()
        local r=Combat.hitEnemy(2,'HeroJab');assert(r.rawLife==0 and not r.dying and r.profile==0 and r.rawDamage==2)
        r=Combat.hitEnemy(1,'HeroJab');assert(r.rawLife==0 and r.dying)
        r=Combat.hitEnemy(16,'HeroUppercut');assert(r.rawLife==15 and not r.dying)
        r=Combat.hitEnemy(15,'Dash');assert(r.profile==3 and r.dying)
        r=Combat.hitEnemy(15,'DragonHeadbutt');assert(r.profile==4 and r.rawDamage==16 and r.dying)
        r=Combat.hit(15,'DragonHeadbutt');assert(r.profile==22 and r.rawDamage==16)
        r=Combat.hit(47,'HeroKick');assert(r.profile==19 and r.rawDamage==8 and r.rawLife==39)
    end)
    test('server selector uses actual Life and heavy state without a combo counter',function()
        for _,case in ipairs({{3,false,'Walker','HeroPowerPunch'},{4,false,'Walker','HeroJab'},
            {19,false,'Walker','HeroUppercut'},{20,false,'Walker','HeroJab'},{35,false,'Dragon','HeroElbow'},
            {36,false,'Dragon','HeroJab'},{7,true,'Walker','HeroBoot'},{8,true,'Walker','HeroKick'}}) do
            local d,s,w,tick,punch=fixture(case[1],case[3]);local e=d.enemies[-1]
            e.reactionUntil=case[2] and 2 or nil;e.heavyReaction=case[2]
            w.targetsFor[1]={-1};assert(punch(.1)=='OK');assert(s.combat[1].attack.action==case[4],case[4])
        end
    end)
    test('repeated source jabs reach the actual uppercut kick boot chain while preserving owner and body',function()
        local d,s,w,tick,punch=fixture();local e=d.enemies[-1];local body=w.actors[-1];local identity=e.actorId
        w.targetsFor[1]={-1}
        local expected={29,27,25,23,21,19,15,7,0}
        local actions={'HeroJab','HeroJab','HeroJab','HeroJab','HeroJab','HeroJab','HeroUppercut','HeroKick','HeroBoot'}
        for i=1,#expected do
            local now=.1+(i-1)*.6
            assert(punch(now)=='OK');local pending=s.combat[1].attack;assert(pending.action==actions[i],tostring(i))
            tick(pending.at);assert(e.rawLife==expected[i],tostring(i)..':'..e.rawLife)
            if i<#expected then assert(not e.dead and e.ownerUserId==71 and w.actors[-1]==body and e.actorId==identity) end
        end
        assert(e.dead and e.health==0 and w.kills==1)
    end)
    test('NPC reaction recovery is real and rawzero remains alive before OR7',function()
        local d,s,w,tick=fixture(2);assert(d:hit(1,-1,'HeroJab'))
        assert(d.enemies[-1].rawLife==0 and not d.enemies[-1].dead)
        tick(d.enemies[-1].reactionUntil);assert(d.enemies[-1].rawLife==7 and not d.enemies[-1].dead)
        local d2,s2,w2,tick2=fixture();assert(d2:hit(1,-1,'HeroJab'));tick2(d2.enemies[-1].reactionUntil)
        assert(d2.enemies[-1].rawLife==31)
    end)
    test('frozen animation hits the new actual body with its victim-specific profile',function()
        local d,s,w,tick,punch=fixture(19);w.targetsFor[1]={-1};assert(punch(.1)=='OK')
        local pending=s.combat[1].attack;assert(pending.action=='HeroUppercut' and pending.inputAction=='Punch')
        w.targetsFor[1]={2};tick(pending.at)
        assert(d.enemies[-1].rawLife==19 and s.combat[2].rawLife==31 and w.lastProfile==20)
        local impulses=w.impulses;tick(pending.at+.01);assert(w.impulses==impulses)
    end)
    test('modern hero reactions accept a legitimate second hit but postheavy protection excludes it',function()
        local d,s,w,tick=fixture();assert(s:_hit(1,2,'HeroJab'));assert(s:_hit(1,2,'HeroJab'))
        assert(s.combat[2].rawLife==39)
        assert(s:_hit(1,2,'HeroUppercut'));local untilTime=s.combat[2].reactionEnd;tick(untilTime)
        assert(not s:_hit(1,2,'HeroJab') and s.combat[2].rawLife==31)
        tick(untilTime+Config.SourceCombat.heavyProtection);assert(s:_hit(1,2,'HeroJab'))
    end)
    test('public validation rejects every internal action and interactions retain priority',function()
        local d,s,w,tick,punch=fixture();w.targetsFor[1]={-1}
        assert(punch(.1,'HeroBoot')=='INVALID_INTENT' and not s.combat[1].attack)
        s.contextualAttack=function() return 'OK' end
        assert(punch(.2)=='OK' and not s.combat[1].attack and d.enemies[-1].rawLife==31)
    end)
    test('overdue reactions normalize before a new selection and cannot extend heavy protection',function()
        local d,s,w,tick,punch=fixture();assert(d:hit(1,-1,'HeroJab') and d.enemies[-1].rawLife==29)
        w.targetsFor[1]={-1};assert(punch(1.2)=='OK')
        assert(d.enemies[-1].rawLife==31,'Expired NPC recovery must precede the new attack choice')
        local d2,s2,w2,tick2=fixture();assert(s2:_hit(1,2,'HeroUppercut'));tick2(2)
        assert(s2:_hit(1,2,'HeroJab'),'A late server step cannot restart an already elapsed protection interval')
    end)
    test('effect-time NPC recovery precedes subtraction and accepted hitbox tuning stays frozen',function()
        local d,s,w,tick,punch=fixture();assert(d:hit(1,-1,'HeroJab'))
        d.now=1.2;assert(d:hit(1,-1,'HeroJab') and d.enemies[-1].rawLife==29)
        local d2,s2,w2,tick2,punch2=fixture();w2.targetsFor[1]={-1};assert(punch2(.1)=='OK')
        local a=s2.combat[1].attack
        d2.config.Attacks=table.clone(d2.config.Attacks);d2.config.Attacks.HeroJab=table.clone(d2.config.Attacks.HeroJab)
        d2.config.Attacks.HeroJab.reach=1;tick2(a.at)
        assert(w2.lastProfileShape.reach==6 and d2.enemies[-1].rawLife==29)
    end)
    test('accepted hero response retains reaction and impulse despite hot configuration changes',function()
        local d,s,w,tick,punch=fixture()
        d.config.Attacks=table.clone(d.config.Attacks);d.config.Attacks.HeroJab=table.clone(d.config.Attacks.HeroJab)
        d.config.Impulses=table.clone(d.config.Impulses);d.config.Impulses[18]=table.clone(d.config.Impulses[18])
        w.targetsFor[1]={2};assert(punch(.1)=='OK');local a=s.combat[1].attack
        d.config.Attacks.HeroJab.reaction=99;d.config.Impulses[18].horizontal=999
        tick(a.at)
        assert(math.abs(s.combat[2].reactionEnd-s.now-28/60)<1e-8 and w.lastCalibration.horizontal==9)
        local d2,s2,w2,tick2,punch2=fixture();w2.targetsFor[1]={-1}
        d2.config.SourceCombat=table.clone(d2.config.SourceCombat)
        assert(punch2(.1)=='OK');local b=s2.combat[1].attack
        d2.config.SourceCombat.npcLightReaction=99;tick2(b.at)
        assert(math.abs(d2.enemies[-1].reactionUntil-d2.now-1.05)<1e-8)
    end)
    test('blocked light hits stay light and never grant postheavy protection',function()
        local d,s,w,tick,punch=fixture();s:_die(2,'fixture');s:step(.1)
        assert(s.state.heroes[2].shield.kind=='Normal' and s:_hit(1,2,'HeroJab'))
        assert(not s.combat[2].heavyReactionEpoch)
        w.targetsFor[1]={2};assert(punch(.2)=='OK' and s.combat[1].attack.action=='HeroJab')
        tick(s.combat[2].reactionEnd)
        assert(s.combat[2].hitProtectedUntil==nil and s:_hit(1,2,'HeroJab'))
    end)
    test('a source target becoming carried or thrown before effect cannot be damaged or released',function()
        local d,s,w,tick,punch=fixture(31,'Pig')
        function w:canGrabEnemy() return true end
        function w:carryEnemy() return true end
        function w:releaseEnemy() return true end
        d.carry=Carry.new(d)
        d.config.Attacks=table.clone(d.config.Attacks);d.config.Attacks.HeroJab=table.clone(d.config.Attacks.HeroJab)
        d.config.Attacks.HeroJab.windup=.5
        w.targetsFor[1]={-1};assert(punch(.1)=='OK')
        local at=s.combat[1].attack.at
        assert(d:interact(2,.11,'Punch')=='OK');d:step(.24,.1)
        assert(d.carry:stateFor(-1)=='Carried');tick(at)
        assert(d.enemies[-1].rawLife==31 and d.carry:stateFor(-1)=='Carried')
        assert(d:interact(2,.8,'Punch')=='OK');local raw=d.enemies[-1].rawLife
        assert(d.carry:stateFor(-1)=='Thrown' and not d:hit(1,-1,'HeroJab'))
        assert(d.enemies[-1].rawLife==raw and d.carry:stateFor(-1)=='Thrown')
    end)
    test('accepted heavy protection duration cannot change during windup or recovery',function()
        local d,s,w,tick,punch=fixture(19)
        d.config.SourceCombat=table.clone(d.config.SourceCombat);Source.bind(s,d,d.config)
        w.targetsFor[1]={-1};assert(punch(.1)=='OK');local a=s.combat[1].attack
        d.config.SourceCombat.heavyProtection=99;w.targetsFor[1]={2};tick(a.at)
        local deadline=s.combat[2].reactionEnd;tick(deadline)
        assert(math.abs(s.combat[2].hitProtectedUntil-deadline-28/60)<1e-8)
    end)
    assert(failed==0,tostring(failed)..' source combat cases failed')
    print('SourceCombat: '..passed..' PASS')
end
