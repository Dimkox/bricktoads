from pathlib import Path
R=Path(__file__).resolve().parent
t=(R/'probe-baseline.luau').read_text()
t=t.replace("local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)","""local tactical=Pilot.plan(c)
   if tactical.evasion and w.actors[1].humanoid.FloorMaterial~='Air'and not w.actors[1].humanoid.PlatformStand then
    tactical=table.clone(tactical);tactical.run=true
   end
   local out=Foot.foot(c,w:position(-99),tactical)""")
t=t.replace('WHOLE_BASELINE','WHOLE_RUNNING_EVADE')
(R/'probe-running-evade.luau').write_text(t)
base=(R/'probe-baseline.luau').read_text()
replacement="""local tactical=Pilot.plan(c)
   local combat=s.combat[1];local p,q=w:position(1),w:position(-99)
   local grounded=w.actors[1].humanoid.FloorMaterial~='Air'and not w.actors[1].humanoid.PlatformStand
   if grounded and not combat.attack and not combat.reactionEnd and (combat.nextAttack or 0)>now
    and (b.state=='Reaction'or b.state=='Recovery'or b.state=='Ready')then
    local dx,dz=p.x-q.x,p.z-q.z;local range=math.sqrt(dx*dx+dz*dz);local n=math.max(.001,range)
    local target={x=math.clamp(q.x+dx/n*10,b.arena.minX+1,b.arena.maxX-1),z=math.clamp(q.z+dz/n*10,b.arena.minZ+1,b.arena.maxZ-1)}
    dx,dz=target.x-p.x,target.z-p.z;n=math.max(1,math.sqrt(dx*dx+dz*dz))
    tactical={x=dx/n,z=dz/n,run=true,primary=false,jump=false,evasion=true}
   elseif grounded and tactical.evasion then tactical=table.clone(tactical);tactical.run=true end
   local out=Foot.foot(c,w:position(-99),tactical)"""
base=base.replace("local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)",replacement).replace('WHOLE_BASELINE','WHOLE_COOLDOWN_RETREAT')
(R/'probe-cooldown-retreat.luau').write_text(base)
