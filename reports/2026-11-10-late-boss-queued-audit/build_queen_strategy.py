from pathlib import Path

HERE = Path(__file__).resolve().parent
text = (HERE / 'queen-probe-current.luau').read_text()
text = text.replace('local rejects={}', 'local rejects={};local latch=nil')
needle = 'local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)'
replacement = '''local tactical=Pilot.plan(c)
   local p,q=w:position(1),w:position(-99);local body=w.actors[1];local combat=s.combat[1]
   local preempt=b.state=='Ready'and b.readyAt-now<=.35
   local active=b.state=='Tell'or b.state=='Active'
   if not combat.attack and not combat.reactionEnd and body.humanoid.FloorMaterial~='Air'and not body.humanoid.PlatformStand and(preempt or active)then
    local a=b.attack;local name=preempt and(b.attackSerial%2==0 and'Sweep'or'Spin')or a.name
    local serial=preempt and b.attackSerial+1 or b.attackSerial
    local origin=preempt and q or a.origin
    local identity=s.state.heroes[1].actorId..':'..serial..':'..name
    local function unit(x,z)local n=math.max(.001,math.sqrt(x*x+z*z));return x/n,z/n end
    local function available(o,x,z)
     local v=math.huge;local r=b.arena
     if x>0 then v=math.min(v,(r.maxX-1-o.x)/x)elseif x<0 then v=math.min(v,(r.minX+1-o.x)/x)end
     if z>0 then v=math.min(v,(r.maxZ-1-o.z)/z)elseif z<0 then v=math.min(v,(r.minZ+1-o.z)/z)end
     return math.max(0,v)
    end
    local safe=false;local x,z=0,0
    if name=='Sweep'then
     local ax,az;if preempt then ax,az=unit(p.x-q.x,p.z-q.z)else ax,az=a.aim.x,a.aim.z end
     local sx,sz=-az,ax
     if not latch or latch.identity~=identity then
      local plus,minus=available(p,sx,sz),available(p,-sx,-sz);local sign=plus>=minus and 1 or-1
      local v=w.vel[1];local momentum=v.x*sx+v.z*sz
      if preempt and math.abs(momentum)>1 and plus>10 and minus>10 then sign=momentum>0 and 1 or-1 end
      latch={identity=identity,x=sx*sign,z=sz*sign}
     else if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end;latch.x,latch.z=sx,sz end
     if not preempt then
      local front=(p.x-origin.x)*ax+(p.z-origin.z)*az
      local side=math.abs((p.x-origin.x)*az-(p.z-origin.z)*ax)
      safe=side>7 or front< -3 or front>13
     end
     if not safe and available(p,latch.x,latch.z)>=24*(delay+.133+.025)then x,z=latch.x,latch.z end
    else
     if not latch or latch.identity~=identity then
      local ax,az=unit(p.x-origin.x,p.z-origin.z);local best=math.huge
      for _,axis in ipairs({{ax,az},{1,0},{-1,0},{0,1},{0,-1}})do
       if available(origin,axis[1],axis[2])>=16 then
        local gx,gz=origin.x+axis[1]*16,origin.z+axis[2]*16
        local cost=(gx-p.x)^2+(gz-p.z)^2
        if cost<best then best=cost;latch={identity=identity,x=axis[1],z=axis[2]}end
       end
      end
     end
     local distance=math.sqrt((p.x-origin.x)^2+(p.z-origin.z)^2)
     safe=distance>=14.2
     if not safe and latch and latch.identity==identity then
      x,z=unit(origin.x+latch.x*16-p.x,origin.z+latch.z*16-p.z)
      if available(p,x,z)<24*(delay+.133+.025)then x,z=0,0 end
     end
    end
    tactical={x=x,z=z,run=true,primary=false,jump=false,evasion=true}
   end
   local out=Foot.foot(c,w:position(-99),tactical)'''
assert text.count(needle) == 1
text = text.replace(needle, replacement).replace('QUEEN13_BASELINE', 'QUEEN13_ONE_STRATEGY')
(HERE / 'queen-one-strategy.luau').write_text(text)
print('Built ONE probe-only Ready-momentum/Sweep-side/Spin-origin-hold strategy; source remains unchanged')
