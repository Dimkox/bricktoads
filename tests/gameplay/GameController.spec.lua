return function(Controller,Core,Combat,Session,Registry,Config,FakeWorld,Director)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture(realDirector)
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
        local c=Controller.new({Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=Config,Director=realDirector and Director or fakeDirector,
            clock=function() return clock end,guid=function() serial+=1; return 'game-'..serial end},world)
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
    print('GameController: '..passed..' PASS')
end
