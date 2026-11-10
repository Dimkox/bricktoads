from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[2]
(root/'build').mkdir(exist_ok=True)
source=(root/'tools/qa/full_campaign_bridge.server.luau').read_text(encoding='utf-8')
start=source.index('local function foot(ctx,desired,combatPlan)')
end=source.index('\nlocal function plan(player)',start)
foot=source[start:end]
header="""local Nav=require('../tools/studio_level_route_driver')
local qa={plans={}}
local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end
local function point(x,y,z)return{x=x,y=y,z=z}end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local Enum={Material={Air='Air'}}
local function floorRows(world)return world.testFloors end
"""
(root/'build/mounted_bridge_foot.lua').write_text(header+foot+'\nreturn foot\n')
baseline=subprocess.run(['git','show','df98106:tools/qa/full_campaign_bridge.server.luau'],cwd=root,check=True,stdout=subprocess.PIPE,text=True,encoding='utf-8').stdout
bs=baseline.index('local function foot(ctx,desired,combatPlan)')
be=baseline.index('\nlocal function plan(player)',bs)
(root/'build/mounted_bridge_baseline_foot.lua').write_text(header+baseline[bs:be]+'\nreturn foot\n')
test=(Path(__file__).resolve().parent/'mounted_bridge_probe_input.luau').read_text(encoding='utf-8')
(root/'build/test_mounted_bridge.luau').write_text(test,encoding='utf-8')
(root/'build/test_mounted_bridge_baseline.luau').write_text(test.replace("require('./mounted_bridge_foot')","require('./mounted_bridge_baseline_foot')"))
print('Extracted actual QA bridge foot function')
spec=(root/'tests/gameplay/DragonFlight.spec.lua').read_text(encoding='utf-8')
fstart=spec.index('    local function fixture()')
fend=spec.index("    test('runtime installs",fstart)
fixture=spec[fstart:fend]
imports="""local Flight=require('../src/server/gameplay/DragonFlight')
local Director=require('../src/server/gameplay/LevelDirector')
local Session=require('../src/stand/server/Session')
local Core=require('../src/server/RunLifecycle')
local Combat=require('../src/stand/server/Combat')
local Config=require('../src/server/gameplay/GameConfig')(require('../src/stand/server/Config'),require('../src/server/gameplay/LevelDefinition'))
local FakeWorld=require('../tests/stand/FakeWorld')
local SourceCombat=require('../src/server/gameplay/SourceCombat')
local foot=require('./mounted_bridge_foot')
"""
contract="""
-- Use the existing flight suite's prepared canonical heavy-hit mount fixture.
-- The behavior under test is the actual bridge plan -> public Session intents;
-- no driver assignment to actor poses, health, stocks or Flight mode is used.
local d,s,w,tick,intent,mount=fixture();mount()
local hero=s.state.heroes[1];local actorId,attempt,stock,life=hero.actorId,hero.attempt,hero.respawns,s.combat[1].rawLife
local floor={minX=-10,maxX=10,minZ=-10,maxZ=10,top=0}
local ctx={position=w:position(1),slot=1,now=1.2,stageToken='session-mount-contract',session=s,
 world={testFloors={floor},actors={[1]={model={GetAttribute=function(_,name)assert(name=='DragonLink');return w.links[1] and w.links[1].mode end},
  root={AssemblyLinearVelocity={X=0,Y=0,Z=0}},humanoid={PlatformStand=true,FloorMaterial='Slate'}}}}}
local plan=foot(ctx,{x=20,y=3,z=0},nil)
assert(plan.jump and not plan.primary and plan.x==0 and plan.z==0,'Actual mounted bridge plan must request a neutral public Jump')
local function send(kind,extra,now)
 local h=s.state.heroes[1];local packet={kind=kind,runId=s.state.runId,actorId=h.actorId,attempt=h.attempt,
  levelEpoch=s.state.levelEpoch,connectionEpoch=h.connectionEpoch,seq=(s.lastSeq[1] or 0)+1}
 for k,v in pairs(extra or{})do packet[k]=v end;return s:intent(1,packet,now)
end
assert(send('Move',{x=plan.x,z=plan.z,run=plan.run},1.2)=='OK')
assert(send('Jump',nil,1.2)=='OK' and not w.links[1] and not d.dragons.heroes[1],'Only Session normal Jump releases the real flight link')
assert(hero.actorId==actorId and hero.attempt==attempt and hero.respawns==stock and s.combat[1].rawLife==life,'Dismount preserves actor identity and resources')
local releases=0;for _,event in ipairs(s.logs)do if event.kind=='DragonReleased'then releases+=1;assert(event.data.reason=='Dismount')end end
assert(releases==1,'One ordinary dismount event')
local after=foot(ctx,{x=20,y=3,z=0},nil)
assert(not after.jump,'Cleared link returns to ordinary navigation without repeated dismount')
print('Actual bridge -> public Session Move/Jump contract GREEN; same actor/resources, one dismount')
"""
(root/'build/test_mounted_bridge_session.luau').write_text(imports+fixture+contract)
