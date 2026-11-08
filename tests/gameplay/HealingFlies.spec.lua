return function(Flies,Session,Core,Combat,Config,FakeWorld,Definition)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture(raw,second)
        local w=FakeWorld.new();w.positions={};w.food={};w.catches={};w.front={}
        local spawn=w.spawn
        function w:spawn(uid,...)
            local ok=spawn(self,uid,...)
            if ok then self.positions[uid]={x=0,y=3,z=0};self.front[uid]=true end
            return ok
        end
        function w:position(uid) return self.positions[uid] end
        function w:healingFly(id,p) self.food[id]=p and table.clone(p) or nil end
        function w:catchFly(uid,id) self.food[id]=nil;self.catches[#self.catches+1]={uid=uid,id=id} end
        function w:canCatchFly(uid,p,range,height)
            local a=self.positions[uid]
            return a~=nil and self.front[uid] and math.abs(a.y-p.y)<=height
                and (a.x-p.x)^2+(a.y-p.y)^2+(a.z-p.z)^2<=range^2
        end
        local roster={{userId=1,template='Mr. Green'}}
        if second then roster[2]={userId=2,template='Mr. Green'} end
        local s=Session.new(Core,Combat,Config,roster,'food-run',w);s:step(0)
        for _,uid in ipairs(s.order) do
            s.combat[uid].rawLife=raw or 31
            assert(s:_event('SetHealth',uid,{health=Combat.hearts(raw or 31)})=='OK')
        end
        local cfg=table.clone(Config)
        cfg.Level={zones={{flies={{id='early-1',x=3,y=4,z=0}}},{flies={{id='late-1',x=20,y=4,z=0}}}}}
        cfg.HealingFlies={range=6,height=3,facingDot=.25,windup=.16,bobHeight=0,bobSpeed=2}
        local f=Flies.new(s,w,cfg);f:activate(1)
        s.contextualAttack=function(uid,now,action)
            if action~='Punch' then return 'NO_INTERACTION' end
            return f:interact(uid,now)
        end
        local sequences={}
        local function packet(uid,overrides)
            local h=s.state.heroes[uid];sequences[uid]=(sequences[uid] or 0)+1
            local p={kind='Attack',attack='Punch',seq=sequences[uid],runId=s.state.runId,actorId=h.actorId,
                attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch}
            for k,v in pairs(overrides or {}) do p[k]=v end
            return p
        end
        local function step(now) s:step(now);f:step(now) end
        return s,w,f,packet,step
    end
    test('source static fly inventory is two early and four late food objects',function()
        local counts,total={},0
        for i,zone in ipairs(Definition.zones) do
            counts[i]=#(zone.flies or {});total+=counts[i]
        end
        assert(total==6 and counts[3]==2 and counts[6]==4,'six source-classified food records must enter the route')
    end)
    test('tongue catches add exactly eight raw Life on impact and preserve identity/resources',function()
        local s,w,f,packet,step=fixture(31);local h=s.state.heroes[1];local actor=h.actorId
        assert(f:interaction(1).available and f:interaction(1).label=='ЛОВИТЬ МУХУ')
        assert(s:intent(1,packet(1),.1)=='OK')
        assert(s.combat[1].rawLife==31 and w.food['early-1'],'no healing before actual catch')
        step(.27)
        h=s.state.heroes[1]
        assert(s.combat[1].rawLife==39 and h.health==Combat.hearts(39))
        assert(h.actorId==actor and h.attempt==1 and h.respawns==3 and h.status=='Alive')
        assert(not w.food['early-1'] and #w.catches==1 and f:snapshot().consumed==1)
    end)
    test('healing caps at47 and a full-health catch still consumes its one fly',function()
        for _,raw in ipairs({43,47}) do
            local s,w,f,p,step=fixture(raw)
            assert(s:intent(1,p(1),.1)=='OK');step(.27)
            assert(s.combat[1].rawLife==47 and f:snapshot().consumed==1 and #w.catches==1)
            f:activate(1);step(1)
            assert(not f:interaction(1).available and not w.food['early-1'])
        end
    end)
    test('a missed tongue heals nothing and leaves the food available',function()
        local s,w,f,p,step=fixture(31)
        assert(s:intent(1,p(1),.1)=='OK');w.positions[1].x=-20;step(.27)
        assert(s.combat[1].rawLife==31 and w.food['early-1'] and f:snapshot().consumed==0)
        w.positions[1].x=0;assert(f:interaction(1).available)
    end)
    test('two accepted tongues compete for the same item without duplicated healing',function()
        local s,w,f,p,step=fixture(31,true)
        assert(s:intent(1,p(1),.1)=='OK' and s:intent(2,p(2),.1)=='OK');step(.27)
        assert(s.combat[1].rawLife==39 and s.combat[2].rawLife==31 and #w.catches==1)
    end)
    test('hit reaction interrupts a tongue before the catch',function()
        local s,w,f,p,step=fixture(31,true)
        assert(s:intent(1,p(1),.1)=='OK');assert(s:_hit(2,1,'Punch'))
        local damaged=s.combat[1].rawLife;step(.27)
        assert(s.combat[1].rawLife==damaged and w.food['early-1'] and #w.catches==0)
    end)
    test('an interrupted tongue stays cancelled after a long frame clears its reaction',function()
        local s,w,f,p,step=fixture(31,true)
        assert(s:intent(1,p(1),.1)=='OK');assert(s:_hit(2,1,'Punch'))
        s:step(2);local recovered=s.combat[1].rawLife
        f:step(2)
        assert(s.combat[1].rawLife==recovered and w.food['early-1'] and #w.catches==0,
            'Historical reaction must cancel the pending tongue even after recovery')
    end)
    test('death and a fresh appearance cannot inherit a pending catch',function()
        local s,w,f,p,step=fixture(31)
        assert(s:intent(1,p(1),.1)=='OK');local old=s.state.heroes[1].actorId
        s:_die(1,'fixture');step(.27)
        assert(s.state.heroes[1].actorId~=old and s.state.heroes[1].attempt==2)
        assert(w.food['early-1'] and #w.catches==0 and s.state.heroes[1].respawns==2)
    end)
    test('already accepted tongue finishes on its offline body without a new appearance',function()
        local s,w,f,p,step=fixture(31)
        local old=s.state.heroes[1].actorId
        assert(s:intent(1,p(1),.1)=='OK');assert(s:connection(1,false,.11)=='OK');step(.27)
        assert(s.combat[1].rawLife==39 and not s.state.heroes[1].connected)
        assert(s.state.heroes[1].actorId==old and s.state.heroes[1].respawns==3 and #w.catches==1)
        assert(not f:interaction(1).available)
    end)
    test('stale or client-selected item/heal intents cannot enter the contextual shortcut',function()
        for _,override in ipairs({{actorId='old'},{runId='old'},{connectionEpoch=2},{flyId='early-1'},{heal=47}}) do
            local s,w,f,p,step=fixture(31)
            assert(s:intent(1,p(1,override),.1)~='OK');step(.27)
            assert(s.combat[1].rawLife==31 and w.food['early-1'] and #w.catches==0)
        end
    end)
    test('catch respects cooldown and consumes a repeated packet at most once',function()
        local s,w,f,p,step=fixture(31);local packet=p(1)
        assert(s:intent(1,packet,.1)=='OK')
        assert(s:intent(1,packet,.1)=='STALE_SEQUENCE')
        assert(s:intent(1,p(1),.11)=='COOLDOWN');step(.27)
        assert(s.combat[1].rawLife==39 and #w.catches==1)
    end)
    test('BeginAttack removes respawn protection before tongue effect without spending another reserve',function()
        local s,w,f,p,step=fixture(31)
        s:_die(1,'fixture');step(.1);local h=s.state.heroes[1]
        assert(h.shield and h.respawns==2)
        assert(s:intent(1,p(1),.2)=='OK');h=s.state.heroes[1]
        assert(not h.shield and not w.actors[1].held and h.respawns==2)
        step(.37);assert(s.state.heroes[1].respawns==2 and #w.catches==1)
    end)
    test('failed authoritative health event neither consumes food nor changes raw Life',function()
        local s,w,f,p,step=fixture(31);local original=s._event
        s._event=function(self,kind,...)
            if kind=='SetHealth' then return 'STALE_ACTOR' end
            return original(self,kind,...)
        end
        assert(s:intent(1,p(1),.1)=='OK');step(.27)
        assert(s.combat[1].rawLife==31 and w.food['early-1'] and #w.catches==0)
    end)
    test('later zones activate once and another run has independent food',function()
        local s,w,f,p,step=fixture(31)
        assert(not w.food['late-1']);f:activate(2);assert(w.food['late-1'])
        assert(s:intent(1,p(1),.1)=='OK');step(.27);f:activate(1)
        assert(not w.food['early-1'] and f:snapshot().total==2)
        local s2,w2,f2=fixture(31)
        assert(w2.food['early-1'] and f2:snapshot().consumed==0 and s2.combat[1].rawLife==31)
    end)
    test('closing a run cancels pending tongues and removes its remaining visuals',function()
        local s,w,f,p,step=fixture(31)
        assert(s:intent(1,p(1),.1)=='OK');s:_die(1,'fixture')
        f:close();step(.27)
        assert(next(w.food)==nil and #w.catches==0 and not f:interaction(1).available)
    end)
    print('HealingFlies: '..passed..' passed')
end
