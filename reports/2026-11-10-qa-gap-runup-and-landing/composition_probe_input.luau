local Rig=require('./gap_review_KIND_foot')
local function freeze(t,seen)
    if type(t)~='table' or table.isfrozen(t)then return t end
    seen=seen or{};if seen[t]then return t end;seen[t]=true
    for _,v in pairs(t)do freeze(v,seen)end;return table.freeze(t)
end
local floors={{minX=4,maxX=48,minZ=-19,maxZ=19,top=0},
    {minX=53,maxX=124,minZ=-19,maxZ=19,top=0}}
local function context(p,vx,vy,vz,rows,key)
    return freeze({slot=1,position=p,now=1.6,stageToken=key,
        world={testFloors=rows,actors={[1]={model={GetAttribute=function()return nil end},
            locomotion={runRequested=false},root={AssemblyLinearVelocity={X=vx,Y=vy,Z=vz}},
            humanoid={FloorMaterial='Slate',PlatformStand=false}}}},
        session={state={heroes={[1]={actorId='original'}}},combat={[1]={}}}})
end
local failed=0
local function check(value,message)
    print(value and 'PASS' or 'FAIL',message);if not value then failed+=1 end
end
local ctx=context({x=55.302,y=3,z=-3.923},-14.93,0,-5.77,floors,'runup')
local p=Rig.foot(ctx,{x=45,y=3,z=-4.14},nil)
check(p.x>0 and p.run and not p.jump and not p.primary,
    'Actual slow reverse approach requests inward ordinary Move before a qualified running Jump')
local pads={{minX=224,maxX=258,minZ=-9,maxZ=9,top=0},
    {minX=262,maxX=289,minZ=-3,maxZ=15,top=2}}
for index,observed in ipairs({{x=267.798,y=5.897,z=.601},{x=267.951,y=9.328,z=.567}})do
    local state={actorId='original'}
    Rig.nav.plan({x=255,y=3,z=.6},{x=280,y=5,z=.6},pads,state,1,{grounded=true,jumpLead=3.2})
    local key='landing'..index;Rig.states[key..':1']=state
    local c=context(observed,24,25,0,pads,key)
    local before=state.jump
    local out=Rig.foot(c,{x=280,y=5,z=.6},nil)
    check(out.x==0 and out.z==0 and not out.jump and not out.primary and state.jump==before,
        'Actual high destination-side observation holds instead of reversing toward the gap')
end
assert(failed==0,'QA gap composition failures: '..failed)
print('QA gap composition GREEN3')
