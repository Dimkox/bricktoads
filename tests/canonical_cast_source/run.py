"""Check decoded source evidence, palette contexts and actual PNG artifacts."""
from pathlib import Path
import hashlib
import json
import struct

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'research/canonical-visuals'
catalog=json.loads((OUT/'cast-source-catalog.json').read_text())
families={f['family']:f for f in catalog['families']}
assert len(families)==32 and sum(len(f['frames']) for f in families.values())==164
assert len(catalog['crossChecks'])==16 and all(x['pixels'] and x['bounds'] for x in catalog['crossChecks'])
for filename,record in catalog['inputs'].items():
    data=(ROOT/'build/canonical-source'/filename).read_bytes()
    assert len(data)==record['bytes'] and hashlib.sha256(data).hexdigest()==record['sha256'],filename
for family in families.values():
    assert family['namespace'] in ('hero','object','heroStatic')
    for frame in family['frames']:
        data=(OUT/frame['referencePng']).read_bytes()
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        w,h=struct.unpack('>II',data[16:24]);bounds=frame['visibleBounds']
        assert (w,h)==(frame['width'],frame['height'])
        assert w==bounds['maxX']-bounds['minX']+1 and h==bounds['maxY']-bounds['minY']+1
        assert frame['parts'] and all(0<=p['paletteSlot']<4 for p in frame['parts'])
# These guard the observed palette errors that a plausible initial-palette
# render would otherwise miss: red snow, gold Queen, red fish and red robot.
assert families['Snowman']['paletteIndices'][12:]==[15,15,0x23,0x20]
assert families['DarkQueen']['paletteIndices'][12:]==[15,15,0x15,0x27]
assert families['DarkQueen']['actorPaletteXor']==2
assert families['Electrofish']['actorPaletteXor']==1
assert families['Hammerfish']['actorPaletteXor']==2
assert families['Duck']['actorPaletteXor']==1
assert families['Shark']['paletteIndices'][12:]==[15,15,0,0x10]
assert families['RoboManus']['paletteIndices'][12:]==[15,15,0x22,0x20]
# High-bit source attack frames require the extra banks, not a changed pose name.
general={p['file'] for p in families['GeneralSlaughter']['bankLoads']}
assert {'gfx/gen_slaughter.4','gfx/rev_obj.4','gfx/byte_7000_92A1.4'}<=general
queen={p['file'] for p in families['DarkQueen']['bankLoads']}
assert {'gfx/armageddon_spr.4','gfx/bigtornado.4','gfx/pimple.4'}<=queen
assert families['Buzzball']['namespace']==families['DarkQueen']['namespace']=='heroStatic'
assert any(x.get('state')=='complete body' for x in families['Snake']['unknown'])
assert any(x.get('state')=='full articulated body' for x in families['Walker']['unknown'])
print('PASS: 32 cast entries, 164 PNG frames, 16 reference cross-checks, source hashes, namespaces and palette regressions')
