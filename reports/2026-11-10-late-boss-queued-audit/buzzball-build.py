"""Build an isolated prepared Buzzball whole-boss audit; never edits repo sources."""
from pathlib import Path

R = Path(__file__).resolve().parent
P = R.parents[1]
S = P / 'reports/2026-11-10-slaughter-qa-proof'
fixture = (S / 'fixture-preemptive-retry.lua').read_text()
assert fixture.count('Definition.build(10,1158731273)') == 1
fixture = fixture.replace('Definition.build(10,1158731273)', 'Definition.build(11,1158731273)')
fixture = fixture.replace("'Slaughter-source'", "'Buzzball-source-prepared-battle'")
fixture = fixture.replace("modes={mode='Race'}", "modes={mode='Clinger'}")
needle = ' local b=Boss.new(s,w,cfg,def);bossStarted=true'
assert fixture.count(needle) == 1
fixture = fixture.replace(needle, ''' local b=Boss.new(s,w,cfg,def);bossStarted=true
 assert(b.kind=='Buzzball'and b.state=='Chase'and b.enemies[-99].rawLife==207 and b.enemies[-99].progress==nil,'Natural Buzzball constructor')
 -- Explicit prepared battle entry: invoke the normal source transition. This
 -- is not evidence of earning the Clinger course or chase in this fixture.
 assert(b:finishChase()=='OK'and b.state=='Ready','Normal prepared finishChase API')''')
(R / 'buzzball-fixture.lua').write_text(fixture)
foot = (S / 'actual-foot-integrated.lua').read_text()
assert foot.count("require('./nav')") == 1
(R / 'buzzball-foot.lua').write_text(foot.replace("require('./nav')", "require('./buzzball-nav')"))
(R / 'buzzball-nav.lua').write_bytes((S / 'nav.lua').read_bytes())
print('Built isolated Definition11 / normal finishChase / actual finished Modes retry fixture')
