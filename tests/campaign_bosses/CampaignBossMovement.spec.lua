-- Campaign bosses use scripted attack motion, but their human Ready-state Move
-- commands still need an explicit ordinary movement cap in the real World.
return function(Boss,Config)
    local failures={}
    for _,kind in ipairs({'BigBlag','RoboManus','GeneralSlaughter','Buzzball','DarkQueen'}) do
        local session={now=0,state={runId='boss-movement',levelEpoch=2,status='Active',heroes={}},order={},combat={}}
        local world={positions={},speedCalls=0}
        function world:spawnEnemy(id,_,position) self.positions[id]=table.clone(position);return true end
        function world:enemyHealth() end
        function world:campaignWalkSpeed(id,speed)
            assert(id==-99,'The movement cap belongs to the existing boss body')
            self.speedCalls+=1;self.bossSpeed=speed;return true
        end
        local boss=Boss.new(session,world,Config,{boss={type=kind,position={x=0,y=3,z=0},chaseComplete=true},
            bossGate={ownerUserId=99,connected=true}})
        assert(boss:canMove(),kind..' accepts movement in Ready')
        if world.speedCalls~=1 or world.bossSpeed~=Config.Enemy.speed then
            failures[#failures+1]=kind..' movement cap expected '..Config.Enemy.speed..', got '..tostring(world.bossSpeed)
        end
    end
    assert(#failures==0,table.concat(failures,'; '))
    print('PASS all five human campaign bosses initialize a usable Ready-state movement cap')
end
