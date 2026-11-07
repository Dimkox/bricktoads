return function(GuardianPattern)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function eq(actual,expected)
        assert(actual==expected,'expected '..tostring(expected)..', got '..tostring(actual))
    end
    local function count(values) local n=0; for _ in pairs(values) do n+=1 end; return n end
    local function fixture()
        local events={}
        local world={positions={[-99]={x=40,y=3,z=0},[1]={x=0,y=3,z=0},[2]={x=0,y=3,z=2}},rendered={},removed={},holds={},facing={}}
        function world:position(slot) return self.positions[slot] end
        function world:groundPosition(position)
            if self.noGround then return nil end
            return {x=position.x,y=1,z=position.z}
        end
        function world:projectile(id,position,reflected,mode)
            self.rendered[id]={position=table.clone(position),reflected=reflected,mode=mode}
            events[#events+1]='render:'..tostring(mode)
        end
        function world:removeProjectile(id) self.removed[id]=(self.removed[id] or 0)+1; self.rendered[id]=nil end
        function world:hold(slot,held) self.holds[slot]=held; events[#events+1]='hold:'..slot..':'..tostring(held) end
        function world:cue() end
        function world:face(slot,target) self.facing[slot]=target end
        function world:enemyHealth(id,health,max) self.lastHealth={id,health,max} end
        local session={state={status='Active',heroes={}},order={1,2},combat={},hits={},attacks=0}
        for _,slot in ipairs(session.order) do
            session.state.heroes[slot]={status='Alive',connected=true,actorId='hero-'..slot,
                attempt=1,connectionEpoch=1,health=5,respawns=3,shield={kind='Emergency',deadline=99}}
            session.combat[slot]={rawLife=47,nextAttack=0}
        end
        function session:_event(kind,slot,fields)
            eq(kind,'BeginAttack'); eq(fields.connectionEpoch,self.state.heroes[slot].connectionEpoch)
            events[#events+1]='BeginAttack:'..slot
            if self.rejectAttack then return 'STALE_CONNECTION' end
            self.attacks+=1; self.state.heroes[slot].shield=nil
            return 'OK'
        end
        function session:_hit(attacker,slot,action)
            self.hits[#self.hits+1]={attacker,slot,action}
            if not self.state.heroes[slot].shield then self.combat[slot].rawLife=math.max(0,self.combat[slot].rawLife-16) end
            return true
        end
        local d={world=world,session=session,stage='Boss',now=0,serial=0,bossHits=0,projectiles={},kills=0,
            enemies={[-99]={boss=true,ownerUserId=99,connected=true,health=3,rawLife=47}},
            config={Boss={hits=3,interval=1.6,initial=1.8,ballInterval=8,projectileSpeed=12,
                returnSpeed=26,ballLife=20,pickupRange=5.5,aggroRange=100}}}
        function d:_nearest(position)
            local best,range=nil,math.huge
            for _,slot in ipairs(session.order) do
                local h=session.state.heroes[slot]; local p=world:position(slot)
                if h.status=='Alive' and not session.combat[slot].deathAt and p then
                    local dist=math.sqrt((p.x-position.x)^2+(p.y-position.y)^2+(p.z-position.z)^2)
                    if dist<range then best,range=slot,dist end
                end
            end
            return best,range
        end
        function d:_kill(id)
            eq(id,-99); self.enemies[id].dead=true; self.enemies[id].health=0; self.kills+=1; self.stage='Exit'
        end
        local pattern=GuardianPattern.new(d)
        local function step(now,dt) d.now=now; return pattern:step(now,dt) end
        local function ground(at)
            step(at,0)
            local id
            for key,p in pairs(d.projectiles) do if p.mode=='Heavy' then id=key end end
            assert(id,'Finite phase must create a Heavy pickup opportunity')
            step(at+4,4)
            eq(d.projectiles[id].mode,'Ground')
            return id
        end
        return pattern,d,world,session,events,step,ground
    end

    test('finite Heavy phase gives idle disconnected human a ground ball without replacing ownership',function()
        local _,d,w,s,_,step=fixture(); d.enemies[-99].connected=false
        step(7.999,0); eq(count(d.projectiles),0)
        step(8,0); local id,p=next(d.projectiles)
        assert(id<-1000); eq(p.mode,'Heavy'); eq(count(d.projectiles),1)
        local captured=table.clone(p.direction); w.positions[1]={x=20,y=3,z=0}
        step(12,4); eq(p.mode,'Ground'); eq(p.position.x,captured.x); eq(p.position.y,1)
        eq(w.rendered[id].mode,'Ground'); eq(#s.hits,0)
        eq(d.enemies[-99].ownerUserId,99); eq(d.enemies[-99].health,3)
        eq(w.facing[-99],nil)
    end)

    test('ordinary shots damage through Session and flying bullets never reflect',function()
        local p,d,_,s,_,step=fixture(); d.now=1.8
        eq(p:fire({x=-1,z=0},1),'OK'); local id,ball=next(d.projectiles)
        eq(ball.mode,'Bullet'); eq(p:hit(1,id,'Punch'),false); eq(ball.mode,'Bullet')
        s.state.heroes[1].shield=nil; step(4.8,3)
        eq(#s.hits,1); eq(s.hits[1][1],-99); eq(s.hits[1][2],1); eq(s.hits[1][3],'Dash')
        eq(s.combat[1].rawLife,31); eq(d.projectiles[id],nil)
    end)

    test('human fire respects cooldown and NPC only fires within aggro range',function()
        local p,d,_,_,_,step=fixture()
        eq(p:fire({x=-1,z=0}),'COOLDOWN'); d.now=1.8
        eq(p:fire({x=-1,z=0}),'OK'); eq(p:fire({x=-1,z=0}),'COOLDOWN')
        eq(count(d.projectiles),1); d.now=3.5; eq(p:fire({x=-1,z=0}),'OK')
        local _,npc,w,_,_,npcStep=fixture(); npc.enemies[-99].ownerUserId=nil
        npcStep(1.8,0); eq(count(npc.projectiles),1)
        w.positions[1].x=-200; w.positions[2].x=-200
        npcStep(3.5,0); eq(count(npc.projectiles),1)
        local _,human,_,_,_,humanStep=fixture(); human.enemies[-99].connected=false
        humanStep(1.8,0); humanStep(3.5,0); eq(count(human.projectiles),0)
        step(3.5,0)
    end)

    test('pickup is exclusive and preserves shield health reserves and combat resources',function()
        local p,d,w,s,_,_,ground=fixture(); local id=ground(8)
        local h=s.state.heroes[1]; local shield=h.shield; local raw=s.combat[1].rawLife
        local interaction=p:interaction(1)
        eq(interaction.available,true); eq(interaction.label,'ВЗЯТЬ ШАР'); eq(interaction.carrying,false)
        eq(p:interact(1,12),'OK'); eq(p:interact(2,12),'NO_INTERACTION')
        eq(d.projectiles[id].mode,'Carried'); eq(d.projectiles[id].holder,1)
        eq(h.shield,shield); eq(h.health,5); eq(h.respawns,3); eq(s.combat[1].rawLife,raw)
        eq(s.attacks,0); eq(w.holds[1],nil)
        local carrying=p:interaction(1)
        eq(carrying.available,true); eq(carrying.label,'БРОСИТЬ ШАР'); eq(carrying.carrying,true)
    end)

    test('pickup requires server distance height and a living connected non-dying hero',function()
        local p,_,w,s,_,_,ground=fixture(); ground(8)
        w.positions[1].x=20; eq(p:interaction(1).available,false); eq(p:interact(1,12),'NO_INTERACTION')
        w.positions[1]={x=0,y=7,z=0}; eq(p:interaction(1).available,false)
        w.positions[1]={x=0,y=3,z=0}; s.combat[1].deathAt=13
        eq(p:interaction(1).available,false); assert(p:interact(1,12)~='OK')
        s.combat[1].deathAt=nil; s.state.heroes[1].connected=false
        eq(p:interaction(1).available,false); assert(p:interact(1,12)~='OK')
        s.state.heroes[1].connected=true; s.state.heroes[1].status='Eliminated'
        eq(p:interaction(1).available,false)
    end)

    test('throw accepts BeginAttack and removes emergency hold before the projectile effect',function()
        local p,d,_,s,events,step,ground=fixture(); local id=ground(8)
        eq(p:interact(1,12),'OK'); table.clear(events)
        eq(p:interact(1,12.1),'OK')
        eq(events[1],'BeginAttack:1'); eq(events[2],'hold:1:false'); eq(events[3],'render:Thrown')
        eq(s.state.heroes[1].shield,nil); eq(s.attacks,1); eq(d.projectiles[id].mode,'Thrown')
        s.state.heroes[1].connected=false; d.enemies[-99].connected=false
        step(14.1,2); eq(d.bossHits,1); eq(d.enemies[-99].rawLife,31); eq(d.enemies[-99].health,2)
        eq(d.projectiles[id],nil); eq(d.enemies[-99].ownerUserId,99)
    end)

    test('failed BeginAttack leaves the ball held and never releases shield hold',function()
        local p,d,w,s,_,_,ground=fixture(); local id=ground(8)
        p:interact(1,12); s.rejectAttack=true
        eq(p:interact(1,12.1),'STALE_CONNECTION'); eq(d.projectiles[id].mode,'Carried')
        eq(w.holds[1],nil); assert(s.state.heroes[1].shield)
    end)

    test('thrown ball clears nearby heroes during normal flight before reaching the guardian',function()
        local p,d,w,s,_,step=fixture()
        w.positions[1]={x=600,y=3,z=0};w.positions[2]={x=600,y=3,z=2};w.positions[-99]={x=628,y=3,z=0}
        local id=-1001
        d.projectiles[id]={mode='Ground',position={x=600,y=1.2,z=0},created=0,expiresAt=20}
        eq(p:interact(1,.1),'OK');eq(p:interact(1,.8),'OK')
        step(.9,.1)
        eq(#s.hits,0);eq(s.combat[1].rawLife,47);eq(d.bossHits,0)
        assert(d.projectiles[id] and d.projectiles[id].mode=='Thrown','First flight step must not consume the ball on its thrower')
        for n=1,20 do step(.9+n*.1,.1) end
        eq(d.bossHits,1);eq(d.enemies[-99].rawLife,31);eq(d.projectiles[id],nil);eq(#s.hits,0)
    end)

    test('carried ball follows its owner and lifecycle changes drop it without duplicating',function()
        for _,change in ipairs({'Disconnected','Death','Attempt','Actor','Epoch'}) do
            local p,d,w,s,_,step,ground=fixture(); local id=ground(8); p:interact(1,12)
            w.positions[1]={x=3,y=3,z=4}; step(12.1,.1)
            eq(d.projectiles[id].position.x,3); eq(d.projectiles[id].position.z,4)
            local h=s.state.heroes[1]
            if change=='Disconnected' then h.connected=false
            elseif change=='Death' then s.combat[1].deathAt=12.2
            elseif change=='Attempt' then h.attempt=2
            elseif change=='Actor' then h.actorId='replacement-body'
            else h.connectionEpoch=2 end
            step(12.2,.1)
            eq(count(d.projectiles),1); eq(d.projectiles[id].mode,'Ground'); eq(d.projectiles[id].holder,nil)
            eq(p:interaction(1).carrying,false)
        end
    end)

    test('unsupported dropped balls clear and expired balls cannot be picked up',function()
        local p,d,w,s,_,step,ground=fixture(); local id=ground(8); p:interact(1,12)
        w.noGround=true; s.state.heroes[1].connected=false; step(12.1,.1)
        eq(d.projectiles[id],nil); eq(w.removed[id],1)
        local other,otherD,_,_,_,otherStep,otherGround=fixture(); local expired=otherGround(8)
        otherStep(28,0); eq(otherD.projectiles[expired],nil)
        eq(other:interaction(1).carrying,false)
    end)

    test('three thrown impacts follow raw 47 31 15 0 and defeat the guardian once',function()
        local p,d,w,_,_,step,ground=fixture()
        for n,raw in ipairs({31,15,0}) do
            ground(n*8); eq(p:interact(1,n*8+4),'OK'); eq(p:interact(1,n*8+4.1),'OK')
            step(n*8+6.1,2); eq(d.bossHits,n); eq(d.enemies[-99].rawLife,raw)
            eq(d.enemies[-99].health,3-n)
        end
        eq(d.kills,1); eq(d.stage,'Exit'); eq(count(d.projectiles),0); eq(w.lastHealth[2],0)
        step(100,100); eq(d.kills,1); eq(count(d.projectiles),0)
    end)

    test('same-tick guardian death clears later impacts and hazards immediately',function()
        local _,d,_,s,_,step=fixture()
        d.bossHits=2; d.enemies[-99].rawLife=15; d.enemies[-99].health=1
        d.projectiles[-2001]={mode='Thrown',position={x=40,y=3,z=0},created=0,expiresAt=20}
        d.projectiles[-2002]={mode='Thrown',position={x=40,y=3,z=0},created=0,expiresAt=20}
        d.projectiles[-2003]={mode='Bullet',position={x=0,y=3,z=0},direction={x=0,y=3,z=0},created=0,expiresAt=20}
        step(0,0)
        eq(d.bossHits,3); eq(d.kills,1); eq(#s.hits,0); eq(count(d.projectiles),0)
    end)

    test('direct attacks cannot bypass the thrown-ball rule and IDs remain unique',function()
        local p,d,_,_,_,step=fixture(); d.now=1.8
        p:fire({x=-1,z=0}); local first=next(d.projectiles)
        d.serial=0; d.now=3.5; p:fire({x=-1,z=0})
        eq(count(d.projectiles),2); assert(d.projectiles[first])
        p:hit(1,-99,'Dash'); eq(d.bossHits,0); eq(d.enemies[-99].rawLife,47)
        d.enemies[-99].dead=true; step(3.6,.1); eq(count(d.projectiles),0)
        eq(p:interact(1,3.6),'NO_INTERACTION')
    end)

    print('GuardianPattern: '..passed..' passed')
end
