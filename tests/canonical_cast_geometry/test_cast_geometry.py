"""Independent geometry, export and anatomical contract for cosmetic cast meshes."""
from pathlib import Path
import importlib.util, json, math, struct, unittest
import hashlib

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'assets/characters/canonical-cast'
FAMILIES = 'Pig Walker Dragon Raven LargeRaven Invader RocketRat Snowman SentryDrone GasTurret RetroBlaster SaturnToadtrap Robot Slug Electrofish Hammerfish Shark Duck Hordhead Swellcheeks FlyingHead RacingRat BigBlag RoboManus GeneralSlaughter Buzzball DarkQueen Snake HealingFly'.split()
ANATOMY = {
    'Pig':'Head Jaw LeftArm RightArm LeftLeg RightLeg',
    'Walker':'LeftLeg RightLeg LeftFoot RightFoot',
    'Dragon':'Head Jaw LeftArm RightArm LeftWing RightWing LeftLeg RightLeg Tail',
    'Raven':'Head Jaw LeftWing RightWing LeftLeg RightLeg Tail',
    'LargeRaven':'Head Jaw LeftWing RightWing LeftLeg RightLeg Tail',
    'Invader':'LeftArm RightArm LeftLeg RightLeg',
    'RocketRat':'Head LeftArm RightArm LeftLeg RightLeg Weapon',
    'Snowman':'Head LeftArm RightArm LeftLeg RightLeg',
    'SentryDrone':'Head Weapon', 'GasTurret':'Weapon',
    'RetroBlaster':'Head Weapon Jaw Tail', 'Robot':'Head Weapon Jaw',
    'SaturnToadtrap':'Head Jaw', 'Slug':'Head Jaw Tail',
    'Electrofish':'Head Tail',
    'Hammerfish':'Head Jaw Fin LeftFin RightFin Tail',
    'Shark':'Head Jaw Fin LeftFin RightFin Tail',
    'Duck':'Head Jaw LeftWing RightWing Tail',
    'Hordhead':'Head LeftArm RightArm LeftLeg RightLeg Tail',
    'RacingRat':'Head LeftArm RightArm LeftLeg RightLeg Tail',
    'FlyingHead':'Head Jaw LeftWing RightWing',
    'Swellcheeks':'Head Jaw LeftWing RightWing',
    'BigBlag':'Head LeftArm RightArm LeftLeg RightLeg Tail',
    'RoboManus':'Head Jaw LeftArm RightArm LeftLeg RightLeg Weapon',
    'GeneralSlaughter':'Head Jaw LeftArm RightArm LeftLeg RightLeg',
    'Buzzball':'Fin', 'Snake':'Head Jaw Tail',
    'DarkQueen':'Head Hair LeftArm RightArm LeftLeg RightLeg LeftLowerLeg RightLowerLeg',
    'HealingFly':'Head LeftWing RightWing Tail',
}

def parse(blob):
    size=struct.unpack_from('<I',blob,12)[0];return json.loads(blob[20:20+size]),blob[28+size:]

def read(scene,binary,idx):
    accessor=scene['accessors'][idx];view=scene['bufferViews'][accessor['bufferView']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']];code={5126:'f',5123:'H',5125:'I'}[accessor['componentType']]
    offset=view.get('byteOffset',0)+accessor.get('byteOffset',0);fmt='<'+str(count)+code;stride=view.get('byteStride',struct.calcsize(fmt))
    return [struct.unpack_from(fmt,binary,offset+i*stride) for i in range(accessor['count'])]

class CastContract(unittest.TestCase):
    def test_all_requested_families_have_distinct_articulated_closed_surfaces(self):
        self.assertTrue((HERE/'build_cast.py').is_file(), 'cast builder is not implemented')
        spec=importlib.util.spec_from_file_location('cast_geometry', HERE/'build_cast.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        manifest=json.loads((HERE/'manifest.json').read_text())
        self.assertEqual(set(FAMILIES), set(manifest['families']))
        for family in FAMILIES:
            with self.subTest(family=family):
                model=module.build(family)
                report=module.validate(model)
                self.assertGreater(report['triangles'], 200)
                self.assertLess(report['triangles'], 50000)
                self.assertTrue(report['closedComponents'])
                names=set(model.parts)
                self.assertIn('Body',names)
                self.assertTrue(set(ANATOMY[family].split()).issubset(names))
                path=HERE/family/(family+'.glb')
                self.assertLess(path.stat().st_size,20_000_000)
                blob=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',blob)
                self.assertEqual((magic,version,total),(b'glTF',2,len(blob)))
                size=struct.unpack_from('<I',blob,12)[0];scene=json.loads(blob[20:20+size])
                self.assertEqual(len(scene['nodes']),len(model.parts))
                self.assertTrue(scene['materials'][0]['pbrMetallicRoughness']['baseColorTexture'])
                for mesh in scene['meshes']:
                    attrs=mesh['primitives'][0]['attributes']
                    self.assertIn('TEXCOORD_0',attrs)
                    self.assertNotIn('COLOR_0',attrs)
                rig=json.loads((HERE/family/(family+'-rig.json')).read_text())
                self.assertEqual(rig['kind'],family)
                self.assertEqual(rig['metresPerStud'],.28)
                self.assertEqual(len(rig['parts']),len(model.parts))
                self.assertTrue(rig['inferred3D'])
                self.assertTrue(rig['sourceFacts'])
                self.assertEqual(hashlib.sha256(blob).hexdigest(),manifest['families'][family]['sha256'])
                # Verify the actual exported arrays, rather than only the
                # authoring meshes: catch bad GLB offsets, UVs and pivot scaling.
                _,binary=parse(blob);parents={c:i for i,n in enumerate(scene['nodes']) for c in n.get('children',[])}
                def position(i):
                    value=scene['nodes'][i]['translation']
                    return tuple(a+b for a,b in zip(value,position(parents[i]))) if i in parents else value
                decoded=[]
                for i,node in enumerate(scene['nodes']):
                    primitive=scene['meshes'][node['mesh']]['primitives'][0];attrs=primitive['attributes']
                    ps=read(scene,binary,attrs['POSITION']);ns=read(scene,binary,attrs['NORMAL']);uvs=read(scene,binary,attrs['TEXCOORD_0']);indices=[v[0] for v in read(scene,binary,primitive['indices'])]
                    self.assertTrue(all(math.isfinite(v) for p in ps for v in p))
                    self.assertTrue(all(abs(math.sqrt(sum(v*v for v in n))-1)<1e-5 for n in ns))
                    self.assertTrue(all(0<u<1 and 0<v<1 for u,v in uvs))
                    self.assertLess(max(indices),len(ps))
                    for j in range(0,len(indices),3):
                        a,b,c=indices[j:j+3]
                        self.assertEqual(uvs[a],uvs[b],'triangle crosses source-palette atlas cells')
                        self.assertEqual(uvs[a],uvs[c],'triangle crosses source-palette atlas cells')
                    pivot=position(i);decoded.extend(tuple(a+b for a,b in zip(p,pivot)) for p in ps)
                envelope=[[min(p[j] for p in decoded) for j in range(3)],[max(p[j] for p in decoded) for j in range(3)]]
                for actual,expected in zip(envelope,rig['bounds']):
                    self.assertTrue(all(abs(a-b*.28)<1e-5 for a,b in zip(actual,expected)))

    def test_combined_import_preserves_individual_triangles_transforms_and_palette_links(self):
        packed=json.loads((HERE/'canonical-cast-pack.json').read_text());blob=(HERE/'canonical-cast.glb').read_bytes();scene,binary=parse(blob)
        self.assertEqual(hashlib.sha256(blob).hexdigest(),packed['sha256'])
        self.assertEqual(packed['familyCount'],len(FAMILIES))
        self.assertLess(len(blob),20_000_000)
        names=[m['name'] for m in scene['meshes']];self.assertEqual(len(names),len(set(names)))
        self.assertEqual(names,packed['meshNames'])
        self.assertEqual(len(scene['scenes'][0]['nodes']),len(FAMILIES))
        by_name={m['name']:m for m in scene['meshes']};nodes={n['name']:n for n in scene['nodes']}
        for family in FAMILIES:
            individual,raw=parse((HERE/family/(family+'.glb')).read_bytes())
            for mesh,node in zip(individual['meshes'],individual['nodes']):
                combined=by_name[family+'__'+mesh['name']];expected=mesh['primitives'][0];actual=combined['primitives'][0]
                self.assertEqual(nodes[family+'__'+node['name']]['translation'],node['translation'])
                for key in ('POSITION','NORMAL','TEXCOORD_0'):
                    self.assertEqual(read(scene,binary,actual['attributes'][key]),read(individual,raw,expected['attributes'][key]))
                self.assertEqual(read(scene,binary,actual['indices']),read(individual,raw,expected['indices']))
                mat=scene['materials'][actual['material']];self.assertEqual(mat['name'],family+'__PaletteSurface')
                texture=scene['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]
                self.assertEqual(scene['images'][texture['source']]['name'],family+'__SourceInspiredPalette')

if __name__=='__main__':unittest.main()
