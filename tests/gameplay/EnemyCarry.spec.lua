return function(Carry,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture(second)
        local w=FakeWorld.new();w.positions={};w.front={};w.grounded={};w.links={};w.savedReaction={};w.releaseCalls={}
        local spawn=w.spawn
        function w:spawn(uid,...)
            local ok=spawn(self,uid,...)
            if ok then self.positions[uid]={x=0,y=3,z=0};self.front[uid]=true;self.grounded[uid]=true end
            return ok
        end
        function w:position(id) return self.positions[id] end
        function w:canGrabEnemy(hero,id,range,height)
            local a,b=self.positions[hero],self.positions[id]
            return a and b and self.front[hero] and self.grounded[hero]
                and math.abs(a.y-b.y)<=height and (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=range^2
        end
        function w:carryEnemy(id,hero)
            if self.carryFails then return false end
            if not self.links[id] then self.savedReaction[id]=self.actors[id].reaction end
            self.links[id]=hero;return true
        end
        function w:releaseEnemy(id,hero,tuning)
            if self.releaseFails then return false end
            self.releaseCalls[#self.releaseCalls+1]={id=id,hero=hero,tuning=tuning}
            if self.savedReaction[id]~=nil then self.actors[id].reaction=self.savedReaction[id] end
            self.savedReaction[id]=nil
            self.links[id]=nil;return true
        end
        local roster={{userId=1,template='Mr. Green'}}
        if second then roster[2]={userId=2,template='Mr. Green'} end
        local s=Session.new(Core,Combat,Config,roster,'carry-run',w);s:step(0)
        w.actors[-1]={id='same-pig-body',alive=true,reaction=false};w.positions[-1]={x=2,y=3,z=0};w.grounded[-1]=true
        local cfg=table.clone(Config)
        cfg.EnemyCarry={range=3.3,height=2.5,facingDot=.5,windup=.12,window=.2,reaction=.85,
            horizontal=26,vertical=16,throwDamage=1,sourceProfile=17,sourceRawDamage=4}
        local d={session=s,world=w,config=cfg,now=0,enemies={[-1]={kind='Pig',health=3,actorId='pig-actor',
            ownerUserId=20,connected=true,connectionEpoch=4,engaged=false,nextAttack=1}},damageCalls=0}
        function d:_kill(id)
            local e=self.enemies[id];if e.dead then return end
            e.dead=true;e.health=0;self.carry:forgetEnemy(id);w:kill(id)
        end
        function d:applyThrowDamage(id,slot)
            self.damageCalls+=1;self.lastThrow={id=id,slot=slot}
            local e=self.enemies[id];e.health=math.max(0,e.health-self.config.EnemyCarry.throwDamage)
            if e.health==0 then self:_kill(id) end
        end
        local c=Carry.new(d);d.carry=c
        s.contextualAttack=function(slot,now,action) d.now=now;return c:interact(slot,now,action) end
        local sequences={}
        local function packet(slot,extra)
            local h=s.state.heroes[slot];sequences[slot]=(sequences[slot] or 0)+1
            local p={kind='Attack',attack='Punch',runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
                connectionEpoch=h.connectionEpoch,levelEpoch=s.state.levelEpoch,seq=sequences[slot]}
            for k,v in pairs(extra or {}) do p[k]=v end
            return p
        end
        local function step(now) s:step(now);d.now=now;c:step(now) end
        local function capture(slot)
            slot=slot or 1;assert(s:intent(slot,packet(slot),.1)=='OK');step(.23)
            assert(c:stateFor(-1)=='Carried' and w.links[-1]==slot)
        end
        return d,s,w,c,packet,step,capture
    end
    local function count(s,kind)
        local n=0;for _,r in ipairs(s.logs) do if r.kind==kind then n+=1 end end;return n
    end
    test('a close grounded Pig is captured as the same living owned body without resources or health changing',function()
        local d,s,w,c,_,_,capture=fixture();local h=s.state.heroes[1];local body=w.actors[-1];local enemy=d.enemies[-1]
        assert(c:interaction(1).available and c:interaction(1).label=='СХВАТИТЬ')
        capture();assert(w.actors[-1]==body and d.enemies[-1]==enemy and enemy.health==3)
        assert(enemy.actorId=='pig-actor' and enemy.ownerUserId==20 and enemy.connectionEpoch==4 and enemy.connected)
        assert(s.state.heroes[1].actorId==h.actorId and s.state.heroes[1].respawns==3 and s.combat[1].rawLife==47)
        assert(c:blocksEnemy(-1) and c:interaction(1).carrying and c:interaction(1).label=='БРОСИТЬ ВРАГА')
        assert(count(s,'EnemyGrabAccepted')==1 and count(s,'EnemyGrabbed')==1)
    end)
    test('only grounded in-range facing living unlinked Pigs qualify',function()
        local cases={
            function(d,s,w) d.enemies[-1].kind='Walker' end,
            function(d,s,w) d.enemies[-1].kind='Dragon' end,
            function(d,s,w) d.enemies[-1].dead=true end,
            function(d,s,w) d.enemies[-1].reactionUntil=5 end,
            function(d,s,w) w.hazards[-1]='Fall' end,
            function(d,s,w) w.front[1]=false end,
            function(d,s,w) w.grounded[1]=false end,
            function(d,s,w) w.positions[-1].x=20 end,
            function(d,s,w) w.positions[-1].y=7 end,
        }
        for _,prepare in ipairs(cases) do
            local d,s,w,c=fixture();prepare(d,s,w)
            assert(not c:interaction(1).available and c:interact(1,.1,'Punch')=='NO_INTERACTION')
            assert(not c:blocksEnemy(-1) and not d.enemies[-1].engaged)
        end
    end)
    test('an accepted grab closes takeover before a delayed miss without acquiring the moved body',function()
        local d,s,w,c,p,step=fixture();assert(s:intent(1,p(1),.1)=='OK')
        assert(d.enemies[-1].engaged and not c:stateFor(-1))
        w.positions[-1].x=20;step(.23)
        assert(not c:stateFor(-1) and not w.links[-1] and d.enemies[-1].health==3)
    end)
    test('a grab outside its finite effect window cannot acquire an old target',function()
        local d,s,w,c,p,step=fixture();assert(s:intent(1,p(1),.1)=='OK');step(1)
        assert(not c:stateFor(-1) and not w.links[-1] and d.enemies[-1].health==3)
    end)
    test('two accepted grabs compete in acceptance order for the same body',function()
        local d,s,w,c,p,step=fixture(true)
        assert(s:intent(2,p(2),.1)=='OK' and s:intent(1,p(1),.1)=='OK');step(.23)
        assert(w.links[-1]==2 and c:interaction(2).carrying and not c:interaction(1).carrying)
        assert(count(s,'EnemyGrabAccepted')==2 and count(s,'EnemyGrabbed')==1 and d.damageCalls==0)
    end)
    test('capture cancels a current Pig windup but does not replace its owner',function()
        local d,s,w,c,_,_,capture=fixture();d.enemies[-1].windup={at=1};d.enemies[-1].lastMove=0
        capture();assert(d.enemies[-1].windup==nil and d.enemies[-1].lastMove==nil and d.enemies[-1].ownerUserId==20)
    end)
    test('capture normalizes an expired enemy reaction before saving the carry physics',function()
        local d,s,w,c,_,_,capture=fixture()
        d.enemies[-1].reactionUntil=.05;w.actors[-1].reaction=true
        capture();c:forgetEnemy(-1)
        assert(d.enemies[-1].reactionUntil==nil and w.actors[-1].reaction==false,
            'Dropping cannot restore an expired PlatformStand with no recovery deadline')
    end)
    test('a historical holder hit cancels a pending grab even after recovery',function()
        local d,s,w,c,p=fixture(true)
        assert(s:intent(1,p(1),.1)=='OK' and s:_hit(2,1,'Punch'))
        s:step(2);c:step(2)
        assert(not c:stateFor(-1) and not w.links[-1] and count(s,'EnemyGrabbed')==0)
    end)
    test('enemy interruption history cancels a pending grab after its current reaction expired',function()
        local d,s,w,c,p,step=fixture();assert(s:intent(1,p(1),.1)=='OK')
        d.enemies[-1].reactionEpoch=1;d.enemies[-1].reactionUntil=.15;step(.23)
        assert(not c:stateFor(-1) and not w.links[-1])
    end)
    test('an already accepted capture and carry persist on their same offline holder body',function()
        local d,s,w,c,p,step=fixture();local id=s.state.heroes[1].actorId
        assert(s:intent(1,p(1),.1)=='OK' and s:connection(1,false,.11)=='OK');step(.23);step(.4)
        assert(c:stateFor(-1)=='Carried' and w.links[-1]==1 and s.state.heroes[1].actorId==id)
        assert(s.state.heroes[1].respawns==3 and not s.state.heroes[1].connected and d.damageCalls==0)
    end)
    test('a new holder appearance cannot inherit the previous pending grab',function()
        local d,s,w,c,p,step=fixture();assert(s:intent(1,p(1),.1)=='OK')
        s:_die(1,'fixture');step(.23)
        assert(s.state.heroes[1].attempt==2 and not c:stateFor(-1) and not w.links[-1])
    end)
    test('manual throw releases the existing body and charges calibrated damage once at release',function()
        local d,s,w,c,p,step,capture=fixture();capture();local body=w.actors[-1];local actor=s.state.heroes[1].actorId
        local packet=p(1);assert(s:intent(1,packet,.7)=='OK')
        assert(d.damageCalls==1 and d.enemies[-1].health==2 and c:stateFor(-1)=='Thrown' and not w.links[-1])
        assert(w.actors[-1]==body and d.enemies[-1].ownerUserId==20 and s.state.heroes[1].actorId==actor)
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3 and count(s,'EnemyThrown')==1)
        assert(s:intent(1,packet,.7)=='STALE_SEQUENCE');step(.8)
        assert(d.damageCalls==1 and c:blocksEnemy(-1))
        local row=s.logs[#s.logs];for _,r in ipairs(s.logs) do if r.kind=='EnemyThrown' then row=r end end
        assert(row.data.sourceProfile==17 and row.data.sourceRawDamage==4 and row.data.damage==1)
    end)
    test('failed physical release does not charge throw damage or lose the held body',function()
        local d,s,w,c,p,_,capture=fixture();capture();w.releaseFails=true
        assert(s:intent(1,p(1),.7)~='OK')
        assert(d.damageCalls==0 and d.enemies[-1].health==3 and c:stateFor(-1)=='Carried' and w.links[-1]==1)
    end)
    test('a held body that physically died between ticks cannot be thrown or charged release damage',function()
        local d,s,w,c,p,_,capture=fixture();capture();w.hazards[-1]='EngineDeath'
        assert(not c:interaction(1).available,'A physically dead body cannot advertise a throw')
        assert(s:intent(1,p(1),.7)=='NOT_ALIVE')
        assert(d.damageCalls==0 and d.enemies[-1].dead and not c:stateFor(-1) and not w.links[-1] and w.kills==1)
    end)
    test('a lethal release uses the existing death path once without resurrecting its carry state',function()
        local d,s,w,c,p,_,capture=fixture();capture();d.enemies[-1].health=1
        assert(s:intent(1,p(1),.7)=='OK')
        assert(d.enemies[-1].dead and d.enemies[-1].health==0 and not c:stateFor(-1) and d.damageCalls==1 and w.kills==1)
        assert(d.enemies[-1].ownerUserId==20 and count(s,'EnemyThrown')==1)
    end)
    test('occupied hands reject the heavy strike without throwing or ordinary attack fallback',function()
        local d,s,w,c,p,_,capture=fixture();capture()
        assert(s:intent(1,p(1,{attack='Dash'}),.7)=='HANDS_FULL')
        assert(c:stateFor(-1)=='Carried' and d.damageCalls==0 and s.combat[1].attack==nil)
    end)
    test('a holder hit drops the same enemy without damage or new resources',function()
        local d,s,w,c,_,step,capture=fixture(true);capture()
        assert(s:_hit(2,1,'Punch'));step(.3)
        assert(not c:stateFor(-1) and not w.links[-1] and d.damageCalls==0 and d.enemies[-1].health==3)
        assert(count(s,'EnemyDropped')==1 and s.state.heroes[1].respawns==3)
    end)
    test('holder death or a new appearance drops from the old pose without transferring the link',function()
        local d,s,w,c,_,step,capture=fixture();capture();s:_die(1,'fixture');step(.3)
        assert(s.state.heroes[1].attempt==2 and not c:stateFor(-1) and not w.links[-1])
        assert(d.enemies[-1].health==3 and d.damageCalls==0 and count(s,'EnemyDropped')==1)
    end)
    test('an accepted flight survives thrower death and ends with restored enemy control after its finite reaction',function()
        local d,s,w,c,p,step,capture=fixture();capture();assert(s:intent(1,p(1),.7)=='OK')
        s:_die(1,'fixture');step(.8);assert(c:stateFor(-1)=='Thrown')
        step(1.56)
        assert(not c:stateFor(-1) and not c:blocksEnemy(-1) and d.enemies[-1].reactionUntil==nil)
        assert(w.actors[-1].reaction==false and d.damageCalls==1 and d.enemies[-1].health==2)
    end)
    test('physical hazards kill an existing held or thrown enemy through its one death path',function()
        for _,throw in ipairs({false,true}) do
            local d,s,w,c,p,step,capture=fixture();capture()
            if throw then assert(s:intent(1,p(1),.7)=='OK') end
            w.hazards[-1]='Fall';step(throw and .8 or .3)
            assert(d.enemies[-1].dead and not c:stateFor(-1) and not w.links[-1] and w.kills==1)
            assert(d.enemies[-1].ownerUserId==20)
        end
    end)
    test('failed BeginAttack creates no pending link or takeover engagement',function()
        local d,s,w,c,p=fixture();local event=s._event
        s._event=function(self,kind,...)
            if kind=='BeginAttack' then return 'STALE_ACTOR' end
            return event(self,kind,...)
        end
        assert(s:intent(1,p(1),.1)=='STALE_ACTOR')
        c:step(.23);assert(not c:stateFor(-1) and not d.enemies[-1].engaged and not w.links[-1])
    end)
    test('an accepted grab clears normal respawn protection before its delayed effect without another reserve',function()
        local d,s,w,c,p,step=fixture();s:_die(1,'fixture');step(.1)
        local h=s.state.heroes[1];local id=h.actorId
        assert(h.shield and h.respawns==2)
        assert(s:intent(1,p(1),.2)=='OK')
        assert(not s.state.heroes[1].shield and not w.actors[1].held and not c:stateFor(-1))
        step(.33)
        assert(c:stateFor(-1)=='Carried' and s.state.heroes[1].actorId==id
            and s.state.heroes[1].respawns==2 and s.combat[1].rawLife==47 and d.enemies[-1].health==3)
    end)
    test('stale or client-selected target intents cannot enter the grab shortcut',function()
        for _,override in ipairs({{actorId='old'},{connectionEpoch=2},{enemyId=-1},{damage=99}}) do
            local d,s,w,c,p,step=fixture();assert(s:intent(1,p(1,override),.1)~='OK');step(.23)
            assert(not c:stateFor(-1) and not d.enemies[-1].engaged and d.enemies[-1].health==3)
        end
    end)
    test('closing clears held flight and pending states idempotently without spawning or damage',function()
        local d,s,w,c,_,_,capture=fixture();capture();local spawns=w.spawns
        c:close();local releases=#w.releaseCalls;c:close();c:step(1)
        assert(not c:stateFor(-1) and not c:interaction(1).available and not w.links[-1])
        assert(#w.releaseCalls==releases and d.damageCalls==0 and w.spawns==spawns and d.enemies[-1].health==3)
        local d2,s2,w2,c2,p2=fixture();assert(s2:intent(1,p2(1),.1)=='OK');c2:close();c2:step(.23)
        assert(not c2:stateFor(-1) and not w2.links[-1] and count(s2,'EnemyGrabbed')==0)
    end)
    print('EnemyCarry: '..passed..' passed')
end
