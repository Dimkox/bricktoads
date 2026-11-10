return function(Pattern,Session,Core,Combat,Config,FakeWorld,Director,Controller)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture()
        local w=FakeWorld.new();w.positions={}
        local spawn=w.spawn
        function w:spawn(id,actorId,...)
            local ok=spawn(self,id,actorId,...);if ok then self.positions[id]={x=0,y=3,z=0} end;return ok
        end
        function w:position(id) return self.positions[id] end
        function w:groundPosition(p) return {x=p.x,y=1.2,z=p.z} end
        function w:projectile(id,p) self.positions[id]=table.clone(p) end
        function w:removeProjectile(id) self.positions[id]=nil end
        function w:enemyHealth() end
        function w:cue() end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'}},'guardian-session',w)
        s:step(0);w.positions[-99]={x=15,y=3,z=0}
        local d={session=s,world=w,config=Config,now=0,stage='Boss',bossHits=0,serial=0,
            enemies={[-99]={health=3,rawLife=47}},projectiles={}}
        function d:_nearest() return 1,15 end
        function d:_kill(id) self.enemies[id].dead=true;self.stage='Exit' end
        local p=Pattern.new(d)
        s.contextualAttack=function(uid,now,action)
            d.now=now
            if action~='Punch' then return p:interaction(uid).carrying and 'HANDS_FULL' or 'NO_INTERACTION' end
            return p:interact(uid,now)
        end
        local function ground()
            d.projectiles[-1001]={mode='Ground',position={x=0,y=1.2,z=0},created=s.now,expiresAt=30}
        end
        local function packet(attack,seq)
            local h=s.state.heroes[1]
            return {kind='Attack',attack=attack,seq=seq,runId=s.state.runId,actorId=h.actorId,
                attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch}
        end
        return s,w,d,p,ground,packet
    end
    test('actual Session pickup retains normal shield/resources and throw clears it before flight',function()
        local s,w,d,p,ground,packet=fixture()
        s:_die(1,'test');s:step(.1);ground()
        local deadline=s.state.heroes[1].shield.deadline
        assert(s:intent(1,packet('Punch',1),.2)=='OK')
        assert(d.projectiles[-1001].mode=='Carried' and s.state.heroes[1].shield.deadline==deadline)
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==2 and not s.combat[1].attack)
        assert(s:intent(1,packet('Dash',2),.8)=='HANDS_FULL')
        assert(s:intent(1,packet('Punch',3),.8)=='OK')
        assert(d.projectiles[-1001].mode=='Thrown' and not s.state.heroes[1].shield)
        assert(w.actors[1].held==false and s.state.heroes[1].respawns==2 and s.combat[1].rawLife==47)
    end)
    test('stale actor cannot pick up and actual death never transfers held ball to a new appearance',function()
        local s,w,d,p,ground,packet=fixture();ground()
        local bad=packet('Punch',1);bad.actorId='stale'
        assert(s:intent(1,bad,.1)=='STALE_ACTOR' and d.projectiles[-1001].mode=='Ground')
        assert(s:intent(1,packet('Punch',1),.1)=='OK')
        s:_die(1,'test');d.now=.2;p:step(.2,.1)
        assert(d.projectiles[-1001].mode=='Ground' and not p:interaction(1).carrying)
        s:step(.3);assert(not p:interaction(1).carrying and s.state.heroes[1].attempt==2)
        assert(d.enemies[-99].rawLife==47)
    end)
    test('actual Session throw survives small flight steps without hurting or stunning its owner',function()
        local s,w,d,p,ground,packet=fixture()
        w.positions[1]={x=600,y=3,z=0};w.positions[-99]={x=628,y=3,z=0};ground()
        d.projectiles[-1001].position={x=600,y=1.2,z=0}
        assert(s:intent(1,packet('Punch',1),.1)=='OK')
        assert(s:intent(1,packet('Punch',2),.8)=='OK')
        s:step(.9);d.now=.9;p:step(.9,.1)
        assert(s.combat[1].rawLife==47 and not s.combat[1].reactionEnd,
            'An accepted throw cannot become boss damage against its own hero')
        assert(d.projectiles[-1001] and d.projectiles[-1001].mode=='Thrown' and d.bossHits==0)
        for n=1,20 do
            local now=.9+n*.1;s:step(now);d.now=now;p:step(now,.1)
        end
        assert(d.bossHits==1 and d.enemies[-99].rawLife==31 and not d.projectiles[-1001])
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3)
        local counts={GuardianBallPickedUp=0,GuardianBallThrown=0,BossHit=0}
        for _,row in ipairs(s.logs) do if counts[row.kind]~=nil then counts[row.kind]+=1 end end
        assert(counts.GuardianBallPickedUp==1 and counts.GuardianBallThrown==1 and counts.BossHit==1,
            'The real pickup throw impact chain needs one confirmed feedback event per effect')
    end)
    test('actual controller defeat clears Guardian projectiles and carriers before its final step stops',function()
        local s,w,d,p,ground,packet=fixture()
        for i=1,3 do s:_die(1,'Preparation exhaustion');s:step(i*.1) end
        ground();assert(s:intent(1,packet('Punch',1),.4)=='OK')
        d.projectiles[-1002]={mode='Bullet',position={x=2,y=3,z=0},created=.4,expiresAt=30}
        w.positions[-1002]={x=2,y=3,z=0}
        assert(p.carriers[1] and next(d.projectiles))
        d.guardian=p;w.stage=function(self,stage) self.stageName=stage end
        s:_die(1,'Final real death');assert(s.state.status=='Lost')
        setmetatable(d,{__index=Director})
        local controller=setmetatable({current=s,director=d,world=w},{__index=Controller})
        controller:step(.5,.1)
        assert(controller.finished and d.result=='Lost')
        assert(next(d.projectiles)==nil and next(p.carriers)==nil and w.positions[-1002]==nil,
            'No next Start or second Director step may be required to remove a closed boss attack')
        controller:step(.6,.1);assert(next(d.projectiles)==nil)
    end)
    print('GuardianSession: '..passed..' passed')
end
