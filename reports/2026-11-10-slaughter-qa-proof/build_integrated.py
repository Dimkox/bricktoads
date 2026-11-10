from pathlib import Path
import os,re
R=Path(__file__).resolve().parent;P=R.parents[1]
t=(R/'probe-preemptive-retry.luau').read_text()
t=t.replace("require('./baseline-combat')","require('../../tools/qa/campaign_combat_pilot')")
start=t.index('local tactical=Pilot.plan(c)');end=t.index('   local out=Foot.foot(c,w:position(-99),tactical)',start)
t=t[:start]+'local tactical=Pilot.plan(c)\n'+t[end:]
t=t.replace('WHOLE_PREEMPTIVE_RETRY','WHOLE_INTEGRATED_RETRY')
t=t.replace(' local hits,accepted,bhits,underflows='," assert(b.defeated and b.enemies[-99].progress==240 and s.state.heroes[1].attempt<=4 and s.state.heroes[1].respawns>=0,'Whole source victory inside the original global resource budget')\n local hits,accepted,bhits,underflows=")
(R/'probe-integrated-retry.luau').write_text(t)
(R/'actual-foot-integrated.lua').write_text((R/'actual-foot.lua').read_text().replace('return{foot=foot,qa=qa,states=qa.plans}','return{foot=foot,qa=qa,states=qa.plans,nav=Nav}'))
def remap_test(source,name,foot=False):
 text=source.read_text()
 def remap(m):
  target=(source.parent/m[2]).resolve()
  if target.name in ['candidate-combat','combat-candidate']:target=P/'tools/qa/campaign_combat_pilot'
  if foot and target.name=='candidate-foot':target=R/'actual-foot-integrated'
  relative=os.path.relpath(target,R).replace('\\','/')
  if not relative.startswith('.'):relative='./'+relative
  return 'require('+m[1]+relative+m[1]+')'
 text=re.sub(r'require\(([\'\"])(\.[^\'\"]+)\1\)',remap,text)
 (R/name).write_text(text)
for kind in ['dragon-146','guardian-10','stepoff-26','bridge-26']:
 remap_test(P/f'reports/2026-11-10-qa-pig-spacing-interior/regression-{kind}.luau',f'integrated-regression-{kind}.luau',True)
print('Built direct working-Combat whole encounter plus retained regressions using working Combat and unchanged extracted Bridge97 foot')
