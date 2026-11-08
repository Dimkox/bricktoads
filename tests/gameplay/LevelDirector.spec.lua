return function(Director,Session,Core,Combat,baseConfig,FakeWorld)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture()
        local world={actors={[1]={}},positions={[1]={x=-65,y=3,z=0}},facing={},spawns=0,hits=0,moves={},pursuits={}}
        function world:spawnEnemy(id,kind,p) self.actors[id]={kind=kind}; self.positions[id]=table.clone(p); self.facing[id]={x=-1,z=0}; self.spawns+=1; return true end
        function world:enemyIdentity(id,actorId,ownerName) self.actors[id].actorId=actorId; self.actors[id].ownerName=ownerName end
        function world:position(id) return self.positions[id] end
        function world:stage(stage) self.currentStage=stage end
        function world:face(id,target)
            local a,b=self.positions[id],self.positions[target]
            local x,z=b.x-a.x,b.z-a.z; local length=math.sqrt(x*x+z*z)
            if length>0 then self.facing[id]={x=x/length,z=z/length} end
        end
        function world:enemyMove(id) self.pursuits[id]=(self.pursuits[id] or 0)+1 end
        function world:targets(id,cfg)
            local result={}; local a=self.positions[id]; local f=self.facing[id] or {x=1,z=0}
            for other,actor in pairs(self.actors) do
                local b=self.positions[other]
                if other~=id and b and not actor.dead then
                    local x,z=b.x-a.x,b.z-a.z; local front=x*f.x+z*f.z; local side=x*f.z-z*f.x
                    if front>=0 and front<=cfg.reach and math.abs(side)<=cfg.width and math.abs(b.y-a.y)<=cfg.height
                        and not (self.blocked and self.blocked[other]) then result[#result+1]=other end
                end
            end
            table.sort(result,function(x,y)
                local p,q=self.positions[x],self.positions[y]
                local dx=(p.x-a.x)^2+(p.y-a.y)^2+(p.z-a.z)^2
                local dy=(q.x-a.x)^2+(q.y-a.y)^2+(q.z-a.z)^2
                return dx==dy and x<y or dx<dy
            end)
            return result
        end
        function world:enemyHealth(id,value) self.actors[id].health=value end
        function world:cue() end
        function world:kill(id) self.actors[id].dead=true end
        function world:move(id,x,z) self.moves[id]={x=x,z=z}; if x*x+z*z>0 then self.facing[id]={x=x,z=z} end end
        function world:jump(id) self.lastJump=id end
        function world:setReaction() end
        function world:impulse() end
        function world:hazard(id) return self.hazards and self.hazards[id] end
        function world:atExit(id) return self.positions[id].x>=108 end
        function world:projectile(id,p,reflected) self.positions[id]=table.clone(p); self.actors[id]={projectile=true,reflected=reflected} end
        function world:removeProjectile(id) self.positions[id]=nil; self.actors[id]=nil end
        local session={state={runId='run-enemies',levelEpoch=1,status='Active',heroes={[1]={status='Alive',connected=true}}},order={1},combat={[1]={}},now=0}
        function session:_hit(a,t,action) world.hits+=1; world.lastHit={a,t,action}; return true end
        local cfg={MoveTimeout=.35,Enemy={hearts=3,punchDamage=1,dashDamage=2,speed=9,range=5,windup=.65,cooldown=1.6,reaction=.35,attack='Dash'},Boss={hits=3,interval=2.4,projectileSpeed=12,returnSpeed=26,projectileLife=12,aggroRange=200},Attacks={Dash={reach=8,width=3,height=4}}}
        return Director.new(session,world,Combat,cfg),world,session
    end
    local function clearWave(d)
        local ids={}; for id,e in pairs(d.enemies) do if not e.dead then ids[#ids+1]=id end end
        for _,id in ipairs(ids) do for _=1,3 do d:hit(1,id,'Punch'); d:step(d.now+.4,.1) end end
    end
    test('ordinary enemies are weaker and die once without respawning',function()
        local d,w=fixture(); local id=-1
        assert(w.actors[id].health==3)
        d:hit(1,id,'Dash'); assert(d.enemies[id].health==1)
        d:step(.4,.1); d:hit(1,id,'Punch')
        assert(d.enemies[id].dead and w.actors[id].dead)
        assert(d:hit(1,id,'Dash')==false)
    end)
    test('encounters unlock in order and never from walking directly to exit',function()
        local d,w=fixture(); w.positions[1].x=112; d:step(.1,.1)
        assert(d.result==nil and d.stage=='Approach')
        clearWave(d); assert(d.stage=='Courtyard')
        clearWave(d); assert(d.stage=='Boss' and d.bossHits==0)
    end)
    test('boss body is protected and only reflected projectiles count',function()
        local d=fixture(); clearWave(d); clearWave(d)
        assert(d:hit(1,-99,'Dash')==true and d.bossHits==0)
    end)
    test('three reflected balls open exit; one living hero completes exactly once',function()
        local d,w=fixture(); clearWave(d); clearWave(d)
        w.positions[1]={x=68,y=3,z=0}
        for n=1,3 do
            d:step(d.now+3,.1)
            local id; for key,p in pairs(d.projectiles) do if not p.reflected then id=key; break end end
            assert(id,'Boss must fire a real projectile')
            assert(d:hit(1,id,'Punch'))
            assert(not d:hit(1,id,'Punch'),'Same ball cannot reflect twice')
            for _=1,80 do d:step(d.now+.1,.1) end
        end
        assert(d.bossHits==3 and d.stage=='Exit')
        w.positions[1].x=112; d:step(d.now+.1,.1)
        assert(d.result=='Won' and d.stage=='Won')
        local spawns=w.spawns; d:step(d.now+1,.1); assert(w.spawns==spawns)
    end)
    test('NPC attack has a windup and resolves against the actual hero once',function()
        local d,w=fixture(); w.positions[1]={x=-25,y=3,z=-6}
        d:step(.1,.1); assert(w.hits==0 and d.enemies[-1].windup)
        d:step(.8,.1); assert(w.hits>=1 and w.lastHit[3]=='Dash')
        local hits=w.hits; d:step(.81,.01); assert(w.hits==hits)
    end)
    test('a late reflection has time to return instead of inheriting outbound expiry',function()
        local d,w=fixture(); clearWave(d); clearWave(d)
        w.positions[1]={x=10,y=3,z=0}; d:step(d.now+3,.1)
        local id,p=next(d.projectiles); assert(id)
        p.created=d.now-11; p.position={x=10,y=3,z=0}; w:projectile(id,p.position,false)
        assert(d:hit(1,id,'Punch'))
        for _=1,35 do d:step(d.now+.1,.1) end
        assert(d.bossHits==1,'Reflected projectile must reach the boss')
    end)
    test('offline living bodies remain targets without an NPC replacing ownership',function()
        local d,w,s=fixture(); s.state.heroes[1].connected=false; w.positions[1]={x=-25,y=3,z=-6}
        d:step(.1,.1); d:step(.8,.1); assert(w.hits>=1)
    end)
    test('lost run closes encounter and cannot be won at exit',function()
        local d,w,s=fixture(); s.state.status='Lost'; w.positions[1].x=112
        d:step(1,.1); assert(d.result=='Lost' and d.stage=='Lost')
    end)
    test('lethal delayed death cannot turn into victory at the exit',function()
        local d,w,s=fixture(); d.stage='Exit'; w.positions[1].x=112; s.combat[1].deathAt=1
        d:step(.1,.1); assert(d.result==nil,'Lethally struck hero cannot win')
    end)
    test('guardian waits for a hero to enter its arena before firing',function()
        local d,w=fixture(); clearWave(d); clearWave(d); d.config.Boss.aggroRange=45
        w.positions[1]={x=-65,y=3,z=0}; d:step(d.now+3,.1)
        assert(next(d.projectiles)==nil,'Guardian cannot fire across the whole level')
        w.positions[1].x=68; d:step(d.now+3,.1); assert(next(d.projectiles)~=nil)
    end)
    test('claim transfers the existing wounded body once without resetting its combat state',function()
        local d,w=fixture(); local body=w.actors[-1]; local p=w.positions[-1]
        d.enemies[-1].health=2; d.enemies[-1].nextAttack=9; d.enemies[-1].reactionUntil=.4
        d.ownerNames={[71]='Guest @guest'}
        assert(type(d.claim)=='function','Director must offer existing enemy ownership')
        assert(d:claim(71,-1)=='OK' and d:claim(71,-1)=='OK')
        assert(w.spawns==2 and w.actors[-1]==body and w.positions[-1]==p,'Claim must preserve body and position')
        assert(d.enemies[-1].health==2 and d.enemies[-1].nextAttack==9 and d.enemies[-1].reactionUntil==.4)
        local role=d:controlled(71)
        assert(role.enemyId==-1 and type(role.actorId)=='string' and role.actorId==body.actorId)
        assert(role.hearts==2 and role.maxHearts==3 and role.status=='Alive' and role.attempt==1)
        assert(role.connectionEpoch==1 and role.connected and role.template=='Sentry' and role.name=="Rusty Guard")
        assert(body.ownerName=='Guest @guest' and d.byUserId[71]==-1)
        assert(d:claim(72,-1)=='ENEMY_OCCUPIED' and d:claim(71,-2)=='ENEMY_ALREADY_OWNED')
    end)
    test('offers contain only existing living unengaged unowned ordinary enemies',function()
        local d,w=fixture()
        assert(type(d.available)=='function','Director must expose claimable bodies')
        local offers=d:available(71); assert(#offers==2 and offers[1].enemyId==-1 and offers[2].enemyId==-2)
        assert(offers[1].actorId==w.actors[-1].actorId and offers[1].hearts==3 and offers[1].maxHearts==3)
        assert(d:claim(71,-99)=='UNKNOWN_ENEMY' and d:claim(71,-1001)=='UNKNOWN_ENEMY')
        d.enemies[-1].engaged=true
        assert(d:claim(71,-1)=='ENEMY_ENGAGED' and #d:available(71)==1)
        d:_kill(-2); assert(d:claim(71,-2)=='ENEMY_DEAD' and #d:available(71)==0)
    end)
    test('actual human enemy death spends the one life through disconnect and later waves',function()
        local d,w=fixture(); assert(d:claim(71,-1)=='OK')
        d:connection(71,false); d:_kill(-1); d:connection(71,true)
        local role=d:controlled(71)
        assert(role.status=='Dead' and role.hearts==0 and role.enemyId==-1)
        assert(d:claim(71,-1)=='ENEMY_LIFE_SPENT' and d:claim(71,-2)=='ENEMY_LIFE_SPENT')
        assert(#d:available(71)==0 and w.spawns==2)
        d:_kill(-2); d:step(.1,.1)
        assert(d.stage=='Courtyard' and d:claim(71,-3)=='ENEMY_LIFE_SPENT')
    end)
    test('hero attack boundary closes the first living directed target even if the effect misses',function()
        local d=fixture()
        assert(type(d.closeTargetForAttack)=='function','Hero acceptance must close directed claims')
        d:closeTargetForAttack({1,-1,-2})
        assert(d:claim(71,-1)=='OK' and d:claim(72,-2)=='OK','A preceding hero keeps unrelated enemies open')
        local other=fixture(); other:closeTargetForAttack({-1,-2})
        assert(other:claim(71,-1)=='ENEMY_ENGAGED' and other:claim(71,-2)=='OK')
        assert(other.enemies[-1].health==3,'Accepted miss closes a claim before damage')
        local third=fixture(); third:_kill(-1); third:closeTargetForAttack({-1,-2})
        assert(third:claim(71,-2)=='ENEMY_ENGAGED','A dead target does not hide the next directed living target')
    end)
    test('reacting heroes do not hide a claimable enemy from the accepted attack boundary',function()
        local d,w,s=fixture(); s.combat[1].reactionEnd=1
        d:closeTargetForAttack({1,-1})
        assert(d:claim(71,-1)=='ENEMY_ENGAGED','Session skips reacting heroes when resolving an actual hit')
        local shielded,sw,ss=fixture(); ss.state.heroes[1].shield={kind='Normal',deadline=2}
        shielded:closeTargetForAttack({1,-1})
        assert(shielded:claim(71,-1)=='OK','A shielded hero still absorbs the accepted hit')
    end)
    test('reacting enemies do not hide the next eligible enemy from the accepted attack boundary',function()
        local d=fixture(); d.enemies[-1].reactionUntil=1
        d:closeTargetForAttack({-1,-2})
        assert(d:claim(71,-2)=='ENEMY_ENGAGED','Director skips enemies protected by an active reaction')
        local expired=fixture(); expired.enemies[-1].reactionUntil=0
        expired:closeTargetForAttack({-1,-2})
        assert(expired:claim(71,-1)=='ENEMY_ENGAGED' and expired:claim(72,-2)=='OK','Expired reactions absorb hits again')
    end)
    test('already reflected projectiles do not hide an eligible enemy at the accepted attack boundary',function()
        local d=fixture(); d.projectiles[-1001]={reflected=true}
        d:closeTargetForAttack({-1001,-1})
        assert(d:claim(71,-1)=='ENEMY_ENGAGED','Reflected balls cannot accept another hit')
        local outbound=fixture(); outbound.projectiles[-1001]={reflected=false}
        outbound:closeTargetForAttack({-1001,-1})
        assert(outbound:claim(71,-1)=='OK','An outbound ball absorbs its first reflection')
    end)
    local function packet(d,userId,kind,seq,fields)
        local role=d:controlled(userId)
        local p={kind=kind,runId='run-enemies',levelEpoch=1,actorId=role.actorId,attempt=1,
            connectionEpoch=role.connectionEpoch,seq=seq}
        for key,value in pairs(fields or {}) do p[key]=value end
        return p
    end
    local validate=Session and Session.validIntent or function(p)
        return type(p)=='table' and (p.kind=='Move' or p.kind=='Jump' or p.kind=='Attack')
            and (p.kind~='Move' or (type(p.x)=='number' and type(p.z)=='number' and p.x*p.x+p.z*p.z<=1.01))
    end
    test('owned enemy commands bind schema identity epoch sequence and ordinary moves',function()
        local d,w=fixture(); d:claim(71,-1)
        assert(type(d.command)=='function','Owned enemies need an authoritative command path')
        local original=packet(d,71,'Move',1,{x=1,z=0})
        local cases={{key='runId',value='other',code='WRONG_RUN'},
            {key='levelEpoch',value=2,code='STALE_ACTOR'}, {key='actorId',value='other',code='STALE_ACTOR'},
            {key='attempt',value=2,code='STALE_ACTOR'}, {key='connectionEpoch',value=2,code='STALE_CONNECTION'}}
        for _,case in ipairs(cases) do
            local p=table.clone(original); p[case.key]=case.value
            assert(d:command(71,p,.1,validate)==case.code,case.key)
        end
        assert(d:command(71,original,.1,function() return false end)=='INVALID_INTENT','Must use the supplied shared schema validator')
        assert(d:command(71,original,.1,validate)=='OK' and w.moves[-1].x==1)
        assert(d:command(71,original,.1,validate)=='STALE_SEQUENCE')
        assert(d:command(71,packet(d,71,'Jump',2),.1,validate)=='OK' and w.lastJump==-1)
        assert(d:command(71,packet(d,71,'Attack',3,{attack='Dash'}),.1,validate)=='INVALID_INTENT','No hero Dash ability')
        assert(d:command(72,original,.1,validate)=='UNKNOWN_ENEMY')
        assert(d:command(71,packet(d,71,'Jump',3),0,validate)=='TIME_REVERSED')
        assert(d:command(71,packet(d,71,'Jump',3),0/0,validate)=='INVALID_TIME')
        d:step(.5,.1); assert(w.moves[-1].x==0,'Voluntary movement expires without fresh commands')
    end)
    test('disconnect retains body and accepted strike while new connection rejects old packets',function()
        local d,w=fixture(); d:claim(71,-1); w.positions[1]={x=-25,y=3,z=-6}
        assert(d:command(71,packet(d,71,'Attack',1,{attack='Punch'}),.1,validate)=='OK')
        assert(d.enemies[-1].engaged and d.enemies[-1].windup and w.hits==0)
        local stale=packet(d,71,'Move',2,{x=1,z=0})
        assert(d:connection(71,false)=='OK' and d:controlled(71).connectionEpoch==2)
        assert(d:command(71,stale,.2,validate)=='OFFLINE')
        local pursuit=w.pursuits[-1]; d:step(.8,.1)
        assert(w.hits==1 and w.lastHit[1]==-1 and w.lastHit[2]==1 and w.lastHit[3]=='Dash')
        d:step(4,.1); assert(w.pursuits[-1]==pursuit and w.hits==1,'Disconnected owner never becomes NPC')
        assert(d:connection(71,true)=='OK' and d:controlled(71).connectionEpoch==3)
        assert(d:command(71,stale,4,validate)=='STALE_CONNECTION')
        assert(d:command(71,packet(d,71,'Jump',1),4,validate)=='OK','Fresh epoch restarts sequencing on same actor')
    end)
    test('human and NPC ordinary strikes share windup front hitbox and cooldown',function()
        local human,w=fixture(); human:claim(71,-1); w.positions[1]={x=-25,y=3,z=-6}
        assert(human:command(71,packet(human,71,'Attack',1,{attack='Punch'}),.1,validate)=='OK')
        human:step(.7,.1); assert(w.hits==0)
        w.positions[1]={x=-23,y=3,z=-6}; human:step(.8,.1)
        assert(w.hits==0,'Windup must miss a target that crossed behind the facing')
        assert(human:command(71,packet(human,71,'Attack',2,{attack='Punch'}),1,validate)=='COOLDOWN')
        w.positions[1]={x=-25,y=3,z=-6}
        assert(human:command(71,packet(human,71,'Attack',3,{attack='Punch'}),2.41,validate)=='OK')
        human:step(3.1,.1); assert(w.hits==1)
        local npc,nw=fixture(); nw.positions[1]={x=-25,y=3,z=-6}; npc:step(.1,.1)
        assert(npc:claim(72,-1)=='ENEMY_ENGAGED','NPC claim closes at its accepted windup')
        nw.positions[1]={x=-23,y=3,z=-6}; npc:step(.8,.1)
        assert(nw.hits==0,'NPC cannot swivel at resolution to hit behind its accepted facing')
        nw.positions[1]={x=-25,y=3,z=-6}; npc:step(1,.1); assert(not npc.enemies[-1].windup)
        npc:step(2.41,.1); assert(npc.enemies[-1].windup); npc:step(3.1,.1); assert(nw.hits==1)
    end)
    test('ordinary human strike hits another enemy through shared enemy health without striking through it',function()
        local d,w=fixture(); d:claim(71,-1)
        w.positions[-2]={x=-26,y=3,z=-6}; w.positions[1]={x=-28,y=3,z=-6}
        assert(d:command(71,packet(d,71,'Attack',1,{attack='Punch'}),.1,validate)=='OK')
        d:step(.8,.1)
        assert(d.enemies[-2].health==1 and d.enemies[-2].engaged,'Ordinary configured Dash damage applies to friendly body')
        assert(w.hits==0,'The first damaged body blocks striking the next candidate')
        assert(d:claim(72,-2)=='ENEMY_ENGAGED')
    end)
    test('reaction death and closed runs reject enemy commands',function()
        local d=fixture(); d:claim(71,-1); d.enemies[-1].reactionUntil=.5
        assert(d:command(71,packet(d,71,'Jump',1),.1,validate)=='REACTION')
        d:step(.6,.1); assert(d:command(71,packet(d,71,'Jump',2),.6,validate)=='OK')
        d:_kill(-1); assert(d:command(71,packet(d,71,'Jump',3),.6,validate)=='NOT_ALIVE')
        local closed=fixture(); closed:claim(71,-1); closed.result='Lost'
        assert(closed:command(71,packet(closed,71,'Jump',1),.1,validate)=='RUN_CLOSED')
        assert(closed:claim(72,-2)=='RUN_CLOSED' and #closed:available(72)==0)
    end)
    test('an engine-dead or missing body cannot be offered or claimed between server steps',function()
        local d,w=fixture(); w.hazards={[-1]='EngineDeath',[-2]='ActorMissing'}
        assert(#d:available(71)==0,'Offers must exclude bodies already lost in the world')
        assert(d:claim(71,-1)=='ENEMY_DEAD' and d:claim(72,-2)=='ENEMY_DEAD')
        assert(d:controlled(71)==nil and d:controlled(72)==nil,'A failed claim must not spend a life')
    end)
    test('boss gate waits before spawning and assigns one existing-profile human guardian',function()
        local d,w=fixture(); local state='Waiting'
        d.bossGate=function() return {state=state,userId=71} end
        clearWave(d); clearWave(d)
        assert(d.stage=='BossReady' and not w.actors[-99],'Pending invitation must precede the encounter')
        local spawns=w.spawns; d:step(d.now+1,.1)
        assert(w.spawns==spawns and not w.actors[-99])
        state='Human'; d:step(d.now+.1,.1)
        local role=d:controlled(71)
        assert(d.stage=='Boss' and role and role.template=='Boss' and role.enemyId==-99)
        assert(role.hearts==d.config.Boss.hits and role.maxHearts==d.config.Boss.hits)
        assert(role.actorId==w.actors[-99].actorId)
        d:step(d.now+.1,.1); assert(w.spawns==spawns+1,'One slot creates one boss')
    end)
    test('human guardian aims and fires only validated input with NPC projectile calibration',function()
        local d,w=fixture(); d.bossGate=function() return {state='Human',userId=71} end
        clearWave(d); clearWave(d); w.positions[1]={x=68,y=3,z=0}
        d:step(d.now+3,.1); assert(next(d.projectiles)==nil,'A human guardian never auto-fires')
        local function command(kind,seq,fields)
            local role=d:controlled(71); local p={kind=kind,runId='run-enemies',levelEpoch=1,actorId=role.actorId,
                attempt=1,connectionEpoch=role.connectionEpoch,seq=seq}
            for k,v in pairs(fields or {}) do p[k]=v end
            return d:command(71,p,d.now,validate)
        end
        assert(command('Jump',1)=='INVALID_INTENT')
        assert(command('Attack',1,{attack='Dash'})=='INVALID_INTENT')
        assert(command('Move',1,{x=-1,z=0})=='OK')
        assert(command('Attack',2,{attack='Punch'})=='OK')
        local id,ball=next(d.projectiles)
        assert(id and ball.direction.x<w.positions[-99].x and not ball.reflected)
        assert(command('Attack',3,{attack='Punch'})=='COOLDOWN')
        local original=w.actors[-99]; d:connection(71,false)
        local epoch=d:controlled(71).connectionEpoch
        local x=ball.position.x; d:step(d.now+.1,.1)
        assert(ball.position.x<x,'Accepted projectile continues after disconnection')
        assert(command('Attack',4,{attack='Punch'})=='OFFLINE')
        assert(d:hit(1,id,'Punch'))
        for _=1,15 do d:step(d.now+.1,.1) end
        assert(d.bossHits==1 and d:controlled(71).hearts==2,'Offline boss remains vulnerable')
        d:connection(71,true)
        assert(d:controlled(71).connectionEpoch==epoch+1 and w.actors[-99]==original)
        assert(d:controlled(71).hearts==2,'Returning controller cannot heal the boss')
    end)
    test('physical guardian death ends its role and does not permit late commands or respawn',function()
        local d,w=fixture(); d.bossGate=function() return {state='Human',userId=71} end
        clearWave(d); clearWave(d); local body=w.actors[-99]
        w.hazards={[-99]='Fall'}; d:step(d.now+.1,.1)
        assert(d.stage=='Exit' and d:controlled(71).status=='Dead' and d:controlled(71).hearts==0)
        assert(d.bossHits==0,'A physical death is not three reflected hits')
        local spawns=w.spawns; d:connection(71,false); d:connection(71,true); d:step(d.now+3,.1)
        assert(w.spawns==spawns and w.actors[-99]==body,'Reconnect cannot recreate a dead guardian')
    end)
    test('guardian input cannot fire through an already missing physical body',function()
        local d,w=fixture(); d.bossGate=function() return {state='Human',userId=71} end
        clearWave(d); clearWave(d); d.now+=3
        local role=d:controlled(71); w.hazards={[-99]='ActorMissing'}; w.positions[-99]=nil
        local p={kind='Attack',attack='Punch',seq=1,runId='run-enemies',levelEpoch=1,
            actorId=role.actorId,attempt=1,connectionEpoch=role.connectionEpoch}
        assert(d:command(71,p,d.now,validate)=='NOT_ALIVE')
        assert(next(d.projectiles)==nil and d:controlled(71).status=='Dead')
    end)
    test('guardian death cancels later outbound impacts in the same server tick',function()
        local d,w=fixture(); clearWave(d); clearWave(d)
        w.positions[1]={x=68,y=3,z=0}; d.bossHits=2; d.enemies[-99].health=1
        d.projectiles={[-1001]={},[-1002]={}}
        local order={}; for id in pairs(d.projectiles) do order[#order+1]=id end
        d.projectiles[order[1]]={position=table.clone(w.positions[-99]),direction=w.positions[1],
            created=d.now,reflected=true,reflectedAt=d.now}
        d.projectiles[order[2]]={position=table.clone(w.positions[1]),direction=w.positions[1],created=d.now,reflected=false}
        d:step(d.now+.01,.01)
        assert(d.stage=='Exit' and d.enemies[-99].dead)
        assert(w.hits==0,'No projectile may hit after guardian defeat, even later in the same tick')
        assert(next(d.projectiles)==nil,'Encounter completion clears every remaining projectile')
    end)
    if Session then
        local function realSessionFixture()
            local d,w=fixture(); local config=table.clone(baseConfig)
            config.Enemy=d.config.Enemy; config.Boss=d.config.Boss
            function w:findSafe() return {safe=true} end
            function w:isSafe() return true end
            function w:spawn(id,actorId)
                self.actors[id]={actorId=actorId}; self.positions[id]={x=-25,y=3,z=-6}; return true
            end
            function w:hold(id,value) self.actors[id].held=value end
            function w:observe(id) return {actorId=self.actors[id].actorId} end
            local s=Session.new(Core,Combat,config,{{userId=1,template='Mr. Green'}},'run-enemies',w)
            s:step(0); d.session=s; d.config=config
            return d,w,s
        end
        test('human and NPC strikes use actual Session hero damage and profile',function()
            for _,human in ipairs({true,false}) do
                local d,w,s=realSessionFixture()
                if human then
                    d:claim(71,-1)
                    assert(d:command(71,packet(d,71,'Attack',1,{attack='Punch'}),.1,Session.validIntent)=='OK')
                else d:step(.1,.1) end
                s:step(.8); d:step(.8,.1)
                assert(s.combat[1].rawLife==31 and s.state.heroes[1].health==155/47)
                local hit=s.logs[#s.logs]
                assert(hit.kind=='Hit' and hit.data.attacker==-1 and hit.data.action=='Dash' and hit.data.profile==22)
            end
        end)
        test('actual respawn shield blocks human enemy damage through the Session hit path',function()
            local d,w,s=realSessionFixture(); s:_die(1,'test-death'); s:step(.01)
            assert(s.state.heroes[1].shield.kind=='Normal' and s.combat[1].rawLife==47)
            d:claim(71,-1)
            assert(d:command(71,packet(d,71,'Attack',1,{attack='Punch'}),.1,Session.validIntent)=='OK')
            s:step(.8); d:step(.8,.1)
            assert(s.combat[1].rawLife==47 and s.state.heroes[1].health==5 and s.state.heroes[1].respawns==2)
            local hit=s.logs[#s.logs]
            assert(hit.kind=='Hit' and hit.data.blocked==true and hit.data.attacker==-1)
        end)
    end
    print('LevelDirector: '..passed..' PASS')
end
