"""Prepared DarkQueen entry; no traversal/phase/resource outcome is manufactured."""
from pathlib import Path
import hashlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'reports/2026-11-10-slaughter-qa-proof'

fixture = (BASE / 'fixture-preemptive-retry.lua').read_text()
assert fixture.count('Definition.build(10,1158731273)') == 1
fixture = fixture.replace('Definition.build(10,1158731273)', 'Definition.build(13,1158731273)')
fixture = fixture.replace("'Slaughter-source'", "'DarkQueen-queued-audit'")
fixture = fixture.replace("modes={mode='Race'}", "modes={mode='Finale'}")
(HERE / 'queen-fixture.lua').write_text(fixture)

baseline = (BASE / 'baseline-combat.lua').read_bytes()
assert hashlib.sha256(baseline).hexdigest() == 'bfb17590f568b6e9c1d30ccddee00b9aa5a152d6289b60651df544661e4f0a38'
(HERE / 'queen-baseline-combat.lua').write_bytes(baseline)
(HERE / 'queen-nav.lua').write_bytes((BASE / 'nav.lua').read_bytes())
(HERE / 'queen-foot.lua').write_text((BASE / 'actual-foot.lua').read_text().replace("require('./nav')", "require('./queen-nav')"))

probe = (BASE / 'probe-baseline.luau').read_text()
probe = probe.replace("require('./fixture')", "require('./queen-fixture')")
probe = probe.replace("require('./baseline-combat')", "require('./queen-baseline-combat')")
probe = probe.replace("require('./actual-foot')", "require('./queen-foot')")
probe = probe.replace('Fixture.new()', 'Fixture.new(0)')
probe = probe.replace("b.enemies[-99].rawLife==255", "b.enemies[-99].rawLife==15")
probe = probe.replace('now-f.base<600', 'now-f.base<300')
probe = probe.replace("stageToken='boss10'", "stageToken='queen13'")
probe = probe.replace('WHOLE_BASELINE', 'QUEEN13_BASELINE')
probe = probe.replace('Finished Race body', 'Prepared finished Finale observation')
probe = probe.replace(' local hits,accepted,bhits,underflows=', ''' assert(s.state.heroes[1].attempt<=4 and s.state.heroes[1].respawns>=0,'Original normal resource budget')
 local heroDeaths,appearances=0,0
 for _,e in ipairs(s.logs)do if e.kind=='ConfirmedDeath'then heroDeaths+=1 elseif e.kind=='CommitSpawn'then appearances+=1 end end
 assert(s.state.heroes[1].attempt==appearances and s.state.heroes[1].respawns==4-appearances,'Only committed source appearances spend reserves')
 assert(heroDeaths>=appearances-1 and heroDeaths<=appearances,'Final elimination grants no replacement')
 local hits,accepted,bhits,underflows=''')
probe = probe.replace("'underflows',underflows)", "'underflows',underflows,'confirmedDeaths',heroDeaths)")
(HERE / 'queen-probe.luau').write_text(probe)
print('Built isolated prepared DarkQueen13 queue audit;300s cap, baseline BFB, actual Modes retry, no source changes')
