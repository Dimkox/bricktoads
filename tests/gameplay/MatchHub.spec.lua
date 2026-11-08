return function(MatchHub,Controller,Core,Combat,Session,Registry,Config,FakeWorld,Director,BossQueue)
    local passed=0
    local function eq(actual,expected)
        assert(actual==expected,'expected '..tostring(expected)..', got '..tostring(actual))
    end
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture(rate)
        local now=1; local serial=0; local players={}
        local config=table.clone(Config); config.Groups={maxGroups=4,spacing=512}
        if rate then config.MaxIntentRate=rate end
        local function factory(index,id)
            local world=FakeWorld.new(); world.names={}; world.positions={}
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
            function world:enemyHealth(slot,health) self.actors[slot].hearts=health end
            function world:enemyMove() end
            function world:face() end
            function world:cue() end
            function world:atExit() return false end
            function world:projectile() end
            function world:removeProjectile() end
            return world
        end
        local hub=MatchHub.new({Controller=Controller,Core=Core,Combat=Combat,Session=Session,
            Registry=Registry,Config=config,Director=Director,BossQueue=BossQueue,
            clock=function() return now end,guid=function() serial+=1; return 'group-run-'..serial end},factory)
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
        eq(create(h,send,p,'one').name,'Команда 2')
        eq(send(p,{kind='CreateGroup',requestId='one'}),'OK'); eq(#h.order,2)
        eq(send(p,{kind='CreateGroup',requestId='one'},'group-1'),'WRONG_GROUP')
        eq(send(p,{kind='CreateGroup',requestId='bad',userId=20}),'INVALID_INTENT')
        eq(send(p,{kind='CreateGroup',requestId=''}),'INVALID_INTENT'); eq(#h.order,2)
        create(h,send,p,'two'); create(h,send,p,'three')
        eq(send(p,{kind='CreateGroup',requestId='four'}),'GROUP_LIMIT'); eq(#h.order,4)
        local view=h:snapshot(p,list)
        eq(view.groupName,'Команда 4'); eq(view.worldName,'ActualWorld_group-4'); eq(view.canCreateGroup,false)
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
        eq(one.groupId,'group-1'); eq(two.groupId,'group-2'); eq(two.groupName,'Команда 2')
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

    print('MatchHub: '..passed..' passed')
end
