return function(Enemies,Director,Session,Core,Combat,Config,FakeWorld,Boss)
    local passed=0
    local function eq(a,b,label) assert(a==b,(label or '')..' expected '..tostring(b)..', got '..tostring(a)) end
    local function count(t) local n=0;for _ in pairs(t) do n+=1 end;return n end
    local function fixture(kind,human,rawLife)
        local w=FakeWorld.new();w.positions={[1]={x=20,y=3,z=0},[2]={x=70,y=3,z=0}};w.shots={};w.releases={}
        w.groundSpeeds={};w.groundInputs={}
        local move=w.move
        function w:move(id,x,z,run) move(self,id,x,z,run);self.groundInputs[id]={x=x,z=z} end
        function w:campaignWalkSpeed(id,speed) self.groundSpeeds[id]=speed end
        function w:campaignProjectileBlocked(a,b)
            return self.wallX~=nil and (a.x-self.wallX)*(b.x-self.wallX)<=0 and a.x~=b.x
        end
        function w:position(id) return self.positions[id] end
        function w:spawnEnemy(id,name,p) self.positions[id]=table.clone(p);self.actors[id]={alive=true,kind=name};return true end
        function w:enemyIdentity(id,actorId) self.actors[id].id=actorId end
        function w:enemyHealth() end
        function w:progress() end
        function w:stage() end
        function w:reached() return false end
        function w:face(id,target) self.aims=self.aims or {};local a,b=self.positions[id],self.positions[target];local x,z=b.x-a.x,b.z-a.z;local l=math.sqrt(x*x+z*z);self.aims[id]={x=l>0 and x/l or 1,z=l>0 and z/l or 0} end
        function w:aim(id,x,z) self.aims=self.aims or {};self.aims[id]={x=x,z=z} end
        function w:cue() end
        function w:enemyMove(id,target,speed) self.lastEnemyMove={id,target,speed} end
        function w:campaignPose(id,p,mode) self.positions[id]=table.clone(p);self.actors[id].campaignControl=mode end
        function w:placeActor(id,p) self.positions[id]=table.clone(p) end
        function w:campaignRelease(id) self.actors[id].campaignControl=nil;self.releases[id]=(self.releases[id] or 0)+1 end
        function w:projectile(id,p,_,mode) self.shots[id]={position=table.clone(p),mode=mode} end
        function w:removeProjectile(id) self.shots[id]=nil end
        local cfg=table.clone(Config)
        cfg.Level={bounds={minX=-50,maxX=150,minY=-30,maxY=100,minZ=-40,maxZ=40},boss={position={x=130,y=3,z=0}},
            zones={{name='families',objective='test',enemies={{id=-1,kind=kind,x=0,y=3,z=0,rawLife=rawLife or 31}},exit={}}}}
        local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Brown'}},'family-test',w)
        s:step(0);s.state.heroes[1].shield=nil;s.state.heroes[2].shield=nil
        local d=Director.new(s,w,Combat,cfg);local component=Enemies.new(d);d.campaignEnemies=component
        if human then eq(d:claim(99,-1),'OK') end
        local function step(now,dt)
            s.now=now;d:step(now,dt);component:step(now,dt)
            for id,input in pairs(w.groundInputs) do
                if id<0 and d.enemies[id] and w.positions[id] and w.actors[id] and not w.actors[id].campaignControl and not d.enemies[id].reactionUntil then
                    local speed=w.groundSpeeds[id] or 9;w.positions[id].x+=input.x*speed*(dt or 0);w.positions[id].z+=input.z*speed*(dt or 0)
                end
            end
        end
        local function command(kindName,attack,x,z,now)
            local e=d.enemies[-1]
            return d:command(99,{kind=kindName,attack=attack,x=x,z=z,runId=s.state.runId,actorId=e.actorId,
                attempt=1,levelEpoch=s.state.levelEpoch,connectionEpoch=e.connectionEpoch,seq=(e.lastSeq or 0)+1},now,Session.validIntent)
        end
        return component,d,w,s,step,command
    end
    local function test(name,body) body();passed+=1;print('PASS '..name) end

    test('projectile species shoot across a real range instead of closing to ground melee',function()
        for _,kind in ipairs({'Snowman','SentryDrone','GasTurret','Robot','Swellcheeks','RetroBlaster'}) do
            local c,d,w,s,step=fixture(kind,false)
            step(.1,.1);step(.8,.7)
            assert(count(c.projectiles)>0 or s.combat[1].rawLife<47,'missing ranged action '..kind)
            eq(d.enemies[-1].engaged,true);eq(d:claim(100,-1),'ENEMY_ENGAGED')
            for n=1,20 do step(.8+n*.1,.1) end
            assert(s.combat[1].rawLife<47,'ranged attack must reach target '..kind)
            eq(s.state.heroes[1].respawns,3)
        end
    end)
    test('Sentry Drone fires in both horizontal directions and gas does not require a direct center hit',function()
        local c,_,w,s,step=fixture('SentryDrone',false);w.positions[2]={x=-20,y=3,z=0}
        step(.1,.1);step(.8,.7);step(1.5,.7)
        eq(s.combat[1].rawLife,31);eq(s.combat[2].rawLife,31)
        local gas,_,gw,gs,gstep=fixture('GasTurret',false)
        gw.positions[1]={x=12,y=3,z=2};gstep(.1,.1);gstep(.8,.7);gstep(1.5,.7)
        assert(gs.combat[1].rawLife<47);eq(count(gas.projectiles)>0,true)
    end)
    test('ranged human and NPC use identical damage while disconnected shots continue',function()
        for _,kind in ipairs({'Snowman','SentryDrone','GasTurret','Robot'}) do
            local _,nd,nw,ns,nstep=fixture(kind,false);local hc,hd,hw,hs,hstep,hcommand=fixture(kind,true)
            nstep(.1,.1);eq(hcommand('Move',nil,1,0,.1),'OK');eq(hcommand('Attack','Punch',nil,nil,.1),'OK')
            hd:connection(99,false)
            for n=1,45 do nstep(.1+n*.05,.05);hstep(.1+n*.05,.05) end
            eq(ns.combat[1].rawLife,hs.combat[1].rawLife,kind);assert(hs.combat[1].rawLife<47)
            eq(nd.enemies[-1].rawLife,hd.enemies[-1].rawLife);eq(hd.enemies[-1].ownerUserId,99)
            eq(hcommand('Attack','Punch',nil,nil,2.5),'OFFLINE')
            assert(hc:owns(-1,hd.enemies[-1]));eq(nw.lastEnemyMove,nil);eq(hw.lastEnemyMove,nil)
        end
    end)
    test('flying and swimming species use mode positions and recover their physical body after a hit',function()
        for _,kind in ipairs({'Raven','RocketRat','Electrofish','Hammerfish','Shark','Duck','FlyingHead','Swellcheeks'}) do
            local c,d,w,_,step=fixture(kind,true)
            c:command(-1,d.enemies[-1],{kind='Move',x=1,z=0},.1);step(.2,.1)
            assert(w.actors[-1].campaignControl,kind..' must enter its medium')
            assert(w.positions[-1].x>0,kind..' human direction must move the same body')
            d.now=.3;eq(d:hit(1,-1,'HeroUppercut'),true)
            eq(w.actors[-1].campaignControl,nil,kind..' hit must release before impulse');assert(w.releases[-1]>0)
            eq(d.enemies[-1].rawLife,kind=='Raven' and 0 or 15)
            step(.4,.1);eq(w.actors[-1].campaignControl,nil)
        end
    end)
    test('leaps and swoops have finite swept collision and do not auto hit an elevated or distant hero',function()
        for _,kind in ipairs({'Raven','Invader','Hordhead','Hammerfish','Shark','Duck','FlyingHead'}) do
            local c,d,w,s,step,command=fixture(kind,true)
            w.positions[1]={x=8,y=3,z=0};w.positions[2]={x=8,y=15,z=0}
            command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1)
            for n=1,60 do step(.1+n*.05,.05) end
            assert(s.combat[1].rawLife<47,'attack should cross target '..kind);eq(s.combat[2].rawLife,47)
            eq(c:stateFor(-1),'Ready');eq(not d.enemies[-1].dead,true)
        end
    end)
    test('slug latches temporarily and releases when struck rather than becoming an immortal attachment',function()
        local c,d,w,s,step,command=fixture('Slug',true);w.positions[1]={x=7,y=3,z=0}
        command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1)
        for n=1,20 do step(.1+n*.05,.05) end
        eq(c:stateFor(-1),'Latched');assert(s.combat[1].rawLife<47)
        d.now=1.2;d:hit(1,-1,'HeroUppercut');eq(c:stateFor(-1),'Ready')
        eq(d.enemies[-1].rawLife,15)
    end)
    test('rocket dropped obstacle remains a finite hazard and never adds a playable enemy',function()
        local c,d,w,_,step,command=fixture('RocketRat',true)
        w.positions[1]={x=20,y=3,z=10};command('Attack','Punch',nil,nil,.1);step(.8,.7)
        eq(count(d.enemies),1);assert(count(c.projectiles)>0)
        for n=1,60 do step(.8+n*.1,.1) end
        eq(count(c.projectiles),0);eq(count(d.enemies),1)
    end)
    test('Robot explosion is a telegraphed one life action with no resource refill or new role',function()
        local c,d,w,s,step,command=fixture('Robot',true)
        w.positions[1]={x=4,y=3,z=0};eq(command('Attack','Punch',nil,nil,.1),'OK')
        eq(not d.enemies[-1].dead,true);step(.4,.3);eq(s.combat[1].rawLife,47)
        step(1,.6);eq(d.enemies[-1].dead,true);eq(s.combat[1].rawLife,0)
        eq(d:claim(100,-1),'ENEMY_DEAD');eq(s.state.heroes[1].respawns,3);eq(count(d.enemies),1)
    end)
    test('in-flight effects damage other enemies and all components remain isolated',function()
        local c,d,w,_,step,command=fixture('Snowman',true)
        d.enemies[-2]={rawLife=31,maxRawLife=31,health=3,kind='Pig',actorId='other',dead=false}
        w.positions[-2]={x=12,y=3,z=0};w.actors[-2]={alive=true}
        command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1);step(.8,.7);step(1.2,.4)
        eq(d.enemies[-2].rawLife,15)
        local other,_,_,_,otherStep=fixture('Snowman',false);otherStep(.1,.1);otherStep(.8,.7)
        c:close('Transition');eq(count(c.projectiles),0);assert(count(other.projectiles)>0)
        eq(c:step(0/0,0),'INVALID_TIME');eq(other:step(.7,0),'TIME_REVERSED')
    end)
    test('existing Pig Walker and Dragon keep their established controllers',function()
        for _,kind in ipairs({'Pig','Walker','Dragon'}) do local c,d=fixture(kind,false);eq(c:owns(-1,d.enemies[-1]),false) end
    end)
    test('swimming lunges stay inside their authored water body instead of pursuing onto dry land',function()
        local _,d,w,s,step,command=fixture('Shark',true)
        d.config.Level.course={media={{kind='Water',minX=-10,maxX=10,minY=-12,maxY=0,minZ=-8,maxZ=8}}}
        w.positions[-1]={x=0,y=-5,z=0};w.positions[1]={x=20,y=3,z=0}
        command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1)
        for n=1,40 do step(.1+n*.05,.05) end
        assert(w.positions[-1].x<=8 and w.positions[-1].y<=-2,'swimmer cannot escape water volume')
        eq(s.combat[1].rawLife,47)
    end)
    test('malformed movement and stale owner commands cannot create attacks or invalid positions',function()
        local c,d,w,_,_,command=fixture('Raven',true)
        eq(command('Move',nil,0/0,0,.1),'INVALID_INTENT')
        eq(c:command(-1,d.enemies[-1],{kind='Move',x=0/0,z=0},.1),'INVALID_MOVE')
        eq(command('Attack','Dash',nil,nil,.1),'INVALID_INTENT')
        eq(c:stateFor(-1),'Ready');eq(count(c.projectiles),0);eq(w.positions[-1].x,0)
        eq(command('Attack','Punch',nil,nil,.5),'OK')
        eq(command('Attack','Punch',nil,nil,.4),'TIME_REVERSED')
        local missing,md,mw=fixture('Raven',true);mw.positions[-1]=nil
        eq(missing:command(-1,md.enemies[-1],{kind='Attack',attack='Punch'},.1),'NOT_ALIVE')
    end)
    test('ordinary projectiles can strike a separately directed boss using its real progress model',function()
        local c,d,w,s,step,command=fixture('Snowman',true)
        function w:targets() return {-99} end
        local boss=Boss.new(s,w,d.config,{boss={type='RoboManus',position={x=12,y=3,z=0}},bossGate={ownerUserId=200}})
        c.externalEnemies={[-99]=boss.enemies[-99]}
        c.enemyHit=function(attacker,target,action,tuning)
            if target==-99 then return boss:hit(attacker,target,action,tuning) end
            return d:hit(attacker,target,action,tuning)
        end
        boss.externalEnemies=d.enemies
        command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1);step(.8,.7);step(1.2,.4)
        eq(boss:snapshot().bossProgress,12);eq(boss.defeated,false);eq(s.combat[1].rawLife,47)
    end)
    test('aerial tell and recovery hold altitude but release immediately for a real incoming impulse',function()
        local c,d,w,_,step,command=fixture('FlyingHead',true)
        w.positions[-1]={x=0,y=30,z=0};w.positions[1]={x=8,y=30,z=0}
        eq(command('Attack','Punch',nil,nil,.1),'OK')
        assert(w.actors[-1].campaignControl,'tell must suspend gravity at the current altitude')
        step(.2,.1);assert(w.actors[-1].campaignControl)
        step(1.3,1.1);eq(c:stateFor(-1),'Recovery');assert(w.actors[-1].campaignControl)
        d.now=1.4;d:hit(1,-1,'HeroUppercut');eq(w.actors[-1].campaignControl,nil)
    end)
    test('long boss projectile history cannot reuse a live ordinary projectile identity',function()
        local c,d,w,s,step,command=fixture('Snowman',true)
        local boss=Boss.new(s,w,d.config,{boss={type='RoboManus',position={x=0,y=3,z=0}},bossGate={ownerUserId=200}})
        boss.serial=2000;boss:command('Punch',{x=1,z=0},.1)
        command('Attack','Punch',nil,nil,.1);step(.8,.7);boss:step(.8,.7)
        eq(count(w.shots),count(c.projectiles)+count(boss.projectiles))
    end)
    test('ground owners obey the same family speed and stationary turrets only aim',function()
        for _,row in ipairs({{'Snowman',4},{'Invader',9},{'Hordhead',8},{'GasTurret',0},{'SentryDrone',0}}) do
            local _,_,w,_,step,command=fixture(row[1],true)
            eq(command('Move',nil,1,0,.1),'OK');step(.3,.2)
            assert(math.abs(w.positions[-1].x-row[2]*.2)<.001,row[1]..' wrong movement budget')
            eq(w.positions[-1].z,0)
        end
    end)
    test('solid geometry blocks projectiles while a body before the wall still receives its hit',function()
        local c,_,w,s,step,command=fixture('Snowman',true);w.wallX=10
        command('Attack','Punch',nil,nil,.1);step(.8,.7);step(1.4,.6)
        eq(s.combat[1].rawLife,47);eq(count(c.projectiles),0)
        local _,_,front,fs,fstep,fcommand=fixture('Snowman',true);front.wallX=10;front.positions[1]={x=6,y=3,z=0}
        fcommand('Attack','Punch',nil,nil,.1);fstep(1.4,1.3)
        eq(fs.combat[1].rawLife,31)
    end)
    test('swimming owners use ordinary up input for altitude and remain in their chamber plane',function()
        local _,d,w,_,step,command=fixture('Electrofish',true)
        d.config.Level.course={media={{kind='Water',minX=-10,maxX=40,minY=-12,maxY=5,minZ=-8,maxZ=8}}}
        w.positions[-1]={x=0,y=-6,z=4};w.positions[1]={x=0,y=3,z=0}
        for n=1,10 do command('Move',nil,0,-1,n*.1);step(n*.1,.1) end
        assert(w.positions[-1].y>1,'up input must let a deep fish reach the legal surface target')
        assert(w.positions[-1].z<4,'depth must drift toward authored chamber plane')
        eq(d:controlled(99).movementKind,'Swim')
        command('Attack','Punch',nil,nil,1.1);step(1.8,.7)
        assert(d.session.combat[1].rawLife<47)
    end)
    test('flying owners use the existing Jump input for finite flap and descend without held input',function()
        local _,d,w,_,step,command=fixture('Raven',true)
        w.positions[-1]={x=0,y=10,z=0};w.positions[1]={x=10,y=13,z=0}
        for n=1,4 do command('Jump',nil,nil,nil,n*.3);step(n*.3,.2) end
        assert(w.positions[-1].y>12,'repeated legal flaps must reach an elevated target')
        eq(d:controlled(99).movementKind,'Fly')
        local high=w.positions[-1].y
        for n=1,15 do step(1.2+n*.1,.1) end
        assert(w.positions[-1].y<high,'flight must have passive descent rather than unlimited hover')
        assert(w.positions[-1].y>=-2,'passive descent must remain within finite flight band')
    end)
    test('an already fired projectile can hurt the boss after its original shooter dies',function()
        local c,d,w,s,step,command=fixture('Snowman',true)
        function w:targets() return {-99} end
        local boss=Boss.new(s,w,d.config,{boss={type='RoboManus',position={x=12,y=3,z=0}},bossGate={ownerUserId=200}})
        c.externalEnemies={[-99]=boss.enemies[-99]};boss.externalEnemies=d.enemies
        c.enemyHit=function(attacker,target,action,tuning)
            if target==-99 then return boss:hit(attacker,target,action,tuning) end
            return d:hit(attacker,target,action,tuning)
        end
        command('Attack','Punch',nil,nil,.1);step(.8,.7);d:_kill(-1,'Combat');step(1.2,.4)
        eq(boss:snapshot().bossProgress,12);eq(boss.defeated,false)
        eq(boss:hit(-1,-99,'HeroUppercut'),false)
    end)
    test('Invader steals one linked raw-eight token and a hit returns it once after the thief dies',function()
        local c,d,w,s,step,command=fixture('Invader',true);w.positions[1]={x=8,y=3,z=0}
        command('Move',nil,1,0,.1);command('Attack','Punch',nil,nil,.1)
        for n=1,20 do step(.1+n*.05,.05) end
        eq(s.combat[1].rawLife,39,'theft subtracts exactly eight without melee nibble rounding')
        eq(s.combat[1].reactionEnd,nil,'theft is a linked health-bar operation')
        eq(count(c.lifeTokens),1);eq(s.state.heroes[1].respawns,3)
        d.now=1.2;eq(d:hit(1,-1,'HeroBoot'),true);eq(d.enemies[-1].dead,true)
        for n=1,30 do step(1.2+n*.1,.1) end
        eq(s.combat[1].rawLife,47);eq(count(c.lifeTokens),0)
        step(6,1);eq(s.combat[1].rawLife,47);eq(d:claim(100,-1),'ENEMY_DEAD')
    end)
    test('full ordinary byte capacities retain three hearts and source recovery after human claim',function()
        for _,raw in ipairs({15,47,63,79,111,255}) do
            local _,d,_,_,step=fixture('Swellcheeks',true,raw);local e=d.enemies[-1]
            eq(e.health,3);eq(e.maxRawLife,raw);eq(e.ownerUserId,99)
            d.now=.1;eq(d:hit(1,-1,'HeroJab'),true);eq(e.rawLife,raw-2)
            assert(e.health<3 and e.health>0);step(2,1.9)
            eq(e.rawLife,raw);eq(e.health,3);eq(e.ownerUserId,99)
        end
    end)
    test('Invader linked theft honors shields and low Life and return tokens reject new bodies and capacity overflow',function()
        local _,_,_,s=fixture('Invader',true)
        assert(s._stealLife,'trusted linked theft helper required')
        s.state.heroes[1].shield={kind='Normal',deadline=10}
        eq(s:_stealLife(-1,1),nil);eq(s.combat[1].rawLife,47)
        s.state.heroes[1].shield=nil;s.combat[1].rawLife=7
        eq(s:_stealLife(-1,1),nil);eq(s.combat[1].rawLife,7)
        s.combat[1].rawLife=47;local token=s:_stealLife(-1,1);eq(s.combat[1].rawLife,39)
        s.combat[1].rawLife=43;eq(s:_recoverStolenLife(token),false);eq(s.combat[1].rawLife,43)
        s.combat[1].rawLife=31;eq(s:_recoverStolenLife(token),false,'capacity rejection consumes token')
        token=s:_stealLife(-1,1);local old=s.state.heroes[1].actorId;s.state.heroes[1].actorId='new-body'
        eq(s:_recoverStolenLife(token),false);eq(s.combat[1].rawLife,23);s.state.heroes[1].actorId=old
        eq(s:_recoverStolenLife(token),false);eq(s:_recoverStolenLife({slot=1}),false)
    end)
    test('stolen Life expires without healing and cannot cross a level epoch',function()
        local c,d,w,s,step,command=fixture('Invader',true);w.positions[1]={x=8,y=3,z=0}
        command('Attack','Punch',nil,nil,.1)
        for n=1,20 do step(.1+n*.05,.05) end
        eq(s.combat[1].rawLife,39);eq(count(c.lifeTokens),1)
        step(8,6.9);eq(count(c.lifeTokens),0);eq(s.combat[1].rawLife,39);eq(d.enemies[-1].dead,true)
        local token=s:_stealLife(-1,1);s.state.levelEpoch+=1
        eq(s:_recoverStolenLife(token),false);eq(s.combat[1].rawLife,31)
    end)
    test('wall families retain their authored anchor for both controllers even while reacting',function()
        for _,kind in ipairs({'RetroBlaster','SaturnToadtrap'}) do for _,human in ipairs({false,true}) do
            local _,d,w,_,step,command=fixture(kind,human);local p=table.clone(w.positions[-1])
            if human then command('Move',nil,1,0,.1) end
            step(.2,.2);eq(w.positions[-1].x,p.x);eq(w.positions[-1].y,p.y)
            d.now=.3;d:hit(1,-1,'HeroJab');step(.4,.1)
            eq(w.positions[-1].x,p.x);eq(w.positions[-1].y,p.y);eq(w.actors[-1].campaignControl,'EnemyWall')
        end end
    end)
    test('rocket riders follow one finite authored route with no free flight and one allowed drop',function()
        for _,human in ipairs({false,true}) do
            local c,d,w,_,step,command=fixture('RocketRat',human)
            d.enemies[-1].trajectory={duration=4,from={x=0,y=14,z=12},to={x=160,y=14,z=-12},dropAt=1.5,dropGroundY=3}
            d.enemies[-1].allowedDrop=true
            step(0,0)
            if human then eq(command('Jump',nil,nil,nil,.1),'NO_JUMP');eq(command('Move',nil,-1,0,.1),'OK') end
            step(2,2);eq(w.positions[-1].x,80);eq(w.positions[-1].y,14);eq(w.positions[-1].z,0)
            eq(count(c.projectiles),1);eq(c.states[-1].dropped,true)
            if human then eq(command('Attack','Punch',nil,nil,2.1),'NO_AMMO') end
            step(4,2);eq(d.enemies[-1].dead,true);eq(d.enemies[-1].health,0)
            step(7,3);eq(count(c.projectiles),0)
        end
    end)
    test('Raven changes into finite dead debris on its first valid hit instead of grinding loader Life',function()
        local c,d,w,_,step=fixture('Raven',true,79)
        step(.1,.1);d.now=.2;eq(d:hit(1,-1,'RopeStrike'),true)
        eq(d.enemies[-1].dead,true);eq(d.enemies[-1].rawLife,0);eq(count(c.debris),1)
        eq(d:claim(100,-1),'ENEMY_DEAD');eq(count(d.enemies),1)
        for _,p in pairs(c.debris) do eq(p.mode,'DeadRaven') end
        step(5,4.8);eq(count(c.debris),0)
    end)
    test('Large Raven reaction creates one finite claw pickup that equips only the current hero body',function()
        local c,d,w,s,step=fixture('LargeRaven',true,79)
        step(.1,.1);d.now=.2;eq(d:hit(1,-1,'RopeStrike'),true)
        eq(not d.enemies[-1].dead,true);eq(d.enemies[-1].rawLife,71);eq(count(c.debris),1)
        for n=1,5 do
            for _,item in pairs(c.debris) do w.positions[1]=table.clone(item.position) end
            step(.2+n*.1,.1)
        end
        eq(c:hasRavenClaw(1),true);eq(count(c.debris),0);eq(s.state.heroes[1].respawns,3)
        d.now=.9;d:hit(1,-1,'RopeStrike');eq(count(c.debris),0,'one original actor supplies one claw')
        s.state.heroes[1].actorId='replacement';eq(c:hasRavenClaw(1),false)
        eq(count(d.enemies),1)
    end)
    test('an Invader hit transforms its ordinary one life without treating sentinel Life as linear HP',function()
        local _,d,_,s=fixture('Invader',true,255)
        d.now=.2;eq(d:hit(1,-1,'HeroJab'),true)
        eq(d.enemies[-1].dead,true);eq(d.enemies[-1].rawLife,0);eq(s.combat[1].rawLife,47)
    end)
    test('a replayed natural spawn uses a new actor identity without restoring an old owners life',function()
        local _,d,_,s=fixture('RocketRat',true,15);local old=d.enemies[-1].actorId
        local payload={kind='Attack',attack='Punch',runId=s.state.runId,actorId=old,attempt=1,
            levelEpoch=s.state.levelEpoch,connectionEpoch=1,seq=1}
        d:_kill(-1,'EncounterExpired')
        d:_wave('Route',{{id=-1,kind='RocketRat',x=20,y=14,z=0,rawLife=15,spawnSerial=2}})
        assert(d.enemies[-1].actorId~=old);eq(d.enemies[-1].ownerUserId,nil)
        eq(d:controlled(99).status,'Dead');eq(d:claim(99,-1),'ENEMY_LIFE_SPENT')
        eq(d:command(99,payload,.5,Session.validIntent),'STALE_ACTOR')
        eq(d:claim(100,-1),'OK');eq(d.enemies[-1].ownerUserId,100)
    end)
    test('Invader low-Life source guard skips subtraction while exact eight reaches living zero and can return',function()
        local _,_,_,s=fixture('Invader',true)
        for raw=0,7 do
            s.combat[1].rawLife=raw
            eq(s:_stealLife(-1,1),nil);eq(s.combat[1].rawLife,raw)
            eq(s.combat[1].deathAt,nil);eq(s.state.heroes[1].status,'Alive');eq(s.state.heroes[1].respawns,3)
        end
        s.combat[1].rawLife=8;local token=s:_stealLife(-1,1)
        assert(token);eq(s.combat[1].rawLife,0);eq(s.combat[1].deathAt,nil);eq(s.state.heroes[1].status,'Alive')
        eq(s:_recoverStolenLife(token),true);eq(s.combat[1].rawLife,8);eq(s.state.heroes[1].respawns,3)
    end)
    test('explicit course reset removes only the selected rocket-rat effects while ordinary death and offline preserve shots',function()
        local c,d,w,_,step,command=fixture('RocketRat',true,15)
        eq(command('Attack','Punch',nil,nil,.1),'OK');eq(count(c.projectiles),1)
        d:connection(99,false);eq(count(c.projectiles),1,'disconnect retains accepted drop')
        d:_wave('Route',{{id=-2,kind='RocketRat',x=40,y=14,z=30,rawLife=15},
            {id=-3,kind='Snowman',x=-25,y=20,z=-20,rawLife=15}})
        eq(c:command(-2,d.enemies[-2],{kind='Attack',attack='Punch'},.1),'OK')
        eq(c:command(-3,d.enemies[-3],{kind='Attack',attack='Punch'},.1),'OK')
        step(.8,.7);eq(count(c.projectiles),3)
        d:_kill(-1,'Combat');eq(count(c.projectiles),3,'ordinary death retains accepted drops')
        assert(c.expireEncounter,'explicit course-reset cleanup hook required')
        eq(c:expireEncounter(-1),1);eq(count(c.projectiles),2);eq(count(w.shots),2)
        local owners={};for _,p in pairs(c.projectiles) do owners[p.owner]=true end
        assert(owners[-2] and owners[-3] and not owners[-1])
        eq(c:expireEncounter(-3),0,'non-rocket family cleanup is outside this hook');eq(count(c.projectiles),2)
        eq(c:expireEncounter(-1),0,'course cleanup is idempotent')
    end)
    print('CampaignEnemies: '..passed..' passed')
end
