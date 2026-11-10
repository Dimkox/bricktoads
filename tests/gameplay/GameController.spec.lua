return function(Controller,Core,Combat,Session,Registry,Config,FakeWorld,Director,BossQueue,Journal,Variation,Level)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture(realDirector,overrides)
        local clock=1; local serial=0
        local world=FakeWorld.new(); world.names={}
        world.positions={}
        local originalSpawn=world.spawn
        function world:spawn(id,actorId,...)
            local ok=originalSpawn(self,id,actorId,...)
            if ok then self.positions[id]={x=-65,y=3,z=id*7} end
            return ok
        end
        function world:clearActors() self.actors={}; self.positions={} end
        function world:spawnEnemy(id,kind,position)
            local ok=self:spawn(id,id,nil,false)
            if ok then self.positions[id]=table.clone(position) end
            return ok
        end
        function world:enemyIdentity(id,actorId,name) self.actors[id].id=actorId; self.actors[id].ownerName=name end
        function world:position(id) return self.positions[id] end
        function world:stage(stage) self.stageName=stage end
        function world:progress(index) self.zoneIndex=index end
        function world:reached() return false end
        function world:enemyHealth(id,health) self.actors[id].hearts=health end
        function world:enemyMove() end
        function world:face() end
        function world:cue() end
        function world:atExit() return false end
        function world:projectile() end
        function world:removeProjectile() end
        local fakeDirector={new=function()
            return {hit=function() return false end,step=function() end,snapshot=function() return {stage='Approach',objective='Play'} end,
                available=function() return {} end,controlled=function() return nil end,connection=function() end,
                closeTargetForAttack=function() end}
        end}
        local deps={Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=Config,BossQueue=BossQueue,Director=realDirector and Director or fakeDirector,
            clock=function() return clock end,guid=function() serial+=1; return 'game-'..serial end}
        for k,v in pairs(overrides or {}) do deps[k]=v end
        local c=Controller.new(deps,world)
        local list={}
        local function player(id,name)
            local p={UserId=id,Name=name or ('User'..id),DisplayName=name or ('Hero'..id),Parent='Players'}
            list[#list+1]=p; c:join(p); return p
        end
        local function send(p,data) clock+=.05; return c:handle(p,data,list) end
        return c,list,player,send,function(dt) clock+=dt; c:step(clock,dt) end
    end
    test('selection is owned by the real sender and duplicate trio templates are allowed',function()
        local c,list,add,send=fixture(); local a,b,d=add(10),add(20),add(30)
        for _,p in ipairs(list) do assert(send(p,{kind='SelectHero',template='Mr. Brown'})=='OK') end
        assert(send(a,{kind='Start'})=='OK')
        for i=1,3 do assert(c.current.state.heroes[i].template=='Mr. Brown') end
        assert(c:snapshot(b,list).mine==2 and c:snapshot(d,list).mine==3)
    end)
    test('malformed and owner-spoofed choices cannot change selection',function()
        local c,list,add,send=fixture(); local a,b=add(10),add(20)
        assert(send(a,{kind='SelectHero',template='Mr. Yellow',userId=20})=='INVALID_INTENT')
        assert(send(a,{kind='SelectHero',template='Unknown'})=='INVALID_INTENT')
        assert(c:snapshot(a,list).selectedTemplate=='Mr. Green')
        assert(c:snapshot(b,list).selectedTemplate=='Mr. Green')
    end)
    test('only host starts; solo begins immediately with full initial resources',function()
        local c,list,add,send=fixture(); local a,b=add(10),add(20)
        assert(send(b,{kind='Start'})=='HOST_ONLY' and not c.current)
        c:leave(b); table.remove(list,2)
        assert(send(a,{kind='Start'})=='OK')
        local h=c.current.state.heroes[1]
        assert(h.status=='Alive' and h.respawns==3 and h.health==5)
    end)
    test('active choices cannot heal, add a hero, or change the frozen template',function()
        local c,list,add,send=fixture(); local a=add(10)
        send(a,{kind='Start'}); local late=add(20)
        c.current.combat[1].rawLife=31
        assert(send(a,{kind='SelectHero',template='Mr. Brown'})=='RUN_ACTIVE')
        assert(send(late,{kind='SelectHero',template='Mr. Brown'})=='RUN_ACTIVE')
        assert(#c.current.order==1 and c.current.combat[1].rawLife==31)
        assert(c:snapshot(late,list).mine==nil)
    end)
    test('a fourth owner receives spectator state and cannot gain a hero',function()
        local c,list,add,send=fixture(); local a=add(10); add(20); add(30); local d=add(40)
        send(a,{kind='Start'}); assert(#c.current.order==3 and c:snapshot(d,list).mine==nil)
    end)
    test('obsolete Player object cannot select or receive private state',function()
        local c,list,add,send=fixture(); local old=add(10); local fresh=add(10,'Returned')
        assert(send(old,{kind='SelectHero',template='Mr. Brown'})=='STALE_CONNECTION')
        assert(c:snapshot(old,list)==nil)
        assert(send(fresh,{kind='SelectHero',template='Mr. Yellow'})=='OK')
    end)
    test('returning current owner retains same actor life reserve and template',function()
        local c,list,add,send=fixture(); local a=add(10)
        send(a,{kind='SelectHero',template='Mr. Yellow'}); send(a,{kind='Start'})
        c.current.combat[1].rawLife=31
        local actor=c.current.state.heroes[1].actorId
        c:leave(a); local fresh=add(10,'Returned')
        local h=c.current.state.heroes[1]
        assert(h.actorId==actor and h.respawns==3 and h.template=='Mr. Yellow' and c.current.combat[1].rawLife==31)
        assert(c:snapshot(fresh,list).mine==1)
    end)
    test('result needs manual new game and creates fresh run only once per accepted start',function()
        local c,list,add,send=fixture(); local a=add(10); send(a,{kind='Start'})
        local first=c.current.state.runId; c.director.result='Won'
        assert(c:snapshot(a,list).status=='Won' and c:snapshot(a,list).canStart)
        assert(send(a,{kind='Start'})=='OK' and c.current.state.runId~=first)
        local nextRun=c.current.state.runId
        assert(send(a,{kind='Start'})=='RUN_ACTIVE' and c.current.state.runId==nextRun)
    end)
    test('Enemy and Spectator preferences leave hero places to selected heroes',function()
        local c,list,add,send=fixture(true); local enemy,hero,viewer=add(10),add(20),add(30)
        assert(send(enemy,{kind='SelectRole',role='Enemy'})=='OK')
        assert(send(viewer,{kind='SelectRole',role='Spectator'})=='OK')
        assert(c:snapshot(hero,list).host==hero.UserId and c:snapshot(hero,list).canStart)
        assert(send(hero,{kind='Start'})=='OK' and #c.current.order==1)
        assert(c:snapshot(enemy,list).mine==nil and c:snapshot(hero,list).mine==1)
    end)
    test('no hero means no game start or consumed appearances',function()
        local c,list,add,send=fixture(true); local a=add(10)
        send(a,{kind='SelectRole',role='Enemy'})
        assert(send(a,{kind='Start'})=='NO_HERO' and c.current==nil and c.world.spawns==0)
    end)
    local function enemyFixture()
        local c,list,add,send,tick=fixture(true); local hero,enemy=add(10),add(20)
        assert(send(enemy,{kind='SelectRole',role='Enemy'})=='OK'); assert(send(hero,{kind='Start'})=='OK')
        return c,list,add,send,tick,hero,enemy
    end
    local function claim(c,send,player,id,extra)
        local p={kind='ClaimEnemy',runId=c.current.state.runId,levelEpoch=c.current.state.levelEpoch,enemyId=id or -1}
        for k,v in pairs(extra or {}) do p[k]=v end
        return send(player,p)
    end
    test('claim takes the same damaged body without healing a hero slot or spawning',function()
        local c,list,_,send,_,_,enemy=enemyFixture()
        c.director.enemies[-1].health=2
        local body=c.world.actors[-1]; local spawns=c.world.spawns; local position=c.world.positions[-1]
        assert(claim(c,send,enemy)=='OK')
        local role=c:snapshot(enemy,list).enemyRole
        assert(role.hearts==2 and role.enemyId==-1 and c:snapshot(enemy,list).mine==nil)
        assert(c.world.actors[-1]==body and c.world.positions[-1]==position and c.world.spawns==spawns)
        assert(c:controlledSlot(enemy.UserId)==-1)
        assert(claim(c,send,enemy)=='OK' and c.world.spawns==spawns)
    end)
    test('hero including eliminated hero cannot reenter this run as an enemy',function()
        local c,_,_,send,_,hero=enemyFixture()
        assert(claim(c,send,hero)=='HERO_LOCKED')
        c.current.state.heroes[1].status='Eliminated'
        assert(claim(c,send,hero)=='HERO_LOCKED')
    end)
    test('claims reject wrong run level spoofed owner and malformed enemy id',function()
        local c,_,_,send,_,_,enemy=enemyFixture()
        assert(claim(c,send,enemy,-1,{runId='old'})=='WRONG_RUN')
        assert(claim(c,send,enemy,-1,{levelEpoch=2})=='STALE_LEVEL')
        assert(claim(c,send,enemy,-1,{userId=10})=='INVALID_INTENT')
        assert(claim(c,send,enemy,0/0)=='INVALID_INTENT')
        assert(c.director:controlled(enemy.UserId)==nil)
    end)
    test('a second applicant cannot take or duplicate an occupied body',function()
        local c,_,add,send,_,_,enemy=enemyFixture(); local other=add(30)
        assert(claim(c,send,enemy)=='OK')
        assert(claim(c,send,other)=='ENEMY_OCCUPIED' and c.director:controlled(other.UserId)==nil)
    end)
    test('accepted directed hero attack locks the enemy before a delayed miss',function()
        local c,_,_,send,_,hero,enemy=enemyFixture()
        c.world.targetsFor[1]={-1}
        local h=c.current.state.heroes[1]
        assert(send(hero,{kind='Attack',attack='Punch',runId=c.current.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=1,connectionEpoch=h.connectionEpoch,seq=1})=='OK')
        c.world.targetsFor[1]={}
        assert(claim(c,send,enemy)=='ENEMY_ENGAGED')
    end)
    test('successful contextual primary action does not engage an unrelated ordinary enemy',function()
        local c,_,_,send,_,hero,enemy=enemyFixture()
        c.world.targetsFor[1]={-1}
        -- Use the real Session contextual shortcut shared by tongues and pickups.
        c.director.interact=function() return 'OK' end
        local h=c.current.state.heroes[1]
        assert(send(hero,{kind='Attack',attack='Punch',runId=c.current.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=1,connectionEpoch=h.connectionEpoch,seq=1})=='OK')
        assert(c.current.combat[1].attack==nil,'A contextual action must not schedule an ordinary Punch')
        assert(not c.director.enemies[-1].engaged,'Catching food or handling a ball must not close an untouched enemy offer')
        assert(claim(c,send,enemy)=='OK','The same untouched enemy must remain available to another player')
    end)
    test('attack lock uses acceptance time when the first target reaction just expired',function()
        local c,_,_,send,_,hero,enemy=enemyFixture()
        c.world.targetsFor[1]={-1,-2}
        c.director.enemies[-1].engaged=true
        c.director.enemies[-1].reactionUntil=c.director.now+.025
        local h=c.current.state.heroes[1]
        assert(send(hero,{kind='Attack',attack='Punch',runId=c.current.state.runId,actorId=h.actorId,attempt=h.attempt,
            levelEpoch=1,connectionEpoch=h.connectionEpoch,seq=1})=='OK')
        assert(claim(c,send,enemy,-2)=='OK','Unrelated enemy behind the recovered first target must remain claimable')
    end)
    test('one enemy life survives disconnect and cannot be reset by selecting a different sentry',function()
        local c,list,add,send,_,_,enemy=enemyFixture(); assert(claim(c,send,enemy)=='OK')
        c.director:_kill(-1)
        assert(claim(c,send,enemy,-2)=='ENEMY_LIFE_SPENT')
        c:leave(enemy); local returned=add(20)
        assert(claim(c,send,returned,-2)=='ENEMY_LIFE_SPENT')
        assert(c:snapshot(returned,list).enemyUnavailableReason=='ENEMY_LIFE_SPENT')
    end)
    test('current replacement retains enemy body health and rejects stale sender and epoch',function()
        local c,list,add,send,_,_,enemy=enemyFixture(); assert(claim(c,send,enemy)=='OK')
        c.director.enemies[-1].health=2
        local before=c.director:controlled(enemy.UserId); local body=c.world.actors[-1]
        local returned=add(20,'Returned')
        local role=c:snapshot(returned,list).enemyRole
        assert(role.actorId==before.actorId and role.hearts==2 and role.connectionEpoch>before.connectionEpoch and c.world.actors[-1]==body)
        assert(claim(c,send,enemy,-2)=='STALE_CONNECTION')
        local p={kind='Move',x=1,z=0,runId=c.current.state.runId,actorId=role.actorId,attempt=1,levelEpoch=1,connectionEpoch=before.connectionEpoch,seq=1}
        assert(send(returned,p)=='STALE_CONNECTION')
        p.connectionEpoch=role.connectionEpoch; assert(send(returned,p)=='OK' and c.world.lastMove[1]==-1)
    end)
    test('separate new game clears enemy spent life but active role preference cannot reset a run',function()
        local c,_,_,send,_,hero,enemy=enemyFixture(); assert(claim(c,send,enemy)=='OK')
        assert(send(enemy,{kind='SelectRole',role='Hero'})=='RUN_ACTIVE')
        c.director:_kill(-1); c.director.result='Won'
        assert(send(hero,{kind='Start'})=='OK')
        assert(claim(c,send,enemy)=='OK' and #c.current.order==1)
    end)
    local function choose(c,send,player,view,extra)
        local p={kind='ChooseView',runId=c.current.state.runId,levelEpoch=c.current.state.levelEpoch,view=view}
        for k,v in pairs(extra or {}) do p[k]=v end
        return send(player,p)
    end
    local function eliminate(c,tick,slot)
        for _=1,4 do
            c.current:_die(slot,'Confirmed test death')
            if c.current.state.heroes[slot].status~='Eliminated' then tick(.1) end
        end
        assert(c.current.state.heroes[slot].status=='Eliminated')
    end
    test('eliminated hero can choose menu and watch without changing the continuing duo',function()
        local c,list,add,send,tick=fixture(true); local a,b=add(10),add(20)
        assert(send(a,{kind='Start'})=='OK')
        eliminate(c,tick,1)
        c.current.combat[2].rawLife=31
        local state=c.current.state; local run=state.runId; local teammate=state.heroes[2]
        local body=c.world.actors[2]; local spawns=c.world.spawns; local kills=c.world.kills
        local initial=c:snapshot(a,list)
        assert(initial.view=='Choice' and initial.canChooseView,'Eliminated hero must receive a personal choice')
        assert(choose(c,send,a,'Menu')=='OK')
        assert(c.current.state.heroes[1].view=='Menu' and c:snapshot(a,list).view=='Menu')
        local revision=c.current.state.revision; local logs=#c.current.logs
        assert(choose(c,send,a,'Menu')=='OK' and c.current.state.revision==revision and #c.current.logs==logs,
            'Repeating the same view must not emit a duplicate Core event')
        assert(choose(c,send,a,'Spectating')=='OK')
        local watching=c:snapshot(a,list)
        assert(watching.view=='Spectating' and watching.heroes[1].view=='Spectating')
        assert(c.current.state.runId==run and c.current.state.status=='Active' and not c.current.state.partyDissolved)
        assert(c.current.state.heroes[1].respawns==0 and c.current.state.heroes[1].health==0 and c.current.combat[1].rawLife==0)
        assert(c.current.state.heroes[2].actorId==teammate.actorId and c.current.state.heroes[2].respawns==teammate.respawns
            and c.current.combat[2].rawLife==31 and c.world.actors[2]==body)
        assert(c.world.spawns==spawns and c.world.kills==kills and #c.current.order==2)
        assert(c:snapshot(b,list).view=='Playing' and not c:snapshot(b,list).canChooseView)
        assert(send(a,{kind='Start'})=='RUN_ACTIVE' and not watching.canStart and not watching.canSelect)
    end)
    test('observer menu is personal and survives Player replacement without spawning',function()
        local c,list,add,send,_,hero=enemyFixture(); local viewer=add(30)
        local body=c.world.actors[1]; local spawns=c.world.spawns
        local initial=c:snapshot(viewer,list)
        assert(initial.view=='Spectating' and initial.canChooseView and not initial.canStart and not initial.canSelect)
        assert(choose(c,send,viewer,'Menu')=='OK','Observer must be able to choose a personal menu')
        assert(c:snapshot(viewer,list).view=='Menu' and c:snapshot(hero,list).view=='Playing')
        local replacement=add(30,'Returned observer')
        assert(c:snapshot(replacement,list).view=='Menu')
        assert(choose(c,send,viewer,'Spectating')=='STALE_CONNECTION' and c:snapshot(viewer,list)==nil)
        assert(choose(c,send,replacement,'Spectating')=='OK' and c:snapshot(replacement,list).view=='Spectating')
        assert(c.current.state.status=='Active' and not c.current.state.partyDissolved and #c.current.order==1)
        assert(c.world.actors[1]==body and c.world.spawns==spawns and c.current.state.heroes[1].respawns==3)
        assert(choose(c,send,replacement,'Menu')=='OK')
        assert(claim(c,send,replacement,-1)=='OK' and c:snapshot(replacement,list).view=='Playing'
            and not c:snapshot(replacement,list).canChooseView)
        c.director:_kill(-1)
        assert(c:snapshot(replacement,list).view=='Choice','A newly spent enemy role must offer a fresh view choice')
    end)
    test('dead enemy menu and watch preserve its spent life through replacement and later waves',function()
        local c,list,add,send,tick,_,enemy=enemyFixture()
        assert(claim(c,send,enemy)=='OK'); c.director:_kill(-1)
        assert(c:snapshot(enemy,list).view=='Choice' and c:snapshot(enemy,list).canChooseView)
        local spawns=c.world.spawns
        assert(choose(c,send,enemy,'Menu')=='OK' and choose(c,send,enemy,'Spectating')=='OK')
        assert(c:snapshot(enemy,list).view=='Spectating' and claim(c,send,enemy,-2)=='ENEMY_LIFE_SPENT')
        assert(c.world.spawns==spawns)
        c:leave(enemy); local returned=add(20,'Returned enemy')
        assert(c:snapshot(returned,list).view=='Spectating')
        assert(choose(c,send,returned,'Menu')=='OK')
        c.director:_kill(-2); tick(.1)
        assert(c.director.stage=='Courtyard' and c:snapshot(returned,list).view=='Menu')
        assert(claim(c,send,returned,-3)=='ENEMY_LIFE_SPENT')
        assert(c.current.state.status=='Active' and #c.current.order==1 and c.director:controlled(20).status=='Dead')
    end)
    test('living roles cannot suspend their actors with a personal view choice',function()
        local c,list,_,send,_,hero,enemy=enemyFixture()
        assert(claim(c,send,enemy)=='OK')
        local spawns=c.world.spawns; local heroBody=c.world.actors[1]; local enemyBody=c.world.actors[-1]
        assert(choose(c,send,hero,'Menu')=='NOT_ELIMINATED')
        assert(choose(c,send,enemy,'Menu')=='ROLE_ACTIVE','A living enemy must keep playing its owned body')
        assert(choose(c,send,enemy,'Spectating')=='ROLE_ACTIVE')
        assert(c:snapshot(hero,list).view=='Playing' and c:snapshot(enemy,list).view=='Playing')
        assert(not c:snapshot(hero,list).canChooseView and not c:snapshot(enemy,list).canChooseView)
        assert(c.world.spawns==spawns and c.world.actors[1]==heroBody and c.world.actors[-1]==enemyBody)
    end)
    test('awaiting initial spawn and awaiting respawn heroes stay Playing and cannot choose menu',function()
        local c,list,add,send,tick=fixture(true); local hero=add(10)
        c.world.safe=false; assert(send(hero,{kind='Start'})=='OK')
        assert(c.current.state.heroes[1].status=='AwaitingInitial')
        assert(choose(c,send,hero,'Menu')=='NOT_ELIMINATED')
        assert(c:snapshot(hero,list).view=='Playing' and not c:snapshot(hero,list).canChooseView)
        c.world.safe=true; tick(1)
        c.current:_die(1,'Test death with reserves')
        assert(c.current.state.heroes[1].status=='AwaitingRespawn')
        assert(choose(c,send,hero,'Spectating')=='NOT_ELIMINATED')
        assert(c:snapshot(hero,list).view=='Playing' and not c:snapshot(hero,list).canChooseView)
    end)
    test('new game resets personal choices while the closed group always shows the result menu',function()
        local c,list,add,send=fixture(true); local hero,enemy,viewer=add(10),add(20),add(30)
        assert(send(enemy,{kind='SelectRole',role='Enemy'})=='OK')
        assert(send(viewer,{kind='SelectRole',role='Spectator'})=='OK')
        assert(send(hero,{kind='Start'})=='OK'); local run=c.current.state.runId
        assert(choose(c,send,viewer,'Menu')=='OK' and claim(c,send,enemy)=='OK')
        c.director:_kill(-1); assert(choose(c,send,enemy,'Menu')=='OK')
        c.director.result='Won'
        for _,p in ipairs(list) do
            assert(c:snapshot(p,list).view=='Menu' and not c:snapshot(p,list).canChooseView)
            assert(choose(c,send,p,'Spectating')=='RUN_CLOSED')
        end
        assert(send(hero,{kind='Start'})=='OK' and c.current.state.runId~=run)
        assert(c:snapshot(viewer,list).view=='Spectating','A separate game must reset the observer menu choice')
        assert(c:snapshot(enemy,list).view=='Spectating' and c:snapshot(enemy,list).enemyRole==nil)
        assert(choose(c,send,viewer,'Menu',{runId=run})=='WRONG_RUN')
        assert(claim(c,send,enemy)=='OK' and c:snapshot(enemy,list).view=='Playing')
    end)
    test('view choice binds current run level and sender while rejecting extra or missing fields',function()
        local c,list,add,send,tick=fixture(true); local a,b,viewer=add(10),add(20),add(30)
        assert(send(viewer,{kind='SelectRole',role='Spectator'})=='OK')
        assert(send(a,{kind='Start'})=='OK'); eliminate(c,tick,1)
        assert(choose(c,send,a,'Menu')=='OK' and choose(c,send,viewer,'Menu')=='OK')
        local before=c.current.state; local revision=before.revision
        local cases={
            {change={runId='old'},want='WRONG_RUN'},
            {change={levelEpoch=2},want='STALE_LEVEL'},
            {change={userId=b.UserId},want='INVALID_INTENT'},
            {change={connectionEpoch=1},want='INVALID_INTENT'},
            {change={actorId='spoof'},want='INVALID_INTENT'},
            {change={view='Playing'},want='INVALID_INTENT'},
            {change={view={}},want='INVALID_INTENT'},
            {change={runId={}},want='INVALID_INTENT'},
            {change={runId=''},want='INVALID_INTENT'},
            {change={levelEpoch=0},want='INVALID_INTENT'},
            {change={levelEpoch=1.5},want='INVALID_INTENT'},
            {change={levelEpoch=0/0},want='INVALID_INTENT'},
            {change={levelEpoch=math.huge},want='INVALID_INTENT'},
        }
        for _,p in ipairs({a,viewer}) do
            for _,case in ipairs(cases) do assert(choose(c,send,p,'Spectating',case.change)==case.want) end
            assert(send(p,{kind='ChooseView',runId=before.runId,view='Menu'})=='INVALID_INTENT')
            assert(send(p,{kind='ChooseView',levelEpoch=1,view='Menu'})=='INVALID_INTENT')
            assert(send(p,{kind='ChooseView',runId=before.runId,levelEpoch=1})=='INVALID_INTENT')
        end
        assert(c.current.state==before and c.current.state.revision==revision)
        assert(c:snapshot(a,list).view=='Menu' and c:snapshot(viewer,list).view=='Menu')
        assert(c.current:_clock(c.deps.clock())=='OK')
        local teammate=c.current.state.heroes[2]
        assert(c.current:_event('AdvanceLevel',2,{actorId=teammate.actorId,attempt=teammate.attempt,levelEpoch=1,
            levelId='second',destinationSafe=true,prerequisitesMet=true})=='OK')
        assert(c:snapshot(a,list).view=='Menu' and c:snapshot(viewer,list).view=='Menu')
        assert(choose(c,send,a,'Spectating',{levelEpoch=1})=='STALE_LEVEL')
        assert(choose(c,send,viewer,'Spectating',{levelEpoch=1})=='STALE_LEVEL')
        local old=a; a=add(10,'Returned eliminated hero')
        assert(c:snapshot(a,list).view=='Menu')
        assert(choose(c,send,old,'Spectating')=='STALE_CONNECTION' and c:snapshot(old,list)==nil)
        a.Parent=nil; assert(choose(c,send,a,'Spectating')=='STALE_CONNECTION')
        a.Parent='Players'; assert(choose(c,send,a,'Spectating')=='OK')
        assert(c.current.state.heroes[1].view=='Spectating')
    end)
    test('snapshot publishes world camera bounds and tolerates worlds without them',function()
        local c,list,add,send=fixture(true); local hero=add(10)
        assert(send(hero,{kind='Start'})=='OK' and c:snapshot(hero,list).cameraBounds==nil)
        function c.world:cameraBounds() return {minX=-90,maxX=130,minY=7,maxY=52,minZ=-49,maxZ=49} end
        local bounds=c:snapshot(hero,list).cameraBounds
        assert(bounds and bounds.minX==-90 and bounds.maxX==130 and bounds.minY==7 and bounds.maxY==52
            and bounds.minZ==-49 and bounds.maxZ==49,'Camera bounds must come from the active world')
    end)
    if BossQueue then
        test('group controllers use one shared guardian queue and retain distinct lifecycle identity',function()
            local shared=BossQueue.new(Config.BossQueue)
            local c,_,add,send=fixture(true,{SharedBossQueue=shared,GroupId='alpha',guid=function() return 'alpha-run' end})
            local other,_,addOther,sendOther=fixture(true,{SharedBossQueue=shared,GroupId='beta',guid=function() return 'beta-run' end})
            assert(c.bossQueue==shared and other.bossQueue==shared,'Controllers must share FIFO authority')
            send(add(10),{kind='Start'}); sendOther(addOther(20),{kind='Start'})
            assert(c.current.state.groupId=='alpha' and other.current.state.groupId=='beta')
            assert(c.current.state.levelId=='causeway' and c.bossSlot~=other.bossSlot)
            assert(shared.slots[c.bossSlot].context.groupId=='alpha' and shared.slots[other.bossSlot].context.groupId=='beta')
        end)
        local function queue(send,p) return send(p,{kind='QueueBoss',bossId='CausewayGuardian'}) end
        local function accept(c,list,send,p)
            local offer=c:snapshot(p,list).bossQueue
            assert(offer.state=='Invited' and type(offer.offerId)=='string')
            assert(send(p,{kind='ReplyBoss',offerId=offer.offerId,accepted=true})=='OK')
            assert(c:snapshot(p,list).bossQueue.state=='Accepted')
            assert(send(p,{kind='ConnectBoss',offerId=offer.offerId})=='OK')
            assert(c:snapshot(p,list).bossQueue.state=='Ready')
        end
        test('boss selection waits FIFO and removes the applicant from the next hero roster',function()
            local c,list,add,send=fixture(true); local hero,boss=add(10),add(20)
            assert(queue(send,boss)=='OK','Boss choice must be implemented')
            assert(c:snapshot(boss,list).bossQueue.state=='Queued')
            assert(c:snapshot(boss,list).preference=='Spectator')
            assert(send(hero,{kind='Start'})=='OK' and #c.current.order==1)
            accept(c,list,send,boss); c.director:_boss()
            assert(c:snapshot(boss,list).bossQueue.state=='Active')
            assert(c:snapshot(boss,list).enemyRole.template=='Boss' and c:controlledSlot(boss.UserId)==-99)
            assert(c.world.actors[-99].ownerName=='Hero20 @User20','New director must retain the assigned owner name')
        end)
        test('boss wait rejects active or eliminated same-run heroes and living ordinary enemies',function()
            local c,list,add,send,_,hero,enemy=enemyFixture()
            assert(queue(send,hero)=='HERO_LOCKED')
            c.current.state.heroes[1].status='Eliminated'; assert(queue(send,hero)=='HERO_LOCKED')
            assert(claim(c,send,enemy)=='OK' and queue(send,enemy)=='ROLE_ACTIVE')
            c:leave(enemy); local fresh=add(enemy.UserId,'Returned')
            assert(queue(send,fresh)=='ROLE_ACTIVE','Offline body retains role ownership')
        end)
        test('successful ordinary claim cancels waiting while failed claims preserve it',function()
            local c,list,_,send,_,_,enemy=enemyFixture()
            assert(queue(send,enemy)=='OK'); local offer=c:snapshot(enemy,list).bossQueue
            c.director.enemies[-1].engaged=true
            assert(claim(c,send,enemy,-1)=='ENEMY_ENGAGED')
            assert(c:snapshot(enemy,list).bossQueue.offerId==offer.offerId)
            assert(claim(c,send,enemy,-2)=='OK' and c:snapshot(enemy,list).bossQueue.state=='None')
            assert(send(enemy,{kind='ReplyBoss',offerId=offer.offerId,accepted=true})~='OK')
        end)
        test('accepted boss reserve excludes ordinary claim and cannot silently enter the hero roster',function()
            local c,list,_,send,_,_,enemy=enemyFixture(); assert(queue(send,enemy)=='OK')
            accept(c,list,send,enemy)
            assert(claim(c,send,enemy,-1)=='ROLE_RESERVED' and not c.director:controlled(enemy.UserId))
            assert(send(enemy,{kind='CancelBossQueue'})=='OK')
            assert(claim(c,send,enemy,-1)=='OK')
        end)
        test('boss gateway validates sender and exact invitation payloads',function()
            local c,list,add,send=fixture(true); local hero,boss=add(10),add(20)
            assert(send(boss,{kind='QueueBoss',bossId='Other'})=='INVALID_INTENT')
            assert(send(boss,{kind='QueueBoss',bossId='CausewayGuardian',userId=10})=='INVALID_INTENT')
            queue(send,boss); send(hero,{kind='Start'})
            local offer=c:snapshot(boss,list).bossQueue; local fresh=add(20,'Returned')
            assert(send(boss,{kind='ReplyBoss',offerId=offer.offerId,accepted=true})=='STALE_CONNECTION')
            assert(send(fresh,{kind='ReplyBoss',offerId=offer.offerId,accepted='yes'})=='INVALID_INTENT')
            assert(send(fresh,{kind='ConnectBoss',offerId={}})=='INVALID_INTENT')
            assert(c:snapshot(fresh,list).bossQueue.deadline==offer.deadline,'Reconnect never extends invitation')
        end)
        test('boss invitation expires into NPC once and a late reply never replaces it',function()
            local c,list,_,send,tick,_,enemy=enemyFixture(); queue(send,enemy)
            local offer=c:snapshot(enemy,list).bossQueue
            c.director:_boss(); assert(c.director.stage=='BossReady' and not c.world.actors[-99])
            tick(10.1); assert(c.director.stage=='Boss' and not c.director:controlled(enemy.UserId))
            local body=c.world.actors[-99]
            assert(send(enemy,{kind='ReplyBoss',offerId=offer.offerId,accepted=true})~='OK')
            tick(.1); assert(c.world.actors[-99]==body and not c.director:controlled(enemy.UserId))
        end)
        test('dead guardian releases its assignment without restoring its body or queue',function()
            local c,list,_,send,tick,_,enemy=enemyFixture(); queue(send,enemy); accept(c,list,send,enemy)
            c.director:_boss(); c.director:_kill(-99); tick(.1)
            assert(c:snapshot(enemy,list).bossQueue.state=='None')
            assert(c:snapshot(enemy,list).enemyRole.status=='Dead' and #c:snapshot(enemy,list).enemyOffers==0)
        end)
        test('ready owner disconnects before guardian spawn without creating a false online controller',function()
            local c,list,add,send,_,_,enemy=enemyFixture(); queue(send,enemy); accept(c,list,send,enemy)
            c:leave(enemy); c.director:_boss()
            assert(c.director:controlled(enemy.UserId).connected==false,'Reserved offline owner must spawn disconnected')
            local body=c.world.actors[-99]; c.director.enemies[-99].health=2
            local fresh=add(enemy.UserId,'Returned')
            assert(c:snapshot(fresh,list).enemyRole.connected and c:snapshot(fresh,list).enemyRole.hearts==2)
            assert(c.world.actors[-99]==body and send(enemy,{kind='Sync'})=='STALE_CONNECTION')
        end)
    end
    test('one private journal follows actual lifecycle hit result and restart without leaking diagnostic rows',function()
        local c,list,add,send,tick=fixture(false,{RunJournal=Journal,BuildId='source-sha'})
        local a,b=add(10),add(20);assert(send(a,{kind='Start'})=='OK')
        assert(c.journal and c.journal:snapshot().build=='source-sha')
        local started=c.journal:snapshot().events[1]
        assert(started.kind=='RunStarted' and started.data.owners[1]==10 and started.data.owners[2]==20)
        assert(c.current:_hit(2,1,'Punch'))
        local data=c:snapshot(a,list)
        assert(data.feedback and data.feedback.latestSeq>0 and data.journal==nil and data.logs==nil)
        local hit=false
        for _,event in ipairs(data.feedback.events) do
            if event.kind=='Hit' then hit=true;assert(event.data==nil and event.slot==1) end
        end
        assert(hit)
        tick(.6)
        local h=c.current.state.heroes[1]
        assert(send(a,{kind='Attack',attack='Punch',runId=c.current.state.runId,actorId=h.actorId,
            attempt=h.attempt,levelEpoch=1,connectionEpoch=h.connectionEpoch,seq=1})=='OK')
        tick(.2)
        local misses=0
        for _,event in ipairs(c.journal:snapshot().events) do if event.kind=='AttackMiss' then misses+=1 end end
        assert(misses==1)
        c.director.result='Won';tick(.1);tick(.1)
        local results=0
        for _,event in ipairs(c.journal:snapshot().events) do if event.kind=='RunResult' then results+=1 end end
        assert(results==1)
        local previous=c.journal:snapshot().runId
        assert(send(a,{kind='Start'})=='OK')
        assert(c.journal:snapshot().runId~=previous and c.previousJournal:snapshot().runId==previous)
    end)
    test('action denial feedback survives Move and Sync and is private scoped and finite',function()
        local c,list,add,send,tick=fixture();local a,b=add(10),add(20)
        send(a,{kind='Start'})
        local function packet(kind,seq)
            local h=c.current.state.heroes[1]
            local p={kind=kind,seq=seq,runId=c.current.state.runId,actorId=h.actorId,
                attempt=h.attempt,levelEpoch=c.current.state.levelEpoch,connectionEpoch=h.connectionEpoch}
            if kind=='Attack' then p.attack='Punch' elseif kind=='Move' then p.x,p.z=1,0 end
            return p
        end
        c.current.combat[1].reactionEnd=100
        assert(send(a,packet('Attack',1))=='REACTION')
        local denied=c:snapshot(a,list).actionFeedback
        assert(denied and denied.code=='REACTION' and denied.kind=='Attack' and type(denied.id)=='number',
            'A validated action denial needs an owner-only sticky result, not a notice erased by movement')
        assert(denied.runId==c.current.state.runId and denied.actorId==c.current.state.heroes[1].actorId
            and denied.groupId==c.current.state.groupId and denied.expiresAt==c.current.now+1.4)
        assert(c:snapshot(b,list).actionFeedback==nil)
        c.current.combat[1].reactionEnd=nil
        assert(send(a,packet('Move',2))=='OK' and send(a,{kind='Sync'})=='OK')
        assert(c:snapshot(a,list).actionFeedback.id==denied.id)
        assert(send(a,packet('Attack',1))=='STALE_SEQUENCE')
        assert(c:snapshot(a,list).actionFeedback.id==denied.id,'Rejected replay cannot create another feedback id')
        c.current.combat[1].reactionEnd=100
        assert(send(a,packet('Jump',3))=='REACTION')
        local jump=c:snapshot(a,list).actionFeedback;assert(jump.kind=='Jump' and jump.id>denied.id)
        tick(1.39);assert(c:snapshot(a,list).actionFeedback.id==jump.id)
        tick(.01);assert(c:snapshot(a,list).actionFeedback==nil,'Expiry at its server deadline removes the result')
        c.current.combat[1].reactionEnd=nil
        assert(send(a,packet('Jump',4))=='OK' and c:snapshot(a,list).actionFeedback==nil)
        c.current.combat[1].reactionEnd=100
        assert(send(a,packet('Attack',5))=='REACTION')
        c.current:_die(1,'Feedback actor replacement');tick(.1)
        assert(c:snapshot(a,list).actionFeedback==nil,'A new appearance cannot receive the old body denial')
    end)

    test('successful actions clear denial feedback but unknown or stale action contexts cannot create it',function()
        local c,list,add,send=fixture();local a=add(10);send(a,{kind='Start'})
        local h=c.current.state.heroes[1]
        local p={kind='Attack',attack='Punch',seq=1,runId=c.current.state.runId,actorId=h.actorId,
            attempt=h.attempt,levelEpoch=1,connectionEpoch=h.connectionEpoch}
        local stale=table.clone(p);stale.actorId='old'
        assert(send(a,stale)=='STALE_ACTOR' and c:snapshot(a,list).actionFeedback==nil)
        c.current.combat[1].reactionEnd=100;assert(send(a,p)=='REACTION')
        c.current.combat[1].reactionEnd=nil;p.seq=2
        assert(send(a,p)=='OK' and c:snapshot(a,list).actionFeedback==nil)
        p.seq=3;assert(send(a,p)=='COOLDOWN')
        local denied=c:snapshot(a,list).actionFeedback;assert(denied and denied.code=='COOLDOWN')
        local replacement=add(10)
        assert(c:snapshot(a,list)==nil and c:snapshot(replacement,list).actionFeedback==nil,
            'A replacement connection cannot replay its predecessor result')
    end)

    test('only the five supported actual action denials generate results and successful Jump clears one',function()
        local c,list,add,send=fixture();local a=add(10);send(a,{kind='Start'})
        local h=c.current.state.heroes[1];local sequence=0;local denial
        c.current.contextualIntent=function(_,p)
            return (p.kind=='Attack' or p.kind=='Jump') and denial or 'NO_INTERACTION'
        end
        local function action(kind)
            sequence+=1
            local packet={kind=kind,seq=sequence,runId=c.current.state.runId,actorId=h.actorId,
                attempt=h.attempt,levelEpoch=1,connectionEpoch=h.connectionEpoch}
            if kind=='Attack' then packet.attack='Punch' end
            return send(a,packet)
        end
        local previous=0
        for _,code in ipairs({'NOT_RUNNING','REACTION','COOLDOWN','HELD','THROWN'}) do
            denial=code;assert(action('Jump')==code)
            local row=c:snapshot(a,list).actionFeedback
            assert(row.code==code and row.id>previous);previous=row.id
        end
        denial='INVALID_INTENT';assert(action('Attack')=='INVALID_INTENT')
        assert(c:snapshot(a,list).actionFeedback.id==previous,'Unsupported results cannot manufacture another feedback id')
        denial='NO_INTERACTION';assert(action('Jump')=='OK' and c:snapshot(a,list).actionFeedback==nil)
    end)

    test('only accepted new starts build one private canonical-based route and record its actual layout',function()
        local config=table.clone(Config);config.Level=Level
        local builds,guids,clears,rebuilds=0,0,0,0
        local variation={seedFromId=Variation.seedFromId,build=function(base,seed)
            assert(base==Level,'Every new map must derive from the unchanged canonical level')
            builds+=1;return Variation.build(base,seed)
        end}
        local c,list,add,send=fixture(true,{Config=config,LevelVariation=variation,RunJournal=Journal,
            guid=function() guids+=1;return 'varied-run-'..guids end})
        c.world.config=table.clone(config)
        local originalClear=c.world.clearActors
        c.world.clearActors=function(world) clears+=1;return originalClear(world) end
        c.world.rebuildLevel=function(world,route)
            assert(next(world.actors)==nil,'Old actors must be cleared before replacing geometry')
            rebuilds+=1;world.config.Level=route;return true
        end
        local a,b=add(10),add(20)
        assert(send(b,{kind='Start'})=='HOST_ONLY')
        assert(send(a,{kind='Start',seed=111})=='INVALID_INTENT')
        assert(send(a,{kind='SelectRole',role='Spectator'})=='OK')
        assert(send(b,{kind='SelectRole',role='Spectator'})=='OK')
        assert(send(a,{kind='Start'})=='NO_HERO')
        assert(send(a,{kind='SelectRole',role='Hero'})=='OK')
        assert(send(b,{kind='SelectRole',role='Hero'})=='OK')
        assert(builds==0 and guids==0 and clears==0 and rebuilds==0)
        assert(send(a,{kind='Start'})=='OK')
        assert(builds==1 and guids==1 and clears==1 and rebuilds==1,'One accepted start must select exactly one layout')
        local route=c.world.config.Level
        assert(route~=Level and c.deps.Config~=config and config.Level==Level)
        assert(c.deps.Config.Level==route and c.current.config.Level==route and c.director.route==route)
        assert(route.variation.seed==Variation.seedFromId(c.current.state.runId))
        local started=c.journal:snapshot().events[1]
        local published=c:snapshot(a,list).level.variation
        assert(started.kind=='RunStarted' and started.data.variation.seed==route.variation.seed)
        assert(started.data.variation.version==1 and published.version==1 and published.seed==route.variation.seed)
        for i,choice in ipairs(route.variation.sectionChoices) do
            assert(published.sectionChoices[i]==choice and started.data.variation.sectionChoices[i]==choice)
        end
        published.sectionChoices[1]=99
        assert(route.variation.sectionChoices[1]~=99,'A public snapshot cannot mutate the selected map')
        local body=c.world.actors[1]
        assert(send(a,{kind='Start'})=='RUN_ACTIVE')
        assert(builds==1 and clears==1 and rebuilds==1 and guids==1 and c.world.actors[1]==body)
        c.director.result='Won'
        assert(send(a,{kind='Start'})=='OK')
        assert(builds==2 and clears==2 and rebuilds==2 and guids==2)
        assert(c.world.config.Level~=route and c.world.config.Level.variation.seed~=route.variation.seed)
        assert(c.previousJournal:snapshot().events[1].data.variation.seed==route.variation.seed)
        assert(config.Level==Level and c.baseLevel==Level)
    end)

    test('a refused world rebuild cannot start a Session or consume a playable appearance',function()
        local config=table.clone(Config);config.Level=Level
        local creations=0;local session=table.clone(Session)
        session.new=function(...) creations+=1;return Session.new(...) end
        local c,_,add,send=fixture(true,{Config=config,LevelVariation=Variation,Session=session})
        c.world.rebuildLevel=function() return false,'ACTORS_PRESENT' end
        local a=add(10)
        local ok=pcall(send,a,{kind='Start'})
        assert(not ok and creations==0 and c.current==nil and c.world.spawns==0,
            'Geometry refusal must abort before Session.new or any new body')
    end)

    test('trusted development default applies before initial spawn and never accepts a client toggle',function()
        local config=table.clone(Config);config.Development={allowInfiniteLives=true,infiniteLives=true}
        local c,list,add,send=fixture(false,{Config=config});local a=add(10)
        assert(send(a,{kind='Start'})=='OK')
        assert(c.current.state.heroes[1].infiniteLives==true and c.current.state.heroes[1].respawns==3)
        assert(c:snapshot(a,list).heroes[1].infiniteLives==true)
        assert(send(a,{kind='SetInfiniteLives',enabled=false})=='INVALID_INTENT')
        assert(c.current.state.heroes[1].infiniteLives==true)
        c.director.result='Won';assert(send(a,{kind='Start'})=='OK')
        assert(c.current.state.heroes[1].infiniteLives==true)
    end)
    test('an unprivileged config cannot enable infinite lives at run start',function()
        local config=table.clone(Config);config.Development={allowInfiniteLives=false,infiniteLives=true}
        local c,_,add,send=fixture(false,{Config=config});local a=add(10)
        assert(send(a,{kind='Start'})=='OK' and c.current.state.heroes[1].infiniteLives==false)
    end)
    print('GameController: '..passed..' PASS')
end
