"""Test the development place build boundary; Studio import is checked separately."""
import importlib.util
import copy
import hashlib
import json
import re
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools/build_bricktoads_place.py"


def named(parent, name):
    return next(item for item in parent.findall("Item")
                if item.findtext("Properties/string[@name='Name']") == name)


class BrickToadsPlaceTests(unittest.TestCase):
    def morph_fixture(self, source):
        shutil.copytree(ROOT / 'src', source / 'src')
        shutil.copytree(ROOT / 'assets', source / 'assets')
        folder = source / 'assets/characters/canonical-hero'
        row = copy.deepcopy(json.loads((folder / 'roblox-player1.json').read_text())['parts'][0])
        row.update(name='Morph', cframe=[0, -.5, -.2, 1,0,0, 0,1,0, 0,0,1],
                   attachments=[{'name':'MorphOriginRigAttachment',
                                 'cframe':[0,.5,.2, 1,0,0, 0,1,0, 0,0,1]}])
        manifests = {}
        for family, kinds, asset_id in [('attack', ('PowerFist','BigBoot'), '987654321'),
                                        ('fear', ('FearBeforeCut','FearAfterCut'), '987654322'),
                                        ('brown', ('PowerFist','BigBoot','FearBeforeCut','FearAfterCut'), '987654324')]:
            blob = f'explicit {family} packaging fixture, never uploaded as an asset'.encode()
            filename = 'brown-hero-morphs.glb' if family=='brown' else f'hero-{family}-morphs.glb'
            (folder / filename).write_bytes(blob)
            manifest = {'schema':1, 'appearanceProfile':'CanonicalNESHeroMorph',
                        'sourceAssetId':asset_id, 'sourceGlbFile':filename,
                        'sourceGlbSha256':hashlib.sha256(blob).hexdigest(), 'templates':[]}
            palettes=[('Brown','Mr. Brown')] if family=='brown' else [('Green','Mr. Green'), ('PlayerTwo','Mr. Yellow')]
            for prefix, hero in palettes:
                for index,kind in enumerate(kinds):
                    part=copy.deepcopy(row)
                    if family=='brown':part.update(meshId='rbxassetid://'+str(987650000+index),
                                                  textureId='rbxassetid://987654999',surfaceAppearances=[])
                    manifest['templates'].append({'name':prefix+kind, 'heroTemplate':hero,
                        'morphKind':kind, 'appearanceScale':1, 'part':part})
            path = folder / f'roblox-{family}-morphs.json'
            path.write_text(json.dumps(manifest), encoding='utf-8')
            manifests[family] = path, manifest
        self.boss_fixture(source)
        return manifests['attack']

    def boss_fixture(self, source):
        folder = source / 'assets/characters/canonical-hero'
        base = json.loads((folder / 'roblox-player1.json').read_text())['parts'][0]
        rotation = [-1,0,0, 0,1,0, 0,0,-1]
        def mesh(name, position, mount_name, mount, asset_id, muzzle=None):
            row = copy.deepcopy(base)
            row.update(name=name, meshId='rbxassetid://' + asset_id,
                       size=[4,6,8], meshSize=[2,3,4], color=[.25,.5,1], material='Metal',
                       cframe=position+rotation, attachments=[{'name':mount_name, 'cframe':mount+rotation}])
            if muzzle is not None:
                row['attachments'].append({'name':'MuzzleRigAttachment', 'cframe':muzzle+rotation})
            return row
        blob = b'explicit four-mesh boss packaging fixture, never uploaded as an asset'
        (folder / 'boss-walker.glb').write_bytes(blob)
        manifest = {'schema':1, 'appearanceProfile':'CanonicalBossWalkerAssets',
                    'sourceAssetId':'987654323', 'sourceGlbFile':'boss-walker.glb',
                    'sourceGlbSha256':hashlib.sha256(blob).hexdigest(), 'templates':[
            {'name':'BossWalkerGuardian', 'appearanceProfile':'CanonicalBossWalker', 'appearanceScale':1,
             'parts':[mesh('GuardianChassis',[2,3,4],'GuardianMountRigAttachment',[2,-3,4],'201'),
                      mesh('GuardianLeftCannon',[-4,2,-1],'GuardianMountRigAttachment',[-1,-2,-1],'202',[-1,-2,3]),
                      mesh('GuardianRightCannon',[4,2,-1],'GuardianMountRigAttachment',[1,-2,-1],'203',[1,-2,3])]},
            {'name':'BossWalkerIntroLeg', 'appearanceProfile':'CanonicalBossWalkerIntroLeg', 'appearanceScale':1,
             'parts':[mesh('IntroLeg12',[2,5,3],'IntroOriginRigAttachment',[2,-5,3],'204')]}]}
        path = folder / 'boss-walker-roblox.json'
        path.write_text(json.dumps(manifest), encoding='utf-8')
        return path, manifest

    def test_boss_templates_preserve_private_resources_rest_frames_origins_and_pbr(self):
        path = self.root / 'assets/characters/canonical-hero/boss-walker-roblox.json'
        manifest = json.loads(path.read_bytes())
        root = ET.fromstring(self.builder.build(self.root))
        storage = named(root,'ServerStorage')
        self.assertIn('BrickToadsBossTemplates',
                      [p.findtext("Properties/string[@name='Name']") for p in storage.findall('Item')])
        folder = named(storage,'BrickToadsBossTemplates')
        self.assertEqual({p.findtext("Properties/string[@name='Name']") for p in folder.findall('Item')},
                         {'BossWalkerGuardian','BossWalkerIntroLeg'})
        for row in manifest['templates']:
            model = named(folder,row['name'])
            self.assertEqual(model.attrib['class'],'Model')
            for name,value in [('AppearanceProfile',row['appearanceProfile']),('SourceAssetId','987654323'),
                               ('SourceGlbSha256',manifest['sourceGlbSha256']),
                               ('AssetManifestSha256',hashlib.sha256(path.read_bytes()).hexdigest())]:
                self.assertEqual(named(model,name).findtext("Properties/string[@name='Value']"),value)
            self.assertEqual(named(model,'AppearanceScale').findtext("Properties/double[@name='Value']"),'1')
            self.assertEqual(len([n for n in model.findall('Item') if n.attrib['class']=='MeshPart']),len(row['parts']))
            self.assertFalse({n.attrib['class'] for n in model.iter('Item')}
                             - {'Model','MeshPart','Attachment','SurfaceAppearance','StringValue','NumberValue'})
            for part in row['parts']:
                mesh = named(model,part['name'])
                self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),part['meshId'])
                self.assertEqual(mesh.findtext("Properties/Color3uint8[@name='Color3uint8']"),str(0xFF4080FF))
                self.assertEqual(mesh.findtext("Properties/token[@name='Material']"),'1088')
                for axis,value in zip('XYZ',[2,3,4]):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='InitialSize']/{axis}")),value)
                for axis,value in zip('XYZ',[4,6,8]):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='size']/{axis}")),value)
                for field,value in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),part['cframe']):
                    self.assertEqual(float(mesh.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
                self.assertEqual(len([n for n in mesh.findall('Item') if n.attrib['class']=='Attachment']),len(part['attachments']))
                for attachment in part['attachments']:
                    child = named(mesh,attachment['name'])
                    for field,value in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),attachment['cframe']):
                        self.assertEqual(float(child.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
                for appearance in part['surfaceAppearances']:
                    surface = named(mesh,appearance['name'])
                    for key,prop in [('colorMap','ColorMap'),('normalMap','NormalMap'),
                                     ('roughnessMap','RoughnessMap'),('metalnessMap','MetalnessMap')]:
                        self.assertEqual(surface.findtext(f"Properties/Content[@name='{prop}']/url"),appearance[key])
                for flag,value in [('Anchored','true'),('Massless','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false')]:
                    self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"),value)
        self.assertNotIn('BrickToadsBossTemplates',''.join(named(root,'ReplicatedStorage').itertext()))
        self.assertNotIn('BrickToadsBossTemplates',''.join(named(root,'Workspace').itertext()))

    def assert_boss_rejects(self, cases):
        path = self.root / 'assets/characters/canonical-hero/boss-walker-roblox.json'
        original = path.read_bytes()
        base = json.loads(original)
        for name,change in cases:
            with self.subTest(case=name):
                manifest = copy.deepcopy(base); change(manifest)
                path.write_text(json.dumps(manifest), encoding='utf-8')
                with self.assertRaises(ValueError):
                    self.builder.build(self.root)
        path.write_bytes(original)

    def test_boss_templates_reject_family_identity_missing_duplicate_and_extra_resources(self):
        self.assert_boss_rejects([
            ('schema',lambda r:r.update(schema=True)),
            ('family',lambda r:r.update(appearanceProfile='CanonicalNESHeroMorph')),
            ('missing-template',lambda r:r['templates'].pop()),
            ('duplicate-template',lambda r:r['templates'][1].update(name='BossWalkerGuardian')),
            ('unknown-template',lambda r:r['templates'][1].update(name='UnknownBoss')),
            ('profile',lambda r:r['templates'][0].update(appearanceProfile='CanonicalBossWalkerIntroLeg')),
            ('scale',lambda r:r['templates'][0].update(appearanceScale=.5)),
            ('missing-part',lambda r:r['templates'][0]['parts'].pop()),
            ('duplicate-part',lambda r:r['templates'][0]['parts'][1].update(name='GuardianChassis')),
            ('unknown-part',lambda r:r['templates'][1]['parts'][0].update(name='Morph')),
            ('extra-part',lambda r:r['templates'][0]['parts'].append(copy.deepcopy(r['templates'][1]['parts'][0]))),
            ('template-script',lambda r:r['templates'][0].update(children=[{'class':'Script'}])),
            ('mesh-humanoid',lambda r:r['templates'][0]['parts'][0].update(children=[{'class':'Humanoid'}])),
            ('attachment-child',lambda r:r['templates'][0]['parts'][0]['attachments'][0].update(children=[])),
            ('surface-child',lambda r:r['templates'][0]['parts'][0]['surfaceAppearances'][0].update(children=[]))])

    def test_boss_templates_reject_invalid_mesh_geometry_visibility_and_content(self):
        cases = [('invisible',lambda r:r['templates'][0]['parts'][0].update(transparency=1)),
                 ('missing-mesh',lambda r:r['templates'][0]['parts'][0].update(meshId='')),
                 ('foreign-mesh',lambda r:r['templates'][0]['parts'][0].update(meshId='https://example.invalid/mesh')),
                 ('missing-mesh-size',lambda r:r['templates'][0]['parts'][0].pop('meshSize')),
                 ('zero-size',lambda r:r['templates'][0]['parts'][0].update(size=[0,1,1])),
                 ('nan-frame',lambda r:r['templates'][0]['parts'][0]['cframe'].__setitem__(0,float('nan'))),
                 ('reflected-frame',lambda r:r['templates'][0]['parts'][0]['cframe'].__setitem__(3,1)),
                 ('invalid-rotation',lambda r:r['templates'][0]['parts'][0]['cframe'].__setitem__(4,.1))]
        for name,value in [('short',[1,2]),('null',None),('zero',[1,0,1]),('negative',[-1,1,1]),
                           ('nan',[1,float('nan'),1]),('infinite',[1,1,float('inf')]),('boolean',[True,1,1])]:
            cases.append(('mesh-size-'+name,lambda r,v=value:r['templates'][0]['parts'][0].update(meshSize=v)))
        self.assert_boss_rejects(cases)

    def test_boss_templates_reject_missing_extra_or_misaligned_mounts_and_muzzles(self):
        self.assert_boss_rejects([
            ('missing-mount',lambda r:r['templates'][0]['parts'][0].update(attachments=[])),
            ('wrong-mount',lambda r:r['templates'][0]['parts'][0]['attachments'][0].update(name='UnknownAttachment')),
            ('duplicate-mount',lambda r:r['templates'][0]['parts'][0]['attachments'].append(copy.deepcopy(r['templates'][0]['parts'][0]['attachments'][0]))),
            ('chassis-muzzle',lambda r:r['templates'][0]['parts'][0]['attachments'].append(copy.deepcopy(r['templates'][0]['parts'][1]['attachments'][1]))),
            ('missing-muzzle',lambda r:r['templates'][0]['parts'][1]['attachments'].pop()),
            ('mount-axis',lambda r:r['templates'][0]['parts'][0]['attachments'][0]['cframe'].__setitem__(3,1)),
            ('mount-axis-tolerance',lambda r:r['templates'][0]['parts'][0]['attachments'][0].update(cframe=[2,-3,4,-1,.0005,0,.0005,1,0,0,0,-1])),
            ('chassis-origin',lambda r:r['templates'][0]['parts'][0]['attachments'][0]['cframe'].__setitem__(0,2.0005)),
            ('left-sign',lambda r:r['templates'][0]['parts'][1]['attachments'][0]['cframe'].__setitem__(0,-5)),
            ('right-sign',lambda r:r['templates'][0]['parts'][2]['attachments'][0]['cframe'].__setitem__(0,5)),
            ('left-near-root',lambda r:r['templates'][0]['parts'][1]['attachments'][0]['cframe'].__setitem__(0,-3.99995)),
            ('right-near-root',lambda r:r['templates'][0]['parts'][2]['attachments'][0]['cframe'].__setitem__(0,3.99995)),
            ('muzzle-behind-mount',lambda r:r['templates'][0]['parts'][1]['attachments'][1]['cframe'].__setitem__(2,-2)),
            ('muzzle-at-mount',lambda r:r['templates'][0]['parts'][1]['attachments'][1]['cframe'].__setitem__(2,-1)),
            ('muzzle-near-mount',lambda r:r['templates'][0]['parts'][1]['attachments'][1]['cframe'].__setitem__(2,-.99995)),
            ('muzzle-orthonormal-quarter-turn',lambda r:r['templates'][0]['parts'][1]['attachments'][1].update(
                cframe=[-1,-2,3,0,0,1,0,1,0,-1,0,0])),
            ('muzzle-nan',lambda r:r['templates'][0]['parts'][1]['attachments'][1]['cframe'].__setitem__(0,float('nan'))),
            ('intro-origin',lambda r:r['templates'][1]['parts'][0]['attachments'][0]['cframe'].__setitem__(0,2.0005)),
            ('intro-axis',lambda r:r['templates'][1]['parts'][0]['attachments'][0]['cframe'].__setitem__(3,1)),
            ('intro-extra-origin',lambda r:r['templates'][1]['parts'][0]['attachments'].append(copy.deepcopy(r['templates'][1]['parts'][0]['attachments'][0])))])

    def test_boss_templates_reject_invalid_provenance_and_source_paths(self):
        cases = [('invalid-id',lambda r:r.update(sourceAssetId='not-uploaded')),
                 ('zero-id',lambda r:r.update(sourceAssetId='0')),
                 ('numeric-id',lambda r:r.update(sourceAssetId=123)),
                 ('bad-sha',lambda r:r.update(sourceGlbSha256='bad')),
                 ('wrong-sha',lambda r:r.update(sourceGlbSha256='0'*64))]
        for filename in ('../outside.glb','..\\outside.glb','/outside.glb','C:\\outside.glb',
                         'C:outside.glb','nested/boss-walker.glb','boss-walker.obj','',None,1,
                         'boss-walker.glb:stream','boss-walker.glb ','CON.glb','other-boss.glb'):
            cases.append(('source-file-'+str(filename),lambda r,v=filename:r.update(sourceGlbFile=v)))
        self.assert_boss_rejects(cases)

    def test_missing_boss_manifest_and_selected_source_fail_closed(self):
        folder = self.root / 'assets/characters/canonical-hero'
        manifest = folder / 'boss-walker-roblox.json'
        original = manifest.read_bytes(); manifest.unlink()
        with self.assertRaises(FileNotFoundError):self.builder.build(self.root)
        manifest.write_bytes(original)
        (folder / 'boss-walker.glb').unlink()
        with self.assertRaises(FileNotFoundError):self.builder.build(self.root)

    def test_attack_morphs_preserve_private_identity_origin_extents_and_pbr(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory); path, manifest=self.morph_fixture(source)
            root=ET.fromstring(self.builder.build(source))
            folder=named(named(root,'ServerStorage'),'BrickToadsCharacterMorphs')
            self.assertEqual({p.findtext("Properties/string[@name='Name']") for p in folder.findall('Item')
                              if not p.findtext("Properties/string[@name='Name']").endswith(('FearBeforeCut','FearAfterCut'))},
                             {p['name'] for p in manifest['templates']}|{'BrownPowerFist','BrownBigBoot'})
            for row in manifest['templates']:
                model=named(folder,row['name']); mesh=named(model,'Morph')
                for key,value in [('AppearanceProfile','CanonicalNESHeroMorph'),('HeroTemplate',row['heroTemplate']),
                                  ('MorphKind',row['morphKind']),('SourceAssetId',manifest['sourceAssetId']),
                                  ('SourceGlbSha256',manifest['sourceGlbSha256'])]:
                    self.assertEqual(named(model,key).findtext("Properties/string[@name='Value']"),value)
                self.assertEqual(named(model,'AppearanceScale').findtext("Properties/double[@name='Value']"),'1')
                self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),row['part']['meshId'])
                for axis,value in zip('XYZ',row['part']['meshSize']):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='InitialSize']/{axis}")),value)
                self.assertEqual(named(mesh,'MorphOriginRigAttachment').attrib['class'],'Attachment')
                self.assertFalse({p.attrib['class'] for p in model.iter('Item')} & {'Script','LocalScript','Humanoid','Motor6D','Bone'})
                for flag,value in [('Anchored','true'),('Massless','true'),('CanCollide','false'),('CanTouch','false'),('CanQuery','false')]:
                    self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"),value)
                for surface in row['part']['surfaceAppearances']:
                    self.assertEqual(named(mesh,surface['name']).findtext("Properties/Content[@name='ColorMap']/url"),surface['colorMap'])

    def test_attack_morphs_reject_wrong_palette_origin_and_missing_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory); path, base=self.morph_fixture(source)
            cases=[('profile',lambda r:r.update(appearanceProfile='Unknown')),
                   ('duplicate',lambda r:r['templates'][-1].update(name=r['templates'][0]['name'])),
                   ('missing',lambda r:r['templates'].pop()),
                   ('palette',lambda r:r['templates'][0].update(heroTemplate='Mr. Yellow')),
                   ('scale',lambda r:r['templates'][0].update(appearanceScale=.5)),
                   ('origin',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,2)),
                   ('runtime-origin-tolerance',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,.0005)),
                   ('invisible-morph',lambda r:r['templates'][0]['part'].update(transparency=1)),
                   ('extent',lambda r:r['templates'][0]['part'].update(meshSize=[0,1,1])),
                   ('wrong-sha',lambda r:r.update(sourceGlbSha256='0'*64)),
                   ('source-path',lambda r:r.update(sourceGlbFile='../outside.glb'))]
            for name,change in cases:
                with self.subTest(case=name):
                    altered=copy.deepcopy(base);change(altered);path.write_text(json.dumps(altered),encoding='utf-8')
                    with self.assertRaises(ValueError):self.builder.build(source)
            path.unlink()
            with self.assertRaises(FileNotFoundError):self.builder.build(source)

    def test_fear_and_attack_morphs_share_one_private_folder_with_distinct_provenance(self):
        root = ET.fromstring(self.builder.build(self.root))
        storage = named(root, 'ServerStorage')
        folders = [node for node in storage.findall('Item')
                   if node.findtext("Properties/string[@name='Name']") == 'BrickToadsCharacterMorphs']
        self.assertEqual(len(folders), 1)
        folder = folders[0]
        self.assertEqual({node.findtext("Properties/string[@name='Name']") for node in folder.findall('Item')},
                         {'GreenPowerFist','GreenBigBoot','PlayerTwoPowerFist','PlayerTwoBigBoot',
                          'GreenFearBeforeCut','GreenFearAfterCut','PlayerTwoFearBeforeCut','PlayerTwoFearAfterCut',
                          'BrownPowerFist','BrownBigBoot','BrownFearBeforeCut','BrownFearAfterCut'})
        path = self.root / 'assets/characters/canonical-hero/roblox-fear-morphs.json'
        manifest = json.loads(path.read_bytes())
        for row in manifest['templates']:
            model = named(folder, row['name'])
            self.assertEqual(model.attrib['class'], 'Model')
            for key, value in [('AppearanceProfile','CanonicalNESHeroMorph'),
                               ('HeroTemplate',row['heroTemplate']), ('MorphKind',row['morphKind']),
                               ('SourceAssetId','987654322'), ('SourceGlbSha256',manifest['sourceGlbSha256']),
                               ('AssetManifestSha256',hashlib.sha256(path.read_bytes()).hexdigest())]:
                self.assertEqual(named(model,key).findtext("Properties/string[@name='Value']"), value)
            self.assertEqual(named(model,'AppearanceScale').findtext("Properties/double[@name='Value']"), '1')
            meshes = [node for node in model.findall('Item') if node.attrib['class'] == 'MeshPart']
            self.assertEqual(len(meshes), 1)
            mesh = named(model, 'Morph')
            self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"), row['part']['meshId'])
            self.assertLess(float(mesh.findtext("Properties/float[@name='Transparency']")), 1)
            for axis, value in zip('XYZ', row['part']['meshSize']):
                self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='InitialSize']/{axis}")), value)
            attachments = [node for node in mesh.findall('Item') if node.attrib['class'] == 'Attachment']
            self.assertEqual(len(attachments), 1)
            self.assertEqual(attachments[0].findtext("Properties/string[@name='Name']"), 'MorphOriginRigAttachment')
            self.assertFalse({node.attrib['class'] for node in model.iter('Item')}
                             & {'Script','LocalScript','Humanoid','Motor6D','Bone'})
        self.assertEqual(named(named(folder,'GreenPowerFist'),'SourceAssetId')
                         .findtext("Properties/string[@name='Value']"), '987654321')

    def test_missing_either_morph_family_fails_closed(self):
        for family in ('attack', 'fear', 'brown'):
            with self.subTest(family=family), tempfile.TemporaryDirectory() as directory:
                source = Path(directory)
                self.morph_fixture(source)
                (source / f'assets/characters/canonical-hero/roblox-{family}-morphs.json').unlink()
                with self.assertRaises(FileNotFoundError):
                    self.builder.build(source)

    def test_fear_morphs_reject_family_mixups_identity_geometry_and_provenance(self):
        path = self.root / 'assets/characters/canonical-hero/roblox-fear-morphs.json'
        base = json.loads(path.read_bytes())
        attack = json.loads((path.parent / 'roblox-attack-morphs.json').read_bytes())
        cases = [('attack-family',lambda r:r.update(templates=attack['templates'])),
                 ('wrong-profile',lambda r:r.update(appearanceProfile='CanonicalNESHero')),
                 ('duplicate-name',lambda r:r['templates'][-1].update(name=r['templates'][0]['name'])),
                 ('missing-template',lambda r:r['templates'].pop()),
                 ('wrong-kind',lambda r:r['templates'][0].update(morphKind='PowerFist')),
                 ('wrong-hero',lambda r:r['templates'][0].update(heroTemplate='Mr. Yellow')),
                 ('wrong-scale',lambda r:r['templates'][0].update(appearanceScale=.8)),
                 ('wrong-part',lambda r:r['templates'][0]['part'].update(name='Head')),
                 ('invisible',lambda r:r['templates'][0]['part'].update(transparency=1)),
                 ('missing-origin',lambda r:r['templates'][0]['part'].update(attachments=[])),
                 ('duplicate-origin',lambda r:r['templates'][0]['part']['attachments'].append(
                     copy.deepcopy(r['templates'][0]['part']['attachments'][0]))),
                 ('origin-tolerance',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,.0005)),
                 ('origin-axis',lambda r:r['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(3,-1)),
                 ('zero-size',lambda r:r['templates'][0]['part'].update(size=[1,0,1])),
                 ('zero-mesh-size',lambda r:r['templates'][0]['part'].update(meshSize=[0,1,1])),
                 ('missing-mesh-size',lambda r:r['templates'][0]['part'].pop('meshSize')),
                 ('missing-mesh-id',lambda r:r['templates'][0]['part'].update(meshId='')),
                 ('wrong-source-id',lambda r:r.update(sourceAssetId='not-uploaded')),
                 ('zero-source-id',lambda r:r.update(sourceAssetId='0')),
                 ('wrong-sha',lambda r:r.update(sourceGlbSha256='0'*64)),
                 ('source-path',lambda r:r.update(sourceGlbFile='../outside.glb')),
                 ('source-drive-path',lambda r:r.update(sourceGlbFile='C:hero.glb')),
                 ('reserved-source-name',lambda r:r.update(sourceGlbFile='CON.glb'))]
        for name, change in cases:
            with self.subTest(case=name):
                altered = copy.deepcopy(base)
                change(altered)
                path.write_text(json.dumps(altered), encoding='utf-8')
                with self.assertRaises(ValueError):
                    self.builder.build(self.root)

    def test_attack_manifest_cannot_substitute_the_fear_family(self):
        folder = self.root / 'assets/characters/canonical-hero'
        path = folder / 'roblox-attack-morphs.json'
        path.write_bytes((folder / 'roblox-fear-morphs.json').read_bytes())
        with self.assertRaises(ValueError):
            self.builder.build(self.root)

    def test_brown_has_a_dedicated_canonical_skin_in_the_playable(self):
        manifest=json.loads((self.root/'assets/characters/canonical-hero/roblox-brown.json').read_text())
        root=ET.fromstring(self.builder.build(self.root))
        skin=named(named(named(root,'ServerStorage'),'BrickToadsCharacterTemplates'),'CanonicalPlayerBrown')
        self.assertEqual(len([p for p in skin.findall('Item') if p.attrib['class']=='MeshPart']),15)
        self.assertEqual(named(skin,'SourceGlbSha256').findtext("Properties/string[@name='Value']"),manifest['sourceGlbSha256'])

    def test_brown_morphs_preserve_dedicated_uploaded_texture_and_all_four_identities(self):
        path=self.root/'assets/characters/canonical-hero/roblox-brown-morphs.json'
        manifest=json.loads(path.read_bytes())
        root=ET.fromstring(self.builder.build(self.root));folder=named(named(root,'ServerStorage'),'BrickToadsCharacterMorphs')
        expected={'BrownPowerFist','BrownBigBoot','BrownFearBeforeCut','BrownFearAfterCut'}
        models={p.findtext("Properties/string[@name='Name']"):p for p in folder.findall('Item')}
        self.assertEqual(set(models)&expected,expected)
        self.assertEqual(len(models),12,'The existing eight Green/P2 resources must remain present')
        for row in manifest['templates']:
            model=models[row['name']];mesh=named(model,'Morph')
            for key,value in [('AppearanceProfile','CanonicalNESHeroMorph'),('HeroTemplate','Mr. Brown'),
                              ('MorphKind',row['morphKind']),('SourceAssetId',manifest['sourceAssetId']),
                              ('SourceGlbSha256',manifest['sourceGlbSha256']),
                              ('AssetManifestSha256',hashlib.sha256(path.read_bytes()).hexdigest())]:
                self.assertEqual(named(model,key).findtext("Properties/string[@name='Value']"),value)
            self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),row['part']['meshId'])
            self.assertEqual(mesh.findtext("Properties/Content[@name='TextureID']/url"),row['part']['textureId'])
            self.assertEqual(row['part']['textureId'],'rbxassetid://987654999')
            self.assertEqual(named(mesh,'MorphOriginRigAttachment').attrib['class'],'Attachment')

    def test_brown_morphs_reject_green_substitution_missing_identity_and_bad_origin(self):
        path=self.root/'assets/characters/canonical-hero/roblox-brown-morphs.json'
        original=path.read_bytes();base=json.loads(original)
        changes=[('green-hero',lambda d:d['templates'][0].update(heroTemplate='Mr. Green')),
                 ('green-name',lambda d:d['templates'][0].update(name='GreenPowerFist')),
                 ('missing-kind',lambda d:d['templates'].pop()),
                 ('duplicate-kind',lambda d:d['templates'][1].update(name='BrownPowerFist')),
                 ('wrong-kind',lambda d:d['templates'][0].update(morphKind='FearAfterCut')),
                 ('wrong-scale',lambda d:d['templates'][0].update(appearanceScale=.8)),
                 ('invalid-origin',lambda d:d['templates'][0]['part']['attachments'][0]['cframe'].__setitem__(0,.005)),
                 ('invalid-hash',lambda d:d.update(sourceGlbSha256='0'*64)),
                 ('source-escape',lambda d:d.update(sourceGlbFile='../brown-hero-morphs.glb'))]
        for name,change in changes:
            with self.subTest(case=name):
                receipt=copy.deepcopy(base);change(receipt);path.write_text(json.dumps(receipt))
                with self.assertRaises(ValueError):self.builder.build(self.root)
        path.write_bytes(original)

    def test_brown_morph_receipt_and_its_selected_source_are_mandatory(self):
        path=self.root/'assets/characters/canonical-hero/roblox-brown-morphs.json'
        original=path.read_bytes();receipt=json.loads(original);path.unlink()
        with self.assertRaises(FileNotFoundError):self.builder.build(self.root)
        path.write_bytes(original)
        (path.parent/receipt['sourceGlbFile']).unlink()
        with self.assertRaises(FileNotFoundError):self.builder.build(self.root)

    def setUp(self):
        self.assertTrue(BUILDER.exists(), "development place builder is missing")
        spec = importlib.util.spec_from_file_location("build_bricktoads_place", BUILDER)
        self.builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.builder)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.morph_fixture(self.root)

    def test_playable_preserves_both_supported_screen_orientations(self):
        root = ET.fromstring(self.builder.build(self.root))
        starter = named(root, "StarterGui")
        self.assertEqual(starter.findtext("Properties/token[@name='ScreenOrientation']"), "4")

    def test_sources_are_current_and_server_code_is_private(self):
        root = ET.fromstring(self.builder.build(self.root))
        server = named(named(root, "ServerScriptService"), "BrickToads")
        shared = named(named(root, "ReplicatedStorage"), "BrickToads")
        client = named(named(named(root, "StarterPlayer"), "StarterPlayerScripts"), "BrickToads")
        for container, filename, name, class_name in [
            (server, "server/RunLifecycle.lua", "RunLifecycle", "ModuleScript"),
            (server, "server/BrickToadsServer.server.luau", "BrickToadsServer", "Script"),
            (shared, "shared/BrickToadsConfig.luau", "BrickToadsConfig", "ModuleScript"),
            (client, "client/BrickToadsClient.client.luau", "BrickToadsClient", "LocalScript"),
        ]:
            item = named(container, name)
            self.assertEqual(item.attrib["class"], class_name)
            self.assertEqual(item.findtext("Properties/ProtectedString[@name='Source']"),
                             (self.root / "src" / filename).read_text(encoding="utf-8"))
        public_sources = "".join(shared.itertext()) + "".join(client.itertext())
        self.assertNotIn((self.root / "src/server/RunLifecycle.lua").read_text(encoding="utf-8"), public_sources)
        self.assertNotIn("LifecycleSpec", [i.findtext("Properties/string[@name='Name']") for i in root.iter("Item")])

    def test_spawn_is_above_a_collidable_anchored_floor(self):
        workspace = named(ET.fromstring(self.builder.build(self.root)), "Workspace")
        floor, spawn = named(workspace, "Baseplate"), named(workspace, "SpawnLocation")
        self.assertEqual(spawn.attrib["class"], "SpawnLocation")
        for part in (floor, spawn):
            self.assertEqual(part.findtext("Properties/bool[@name='Anchored']"), "true")
            self.assertEqual(part.findtext("Properties/bool[@name='CanCollide']"), "true")
        floor_top = float(floor.findtext("Properties/CoordinateFrame/Y")) + float(floor.findtext("Properties/Vector3/Y")) / 2
        spawn_bottom = float(spawn.findtext("Properties/CoordinateFrame/Y")) - float(spawn.findtext("Properties/Vector3/Y")) / 2
        self.assertGreaterEqual(spawn_bottom, floor_top)
        self.assertGreater(float(floor.findtext("Properties/Vector3/X")), float(spawn.findtext("Properties/Vector3/X")))

    def test_playable_runtime_reuses_private_combat_sources_without_stand_entrypoint(self):
        root = ET.fromstring(self.builder.build(self.root))
        server = named(named(root, "ServerScriptService"), "BrickToads")
        runtime = named(server, "CombatRuntime")
        expected = {"Combat", "Session", "Config", "ConnectionRegistry", "RobloxWorld"}
        self.assertEqual({i.findtext("Properties/string[@name='Name']") for i in runtime.findall("Item")}, expected)
        for name in expected:
            source = (self.root / "src/stand/server" / (name + ".lua")).read_text(encoding="utf-8")
            module = named(runtime, name)
            self.assertEqual(module.attrib["class"], "ModuleScript")
            self.assertEqual(module.findtext("Properties/ProtectedString[@name='Source']"), source)
        all_names = {i.findtext("Properties/string[@name='Name']") for i in root.iter("Item")}
        self.assertNotIn("Stand", all_names)
        self.assertNotIn("Diagnostics", all_names)
        self.assertNotIn("StudioReconnectTransportProbe", all_names)

    def test_rebuild_is_deterministic(self):
        self.assertEqual(self.builder.build(self.root), self.builder.build(self.root))

    def test_private_source_receipt_changes_when_an_embedded_source_changes(self):
        def stamp(content):
            server = named(named(ET.fromstring(content), "ServerScriptService"), "BrickToads")
            receipt = named(server, "BuildInfo").findtext("Properties/ProtectedString[@name='Source']")
            return re.search(r"sourceSha256='([0-9a-f]{64})'", receipt).group(1)
        original = stamp(self.builder.build(self.root))
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / "src", source / "src")
            shutil.copytree(self.root / "assets", source / "assets")
            file = source / "src/server/gameplay/GameConfig.lua"
            file.write_text(file.read_text() + "\n-- Controlled embedded source identity probe.\n")
            self.assertNotEqual(original, stamp(self.builder.build(source)))

    def test_green_mesh_template_is_serialized_privately_with_exact_pbr_and_attachments(self):
        manifest = json.loads((self.root / "assets/characters/green-toad.json").read_text(encoding="utf-8"))
        root = ET.fromstring(self.builder.build(self.root, include_character_study=True))
        folder = named(named(root, "ServerStorage"), "BrickToadsCharacterTemplates")
        template = named(folder, "GreenToad")
        meshes = [p for p in template.findall("Item") if p.attrib["class"] == "MeshPart"]
        self.assertEqual(len(meshes), 15)
        self.assertEqual({p.findtext("Properties/string[@name='Name']") for p in meshes}, {p["name"] for p in manifest["parts"]})
        for row in manifest["parts"]:
            mesh = named(template, row["name"])
            self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"), row["meshId"])
            for flag in ("CanCollide", "CanTouch", "CanQuery"):
                self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"), "false")
            self.assertEqual(mesh.findtext("Properties/bool[@name='Massless']"), "true")
            initial = mesh.find("Properties/Vector3[@name='InitialSize']")
            self.assertIsNotNone(initial, 'Saved MeshParts must preserve their source geometry extent')
            for axis, value in zip('XYZ', row.get('meshSize', row['size'])):
                self.assertEqual(float(initial.findtext(axis)), value)
            for surface in row["surfaceAppearances"]:
                appearance = named(mesh, surface["name"])
                for key, prop in (("colorMap", "ColorMap"), ("roughnessMap", "RoughnessMap"), ("metalnessMap", "MetalnessMap")):
                    self.assertEqual(appearance.findtext(f"Properties/Content[@name='{prop}']/url"), surface[key])
            for attachment in row["attachments"]:
                node = named(mesh, attachment["name"])
                self.assertEqual(node.attrib["class"], "Attachment")
                self.assertAlmostEqual(float(node.findtext("Properties/CoordinateFrame[@name='CFrame']/X")), attachment["cframe"][0])
        self.assertFalse({p.attrib["class"] for p in template.iter("Item")} & {"Humanoid", "AnimationConstraint", "BallSocketConstraint", "Script", "Motor6D"})
        self.assertEqual(named(template, "AppearanceScale").findtext("Properties/double[@name='Value']"), "0.8")
        self.assertEqual([p.findtext("Properties/string[@name='Name']") for p in folder.findall("Item")],
                         ["CanonicalPlayer1", "CanonicalPlayer2", "CanonicalPlayerBrown", "GreenToad"])
        self.assertEqual(sum(p.attrib['class']=='ServerStorage' for p in root.findall('Item')),1)
        self.assertEqual(sum(p.findtext("Properties/string[@name='Name']")=='BrickToadsCharacterTemplates'
                             for p in named(root,'ServerStorage').findall('Item')),1)

    def test_missing_character_resource_fails_instead_of_silently_replacing_mesh_art(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / "src", source / "src")
            shutil.copytree(self.root / "assets/characters/canonical-hero", source / "assets/characters/canonical-hero")
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            with self.assertRaises(FileNotFoundError):
                self.builder.build(source, include_character_study=True)

    def test_rejected_explorer_is_excluded_from_the_playable_by_default(self):
        root = ET.fromstring(self.builder.build(self.root))
        self.assertFalse([p for p in root.iter("Item") if p.findtext("Properties/string[@name='Name']") == "GreenToad"])
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / "src", source / "src")
            shutil.copytree(self.root / "assets/characters/canonical-hero", source / "assets/characters/canonical-hero")
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            self.builder.build(source)

    def test_canonical_player_templates_are_default_private_exact_uploaded_resources(self):
        root=ET.fromstring(self.builder.build(self.root))
        storage=next((p for p in root.findall('Item') if p.attrib['class']=='ServerStorage'),None)
        self.assertIsNotNone(storage,'Default playable must package both canonical player resources')
        folder=named(storage,'BrickToadsCharacterTemplates')
        self.assertEqual([p.findtext("Properties/string[@name='Name']") for p in folder.findall('Item')],
                         ['CanonicalPlayer1','CanonicalPlayer2','CanonicalPlayerBrown'])
        source_asset_ids=[]
        mesh_sets=[]
        for player in (1,2):
            path=self.root/f'assets/characters/canonical-hero/roblox-player{player}.json'
            manifest=json.loads(path.read_text(encoding='utf-8'))
            template=named(folder,f'CanonicalPlayer{player}')
            self.assertEqual(template.attrib['class'],'Model')
            for name,value in [('AppearanceProfile','CanonicalNESHero'),('SourceAssetId',manifest['sourceAssetId']),
                               ('SourceGlbSha256',manifest['sourceGlbSha256']),
                               ('AssetManifestSha256',hashlib.sha256(path.read_bytes()).hexdigest())]:
                self.assertEqual(named(template,name).findtext("Properties/string[@name='Value']"),value)
            self.assertEqual(float(named(template,'AppearanceScale').findtext("Properties/double[@name='Value']")),1)
            meshes=[p for p in template.findall('Item') if p.attrib['class']=='MeshPart']
            self.assertEqual(len(meshes),15)
            self.assertEqual(sum(p.attrib['class']=='Attachment' for p in template.iter('Item')),28)
            for row in manifest['parts']:
                mesh=named(template,row['name'])
                self.assertEqual(mesh.findtext("Properties/Content[@name='MeshId']/url"),row['meshId'])
                self.assertIsNotNone(mesh.find("Properties/Content[@name='TextureID']/null"))
                for axis,value in zip('XYZ',row['size']):
                    self.assertEqual(float(mesh.findtext(f"Properties/Vector3[@name='size']/{axis}")),value)
                initial = mesh.find("Properties/Vector3[@name='InitialSize']")
                self.assertIsNotNone(initial, 'MeshId and resized size alone restore MeshSize as zero')
                for axis, value in zip('XYZ', row['meshSize']):
                    self.assertEqual(float(initial.findtext(axis)), value)
                self.assertIsNone(mesh.find("Properties/Vector3[@name='MeshSize']"),
                                  'Read-only MeshSize is saved under the InitialSize property')
                fields=('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22')
                for field,value in zip(fields,row['cframe']):
                    self.assertEqual(float(mesh.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
                color=[round(v*255) for v in row['color']]
                self.assertEqual(int(mesh.findtext("Properties/Color3uint8[@name='Color3uint8']")),
                                 0xFF000000 | color[0]<<16 | color[1]<<8 | color[2])
                for flag,value in [('Anchored','true'),('Massless','true'),('CanCollide','false'),
                                   ('CanTouch','false'),('CanQuery','false')]:
                    self.assertEqual(mesh.findtext(f"Properties/bool[@name='{flag}']"),value)
                for attachment in row['attachments']:
                    target=named(mesh,attachment['name'])
                    for field,value in zip(fields,attachment['cframe']):
                        self.assertEqual(float(target.findtext(f"Properties/CoordinateFrame[@name='CFrame']/{field}")),value)
            self.assertFalse({p.attrib['class'] for p in template.iter('Item')} &
                             {'Script','LocalScript','Humanoid','Motor6D','Bone','AnimationConstraint'})
            source_asset_ids.append(manifest['sourceAssetId'])
            mesh_sets.append({p['meshId'] for p in manifest['parts']})
        self.assertNotEqual(source_asset_ids[0],source_asset_ids[1])
        # Roblox deduplicates identical brawler geometry across palette uploads.
        # Distinct uploaded albedo, rather than duplicate MeshIds, owns the colour.
        albedos=[]
        for player in (1,2):
            manifest=json.loads((self.root/f'assets/characters/canonical-hero/roblox-player{player}.json').read_text())
            albedos.append({s['colorMap'] for p in manifest['parts'] for s in p['surfaceAppearances']})
        self.assertTrue(albedos[0] and albedos[1])
        self.assertNotEqual(albedos[0],albedos[1],'P2 retains its actual uploaded source-palette albedo')
        entry=named(named(named(root,'ServerScriptService'),'BrickToads'),'BrickToadsServer')
        self.assertIn('characterAppearance=require(gameplay.CharacterAppearance)',
                      entry.findtext("Properties/ProtectedString[@name='Source']"))

    def test_missing_either_canonical_manifest_fails_closed(self):
        for player in (1,2):
            with self.subTest(player=player),tempfile.TemporaryDirectory() as directory:
                source=Path(directory)
                shutil.copytree(self.root/'src',source/'src')
                shutil.copytree(self.root/'assets',source/'assets')
                (source/f'assets/characters/canonical-hero/roblox-player{player}.json').unlink()
                with self.assertRaises(FileNotFoundError):self.builder.build(source)

    def test_explicit_canonical_glb_basename_replaces_only_the_default_source_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(self.root / 'assets/characters/canonical-hero', folder)
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            default = folder / manifest.get('sourceGlbFile', 'canonical-hero-player1.glb')
            selected = folder / 'review-versioned-hero.glb'
            default.rename(selected)
            manifest['sourceGlbFile'] = selected.name
            path.write_text(json.dumps(manifest), encoding='utf-8')
            root = ET.fromstring(self.builder.build(source))
            template = named(named(named(root, 'ServerStorage'), 'BrickToadsCharacterTemplates'), 'CanonicalPlayer1')
            self.assertEqual(named(template, 'SourceGlbSha256').findtext("Properties/string[@name='Value']"),
                             manifest['sourceGlbSha256'])
            self.assertEqual(len([p for p in template.findall('Item') if p.attrib['class'] == 'MeshPart']), 15)

    def test_canonical_glb_filename_rejects_paths_extensions_and_empty_values(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(self.root / 'assets/characters/canonical-hero', folder)
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            for filename in ('../outside.glb', '..\\outside.glb', '/outside.glb', 'C:\\outside.glb',
                             'C:outside.glb', 'nested/hero.glb', 'hero.obj', '', None, 1,
                             'hero.glb:stream', 'hero.glb ', 'hero\x00.glb', 'CON.glb', 'com1.glb'):
                with self.subTest(filename=filename):
                    manifest['sourceGlbFile'] = filename
                    path.write_text(json.dumps(manifest), encoding='utf-8')
                    with self.assertRaises(ValueError):
                        self.builder.build(source)

    def test_explicit_canonical_glb_missing_or_wrong_hash_never_uses_the_default(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(self.root / 'assets/characters/canonical-hero', folder)
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            manifest['sourceGlbFile'] = 'review-missing-hero.glb'
            path.write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaises(FileNotFoundError):
                self.builder.build(source)
            # The ordinary source still exists, but only the selected bytes count.
            (folder / manifest['sourceGlbFile']).write_bytes(b'wrong source GLB bytes')
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                self.builder.build(source)

    def test_canonical_surface_appearance_maps_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            shutil.copytree(self.root / 'src', source / 'src')
            folder = source / 'assets/characters/canonical-hero'
            shutil.copytree(self.root / 'assets/characters/canonical-hero', folder)
            shutil.copytree(self.root / 'assets/characters/canonical-cast', source / 'assets/characters/canonical-cast')
            path = folder / 'roblox-player1.json'
            manifest = json.loads(path.read_text(encoding='utf-8'))
            surface = {'name': 'SurfaceAppearance', 'colorMap': 'rbxassetid://101',
                       'normalMap': 'rbxassetid://102', 'roughnessMap': 'rbxassetid://103',
                       'metalnessMap': 'rbxassetid://104', 'color': [.8, .9, 1], 'alphaMode': 'Overlay'}
            manifest['parts'][0]['surfaceAppearances'] = [surface]
            path.write_text(json.dumps(manifest), encoding='utf-8')
            root = ET.fromstring(self.builder.build(source))
            template = named(named(named(root, 'ServerStorage'), 'BrickToadsCharacterTemplates'), 'CanonicalPlayer1')
            appearance = named(named(template, manifest['parts'][0]['name']), 'SurfaceAppearance')
            for key, prop in (('colorMap', 'ColorMap'), ('normalMap', 'NormalMap'),
                              ('roughnessMap', 'RoughnessMap'), ('metalnessMap', 'MetalnessMap')):
                self.assertEqual(appearance.findtext(f"Properties/Content[@name='{prop}']/url"), surface[key])
            for axis, value in zip('RGB', surface['color']):
                self.assertEqual(float(appearance.findtext(f"Properties/Color3[@name='Color']/{axis}")), value)

    def test_invalid_canonical_geometry_content_profile_or_provenance_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)
            shutil.copytree(self.root/'src',source/'src')
            shutil.copytree(self.root/'assets',source/'assets')
            path=source/'assets/characters/canonical-hero/roblox-player1.json'
            original=path.read_bytes();base=json.loads(original)
            def altered(name,change):
                row=copy.deepcopy(base);change(row)
                with self.subTest(case=name):
                    path.write_text(json.dumps(row),encoding='utf-8')
                    with self.assertRaises(ValueError):self.builder.build(source)
            altered('unknown-profile',lambda r:r.update(appearanceProfile='UnverifiedAvatar'))
            altered('wrong-template-name',lambda r:r.update(templateName='CanonicalPlayer2'))
            altered('wrong-scale',lambda r:r.update(appearanceScale=.8))
            altered('invalid-asset-id',lambda r:r.update(sourceAssetId='not-an-uploaded-id'))
            altered('invalid-glb-sha',lambda r:r.update(sourceGlbSha256='bad'))
            altered('mismatched-glb-sha',lambda r:r.update(sourceGlbSha256='0'*64))
            altered('missing-part',lambda r:r['parts'].pop())
            altered('duplicate-part',lambda r:r['parts'][-1].update(name=r['parts'][0]['name']))
            altered('missing-mesh-id',lambda r:r['parts'][0].update(meshId=''))
            altered('foreign-content-url',lambda r:r['parts'][0].update(meshId='https://example.invalid/mesh'))
            altered('negative-size',lambda r:r['parts'][0]['size'].__setitem__(0,-1))
            altered('missing-mesh-size',lambda r:r['parts'][0].pop('meshSize', None))
            for name, value in [('short', [1, 2]), ('null', None), ('zero', [1, 0, 1]),
                                ('negative', [-1, 1, 1]), ('nan', [1, float('nan'), 1]),
                                ('infinite', [1, 1, float('inf')]), ('boolean', [True, 1, 1])]:
                altered('mesh-size-' + name, lambda r, v=value: r['parts'][0].update(meshSize=v))
            altered('nan-position',lambda r:r['parts'][0]['cframe'].__setitem__(0,float('nan')))
            altered('invalid-rotation',lambda r:r['parts'][0]['cframe'].__setitem__(3,8))
            altered('color-out-of-range',lambda r:r['parts'][0]['color'].__setitem__(1,1.5))
            altered('missing-source-joint',lambda r:r['parts'][0]['attachments'].pop())
            altered('duplicate-source-joint',lambda r:r['parts'][0]['attachments'].append(copy.deepcopy(r['parts'][0]['attachments'][0])))
            path.write_bytes(original)

    def test_missing_sources_fail_without_emitting_an_empty_place(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                self.builder.build(Path(directory))

    def test_conflicting_lua_and_luau_names_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            for scope in ("server", "client", "shared"):
                (source / "src" / scope).mkdir(parents=True)
            (source / "src/server/RunLifecycle.lua").write_text("return {}", encoding="utf-8")
            (source / "src/server/RunLifecycle.luau").write_text("return {}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                self.builder.build(source)

    def test_server_scripts_cannot_be_built_into_public_containers(self):
        for scope in ("shared", "client"):
            with self.subTest(scope=scope), tempfile.TemporaryDirectory() as directory:
                source = Path(directory)
                shutil.copytree(self.root / "src", source / "src")
                (source / "src" / scope / "Private.server.luau").write_text("return 'private'", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Server script"):
                    self.builder.build(source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
