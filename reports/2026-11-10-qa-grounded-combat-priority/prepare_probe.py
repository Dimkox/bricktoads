"""Extract the real QA foot/Nav and generate bounded source contracts."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
BUILD=ROOT/'build'
BUILD.mkdir(exist_ok=True)
baseline=subprocess.run(['git','show','331e705d837e8d92cd7c4cdafd905be150adaff6:tools/qa/full_campaign_bridge.server.luau'],cwd=ROOT,stdout=subprocess.PIPE,check=True).stdout.decode()
current=(ROOT/'tools/qa/full_campaign_bridge.server.luau').read_text()
(HERE/'baseline-bridge.lua').write_text(baseline)
nav=(ROOT/'tools/studio_level_route_driver.luau').read_text().split('\nif not game then return Nav end',1)[0]+'\nreturn Nav\n'
(BUILD/'ground_priority_nav.lua').write_text(nav)
header="""local Nav=require('./ground_priority_nav')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function floorRows(w)return w.testFloors end
local Enum={Material={Air='Air'}}
"""
hold_baseline=(HERE/'hold-baseline-bridge.lua').read_text()
for kind,source in [('base',baseline),('hold_base',hold_baseline),('current',current)]:
    source=source.replace('\r\n','\n')
    foot=source[source.index('local function foot(ctx,desired,combatPlan)'):source.index('\nlocal function plan(player)')]
    (BUILD/f'ground_priority_{kind}_foot.lua').write_text(header+foot+'\nreturn {foot=foot,nav=Nav,states=qa.plans,qa=qa}\n')
    probe=(HERE/'composition_probe_input.luau').read_text().replace('KIND',kind)
    (BUILD/f'ground_priority_{kind}_probe.luau').write_text(probe)
print('Extracted baseline/current actual foot and pure current Nav')
public=(ROOT/'reports/2026-11-10-qa-dragon-runup/public-session-dash.luau').read_text()
public=public.replace("require('../../","require('../")
public=public.replace('265.2443542480469','285.0016784667969').replace('272.2443542480469','289.0016784667969')
public=public.replace('4.974132537841797','2.9717209339141846').replace('6.632584571838379','4.630172967910767')
public=public.replace('.7214843034744263','3.399744749069214')
public=public.replace("return key=='MovementMode'and", "if key=='ActorId'then return h.actorId end;return key=='MovementMode'and")
marker="assert(plan.primary and plan.run,'Observed grounded run at reachable Dragon height selects ordinary primary')"
addition="""
local definition=require('../src/server/gameplay/CampaignDefinition').build(1,503914550)
w.testFloors={}
for _,zone in ipairs(definition.zones)do for _,f in ipairs(zone.platforms)do
 w.testFloors[#w.testFloors+1]={minX=f.x-f.w/2,maxX=f.x+f.w/2,minZ=f.z-f.d/2,maxZ=f.z+f.d/2,top=f.y+f.h/2}
end end
local Rig=require('./ground_priority_KIND_foot')
local composed=Rig.foot({slot=1,now=1.01,stageToken='public-bridge',session=s,world=w,position=w:position(1)},w:position(-1),plan)
assert(composed==plan and composed.primary and composed.run and not composed.jump,'Actual bridge preserves public ready Dash before across-gap navigation')
assert(not Rig.states['public-bridge:1'].jump,'Tactical priority does not invent a physical jump')
plan=composed
"""
assert marker in public
public=public.replace(marker,marker+addition)
for kind in ('base','hold_base','current'):
 (BUILD/f'ground_priority_{kind}_public.luau').write_text(public.replace('KIND',kind))
hold=public.replace("body.root.AssemblyLinearVelocity={X=x*speed,Y=0,Z=z*speed}","body.root.AssemblyLinearVelocity={X=x*speed,Y=0,Z=z*speed};if n>0 then body.root.CFrame={LookVector={X=x/n,Z=z/n}}end")
stop="""
function w:stop(slot)
 self.stops=(self.stops or 0)+1
 local body=self.actors[slot]
 if body and body.root then body.root.AssemblyLinearVelocity={X=0,Y=0,Z=0};body.locomotion={runRequested=false,groundRun=false,at=s.now}end
end
"""
hold=hold.replace('function w:isRunning(slot)',stop+'\nfunction w:isRunning(slot)')
hold=hold.replace("return dx>=0 and dx<=cfg.reach and math.abs(dz)<=cfg.width and math.abs(dy)<=cfg.height and{-1}or{}", "local look=self.actors[slot].root.CFrame.LookVector;local front=dx*look.X+dz*look.Z;local side=dx*(-look.Z)+dz*look.X;return front>=0 and front<=cfg.reach and math.abs(side)<=cfg.width and math.abs(dy)<=cfg.height and{-1}or{}")
after="""
local follow=Pilot.plan({slot=1,now=1.14,session=s,director=d,world=w,definition=d.route,dt=.133})
assert(s.combat[1].attack and follow.hold and not follow.primary,'Actual Pilot requests a neutral hold during the accepted windup')
local held=Rig.foot({slot=1,now=1.14,stageToken='public-bridge',session=s,world=w,position=w:position(1)},w:position(-1),follow)
assert(held.x==0 and held.z==0 and not held.jump and not held.primary and not held.run,'Follow-up bridge plan must keep accepted strike facing and stopped movement')
assert(send('Move',{x=held.x,z=held.z,run=held.run},1.14)=='OK')
"""
hold=hold.replace('d.now=1.20;s:step(1.20)',after+'\nd.now=1.20;s:step(1.20)')
for kind in ('hold_base','current'):
 (BUILD/f'ground_priority_{kind}_hold_public.luau').write_text(hold.replace('KIND',kind))
outcome=hold.replace("assert(held.x==0 and held.z==0 and not held.jump and not held.primary and not held.run,'Follow-up bridge plan must keep accepted strike facing and stopped movement')", "print('FOLLOWUP',held.x,held.z,held.run,held.jump)")
outcome=outcome.replace("assert(d.enemies[-1].rawLife==31 and d.enemies[-1].heavyReaction,'Accepted Dash at real dy1.658 preserves source47to31 heavy response')", "print('DAMAGE',d.enemies[-1].rawLife,d.enemies[-1].heavyReaction);assert(d.enemies[-1].rawLife==EXPECTED,'Expected prepared facing-boundary outcome')")
outcome=outcome.replace("print('PASS public Session ordinary Run -> Punch -> Dash at dy1.658; enemy47to31, hero47/attempt1/stock3')", "print('PASS prepared follow-up facing outcome; original hero47/attempt1/stock3')")
for kind,expected in [('hold_base',47),('current',31)]:
 (BUILD/f'ground_priority_{kind}_hold_outcome.luau').write_text(outcome.replace('KIND',kind).replace('==EXPECTED','=='+str(expected)))
