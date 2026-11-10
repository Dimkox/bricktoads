from pathlib import Path
import datetime,hashlib,json,subprocess
R=Path(__file__).resolve().parent;P=R.parents[1]
def run(cmd,log):
 p=subprocess.run([str(x)for x in cmd],cwd=P,capture_output=True,text=True)
 (R/log).write_text(p.stdout+p.stderr);assert p.returncode==0,(log,p.stdout,p.stderr)
 return p.stdout
run([P/'.tools/python-3.13.9/python.exe',R/'prepare.py'],'prepare.txt')
run([P/'.tools/python-3.13.9/python.exe',R/'build_strategy.py'],'build-strategy.txt')
cases=[]
for probe,expected in [('probe-baseline.luau',['Won','Lost']),('probe-running-evade.luau',['Won','Lost']),('probe-cooldown-retreat.luau',['Won','Lost'])]:
 output=run([P/'.tools/luau-0.745/luau.exe',R/probe],probe.replace('.luau','.txt'))
 rows=[]
 for line in output.splitlines():
  if not line.startswith('WHOLE_'):continue
  bits=[x.strip()for x in line.split('\t')]
  row={'probe':probe,'delay':float(bits[1])}
  for i in range(2,len(bits)-1,2):
   key=bits[i];value=bits[i+1]
   try:value=float(value)if'.'in value else int(value)
   except ValueError:pass
   row[key]=value
  rows.append(row)
 assert [x['result']for x in rows]==expected
 assert rows[0]['progress']==240 and rows[0]['underflows']==21,'Full natural source progress requirement'
 assert rows[1]['attempt']==4 and rows[1]['stock']==0 and rows[1]['progress']==0,'Delayed policy exhausts actual global reserves'
 cases+=rows
compiled=run([P/'.tools/luau-0.745/luau-compile.exe','--null',R/'fixture.lua',R/'actual-foot.lua',R/'probe-baseline.luau',R/'probe-running-evade.luau',R/'probe-cooldown-retreat.luau'],'compile.txt')
assert 'SyntaxError'not in compiled and 'CompileError'not in compiled
source=['src/server/gameplay/CampaignBoss.lua','src/stand/server/Session.lua','src/stand/server/Combat.lua','src/server/gameplay/SourceCombat.lua','src/server/gameplay/GameConfig.lua','src/server/gameplay/CampaignDefinition.lua','tools/qa/campaign_combat_pilot.lua','tools/qa/full_campaign_bridge.server.luau','tools/qa/campaign_early_course_pilot.lua','tools/qa/full_campaign_client_adapter.luau']
hashes={f:hashlib.sha256((P/f).read_bytes()).hexdigest()for f in source}
assert hashes['tools/qa/campaign_combat_pilot.lua']=='bfb17590f568b6e9c1d30ccddee00b9aa5a152d6289b60651df544661e4f0a38'
assert hashes['tools/qa/full_campaign_bridge.server.luau']=='97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'
assert hashes['tools/qa/campaign_early_course_pilot.lua']=='1d5693ed7ed9089a7c645c8bf4f3b8b2578fe169dd758f316c47f9b51a280695'
data={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'bounded_whole_boss_RED_both_probe_strategies_rejected_no_source_edit','seed':1158731273,'sourceHashes':hashes,'cases':cases,'sourcePhysicsOrResourcesWritten':False,'sourcePhasesOrHitsForced':False,'fixturePreparation':['Normal Session initial47/attempt1/reserves3; expire original spawn shield by normal clock before constructing boss','CampaignBoss naturalGeneralSlaughter constructor255/progress0/Ready on authoredlevel10platform','Finished Race observation matches Native24detail; actualFoot early return asserted','SourceAI attacks and actualHit windows/cone, SourceCombat selection, runqualification18 and Session identities/rate operate normally'],'limits':['Prepared onehero wholeboss, fresh global3reserves easier thanNative24remaining1','Mapped ground/Humanoid gravity/knockback/facing; no native rig collision, friction or decorativeobstacles','Finite authored72x64platform and actualBossarena clamping included; not an infinite openplane','Fixed planningcadence.133 and queued inputs0/.133, not exact native transport replay','No Studio/Git/source edits, no all13 native acceptance']}
(R/'validation.json').write_text(json.dumps(data,indent=2)+'\n')
for c in cases:print(c)
print('PASS expected whole-boss baseline/control negative results and unchanged sources')
