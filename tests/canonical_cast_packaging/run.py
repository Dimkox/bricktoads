"""Validate the mandatory private cast resource boundary using explicit fixtures."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
PIN='f1a43b69577246850d136473700a333b3cdfe93f'
IDENTITY=[0,0,0,1,0,0,0,1,0,0,0,1]

def named(parent,name):
    return next(p for p in parent.findall('Item') if p.findtext("Properties/string[@name='Name']")==name)

class Packaging(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('cast_packager',ROOT/'tools/package_canonical_cast.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);self.package=module.package_cast
        self.temporary=tempfile.TemporaryDirectory();self.addCleanup(self.temporary.cleanup)
        self.root=Path(self.temporary.name);self.folder=self.root/'assets/characters/canonical-cast';self.folder.mkdir(parents=True)
        kinds=list(json.loads((ROOT/'assets/characters/canonical-cast/manifest.json').read_text())['families'])
        (self.folder/'manifest.json').write_text(json.dumps({'schema':1,'sourcePin':PIN,'families':dict.fromkeys(kinds,{})}))
        blob=b'explicit cast packaging fixture; not uploaded'
        (self.folder/'canonical-cast.glb').write_bytes(blob)
        def part(name,parent,x):
            frame=IDENTITY.copy();frame[0]=x
            origin=IDENTITY.copy();origin[0]=-x
            attachments=[{'name':'CastRigAttachment','cframe':origin}]
            if name=='Body':attachments.append({'name':'CastHeadRigAttachment','cframe':origin.copy()})
            return {'name':name,'parentSegment':parent,'meshId':'rbxassetid://12345','textureId':'',
                    'size':[1,2,3],'meshSize':[.5,1,1.5],'cframe':frame,'color':[.25,.5,1],
                    'material':'Metal','renderFidelity':'Precise','doubleSided':False,'transparency':0,
                    'reflectance':.1,'attachments':attachments,'surfaceAppearances':[]}
        self.receipt={'schema':1,'appearanceProfile':'CanonicalNESCastAssets','sourceAssetId':'987654',
                      'sourceGlbFile':'canonical-cast.glb','sourceGlbSha256':hashlib.sha256(blob).hexdigest(),
                      'sourcePin':PIN,'templates':[{'name':kind,'appearanceProfile':'CanonicalNESCast',
                        'fitYOffset':0,'sourcePixelScale':.18,'parts':[part('Body','@Torso',1),part('Head','Body',2)]}
                        for kind in kinds]}
        self.path=self.folder/'roblox-cast.json';self.path.write_text(json.dumps(self.receipt))
        self.xml=ET.Element('roblox');self.storage=self.item(self.xml,'ServerStorage','ServerStorage');self.calls=[]

    def item(self,parent,cls,name):
        result=ET.SubElement(parent,'Item',{'class':cls});props=ET.SubElement(result,'Properties')
        ET.SubElement(props,'string',{'name':'Name'}).text=name
        return result

    def prop(self,target,kind,name,value):
        result=ET.SubElement(target.find('Properties'),kind,{'name':name});result.text=str(value);return result

    def mesh(self,parent,row):
        self.calls.append(row['name']);mesh=self.item(parent,'MeshPart',row['name'])
        self.prop(mesh,'Content','MeshId',row['meshId'])
        for a in row['attachments']:self.item(mesh,'Attachment',a['name'])
        return mesh

    def build(self):
        return self.package(self.root,self.storage,item=self.item,prop=self.prop,mesh_resource=self.mesh)

    def rejected(self,change):
        receipt=copy.deepcopy(self.receipt);change(receipt);self.path.write_text(json.dumps(receipt))
        with self.assertRaises((ValueError,FileNotFoundError)):self.build()
        self.assertEqual(self.calls,[],'Invalid data must fail before emitting geometry')
        self.assertEqual(len(self.storage.findall('Item')),0)

    def test_mandatory_private_folder_models_parents_and_provenance(self):
        folder=self.build();self.assertEqual(folder,named(self.storage,'BrickToadsCastTemplates'))
        self.assertEqual(len(folder.findall('Item')),29);self.assertEqual(len(self.calls),58)
        for record in self.receipt['templates']:
            model=named(folder,record['name'])
            for key,value in [('AppearanceProfile','CanonicalNESCast'),('CastKind',record['name']),('SourcePin',PIN),
                              ('SourceAssetId','987654'),('SourceGlbSha256',self.receipt['sourceGlbSha256']),
                              ('SourcePixelScale','.18'),('FitYOffset','0')]:
                actual=named(model,key).findtext("Properties/string[@name='Value']")
                if key=='SourcePixelScale':self.assertEqual(float(actual),.18)
                else:self.assertEqual(actual,value)
            self.assertEqual(named(named(model,'Head'),'ParentSegment').findtext("Properties/string[@name='Value']"),'Body')
            self.assertEqual(named(named(model,'Body'),'ParentSegment').findtext("Properties/string[@name='Value']"),'@Torso')
            self.assertEqual({i.attrib['class'] for i in model.iter('Item')},{'Model','MeshPart','Attachment','StringValue'})

    def test_missing_receipt_is_not_a_fallback(self):
        self.path.unlink()
        with self.assertRaises(FileNotFoundError):self.build()

    def test_actual_receipt_round_trips_through_the_real_private_builder(self):
        receipt=ROOT/'assets/characters/canonical-cast/roblox-cast.json'
        if not receipt.is_file():self.skipTest('Production import receipt has not been exported yet')
        spec=importlib.util.spec_from_file_location('real_cast_place_builder',ROOT/'tools/build_bricktoads_place.py')
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        root=ET.fromstring(builder.build(ROOT));folder=named(named(root,'ServerStorage'),'BrickToadsCastTemplates')
        models=folder.findall('Item');self.assertEqual(len(models),29)
        meshes=[p for m in models for p in m.findall('Item') if p.attrib['class']=='MeshPart']
        self.assertEqual(len(meshes),166)
        for mesh in meshes:
            self.assertTrue(named(mesh,'ParentSegment').findtext("Properties/string[@name='Value']"))
            self.assertIsNotNone(mesh.find("Properties/Content[@name='MeshId']/url"))
            self.assertIsNotNone(mesh.find("Properties/Vector3[@name='InitialSize']"))
            self.assertEqual(mesh.findtext("Properties/bool[@name='Massless']"),'true')
            self.assertEqual(mesh.findtext("Properties/bool[@name='CanCollide']"),'false')

    def test_identity_roster_and_owned_glb_rejections(self):
        cases=[lambda d:d.update(schema=True),lambda d:d.update(sourcePin='different'),
               lambda d:d.update(appearanceProfile='CanonicalNESHero'),lambda d:d.update(sourceAssetId='0'),
               lambda d:d.update(sourceGlbSha256='0'*64),lambda d:d.update(sourceGlbFile='../canonical-cast.glb'),
               lambda d:d.update(sourceGlbFile='C:/private.glb'),lambda d:d['templates'].pop(),
               lambda d:d['templates'][0].update(name=d['templates'][1]['name']),
               lambda d:d['templates'][0].update(name='UnexpectedKind'),lambda d:d.update(children=[])]
        for i,change in enumerate(cases):
            with self.subTest(case=i):self.rejected(change)

    def test_tree_and_attachment_rejections(self):
        cases=[lambda d:d['templates'][0]['parts'].pop(0),
               lambda d:d['templates'][0]['parts'][1].update(name='Body'),
               lambda d:d['templates'][0]['parts'][1].update(parentSegment='@Torso'),
               lambda d:d['templates'][0]['parts'][1].update(parentSegment='Missing'),
               lambda d:d['templates'][0]['parts'][1].update(parentSegment='Head'),
               lambda d:d['templates'][0]['parts'][0].update(parentSegment='Head'),
               lambda d:d['templates'][0]['parts'][1].update(attachments=[]),
               lambda d:d['templates'][0]['parts'][0]['attachments'].pop(),
               lambda d:d['templates'][0]['parts'][0]['attachments'].append(copy.deepcopy(d['templates'][0]['parts'][0]['attachments'][0])),
               lambda d:d['templates'][0]['parts'][1]['attachments'][0]['cframe'].__setitem__(0,1),
               lambda d:d['templates'][0]['parts'][1]['attachments'][0].update(children=[])]
        for i,change in enumerate(cases):
            with self.subTest(case=i):self.rejected(change)

    def test_mesh_geometry_resource_and_script_rejections(self):
        changes=[{'size':[0,1,1]},{'meshSize':[True,1,1]},{'transparency':1},{'meshId':''},
                 {'textureId':'https://bad.invalid/t.png'},{'color':[2,0,0]},{'reflectance':float('nan')},
                 {'cframe':[0,0,0,-1,0,0,0,1,0,0,0,1]},{'children':[{'class':'Script'}]},
                 {'attachments':[{'name':'CastRigAttachment','cframe':IDENTITY,'script':'evil'}]}]
        for i,change in enumerate(changes):
            with self.subTest(case=i):self.rejected(lambda d,c=change:d['templates'][0]['parts'][1].update(c))
        for change in [lambda d:d['templates'][0].update(fitYOffset=float('inf')),
                       lambda d:d['templates'][0].update(sourcePixelScale=0),
                       lambda d:d['templates'][0].update(children=[{'class':'Humanoid'}])]:self.rejected(change)

if __name__=='__main__':unittest.main(verbosity=2)
