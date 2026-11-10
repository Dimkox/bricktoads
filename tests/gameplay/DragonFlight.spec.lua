return function(Flight,Director,Session,Core,Combat,Config,FakeWorld,SourceCombat)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture()
        local w=FakeWorld.new();w.positions={[1]={x=3,y=3,z=0},[2]={x=10,y=3,z=0}};w.grounded={};w.links={};w.shots={}
        function w:spawnEnemy(id,kind,p) self.actors[id]={id=id,kind=kind,alive=true};self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity() end
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress(index,complete) self.progressComplete=complete end
        function w:reached() return false end
        function w:enemyHealth() end
        function w:cue() end
        function w:face() end
        function w:enemyMove() end
        function w:dragonGrounded(id) return self.grounded[id]~=false end
        function w:dragonFloor() return 3 end
        function w:dragonAscentBlocked(id,height)
            self.ascentHeight=height
            return self.motionFailure=='ASCENT_BLOCKED'
        end
        function w:dragonMotion(id,x,z,y,speed)
            self.motion={id=id,x=x,z=z,y=y,speed=speed}
            if self.motionFailure then return false,self.motionFailure end
            return true
        end
        function w:stopDragon(id) self.stopped=id end
        function w:dragonLink(id,slot,mode) if self.linkFails then return false end;self.links[slot]={id=id,mode=mode};return true end
        function w:dragonUnlink(slot) self.links[slot]=nil;return true end
        function w:dragonCanMount(slot,id,range) return not self.mountBlocked and math.abs(self.positions[id].x-self.positions[slot].x)<=range end
        function w:dragonMuzzle(id) local p=self.positions[id];return {x=p.x,y=p.y,z=p.z},{x=1,y=0,z=0},self.muzzleBlocked end
        function w:dragonFire(id,p) self.shots[id]=p end
        function w:removeDragonFire(id) self.shots[id]=nil end
        function w:dragonFireTargets(from,to,radius,exclude) self.segment={from=from,to=to,exclude=exclude};return self.fireVictims or {},self.wallHit==true end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},{userId=2,template='Mr. Green'}},'flight-test',w)
        s:step(0)
        local cfg=table.clone(Config);cfg.Level={zones={{enemies={{id=-1,kind='Dragon',x=0,y=3,z=0,rawLife=31},
            {id=-2,kind='Pig',x=-30,y=3,z=0,rawLife=31}},exit={}}}}
        s.config=cfg
        local d=Director.new(s,w,Combat,cfg,nil,nil,nil,nil,Flight)
        SourceCombat.bind(s,d,cfg)
        s.contextualAttack=function(slot,now,action) return d:interact(slot,now,action) end
        local hit=s._hit
        s._hit=function(self,a,b,action,tuning) if b<0 then return d:hit(a,b,action,tuning) end;return hit(self,a,b,action,tuning) end
        local seq={0,0}
        local function intent(now,kind,attack,slot)
            slot=slot or 1;seq[slot]+=1;local h=s.state.heroes[slot]
            local p={kind=kind or 'Attack',attack=attack or 'Punch',runId=s.state.runId,
                levelEpoch=s.state.levelEpoch,actorId=h.actorId,attempt=h.attempt,connectionEpoch=h.connectionEpoch,seq=seq[slot]}
            if kind=='Move' then p.attack=nil;p.x=1;p.z=0 elseif kind=='Jump' then p.attack=nil end
            return s:intent(slot,p,now)
        end
        local function tick(now,dt) d.now=now;s:step(now);d:step(now,dt or .05) end
        local function mount(now)
            now=now or 1
            assert(d:hit(2,-1,'HeroUppercut'));tick(now)
            assert(intent(now,'Attack')=='OK','Grounded disabled Dragon must be mountable through public F')
        end
        return d,s,w,tick,intent,mount
    end
    test('runtime installs finite Dragon control without adding an enemy',function()
        local d,s,w=fixture()
        assert(d.dragons~=nil,'Dragon flight is not wired into the real Director')
        local body=w.actors[-1];d.dragons:step(0,.05);d.dragons:enemyStep(-1,d.enemies[-1],.05)
        assert(w.motion and w.motion.speed>0 and w.actors[-1]==body)
    end)
    test('blocked ascent cancels pending strike and lift without damage or a free mount',function()
        local d,s,w,tick=fixture();local e=d.enemies[-1];local body=w.actors[-1];local actor=e.actorId
        assert(d:claim(71,-1)=='OK');d:_beginStrike(-1,e,1)
        local row=d.dragons.states[-1];row.liftUntil=10;row.move={x=1,z=0,at=0};e.dragonMove={x=1,z=0,at=0}
        assert(e.windup,'Fixture must contain a real pending Dragon strike')
        w.motionFailure='ASCENT_BLOCKED';tick(.1)
        assert(not e.windup and not row.capture and not row.liftUntil and not row.move and not e.dragonMove,
            'Blocked lift must cancel the pending attack and all accepted steering/lift')
        assert(w.stopped==-1 and row.mode=='Turn' and row.ascentBlocked and not row.disabledUntil,
            'Physical obstruction must stop flight without granting heavy-hit Disabled')
        assert(w.actors[-1]==body and e.actorId==actor and e.rawLife==31 and not e.dead and not e.reactionUntil)
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3 and s.state.heroes[1].attempt==1)
        assert(d.dragons:interaction(1).available==false,'Blocked ascent alone cannot grant a mount')
    end)
    test('blocked ascent logs once and resumes policy only after accepted clear motion',function()
        local d,s,w,tick=fixture();w.motionFailure='ASCENT_BLOCKED';tick(.1)
        local row=d.dragons.states[-1]
        tick(.2);tick(.5)
        assert(row.ascentBlocked and not d.enemies[-1].windup and w.motion.x==0 and w.motion.z==0,
            'Repeated blocked frames may only retry the physical clearance, never attacks or pursuit')
        local function count(kind)
            local total=0;for _,event in ipairs(s.logs) do if event.kind==kind then total+=1 end end;return total
        end
        assert(count('DragonFlightBlocked')==1,'One continuous obstruction needs one event')
        local attacks=count('EnemyAttackAccepted')
        w.motionFailure='UNAVAILABLE';tick(.6)
        assert(row.ascentBlocked and count('DragonFlightBlocked')==1,'Unrelated refusal cannot clear the blocked episode')
        w.motionFailure=nil;tick(.7)
        assert(not row.ascentBlocked and count('EnemyAttackAccepted')==attacks and w.motion.x==0,
            'The successful clearance probe must precede resuming enemy policy')
        tick(1.1);assert(count('EnemyAttackAccepted')>attacks,'Ordinary attacks must resume after clearance')
        w.motionFailure='ASCENT_BLOCKED';tick(1.15)
        assert(count('DragonFlightBlocked')==2,'A later obstruction after accepted motion is a new episode')
    end)
    test('blocked mounted flight releases the real rider and never grants remount',function()
        local d,s,w,tick,intent,mount=fixture();mount();assert(intent(1.1,'Move')=='OK')
        local e=d.enemies[-1];local hero=s.state.heroes[1];local heroId,enemyId=hero.actorId,e.actorId
        local raw,stock=s.combat[1].rawLife,hero.respawns;local enemyRaw=e.rawLife
        w.motionFailure='ASCENT_BLOCKED';tick(1.2)
        local row=d.dragons.states[-1]
        assert(not w.links[1] and not d.dragons.heroes[1] and not row.slot and row.mode=='Turn')
        assert(not row.move and not e.dragonMove and not row.liftUntil and w.stopped==-1)
        assert(hero.actorId==heroId and e.actorId==enemyId and s.combat[1].rawLife==raw
            and hero.respawns==stock and e.rawLife==enemyRaw and not e.dead)
        assert(d.dragons:interact(1,1.2,'Punch')=='NO_INTERACTION','Only a new canonical heavy hit can make a mount available')
    end)
    test('blocked captured flight releases without a second hit or paid appearance',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'))
        w.targetsFor[-1]={1};assert(d.dragons:beginCapture(-1,d.enemies[-1],1));tick(.3)
        assert(w.links[1] and w.links[1].mode=='Captured','Fixture must complete the real capture path')
        local hero=s.state.heroes[1];local raw,stock,actor=s.combat[1].rawLife,hero.respawns,hero.actorId
        w.motionFailure='ASCENT_BLOCKED';tick(.35)
        local row=d.dragons.states[-1]
        assert(not w.links[1] and not d.dragons.heroes[1] and not row.slot and not row.releaseAt and row.mode=='Turn')
        assert(s.combat[1].rawLife==raw and hero.respawns==stock and hero.actorId==actor and hero.attempt==1)
        assert(d.enemies[-1].rawLife==31 and not d.enemies[-1].reactionUntil and not d.enemies[-1].dead)
    end)
    test('blocked lift cancels a pending capture before it can attach later',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'))
        w.targetsFor[-1]={1};assert(d.dragons:beginCapture(-1,d.enemies[-1],1))
        local raw=s.combat[1].rawLife;w.motionFailure='ASCENT_BLOCKED';tick(.1)
        assert(not d.dragons.states[-1].capture,'A rejected lift must cancel the real capture windup')
        tick(.3);w.motionFailure=nil;tick(.4)
        assert(not w.links[1] and not d.dragons.heroes[1] and s.combat[1].rawLife==raw)
        for _,event in ipairs(s.logs) do assert(event.kind~='DragonCaptured','Cleared motion cannot resurrect a canceled capture') end
    end)
    test('first blocked ascent after strike deadline prevents the due damage commit',function()
        local d,s,w,tick=fixture();local e=d.enemies[-1]
        assert(d:claim(71,-1)=='OK');w.targetsFor[-1]={1};d:_beginStrike(-1,e,1)
        local deadline=e.windup.at;local before=s.combat[1].rawLife
        w.motionFailure='ASCENT_BLOCKED';tick(deadline+.01)
        assert(s.combat[1].rawLife==before and not s.combat[1].reactionEnd,
            'Clearance must reject a due strike before real Session damage is committed')
        assert(not e.windup and d.dragons.states[-1].ascentBlocked and not e.dead and e.rawLife==31)
        assert(s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3)
    end)
    test('first blocked ascent after capture deadline never commits the capture',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'));w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1))
        local deadline=d.dragons.states[-1].capture.at;local raw=s.combat[1].rawLife
        w.motionFailure='ASCENT_BLOCKED';tick(deadline+.01)
        assert(not w.links[1] and not d.dragons.heroes[1] and not d.dragons.states[-1].capture)
        for _,event in ipairs(s.logs) do
            assert(event.kind~='DragonCaptured','A blocked due capture must never link and then release as a substitute for rejection')
        end
        assert(s.combat[1].rawLife==raw and s.state.heroes[1].respawns==3 and s.state.heroes[1].attempt==1)
    end)
    test('captured clearance queries include capture height exactly once',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'));w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1));tick(.3)
        assert(d.dragons.states[-1].mode=='Captured')
        w.motionFailure='ASCENT_BLOCKED';tick(.35)
        assert(w.ascentHeight==3+d.config.DragonFlight.altitude+d.config.DragonFlight.captureHeight)
        assert(not w.links[1] and not d.dragons.states[-1].slot and d.dragons.states[-1].ascentBlocked)
    end)
    test('due capture checks its intended lift before linking beneath a lower roof',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'));w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1))
        function w:dragonAscentBlocked(id,height) self.ascentHeight=height;return height>6 end
        local raw,stock,actor=s.combat[1].rawLife,s.state.heroes[1].respawns,s.state.heroes[1].actorId
        tick(.3)
        assert(not w.links[1] and not d.dragons.heroes[1],
            'The normal4.5 lift may be clear while the intended7.5 capture lift is blocked')
        assert(w.ascentHeight==3+d.config.DragonFlight.altitude+d.config.DragonFlight.captureHeight)
        for _,event in ipairs(s.logs) do assert(event.kind~='DragonCaptured','Blocked intended lift must precede the capture commit') end
        assert(s.combat[1].rawLife==raw and s.state.heroes[1].respawns==stock and s.state.heroes[1].actorId==actor)
    end)
    test('clear due capture applies intended height once to query and first motion',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'));w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1));tick(.3)
        local height=3+d.config.DragonFlight.altitude+d.config.DragonFlight.captureHeight
        assert(d.dragons.states[-1].mode=='Captured' and w.links[1])
        assert(w.ascentHeight==height and w.motion.y==height,'The transition must use the checked capture height immediately')
        tick(.35);assert(w.ascentHeight==height and w.motion.y==height,'An already captured frame must not add its height twice')
    end)
    test('missed due capture keeps normal flight height',function()
        local d,s,w,tick=fixture();assert(s:_hit(2,1,'HeroUppercut'));w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1));w.targetsFor[-1]={};tick(.3)
        assert(not w.links[1] and d.dragons.states[-1].mode~='Captured')
        assert(w.motion.y==3+d.config.DragonFlight.altitude,'A failed effect-time capture cannot apply the prospective capture lift')
    end)
    test('legacy worlds without clearance query retain the motion rejection backstop',function()
        local d,s,w,tick=fixture();w.dragonAscentBlocked=nil;w.motionFailure='ASCENT_BLOCKED';tick(.1)
        assert(d.dragons.states[-1].ascentBlocked and not d.enemies[-1].windup and w.stopped==-1)
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3)
    end)
    test('surviving heavy hit mounts the same body without healing or spending resources',function()
        local d,s,w,tick,intent,mount=fixture();local body=w.actors[-1];local actor=d.enemies[-1].actorId
        assert(d:claim(71,-1)=='OK');mount()
        assert(w.links[1].mode=='Mounted' and d.dragons:isMounted(-1))
        assert(w.actors[-1]==body and d.enemies[-1].actorId==actor and d.enemies[-1].ownerUserId==71)
        assert(d.enemies[-1].rawLife==15 and s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3)
        assert(intent(1.1,'Move')=='OK');tick(1.15);assert(w.motion.x==1)
        assert(intent(1.2,'Jump')=='OK' and not w.links[1] and not d.dragons:isMounted(-1))
    end)
    test('mount rejects airborne obstructed or already reserved bodies',function()
        local d,s,w,tick,intent=fixture();d:hit(2,-1,'HeroUppercut');tick(1)
        w.grounded[-1]=false;assert(d:interact(1,1,'Punch')=='NO_INTERACTION')
        w.grounded[-1]=true;w.mountBlocked=true;assert(d:interact(1,1,'Punch')=='NO_INTERACTION')
        w.mountBlocked=false;assert(intent(1,'Attack')=='OK')
        w.positions[2].x=3;assert(d:interact(2,1,'Punch')=='NO_INTERACTION' and not w.links[2])
    end)
    test('mounted human enemy retains life and rejects a new control command',function()
        local d,s,w,tick,intent,mount=fixture();d:claim(71,-1);mount()
        local e=d.enemies[-1]
        local p={kind='Move',x=1,z=0,runId=s.state.runId,levelEpoch=1,actorId=e.actorId,attempt=1,connectionEpoch=e.connectionEpoch,seq=1}
        assert(d:command(71,p,1.1,Session.validIntent)=='MOUNTED')
        assert(d.enemies[-1].ownerUserId==71 and not e.dead and d:claim(72,-1)=='ENEMY_OCCUPIED')
    end)
    test('disconnect stops rider steering after timeout but keeps the vulnerable body',function()
        local d,s,w,tick,intent,mount=fixture();mount();intent(1.1,'Move');s:connection(1,false,1.2);tick(1.7)
        assert(w.links[1] and w.motion.x==0 and s.state.heroes[1].respawns==3)
        assert(intent(1.8,'Move')=='OFFLINE')
    end)
    test('mounted fire has fixed profile22 and global two-shot cap',function()
        local d,s,w,tick,intent,mount=fixture();mount()
        assert(intent(1.6,'Attack')=='OK' and intent(2.2,'Attack')=='OK')
        assert(intent(2.8,'Attack')=='PROJECTILE_LIMIT')
        s.combat[2].rawLife=15;w.fireVictims={2};tick(2.9,.1)
        assert(s.combat[2].deathAt and w.lastProfile==22,'Fire must underflow15 by raw16, not Dash finisher')
        local n=0;for _ in pairs(w.shots) do n+=1 end;assert(n<=1)
    end)
    test('fire respects shields walls ordinary damage and immutable accepted response',function()
        local d,s,w,tick,intent,mount=fixture();mount();intent(1.6,'Attack')
        d.config.Impulses=table.clone(d.config.Impulses);d.config.Impulses[4]={horizontal=999,vertical=999}
        w.fireVictims={-2};tick(1.7,.1)
        assert(d.enemies[-2].rawLife==15 and w.lastProfile==4 and w.lastCalibration.horizontal==32)
        assert(intent(2.2,'Attack')=='OK');w.fireVictims={};w.wallHit=true;tick(2.3,.1)
        assert(next(w.shots)==nil,'Wall impact must consume the fireball')
    end)
    test('hero fire impulse uses a cloned accepted direction after the rider turns and tuning changes',function()
        local d,s,w,tick,intent,mount=fixture();mount()
        local direction={x=1,y=0,z=0}
        function w:dragonMuzzle(id) return table.clone(self.positions[id]),direction,false end
        assert(intent(1.6,'Attack')=='OK')
        local _,shot=next(d.dragons.shots);local response=shot.tuning.responses[22]
        assert(shot.tuning.impulseDirection and shot.tuning.impulseDirection~=direction
            and shot.tuning.impulseDirection~=shot.direction,'Accepted impulse direction must have its own immutable copy')
        direction.x=-1;w.actors[1].facing={x=-1,z=0}
        d.config.Impulses=table.clone(d.config.Impulses);d.config.Impulses[22]={horizontal=999,vertical=999}
        w.fireVictims={2};tick(1.7,.1)
        assert(s.combat[2].rawLife==31 and w.lastProfile==22 and w.lastCalibration==response and response.horizontal==32)
        assert(w.lastImpulseDirection and w.lastImpulseDirection.x==1 and w.lastImpulseDirection.z==0,
            'Actual Session damage must forward the shot direction rather than the later rider facing')
        assert(w.lastImpulse[2]==1 and w.actors[1].facing.x==-1,'Attribution stays with the original slot without rotating its body')
    end)
    test('NPC fire impulse survives an actual new rider appearance with captured response and direction',function()
        local d,s,w,tick,intent,mount=fixture();mount();assert(intent(1.6,'Attack')=='OK')
        local actor=s.state.heroes[1].actorId;local _,shot=next(d.dragons.shots);local response=shot.tuning.responses[4]
        s:_die(1,'Fixture');w.fireVictims={-2};tick(1.7,.1)
        assert(s.state.heroes[1].attempt==2 and s.state.heroes[1].actorId~=actor)
        assert(d.enemies[-2].rawLife==15 and w.lastProfile==4 and w.lastCalibration==response)
        assert(w.lastImpulseDirection and w.lastImpulseDirection.x==1 and w.lastImpulseDirection.z==0,
            'Director NPC damage must forward the original shot direction after rider respawn')
        assert(w.lastImpulse[2]==1,'A replacement body does not change original attribution')
    end)
    test('accepted hero and NPC fire impacts retain direction after the attacker body is removed',function()
        for _,target in ipairs({2,-2}) do
            local d,s,w,tick,intent,mount=fixture();mount();assert(intent(1.6,'Attack')=='OK')
            s:_die(1,'Fixture');w.actors[1]=nil;w.positions[1]=nil;w.fireVictims={target}
            assert(s:_clock(1.7)=='OK');d.now=1.7;d.dragons:step(1.7,.1)
            assert((target==2 and s.combat[2].rawLife==31) or (target==-2 and d.enemies[-2].rawLife==15))
            assert(w.lastImpulseDirection and w.lastImpulseDirection.x==1 and w.lastImpulse[2]==1,
                'Accepted shot response cannot depend on an extant attacker body')
        end
    end)
    test('incoming hero hit releases the mount before applying the physical response',function()
        local d,s,w,tick,intent,mount=fixture();mount()
        local impulse=w.impulse
        function w:impulse(id,a,c,p) assert(not self.links[id],'Linked hero still anchored during impulse');return impulse(self,id,a,c,p) end
        assert(s:_hit(2,1,'HeroJab') and not w.links[1] and not d.dragons:isMounted(-1))
        assert(s.combat[1].rawLife==43 and s.state.heroes[1].respawns==3)
    end)
    test('capture rechecks the effect victim and never adds a second damage event',function()
        local d,s,w,tick=fixture();s:_hit(2,1,'HeroUppercut')
        w.targetsFor[-1]={1};assert(d.dragons:beginCapture(-1,d.enemies[-1],1))
        local before=s.combat[1].rawLife;tick(.3)
        assert(w.links[1] and w.links[1].mode=='Captured' and s.combat[1].rawLife==before)
        tick(2);assert(not w.links[1] and s.state.heroes[1].respawns==3)
    end)
    test('capture miss and later interruption cannot attach a stale actor',function()
        local d,s,w,tick=fixture();s:_hit(2,1,'HeroUppercut');w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1));w.targetsFor[-1]={};tick(.3);assert(not w.links[1])
        d.enemies[-1].nextAttack=0;w.targetsFor[-1]={1}
        assert(d.dragons:beginCapture(-1,d.enemies[-1],1));d:hit(2,-1,'HeroJab');tick(.6)
        assert(not w.links[1])
    end)
    test('actor replacement and run close clean temporary links and all projectiles',function()
        local d,s,w,tick,intent,mount=fixture();mount();intent(1.6,'Attack')
        s.state.heroes[1].actorId='replacement';tick(1.7)
        assert(not w.links[1] and not d.dragons:isMounted(-1))
        d.result='Lost';d:step(1.8,.1)
        assert(next(w.shots)==nil)
    end)
    test('public schema rejects internal Dragon actions before any side effect',function()
        local d,s,w,tick,intent,mount=fixture();mount()
        assert(intent(1.6,'Attack','DragonFire')=='INVALID_INTENT' and next(w.shots)==nil)
    end)
    test('both respawn shields retain fire damage and impulse policy',function()
        for _,kind in ipairs({'Normal','Emergency'}) do
            local d,s,w,tick,intent,mount=fixture();mount()
            w.hazards[2]='Fall';s:step(1.1);w.safe=kind=='Normal';s:step(1.2)
            assert(s.state.heroes[2].shield.kind==kind)
            local impulses=w.impulses;assert(intent(1.6,'Attack')=='OK');w.fireVictims={2};tick(1.7,.1)
            assert(s.combat[2].rawLife==47 and s.state.heroes[2].respawns==2)
            assert(w.impulses-impulses==(kind=='Normal' and 1 or 0))
        end
    end)
    test('mount neutralizes a gate only while the same surviving Dragon remains mounted',function()
        local d,s,w,tick,intent,mount=fixture();d:_kill(-2,'Combat');mount()
        tick(1.1);assert(w.progressComplete and not d.enemies[-1].dead)
        intent(1.2,'Jump');tick(1.3)
        assert(w.progressComplete==false,'Dismount before crossing must close the current gate again')
    end)
    test('mounted motion keeps processing after the ground encounter reaches the boss',function()
        local d,s,w,tick,intent,mount=fixture();mount();intent(1.1,'Move');tick(1.2)
        assert(w.motion.x==1);d.stage='Boss';tick(2)
        assert(w.motion.x==0,'Stage transition cannot leave an old flight velocity running forever')
    end)
    test('an obstructed accepted shot consumes attack timing without spawning beyond the wall',function()
        local d,s,w,tick,intent,mount=fixture();mount();w.muzzleBlocked=true
        assert(intent(1.6,'Attack')=='OK')
        assert(next(w.shots)==nil and s.combat[1].nextAttack>1.6,'Blocked muzzle cannot spawn fire or fall back to melee')
        assert(intent(1.61,'Attack')=='COOLDOWN')
    end)
    print('DragonFlight: '..passed..' PASS')
end
