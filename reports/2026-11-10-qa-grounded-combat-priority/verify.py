from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def run(label,args,expected):
 p=subprocess.run(args,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace')
 (HERE/(label+'.txt')).write_text(p.stdout,encoding='utf-8')
 row={'label':label,'command':args,'exit':p.returncode,'expectedExit':expected,'matched':p.returncode==expected,'output':p.stdout}
 assert row['matched'],row
 return row
lua='.tools/luau-0.745/luau.exe'
checks=[run('prepare',[sys.executable,str(HERE/'prepare_probe.py')],0),
 run('baseline-composition-red',[lua,'build/ground_priority_base_probe.luau'],1),
 run('composition-green',[lua,'build/ground_priority_current_probe.luau'],0),
 run('baseline-public-red',[lua,'build/ground_priority_base_public.luau'],1),
 run('public-session-green',[lua,'build/ground_priority_current_public.luau','build/ground_priority_current_hold_public.luau'],0),
 run('hold-baseline-red',[lua,'build/ground_priority_hold_base_hold_public.luau'],1),
 run('hold-public-green',[lua,'build/ground_priority_current_hold_public.luau'],0),
 run('hold-old-outcome',[lua,'build/ground_priority_hold_base_hold_outcome.luau'],0),
 run('hold-current-outcome',[lua,'build/ground_priority_current_hold_outcome.luau'],0),
 run('navigation88-green',[lua,'tests/run_route_driver_navigation.luau'],0),
 run('compile',['.tools/luau-0.745/luau-compile.exe','--null','tools/qa/full_campaign_bridge.server.luau','build/ground_priority_current_probe.luau','build/ground_priority_current_public.luau','build/ground_priority_current_hold_public.luau'],0),
 run('diff-check',['git','diff','--check','--','tools/qa/full_campaign_bridge.server.luau'],0)]
bridge=ROOT/'tools/qa/full_campaign_bridge.server.luau'
(HERE/'candidate-bridge.lua').write_bytes(bridge.read_bytes())
report={'status':'focused_verified_frozen','scope':'QA-only bridge grounded tactical priority; no native/production changes or full completion claim',
 'bridgeSha256':hashlib.sha256(bridge.read_bytes()).hexdigest(),'combatSha256':hashlib.sha256((ROOT/'tools/qa/campaign_combat_pilot.lua').read_bytes()).hexdigest(),
 'baselineCommit':'331e705d837e8d92cd7c4cdafd905be150adaff6','productionSourceSha256':'7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a',
 'checks':checks,'cases':26,'holdBaselineSha256':hashlib.sha256((HERE/'hold-baseline-bridge.lua').read_bytes()).hexdigest(),'independentReview':'CLEAR by /root/solo_dragon_audit on frozen bridge97: independently reran 26 composition checks, public first Dash and followup hold, expected baseline hold RED, paired 47/31 outcomes; inspected actual GameWorld stop/reset/facing-zero semantics. No blocker.',
 'limits':['Numeric context uses exact seed503914550 authored support and recorded native p/velocity. Enemy desired points in composition are controlled test data; current enemy position/windup was not retained.',
 'The public Session fixture reuses the pinned Dragon run-up contract, arranged across a legitimate authored gap with no ray obstruction; it supplies numeric run/target geometry, not native engine collisions or network latency.',
 'Only grounded/no-existing-flight plans receive priority; no midair evasion override, physical landing declaration, actor/health/stock/AI/phase writes or new network target/auth fields.',
 'Attempt18 has seven actual Headbutt Hits. Only the first last-preHit phase is Stage gap run-up; six are Walk. No claim that bridge priority explains all four Falls.',
 'Native attempt19 is required to verify physical survival and complete campaign acceptance.']}
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:report[k]for k in ['status','bridgeSha256','combatSha256','cases']}))
