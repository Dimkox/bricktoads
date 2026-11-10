return function(CampaignDirector,LevelDirector,Session,Core,Combat,Config,FakeWorld)
    assert(type(CampaignDirector.new)=='function','Campaign director must own mode and boss completion gates')
    local function fixture(bossKind,withEnemy,mode)
        local world=FakeWorld.new();world.names={};world.positions={}
        function world:position(id) return self.positions[id] or {x=0,y=3,z=0} end
        function world:stage(value) self.stageName=value end
        function world:progress() end
        function world:enemyMove() end
        function world:enemyHealth() end
        function world:enemyIdentity() end
        function world:spawnEnemy(id,kind,position)
            self.positions[id]=table.clone(position)
            return self:spawn(id,'ordinary-'..id,nil,false)
        end
        function world:face() end
        function world:reached() return true end
        function world:atExit() return true end
        function world:cue() end
        function world:placeActor(id,point) self.positions[id]=table.clone(point);return true end
        local route={id='test-mode',name='Test course',campaignIndex=5,mode=mode or 'Surf',
            zones={{name='Course',objective='Finish course',enemies=withEnemy and {{id=-1,x=8,z=0}} or {},exit={}}},
            boss=bossKind and {kind=bossKind,position={x=20,y=3,z=0}} or {position={x=20,y=3,z=0}}}
        local cfg=table.clone(Config);cfg.Level=route
        local session=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'campaign-director',world)
        session:step(1)
        local modes={new=function()
            return {complete=false,steps=0,step=function(self) self.steps+=1 end,
                snapshot=function() return {objective='Ride to the arena'} end,
                interaction=function() return {available=false} end,interact=function() return 'NO_INTERACTION' end,
                close=function(self) self.closed=true end}
        end}
        local bosses={new=function(_,_,_,definition)
            local owner=definition.bossGate.ownerUserId
            return {defeated=false,state=definition.boss.chaseComplete and 'Ready' or 'Chase',
                enemies={[-99]={actorId='boss-actor',boss=true,health=3,rawLife=207}},
                step=function() end,hit=function() return true end,canMove=function() return true end,
                finishChase=function(self) self.state='Ready';self.handoffs=(self.handoffs or 0)+1 end,
                controlled=function() return owner and {enemyId=-99,actorId='boss-actor',attempt=1,connectionEpoch=1,
                    connected=true,status='Alive',template='Boss'} end,
                available=function() return {} end,claim=function() return 'UNKNOWN_ENEMY' end,
                connection=function() return 'OK' end,
                command=function(self) self.commands=(self.commands or 0)+1;return 'OK' end,
                snapshot=function() return {kind=bossKind} end,close=function(self) self.closed=true end}
        end}
        local director=CampaignDirector.new(session,world,Combat,cfg,{Director=LevelDirector,CampaignModes=modes,CampaignBoss=bosses})
        return director,session,world
    end
    local d,session,world=fixture()
    d:step(2,.1)
    assert(d.modes.steps==1 and not d.result and not d.boss,'An empty ordinary roster cannot bypass the mode objective')
    assert(world.campaignModes==d.modes)
    d.modes.complete=true;d:step(3,.1)
    assert(d.result=='Won' and not d.boss and world.stageName=='Won','Nonboss modes never create a Guardian')
    d:close('Advance');assert(d.modes.closed and world.campaignModes==nil)
    print('PASS traversal objectives own completion and nonboss stages never spawn a fallback Guardian')
    local combat=fixture(nil,true)
    combat.modes.complete=true;combat:step(2,.1)
    assert(not combat.result,'Travel completion cannot bypass an undefeated authored enemy')
    combat.ordinary:_kill(-1,'fixture');combat:step(3,.1)
    assert(combat.result=='Won')
    print('PASS an authored ordinary enemy remains a real completion gate after traversal')
    local traversal=fixture(nil,true,'Rope')
    traversal.definition.requiresClearAtExit=false
    traversal.modes.complete=true;traversal:step(2,.1)
    assert(traversal.result=='Won' and not traversal.ordinary.enemies[-1].dead,
        'an earned shaft exit must not require chasing a surviving bird back up the entire shaft')
    local boarding=fixture(nil,true)
    boarding.ordinary.enemies[-1].encounter=true
    assert(boarding.modes.canBoard(),'a later riding encounter must not re-lock the entry boarding pad')
    assert(type(boarding.modes.spawnEncounter)=='function' and type(boarding.modes.resetEncounters)=='function',
        'ride encounters and rewind must route through actual ordinary actors')
    assert(type(traversal.modes.ropeKick)=='function','rope action must hit actual role actors')
    local expired
    boarding.campaignEnemies={expireEncounter=function(_,id) expired=id end}
    boarding.modes.resetEncounters({replayIds={}})
    assert(boarding.ordinary.enemies[-1].dead and expired==-1,
        'all active riding passes expire on rewind even when their trigger is before the checkpoint')
    print('PASS mode-specific exit, entry-only boarding and real encounter callbacks')

    local rope,ropeSession,ropeWorld=fixture(nil,true,'Rope')
    rope.config.SourceCombat={npcLightReaction=1.05,npcHeavyReaction=.85,heavyProtection=28/60}
    local bird=rope.ordinary.enemies[-1]
    bird.kind='LargeRaven';bird.rawLife=15;bird.maxRawLife=79
    rope.campaignEnemies={hasRavenClaw=function() return true end}
    local shape
    function ropeWorld:targets(_,geometry) shape=geometry;return {-1} end
    assert(rope:_ropeKick(1,ropeSession.now)=='OK')
    assert(shape==rope.config.Attacks.RopeClaw and bird.rawLife==7,
        'an armed large-raven strike uses the expanded contact shape and source profile7 even at low Life')
    print('PASS armed rope shape and LargeRaven source branch preserve their real damage profile')
    local boss,run=fixture('BigBlag')
    boss.bossGate=function() return {state='Waiting'} end
    boss.modes.complete=true;boss:step(2,.1)
    assert(boss.stage=='BossReady' and not boss.result and not boss.boss)
    boss.bossGate=function() return {state='Human',userId=90} end
    boss:step(3,.1);assert(boss.boss and boss.stage=='Boss' and not boss.result)
    local p={kind='Attack',attack='Punch',runId=run.state.runId,actorId='boss-actor',attempt=1,
        levelEpoch=1,connectionEpoch=1,seq=1}
    assert(boss:command(90,p,3,Session.validIntent)=='OK' and boss.boss.commands==1)
    assert(boss:command(90,p,3,Session.validIntent)=='STALE_SEQUENCE' and boss.boss.commands==1)
    p.seq=2;p.levelEpoch=2
    assert(boss:command(90,p,3,Session.validIntent)=='STALE_ACTOR')
    assert(not boss.result);boss.boss.defeated=true;boss:step(4,.1);assert(boss.result=='Won')
    print('PASS typed boss invitation, fight, stale command and defeat gates run after traversal')
    local chase=fixture('Buzzball',false,'Clinger')
    chase.bossGate=function() return {state='Waiting'} end
    chase:step(2,.1);assert(chase.modes.steps==0 and not chase.boss,'Invitation must resolve before chase progression starts')
    chase.bossGate=function() return {state='NPC'} end
    chase:step(3,.1)
    assert(chase.boss and chase.boss.state=='Chase' and chase.modes.steps==1)
    local body=chase.boss;local life=body.enemies[-99].rawLife
    chase.modes.complete=true;chase:step(4,.1)
    assert(chase.boss==body and body.handoffs==1 and body.enemies[-99].rawLife==life and chase.stage=='Boss')
    chase.modes.chaseActor({x=999,y=3,z=0})
    assert(chase.world.positions[-99].x==chase.definition.boss.position.x and chase.modes.chaseFinished,
        'Trailing rider simulation cannot move the same boss out of its battle arena')
    print('PASS Buzzball invitation precedes chase and the same boss identity and Life enter the fight')
    local snapshot=chase:snapshot()
    assert(snapshot.bossMechanic=='Campaign' and snapshot.bossHits==nil and snapshot.bossMax==nil,
        'Campaign snapshots cannot advertise the Guardian ball mechanic')
end
