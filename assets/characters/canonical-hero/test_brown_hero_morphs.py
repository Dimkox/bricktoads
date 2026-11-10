"""Exact inherited geometry and atlas-color contracts for Brown morph assets."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent


class BrownMorphContracts(unittest.TestCase):
    def builder(self):
        path=HERE/'build_brown_hero_morphs.py'
        self.assertTrue(path.exists(),'Dedicated Brown morph builder is missing')
        spec=importlib.util.spec_from_file_location('brown_morph_builder',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module

    def test_brown_atlas_replaces_green_without_tinting_tongue_cavity_or_teeth(self):
        b=self.builder()
        original=bytearray((33,110,23,255, 161,199,41,255, 180,16,35,255, 17,1,3,255, 240,242,209,255, 18,19,20,255))
        changed,stats=b.recolor(original)
        self.assertEqual(tuple(changed[:4]),(160,112,86,255))
        self.assertEqual(tuple(changed[4:8]),(224,186,129,255))
        self.assertEqual(changed[8:],original[8:])
        self.assertEqual(stats['changedPixels'],2)

    def test_real_package_copies_all_four_green_mesh_arrays_uvs_and_pivots_exactly(self):
        b=self.builder()
        with tempfile.TemporaryDirectory(prefix='bricktoads-brown-morph-') as directory:
            destination=Path(directory)/'brown.glb'
            report=b.build(destination)
            scene,raw=b.B.parse(destination.read_bytes())
            self.assertEqual([n['name'] for n in scene['nodes']],['BrownPowerFist','BrownBigBoot','BrownFearBeforeCut','BrownFearAfterCut'])
            self.assertEqual(len(scene['materials']),2);self.assertEqual(len(scene['images']),2)
            for row in report['parts']:
                source,binary=b.B.parse((HERE/row['sourceGlb']).read_bytes())
                old=next(n for n in source['nodes'] if n['name']==row['sourceName'])
                node=next(n for n in scene['nodes'] if n['name']==row['name'])
                self.assertEqual(node.get('translation'),old.get('translation'))
                self.assertEqual(b.mesh_fingerprint(scene,raw,node['mesh']),b.mesh_fingerprint(source,binary,old['mesh']))
                primitive=scene['meshes'][node['mesh']]['primitives'][0]
                self.assertNotIn('COLOR_0',primitive['attributes'])
            self.assertTrue(report['validation']['oldGlbsPreserved'])
            self.assertTrue(report['validation']['allFourGeometryUVsAndPivotsExact'])
            self.assertLess(destination.stat().st_size,20_000_000)

    def test_previous_green_asset_cannot_be_an_output(self):
        b=self.builder()
        with self.assertRaises(ValueError):b.build(HERE/'hero-fear-wide-mouth.glb')


if __name__=='__main__':unittest.main()
