-- Pure encounter contract plus real Session damage/lifecycle integration. World
-- only replaces engine presentation and actor positions; combat is production.
return function(Boss,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function eq(a,b,label) assert(a==b,(label or '')..' expected '..tostring(b)..', got '..tostring(a)) end
    local function count(t) local n=0;for _ in pairs(t) do n+=1 end;return n end
    local function fixture(kind,human,chase,platform)
        local w=FakeWorld.new();w.positions={[1]={x=4,y=3,z=0},[2]={x=70,y=3,z=0}}
        w.rendered={};w.removed={};w.tells={};w.bossSpawns=0
        function w:position(id) return self.positions[id] end
        function w:spawnEnemy(id,name,p) self.bossSpawns+=1;self.positions[id]=table.clone(p);self.actors[id]={alive=true,kind=name};return true end
        function w:placeActor(id,p) self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity(id,actorId) self.actors[id].id=actorId end
        function w:enemyHealth(id,current,maximum) self.lastHealth={id,current,maximum} end
        function w:face(id,target) self.lastFace={id,target} end
        function w:aim(id,x,z) self.lastAim={id,x,z} end
        function w:cue(id,active) self.lastCue={id,active} end
        function w:projectile(id,p,_,mode) self.rendered[id]={position=table.clone(p),mode=mode} end
        function w:removeProjectile(id) self.rendered[id]=nil;self.removed[id]=(self.removed[id] or 0)+1 end
        function w:bossTell(kind,p,radius,untilAt) self.tells[#self.tells+1]={kind,p,radius,untilAt} end
        function w:campaignProjectileBlocked(a,b)
            return self.wallX~=nil and (a.x-self.wallX)*(b.x-self.wallX)<=0 and a.x~=b.x
        end
        function w:targets(id,cfg)
            if self.blocked then return {} end
            local p=self.positions[id];if not p then return {} end
            local towards=self.positions[-99]
            local face=self.facings and self.facings[id] or {x=towards.x-p.x,z=towards.z-p.z}
            local length=math.sqrt(face.x^2+face.z^2);if length==0 then return {} end
            local x,z=face.x/length,face.z/length;local result={}
            for target,q in pairs(self.positions) do
                local forward=(q.x-p.x)*x+(q.z-p.z)*z;local side=(q.x-p.x)*z-(q.z-p.z)*x
                if target~=id and forward>=0 and forward<=(cfg.reach or 6) and math.abs(side)<=(cfg.width or 3)
                    and math.abs(q.y-p.y)<=(cfg.height or 4) then result[#result+1]=target end
            end
            return result
        end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Yellow'}},'boss-test',w)
        s:step(0);s.state.heroes[1].shield=nil;s.state.heroes[2].shield=nil
        local definition={id='campaign-test',boss={type=kind,position={x=0,y=3,z=0},chaseComplete=chase~=false},
            arena={minX=-24,maxX=24,minZ=-20,maxZ=20},bossGate=human and {ownerUserId=99,connected=true,connectionEpoch=1,ownerName='owner'} or nil}
        if platform then
            definition.arena=nil;definition.boss.platform=platform
            definition.boss.position={x=platform.x+4,y=platform.y+platform.h/2+3,z=platform.z}
        end
        local b=Boss.new(s,w,Config,definition)
        local function step(now,dt) s.now=now;return b:step(now,dt) end
        return b,w,s,step
    end
    local function test(name,body) body();passed+=1;print('PASS '..name) end

    test('byte damage differs by action and recovery does not heal across the source boundary',function()
        local b,_,_,step=fixture('BigBlag',true)
        eq(b:hit(1,-99,'HeroJab'),true);eq(b:snapshot().bossRawLife,253)
        step(1.1,1.1);eq(b:snapshot().bossRawLife,255)
        eq(b:hit(1,-99,'HeroUppercut'),true);eq(b:snapshot().bossRawLife,239)
        step(2.2,1.1);eq(b:snapshot().bossRawLife,239)
        eq(b:snapshot().bossPhase,1);eq(b.defeated,false)
    end)

    test('unknown attacks self hits far hits and invalid geometry cannot advance boss resources',function()
        local b,w=fixture('BigBlag',true)
        eq(b:hit(1,-99,'Invented',{damage=255}),false)
        eq(b:hit(-99,-99,'HeroBoot'),false)
        w.positions[1].x=100;eq(b:hit(1,-99,'HeroBoot'),false)
        w.positions[1]={x=0/0,y=3,z=0};eq(b:hit(1,-99,'HeroBoot'),false)
        eq(b:snapshot().bossRawLife,255);eq(b.defeated,false)
    end)

    test('Big Blag crosses source C0 and80 thresholds and cannot lose from time alone',function()
        local b,_,_,step=fixture('BigBlag',true)
        for i=1,4 do b:hit(1,-99,'HeroUppercut');step(i,.5) end
        eq(b:snapshot().bossRawLife,191);eq(b:snapshot().bossPhase,2)
        for i=5,8 do b:hit(1,-99,'HeroUppercut');step(i,.5) end
        eq(b:snapshot().bossRawLife,127);eq(b:snapshot().bossPhase,3)
        step(10000,9992);eq(b.defeated,false);eq(b:snapshot().bossRawLife,127)
    end)

    test('Robo Manus and Queen underflow advances0583 progress instead of killing fifteen HP',function()
        for _,kind in ipairs({'RoboManus','DarkQueen'}) do
            local b,_,_,step=fixture(kind,true)
            eq(b:hit(1,-99,'HeroUppercut'),true)
            eq(b:snapshot().bossProgress,12);eq(b:snapshot().bossRawLife,0);eq(b.defeated,false)
            step(.5,.5);eq(b:snapshot().bossRawLife,7)
            for n=2,20 do eq(b:hit(1,-99,'HeroUppercut'),true);step(n,.5) end
            eq(b:snapshot().bossProgress,240);eq(b.defeated,false)
            eq(b:hit(1,-99,'HeroUppercut'),true);eq(b.defeated,true)
            eq(b:snapshot().bossState,'Defeated')
        end
    end)

    test('General Slaughter spends initial FF Life before separate progress and preserves exact zero',function()
        local b,_,_,step=fixture('GeneralSlaughter',true)
        for n=1,15 do eq(b:hit(1,-99,'HeroUppercut'),true);step(n,.5) end
        eq(b:snapshot().bossRawLife,15);eq(b:snapshot().bossProgress,0)
        eq(b:hit(1,-99,'HeroUppercut'),true);eq(b:snapshot().bossProgress,12);eq(b.defeated,false)
        step(16,.5);eq(b:snapshot().bossRawLife,7)
    end)

    test('Buzzball chase handoff preserves one CF actor and offers no chase damage exploit',function()
        local b,w=fixture('Buzzball',true,false)
        local actor=b.enemies[-99].actorId
        eq(b:snapshot().bossState,'Chase');eq(b:hit(1,-99,'HeroBoot'),false)
        eq(b:finishChase(),'OK');eq(b:finishChase(),'NO_CHANGE')
        eq(b.enemies[-99].actorId,actor);eq(w.bossSpawns,1);eq(b:snapshot().bossRawLife,207)
        eq(b:hit(1,-99,'HeroUppercut'),true);eq(b:snapshot().bossRawLife,191)
    end)

    test('every boss has distinct command attacks finite recovery and real vulnerable windows',function()
        local actions={BigBlag='Hop',RoboManus='Burst',GeneralSlaughter='Charge',Buzzball='Roll',DarkQueen='Sweep'}
        for kind,want in pairs(actions) do
            local b,w,_,step=fixture(kind,true)
            eq(b:command('Punch',{x=1,z=0}),'OK');eq(b:snapshot().bossAttack,want)
            eq(b:command('Punch',{x=1,z=0}),'COOLDOWN')
            eq(b:hit(1,-99,'HeroUppercut'),false,'windup armor '..kind)
            for n=1,120 do step(n/20,.05) end
            eq(b:snapshot().bossState,'Ready',kind);eq(count(b.projectiles),0)
            w.positions[1]={x=w.positions[-99].x+3,y=w.positions[-99].y,z=w.positions[-99].z}
            eq(b:hit(1,-99,'HeroUppercut'),true,'vulnerability '..kind)
        end
    end)

    test('swept Robo projectile hits real Session and misses distant or elevated heroes',function()
        local b,w,s,step=fixture('RoboManus',true)
        w.positions[1]={x=20,y=3,z=0};w.positions[2]={x=20,y=15,z=0}
        eq(b:command('Punch',{x=1,z=0}),'OK')
        step(.6,.6);step(1.2,.6)
        assert(s.combat[1].rawLife<47,'swept bolt must cross target between frames')
        eq(s.combat[2].rawLife,47);eq(s.state.heroes[1].respawns,3)
        local miss,missWorld,missSession,missStep=fixture('RoboManus',true)
        missWorld.positions[1]={x=20,y=3,z=10};missWorld.positions[2]={x=70,y=3,z=0}
        miss:command('Punch',{x=1,z=0});missStep(.6,.6);missStep(1.2,.6)
        eq(missSession.combat[1].rawLife,47)
    end)

    test('charges use swept contact once per attack and clamp to this arenas bounds',function()
        local b,w,s,step=fixture('GeneralSlaughter',true)
        w.positions[1]={x=12,y=3,z=0};w.positions[2]={x=12,y=3,z=12}
        b:command('Punch',{x=1,z=0});step(.7,.7);step(1.3,.6)
        eq(s.combat[1].rawLife,31);eq(s.combat[2].rawLife,47)
        step(1.4,.1);eq(s.combat[1].rawLife,31)
        assert(w.positions[-99].x<=24 and w.positions[-99].z<=20)
    end)

    test('human and NPC damage progress and action profiles share the same state machine',function()
        local npc,nw,ns,nstep=fixture('RoboManus',false)
        local human,hw,hs,hstep=fixture('RoboManus',true)
        nw.positions[1]={x=20,y=3,z=0};hw.positions[1]={x=20,y=3,z=0}
        nstep(.5,0);hstep(.5,0);human:command('Punch',{x=1,z=0})
        for n=1,30 do nstep(.5+n*.05,.05);hstep(.5+n*.05,.05) end
        eq(ns.combat[1].rawLife,hs.combat[1].rawLife)
        eq(npc:snapshot().bossRawLife,human:snapshot().bossRawLife)
        eq(npc:snapshot().bossProgress,human:snapshot().bossProgress)
    end)

    test('disconnect blocks new commands while pending attacks finish without resource refill',function()
        local b,w,s,step=fixture('RoboManus',true)
        w.positions[1]={x=20,y=3,z=0};b:command('Punch',{x=1,z=0})
        eq(b:connection(99,false),'OK');eq(b:command('Dash',{x=1,z=0}),'OFFLINE')
        step(.6,.6);step(1.2,.6);assert(s.combat[1].rawLife<47)
        local life=b:snapshot().bossRawLife;local progress=b:snapshot().bossProgress
        eq(b:connection(99,true),'OK');eq(b:snapshot().bossRawLife,life);eq(b:snapshot().bossProgress,progress)
        eq(b:claim(100,-99),'UNKNOWN_ENEMY');eq(#b:available(100),0)
        eq(b:controlled(99).enemyId,-99);eq(b:controlled(100),nil)
    end)

    test('closing one encounter clears only its projectiles and prevents further effects',function()
        local a,aw,as,astep=fixture('RoboManus',true)
        local b,bw,_,bstep=fixture('RoboManus',true)
        aw.positions[1]={x=20,y=3,z=0};bw.positions[1]={x=20,y=3,z=0}
        a:command('Punch',{x=1,z=0});b:command('Punch',{x=1,z=0});astep(.6,.6);bstep(.6,.6)
        assert(count(a.projectiles)>0 and count(b.projectiles)>0)
        a:close('Transition');eq(count(a.projectiles),0);assert(count(b.projectiles)>0)
        eq(count(aw.rendered),0);assert(count(bw.rendered)>0)
        astep(4,3.4);eq(as.combat[1].rawLife,47);eq(a:command('Punch'),'RUN_CLOSED')
        eq(a:step(0/0,0),'INVALID_TIME');eq(b:step(.5,0),'TIME_REVERSED')
    end)

    test('trusted command time starts a fresh telegraph instead of inheriting an old frame',function()
        local b,_,s,step=fixture('RoboManus',true)
        s.now=10;eq(b:command('Punch',{x=1,z=0},10),'OK')
        step(10.1,.1);eq(b:snapshot().bossState,'Tell');eq(count(b.projectiles),0)
        eq(b:command('Dash',{x=1,z=0},9),'TIME_REVERSED')
    end)

    test('light reaction allows a real combo while a heavy reaction prevents repeated hits',function()
        local b,_,_,step=fixture('BigBlag',true)
        b:hit(1,-99,'HeroJab');step(.55,.55)
        eq(b:hit(1,-99,'HeroJab'),true);eq(b:snapshot().bossRawLife,251)
        eq(b:selectAction('Punch'),'HeroJab')
        for n=2,6 do step(n*.55,.55);eq(b:hit(1,-99,'HeroJab'),true) end
        eq(b:snapshot().bossRawLife,241);eq(b:selectAction('Punch'),'HeroUppercut')
        step(3.85,.55);eq(b:hit(1,-99,'HeroUppercut'),true)
        eq(b:hit(1,-99,'HeroUppercut'),false)
    end)

    test('frontal attack geometry rejects a target behind the attacker or behind a blocker',function()
        local b,w=fixture('BigBlag',true)
        w.facings={[1]={x=1,z=0}}
        w.positions[1]={x=4,y=3,z=0}
        eq(b:hit(1,-99,'HeroUppercut'),false)
        w.facings[1]={x=-1,z=0};eq(b:hit(1,-99,'HeroUppercut'),true)
        local other,ow=fixture('BigBlag',true);ow.blocked=true
        eq(other:hit(1,-99,'HeroUppercut'),false)
    end)

    test('equal FF damage rounds to0F without underflow and raw-life bosses require a lethal hit',function()
        local b,_,_,step=fixture('BigBlag',true)
        eq(b:hit(1,-99,'HeroPowerPunch'),true);eq(b:snapshot().bossRawLife,15);eq(b.defeated,false)
        step(1,1);eq(b:snapshot().bossRawLife,15)
        b:hit(1,-99,'HeroBoot');eq(b.defeated,true)
        local ball,_,_,ballStep=fixture('Buzzball',true)
        for n=1,12 do ball:hit(1,-99,'HeroUppercut');ballStep(n,1) end
        eq(ball:snapshot().bossRawLife,15);eq(ball.defeated,false)
        ball:hit(1,-99,'HeroUppercut');eq(ball.defeated,true)
    end)

    test('each landing attack hits in its area and leaves an elevated hero unharmed',function()
        for _,kind in ipairs({'BigBlag','RoboManus','Buzzball'}) do
            local b,w,s,step=fixture(kind,true)
            local action=kind=='BigBlag' and 'Punch' or 'Dash'
            w.positions[1]={x=12,y=3,z=0};w.positions[2]={x=12,y=12,z=0}
            b:command(action,{x=1,z=0})
            for n=1,50 do step(n*.05,.05) end
            eq(s.combat[1].rawLife,31);eq(s.combat[2].rawLife,47)
        end
    end)

    test('Queen spin follows a curved sweep rather than hitting the line across its orbit',function()
        local b,w,s,step=fixture('DarkQueen',true)
        w.positions[1]={x=8,y=3,z=4};w.positions[2]={x=0,y=3,z=4}
        b:command('Dash',{x=1,z=0});step(2.6,2.6)
        eq(s.combat[1].rawLife,31);eq(s.combat[2].rawLife,47)
        eq(b:snapshot().bossState,'Recovery')
        eq(b:hit(2,-99,'HeroUppercut'),true)
    end)

    test('ordinary enemy attacks and boss attacks use the same bodies without changing hero stocks',function()
        local b,w,s,step=fixture('GeneralSlaughter',true)
        b.externalEnemies={[-1]={rawLife=31,dead=false}};w.positions[-1]={x=12,y=3,z=0}
        local hits={};b.enemyHit=function(attacker,target,action,tuning) hits[#hits+1]={attacker,target,action,tuning};return true end
        w.positions[1]={x=12,y=3,z=10};w.positions[2]={x=70,y=3,z=0}
        b:command('Punch',{x=1,z=0});step(1.5,1.5)
        eq(#hits,1);eq(hits[1][2],-1);eq(hits[1][3],'PigRush')
        step(3,1.5);w.positions[-1]={x=w.positions[-99].x-3,y=3,z=0}
        eq(b:hit(-1,-99,'WalkerHeavy'),true);eq(b:snapshot().bossRawLife,239)
        eq(s.state.heroes[1].respawns,3);eq(s.combat[1].rawLife,47)
    end)

    test('all five human and NPC bosses preserve the same damage progress and first attack profiles',function()
        for _,kind in ipairs({'BigBlag','RoboManus','GeneralSlaughter','Buzzball','DarkQueen'}) do
            local npc,nw,_,nstep=fixture(kind,false);local human,hw,_,hstep=fixture(kind,true)
            nstep(.5,0);hstep(.5,0);human:command('Punch',{x=1,z=0},.5)
            eq(npc:snapshot().bossAttack,human:snapshot().bossAttack)
            for n=1,80 do
                nstep(.5+n*.05,.05);hstep(.5+n*.05,.05)
                if npc:snapshot().bossState=='Ready' and human:snapshot().bossState=='Ready' then break end
            end
            nw.positions[1]={x=nw.positions[-99].x-3,y=nw.positions[-99].y,z=nw.positions[-99].z}
            hw.positions[1]={x=hw.positions[-99].x-3,y=hw.positions[-99].y,z=hw.positions[-99].z}
            eq(npc:hit(1,-99,'HeroUppercut'),true);eq(human:hit(1,-99,'HeroUppercut'),true)
            eq(npc:snapshot().bossRawLife,human:snapshot().bossRawLife)
            eq(npc:snapshot().bossProgress,human:snapshot().bossProgress)
            eq(nw.lastProfile,2);eq(hw.lastProfile,2)
        end
    end)
    test('authored raised boss platform bounds charges and landing height in campaign coordinates',function()
        local b,w,_,step=fixture('GeneralSlaughter',true,true,{x=450,y=98,z=28,w=30,h=2,d=24})
        b:command('Punch',{x=1,z=0});step(1.5,1.5)
        assert(w.positions[-99].x<=462,'charge must stay inside platform with actor margin')
        eq(w.positions[-99].y,102)
        local jumper,jw,_,jstep=fixture('RoboManus',true,true,{x=450,y=98,z=28,w=30,h=2,d=24})
        jumper:command('Dash',{x=1,z=0});jstep(2,2)
        assert(jw.positions[-99].x<=462);assert(math.abs(jw.positions[-99].y-102)<.001)
    end)
    test('knockback cannot strand either controller below the authored boss arena',function()
        for _,human in ipairs({true,false}) do
            local b,w,_,step=fixture('RoboManus',human)
            b:hit(1,-99,'HeroUppercut')
            w.positions[-99]={x=100,y=-40,z=-100};step(.2,.2)
            eq(w.positions[-99].x,24);eq(w.positions[-99].z,-20);eq(w.positions[-99].y,3)
            eq(b:snapshot().bossProgress,12);eq(b:snapshot().bossRawLife,0);eq(b.defeated,false)
            w.positions[1]={x=20,y=3,z=-20};step(.6,.4)
            eq(b:snapshot().bossRawLife,7)
            if human then eq(b:command('Punch',{x=-1,z=0},.7),'OK')
            else step(1,.4);eq(b:snapshot().bossState,'Tell') end
        end
    end)
    test('boss bolts stop on solid geometry and can still hit a body before the wall',function()
        local b,w,s,step=fixture('RoboManus',true);w.wallX=10;w.positions[1]={x=20,y=3,z=0}
        b:command('Punch',{x=1,z=0});step(.6,.6);step(1.2,.6)
        eq(s.combat[1].rawLife,47);eq(count(b.projectiles),0)
        local front,fw,fs,fstep=fixture('RoboManus',true);fw.wallX=10;fw.positions[1]={x=6,y=3,z=0}
        front:command('Punch',{x=1,z=0});fstep(1.2,1.2)
        eq(fs.combat[1].rawLife,31)
    end)
    test('the ordinary Punch control reaches both boss moves through the same NPC decision cycle',function()
        local second={BigBlag='BellyDrop',RoboManus='Jump',GeneralSlaughter='Headbutt',Buzzball='Bounce',DarkQueen='Spin'}
        for kind,want in pairs(second) do
            local b,w,_,step=fixture(kind,true)
            if kind=='BigBlag' then for n=1,4 do b:hit(1,-99,'HeroUppercut');step(n,.5) end end
            w.positions[1]={x=1000,y=3,z=0};w.positions[2]={x=1000,y=3,z=20}
            local start=b.now;eq(b:command('Punch',{x=1,z=0},start),'OK')
            for n=1,80 do step(start+n*.05,.05);if b:snapshot().bossState=='Ready' then break end end
            eq(b:command('Punch',{x=1,z=0},b.now),'OK');eq(b:snapshot().bossAttack,want,kind)
        end
    end)
    print('CampaignBoss: '..passed..' passed')
end
