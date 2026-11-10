local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Baseline=require('./combat-baseline-c1')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),Definition.build(1,338231076))
local function freeze(t,seen)
    if type(t)~='table' or table.isfrozen(t) then return t end
    seen=seen or{};if seen[t]then return t end;seen[t]=true
    for _,v in pairs(t)do freeze(v,seen)end
    return table.freeze(t)
end
local function fixture(dy,kind)
    local p={x=271.6141052246094,y=4.974132537841797,z=.5977640748023987}
    local q={x=272.2443542480469,y=p.y+(dy or 1.658452033996582),z=.7214843034744263}
    local positions={[1]=p,[-10]=q}
    local dx,dz=q.x-p.x,q.z-p.z;local n=math.sqrt(dx*dx+dz*dz)
    local c={slot=1,now=100,dt=.132,definition=Definition.build(1,338231076),
        session={state={status='Active',runId='dragon-runup',levelEpoch=1,heroes={[1]={status='Alive',connected=true,actorId='hero1',attempt=1,respawns=3}}},
            config=Config,combat={[1]={rawLife=47,nextAttack=0}}},
        director={enemies={[-10]={kind=kind or 'Dragon',rawLife=47,actorId='dragon10'}}},
        world={actors={[1]={root={Parent=true,Anchored=false,CFrame={LookVector={X=dx/n,Z=dz/n}},AssemblyLinearVelocity={X=6.112136363983154,Y=-.08412782847881317,Z=1.6921414136886597}},
            locomotion={runRequested=false,groundRun=false,at=100},model={GetAttribute=function()return'Walk'end},
            humanoid={PlatformStand=false,Health=100,FloorMaterial='Slate'}}},position=function(_,id)return positions[id]end}}
    return c,p,q,c.definition.zones[4].platforms[2]
end
local count=0
local function check(v,message)assert(v,message);count+=1 end
local function eligible(dy)
    local c,p,q,f=fixture(dy);freeze(c)
    local out=Pilot.plan(c)
    check(out.evasion==true and not out.primary and not out.jump and not out.run,'Grounded hero below reachable ordinary Dragon must plan a safe normal run-up backoff')
    check(out.x*(q.x-p.x)+out.z*(q.z-p.z)<=0,'Initial run-up movement must not close into the Dragon')
    local ax,az=p.x-q.x,p.z-q.z;local along=ax*out.x+az*out.z
    local travel=-along+math.sqrt(along*along-ax*ax-az*az+144)
    local x,z=p.x+out.x*travel,p.z+out.z*travel
    check(x>=f.x-f.w/2+3 and x<=f.x+f.w/2-3 and z>=f.z-f.d/2+3 and z<=f.z+f.d/2-3,'The backoff destination remains on the same authored floor with strict3stud inset')
    check(c.session.state.heroes[1].respawns==3 and c.session.combat[1].rawLife==47,'Frozen original resources stay unchanged')
end
eligible(1.658452033996582)
for _,dy in ipairs({.9,1.5,2,3.7})do eligible(dy)end
local function sameAsBaseline(alter)
    local a=fixture();local b=fixture();alter(a);alter(b);freeze(a);freeze(b)
    local x,y=Pilot.plan(a),Baseline.plan(b)
    for key,v in pairs(x)do check(y[key]==v,'Unrelated or unsafe observation must preserve baseline '..key)end
    for key,v in pairs(y)do check(x[key]==v,'No extra changed baseline field '..key)end
end
sameAsBaseline(function(c)c.director.enemies[-10].kind='Walker'end)
sameAsBaseline(function(c)c.director.enemies[-10].kind='Pig'end)
sameAsBaseline(function(c)local old=c.world.position;c.world.position=function(w,id)local p=old(w,id);if id==-10 then return{x=p.x,y=9,z=p.z}end;return p end end)
sameAsBaseline(function(c)c.director.enemies[-10].reactionUntil=101 end)
sameAsBaseline(function(c)c.world.actors[1].root.Anchored=true end)
sameAsBaseline(function(c)c.world.actors[1].humanoid.PlatformStand=true end)
sameAsBaseline(function(c)c.world.actors[1].humanoid.FloorMaterial='Air'end)
sameAsBaseline(function(c)c.world.actors[1].root.AssemblyLinearVelocity.Y=4 end)
sameAsBaseline(function(c)c.definition.zones={}end)
print('PASS Dragon run-up height contract '..count)
