"""Strict prop resource boundary: source provenance, complete geometry, flat cosmetics."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/props/canonical-course'
KINDS = {'AirMine','BoardingPad','Bomb','Buzzball','ElectricTrap','Fan','Gas','Gear','IceBlock','Icicle',
         'Lift','Log','Mine','MovingIcePlatform','Ramp','Rocket','RocketLauncher','Rope','RotatingSpike',
         'Snowball','Spike','Spring','Telegraph','Tower','TowerPlatform','Warning','Water','Whirlpool'}
REST = [-1,0,0,0,1,0,0,0,-1]


def prop_fixture(root):
    """Real frozen geometry with deliberately nonuploaded receipt IDs for local tests."""
    folder = root / 'assets/props/canonical-course'
    folder.mkdir(parents=True, exist_ok=True)
    for name in ('canonical-course-props.glb', 'canonical-course-props-pack.json'):
        if (folder/name).resolve() != (ASSETS/name).resolve():
            shutil.copyfile(ASSETS/name, folder/name)
    pack = json.loads((folder/'canonical-course-props-pack.json').read_bytes())
    templates = {}
    for ki, (kind, entry) in enumerate(sorted(pack['templates'].items())):
        rows = []
        for pi, part in enumerate(entry['parts']):
            size = part['sizeStuds']
            row = {'name':part['name'], 'meshId':f'rbxassetid://{920000+ki*100+pi}',
                   'textureId':f'rbxassetid://{960000+ki}', 'size':size,
                   'meshSize':[v*.28 for v in size], 'initialSize':[v*.28 for v in size],
                   'cframe':part['centerStuds']+REST, 'color':[1,1,1], 'material':'Plastic',
                   'renderFidelity':'Automatic', 'doubleSided':False, 'transparency':part.get('baseTransparency',0),
                   'reflectance':0, 'attachments':[], 'surfaceAppearances':[]}
            if part['name'] in entry.get('motionParts', {}):
                row['motion'] = copy.deepcopy(entry['motionParts'][part['name']])
            rows.append(row)
        templates[kind] = {'referenceSize':entry['referenceSize'], 'fitMode':entry['fitMode'], 'parts':rows}
    receipt = {'schema':1, 'sourcePin':pack['sourcePin'], 'modelAssetId':'987650002',
               'sourceGlbFile':'canonical-course-props.glb', 'sourceGlbSha256':pack['sha256'],
               'sourceGlbBytes':pack['bytes'], 'templates':templates}
    path = folder/'roblox-course-props.json'
    path.write_text(json.dumps(receipt)+'\n', encoding='utf-8')
    return path, receipt


def named(parent, name):
    return next(n for n in parent.findall('Item') if n.findtext("Properties/string[@name='Name']") == name)


class CoursePropPackagingTests(unittest.TestCase):
    def setUp(self):
        module_path=ROOT/'tools/package_course_props.py'
        self.assertTrue(module_path.exists(), 'Strict mandatory course prop packager is missing')
        spec = importlib.util.spec_from_file_location('package_course_props', module_path)
        self.packager = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.packager)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.path, self.receipt = prop_fixture(self.root)

    def package(self):
        tree = ET.Element('root')
        self.last_tree=tree
        seen = []
        def item(parent, klass, name):
            node = ET.SubElement(parent, 'Item', {'class':klass})
            properties = ET.SubElement(node, 'Properties')
            ET.SubElement(properties, 'string', {'name':'Name'}).text = name
            return node
        def prop(node, klass, name, value):
            ET.SubElement(node.find('Properties'), klass, {'name':name}).text = str(value)
        def mesh_resource(parent, row):
            seen.append(copy.deepcopy(row))
            mesh = item(parent, 'MeshPart', row['name'])
            for surface in row['surfaceAppearances']:
                item(mesh, 'SurfaceAppearance', surface['name'])
            return mesh
        self.packager.package_course_props(self.root, tree, item=item, prop=prop, mesh_resource=mesh_resource)
        return tree, seen

    def test_packages_all_28_flat_templates_preserving_resources_and_fit_metadata(self):
        tree, seen = self.package()
        folder = named(tree, 'BrickToadsCoursePropTemplates')
        self.assertEqual({n.findtext("Properties/string[@name='Name']") for n in folder.findall('Item')}, KINDS)
        self.assertEqual(len(seen), sum(len(v['parts']) for v in self.receipt['templates'].values()))
        for kind, entry in self.receipt['templates'].items():
            model = named(folder, kind)
            self.assertEqual(model.attrib['class'], 'Model')
            for key, value in {'AppearanceProfile':'CanonicalCourseProp', 'CourseKind':kind,
                               'SourcePin':self.receipt['sourcePin'], 'FitMode':entry['fitMode']}.items():
                node = named(model, key)
                self.assertEqual(node.attrib['class'], 'StringValue')
                self.assertEqual(node.findtext("Properties/string[@name='Value']"), value)
            for axis, value in zip('XYZ', entry['referenceSize']):
                node = named(model, 'ReferenceSize'+axis)
                self.assertEqual(node.attrib['class'], 'NumberValue')
                self.assertAlmostEqual(float(node.findtext("Properties/double[@name='Value']")), value)
            self.assertEqual(sum(n.attrib['class']=='MeshPart' for n in model.findall('Item')), len(entry['parts']))
            self.assertFalse({n.attrib['class'] for n in model.iter('Item')}
                             - {'Model','MeshPart','SurfaceAppearance','StringValue','NumberValue'})
            for row in entry['parts']:
                if 'motion' not in row:continue
                motion=row['motion'];suffix='_'+row['name']
                self.assertEqual(named(model,'MotionKind'+suffix).findtext("Properties/string[@name='Value']"),motion['kind'])
                self.assertAlmostEqual(float(named(model,'MotionSpeed'+suffix).findtext("Properties/double[@name='Value']")),motion['speed'])
                for axis,value in zip('XYZ',motion['pivot']):
                    self.assertAlmostEqual(float(named(model,'MotionPivot'+axis+suffix).findtext("Properties/double[@name='Value']")),value)
        self.assertEqual({r['meshId'] for r in seen},
                         {r['meshId'] for t in self.receipt['templates'].values() for r in t['parts']})

    def reject(self, changes):
        for label, change in changes:
            with self.subTest(case=label):
                receipt = copy.deepcopy(self.receipt)
                change(receipt)
                self.path.write_text(json.dumps(receipt), encoding='utf-8')
                with self.assertRaises(ValueError):
                    self.package()
                self.assertEqual(len(self.last_tree),0,'Rejected resources must not emit partial template trees')
        self.path.write_text(json.dumps(self.receipt), encoding='utf-8')

    def test_rejects_incomplete_duplicate_extra_or_executable_templates(self):
        def first(r): return r['templates']['AirMine']['parts'][0]
        self.reject([
            ('missing-kind', lambda r:r['templates'].pop('Whirlpool')),
            ('extra-kind', lambda r:r['templates'].update(Orb=copy.deepcopy(r['templates']['Mine']))),
            ('missing-part', lambda r:r['templates']['AirMine']['parts'].pop()),
            ('duplicate-part', lambda r:r['templates']['AirMine']['parts'].append(copy.deepcopy(first(r)))),
            ('unknown-part', lambda r:first(r).update(name='ForeignBody')),
            ('model-script', lambda r:r['templates']['AirMine'].update(children=[{'class':'Script'}])),
            ('mesh-script', lambda r:first(r).update(children=[{'class':'Script'}])),
            ('mesh-class', lambda r:first(r).update(className='Part')),
            ('attachment', lambda r:first(r).update(attachments=[{'name':'HiddenJoint','cframe':[0,0,0]+REST}])),
            ('surface-script', lambda r:first(r).update(surfaceAppearances=[{'name':'SurfaceAppearance','children':[]}]))])

    def test_rejects_forged_source_geometry_fit_motion_and_invalid_material_resources(self):
        def first(r): return r['templates']['AirMine']['parts'][0]
        self.reject([
            ('schema-bool', lambda r:r.update(schema=True)),
            ('pin', lambda r:r.update(sourcePin='wrong')),
            ('asset-id', lambda r:r.update(modelAssetId='0')),
            ('source-hash', lambda r:r.update(sourceGlbSha256='0'*64)),
            ('source-bytes', lambda r:r.update(sourceGlbBytes=1)),
            ('source-path', lambda r:r.update(sourceGlbFile='../canonical-course-props.glb')),
            ('fit-mode', lambda r:r['templates']['AirMine'].update(fitMode='Stretch')),
            ('reference-size', lambda r:r['templates']['AirMine']['referenceSize'].__setitem__(0,999)),
            ('nan-frame', lambda r:first(r)['cframe'].__setitem__(0,float('nan'))),
            ('moved-mesh', lambda r:first(r)['cframe'].__setitem__(0,77)),
            ('wrong-rotation', lambda r:first(r).update(cframe=first(r)['cframe'][:3]+[1,0,0,0,1,0,0,0,1])),
            ('changed-size', lambda r:first(r)['size'].__setitem__(0,77)),
            ('changed-source-mesh-size', lambda r:first(r)['meshSize'].__setitem__(0,77)),
            ('initial-size-mismatch', lambda r:first(r)['initialSize'].__setitem__(0,77)),
            ('empty-mesh', lambda r:first(r).update(meshId='')),
            ('remote-mesh', lambda r:first(r).update(meshId='https://example.invalid/mesh')),
            ('untextured', lambda r:first(r).update(textureId='',surfaceAppearances=[])),
            ('invisible', lambda r:first(r).update(transparency=1)),
            ('infinite-color', lambda r:first(r).update(color=[1,float('inf'),1])),
            ('wrong-material', lambda r:first(r).update(material='Wood')),
            ('motion-injection', lambda r:first(r).update(motion={'kind':'SpinY','speed':2,'pivot':[0,0,0]}))])

    def test_rejects_missing_changed_or_nonfinite_frozen_motion(self):
        def rotor(r):return next(p for p in r['templates']['Fan']['parts'] if p['name']=='Rotor')
        self.reject([
            ('missing-motion',lambda r:rotor(r).pop('motion')),
            ('wrong-motion-axis',lambda r:rotor(r)['motion'].update(kind='SpinY')),
            ('wrong-motion-speed',lambda r:rotor(r)['motion'].update(speed=9)),
            ('nan-motion-speed',lambda r:rotor(r)['motion'].update(speed=float('nan'))),
            ('wrong-motion-pivot',lambda r:rotor(r)['motion']['pivot'].__setitem__(0,17)),
            ('extra-motion-field',lambda r:rotor(r)['motion'].update(script='evil'))])

    def test_packages_authored_vortex_spin_as_typed_motion_metadata(self):
        row=next(p for p in self.receipt['templates']['Whirlpool']['parts'] if p['name']=='Spiral')
        row['motion']={'kind':'SpinY','speed':1.2,'pivot':[0,0.11683073718728623,0]}
        self.path.write_text(json.dumps(self.receipt))
        try:
            tree,_=self.package()
        except ValueError as error:
            self.fail('Authored vortex motion was rejected: '+str(error))
        model=named(named(tree,'BrickToadsCoursePropTemplates'),'Whirlpool')
        self.assertEqual(named(model,'MotionKind_Spiral').findtext("Properties/string[@name='Value']"),'SpinY')
        self.assertEqual(float(named(model,'MotionSpeed_Spiral').findtext("Properties/double[@name='Value']")),1.2)
        self.assertAlmostEqual(float(named(model,'MotionPivotY_Spiral').findtext("Properties/double[@name='Value']")),0.11683073718728623)

    def test_rejects_vortex_missing_or_changing_its_frozen_authored_motion(self):
        def spiral(r):return next(p for p in r['templates']['Whirlpool']['parts'] if p['name']=='Spiral')
        for label,motion in [('missing',None),('axis',{'kind':'SpinZ','speed':1.2,'pivot':[0,.11683073718728623,0]}),
                             ('speed',{'kind':'SpinY','speed':1,'pivot':[0,.11683073718728623,0]})]:
            with self.subTest(case=label):
                receipt=copy.deepcopy(self.receipt)
                if motion is None:spiral(receipt).pop('motion',None)
                else:spiral(receipt)['motion']=motion
                self.path.write_text(json.dumps(receipt))
                with self.assertRaises(ValueError):self.package()

    def test_duplicate_receipt_keys_are_rejected_before_emitting_any_geometry(self):
        raw=self.path.read_text()
        self.path.write_text(raw.replace('"schema": 1', '"schema": 1, "schema": 1', 1))
        with self.assertRaises(ValueError):self.package()

    def test_missing_registry_or_source_never_silently_omits_props(self):
        raw=self.path.read_bytes();self.path.unlink()
        with self.assertRaises(FileNotFoundError):self.package()
        self.path.write_bytes(raw)
        (self.path.parent/'canonical-course-props.glb').unlink()
        with self.assertRaises(FileNotFoundError):self.package()

    def test_source_mutation_is_rejected_before_creating_template_folder(self):
        path=self.path.parent/'canonical-course-props.glb'
        blob=bytearray(path.read_bytes());blob[-1]^=1;path.write_bytes(blob)
        with self.assertRaisesRegex(ValueError, 'SHA256'):self.package()
        self.assertEqual(len(self.last_tree),0)

    def test_optional_initial_size_alias_preserves_the_same_source_resources(self):
        for entry in self.receipt['templates'].values():
            for row in entry['parts']:row.pop('initialSize')
        self.path.write_text(json.dumps(self.receipt))
        self.assertEqual(len(self.package()[1]),98)

    def test_preserves_native_float32_transparency_without_normalizing_uploaded_receipt(self):
        row=next(p for p in self.receipt['templates']['Gas']['parts'] if p['name']=='Body')
        row['transparency']=0.30000001192092896
        self.path.write_text(json.dumps(self.receipt))
        try:
            _,seen=self.package()
        except ValueError as error:
            self.fail('Actual native float32 transparency was rejected: '+str(error))
        actual=next(p for p in seen if p['meshId']==row['meshId'])
        self.assertEqual(actual['transparency'],0.30000001192092896)

    def test_editable_pack_sidecar_cannot_change_frozen_geometry_contract(self):
        (self.path.parent/'canonical-course-props-pack.json').write_text('{}')
        self.assertEqual(len(self.package()[1]),98)

    def test_preserves_uploaded_pbr_content_without_allowing_additional_descendants(self):
        row=self.receipt['templates']['Water']['parts'][0]
        row.update(textureId='',surfaceAppearances=[{'name':'SurfaceAppearance','colorMap':'rbxassetid://12345',
            'normalMap':'rbxassetid://12346','roughnessMap':'','metalnessMap':'','color':[1,.8,.7],'alphaMode':'Overlay'}])
        self.path.write_text(json.dumps(self.receipt))
        _,seen=self.package()
        self.assertIn(row['surfaceAppearances'], [r['surfaceAppearances'] for r in seen])


if __name__ == '__main__':unittest.main()
