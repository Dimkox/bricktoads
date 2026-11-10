from pathlib import Path
R=Path(__file__).resolve().parent
fixture=(R/'fixture.lua').read_text()
start=fixture.index(' local function advance(dt,now)')
end=fixture.index(' return{definition=def',start)
advance=fixture[start:end]
fixture=fixture[:start]+fixture[end:]
fixture=fixture.replace('local function new()','local function new(preDeaths)')
fixture=fixture.replace(' local s=Session.new',advance+' local s=Session.new')
needle=' local b=Boss.new(s,w,cfg,def)'
prep=''' local preSeq=0
 local function prepMove(x)
  local h=s.state.heroes[1];preSeq+=1
  return s:intent(1,{kind='Move',runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=preSeq,x=x,z=0,run=x~=0},w.now)
 end
 local prepStart=w.now;local nextMove=w.now
 while s.state.heroes[1].attempt<1+(preDeaths or 0)or s.state.heroes[1].status~='Alive'do
  assert(w.now-prepStart<30,'Bounded ordinary pre-test falls')
  if s.state.heroes[1].status=='Alive'and w.now>=nextMove then assert(prepMove(1)=='OK');nextMove=w.now+.133 end
  local now=w.now+1/120;advance(1/120,now);s:step(now)
 end
 if(preDeaths or 0)>0 then
  assert(prepMove(0)=='OK');local untilTime=w.now+2.1
  while w.now<untilTime do local now=w.now+1/120;advance(1/120,now);s:step(now)end
 end
 local base=w.now
 assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1+(preDeaths or 0)and s.state.heroes[1].respawns==3-(preDeaths or 0))
 local prepFalls=0;for _,e in ipairs(s.logs)do if e.kind=='ConfirmedDeath'and e.data.reason=='Fall'then prepFalls+=1 end end
 assert(prepFalls==(preDeaths or 0),'Every depleted reserve was earned by ordinary Move/gravity/Fall through Session')
'''
fixture=fixture.replace(needle,prep+needle).replace('base=2.1','base=base,preSeq=preSeq,preDeaths=preDeaths or 0,prepFalls=prepFalls')
(R/'fixture-preemptive.lua').write_text(fixture)
t=(R/'probe-baseline.luau').read_text().replace("require('./fixture')","require('./fixture-preemptive')")
t=t.replace('for _,delay in ipairs({0,.133})do','for _,preDeaths in ipairs({0,2})do\nfor _,delay in ipairs({0,.133})do')
t=t.replace('Fixture.new()','Fixture.new(preDeaths)').replace('local seq=0','local seq=f.preSeq;local latch=nil;local strategies={preempt=0,evade=0,safeHold=0,boundaryHold=0}')
t=t.replace("assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3,'Fresh natural Session resources')","assert(s.combat[1].rawLife==47 and s.state.heroes[1].attempt==1+preDeaths and s.state.heroes[1].respawns==3-preDeaths,'Only normal pre-test Fall/respawn changes resources')")
t=t.replace(" local function send(kind,extra,token)",''' local oldRecord=s._record
 function s:_record(kind,id,data,at)
  oldRecord(self,kind,id,data,at)
  if kind=='Hit'or kind=='ConfirmedDeath'then
   local p=w:position(1);local v=w.vel[1];local m=w.inputs[1];local a=b.attack
   print('STRATEGY_EVENT',preDeaths,delay,now-f.base,kind,data.action or data.reason or'',data.before or-1,data.after or-1,b.state,b.attackSerial,p.x,p.y,p.z,v.x,v.y,v.z,m.x,m.z,m.run,a and a.aim.x or 0,a and a.aim.z or 0)
  end
 end
 local function send(kind,extra,token)''')
replacement='''local tactical=Pilot.plan(c)
   local body,combat,p,q=w.actors[1],s.combat[1],w:position(1),w:position(-99)
   local grounded=body.humanoid.FloorMaterial~='Air'and not body.humanoid.PlatformStand
   local preempt=b.state=='Ready'and b.attackSerial%2==1 and b.readyAt-now<=.35
   local attack=b.attack
   if grounded and not combat.attack and not combat.reactionEnd and(preempt or b.state=='Tell'or b.state=='Active')then
    local ax,az,serial
    if preempt then ax,az=p.x-q.x,p.z-q.z;serial=b.attackSerial+1
    else ax,az=attack.aim.x,attack.aim.z;serial=b.attackSerial end
    local n=math.max(.001,math.sqrt(ax*ax+az*az));ax,az=ax/n,az/n
    local sx,sz=-az,ax
    local function clearance(x,z)
     local a=b.arena;local result=math.huge
     if x>0 then result=math.min(result,(a.maxX-1-p.x)/x)elseif x<0 then result=math.min(result,(a.minX+1-p.x)/x)end
     if z>0 then result=math.min(result,(a.maxZ-1-p.z)/z)elseif z<0 then result=math.min(result,(a.minZ+1-p.z)/z)end
     return math.max(0,result)
    end
    if not latch or latch.serial~=serial then
     local plus,minus=clearance(sx,sz),clearance(-sx,-sz);local sign=plus>=minus and 1 or-1
     local v=w.vel[1];local momentum=v.x*sx+v.z*sz
     if preempt and math.abs(momentum)>1 and plus>10 and minus>10 then sign=momentum>0 and 1 or-1 end
     latch={serial=serial,sign=sign,x=sx*sign,z=sz*sign}
    elseif preempt then
     if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end
     latch.x,latch.z=sx,sz
    else
     if sx*latch.x+sz*latch.z<0 then sx,sz=-sx,-sz end
     latch.x,latch.z=sx,sz
    end
    local safe=false
    if not preempt then
     local origin=attack.origin;local front=(p.x-origin.x)*ax+(p.z-origin.z)*az
     local side=math.abs((p.x-origin.x)*-az+(p.z-origin.z)*ax)
     local m=attack.move;local extent=m.reach or(m.speed*m.active*(b:_phase()==2 and 1.2 or 1))
     safe=side>(m.width or m.radius)+3 or front< -3 or front>extent+5
    end
    tactical={x=latch.x,z=latch.z,run=true,primary=false,jump=false,evasion=true}
    if safe then tactical.x,tactical.z=0,0;strategies.safeHold+=1
    elseif clearance(latch.x,latch.z)<24*(delay+.133+.025)then tactical.x,tactical.z=0,0;strategies.boundaryHold+=1
    elseif preempt then strategies.preempt+=1 else strategies.evade+=1 end
   end
   local out=Foot.foot(c,w:position(-99),tactical)'''
assert t.count('local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)')==1
t=t.replace('local tactical=Pilot.plan(c);local out=Foot.foot(c,w:position(-99),tactical)',replacement)
t=t.replace('WHOLE_BASELINE','WHOLE_PREEMPTIVE').replace("'heroHits',hits","'heroHits',hits,'preDeaths',preDeaths,'prepFalls',f.prepFalls,'preemptPlans',strategies.preempt,'evadePlans',strategies.evade,'safeHolds',strategies.safeHold,'boundaryHolds',strategies.boundaryHold")
t+='\nend\n'
(R/'probe-preemptive.luau').write_text(t)
print('Built one probe-only strategy with normal pre-test Fall resource preparation')
