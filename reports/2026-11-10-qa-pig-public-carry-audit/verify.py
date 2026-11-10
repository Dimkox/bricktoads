from pathlib import Path
import hashlib,json,subprocess,datetime,sys
R=Path(__file__).resolve().parent;P=R.parents[1]
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
original=json.loads((R/'validation.json').read_text())
restored={'tools/qa/campaign_combat_pilot.lua':'bfb17590f568b6e9c1d30ccddee00b9aa5a152d6289b60651df544661e4f0a38','tools/qa/full_campaign_bridge.server.luau':'97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'}
assert sha(R/'baseline-combat-bfb.lua')==restored['tools/qa/campaign_combat_pilot.lua']
bridge=R.parent/'2026-11-10-qa-pig-spacing-interior/baseline-bridge.lua'
assert sha(bridge)==restored['tools/qa/full_campaign_bridge.server.luau']
if '--check-working-baseline' in sys.argv:
 assert all(sha(P/f)==value for f,value in restored.items()),'Working QA has moved beyond the historical restored baseline'
jobs=[(R/'probe-public-contract.luau','public-contract.txt',0),(R/'probe-policy-red.luau','policy-red.txt',1),(P/'tests/run_enemy_carry.luau','carry-24.txt',0)]
checks=[]
for path,log,expected in jobs:
 r=subprocess.run([str(P/'.tools/luau-0.745/luau.exe'),str(path)],cwd=P,capture_output=True,text=True)
 (R/log).write_text(r.stdout+r.stderr);assert r.returncode==expected,(log,r.returncode)
 checks.append({'probe':str(path.relative_to(P)),'log':log,'exit':r.returncode,'expectedExit':expected})
r=subprocess.run([str(P/'.tools/luau-0.745/luau-compile.exe'),'--null',str(R/'fixture.lua'),str(R/'probe-public-contract.luau'),str(R/'probe-policy-red.luau')],cwd=P,capture_output=True,text=True)
(R/'compile.txt').write_text(r.stdout+r.stderr);assert r.returncode==0
sources=['tools/qa/campaign_combat_pilot.lua','tools/qa/full_campaign_bridge.server.luau','src/server/gameplay/EnemyCarry.lua','src/server/gameplay/LevelDirector.lua','src/stand/server/Session.lua','src/stand/server/Combat.lua']
data={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'read_only_public_control_contract_proven_policy_red_retained','scope':'Prepared actual Session/Director/EnemyCarry/SourceCombat, no production or QA source edit','checks':checks,'compileExit':r.returncode,'sourceHashes':{f:sha(P/f)for f in sources},'results':{'raw15':{'cycles':3,'perCycle':[15,11,15],'enemyDied':False,'netDamage':0},'raw3':{'publicPunches':2,'enemyDied':True,'heroLife':47,'heroAttempt':1,'heroStock':3},'originalPilotRaw3':{'grabAvailable':True,'primary':False,'evasion':True}},'limits':['Static prepared same-floor corner/facing; numeric eligibility/physical carry/release adapter, no native ray/rig/throw flight parity','Pig physical throw fall is not simulated or used for progress','No multiplayer/latency/fullfight acceptance','Earlier rejected7inset closed-loop omitted EnemyCarry dependency; not a carry availability test','No source edits, Studio calls or Git actions']}
data['atFreeze']=original.get('atFreeze',original['at'])
data['atFreezeSourceHashes']=original.get('atFreezeSourceHashes',original['sourceHashes'])
data['workingQAHashes']={f:sha(P/f)for f in restored}
data['sourceHashes'].update(restored)
data['sourceBindings']={'tools/qa/campaign_combat_pilot.lua':'./baseline-combat-bfb.lua','tools/qa/full_campaign_bridge.server.luau':'../2026-11-10-qa-pig-spacing-interior/baseline-bridge.lua'}
(R/'validation.json').write_text(json.dumps(data,indent=2)+'\n');print('PASS pinned public carry contracts, expected BFB policy RED, existing24 and compile; at-freeze hashes retained')
