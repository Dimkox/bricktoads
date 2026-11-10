-- Pure collision/Session regression. The optional production BaseWorld impulse
-- callback is supplied by the native-Luau API-double bundle as an extra check.
return function(Boss,Session,Core,Combat,Config,FakeWorld,baseImpulse)
    local failures={};local passed=0
    local function check(value,label) assert(value,label) end
    local function near(a,b) return type(a)=='number' and math.abs(a-b)<1e-6 end
    local function test(name,body)
        local ok,message=pcall(body)
        if ok then passed+=1;print('PASS '..name) else failures[#failures+1]=name..': '..tostring(message);print('FAIL '..failures[#failures]) end
    end
    local Vec={}
    Vec.__index=function(self,key)
        if key=='Magnitude' then return math.sqrt(self.X^2+self.Y^2+self.Z^2) end
        if key=='Unit' then local n=math.sqrt(self.X^2+self.Y^2+self.Z^2);return setmetatable({X=self.X/n,Y=self.Y/n,Z=self.Z/n},Vec) end
        return Vec[key]
    end
    function Vec.__add(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},Vec) end
    function Vec.__mul(a,b)
        if type(a)=='number' then a,b=b,a end
        return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},Vec)
    end
    local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},Vec) end
    local function fixture(target,enemyTarget)
        local config=table.clone(Config);config.Attacks=table.clone(Config.Attacks)
        config.Attacks.DragonFire=table.clone(Config.Attacks.DragonFire)
        local world=FakeWorld.new();world.config=config;world.positions={[1]=enemyTarget and {x=1000,y=3,z=1000} or target}
        function world:position(id) return self.positions[id] end
        function world:spawnEnemy(id,_,p)
            self.positions[id]=table.clone(p)
            self.actors[id]={root={Parent=true,Anchored=false,CFrame={LookVector=vector(1,0,0)}}};return true
        end
        function world:enemyHealth() end
        function world:campaignWalkSpeed() end
        function world:cue() end
        function world:projectile() end
        function world:removeProjectile() end
        function world:campaignProjectileBlocked() return false end
        function world:placeActor(id,p) self.positions[id]=table.clone(p) end
        function world:aim(id,x,z)
            if self.actors[id] then self.actors[id].root.CFrame.LookVector=vector(x,0,z) end
        end
        function world:impulse(id,attacker,tuning,profile,direction)
            self.lastResponse={id=id,attacker=attacker,tuning=tuning,profile=profile,direction=direction}
            if baseImpulse then baseImpulse(self,id,attacker,tuning,profile,direction) end
        end
        local session=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},'robo-projectile-regression',world)
        session:step(0);session.state.heroes[1].shield=nil;session.sourceCombat=config.SourceCombat
        local heroRoot={Parent=true,Anchored=false,AssemblyMass=1}
        function heroRoot:ApplyImpulse(value) self.lastImpulse=value end
        world.actors[1].root=heroRoot
        local originalHit=session._hit
        function session:_hit(attacker,id,action,tuning)
            self.lastHitTuning=tuning;return originalHit(self,attacker,id,action,tuning)
        end
        local boss=Boss.new(session,world,config,{boss={type='RoboManus',position={x=0,y=3,z=0},chaseComplete=true},
            bossGate={ownerUserId=99,connected=true}})
        if enemyTarget then boss.externalEnemies={[-1]={dead=false}};world.positions[-1]=target end
        local function step(now) session.now=now;check(boss:step(now,0)=='OK','accepted boss step') end
        return boss,world,session,config,heroRoot,step
    end
    test('Robo bolt keeps emission response and +X impulse when the next Jump turns -Z',function()
        local boss,world,session,config,root,step=fixture({x=60,y=3,z=0})
        local reaction=config.Attacks.DragonFire.reaction
        check(boss:command('Punch',{x=1,z=0},0)=='OK','accepted Burst');step(.81)
        config.Attacks.DragonFire.reaction=9
        step(1.81);check(boss:command('Dash',{x=0,z=-1},1.81)=='OK','accepted later Jump');step(2.1)
        check(session.combat[1].rawLife==31,'real Session receives exactly one middle-bolt hit')
        local response=world.lastResponse;local direction=response and response.direction
        check(direction and near(direction.x,1) and near(direction.z,0),'old +X bolt must not inherit the later -Z facing')
        check(near(session.combat[1].reactionEnd,2.1+reaction),'in-flight bolt retains its emission reaction tuning')
        check(session.lastHitTuning~=config.Attacks.DragonFire,'projectile owns its tuning snapshot')
        check(config.Attacks.DragonFire.impulseDirection==nil,'shot direction never mutates shared config')
        if baseImpulse then check(root.lastImpulse and near(root.lastImpulse.X,32) and near(root.lastImpulse.Z,0),'actual BaseWorld applies +X impulse') end
    end)
    test('spread bolt retains its own direction through owner disconnect and missing actor lookup',function()
        local angle=-.1;local x,z=math.cos(angle),math.sin(angle)
        local boss,world,session,config,root,step=fixture({x=60*x,y=3,z=60*z})
        check(boss:command('Punch',{x=1,z=0},0)=='OK','accepted Burst');step(.81)
        check(boss:connection(99,false)=='OK','owner disconnected');world:aim(-99,0,-1)
        world.actors[-99]=nil -- Accepted response must not need a later attacker body lookup.
        step(2)
        check(session.combat[1].rawLife==31,'accepted spread bolt still hits disconnected owner target')
        local direction=world.lastResponse and world.lastResponse.direction
        check(direction and near(direction.x,x) and near(direction.z,z),'spread direction is captured per bolt')
        check(config.Attacks.DragonFire.impulseDirection==nil,'spread direction never mutates shared config')
        if baseImpulse then check(root.lastImpulse and near(root.lastImpulse.X,32*x) and near(root.lastImpulse.Z,32*z),'actual BaseWorld applies spread impulse without attacker lookup') end
    end)
    test('ordinary enemy collision receives the same independent captured projectile response',function()
        local angle=.1;local x,z=math.cos(angle),math.sin(angle)
        local boss,world,_,config,_,step=fixture({x=60*x,y=3,z=60*z},true)
        local received
        boss.enemyHit=function(attacker,target,action,tuning) received={attacker=attacker,target=target,action=action,tuning=tuning};return true end
        check(boss:command('Punch',{x=1,z=0},0)=='OK','accepted Burst');step(.81)
        check(boss:connection(99,false)=='OK','owner disconnected');world:aim(-99,-1,0);step(2.3)
        check(received and received.attacker==-99 and received.target==-1 and received.action=='DragonFire','ordinary enemy receives accepted bolt hit')
        local direction=received.tuning.impulseDirection
        check(direction and near(direction.x,x) and near(direction.z,z),'ordinary enemy receives its spread direction')
        check(received.tuning~=config.Attacks.DragonFire and config.Attacks.DragonFire.impulseDirection==nil,'ordinary response does not reuse/mutate live config')
    end)
    check(#failures==0,table.concat(failures,'\n'))
    print('CampaignBossProjectile: '..passed..' passed')
end
