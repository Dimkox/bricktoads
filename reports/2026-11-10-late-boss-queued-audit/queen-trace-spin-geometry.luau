-- Read-only source geometry check; no accepted attack/hit/phase is fabricated.
local f=require('./queen-fixture').new(0)
local b=f.boss
local origin=table.clone(f.world:position(-99))
local a={origin=origin,tellAt=f.base,move={orbit=8,active=1.8}}
local maximum=0
for i=0,2400 do
 local p=b:_motion(a,a.tellAt+a.move.active*i/2400)
 local distance=math.sqrt((p.x-origin.x)^2+(p.z-origin.z)^2)
 maximum=math.max(maximum,distance)
end
local atPi=b:_motion(a,a.tellAt+a.move.active/4)
print('ACTUAL_SOURCE_SPIN_MAX_CENTRE_DISTANCE',maximum,'analytic',math.sqrt(256/3),'plusHitRadius',maximum+3.2)
print('ACTUAL_SOURCE_SPIN_PI_OFFSET',atPi.x-origin.x,atPi.z-origin.z,'distanceFromHeroAtZ14.2',14.2-(atPi.z-origin.z))
assert(maximum+3.2<14.2,'Source ellipse plus collision radius stays inside14.2 refuge')
assert(b.state=='Ready'and b.enemies[-99].rawLife==15 and b.enemies[-99].progress==0)
