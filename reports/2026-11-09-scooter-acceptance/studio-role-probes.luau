-- Prepared native boundaries, not a normal-input route or multiple clients.
-- Install the prior campaign fixture as ServerStorage.BrickToadsCampaignFixture.
local F=require(game.ServerStorage.BrickToadsCampaignFixture)
local Session=require(game.ServerScriptService.BrickToads.CombatRuntime.Session)
local function command(userId,seq,kind,fields)
    local role=assert(F.director:controlled(userId))
    local p={kind=kind,runId=F.session.state.runId,actorId=role.actorId,attempt=1,
        levelEpoch=F.session.state.levelEpoch,connectionEpoch=role.connectionEpoch,seq=seq}
    for k,v in pairs(fields or {})do p[k]=v end
    return F.director:command(userId,p,F.now,Session.validIntent)
end
local function drop()
    F.begin(3,3,41)
    for id in pairs(F.director.ordinary.enemies)do F.director.ordinary:_kill(id,'PreparedEntryClear')end
    F.realtime(2.2)
    local bodies={F.world.actors[1],F.world.actors[2],F.world.actors[3]}
    for slot=1,3 do
        F.world:placeActor(slot,F.definition.course.mount)
        assert(F.input(slot,'Attack',{attack='Punch'})=='OK')
    end
    local mode=F.director.modes
    for slot=1,3 do
        local a=mode.actors[slot]
        a.position={x=slot==3 and 100 or 117,y=3,z=slot==1 and 12 or -12}
        a.previous=table.clone(a.position);a.progress=a.position.x-F.definition.course.mount.x
        F.world:campaignPose(slot,a.position,'Speeder',a.velocity)
    end
    mode:_encounters()
    local rat
    for id,e in pairs(F.director.enemies)do if e.encounter then rat=id end end
    local ratBefore=rat and F.world.actors[rat]
    assert(rat and F.director:claim(999,rat)=='OK')
    local enemy=F.director.enemies[rat];local ratBody=F.world.actors[rat]
    local before=F.status();local actorId=enemy.actorId
    assert(command(999,1,'Attack',{attack='Punch'})=='OK')
    local second=command(999,2,'Attack',{attack='Punch'})
    assert(second=='NO_AMMO',second)
    F.realtime(.8)
    local stopped=F.status()
    assert(mode.vehicleGroup.serial==1 and mode.vehicleGroup.phase~='Riding')
    F.realtime(1.2,{[1]={x=.1,z=0},[2]={x=.1,z=0},[3]={x=.1,z=0}})
    local after=F.status()
    assert(mode.vehicleGroup.phase=='Riding' and mode.vehicleGroup.serial==1)
    assert(after.actors[1].attempt==2 and after.actors[1].respawns==2)
    for slot=2,3 do
        assert(bodies[slot]==F.world.actors[slot] and after.actors[slot].actorId==before.actors[slot].actorId)
        assert(after.actors[slot].attempt==1 and after.actors[slot].respawns==3 and after.actors[slot].rawLife==47)
    end
    local projectiles=0;for _ in pairs(F.director.campaignEnemies.projectiles)do projectiles+=1 end
    return {source=before.source,preparation='Entry removed; real boarding; rider poses set once at an existing scripted encounter; real-clock engine thereafter',
        humanRoleClaimed=true,enemyActorId=actorId,sameRatBodyAtClaim=ratBefore==ratBody,
        secondDrop=second,projectilesAfterRewind=projectiles,before=before,stopped=stopped,after=after,
        survivorsSameBodies=bodies[2]==F.world.actors[2] and bodies[3]==F.world.actors[3]}
end
local function invader()
    F.begin(3,3,41)
    local invaderBefore=F.world.actors[-1]
    assert(F.director:claim(998,-1)=='OK')
    local invaderBody=F.world.actors[-1];local enemy=F.director.enemies[-1]
    F.realtime(2.2)
    F.world:placeActor(1,{x=25,y=3,z=-10})
    local before=F.status();local victim=F.session.state.heroes[1].actorId
    assert(command(998,1,'Move',{x=-.01,z=0})=='OK')
    assert(command(998,2,'Attack',{attack='Punch'})=='OK')
    F.realtime(1.3)
    local stolen=F.status();assert(stolen.actors[1].rawLife==39,'Actual native theft must remove exactly raw8')
    assert(invaderBefore==invaderBody and invaderBody==F.world.actors[-1])
    local escapeAt=assert(enemy.lifeEscapeAt)
    -- Explicit lifecycle event injection isolates victim replacement from combat.
    F.session:_die(1,'PreparedVictimDeath')
    F.realtime(.4)
    local replaced=F.status()
    assert(replaced.actors[1].actorId~=victim and replaced.actors[1].attempt==2 and replaced.actors[1].respawns==2)
    F.realtime(5.2)
    local after=F.status();assert(enemy.dead and F.now>=escapeAt)
    assert(after.actors[1].rawLife==47 and after.actors[1].attempt==2 and after.actors[1].respawns==2)
    local refunds=0
    for _,row in ipairs(F.session.logs)do if row.kind=='StolenLifeRecovered'then refunds+=1 end end
    assert(refunds==0,'The victim link cannot heal a replacement body')
    return {source=before.source,preparation='Same-body pre-engagement claim, initial shield wait and one victim stance; actual validated theft, then explicit Session death injection',
        before=before,stolen=stolen,replaced=replaced,after=after,escapeAt=escapeAt,escaped=enemy.dead,
        sameInvaderBodyBeforeEscape=invaderBefore==invaderBody,staleRefunds=refunds,owner=998}
end
local result={drop=drop(),invader=invader()}
F.close()
return game.HttpService:JSONEncode(result)
