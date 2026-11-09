return function(Intro,Director,Config,Combat,Controller,Session,Core,Registry,FakeWorld,WorldIntro,Carry)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function fixture(runId)
        local w=FakeWorld.new();w.names={};w.positions={};w.events={};w.presentations={};w.patterns=0
        function w:spawnEnemy(id,kind,p) self:spawn(id,id);self.positions[id]=table.clone(p);return true end
        function w:enemyIdentity(id,actorId) self.actors[id].id=actorId end
        function w:enemyHealth(id,n) self.actors[id].health=n end
        function w:position(id) return self.positions[id] end
        function w:stage(s) self.stageName=s end
        function w:progress() end
        function w:reached() return false end
        function w:enemyMove() end
        function w:face() end
        function w:cue() end
        function w:atExit() return false end
        function w:clearActors() self.actors={};self.positions={};self:bossIntro(nil) end
        function w:bossIntro(state)
            self.bossIntroState=state
            self.presentations[#self.presentations+1]=state or false
            for _,event in ipairs(state and state.events or {}) do self.events[#self.events+1]=event.kind..':'..event.counter end
        end
        local s=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},
            {userId=2,template='Mr. Yellow'},{userId=3,template='Mr. Brown'}},runId or 'intro-a',w)
        s:step(0)
        for _,slot in ipairs(s.order) do w.positions[slot]={x=603,y=3,z=(slot-2)*7} end
        local pattern={new=function()
            w.patterns+=1
            return {step=function() end,interaction=function() return {available=false} end}
        end}
        local d=Director.new(s,w,Combat,Config,pattern,nil,nil,nil,nil,Intro)
        return d,w,s,pattern
    end
    local function at(d,counter) d:step(d.bossIntro.state.startedAt+counter/60,1/60) end
    local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
    local function scalarTree(value)
        local t=type(value);assert(t=='table' or t=='number' or t=='string' or t=='boolean' or t=='nil')
        if t=='table' then for k,v in pairs(value) do scalarTree(k);scalarTree(v) end end
    end
    test('guardian selection waits for controller then defers actual boss and pattern until finite intro ends',function()
        local d,w=fixture();local ready=false
        d.bossGate=function() return ready and {state='Human',userId=50} or {state='Waiting'} end
        d.ownerNames[50]='Guardian';d.ownerConnections={[50]=false}
        d:_boss();eq(d.stage,'BossReady');assert(not d.bossIntro and not w.actors[-99])
        ready=true;d:step(.25,.1)
        eq(d.stage,'BossIntro');eq(d.bossIntro.state.counter,1);eq(w.patterns,0)
        assert(not w.actors[-99] and not d:controlled(50));eq(#d:available(50),3)
        at(d,0xFE);eq(d.stage,'BossIntro');assert(not w.actors[-99]);eq(w.patterns,0)
        at(d,0xFF);eq(d.stage,'Boss');eq(w.patterns,1);eq(d.enemies[-99].ownerUserId,50)
        eq(d.enemies[-99].connected,false);eq(d.byUserId[50],-99);eq(d.enemies[-99].connectionEpoch,1)
        eq(w.bossIntroState,nil);eq(d.bossIntro.state.fearFrame,0x33)
        d:step(20,.1);eq(w.patterns,1)
    end)
    test('nominal sixty hertz counter keeps fear32 at E0 and fear33 through the FF non-write',function()
        local d,w=fixture();d:_boss();local intro=d.bossIntro
        eq(intro.state.counter,1);eq(intro.state.fearFrame,0x32);eq(intro.state.fearAnimation,0x2C)
        for slot=1,3 do eq(intro.state.heroActors[slot],d.session.state.heroes[slot].actorId) end
        at(d,0xDF);eq(w.bossIntroState.fearFrame,0x32);eq(w.bossIntroState.cameraCut,false)
        at(d,0xE0);eq(w.bossIntroState.fearFrame,0x32);eq(w.bossIntroState.cameraCut,true)
        at(d,0xE1);eq(w.bossIntroState.fearFrame,0x33);eq(w.bossIntroState.fearAnimation,0x2E)
        at(d,0xFF);eq(intro.state.counter,255);eq(intro.state.phase,'Complete');eq(intro.state.fearFrame,0x33)
        eq(intro.state.active,false);eq(w.bossIntroState,nil)
    end)
    test('crossed source milestones emit exactly once across skipped visual frames',function()
        local d,w=fixture();d:_boss();at(d,0x64)
        eq(table.concat(w.events,','),'Stomp:48,FootMotionStarted:80,Stomp:100')
        local n=#w.presentations;at(d,0x64);eq(#w.events,3);eq(#w.presentations,n)
        at(d,0xFF)
        eq(table.concat(w.events,','),'Stomp:48,FootMotionStarted:80,Stomp:100,ArenaCut:224,IntroEnded:255')
        d:step(9,.1);eq(#w.events,5)
    end)
    test('large step crossing E0 preserves fear write32 and records cut once',function()
        local d,w=fixture();d:_boss();at(d,0xE0)
        eq(w.bossIntroState.fearFrame,0x32);eq(w.bossIntroState.cameraCut,true)
        at(d,0xFF);eq(d.bossIntro.state.fearFrame,0x33)
    end)
    test('intro changes no hero resources bodies controls or damage',function()
        local d,w,s=fixture();local h=s.state.heroes[1];local body=w.actors[1]
        s.combat[1].rawLife=31
        local health,reserve,attempt,shield=h.health,h.respawns,h.attempt,h.shield
        local spawns,kills,impulses=w.spawns,w.kills,w.impulses
        d:_boss();at(d,0x64)
        local function intent(kind,seq)
            return {kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,
                connectionEpoch=h.connectionEpoch,seq=seq,x=kind=='Move' and 1 or nil,z=kind=='Move' and 0 or nil}
        end
        eq(s:intent(1,intent('Move',1),2),'OK');eq(w.lastMove[1],1)
        eq(s:intent(1,intent('Jump',2),2.01),'OK');eq(w.lastJump,1)
        eq(s.combat[1].rawLife,31);eq(h.health,health);eq(h.respawns,reserve);eq(h.attempt,attempt);eq(h.shield,shield)
        eq(w.actors[1],body);eq(w.spawns,spawns);eq(w.kills,kills);eq(w.impulses,impulses)
    end)
    test('body replacement excludes that identity without healing or retargeting fear',function()
        local d,w,s=fixture();d:_boss();local old=w.bossIntroState.heroActors[1]
        s.state.heroes[1]=table.clone(s.state.heroes[1]);s.state.heroes[1].actorId='new-actor'
        w.actors[1]={id='new-actor'};s.combat[1].rawLife=12
        at(d,0x30);assert(w.bossIntroState.heroActors[1]==nil and old~='new-actor')
        eq(w.bossIntroState.heroActors[2],s.state.heroes[2].actorId);eq(s.combat[1].rawLife,12)
        at(d,0xFF);eq(s.state.heroes[1].actorId,'new-actor');eq(s.combat[1].rawLife,12)
    end)
    test('run and level replacement cancel without spawning a stale Guardian',function()
        for _,field in ipairs({'runId','levelEpoch'}) do
            local d,w,s=fixture();d:_boss()
            s.state[field]=field=='runId' and 'replacement' or 2
            d:step(.5,.1);eq(w.bossIntroState,nil);eq(d.bossIntro.cancelled,true)
            d:step(9,.1);assert(not w.actors[-99]);eq(w.patterns,0)
        end
    end)
    test('run end cancels all intro effects and never activates a Guardian',function()
        local d,w,s=fixture();d:_boss();s.state.status='Lost'
        d:step(.5,.1);eq(w.bossIntroState,nil);eq(d.bossIntro.cancelled,true)
        d:step(9,.1);assert(not w.actors[-99]);eq(w.patterns,0)
    end)
    test('bounded snapshot and two parties retain independent intro counters and camera cuts',function()
        local a,wa=fixture('party-a');local b,wb=fixture('party-b');a:_boss();b:_boss()
        at(a,0xE0);at(b,0x30)
        local aa,bb=a:snapshot().bossIntro,b:snapshot().bossIntro
        assert(aa.id~=bb.id);eq(aa.runId,'party-a');eq(aa.levelEpoch,1);eq(aa.counter,0xE0);eq(aa.fearFrame,0x32)
        eq(aa.phase,'AfterCut');eq(aa.cameraCut,true);eq(bb.cameraCut,false);scalarTree(aa)
        a:cancelBossIntro('Quarantine');eq(wa.bossIntroState,nil);assert(wb.bossIntroState and not b.bossIntro.cancelled)
    end)
    test('equipment intro and carried body release happen once without closing future carry',function()
        local d,w=fixture();local drops,released=0,{}
        d.clubs={bossIntro=function() drops+=1 end,step=function() end}
        d.carry={states={[-1]={mode='Carried'},[-2]={mode='Thrown'}},pending={{id=-3}},
            forgetEnemy=function(self,id) released[#released+1]=id;self.states[id]=nil end,step=function() end}
        d:_boss();d:_boss();at(d,0x64);eq(drops,1);eq(#released,2)
        table.sort(released);eq(released[1],-3);eq(released[2],-1)
        assert(not d.carry.closed and d.carry.states[-2])
        at(d,0xFF);eq(drops,1)
    end)
    test('controller quarantine and run replacement clear existing intro through real director integration',function()
        local _,w,_,pattern=fixture();local serial=0
        local c=Controller.new({Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=Config,Director=Director,
            BossIntro=Intro,GuardianPattern=pattern,clock=function() return 1 end,
            guid=function() serial+=1;return 'controller-'..serial end},w)
        local p={UserId=10,Name='Hero',DisplayName='Hero',Parent='Players'};c:join(p)
        eq(c:handle(p,{kind='Start'},{p}),'OK');c.director:_boss();eq(c.director.stage,'BossIntro')
        local first=c.director.bossIntro;c:quarantine();eq(w.bossIntroState,nil);eq(first.cancelled,true)
        eq(c:handle(p,{kind='Start'},{p}),'OK');c.director:_boss();local second=c.director.bossIntro
        c.director.result='Lost';eq(c:handle(p,{kind='Start'},{p}),'OK')
        eq(w.bossIntroState,nil);eq(second.cancelled,true)
    end)
    test('intro releases an existing carried body through live carry without damage or permanent shutdown',function()
        local d,w,s=fixture();d.carry=Carry.new(d);local carry=d.carry;local released=0
        w.positions[1]=table.clone(w.positions[-1])
        function w:canGrabEnemy() return true end
        function w:carryEnemy(id,slot) self.heldEnemy={id,slot};return true end
        function w:releaseEnemy(id) self.heldEnemy=nil;released+=1;return true end
        eq(carry:interact(1,0,'Punch'),'OK');carry:step(.12)
        eq(carry:stateFor(-1),'Carried');assert(w.heldEnemy)
        local life=d.enemies[-1].rawLife;local health=d.enemies[-1].health
        d:_boss();eq(carry:stateFor(-1),nil);eq(released,1);assert(not w.heldEnemy and not carry.closed)
        eq(d.enemies[-1].rawLife,life);eq(d.enemies[-1].health,health);eq(w.kills,0);eq(w.impulses,0)
    end)
    test('world intro owns bounded safe cosmetics and translated camera focus without changing actors or another party',function()
        local V={};V.__index=V
        function V.__add(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},V) end
        local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
        local F={};F.__index=F
        function F.__mul(a,b) return setmetatable({Position=a.Position+b.Position},F) end
        local function frame(x,y,z) return setmetatable({Position=type(x)=='table' and x or vector(x,y,z)},F) end
        local N={};N.__index=function(self,key)
            if key=='Parent' then return rawget(self,'parent') end
            return N[key]
        end
        N.__newindex=function(self,key,value)
            if key=='Parent' then
                local old=rawget(self,'parent')
                if old then for i,n in ipairs(old.children) do if n==self then table.remove(old.children,i);break end end end
                rawset(self,'parent',value);if value then value.children[#value.children+1]=self end
            else rawset(self,key,value) end
        end
        local function node(class) return setmetatable({ClassName=class,children={},attributes={}},N) end
        function N:SetAttribute(key,value) self.attributes[key]=value end
        function N:GetAttribute(key) return self.attributes[key] end
        function N:Destroy() for _,child in ipairs(table.clone(self.children)) do child:Destroy() end;self.Parent=nil;self.destroyed=true end
        local enums=setmetatable({},{__index=function(_,key) return setmetatable({},{__index=function(_,name) return name end}) end})
        local env=setmetatable({Vector3={new=vector},CFrame={new=frame,Angles=function() return frame() end},
            Color3={fromRGB=function(...) return {...} end},Enum=enums,Instance={new=node}}, {__index=getfenv()})
        setfenv(WorldIntro,env)
        local World={}
        function World.new(z)
            return setmetatable({folder=node('Folder'),offset=vector(0,0,z),actors={[1]={identity='untouched',owner=99}},clears=0},{__index=World})
        end
        function World:clearActors() self.clears+=1 end
        WorldIntro(World)
        local a,b=World.new(200),World.new(1200)
        local da,_,sa=fixture();da:_boss();local state=da.bossIntro.state
        state.counter=100;state.footFrame=0x12;state.footMotion=true
        state.events={{kind='Stomp',counter=48},{kind='FootMotionStarted',counter=80},{kind='Stomp',counter=100}}
        a:bossIntro(state);b:bossIntro(state)
        local folder=assert(a.bossIntroFolder);local other=assert(b.bossIntroFolder)
        eq(folder.Name,'BossIntro');eq(folder.Parent,a.folder);eq(folder:GetAttribute('Active'),true)
        eq(folder:GetAttribute('IntroId'),'intro-a:boss-intro:1');eq(folder:GetAttribute('Counter'),100)
        eq(folder:GetAttribute('FearFrame'),0x32);eq(folder:GetAttribute('CameraCut'),false)
        local focus=folder:GetAttribute('Focus');eq(focus.X,628);eq(focus.Z,200)
        local function inspect(parent)
            local total=0
            for _,n in ipairs(parent.children) do
                total+=1
                if n.ClassName=='Part' then assert(n.Anchored and n.Massless and not n.CanCollide and not n.CanTouch and not n.CanQuery) end
                total+=inspect(n)
            end
            return total
        end
        local total=inspect(folder);assert(total>8 and total<35)
        for counter=101,254 do state.counter=counter;state.events={};a:bossIntro(state) end
        eq(inspect(folder),total);eq(a.actors[1].identity,'untouched');eq(a.actors[1].owner,99)
        assert(type(a.bossIntroState)=='table');scalarTree(a.bossIntroState)
        a:clearActors();eq(a.bossIntroState,nil);eq(a.bossIntroFolder,nil);eq(folder.Parent,nil);eq(a.clears,1)
        eq(other.Parent,b.folder);eq(b.bossIntroFolder,other);assert(not other.destroyed)
        b:bossIntro(nil);eq(other.Parent,nil)
    end)
    print('BossIntro: '..passed..' tests passed')
end
