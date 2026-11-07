return function(Controller,Core,Combat,Session,Registry,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn(); passed+=1; print('PASS '..name) end
    local function fixture()
        local clock=1; local serial=0
        local world=FakeWorld.new(); world.names={}
        function world:clearActors() self.actors={} end
        local fakeDirector={new=function()
            return {hit=function() return false end,step=function() end,snapshot=function() return {stage='Approach',objective='Play'} end}
        end}
        local c=Controller.new({Core=Core,Combat=Combat,Session=Session,Registry=Registry,Config=Config,Director=fakeDirector,
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
    print('GameController: '..passed..' PASS')
end
