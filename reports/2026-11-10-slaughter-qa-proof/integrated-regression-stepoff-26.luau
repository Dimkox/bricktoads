-- Frozen observations only: no Session intents, physics or source-state writes.
local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local function freeze(v,seen)
    if type(v)~='table' then return v end
    seen=seen or{};if seen[v]then return v end;seen[v]=true
    for _,item in pairs(v)do freeze(item,seen)end
    return table.freeze(v)
end
local function context()
    local p={x=155.970703,y=8.025629,z=-23.759357}
    local q={x=155.970993,y=2.999987,z=-23.759354}
    local definition=Definition.build(1,388791054)
    local floor=definition.zones[3].platforms[1]
    local positions={[1]=p,[-8]=q}
    local c={slot=1,now=100,dt=.1,definition=definition,
        session={state={status='Active',runId='native11-stepoff',levelEpoch=1,heroes={[1]={status='Alive',connected=true,actorId='hero1',attempt=3}}},
            config={Attacks={Punch={reach=6,height=4,windup=.1}}},combat={[1]={rawLife=39,nextAttack=0}}},
        director={enemies={[-8]={kind='Pig',rawLife=15,actorId='pig8'}}},
        world={actors={[1]={root={Parent=true,Anchored=false,CFrame={LookVector={X=1,Z=0}}},
            humanoid={PlatformStand=false,Health=100,FloorMaterial='SmoothPlastic'}}},position=function(_,id)return positions[id]end}}
    return c,p,q,floor
end
local c,p,q,f=context();freeze(c)
local plan=Pilot.plan(c)
assert(plan.evasion==true,'Native11 real seeded floor/Pig-head pose must produce an ordinary step-off')
assert(plan.primary==false and plan.jump==false and plan.run==false,'Step-off must use ordinary walking only')
assert(math.sqrt(plan.x^2+plan.z^2)>.99,'Step-off must make meaningful progress')
-- Recover the selected seven-stud candidate from its observed unit steering.
local rx,rz=p.x-q.x,p.z-q.z;local along=rx*plan.x+rz*plan.z
local travel=-along+math.sqrt(along*along-rx*rx-rz*rz+49)
local goal={x=p.x+plan.x*travel,z=p.z+plan.z*travel}
local dx,dz=goal.x-p.x,goal.z-p.z
assert(goal.x>=f.x-f.w/2+3 and goal.x<=f.x+f.w/2-3 and goal.z>=f.z-f.d/2+3 and goal.z<=f.z+f.d/2-3,'Destination retains strict three-stud margins')
assert(dx*(q.x-p.x)+dz*(q.z-p.z)<=0,'Initial step-off must move away from enemy')
local function safeStep(ctx,hero,enemy,floor)
    local out=Pilot.plan(ctx)
    assert(out.evasion==true,'Eligible supported stack must step off')
    assert(out.primary==false and out.jump==false and out.run==false,'Only normal walking is allowed')
    -- Match the steering against an exact seven-stud candidate. This avoids
    -- adding error by projecting a unit vector back onto a boundary endpoint.
    local axes={{1,0},{-1,0},{0,1},{0,-1}}
    for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do axes[#axes+1]={sx/math.sqrt(2),sz/math.sqrt(2)}end end
    for step=1,5 do for _,sign in ipairs({-1,1})do
        axes[#axes+1]={math.cos(step*math.pi/12),math.sin(step*math.pi/12)*sign}
    end end
    local safe=false
    for _,axis in ipairs(axes)do
        local destination={x=enemy.x+axis[1]*7,z=enemy.z+axis[2]*7}
        local dx,dz=destination.x-hero.x,destination.z-hero.z;local n=math.sqrt(dx*dx+dz*dz)
        if math.abs(out.x-dx/n)<1e-8 and math.abs(out.z-dz/n)<1e-8
            and dx*(enemy.x-hero.x)+dz*(enemy.z-hero.z)<=0 then
            -- Shared section boundaries may belong to two actual supports.
            for _,zone in ipairs(ctx.definition.zones)do for _,support in ipairs(zone.platforms)do
                local minX,maxX=support.x-support.w/2,support.x+support.w/2
                local minZ,maxZ=support.z-support.d/2,support.z+support.d/2
                if hero.x>=minX-.001 and hero.x<=maxX+.001 and hero.z>=minZ-.001 and hero.z<=maxZ+.001
                    and enemy.x>=minX-.001 and enemy.x<=maxX+.001 and enemy.z>=minZ-.001 and enemy.z<=maxZ+.001
                    and destination.x>=minX+3 and destination.x<=maxX-3 and destination.z>=minZ+3 and destination.z<=maxZ-3 then safe=true end
            end end
        end
    end
    assert(safe,'Every step must match a strict safe candidate with outward initial direction')
end
local cases=1
for _,axis in ipairs({'x','z'})do for _,sign in ipairs({-1,1})do
    c,p,q,f=context();local lo=axis=='x'and f.x-f.w/2 or f.z-f.d/2
    local hi=axis=='x'and f.x+f.w/2 or f.z+f.d/2
    p.x,q.x=f.x,f.x;p.z,q.z=f.z,f.z
    q[axis]=sign<0 and lo or hi;p[axis]=q[axis]+sign*.0000038
    -- Preserve the observed pose's larger tangential separation, so moving
    -- to an authored-safe tangent also satisfies the unchanged away gate.
    local tangent=axis=='x'and'z'or'x';p[tangent]=q[tangent]-.00029
    freeze(c);safeStep(c,p,q,f)
    cases+=1
end end
for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
    c,p,q,f=context()
    q.x=f.x+sx*(f.w/2-2.24);q.z=f.z+sz*(f.d/2-2.24)
    p.x=q.x-sx*.00029;p.z=q.z-sz*.000003
    freeze(c);safeStep(c,p,q,f);cases+=1
end end
c,p,q,f=context();p.x=q.x;p.z=q.z;freeze(c);safeStep(c,p,q,f);cases+=1
for _,alter in ipairs({
    function(ctx,hero,enemy,floor)enemy.z=floor.z-floor.d/2;hero.z=enemy.z-.002 end,
    function(ctx,hero,enemy,floor)enemy.z=floor.z-floor.d/2-.002;hero.z=enemy.z end,
    function(ctx)ctx.world.actors[1].root.Anchored=true end,
    function(ctx)ctx.world.actors[1].humanoid.FloorMaterial='Air'end,
    function(ctx)ctx.session.combat[1].attack={}end,
    function(ctx)ctx.modes={mode='Tubes',actors={[1]={medium='Dry'}}}end,
    function(ctx)ctx.session.combat[1].reactionEnd=101 end,
    function(ctx)ctx.world.actors[1].humanoid.PlatformStand=true end,
    function(ctx)ctx.world.actors[1].humanoid.Health=0 end,
    function(ctx)ctx.world.actors[1].root.Parent=false end,
    function(ctx)ctx.director.enemies[-8].boss=true end,
    function(ctx)ctx.director.enemies[-8].dead=true end,
    function(ctx,hero,enemy)ctx.director.enemies[-8].kind='Dragon';enemy.y=8;hero.y=13 end,
    function(ctx,hero,enemy)ctx.director.enemies[-8].kind='Walker';enemy.y=8;hero.y=13 end,
    function(ctx,hero,enemy)hero.y=16 end,
    function(ctx)ctx.director.carry={pendingBySlot={[1]=true}}end,
})do
    c,p,q,f=context();alter(c,p,q,f);freeze(c);plan=Pilot.plan(c)
    assert(plan.evasion~=true,'Outside tolerance or ineligible actors must not receive step-off')
    cases+=1
end
print('Combat step-off boundary frozen probes GREEN',cases)
