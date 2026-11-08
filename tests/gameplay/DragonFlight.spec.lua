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
        function w:dragonMotion(id,x,z,y,speed) self.motion={id=id,x=x,z=z,y=y,speed=speed};return true end
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
