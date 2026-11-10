from pathlib import Path
import datetime,hashlib,json,subprocess
R=Path(__file__).resolve().parent;P=R.parents[1]
def run(cmd,log):
 p=subprocess.run([str(x)for x in cmd],cwd=P,capture_output=True,text=True)
 (R/log).write_text(p.stdout+p.stderr);assert p.returncode==0,(log,p.stdout,p.stderr)
 return p.stdout
run([P/'.tools/python-3.13.9/python.exe',R/'build_preemptive.py'],'build-preemptive.txt')
output=run([P/'.tools/luau-0.745/luau.exe',R/'probe-preemptive.luau'],'probe-preemptive.txt')
cases=[];events=[]
for line in output.splitlines():
 if line.startswith('STRATEGY_EVENT'):events.append(line.split('\t')[1:])
 if not line.startswith('WHOLE_PREEMPTIVE'):continue
 bits=line.split('\t');row={'delay':float(bits[1])}
 for i in range(2,len(bits)-1,2):
  value=bits[i+1]
  try:value=float(value)if'.'in value else int(value)
  except ValueError:pass
  row[bits[i]]=value
 cases.append(row)
assert len(cases)==4 and all(c['result']=='Won'and c['progress']==240 and c['underflows']==21 for c in cases)
assert [c['heroHits']for c in cases]==[0,3,0,0]
assert [(c['attempt'],c['stock'],c['prepFalls'])for c in cases]==[(1,3,0),(2,2,0),(3,1,2),(3,1,2)]
compiled=run([P/'.tools/luau-0.745/luau-compile.exe','--null',R/'fixture-preemptive.lua',R/'probe-preemptive.luau'],'compile-preemptive.txt')
assert 'SyntaxError'not in compiled and 'CompileError'not in compiled
source=['src/server/gameplay/CampaignBoss.lua','src/stand/server/Session.lua','src/stand/server/Combat.lua','src/server/gameplay/SourceCombat.lua','tools/qa/campaign_combat_pilot.lua','tools/qa/full_campaign_bridge.server.luau','tools/qa/campaign_early_course_pilot.lua','tools/qa/full_campaign_client_adapter.luau']
hashes={f:hashlib.sha256((P/f).read_bytes()).hexdigest()for f in source}
assert hashes['tools/qa/campaign_combat_pilot.lua']=='bfb17590f568b6e9c1d30ccddee00b9aa5a152d6289b60651df544661e4f0a38'
assert hashes['tools/qa/full_campaign_bridge.server.luau']=='97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'
assert hashes['tools/qa/campaign_early_course_pilot.lua']=='1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695'
data={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'probe_frozen_four_whole_boss_Won_fresh_queued_original_body_RED_no_source_patch','seed':1158731273,'cases':cases,'eventColumns':['preDeaths','queue','elapsed','kind','actionOrReason','before','after','bossState','attackSerial','heroX','heroY','heroZ','velocityX','velocityY','velocityZ','acceptedX','acceptedZ','acceptedRun','attackAimX','attackAimZ'],'events':events,'sourceHashes':hashes,'probeHashes':{f:hashlib.sha256((R/f).read_bytes()).hexdigest()for f in ['build_preemptive.py','fixture-preemptive.lua','probe-preemptive.luau']},'limits':['One combined probe-only strategy; no accepted QA source change','Preemptive motion cannot create offset against future retargeted aim; it establishes already accepted perpendicular momentum','Fresh queued case used one normal reserve: original-body gate remains RED','Two pre-test falls earned through ordinary Move/gravity/hazard/Session; no resource writes','Initial CommitSpawn has no shield; initial2.1s only advances time; post-Fall shield expires normally','Retry findSafe maps to authored course-finish entry, not production finished-mode retry position; affects fresh queued retry result','Mapped Humanoid movement/facing/impulses and fixed queue; native acceleration/rig collision/friction/transport not replayed','Not native or all-campaign acceptance']}
(R/'validation-preemptive.json').write_text(json.dumps(data,indent=2)+'\n')
for c in cases:print(c)
print('PASS four whole-source-boss outcomes; original-body queued negative preserved; sources unchanged')
