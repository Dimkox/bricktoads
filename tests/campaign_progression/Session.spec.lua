return function(Session,Core,Combat,Config,FakeWorld)
    local function fixture()
        local world=FakeWorld.new()
        local session=Session.new(Core,Combat,Config,{{userId=1,template='Mr. Green'},
            {userId=2,template='Mr. Green'},{userId=3,template='Mr. Yellow'}},'campaign-run',world,nil,{levelId='causeway'})
        session:step(1)
        return session,world
    end
    local session,world=fixture()
    assert(type(session.advanceLevel)=='function','Session must expose the real campaign transition boundary')
    local actor=session.state.heroes[1].actorId
    session:_event('SetHealth',1,{health=2});session.combat[1].rawLife=15
    session:connection(2,false,1)
    for _=1,4 do session:_die(3,'fixture');session:step(session.now+3) end
    assert(session.state.heroes[3].status=='Eliminated')
    local before=session.state.heroes[2]
    session.lastSeq[1]=90;session.lastMove[1]=1;session.buckets[1]={tokens=0,last=1}
    session.combat[1].attack={actorId=actor};session.combat[1].deathAt=nil
    assert(session:advanceLevel('rope',14,{prerequisitesMet=true})=='OK')
    assert(session.state.runId=='campaign-run' and session.state.levelId=='rope' and session.state.levelEpoch==2)
    local hero=session.state.heroes[1]
    assert(hero.actorId==actor and hero.attempt==1 and hero.respawns==3 and hero.health==5)
    assert(session.combat[1].rawLife==47 and not session.combat[1].attack and session.lastSeq[1]==0)
    assert(not session.lastMove[1] and not session.buckets[1])
    local offline=session.state.heroes[2]
    assert(not offline.connected and offline.connectionEpoch==before.connectionEpoch and offline.actorId==before.actorId)
    assert(offline.health==5 and offline.respawns==3 and offline.attempt==1)
    assert(session.state.heroes[3].status=='Eliminated' and session.combat[3].rawLife==0)
    assert(world.spawns==6 and world.relocations==2,'Transition must relocate survivors without creating another life')
    local intent={kind='Move',runId='campaign-run',actorId=actor,attempt=1,levelEpoch=1,connectionEpoch=1,seq=91,x=1,z=0}
    assert(session:intent(1,intent,14)=='STALE_ACTOR')
    intent.levelEpoch=2;intent.seq=1
    assert(session:intent(1,intent,14)=='OK','New level accepts a fresh sequence')
    print('PASS campaign transition preserves identity, offline owners, elimination and resource accounting')

    local denied,unsafe=fixture();local revision=denied.state.revision
    assert(denied:advanceLevel('rope',2,{prerequisitesMet=false})=='EXIT_NOT_READY')
    assert(denied.state.revision==revision and denied.state.levelEpoch==1)
    unsafe.safe=false
    assert(denied:advanceLevel('rope',2,{prerequisitesMet=true})=='UNSAFE_DESTINATION')
    assert(denied.state.revision==revision and unsafe.relocations==0)
    unsafe.safe=true
    assert(denied:advanceLevel('causeway',2,{prerequisitesMet=true})=='SAME_LEVEL')
    denied:_event('SetHealth',1,{health=1});denied.combat[1].rawLife=0;denied.combat[1].deathAt=3
    denied.combat[2].deathAt=3;denied.combat[3].deathAt=3
    assert(denied:advanceLevel('rope',2,{prerequisitesMet=true})=='NO_SURVIVOR')
    print('PASS incomplete exit, unsafe destination, same level and dying party reject without mutation')

    local pending=fixture()
    pending:_event('SetHealth',2,{health=0})
    pending.combat[2].rawLife=0;pending.combat[2].deathAt=4;pending.combat[2].reactionEnd=4
    assert(pending:advanceLevel('rope',2,{prerequisitesMet=true})=='OK')
    assert(pending.combat[2].rawLife==0 and pending.combat[2].deathAt==4 and pending.state.heroes[2].health==0,
        'An already accepted lethal effect cannot turn into a level-boundary heal')
    pending:step(3);assert(pending.state.heroes[2].status=='Alive')
    pending:step(4);assert(pending.state.heroes[2].status=='AwaitingRespawn' and pending.state.heroes[2].respawns==3)
    pending:step(5);assert(pending.state.heroes[2].attempt==2 and pending.state.heroes[2].respawns==2)
    print('PASS level advance preserves lethal timers and the ordinary later respawn cost')
end
