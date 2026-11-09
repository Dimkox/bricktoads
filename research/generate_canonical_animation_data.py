"""Regenerate the factual clip literal inside CanonicalAnimation; no engine or downloads."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check',action='store_true',help='Verify the literal without writing the module')
args=parser.parse_args()
CATALOG=ROOT/'research/2026-11-09-canonical-character-animation-catalog.json'
MODULE=ROOT/'src/server/gameplay/CanonicalAnimation.lua'
catalog_text=CATALOG.read_text(encoding='utf-8')
catalog=json.loads(catalog_text)
assert catalog['reference']['commit']=='f1a43b69577246850d136473700a333b3cdfe93f'
assert len(catalog['animations'])==69

def bytecode(row):
    count=row['displayAdvances']
    frames=[None]*count
    for run in row['frameRuns']:
        for i in range(run['startAdvance'],run['startAdvance']+run['advances']):
            assert frames[i] is None
            frames[i]=run['frameId']
    assert all(frame is not None for frame in frames)
    events={}
    for event in row['events']:events.setdefault(event['atDisplayAdvance'],[]).append(event)
    result=[]
    for advance in range(count+1):
        for event in events.get(advance,[]):
            assert len(result)==event['byteIndex'],(advance,len(result),event)
            result.extend([event['opcode'],*event['params']])
        if advance<count:result.append(frames[advance])
    assert len(result)==row['terminatorByte']
    result.append(0)
    return '{'+','.join(f'0x{v:02X}' for v in result)+'}'

literal=['local CLIPS={']
for row in catalog['animations']:
    label=json.dumps(row['label'])
    literal.append(f"    [0x{row['animationId']:02X}]={{label={label},line={row['sourceLine']},endLine={row['sourceEffectiveEndLine']},fallthrough={str(row['fallsThroughDeclaredBlock']).lower()},bytes={bytecode(row)}}},")
literal.append('}')
tail=catalog['dashLowLifeTail']['playbackFromEffectEntry']
literal.append(f"local DASH_TAIL={{label='udar_s_razbega:low_life_tail',line=97,endLine=97,bytes={bytecode(tail)}}}")
# read_text normalizes checkout line endings; provenance stays identical on
# Windows CRLF and the repository's canonical UTF-8/LF content in Linux CI.
literal.append(f"local CATALOG_SHA='{hashlib.sha256(catalog_text.encode('utf-8')).hexdigest()}'")
source=MODULE.read_text(encoding='utf-8')
start='-- BEGIN SOURCE CLIPS\n';end='-- END SOURCE CLIPS'
before,remaining=source.split(start,1)
_,after=remaining.split(end,1)
expected=before+start+'\n'.join(literal)+'\n'+end+after
if args.check:
    if source!=expected:parser.exit(1,'Canonical source literal is stale; regenerate it\n')
else:
    MODULE.write_text(expected,encoding='utf-8',newline='\n')
print(f'{"Verified" if args.check else "Generated"}69 clips plus Dash continuation; {MODULE.stat().st_size} bytes')
