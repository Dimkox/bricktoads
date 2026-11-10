-- Nav/foot imports are generated from actual current sources by prepare_probe.py.
local d=require('../src/server/gameplay/CampaignDefinition').build(1,303307263)
local floors={}
for i=1,2 do local f=d.zones[i].platforms[1]
    floors[i]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}
end
local failures=0
for _,reverse in ipairs({false,true}) do for _,mirror in ipairs({false,true}) do
    local observed={}
    if reverse then for i=#floors,1,-1 do local f=floors[i]
        observed[#observed+1]={minX=-f.maxX,maxX=-f.minX,minZ=f.minZ,maxZ=f.maxZ,top=f.top}
    end else for i,f in ipairs(floors) do observed[i]=table.clone(f) end end
    if mirror then for _,f in ipairs(observed) do f.minZ,f.maxZ=-f.maxZ,-f.minZ end end
    local low,high=math.max(observed[1].minZ,observed[2].minZ)+2,math.min(observed[1].maxZ,observed[2].maxZ)-2
    local p={x=reverse and 4.2 or -4.2,y=3,z=mirror and high+.01 or low-.01}
    local desired={x=reverse and -20 or 20,y=3,z=mirror and high or low}
    local nav=Nav.plan(p,desired,observed,{},1,{})
    local ctx={position=p,slot=1,now=1,stageToken='seam-'..tostring(reverse)..tostring(mirror),
        session={state={heroes={[1]={actorId='same-body'}}},combat={[1]={}}},
        world={testFloors=observed,actors={[1]={model={GetAttribute=function()return nil end},
            root={AssemblyLinearVelocity={X=0,Y=0,Z=0}},humanoid={FloorMaterial='Slate',PlatformStand=false}}}}}
    local out=foot(ctx,desired,nil)
    local n=math.sqrt((nav.target.x-p.x)^2+(nav.target.z-p.z)^2)
    local ok=nav.phase=='Align adjoining support' and n>.15 and nav.target.z>low and nav.target.z<high
        and out.x==0 and out.z*(mirror and -1 or 1)>0 and not out.jump and not out.primary
    if not ok then failures+=1 end
    print(ok and 'PASS' or 'FAIL',reverse and 'reverse' or 'forward',mirror and 'upper' or 'lower',n,out.x,out.z)
end end
assert(failures==0,'Actual bridge composition deadzone failures: '..failures..'/4')
print('PASS actual bridge adjoining composition: 4 checks')
