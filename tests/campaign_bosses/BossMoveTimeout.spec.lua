-- The real boss director routes owner input; only engine presentation is replaced.
return function()
    local Boss=require('../../src/server/gameplay/CampaignBoss')
    local CampaignDirector=require('../../src/server/gameplay/CampaignDirector')
    local LevelDirector=require('../../src/server/gameplay/LevelDirector')
    local Session=require('../../src/stand/server/Session')
    local Core=require('../../src/server/RunLifecycle')
    local Combat=require('../../src/stand/server/Combat')
    local GameConfig=require('../../src/server/gameplay/GameConfig')
    local BaseConfig=require('../../src/stand/server/Config')
    local FakeWorld=require('../stand/FakeWorld')
    local function fixture(kind)
        local w=FakeWorld.new();w.positions={[1]={x=70,y=3,z=20}};w.names={};w.requestedMoves={};w.placements=0
        function w:position(id) return self.positions[id] end
        function w:stage() end
        function w:progress() end
        function w:enemyHealth() end
        function w:enemyIdentity(id,actorId) self.actors[id].id=actorId end
        function w:spawnEnemy(id,name,p) self.positions[id]=table.clone(p);self.actors[id]={alive=true};return true end
        function w:campaignWalkSpeed(id,speed) self.actors[id].walkSpeed=speed;return true end
        function w:placeActor(id,p) self.positions[id]=table.clone(p);self.placements+=1;return true end
        function w:face() end
        function w:aim() end
        function w:cue() end
        function w:bossTell() end
        function w:projectile() end
        function w:removeProjectile() end
        function w:move(id,x,z) self.requestedMoves[id]={x=x,z=z} end
        local route={id='boss-move-timeout',name='Prepared arena',mode='Finale',campaignIndex=13,
            zones={{name='Arena',enemies={},exit={}}},boss={kind=kind,position={x=0,y=3,z=0}}}
        local cfg=GameConfig(BaseConfig,route)
        local s=Session.new(Core,Combat,cfg,{{userId=1,template='Mr. Green'}},'boss-move-timeout-'..kind,w)
        assert(s:step(0)=='OK')
        local Modes={new=function() return {complete=false,step=function() end,close=function() end} end}
        local d=CampaignDirector.new(s,w,Combat,cfg,{Director=LevelDirector,CampaignModes=Modes,CampaignBoss=Boss})
        d.bossGate=function() return {state='Human',userId=99} end
        assert(d:_startBoss(0,false));local b=d.boss;local seq=0
        local function command(kind,fields,now,epoch)
            seq+=1;local role=d:controlled(99)
            local p={kind=kind,runId=s.state.runId,actorId=role.actorId,attempt=role.attempt,
                levelEpoch=s.state.levelEpoch,connectionEpoch=epoch or role.connectionEpoch,seq=seq}
            for k,v in pairs(fields or {}) do p[k]=v end
            return d:command(99,p,now,Session.validIntent)
        end
        local function step(now) s.now=now;d:step(now,.01) end
        return b,w,s,d,cfg,command,step
    end
    for _,kind in ipairs({'BigBlag','RoboManus','GeneralSlaughter','Buzzball','DarkQueen'}) do
        local b,w,s,d,cfg,command,step=fixture(kind)
        local actorId=b.enemies[-99].actorId;local body=w.actors[-99]
        assert(body.walkSpeed==9 and b.state=='Ready')
        assert(command('Move',{x=1,z=0},0)=='OK' and w.requestedMoves[-99].x==1)
        step(cfg.MoveTimeout-.01);assert(w.requestedMoves[-99].x==1,'Fresh owner movement must persist within its budget')
        step(cfg.MoveTimeout+.01)
        assert(w.requestedMoves[-99].x==0 and w.requestedMoves[-99].z==0,
            kind..' one Move at0 must stop after '..cfg.MoveTimeout..'; requested x='..w.requestedMoves[-99].x)
        local idleMoves=w.moves;step(2)
        assert(b.state=='Ready' and w.requestedMoves[-99].x==0 and w.actors[-99]==body
            and b.enemies[-99].actorId==actorId and body.walkSpeed==9)
        assert(command('Move',{x=-1,z=0},2)=='OK' and w.requestedMoves[-99].x==-1)
        local epoch=b.enemies[-99].connectionEpoch
        assert(d:connection(99,false)=='OK' and w.requestedMoves[-99].x==0)
        assert(command('Move',{x=1,z=0},2.01)=='OFFLINE')
        assert(d:connection(99,true)=='OK');step(3)
        assert(w.requestedMoves[-99].x==0,'Reconnect must not replay old movement')
        assert(command('Move',{x=1,z=0},3,epoch)=='STALE_CONNECTION')
        assert(w.requestedMoves[-99].x==0)
        assert(command('Move',{x=1,z=0},3)=='OK');step(3+cfg.MoveTimeout+.01)
        assert(w.requestedMoves[-99].x==0,'Fresh epoch input must receive the same timeout')
        d:close('TestComplete')
    end
    print('PASS all five campaign bosses stop one stale Move without changing body, cap or ownership')
    for _,kind in ipairs({'GeneralSlaughter','RoboManus'}) do
        local b,w,s,d,cfg,command,step=fixture(kind)
        assert(command('Move',{x=1,z=0},0)=='OK')
        assert(command('Attack',{attack=kind=='RoboManus' and 'Dash' or 'Punch'},.1)=='OK')
        local a=b.attack;local placements=w.placements
        step(a.tellAt+.2)
        local first=table.clone(w.positions[-99]);step(a.tellAt+.4)
        local second=w.positions[-99]
        assert(w.placements>placements and (second.x~=first.x or second.y~=first.y or second.z~=first.z),
            'The stale input timeout must leave accepted '..a.name..' motion running')
        assert(b.attack==a and b.state=='Active' and w.requestedMoves[-99].x==0)
        d:close('TestComplete')
    end
    print('PASS owner Move expiry leaves accepted charge and jump motion running')
end
