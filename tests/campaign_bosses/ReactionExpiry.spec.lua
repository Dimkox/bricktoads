-- Real Session effects run before the boss heartbeat in GameController. Recovery
-- deadlines must therefore normalize before hit/selection/command decisions.
return function(Boss,Session,Core,Combat,Config,FakeWorld,SourceCombat)
    local passed,failures=0,{}
    local cases={
        {kind='BigBlag',jab=253,combo=251,heavy=239,afterJab=237},
        {kind='RoboManus',jab=13,combo=11,heavy=7,afterJab=5},
        {kind='GeneralSlaughter',jab=253,combo=251,heavy=239,afterJab=237},
        {kind='Buzzball',jab=205,combo=203,heavy=191,afterJab=189},
        {kind='DarkQueen',jab=13,combo=11,heavy=7,afterJab=5},
    }
    local function eq(actual,want,label)
        assert(actual==want,(label or '')..' expected '..tostring(want)..', got '..tostring(actual))
    end
    local function test(name,body)
        local ok,message=pcall(body)
        if ok then passed+=1;print('PASS '..name)
        else failures[#failures+1]=name..': '..tostring(message);print('FAIL '..failures[#failures]) end
    end
    local function fixture(kind,human)
        local world=FakeWorld.new();world.positions={[1]={x=4,y=3,z=0}};world.targetsFor[1]={-99}
        function world:position(id) return self.positions[id] end
        function world:spawnEnemy(id,_,position)
            self.positions[id]=table.clone(position);self.actors[id]={alive=true};return true
        end
        function world:enemyHealth() end
        function world:cue() end
        function world:placeActor(id,position) self.positions[id]=table.clone(position) end
        local session=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'}},'boss-reaction-expiry',world)
        eq(session:step(0),'OK')
        local boss=Boss.new(session,world,Config,{boss={type=kind,position={x=0,y=3,z=0},chaseComplete=true},
            bossGate=human and {ownerUserId=99,connected=true,connectionEpoch=1} or nil})
        local director={enemies=boss.enemies,now=0}
        function director:selectBossAction(_,input) return boss:selectAction(input) end
        SourceCombat.bind(session,director,Config)
        local originalHit=session._hit
        function session:_hit(attacker,target,action,tuning)
            if target==-99 then return boss:hit(attacker,target,action,tuning) end
            return originalHit(self,attacker,target,action,tuning)
        end
        local function punch(now)
            local hero=session.state.heroes[1]
            return session:intent(1,{kind='Attack',attack='Punch',runId=session.state.runId,actorId=hero.actorId,
                attempt=hero.attempt,levelEpoch=session.state.levelEpoch,connectionEpoch=hero.connectionEpoch,seq=1},now)
        end
        return boss,session,world,punch
    end
    for _,case in ipairs(cases) do
        for _,human in ipairs({true,false}) do
            local label=case.kind..' '..(human and 'human' or 'NPC')
            test(label..' expired light recovery precedes Session-first hit at the exact deadline',function()
                local boss,session,_,punch=fixture(case.kind,human)
                local actor=boss.enemies[-99].actorId
                eq(boss:hit(1,-99,'HeroJab'),true);eq(boss.enemies[-99].rawLife,case.jab)
                eq(punch(.95),'OK');eq(session.combat[1].attack.at,1.05)
                session.now=1.04;eq(boss:step(1.04,1.04),'OK')
                eq(session:step(1.05),'OK');eq(boss:step(1.05,.01),'OK')
                eq(boss.enemies[-99].rawLife,case.jab,'OR7 recovery must precede the new two-byte hit')
                eq(boss.enemies[-99].actorId,actor);eq(session.state.heroes[1].respawns,3)
            end)
            test(label..' expired heavy recovery precedes accepted hero action selection',function()
                local boss,session,_,punch=fixture(case.kind,human)
                eq(boss:hit(1,-99,'HeroUppercut'),true)
                eq(punch(.41),'OK')
                eq(session.combat[1].attack.action,'HeroJab','expired heavy state cannot select kick or boot')
                eq(boss.enemies[-99].rawLife,case.heavy,'recovered Life must inform selection')
                eq(boss:step(.41,.41),'OK');eq(session:step(.52),'OK');eq(boss:step(.52,.11),'OK')
                eq(boss.enemies[-99].rawLife,case.afterJab,'accepted jab keeps its two-byte damage')
            end)
            test(label..' direct hit normalizes heavy recovery at the exact deadline',function()
                local boss,session=fixture(case.kind,human)
                eq(boss:hit(1,-99,'HeroUppercut'),true)
                session.now=.4;eq(boss:hit(1,-99,'HeroJab'),true)
                eq(boss.enemies[-99].rawLife,case.afterJab)
            end)
            test(label..' live light combos and heavy reaction rejection keep their windows',function()
                local boss,session=fixture(case.kind,human)
                eq(boss:hit(1,-99,'HeroJab'),true)
                session.now=.55;eq(boss:hit(1,-99,'HeroJab'),true)
                eq(boss.enemies[-99].rawLife,case.combo)
                local heavy,heavySession=fixture(case.kind,human)
                eq(heavy:hit(1,-99,'HeroUppercut'),true)
                local before=heavy.enemies[-99].rawLife
                heavySession.now=.2;eq(heavy:hit(1,-99,'HeroJab'),false)
                eq(heavy.enemies[-99].rawLife,before)
            end)
            test(label..' command normalizes light recovery at the exact deadline',function()
                local boss=fixture(case.kind,human)
                eq(boss:hit(1,-99,'HeroJab'),true)
                eq(boss:command('Punch',{x=1,z=0},1.05),'OK')
                eq(boss.state,'Tell')
            end)
            test(label..' command normalizes heavy recovery at the exact deadline',function()
                local boss=fixture(case.kind,human)
                eq(boss:hit(1,-99,'HeroUppercut'),true)
                eq(boss:command('Punch',{x=1,z=0},.4),'OK')
                eq(boss.enemies[-99].rawLife,case.heavy);eq(boss.state,'Tell')
            end)
        end
    end
    print('CampaignBossReactionExpiry: '..passed..' passed, '..#failures..' failed')
    assert(#failures==0,table.concat(failures,'\n'))
    return passed
end
