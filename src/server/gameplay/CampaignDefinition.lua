-- Original BrickToads courses. Mode/family inventory follows FULL_GAME_SCOPE;
-- every distance, speed, geometry, population and timer here is Roblox tuning.
-- No ROM track data, music, art or unknown source object identities are copied.
local Definition={count=13,bossTypes={'CausewayGuardian','BigBlag','RoboManus','GeneralSlaughter','Buzzball','DarkQueen'}}
local MOD=2147483647
local function copy(v) if type(v)~='table' then return v end;local r={};for k,a in pairs(v) do r[k]=copy(a) end;return r end
local function floor(x,top,z,w,d) return {x=x,y=top-1,z=z,w=w,h=2,d=d} end
local function point(x,y,z) return {x=x,y=y,z=z or 0} end
local function volume(x,y,z,w,h,d) return {minX=x-w/2,maxX=x+w/2,minY=y-h/2,maxY=y+h/2,minZ=z-d/2,maxZ=z+d/2} end
local function hazard(id,kind,x,y,z,w,h,d,motion)
    return {id=id,kind=kind,x=x,y=y,z=z,w=w,h=h,d=d,motion=motion}
end
local names={"Flooded Causeway","Echo Shaft","Copper Rush","Frostworks","Tidal Foundry","Four Coil Vaults",
    "Ember Airway","Machine Ascent","Pressure Pipes","Fuse Pursuit","Magnetic Circuit","Turning Spire","Last Eclipse"}
local modes={'Causeway','Rope','Speeder','Ice','Surf','Serpents','Jet','Ascent','Tubes','Race','Clinger','Tower','Finale'}
local bossByLevel={[5]='BigBlag',[8]='RoboManus',[10]='GeneralSlaughter',[11]='Buzzball',[13]='DarkQueen'}
local objectives={Rope='Descend on the rope; swing clear of the shaft traps',Speeder='Board the speeder; steer and jump through the course',
    Ice='Control your slide across the frozen platforms',Surf='Board the surfboard and reach the shoreline',Serpents='Ride moving serpents through all four vaults',
    Jet='Board the jet and steer through the aerial gates',Ascent='Climb the lifts, springs and fan shafts',Tubes='Cross dry pipes and swim the flooded chambers',
    Race='Beat the rat to every bomb and defuse it',Clinger='Hold each route direction and stay ahead of the orb',Tower='Climb around the rotating spire and resist the wind',
    Finale='Enter the eclipse arena and defeat the final guardian'}
local function sourceModule(name)
    if script then return require(script.Parent[name]) end
    return require('./'..name)
end
function Definition.build(index,seed)
    assert(type(index)=='number' and index%1==0 and index>=1 and index<=13,'Invalid campaign index')
    assert(type(seed)=='number' and seed==seed and seed%1==0 and seed>=1 and seed<MOD,'Invalid campaign seed')
    if index==1 then
        local d=sourceModule('LevelVariation').build(sourceModule('LevelDefinition'),seed)
        d.campaignIndex=1;d.mode='Causeway';d.spawn=point(-65,3,0);d.boss.kind='CausewayGuardian';return d
    end
    local rng=(seed+index*7919)%(MOD-1)+1
    local choices={}
    local function choose() rng=rng*48271%MOD;local n=rng%3+1;choices[#choices+1]=n;return n end
    local c={hazards={},checkpoints={},supports={},media={},platforms={},tuning='ROBLOX_ORIGINAL_COURSE',speed=28}
    local d={id='campaign-'..index,name=names[index],campaignIndex=index,mode=modes[index],course=c,
        requiresClearAtExit=false,
        spawn=point(0,3,0),bounds={minX=-32,maxX=500,minY=-60,maxY=280,minZ=-56,maxZ=56},
        variation={version=1,seed=seed,sectionChoices=choices},calibration='ORIGINAL_ROBLOX_MODE_TUNING'}
    local platforms,enemies={},{}
    local function addFloor(x,y,z,w,depth) local p=floor(x,y,z,w,depth);platforms[#platforms+1]=p;return p end
    local function cp(x,y,z,progress) c.checkpoints[#c.checkpoints+1]={position=point(x,y,z),progress=progress} end
    local function foe(kind,x,y,z) enemies[#enemies+1]={id=-#enemies-1,kind=kind,x=x,y=y,z=z,rawLife=31} end
    local finish=point(180,3,0)
    if index==2 then
        c.anchor=point(0,258,0);c.ropeLength=15;c.descentSpeed=10;c.swingLimit=16;c.swingAcceleration=32;c.swingDamping=1.1;c.emitters={}
        d.spawn=point(0,240,0);addFloor(0,237,0,18,20);addFloor(0,0,0,46,32);cp(0,240,0,0)
        for n=1,9 do local v=choose();local y=220-n*20
            c.hazards[#c.hazards+1]=hazard('shaft-'..n,({'Raven','ElectricTrap','Toadtrap'})[(n-1)%3+1],(v-2)*10,y,0,9,5,18,
                n%3==0 and {axis='x',amplitude=5,period=3.5,phase=n} or nil)
            if n%3==0 then cp(0,y+12,0,240-y-12) end
        end
        for n=1,3 do c.emitters[n]={id='shaft-blaster-'..n,kind='RetroBlaster',position=point(n%2==0 and -22 or 22,225-n*55,0),interval=2.3,speed=15,life=3} end
        finish=point(0,3,0);c.axis='descent';d.bounds.maxX=38;d.bounds.maxY=270;d.bounds.minY=-25
    elseif index==3 or index==5 or index==7 then
        local surf=index==5;local jet=index==7
        c.speed=jet and 35 or (surf and 29 or 32);c.acceleration=jet and .45 or .35;c.maxSpeed=jet and 52 or 48
        c.mount=point(24,3,0);c.mountRange=7;c.finishDistance=420;c.laneLimit=18;c.steerSpeed=22;c.jumpSpeed=42
        -- Only the entry foot patrol blocks boarding. Rocket rats are actual
        -- later scripted encounters, never an enemy that must die before riding.
        addFloor(5,0,0,58,46);foe('Invader',28,3,-10)
        c.restart={stopSeconds=.35,rewindSeconds=.55,acceleration=110,tuning='ROBLOX_ORIGINAL_RESTART_TIMING'}
        c.encounters={}
        if index==3 or index==7 then c.encounters[1]={id='rocket-rat-pass-1',kind='RocketRat',progress=90,
            position=point(138,jet and 27 or 14,12),allowedDrop=true,
            trajectory={from=point(138,jet and 27 or 14,12),to=point(274,jet and 27 or 14,-12),duration=4,dropAt=1.5,dropGroundY=3}}
        end
        if surf then c.media[1]={kind='Water',minX=32,maxX=450,minY=-12,maxY=1,minZ=-25,maxZ=25} end
        if jet then c.altitudeMin=5;c.altitudeMax=31;c.mount.y=8 end
        c.ramps={};c.emitters={}
        cp(24,c.mount.y,0,0)
        local sectionX=54
        for n=1,12 do local v=choose();sectionX+=25+v;local x=sectionX
            local kind=jet and ({'AirMine','ElectricGate','Rocket'})[(n-1)%3+1] or
                (surf and ({'Mine','Log','Whirlpool'})[(n-1)%3+1] or ({'Wall','LowBarrier','Overhead'})[(n-1)%3+1])
            local y=jet and (8+(v-1)*9) or (kind=='Overhead' and 10 or 3)
            local h=jet and 9 or (kind=='Overhead' and 5 or (kind=='Wall' and 18 or 3))
            local z=jet and 0 or (v-2)*12;local depth=(jet or kind=='LowBarrier' or kind=='Log') and 44 or 12
            c.hazards[#c.hazards+1]=hazard('ride-'..n,kind,x,y,z,3,h,depth,
                kind=='Rocket' and {axis='z',amplitude=8,period=2.4,phase=n} or nil)
            if n==4 or n==8 then cp(x+12,c.mount.y,0,x+12-c.mount.x) end
            if index==3 and (n==2 or n==8) then c.ramps[#c.ramps+1]={id='ramp-'..n,x=x-10,y=1,z=0,w=10,h=2,d=12,launchSpeed=50} end
        end
        if surf or jet then for n=1,3 do c.emitters[n]={id='ride-launcher-'..n,kind='RocketLauncher',position=point(100+n*85,jet and 20 or 4,23),interval=3,speed=18,life=2} end end
        addFloor(439,0,0,62,48);finish=point(434,3,0);d.bounds.maxX=495;c.axis='x'
        if index==3 then
            -- The logical speeder floor is y=0 across every steering lane.
            -- Render that same solid road, overlapping both arrival and finish
            -- ledges; water and flight retain their distinct support geometry.
            addFloor((c.mount.x+finish.x)/2,0,0,finish.x-c.mount.x+24,c.laneLimit*2+10)
        end
    elseif index==4 then
        c.acceleration=19;c.friction=2.4;c.maxSpeed=25;c.gravity=150;c.jumpSpeed=51
        local cursor=-12
        for n=1,9 do local v=choose();local width=25+v*4;local z=(v-2)*3
            addFloor(cursor+width/2,(n%3==0 and 2 or 0),z,width,30);cursor+=width
            if n<9 then cursor+=4 end
            if n%2==0 then c.hazards[#c.hazards+1]=hazard('ice-'..n,n%4==0 and 'Icicle' or 'Snowball',cursor-8,5,(v-2)*9,4,6,7,
                {axis=n%4==0 and 'y' or 'z',amplitude=n%4==0 and 4 or 10,period=3,phase=n}) end
            if n==3 or n==6 then cp(cursor-8,5,z,cursor-8) end
        end
        c.blocks={}
        for _,n in ipairs({2,6}) do local p=platforms[n]
            c.blocks[#c.blocks+1]={id='ice-block-'..n,kind='IceBlock',position=point(p.x,p.y+p.h/2+2,p.z+8),w=6,h=4,d=6,
                minX=p.x-p.w/2+4,maxX=p.x+p.w/2-4}
        end
        c.walls={}
        for _,n in ipairs({3,7}) do local p=platforms[n]
            c.walls[#c.walls+1]={id='ice-wall-'..n,kind='MovingWall',x=p.x,y=p.y+7,z=p.z+10,w=4,h=14,d=5,
                motion={axis='z',amplitude=3,period=4.5,phase=n}}
        end
        local p=platforms[4];local edge=p.x+p.w/2+2
        c.supports[1]={id='ice-shuttle',kind='MovingIcePlatform',w=7,h=1,d=12,speed=3,
            path={point(edge,p.y+1,-5),point(edge,p.y+1,5)}}
        for _,n in ipairs({3,7}) do local p=platforms[n]
            c.hazards[#c.hazards+1]=hazard('ice-spike-'..n,'Spike',p.x+4,p.y+3.5,9,5,5,5,
                {axis='y',amplitude=1.5,period=4,phase=n})
        end
        table.sort(c.hazards,function(a,b) return a.x<b.x end)
        cp(0,3,0,0);finish=point(cursor-6,3,0);foe('Snowman',56,3,6);foe('Snowman',154,3,-7);d.bounds.maxX=cursor+52
    elseif index==6 then
        c.gravity=150;c.jumpSpeed=51;c.maxSpeed=16;c.rooms={}
        for room=1,4 do local v=choose();local base=(room-1)*80;local y=(room-1)*6
            addFloor(base,y,0,20,22);addFloor(base+72,y+6,0,20,24)
            local ex=volume(base+72,y+9,0,12,8,18)
            c.rooms[room]={id=room,exit=ex,start=point(base,y+3,0)}
            c.supports[room]={id='serpent-'..room,kind='Serpent',room=room,speed=10+v,w=15,h=1,d=14,segments=4,segmentSpacing=6,
                path={point(base+19,y+1,0),point(base+36,y+3,(v-2)*4),point(base+55,y+5,0),point(base+36,y+3,-(v-2)*4)}}
            c.hazards[#c.hazards+1]=hazard('coil-spike-'..room,'Spike',base+38,y+5,(v-2)*6,4,4,5)
            cp(base,y+3,0,room-1)
        end
        finish=point(312,27,0);d.bounds.maxX=350;c.axis='rooms'
    elseif index==8 then
        c.gravity=150;c.jumpSpeed=52;c.maxSpeed=16;c.fans={};c.springs={};c.lifts={};c.axis='ascent'
        addFloor(0,0,0,36,30);cp(0,3,0,0)
        for n=1,16 do local v=choose();local x=n%2==0 and -8 or 8;local y=n*6
            addFloor(x,y,(v-2)*2,25,24)
            if n==4 or n==12 then c.fans[#c.fans+1]={id='fan-'..n,x=x,y=y+7,z=0,w=12,h=14,d=14,force=170} end
            if n==6 then c.springs[1]={x=x,y=y+3,z=0,w=8,h=4,d=8,power=68} end
            if n==8 then cp(x,y+3,0,y) end
            if n%4==2 then c.hazards[#c.hazards+1]=hazard('ascent-'..n,'Gas',x+(v-2)*8,y+4,9,6,6,6,
                {axis='z',amplitude=5,period=4,phase=n}) end
            if n==5 or n==13 then c.hazards[#c.hazards+1]=hazard('ascent-electric-'..n,'ElectricTrap',x+7,y+5,8,6,8,7,
                {phase=n}) end
            if n==9 then c.hazards[#c.hazards+1]=hazard('ascent-piston','MechanicalCrusher',x+8,y+7,9,6,10,6,
                {axis='y',amplitude=5,period=3.5,phase=n}) end
        end
        c.lifts[1]={id='lift-a',kind='Lift',w=14,h=1,d=15,path={point(-24,16,0),point(-24,34,0)},speed=5}
        foe('SentryDrone',8,15,0);foe('Slug',-8,39,0);foe('GasTurret',8,63,8)
        finish=point(-8,99,0);d.bounds.maxX=65;d.bounds.maxY=150;d.bounds.minX=-65
    elseif index==9 then
        c.gravity=150;c.jumpSpeed=51;c.maxSpeed=16;c.swimSpeed=15;c.swimAcceleration=28;c.oxygenSeconds=18
        addFloor(12,0,0,50,30);addFloor(91,-18,0,112,34);addFloor(172,0,0,52,30)
        addFloor(246,-25,0,96,34);addFloor(321,0,0,58,36);cp(0,3,0,0);cp(174,3,0,174)
        c.media={{kind='Water',minX=35,maxX=148,minY=-17,maxY=5,minZ=-18,maxZ=18,current={x=-5,y=0,z=0}},
            {kind='Water',minX=196,maxX=295,minY=-24,maxY=5,minZ=-18,maxZ=18,current={x=4,y=-1.5,z=0}}}
        for n=1,6 do local v=choose();local x=46+n*37
            c.hazards[#c.hazards+1]=hazard('pipe-'..n,n%2==0 and 'Gear' or 'PipeCrusher',x,-5,(v-2)*9,5,10,8,
                {axis='y',amplitude=6,period=3.5,phase=n})
        end
        foe('Robot',20,3,6);foe('Electrofish',78,-6,-8);foe('Hammerfish',117,-8,7);foe('Shark',230,-9,-6);foe('Duck',276,-5,8)
        finish=point(337,3,0);d.bounds.maxX=390
    elseif index==10 then
        c.gravity=150;c.jumpSpeed=52;c.maxSpeed=19;c.axis='race';c.bombs={};c.ratSpeed=9
        addFloor(0,90,0,30,28);d.spawn=point(0,93,0);cp(0,93,0,0)
        for race=1,3 do local v=choose();local y=90-race*30;local x=(race%2==0 and -1 or 1)*(8+v*2)
            for stair=1,5 do addFloor(x*(stair%2==0 and -.3 or 1),90-(race-1)*30-stair*6,0,28,28) end
            c.bombs[race]={id='bomb-'..race,position=point(x,y+3,0),radius=7,
                checkpoint=point(x,y+3,0),ratStart=point(-x,y+28,0)}
            if race<3 then cp(x,y+3,0,race) end
            c.hazards[#c.hazards+1]=hazard('race-gas-'..race,'Gas',-x,y+17,9,6,6,6)
        end
        foe('SentryDrone',0,75,7);foe('GasTurret',0,45,8);finish=point(c.bombs[3].position.x,3,0)
        d.bounds.minX=-60;d.bounds.maxX=60;d.bounds.maxY=140
    elseif index==11 then
        c.speed=24;c.chaseSpeed=22;c.chaseGap=32;c.chaseLife=207;c.path={};c.axis='path'
        local x,y,z=0,3,0;local directions={{x=1,z=0},{x=0,z=1},{x=-1,z=0},{x=0,z=-1}}
        for n=1,12 do local v=choose();local direction=directions[(n-1)%4+1];local length=32+v*6
            c.path[n]={from=point(x,y,z),direction=copy(direction),length=length}
            local nx,nz=x+direction.x*length,z+direction.z*length
            addFloor((x+nx)/2,0,(z+nz)/2,direction.x~=0 and length+8 or 9,direction.z~=0 and length+8 or 9)
            x,z=nx,nz
        end
        finish=point(x,y,z);d.bounds={minX=-70,maxX=120,minY=-30,maxY=65,minZ=-70,maxZ=120}
    elseif index==12 then
        c.gravity=150;c.jumpSpeed=52;c.maxSpeed=16;c.radius=23;c.rotationSpeed=.16;c.windForce=6;c.towerPlatforms={};c.springs={};c.axis='tower';c.renderDynamicPlatforms=true
        local v=choose();c.windPhase=v
        d.spawn=point(23,3,0);cp(23,3,0,0)
        for n=0,18 do local choice=choose();local angle=n*.48;local y=n*5.5;local radius=23+(choice-2)
            local x,z=math.cos(angle)*radius,math.sin(angle)*radius
            addFloor(x,y,z,18,18);c.towerPlatforms[#c.towerPlatforms+1]={angle=angle,radius=radius,y=y,w=18,d=18}
            if n==9 then cp(x,y+3,z,y) end
            if n==7 or n==14 then c.springs[#c.springs+1]={x=x,y=y+3,z=z,w=8,h=3,d=8,power=65,towerPlatform=#c.towerPlatforms} end
            if n>0 and n%5==0 then c.hazards[#c.hazards+1]=hazard('spire-spike-'..n,'RotatingSpike',x,y+3,z,4,5,4,
                {axis='orbit',radius=radius,period=6,phase=angle}) end
        end
        foe('Hordhead',23,25,0);foe('Swellcheeks',-20,58,4);foe('FlyingHead',-4,86,-20)
        local final=c.towerPlatforms[#c.towerPlatforms];finish=point(math.cos(final.angle)*final.radius,final.y+3,math.sin(final.angle)*final.radius)
        d.bounds={minX=-64,maxX=64,minY=-30,maxY=160,minZ=-64,maxZ=64}
    elseif index==13 then
        local v=choose();addFloor(0,0,0,70+v*4,68+v*4);addFloor(43,0,0,22,24)
        finish=point(38,3,0);cp(0,3,0,0);c.axis='arena';d.bounds={minX=-60,maxX=110,minY=-30,maxY=90,minZ=-60,maxZ=60}
    end
    if #c.checkpoints==0 then cp(d.spawn.x,d.spawn.y,d.spawn.z,0) end
    table.sort(c.checkpoints,function(a,b) return a.progress<b.progress end)
    if index==2 or index==3 or index==5 or index==7 then
        for n,p in ipairs(c.checkpoints) do if n>1 then addFloor(p.position.x,p.position.y-3,p.position.z,16,20) end end
    end
    c.finishPoint=finish;c.finish=volume(finish.x,finish.y,finish.z,12,10,18);c.platforms=copy(platforms)
    local arenaX,arenaY,arenaZ=finish.x+34,finish.y-3,finish.z
    if index==2 or index==8 or index==10 or index==12 then arenaX=finish.x;arenaZ=finish.z+28 end
    local arena=floor(arenaX,arenaY,arenaZ,72,64)
    d.boss={kind=bossByLevel[index],position=point(arenaX+12,arenaY+3,arenaZ),platform=arena,gateX=arenaX+31,
        exit=volume(arenaX+28,arenaY+3,arenaZ,12,10,20),pad={x=arenaX+28,y=arenaY+.09,z=arenaZ,w=12,d=20}}
    d.zones={{id=d.mode..'Course',name=d.name,objective=objectives[d.mode],gateX=finish.x,exit=copy(c.finish),platforms=platforms,enemies=enemies}}
    d.bounds.maxX=math.max(d.bounds.maxX,arena.x+arena.w/2+8);d.bounds.minX=math.min(d.bounds.minX,arena.x-arena.w/2-8)
    d.bounds.maxZ=math.max(d.bounds.maxZ,arena.z+arena.d/2+8);d.bounds.minZ=math.min(d.bounds.minZ,arena.z-arena.d/2-8)
    sourceModule('CampaignRoster').apply(d,index)
    return d
end
return Definition
