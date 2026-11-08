return function(Clubs,Session,Core,Combat,Config,FakeWorld)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function copy(p) return {x=p.x,y=p.y,z=p.z} end
    local function fixture(second)
        local w=FakeWorld.new();w.positions={};w.items={};w.equipment={};w.grounded={};w.swings=0
        local spawn=w.spawn
        function w:spawn(uid,...)
            local ok=spawn(self,uid,...)
            if ok then self.positions[uid]={x=0,y=3,z=0};self.grounded[uid]=true end
            return ok
        end
        function w:position(id) return self.positions[id] end
        function w:groundPosition(p) if self.unsupported then return nil end;return {x=p.x,y=1,z=p.z} end
        function w:clubItem(id,p) self.items[id]=p and copy(p) or nil end
        function w:canPickupClub(slot,p,range,height)
            local a=self.positions[slot]
            return a and self.grounded[slot] and not self.blocked and math.abs(a.y-p.y)<=height
                and (a.x-p.x)^2+(a.y-p.y)^2+(a.z-p.z)^2<=range^2
        end
        function w:aim(slot,x,z)
            self.lastAim={slot=slot,x=x,z=z,equipped=next(self.equipment)~=nil}
        end
        function w:equipClub(id,slot)
            if self.equipFails or not self.items[id] then return false end
            self.equipment[id]=slot;return true
        end
        function w:unequipClub(id) self.equipment[id]=nil end
        function w:clubSwing(id,slot) self.swings+=1;self.lastSwing={id=id,slot=slot} end
        local roster={{userId=1,template='Mr. Green'}}
        if second then roster[2]={userId=2,template='Mr. Green'} end
        local s=Session.new(Core,Combat,Config,roster,'club-run',w);s:step(0)
        local d={session=s,world=w,config=Config,now=0,locks=0,hits=0,
            enemies={[-1]={kind='Walker',actorId='walker-body',dead=true,health=0},
                [-2]={kind='Pig',actorId='pig-body',health=3}}}
        function d:closeTargetForAttack(targets)
            self.locks+=1;self.lockTargets=targets
            for _,id in ipairs(targets) do if self.enemies[id] and not self.enemies[id].dead then self.enemies[id].engaged=true;break end end
        end
        local hit=s._hit
        s._hit=function(session,attacker,target,action)
            if target<0 then
                local e=d.enemies[target]
                if not e or e.dead then return false end
                d.hits+=1;d.lastAction=action;e.health=math.max(0,e.health-Config.WalkerClub.npcDamage)
                e.dead=e.health==0;return true
            end
            return hit(session,attacker,target,action)
        end
        local c=Clubs.new(d);d.clubs=c
        s.contextualAttack=function(slot,now,action) d.now=now;return c:interact(slot,now,action) end
        local seq={}
        local function packet(slot,extra)
            local h=s.state.heroes[slot];seq[slot]=(seq[slot] or 0)+1
            local p={kind='Attack',attack='Punch',runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
                levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=seq[slot]}
            for k,v in pairs(extra or {}) do p[k]=v end;return p
        end
        local function step(now) s:step(now);d.now=now;c:step(now) end
        local function give(slot)
            slot=slot or 1;c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat')
            assert(s:intent(slot,packet(slot),.1)=='OK' and c:hasClub(slot))
        end
        return d,s,w,c,packet,step,give
    end
    local function countRows(rows) local n=0;for _ in pairs(rows) do n+=1 end;return n end
    test('one combat-defeated Walker emits one unique supported club and repeated death cannot duplicate it',function()
        local d,s,w,c=fixture()
        c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat');assert(countRows(w.items)==1)
        c:walkerDefeated(-1,{x=2,y=3,z=0},'Combat');assert(countRows(w.items)==1)
        c:walkerDefeated(-2,{x=0,y=3,z=0},'Combat');assert(countRows(w.items)==1)
        assert(s.combat[1].rawLife==47 and s.state.heroes[1].respawns==3)
    end)
    test('fall or unsupported combat deaths do not farm a replacement safe pickup',function()
        local d,s,w,c=fixture()
        c:walkerDefeated(-1,{x=0,y=-50,z=0},'Fall');assert(next(w.items)==nil)
        w.unsupported=true;c:walkerDefeated(-1,{x=0,y=-50,z=0},'Combat');assert(next(w.items)==nil)
        w.unsupported=false;c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat');assert(next(w.items)==nil)
    end)
    test('pickup equips one item exclusively without beginning an attack or changing resources',function()
        local d,s,w,c,p,_,give=fixture(true);local actor=s.state.heroes[1].actorId
        give();assert(c:hasClub(1) and not c:hasClub(2) and next(w.items)==nil and countRows(w.equipment)==1)
        assert(c:interaction(1).equipped and c:interaction(1).label=="CLUB HIT" and not c:interaction(1).carrying)
        assert(s.combat[1].attack==nil and s.combat[1].rawLife==47 and s.state.heroes[1].actorId==actor
            and s.state.heroes[1].respawns==3 and d.locks==0)
        assert(c:interact(2,.2,'Punch')=='NO_INTERACTION')
    end)
    test('pickup respects actual grounded reach height and obstruction without a facing prerequisite',function()
        for _,prepare in ipairs({function(w)w.grounded[1]=false end,function(w)w.positions[1].x=20 end,
            function(w)w.positions[1].y=10 end,function(w)w.blocked=true end}) do
            local d,s,w,c=fixture();c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat');prepare(w)
            assert(not c:interaction(1).available and c:interact(1,.1,'Punch')=='NO_INTERACTION')
        end
        local d,s,w,c,p=fixture();c:walkerDefeated(-1,{x=-1,y=3,z=0},'Combat')
        assert(c:interaction(1).label=="PICK UP CLUB" and s:intent(1,p(1),.1)=='OK')
    end)
    test('successful ground pickup turns the hero toward the item only after equipment succeeds',function()
        local d,s,w,c,p=fixture();c:walkerDefeated(-1,{x=-1,y=3,z=2},'Combat')
        assert(s:intent(1,p(1),.1)=='OK')
        assert(w.lastAim and w.lastAim.slot==1 and w.lastAim.x==-1 and w.lastAim.z==2 and w.lastAim.equipped,
            'Source pickup auto-facing must follow successful equipment without an initial facing prerequisite')
        local d2,s2,w2,c2,p2=fixture();c2:walkerDefeated(-1,{x=-1,y=3,z=2},'Combat');w2.equipFails=true
        assert(s2:intent(1,p2(1),.1)~='OK' and not w2.lastAim,'A rejected pickup must not rotate the hero')
    end)
    test('pickup preserves an actual respawn shield while a swing removes it before its effect',function()
        local d,s,w,c,p,step=fixture();s:_die(1,'fixture');step(.05)
        c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat')
        assert(s.state.heroes[1].shield and s:intent(1,p(1),.1)=='OK' and s.state.heroes[1].shield)
        assert(s:intent(1,p(1),.8)=='OK' and not s.state.heroes[1].shield)
        assert(s.state.heroes[1].respawns==2 and s.combat[1].rawLife==47)
    end)
    test('club swing uses its own hitbox and locks an accepted target before a delayed miss',function()
        local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2}
        local targets=w.targets
        function w:targets(slot,cfg) self.lastTargetProfile=cfg;return targets(self,slot,cfg) end
        assert(s:intent(1,p(1),.8)=='OK' and d.enemies[-2].engaged and d.locks==1)
        assert(w.lastTargetProfile==Config.Attacks.Club and w.swings==1 and s.combat[1].attack==nil)
        w.targetsFor[1]={};step(.97)
        assert(d.enemies[-2].health==3 and d.hits==0 and c:hasClub(1))
    end)
    test('accepted club swing damages an ordinary enemy by calibrated two HP exactly once',function()
        local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2}
        assert(s:intent(1,p(1),.8)=='OK');assert(d.enemies[-2].health==3)
        step(.97);step(1.0)
        assert(d.enemies[-2].health==1 and d.hits==1 and d.lastAction=='Club' and c:hasClub(1))
    end)
    test('real friendly fire uses raw16 hero profile20 and one successful hit stops target traversal',function()
        local d,s,w,c,p,step,give=fixture(true);give();w.targetsFor[1]={2,-2}
        assert(s:intent(1,p(1),.8)=='OK');step(.97)
        assert(s.combat[2].rawLife==31 and w.lastProfile==20 and d.enemies[-2].health==3)
        assert(s.state.heroes[2].respawns==3 and s.combat[1].rawLife==47)
    end)
    test('club below raw16 still uses profile20 rather than running finisher21',function()
        local d,s,w,c,p,step,give=fixture(true);give();s.combat[2].rawLife=15
        assert(s:_event('SetHealth',2,{health=Combat.hearts(15)})=='OK');w.targetsFor[1]={2}
        assert(s:intent(1,p(1),.8)=='OK');step(.97)
        assert(w.lastProfile==20 and s.combat[2].deathAt and s.combat[2].rawLife==0)
    end)
    test('club has no invented use limit and its trusted cooldown outlasts the primary default',function()
        local d,s,w,c,p,step,give=fixture();give()
        assert(s:intent(1,p(1),.8)=='OK' and s.combat[1].nextAttack>=1.5)
        step(.97);assert(s:intent(1,p(1),1.4)=='COOLDOWN')
        local now=1.6
        for _=1,6 do assert(s:intent(1,p(1),now)=='OK');step(now+.17);now+=.8 end
        assert(c:hasClub(1) and w.swings==7 and next(w.items)==nil)
    end)
    test('a light hit cancels the pending swing but retains the equipped item after recovery',function()
        local d,s,w,c,p,step,give=fixture(true);give();w.targetsFor[1]={-2}
        assert(s:intent(1,p(1),.8)=='OK' and s:_hit(2,1,'Punch'));step(.97);step(2)
        assert(c:hasClub(1) and d.hits==0 and d.enemies[-2].health==3 and next(w.items)==nil)
    end)
    test('historical heavy reaction drops the same item after recovery instead of retaining equipment',function()
        local d,s,w,c,p,step,give=fixture(true);give();w.positions[1]={x=8,y=3,z=0}
        assert(s:_hit(2,1,'Dash'));step(2)
        assert(not c:hasClub(1) and countRows(w.items)==1 and next(w.equipment)==nil)
        local _,position=next(w.items);assert(position.x==8)
    end)
    test('a dropped supported club can be picked up again without replenishing a fabricated durability',function()
        local d,s,w,c,p,_,give=fixture();give();c:drop(1,'Fixture')
        assert(not c:hasClub(1) and countRows(w.items)==1)
        assert(s:intent(1,p(1),.8)=='OK' and c:hasClub(1) and next(w.items)==nil)
    end)
    test('failed equipment creation leaves the ground item available without granting ownership',function()
        local d,s,w,c,p=fixture();c:walkerDefeated(-1,{x=0,y=3,z=0},'Combat');w.equipFails=true
        assert(s:intent(1,p(1),.1)~='OK' and not c:hasClub(1) and countRows(w.items)==1)
    end)
    test('a changed appearance drops at the old body position and does not equip its replacement',function()
        local d,s,w,c,p,step,give=fixture();give();w.positions[1]={x=12,y=3,z=0};step(.2)
        s:_die(1,'fixture');step(.3)
        assert(s.state.heroes[1].attempt==2 and not c:hasClub(1) and next(w.equipment)==nil)
        local _,position=next(w.items);assert(position and position.x==12,'Drop must not use the new spawn at x0')
    end)
    test('unsupported weapon release loses the item instead of relocating it onto safe ground',function()
        local d,s,w,c,_,_,give=fixture();give();w.unsupported=true;c:drop(1,'Fall')
        assert(not c:hasClub(1) and next(w.items)==nil and next(w.equipment)==nil)
    end)
    test('accepted swing can finish on its same offline body and equipment remains attached',function()
        local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2}
        assert(s:intent(1,p(1),.8)=='OK' and s:connection(1,false,.81)=='OK');step(.97)
        assert(d.hits==1 and c:hasClub(1) and not s.state.heroes[1].connected)
    end)
    test('old target context or an expired effect window cannot replay a swing',function()
        for _,change in ipairs({function(d,s,w,c)s.state.levelEpoch+=1 end,function(d,s,w,c)s:_die(1,'fixture') end,
            function(d,s,w,c)c:drop(1,'Fixture') end}) do
            local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2}
            assert(s:intent(1,p(1),.8)=='OK');change(d,s,w,c);step(.97)
            assert(d.hits==0 and d.enemies[-2].health==3)
        end
        local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2}
        assert(s:intent(1,p(1),.8)=='OK');step(2);assert(d.hits==0 and c:hasClub(1))
    end)
    test('boss introduction drops current equipment once while a later ball-hand release can drop a repickup',function()
        local d,s,w,c,p,_,give=fixture();give();c:bossIntro()
        assert(not c:hasClub(1) and countRows(w.items)==1)
        assert(s:intent(1,p(1),.8)=='OK');c:bossIntro();assert(c:hasClub(1),'Intro is one transition, not a permanent lock')
        c:drop(1,'GuardianBall');assert(not c:hasClub(1) and countRows(w.items)==1)
    end)
    test('existing R-heavy action is not converted into a club swing',function()
        local d,s,w,c,p,_,give=fixture();give()
        assert(s:intent(1,p(1,{attack='Dash'}),.8)=='OK' and s.combat[1].attack.action=='Dash')
        assert(w.swings==0 and c:hasClub(1))
    end)
    test('schema and sequence validation reject client Club targets damage and repeated swings',function()
        for _,over in ipairs({{attack='Club'},{itemId='club'},{target=-2},{damage=16},{actorId='old'}}) do
            local d,s,w,c,p,_,give=fixture();give();assert(s:intent(1,p(1,over),.8)~='OK' and w.swings==0)
        end
        local d,s,w,c,p,step,give=fixture();give();local a=p(1)
        assert(s:intent(1,a,.8)=='OK' and s:intent(1,a,.8)=='STALE_SEQUENCE');step(.97);assert(w.swings==1)
    end)
    test('clubs and equipment stay independent between directors and closed runs clear all visuals and effects',function()
        local d,s,w,c,p,step,give=fixture();give();w.targetsFor[1]={-2};assert(s:intent(1,p(1),.8)=='OK')
        local d2,s2,w2,c2=fixture();c2:walkerDefeated(-1,{x=0,y=3,z=0},'Combat')
        c:close();c:close();step(.97)
        assert(not c:hasClub(1) and not c:interaction(1).available and next(w.items)==nil and next(w.equipment)==nil and d.hits==0)
        assert(countRows(w2.items)==1 and not c2:hasClub(1) and s2.combat[1].rawLife==47)
    end)
    print('WalkerClubs: '..passed..' passed')
end
