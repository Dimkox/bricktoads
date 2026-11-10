from pathlib import Path
import datetime,difflib,hashlib,json,subprocess
R=Path(__file__).resolve().parent;P=R.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,log):
 p=subprocess.run([str(x)for x in args],cwd=P,capture_output=True,text=True)
 (R/log).write_text(p.stdout+p.stderr);assert p.returncode==0,(log,p.stdout,p.stderr)
 return p.stdout
for script in ['prepare.py','build_retry.py','build_integrated.py']:
 run([P/'.tools/python-3.13.9/python.exe',R/script],script.replace('.py','-integrated.txt'))
def rows(output,prefix):
 cases=[]
 for line in output.splitlines():
  if not line.startswith(prefix):continue
  bits=line.split('\t');row={'delay':float(bits[1])}
  for i in range(2,len(bits)-1,2):
   value=bits[i+1]
   try:value=float(value)if'.'in value else int(value)
   except ValueError:pass
   row[bits[i]]=value
  cases.append(row)
 return cases
base=rows(run([P/'.tools/luau-0.745/luau.exe',R/'probe-baseline-retry.luau'],'probe-baseline-retry.txt'),'WHOLE_BASELINE_RETRY')
assert [c['result']for c in base]==['Won','Lost']
assert base[1]['attempt']==4 and base[1]['stock']==0 and base[1]['progress']==0
probe=rows(run([P/'.tools/luau-0.745/luau.exe',R/'probe-preemptive-retry.luau'],'probe-preemptive-retry.txt'),'WHOLE_PREEMPTIVE_RETRY')
integrated=rows(run([P/'.tools/luau-0.745/luau.exe',R/'probe-integrated-retry.luau'],'probe-integrated-retry.txt'),'WHOLE_INTEGRATED_RETRY')
for cases in [probe,integrated]:
 assert len(cases)==4 and all(c['result']=='Won'and c['bossLife']==0 and c['progress']==240 and c['underflows']==21 and c['bossHits']==36 for c in cases)
 assert [c['heroHits']for c in cases]==[0,4,0,0]
 assert [(c['heroLife'],c['attempt'],c['stock'],c['prepFalls'])for c in cases]==[(47,1,3,0),(31,2,2,0),(47,3,1,2),(47,3,1,2)]
 assert all(c['heroHits']<6 and c['attempt']<=4 and c['stock']>=0 for c in cases)
for a,b in zip(probe,integrated):
 for k in ['result','elapsed','bossLife','progress','phase','heroLife','attempt','stock','heroHits','acceptedPrimary','bossHits','underflows','prepFalls']:
  assert a[k]==b[k],('Integrated source differs from frozen strategy',k,a,b)
checks=[]
for name in ['probe-integrated-gates.luau','integrated-regression-dragon-146.luau','integrated-regression-guardian-10.luau','integrated-regression-stepoff-26.luau','integrated-regression-bridge-26.luau']:
 output=run([P/'.tools/luau-0.745/luau.exe',R/name],name.replace('.luau','.txt'))
 checks.append({'probe':name,'exit':0,'output':output.strip()})
compileFiles=['fixture-preemptive-retry.lua','probe-integrated-retry.luau','probe-integrated-gates.luau','actual-foot-integrated.lua']
compiled=run([P/'.tools/luau-0.745/luau-compile.exe','--null',P/'tools/qa/campaign_combat_pilot.lua',*[R/f for f in compileFiles]],'compile-integrated.txt')
assert 'SyntaxError'not in compiled and 'CompileError'not in compiled
old=(R/'baseline-combat.lua').read_text();current=(P/'tools/qa/campaign_combat_pilot.lua').read_text()
start=current.index('local slaughterEvasions = ');end=current.index('local function guardianPlan(',start)
call='    local slaughter = slaughterEvasion(c,boss,q)\n    if slaughter then clearRunUp(c);return slaughter end\n'
assert current.count(call)==1
assert (current[:start]+current[end:]).replace(call,'')==old,'Unrelated original Combat behavior changed'
(R/'integrated-combat-diff.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),current.splitlines(True),fromfile='CombatBFB',tofile='working-Combat')))
source=['src/server/gameplay/CampaignBoss.lua','src/server/gameplay/CampaignModes.lua','src/stand/server/Session.lua','src/stand/server/Combat.lua','src/server/gameplay/SourceCombat.lua','tools/qa/campaign_combat_pilot.lua','tools/qa/full_campaign_bridge.server.luau','tools/qa/campaign_early_course_pilot.lua','tools/qa/full_campaign_client_adapter.luau']
hashes={f:sha(P/f)for f in source}
assert hashes['tools/qa/campaign_combat_pilot.lua']=='4f1d67ebec451fa545eaea1e9baa58c6d1a071c7fa274845c42c5f7e41462129'
assert hashes['tools/qa/full_campaign_bridge.server.luau']=='97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'
assert hashes['tools/qa/campaign_early_course_pilot.lua']=='1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695'
prior=json.loads((R/'validation-preemptive.json').read_text())['sourceHashes']
assert all(hashes[f]==prior[f]for f in prior if f!='tools/qa/campaign_combat_pilot.lua'),'An unowned source changed during integration'
data={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'bounded_source_simulation_GREEN_normal_resource_budget_native_pending','seed':1158731273,'acceptance':'Whole source Boss victory within the original global reserve budget; fresh queued original-body gate remains RED and is not required for this acceptance','baselineCorrectRetry':base,'probeCorrectRetry':probe,'integratedSourceCases':integrated,'checks':checks,'sourceHashes':hashes,'artifactHashes':{f:sha(R/f)for f in ['fixture-preemptive.lua','fixture-preemptive-retry.lua','probe-preemptive-retry.luau','probe-integrated-retry.luau','probe-integrated-gates.luau','actual-foot-integrated.lua']},'resourcePreparation':'Two pre-test reserves consumed by valid Move/off-edge gravity/Session ConfirmedDeath(Fall); no manual Life/stock/attempt assignment','retryContract':'After normal Boss constructor, findSafe uses actual CampaignModes.respawnPosition on a finished slot1 read-only view; parity assertion requires arena.x-15,top+3,arena.z. Initial and pre-test entry remain authored course.finishPoint.','limits':['One seed, mapped ground/facing/impulses, fixed planning133ms and inputqueues0/133ms; no native Humanoid/rig/decor/friction or exact client resend replay','Fresh queued integrated case consumes one normal reserve and ends Life31/attempt2/stock2; original-body requirement remains RED','Depleted entry calibrates actual global resources through ordinary test falls, not a replay of Native24route','Local QA state only, keyed by Session/slot/hero identity/Boss/serial; no game mechanics or Core resources changed','No Studio/native or all13 campaign proof, no Git operation by child']}
(R/'validation-integrated.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps({'integrated':integrated,'checks':checks,'Combat':hashes['tools/qa/campaign_combat_pilot.lua']},indent=2))
print('PASS actual-source4 whole wins inside normal budget; retained regressions; unchanged unowned sources')
