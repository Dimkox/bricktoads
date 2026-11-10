from pathlib import Path
import datetime,difflib,hashlib,json,subprocess,sys
R=Path(__file__).resolve().parent;P=R.parents[1]
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
original=json.loads((R/'validation.json').read_text())
restored={'tools/qa/campaign_combat_pilot.lua':'bfb17590f568b6e9c1d30ccddee00b9aa5a152d6289b60651df544661e4f0a38','tools/qa/full_campaign_bridge.server.luau':'97c32bcbcd8c9af1336875460273a2438972df2ca07a47c9473c144dc1f60add'}
assert sha(R/'baseline-combat.lua')==restored['tools/qa/campaign_combat_pilot.lua']
assert sha(R/'baseline-bridge.lua')==restored['tools/qa/full_campaign_bridge.server.luau']
if '--check-working-baseline' in sys.argv:
 assert all(sha(P/f)==value for f,value in restored.items()),'Working QA has moved beyond the historical restored baseline'
def run(args,log,expected=0):
 r=subprocess.run([str(x)for x in args],cwd=P,capture_output=True,text=True)
 (R/log).write_text(r.stdout+r.stderr)
 assert r.returncode==expected,(log,r.returncode,r.stdout,r.stderr)
 return {'command':[str(x.relative_to(P))if isinstance(x,Path)and x.is_relative_to(P)else str(x)for x in args],'exit':r.returncode,'expectedExit':expected,'log':log}
run([P/'.tools/python-3.13.9/python.exe',R/'prepare.py'],'prepare.txt')
assert sha(R/'candidate-combat.lua')=='cb44211da82b85a9d9ee815576b15aa5a59841aa0cc32c8e0775171856005c28'
assert sha(R/'candidate-bridge.lua')=='74c59dc75f263b8bb22aab3853bac63dd8275be560b1bbee81252194bd0a5132'
for name,start,end in [('combat','local function pigSpacing(','local function guardianPlan('),('bridge','        elseif combatPlan.evasion then','        elseif combatPlan.primary==true')]:
 a=(R/('baseline-'+name+'.lua')).read_bytes().decode();b=(R/('candidate-'+name+'.lua')).read_bytes().decode()
 assert a[:a.index(start)]==b[:b.index(start)]and a[a.index(end):]==b[b.index(end):],'Unrelated source bytes changed: '+name
 (R/(name+'-diff.patch')).write_text(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='baseline-'+name,tofile='candidate-'+name)))
L=P/'.tools/luau-0.745/luau.exe'
dragon=R/'regression-dragon-146.luau'
guardian=R/'regression-guardian-10.luau'
stepoff=R/'regression-stepoff-26.luau'
jobs=[(R/'probe-baseline.luau','composition-red.txt',1),(R/'probe-current.luau','composition-green.txt',0),
 (R/'baseline-session-envelope.luau','session-baseline.txt',0),(R/'candidate-session-envelope.luau','session-candidate.txt',0),
 (R/'probe-gates.luau','gates.txt',0),(R/'regression-bridge-26.luau','bridge-26.txt',0),
 (dragon,'dragon-146.txt',0),(guardian,'guardian-10.txt',0),(stepoff,'stepoff-26.txt',0),
 (R/'probe-closed-loop.luau','closed-loop-red.txt',1)]
checks=[run([L,path],log,expected)for path,log,expected in jobs]
checks.append(run([P/'.tools/luau-0.745/luau-compile.exe','--null',R/'candidate-combat.lua',R/'candidate-bridge.lua',R/'probe-current.luau',R/'candidate-session-envelope.luau',R/'probe-gates.luau',R/'probe-closed-loop.luau'],'compile.txt'))
data={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'REJECTED_liveness_unproven_originals_restored','scope':'Rejected QA Pig spacing hint and margin candidate; no production/client/Studio changes','hashes':{n:sha(R/n)for n in ['baseline-combat.lua','baseline-bridge.lua','candidate-combat.lua','candidate-bridge.lua']},'checks':checks,'conditionalSessionResults':{'baselineRed':2,'baselineGreen':1,'candidateGreen':3,'candidateRed':0},'closedLoop30s':{'pigLife':15,'pigDead':False,'acceptedPrimary':2,'heroHits':19,'heroLife':47,'effectiveEnemyDamage':0},'limits':['Prepared Pig remains2.8studs diagonallyrelative tohero in conditional envelope; not retained nativeNPC trajectory','Fixedacceptedcontactimposed with realSession/profile18; mappedground/Humanoidboundary, noengineparity','Baseline80msdeliveryalreadyGREEN; not exactnative replay','Reservedinsetmayreverseorstopspacing; actual source corner has zeroMove before primary','ActualDirector/NPC closed-loop has no imposedhit or q-follow but mappedground and preparedlook remain nonnative; failed to establish combat progress','NochangedTinyFacepriority, flights, runprimary oracceptedholdguards']}
data['atFreeze']=original.get('atFreeze',original['at'])
data['atFreezeRestorationHashes']=original.get('atFreezeRestorationHashes',restored)
data['reproductionBindings']='Pinned baseline BFB/97, pinned rejected candidate and retained probes; current working QA is not the historical policy under test'
data['workingQAHashes']={f:sha(P/f)for f in restored}
(R/'validation.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps(data['hashes'],indent=2));print('Verified pinned conditional proof and decisive negative progress check; historical restoration receipt retained')
