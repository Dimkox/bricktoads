"""Extract actual QA standby dispatch; write only named ignored build outputs."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[2]
build=root/'build';build.mkdir(exist_ok=True)
current=(root/'tools/qa/full_campaign_bridge.server.luau').read_text(encoding='utf-8')
baseline=subprocess.run(['git','show','df98106:tools/qa/full_campaign_bridge.server.luau'],cwd=root,check=True,stdout=subprocess.PIPE,text=True,encoding='utf-8').stdout
def subject(source):
    header="local function neutral()return{x=0,z=0,jump=false,primary=false,run=false}end\nlocal Enum={Material={Air='Air'}}\nlocal function floorRows(world)return world.testFloors end\n"
    marker='local function standby(ctx)'
    if marker in source:
        start=source.index(marker);end=source.index('\nlocal function foot(',start)
        header+=source[start:end]+'\n'
    dispatch=next(line.strip() for line in source.splitlines() if line.strip().startswith('if index==1 and slot~=leadSlot then return'))
    return header+'return function(ctx,index,leadSlot)\nlocal slot=ctx.slot\n'+dispatch+'\nend\n'
(build/'standby_current.lua').write_text(subject(current),encoding='utf-8')
(build/'standby_baseline.lua').write_text(subject(baseline),encoding='utf-8')
probe=(Path(__file__).parent/'standby_probe_input.luau').read_text(encoding='utf-8')
(build/'test_standby_edge.luau').write_text(probe,encoding='utf-8')
(build/'test_standby_edge_baseline.luau').write_text(probe.replace("require('./standby_current')","require('./standby_baseline')"),encoding='utf-8')
print('Generated actual current and df98106 baseline standby dispatch probes')
