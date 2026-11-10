return function(MatchHub,Controller,Core,Combat,Session,Registry,Config,FakeWorld,Director,BossQueue,Variation,Level)
    local passed=0
    local function eq(actual,expected)
        assert(actual==expected,'expected '..tostring(expected)..', got '..tostring(actual))
    end
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture(rate,overrides)
        local now=1; local serial=0; local players={}
        local config=table.clone(overrides and overrides.Config or Config); config.Groups={maxGroups=4,spacing=512}
        if rate then config.MaxIntentRate=rate end
        local function factory(index,id)
            local world=FakeWorld.new(); world.names={}; world.positions={}
            world.config=table.clone(config);world.rebuilds=0
            function world:rebuildLevel(route)
                assert(next(self.actors)==nil,'A route rebuild cannot happen beneath existing actors')
                self.config.Level=route;self.rebuilds+=1;return true
            end
            world.folder={Name='ActualWorld_'..id}; world.factoryIndex=index
            local originalSpawn=world.spawn
            function world:spawn(slot,actorId,...)
                local ok=originalSpawn(self,slot,actorId,...)
                if ok then self.positions[slot]={x=-65,y=3,z=slot*7} end
                return ok
            end
            function world:clearActors() self.actors={}; self.positions={} end
            function world:spawnEnemy(slot,kind,position)
                local ok=self:spawn(slot,slot,nil,false)
                if ok then self.positions[slot]=table.clone(position) end
                return ok
            end
            function world:enemyIdentity(slot,actorId,name) self.actors[slot].id=actorId; self.actors[slot].ownerName=name end
            function world:position(slot) return self.positions[slot] end
            function world:stage(stage) self.stageName=stage end
            function world:progress(index) self.zoneIndex=index end
            function world:reached() return false end
            function world:enemyHealth(slot,health) self.actors[slot].hearts=health end
            function world:enemyMove() end
            function world:face() end
            function world:cue() end
            function world:atExit() return false end
            function world:projectile() end
            function world:removeProjectile() end
            return world
        end
        local deps={Controller=Controller,Core=Core,Combat=Combat,Session=Session,
            Registry=Registry,Config=config,Director=Director,BossQueue=BossQueue,
            clock=function() return now end,guid=function() serial+=1; return 'group-run-'..serial end}
        for key,value in pairs(overrides or {}) do if key~='Config' then deps[key]=value end end
        local hub=MatchHub.new(deps,factory)
        local function add(id)
            local p={UserId=id,Name='User'..id,DisplayName='Player'..id,Parent='Players'}
            players[#players+1]=p; hub:join(p); return p
        end
        local function send(p,payload,groupId)
            now+=.1
            local packet=table.clone(payload)
            if groupId~=false then packet.groupId=groupId or hub.routes[p.UserId] end
            return hub:handle(p,packet,players)
        end
        local function tick(dt) now+=dt; hub:step(now,dt) end
        return hub,players,add,send,tick
    end
    local function create(h,send,p,request)
        eq(send(p,{kind='CreateGroup',requestId=request}),'OK')
        return h:selected(p)
    end
    local function join(send,p,id) return send(p,{kind='JoinGroup',targetGroupId=id}) end
    local function claim(send,p,g,id)
        return send(p,{kind='ClaimEnemy',runId=g.controller.current.state.runId,
            levelEpoch=g.controller.current.state.levelEpoch,enemyId=id or -1})
    end
    local function eliminate(g,tick,slot)
        for _=1,4 do
            g.controller.current:_die(slot,'Confirmed group regression death')
            if g.controller.current.state.heroes[slot].status~='Eliminated' then tick(.1) end
        end
        eq(g.controller.current.state.heroes[slot].status,'Eliminated')
    end

    -- Reusing one controller/world or stepping only the selected group breaks this test.
    test('independent real controllers keep group B alive when group A loses',function()
        local h,list,add,send,tick=fixture(); local a,b=add(10),add(20)
        eq(h.order[1],'group-1'); local first=h.groups['group-1']
        local second=create(h,send,b,'second')
        eq(second.id,'group-2'); eq(first.world.factoryIndex,1); eq(second.world.factoryIndex,2)
        assert(first.controller~=second.controller and first.world~=second.world)
        eq(send(a,{kind='Start'}),'OK'); eq(send(b,{kind='Start'}),'OK')
        eq(#first.controller.current.order,1); eq(#second.controller.current.order,1)
        eq(first.controller.current.state.groupId,'group-1'); eq(second.controller.current.state.groupId,'group-2')
        local before=second.controller.current.state.runId; local body=second.world.actors[1]
        second.controller.current.combat[1].rawLife=31
        eliminate(first,tick,1); tick(.1)
        eq(first.controller.director.result,'Lost'); eq(second.controller.current.state.status,'Active')
        eq(second.controller.current.state.runId,before); eq(second.controller.current.combat[1].rawLife,31)
        eq(second.world.actors[1],body); eq(h:snapshot(b,list).status,'Active')
        local slot,world=h:controlledSlot(b.UserId); eq(slot,1); eq(world,second.world)
    end)

    test('creation is bounded and duplicate request IDs do not create another group',function()
        local h,list,add,send=fixture(); local p=add(10)
        eq(create(h,send,p,'one').name,'Team 2')
        eq(send(p,{kind='CreateGroup',requestId='one'}),'OK'); eq(#h.order,2)
        eq(send(p,{kind='CreateGroup',requestId='one'},'group-1'),'WRONG_GROUP')
        eq(send(p,{kind='CreateGroup',requestId='bad',userId=20}),'INVALID_INTENT')
        eq(send(p,{kind='CreateGroup',requestId=''}),'INVALID_INTENT'); eq(#h.order,2)
        create(h,send,p,'two'); create(h,send,p,'three')
        eq(send(p,{kind='CreateGroup',requestId='four'}),'GROUP_LIMIT'); eq(#h.order,4)
        local view=h:snapshot(p,list)
        eq(view.groupName,'Team 4'); eq(view.worldName,'ActualWorld_group-4'); eq(view.canCreateGroup,false)
        eq(#view.groups,4); eq(view.groups[1].id,'group-1'); eq(view.groups[4].players,1)
    end)

    test('only initial Sync can omit the strict current group envelope',function()
        local h,_,add,send=fixture(); local p=add(10)
        eq(send(p,{kind='Sync'},false),'OK')
        eq(send(p,{kind='Sync'},false),'MISSING_GROUP')
        eq(send(p,{kind='Start'},false),'MISSING_GROUP')
        create(h,send,p,'new')
        eq(send(p,{kind='Start'},'group-1'),'WRONG_GROUP')
        eq(h.groups['group-1'].controller.current,nil)
        eq(send(p,{kind='JoinGroup',targetGroupId='missing'}),'UNKNOWN_GROUP')
        eq(send(p,{kind='JoinGroup',targetGroupId='group-1',extra=true}),'INVALID_INTENT')
        eq(send(p,{kind='Sync',extra=true}),'INVALID_INTENT')
        eq(send(p,{kind='Start'}),'OK')
    end)

    -- An old group registry tombstone must not prevent a still-current Player returning.
    test('observer A to B to A permits return while replacement rejects the obsolete Player',function()
        local h,list,add,send=fixture(); local hero,other,observer=add(10),add(20),add(30)
        create(h,send,other,'other'); eq(send(observer,{kind='SelectRole',role='Spectator'}),'OK')
        eq(join(send,observer,'group-2'),'OK'); eq(join(send,observer,'group-1'),'OK')
        eq(h:snapshot(observer,list).groupId,'group-1'); eq(send(hero,{kind='Start'}),'OK')
        local fresh=add(30)
        eq(h:snapshot(observer,list),nil); eq(h.groups['group-1'].controller:snapshot(observer,list),nil)
        eq(join(send,observer,'group-2'),'STALE_CONNECTION')
        eq(claim(send,observer,h.groups['group-1']),'STALE_CONNECTION')
        h:join(observer); h:leave(observer)
        eq(h:selected(fresh).id,'group-1'); eq(claim(send,fresh,h.groups['group-1']),'OK')
        eq(h.groups['group-1'].controller.director:controlled(30).status,'Alive')
    end)

    test('living and respawning heroes cannot create or join a second group',function()
        local h,list,add,send=fixture(); local hero,other=add(10),add(20)
        create(h,send,other,'other'); eq(send(hero,{kind='Start'}),'OK')
        eq(join(send,hero,'group-2'),'ROLE_ACTIVE')
        eq(send(hero,{kind='CreateGroup',requestId='forbidden'}),'ROLE_ACTIVE')
        local c=h.groups['group-1'].controller; local actor=c.world.actors[1]
        c.current.combat[1].rawLife=31; h:leave(hero)
        local fresh=add(10); local view=h:snapshot(fresh,list)
        eq(h:selected(fresh).id,'group-1'); eq(c.world.actors[1],actor); eq(c.current.combat[1].rawLife,31)
        eq(view.groups[2].canJoin,false); eq(view.groups[2].reason,'ROLE_ACTIVE')
        eq(view.canCreateGroup,false); eq(send(hero,{kind='Start'}),'STALE_CONNECTION')
        c.current:_die(1,'Awaiting respawn')
        eq(c.current.state.heroes[1].status,'AwaitingRespawn')
        eq(join(send,fresh,'group-2'),'ROLE_ACTIVE')
    end)

    test('eliminated hero can take group B enemy but retains group A hero and spent B history',function()
        local h,_,add,send,tick=fixture(); local a,teammate,b=add(10),add(11),add(20)
        local second=create(h,send,b,'other'); local first=h.groups['group-1']
        eq(send(a,{kind='Start'}),'OK'); eq(send(b,{kind='Start'}),'OK')
        eliminate(first,tick,1)
        eq(join(send,a,'group-2'),'OK'); eq(first.controller.ownerSlots[10],1)
        eq(claim(send,a,second),'OK'); eq(join(send,a,'group-1'),'ROLE_ACTIVE')
        second.controller.director:_kill(-1)
        eq(join(send,a,'group-1'),'OK'); eq(claim(send,a,first,-1),'HERO_LOCKED')
        eq(first.controller.current.state.heroes[2].status,'Alive')
        eq(join(send,a,'group-2'),'OK'); eq(claim(send,a,second,-2),'ENEMY_LIFE_SPENT')
        eq(second.controller.director:controlled(10).status,'Dead')
        assert(teammate.Parent)
    end)

    test('shared guardian FIFO targets each group and accepting moves only the invited observer',function()
        local h,list,add,send=fixture(); local a,b,q1,q2=add(10),add(20),add(30),add(40)
        eq(send(q1,{kind='QueueBoss',bossId='CausewayGuardian'}),'OK')
        eq(send(q2,{kind='QueueBoss',bossId='CausewayGuardian'}),'OK')
        local second=create(h,send,b,'other'); local first=h.groups['group-1']
        eq(first.controller.bossQueue,h.queue); eq(second.controller.bossQueue,h.queue)
        eq(send(a,{kind='Start'}),'OK'); eq(send(b,{kind='Start'}),'OK')
        local one=h:snapshot(q1,list).bossQueue; local two=h:snapshot(q2,list).bossQueue
        eq(one.groupId,'group-1'); eq(two.groupId,'group-2'); eq(two.groupName,'Team 2')
        eq(send(q2,{kind='ReplyBoss',offerId=two.offerId,accepted=true}),'OK')
        eq(h:selected(q2).id,'group-2'); eq(h:selected(q1).id,'group-1')
        eq(h:snapshot(q2,list).bossQueue.state,'Accepted'); eq(join(send,q2,'group-1'),'ROLE_RESERVED')
        eq(send(q2,{kind='ReplyBoss',offerId=two.offerId,accepted=true},'group-1'),'WRONG_GROUP')
        eq(send(q2,{kind='ReplyBoss',offerId=two.offerId,accepted=true}),'OK')
        eq(send(q2,{kind='ConnectBoss',offerId=two.offerId}),'OK')
        second.controller.director:_boss()
        eq(second.controller.director:controlled(40).template,'Boss')
        eq(h:snapshot(q2,list).bossQueue.state,'Active')
        eq(join(send,q2,'group-1'),'ROLE_ACTIVE')
    end)

    test('waiting survives observer switches and a created lobby stays spectator until Hero selection',function()
        local h,list,add,send=fixture(); local p=add(10)
        eq(send(p,{kind='QueueBoss',bossId='CausewayGuardian'}),'OK')
        local second=create(h,send,p,'other')
        eq(h:snapshot(p,list).bossQueue.state,'Queued'); eq(second.controller.preferences[10],'Spectator')
        eq(send(p,{kind='Start'}),'NO_HERO')
        eq(join(send,p,'group-1'),'OK'); eq(h:snapshot(p,list).bossQueue.state,'Queued')
        eq(join(send,p,'group-2'),'OK'); eq(send(p,{kind='SelectRole',role='Hero'}),'OK')
        eq(h:snapshot(p,list).bossQueue.state,'None'); eq(send(p,{kind='Start'}),'OK')
    end)

    test('same-run eliminated hero is excluded only from that groups guardian slot',function()
        local h,list,add,send,tick=fixture(); local a,teammate,b=add(10),add(11),add(20)
        local second=create(h,send,b,'other'); local first=h.groups['group-1']
        send(a,{kind='Start'}); send(b,{kind='Start'}); eliminate(first,tick,1)
        eq(join(send,a,'group-2'),'OK'); eq(send(a,{kind='QueueBoss',bossId='CausewayGuardian'}),'OK')
        local offer=h:snapshot(a,list).bossQueue
        eq(offer.groupId,'group-2'); eq(offer.slotId,second.controller.bossSlot)
        eq(first.controller.ownerSlots[10],1); assert(teammate.Parent)
    end)

    test('failed ordinary claims preserve global waiting and success cancels its invitation',function()
        local h,list,add,send=fixture(); local a,b,viewer=add(10),add(20),add(30)
        send(viewer,{kind='SelectRole',role='Spectator'})
        local second=create(h,send,b,'other'); send(a,{kind='Start'}); send(b,{kind='Start'})
        join(send,viewer,'group-2'); send(viewer,{kind='QueueBoss',bossId='CausewayGuardian'})
        local token=h:snapshot(viewer,list).bossQueue.offerId
        eq(h:snapshot(viewer,list).bossQueue.groupId,'group-1')
        second.controller.director.enemies[-1].engaged=true
        eq(claim(send,viewer,second,-1),'ENEMY_ENGAGED')
        eq(h:snapshot(viewer,list).bossQueue.offerId,token)
        eq(claim(send,viewer,second,-2),'OK'); eq(h:snapshot(viewer,list).bossQueue.state,'None')
        assert(send(viewer,{kind='ReplyBoss',offerId=token,accepted=true})~='OK')
        eq(h:selected(viewer).id,'group-2')
    end)

    test('one global token bucket prevents group hopping from resetting intent limits',function()
        local h,_,add,send,tick=fixture(2); local p=add(10)
        create(h,send,p,'one'); eq(join(send,p,'group-1'),'OK')
        eq(send(p,{kind='CreateGroup',requestId='two'}),'RATE_LIMIT'); eq(#h.order,2)
        tick(1); eq(send(p,{kind='CreateGroup',requestId='two'}),'OK'); eq(#h.order,3)
    end)

    test('snapshot sequence is monotonic across groups and independent for each current Player',function()
        local h,list,add,send=fixture();local a,b=add(10),add(20)
        local first=h:snapshot(a,list);local second=h:snapshot(a,list)
        assert(first.snapshotSeq==1 and second.snapshotSeq==2 and second.serverNow==1)
        assert(h:snapshot(b,list).snapshotSeq==1)
        create(h,send,a,'snapshot-group')
        assert(h:snapshot(a,list).snapshotSeq>second.snapshotSeq)
        local fresh=add(10)
        assert(h:snapshot(a,list)==nil and h:snapshot(fresh,list).snapshotSeq==1)
    end)
    test('handle step and presentation faults quarantine one group and host Start creates a fresh run',function()
        for _,phase in ipairs({'handle','step','presentation'}) do
            local h,list,add,send,tick=fixture();local a,b=add(10),add(20)
            local first=h.groups['group-1'];local second=create(h,send,b,'healthy')
            send(a,{kind='Start'});send(b,{kind='Start'})
            local oldRun=first.controller.current.state.runId
            local healthyRun,healthyBody=second.controller.current.state.runId,second.world.actors[1]
            second.controller.current.combat[1].rawLife=31
            local warnings={};h.deps.warn=function(message) warnings[#warnings+1]=message end
            local previous
            if phase=='handle' then
                previous=first.controller.handle;first.controller.handle=function() error('private handle sentinel') end
                local ok,code=pcall(send,a,{kind='Sync'})
                assert(ok and code=='PARTY_FAULTED','A group handler exception must not escape to the global runtime trap')
                first.controller.handle=previous
            elseif phase=='step' then
                previous=first.controller.step;first.controller.step=function() error('private step sentinel') end
                assert(pcall(tick,.1),'A group step exception must not stop the healthy group')
                first.controller.step=previous
            else
                first.world.updatePresentation=function() error('private presentation sentinel') end
                assert(pcall(tick,.1),'A visual exception must not stop other parties')
                first.world.updatePresentation=nil
            end
            local broken=h:snapshot(a,list)
            eq(broken.status,'Faulted');eq(broken.fault,true);eq(broken.canSelect,false);eq(broken.canStart,true)
            assert(broken.trace==nil and broken.error==nil and #warnings==1
                and string.find(warnings[1],'private '..phase..' sentinel',1,true),'Trace belongs only to the private server warning')
            eq(first.world.actors[1].held,true)
            tick(.1);eq(h:snapshot(b,list).status,'Active');eq(second.controller.current.state.runId,healthyRun)
            eq(second.controller.current.combat[1].rawLife,31);eq(second.world.actors[1],healthyBody)
            eq(send(a,{kind='Move'}),'PARTY_FAULTED')
            eq(send(a,{kind='Start'}),'OK')
            assert(first.controller.current.state.runId~=oldRun and h:snapshot(a,list).fault~=true,
                'Recovery must be a new manual game, never resume or heal the quarantined run')
        end
    end)

    test('shared queue failure remains a shared fatal error rather than blaming one party',function()
        local h,_,add=fixture();add(10)
        h.queue.step=function() error('shared queue sentinel') end
        assert(not pcall(function() h:step(2,.1) end))
        assert(not h.groups['group-1'].controller.faulted)
    end)

    test('a first Start failure still has a valid fault snapshot and can recover without an old session',function()
        local h,list,add,send=fixture();local a=add(10);local group=h.groups['group-1']
        local clear=group.world.clearActors
        group.world.clearActors=function() error('private first-start sentinel') end
        eq(send(a,{kind='Start'}),'PARTY_FAULTED')
        local view=h:snapshot(a,list)
        assert(view.status=='Faulted' and type(view.runId)=='string' and #view.runId>0 and view.levelEpoch>=1,
            'Fault UI must get a valid scope even when Start failed before constructing the first Session')
        group.world.clearActors=clear
        eq(send(a,{kind='Start'}),'OK');eq(h:snapshot(a,list).status,'Active')
    end)

    test('action result identifiers stay monotonic through a same-connection group change',function()
        local h,list,add,send,tick=fixture();local a=add(10);send(a,{kind='Start'})
        local first=h.groups['group-1']
        local function deny(group)
            local s=group.controller.current;local hero=s.state.heroes[1];s.combat[1].reactionEnd=100
            eq(send(a,{kind='Attack',attack='Punch',seq=1,runId=s.state.runId,actorId=hero.actorId,
                attempt=hero.attempt,connectionEpoch=hero.connectionEpoch,levelEpoch=s.state.levelEpoch}),'REACTION')
            return h:snapshot(a,list).actionFeedback
        end
        local old=deny(first);eliminate(first,tick,1);tick(.1)
        local second=create(h,send,a,'feedback-context');send(a,{kind='Start'})
        assert(h:snapshot(a,list).actionFeedback==nil)
        local fresh=deny(second)
        assert(fresh.id>old.id and fresh.groupId~=old.groupId and fresh.runId~=old.runId)
    end)

    test('optional capacity transfer preserves old parties and is private to its requester',function()
        local h,list,add,send=fixture();local p,other=add(10),add(20)
        create(h,send,p,'two');create(h,send,p,'three');create(h,send,p,'four')
        local requests,state={},{}
        h.deps.Transfer={request=function(_,player,id)
            requests[#requests+1]={player=player,id=id};state[player]={state='Pending'};return 'TRANSFER_PENDING'
        end,snapshot=function(_,player) return state[player] end,remove=function(_,player) state[player]=nil end}
        assert(h:snapshot(p,list).canCreateGroup,'Available transfer must keep the existing create action usable at local capacity')
        eq(send(p,{kind='CreateGroup',requestId='capacity'}),'TRANSFER_PENDING')
        eq(#h.order,4);eq(requests[1].player,p);eq(requests[1].id,'capacity')
        eq(h:snapshot(p,list).serverTransfer.state,'Pending');eq(h:snapshot(other,list).serverTransfer,nil)
        send(p,{kind='Start'})
        eq(send(p,{kind='CreateGroup',requestId='role-blocked'}),'ROLE_ACTIVE');eq(#requests,1)
        h:leave(p);eq(state[p],nil)
    end)

    test('a foreign group role-read failure cannot poison healthy snapshots routing or boss eligibility',function()
        local h,list,add,send=fixture();local a,b,observer=add(10),add(20),add(30)
        send(observer,{kind='SelectRole',role='Spectator'})
        local first=h.groups['group-1'];local second=create(h,send,b,'healthy-read')
        send(a,{kind='Start'});send(b,{kind='Start'});eq(join(send,observer,'group-2'),'OK')
        local healthyBody,healthyRun=second.world.actors[1],second.controller.current.state.runId
        second.controller.current.combat[1].rawLife=31
        local warnings={};h.deps.warn=function(message) warnings[#warnings+1]=message end
        first.controller.director.controlled=function() error('private foreign role-read sentinel') end
        local ok,view=pcall(function() return h:snapshot(b,list) end)
        assert(ok and view.status=='Active','Healthy snapshot must contain a different group role-read exception')
        assert(first.controller.faulted and h:snapshot(a,list).status=='Faulted' and #warnings==1)
        eq(send(b,{kind='CreateGroup',requestId='still-active'}),'ROLE_ACTIVE')
        eq(join(send,b,'group-1'),'ROLE_ACTIVE')
        local context={groupId='group-2',runId=healthyRun,levelEpoch=second.controller.current.state.levelEpoch}
        assert(h:_queueEligible(observer.UserId,context) and not h:_queueEligible(b.UserId,context))
        local third=create(h,send,observer,'observer-can-create')
        eq(third.id,'group-3');eq(join(send,observer,'group-2'),'OK')
        eq(send(observer,{kind='QueueBoss',bossId='CausewayGuardian'}),'OK')
        eq(second.controller.current.state.runId,healthyRun);eq(second.world.actors[1],healthyBody)
        eq(second.controller.current.combat[1].rawLife,31)
    end)

    test('Start eligibility and replication focus reads quarantine their owning group only',function()
        for _,phase in ipairs({'start','focus'}) do
            local h,list,add,send=fixture();local a,b=add(10),add(20)
            local first=h.groups['group-1'];local second=create(h,send,b,'read-neighbour')
            send(a,{kind='Start'});send(b,{kind='Start'})
            if phase=='start' then
                first.controller._open=function() error('private open eligibility sentinel') end
                local ok,code=pcall(send,a,{kind='Start'})
                assert(ok and code=='PARTY_FAULTED','Start eligibility must run inside its group boundary')
            else
                first.controller.controlledSlot=function() error('private focus-read sentinel') end
                local ok,slot=pcall(function() return h:controlledSlot(a.UserId) end)
                assert(ok and slot==nil,'Replication focus lookup must not escape its owning group')
            end
            assert(first.controller.faulted)
            eq(h:snapshot(b,list).status,'Active');assert(not second.controller.faulted)
        end
    end)

    test('boss eligibility quarantine waits for the queue operation and never invites a closed target',function()
        local h,list,add,send=fixture();local a,o=add(10),add(30)
        send(o,{kind='SelectRole',role='Spectator'});send(a,{kind='Start'})
        local first=h.groups['group-1'];local d=first.controller.director
        local original,reads=d.controlled,0
        d.controlled=function(self,userId)
            reads+=1;if reads==2 then error('target role-read fails inside queue fill') end
            return original(self,userId)
        end
        local eligible,close=h.queue.eligible,h.queue.close
        local checking,closedDuringEligibility=false,false
        h.queue.eligible=function(...)
            checking=true;local result=eligible(...);checking=false;return result
        end
        h.queue.close=function(self,...)
            if checking then closedDuringEligibility=true end
            return close(self,...)
        end
        eq(h.queue:select(o.UserId,'CausewayGuardian',2),'OK')
        assert(not closedDuringEligibility,'Eligibility must never reenter the shared queue through quarantine')
        assert(first.controller.faulted)
        local slot=h.queue.slots[first.controller.bossSlot]
        eq(slot.state,'Closed');eq(slot.userId,nil)
        eq(h.queue:view(o.UserId,2).state,'Queued')
        eq(h.queue:view(o.UserId,100).state,'Queued')
        eq(h:snapshot(a,list).status,'Faulted')
    end)

    test('a target eligibility fault invalidates acceptance while a healthy boss slot stays usable',function()
        local h,list,add,send=fixture();local a,b,o=add(10),add(20),add(30)
        send(o,{kind='SelectRole',role='Spectator'})
        local first=h.groups['group-1'];local second=create(h,send,b,'queue-neighbour')
        send(a,{kind='Start'});send(b,{kind='Start'})
        eq(h.queue:select(o.UserId,'CausewayGuardian',2),'OK')
        local offer=h.queue:view(o.UserId,2);eq(offer.slotId,first.controller.bossSlot)
        first.controller.director.controlled=function() error('target acceptance role-read fails') end
        eq(h.queue:reply(o.UserId,offer.offerId,true,2),'STALE_OFFER')
        eq(h.queue.slots[first.controller.bossSlot].state,'Closed')
        eq(h.queue.slots[first.controller.bossSlot].userId,nil)
        eq(h:snapshot(b,list).status,'Active');assert(not second.controller.faulted)
        local nextOffer=h.queue:view(o.UserId,2)
        eq(nextOffer.state,'Invited');eq(nextOffer.slotId,second.controller.bossSlot)
        eq(h.queue:reply(o.UserId,nextOffer.offerId,true,2),'OK')
        eq(h.queue:connect(o.UserId,nextOffer.offerId,2),'OK')
        eq(h.queue:start(second.controller.bossSlot,2).state,'Human')
    end)

    test('new run layout is private to its group while invalid starts and neighbouring bodies stay unchanged',function()
        local config=table.clone(Config);config.Level=Level
        local builds=0
        local variation={seedFromId=Variation.seedFromId,build=function(base,seed)
            assert(base==Level);builds+=1;return Variation.build(base,seed)
        end}
        local h,list,add,send=fixture(nil,{Config=config,LevelVariation=variation})
        local a,b=add(10),add(20);local first=h.groups['group-1'];local second=create(h,send,b,'varied-neighbour')
        eq(send(a,{kind='Start'}),'OK')
        local firstRoute=first.world.config.Level;local firstBody=first.world.actors[1]
        eq(builds,1);eq(first.world.rebuilds,1);eq(second.world.rebuilds,0)
        assert(firstRoute~=Level and second.world.config.Level==Level and h.deps.Config.Level==Level)
        eq(send(b,{kind='Start'}),'OK')
        local secondRoute,secondBody=second.world.config.Level,second.world.actors[1]
        assert(firstRoute~=secondRoute and firstRoute.variation.seed~=secondRoute.variation.seed)
        assert(first.controller.deps.Config~=second.controller.deps.Config)
        assert(first.controller.current.config.Level==firstRoute and second.controller.current.config.Level==secondRoute)
        second.controller.current.combat[1].rawLife=31
        eq(send(a,{kind='Start'}),'RUN_ACTIVE')
        eq(builds,2);eq(first.world.actors[1],firstBody)
        first.controller.director.result='Won'
        eq(send(a,{kind='Start'}),'OK');eq(builds,3)
        assert(first.world.config.Level~=firstRoute and first.world.actors[1]~=firstBody)
        eq(second.world.config.Level,secondRoute);eq(second.world.actors[1],secondBody)
        eq(second.world.rebuilds,1);eq(second.controller.current.combat[1].rawLife,31)
        eq(h:snapshot(b,list).level.variation.seed,secondRoute.variation.seed)
        assert(h.deps.Config.Level==Level and config.Level==Level)
    end)

    test('trusted live toggle covers active and future groups without sharing mutable config',function()
        local config=table.clone(Config);config.Development={allowInfiniteLives=true,infiniteLives=false}
        local h,_,add,send=fixture(nil,{Config=config});local a=add(10)
        local first=h:selected(a);eq(send(a,{kind='Start'}),'OK')
        local body=first.controller.current.state.heroes[1].actorId
        eq(h:setInfiniteLives(true),'OK')
        eq(first.controller.current.state.heroes[1].infiniteLives,true)
        eq(first.controller.current.state.heroes[1].actorId,body)
        local b=add(20);local second=create(h,send,b,'god-group');eq(send(b,{kind='Start'}),'OK')
        eq(second.controller.current.state.heroes[1].infiniteLives,true)
        assert(first.controller.deps.Config.Development~=second.controller.deps.Config.Development)
        eq(h:setInfiniteLives(false),'OK')
        eq(first.controller.current.state.heroes[1].infiniteLives,false)
        eq(second.controller.current.state.heroes[1].infiniteLives,false)
        first.controller.director.result='Won';eq(send(a,{kind='Start'}),'OK')
        eq(first.controller.current.state.heroes[1].infiniteLives,false)
    end)
    test('public group traffic and ungated server calls cannot grant infinite lives',function()
        local h,_,add,send=fixture();local a=add(10)
        eq(h:setInfiniteLives(true),'DEVELOPMENT_ONLY')
        eq(send(a,{kind='Start'}),'OK')
        eq(send(a,{kind='SetInfiniteLives',enabled=true}),'INVALID_INTENT')
        eq(h:selected(a).controller.current.state.heroes[1].infiniteLives,false)
    end)
    print('MatchHub: '..passed..' passed')
end
