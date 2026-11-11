"""Course asset boundary tests: frozen source, flat resources, no executable nodes."""
import copy,hashlib,importlib.util,json,shutil,tempfile,unittest
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/vehicles/canonical-course'
IDENTITY=[1,0,0,0,1,0,0,0,1]
REST_ROTATION=[-1,0,0,0,1,0,0,0,-1]

def course_fixture(root):
    folder=root/'assets/vehicles/canonical-course';folder.mkdir(parents=True,exist_ok=True)
    for name in ('canonical-course-vehicles.glb','canonical-course-vehicles-pack.json'):
        if (folder/name).resolve()!=(ASSETS/name).resolve():shutil.copyfile(ASSETS/name,folder/name)
    pack=json.loads((folder/'canonical-course-vehicles-pack.json').read_text())
    templates={}
    for ki,(kind,entry) in enumerate(pack['templates'].items()):
        parts=[]
        for pi,part in enumerate(entry['parts']):
            size=part['sizeStuds'];resource=910000+ki*100+pi
            parts.append({'name':part['name'],'meshId':'rbxassetid://'+str(resource),'textureId':'rbxassetid://'+str(950000+ki),
                          'meshSize':[v*.28 for v in size],'initialSize':[v*.28 for v in size],
                          'size':size,'cframe':part['centerStuds']+REST_ROTATION,'color':[1,1,1],
                          'material':'Plastic','renderFidelity':'Automatic','doubleSided':False,
                          'transparency':0,'reflectance':0,'attachments':[],
                          'surfaceAppearances':[]})
        templates[kind]={key:entry[key] for key in ('deckTop','deckLength','deckWidth')};templates[kind]['parts']=parts
    receipt={'schema':1,'sourcePin':pack['sourcePin'],'modelAssetId':'987650001',
             'sourceGlbFile':'canonical-course-vehicles.glb','sourceGlbSha256':pack['sha256'],
             'sourceGlbBytes':pack['bytes'],'templates':templates}
    path=folder/'roblox-course-vehicles.json';path.write_text(json.dumps(receipt)+'\n')
    return path,receipt

def named(parent,name):return next(i for i in parent.findall('Item') if i.findtext("Properties/string[@name='Name']")==name)

class CoursePackagingTests(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('package_course_assets',ROOT/'tools/package_course_assets.py')
        self.packager=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.packager)
        temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup);self.root=Path(temporary.name)
        self.path,self.receipt=course_fixture(self.root)

    def package(self):
        tree=ET.Element('root');seen=[]
        def item(parent,klass,name):
            node=ET.SubElement(parent,'Item',{'class':klass});properties=ET.SubElement(node,'Properties');ET.SubElement(properties,'string',{'name':'Name'}).text=name;return node
        def prop(node,kind,name,value):ET.SubElement(node.find('Properties'),kind,{'name':name}).text=str(value)
        def mesh_resource(parent,row):
            seen.append(copy.deepcopy(row));mesh=item(parent,'MeshPart',row['name'])
            for a in row['surfaceAppearances']:item(mesh,'SurfaceAppearance',a['name'])
            return mesh
        self.packager.package_course_assets(self.root,tree,item=item,prop=prop,mesh_resource=mesh_resource)
        return tree,seen

    def test_packages_exact_four_flat_cosmetic_templates_and_native_resources(self):
        tree,seen=self.package();folder=named(tree,'BrickToadsCourseTemplates')
        self.assertEqual(folder.attrib['class'],'Folder');self.assertEqual(len(folder.findall('Item')),4)
        self.assertEqual(len(seen),36)
        expected=[row for kind in sorted(self.receipt['templates']) for row in sorted(self.receipt['templates'][kind]['parts'],key=lambda r:r['name'])]
        self.assertEqual(seen,expected)
        for kind,entry in self.receipt['templates'].items():
            model=named(folder,kind);self.assertEqual(model.attrib['class'],'Model')
            for key,value in {'AppearanceProfile':'CanonicalCourseVehicle','CourseKind':kind,'SourcePin':self.receipt['sourcePin']}.items():
                node=named(model,key);self.assertEqual(node.attrib['class'],'StringValue');self.assertEqual(node.findtext("Properties/string[@name='Value']"),value)
            for field in ('deckTop','deckLength','deckWidth'):
                node=named(model,field[0].upper()+field[1:]);self.assertEqual(node.attrib['class'],'NumberValue');self.assertEqual(float(node.findtext("Properties/double[@name='Value']")),entry[field])
            self.assertEqual(sum(c.attrib['class']=='MeshPart' for c in model.findall('Item')),len(entry['parts']))
            self.assertFalse({n.attrib['class'] for n in model.iter('Item')}-{'Model','MeshPart','SurfaceAppearance','StringValue','NumberValue'})

    def reject(self,changes):
        for label,change in changes:
            with self.subTest(case=label):
                receipt=copy.deepcopy(self.receipt)
                for entry in receipt['templates'].values():
                    for row in entry['parts']:
                        row['surfaceAppearances']=[{'name':'SurfaceAppearance','colorMap':'rbxassetid://12345',
                            'normalMap':'','roughnessMap':'','metalnessMap':'','color':[1,1,1],'alphaMode':'Overlay'}]
                change(receipt);self.path.write_text(json.dumps(receipt))
                with self.assertRaises(ValueError):self.package()
        self.path.write_text(json.dumps(self.receipt))

    def test_rejects_missing_extra_duplicate_and_executable_resource_nodes(self):
        def first(r):return r['templates']['Speeder']['parts'][0]
        self.reject([
            ('missing-kind',lambda r:r['templates'].pop('Jet')),
            ('extra-kind',lambda r:r['templates'].update(Board=copy.deepcopy(r['templates']['Surfboard']))),
            ('missing-part',lambda r:r['templates']['Jet']['parts'].pop()),
            ('duplicate-part',lambda r:r['templates']['Jet']['parts'][1].update(name='Body')),
            ('foreign-part',lambda r:first(r).update(name='UnknownPart')),
            ('model-script',lambda r:r['templates']['Jet'].update(children=[{'class':'Script'}])),
            ('part-child',lambda r:first(r).update(children=[{'class':'Humanoid'}])),
            ('part-class',lambda r:first(r).update(className='Part')),
            ('attachment',lambda r:first(r).update(attachments=[{'name':'HiddenJoint','cframe':[0,0,0]+IDENTITY}])),
            ('surface-script',lambda r:first(r)['surfaceAppearances'][0].update(children=[{'class':'Script'}])),
            ('surface-duplicate',lambda r:first(r)['surfaceAppearances'].append(copy.deepcopy(first(r)['surfaceAppearances'][0])))])

    def test_rejects_forged_provenance_bad_geometry_invisible_or_untextured_meshes(self):
        def first(r):return r['templates']['Speeder']['parts'][0]
        self.reject([
            ('schema-bool',lambda r:r.update(schema=True)),('pin',lambda r:r.update(sourcePin='wrong')),
            ('asset-id',lambda r:r.update(modelAssetId='0')),('sha',lambda r:r.update(sourceGlbSha256='0'*64)),
            ('bytes',lambda r:r.update(sourceGlbBytes=303501)),('path',lambda r:r.update(sourceGlbFile='../canonical-course-vehicles.glb')),
            ('deck-top',lambda r:r['templates']['Jet'].update(deckTop=1)),
            ('deck-width',lambda r:r['templates']['Jet'].update(deckWidth=8)),
            ('nan-position',lambda r:first(r)['cframe'].__setitem__(0,float('nan'))),
            ('moved-position',lambda r:first(r)['cframe'].__setitem__(0,4)),
            ('rotated-frame',lambda r:first(r).update(cframe=first(r)['cframe'][:3]+IDENTITY)),
            ('changed-size',lambda r:first(r)['size'].__setitem__(0,5)),
            ('zero-mesh-size',lambda r:first(r)['meshSize'].__setitem__(0,0)),
            ('initial-mismatch',lambda r:first(r)['initialSize'].__setitem__(0,5)),
            ('missing-mesh',lambda r:first(r).update(meshId='')),
            ('foreign-mesh',lambda r:first(r).update(meshId='https://example.invalid')),
            ('invisible',lambda r:first(r).update(transparency=1)),
            ('no-texture',lambda r:first(r).update(surfaceAppearances=[],textureId='')),
            ('empty-texture',lambda r:first(r)['surfaceAppearances'][0].update(colorMap='')),
            ('bad-color',lambda r:first(r).update(color=[1,1,float('inf')]))])

    def test_missing_registry_or_source_never_falls_back_to_placeholder_geometry(self):
        original=self.path.read_bytes();self.path.unlink()
        with self.assertRaises(FileNotFoundError):self.package()
        self.path.write_bytes(original);glb=self.path.parent/'canonical-course-vehicles.glb';glb.unlink()
        with self.assertRaises(FileNotFoundError):self.package()

    def test_modified_source_glb_is_rejected_before_emitting_templates(self):
        glb=self.path.parent/'canonical-course-vehicles.glb';glb.write_bytes(glb.read_bytes()+b'altered')
        with self.assertRaises(ValueError):self.package()

    def test_initial_size_is_optional_and_matching_alias_does_not_change_resources(self):
        for entry in self.receipt['templates'].values():
            for row in entry['parts']:row.pop('initialSize')
        self.path.write_text(json.dumps(self.receipt));self.assertEqual(len(self.package()[1]),36)

    def test_actual_surface_texture_is_preserved_when_native_import_uses_pbr(self):
        surface={'name':'SurfaceAppearance','colorMap':'rbxassetid://12345','normalMap':'rbxassetid://12346',
                 'roughnessMap':'','metalnessMap':'','color':[.8,.9,1],'alphaMode':'Overlay'}
        row=self.receipt['templates']['Jet']['parts'][0];row['textureId']='';row['surfaceAppearances']=[surface]
        self.path.write_text(json.dumps(self.receipt));_,seen=self.package()
        self.assertIn(row,seen)

if __name__=='__main__':unittest.main()
