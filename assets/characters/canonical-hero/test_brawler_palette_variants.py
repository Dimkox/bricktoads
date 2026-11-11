"""Behavior contracts for texture-only variants of the actual detailed P1 GLB."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent


class BrawlerPaletteContracts(unittest.TestCase):
    def builder(self):
        path=HERE/'build_brawler_palette_variants.py'
        self.assertTrue(path.exists(),'Missing detailed-brawler palette builder')
        spec=importlib.util.spec_from_file_location('brawler_palette_builder',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module

    def test_source_p2_uses_17_27_and_preserves_red_cloth_metal_and_glasses(self):
        b=self.builder()
        pixels=bytearray((33,110,23,255, 161,199,41,255, 160,4,10,255, 50,57,60,255, 2,3,3,255))
        result,report=b.recolor_rgba(pixels,'player2')
        self.assertEqual(tuple(result[:4]),(155,83,0,255))
        self.assertEqual(tuple(result[4:8]),(250,160,66,255))
        self.assertEqual(result[8:],pixels[8:])
        self.assertEqual(report['changedPixels'],2)
        self.assertEqual(report['preservedPixels'],3)

    def test_brown_is_the_approved_palette_with_ordered_shadows_and_unchanged_alpha(self):
        b=self.builder()
        pixels=bytearray((33,110,23,255, 12,43,12,255, 161,199,41,180))
        result,_=b.recolor_rgba(pixels,'brown')
        self.assertEqual(tuple(result[:4]),(160,112,86,255))
        self.assertTrue(0<result[4]<result[0]<result[8])
        self.assertEqual(tuple(result[8:]),(224,186,129,180))
        self.assertNotEqual(result[0],pixels[0]*160//255,'Brown must remap the atlas rather than multiply green by a tint')

    def test_real_variant_preserves_every_triangle_joint_uv_material_and_noncolor_texture(self):
        b=self.builder();source=HERE/'green-brawler.glb';before=source.read_bytes()
        with tempfile.TemporaryDirectory(prefix='bricktoads-brawler-palette-') as directory:
            destination=Path(directory)/'brown.glb'
            report=b.build_variant(source,destination,'brown')
            base,raw=b.B.parse(before);variant,newraw=b.B.parse(destination.read_bytes())
            self.assertEqual(b.B.triangle_fingerprint(base,raw),b.B.triangle_fingerprint(variant,newraw))
            for key in ('nodes','meshes','accessors','materials','textures','samplers'):
                self.assertEqual(base[key],variant[key],key)
            self.assertEqual(b.noncolor_fingerprint(base,raw),b.noncolor_fingerprint(variant,newraw))
            self.assertEqual(len(variant['nodes']),15)
            self.assertTrue(report['validation']['onlyBaseColorTextureChanged'])
            self.assertGreater(report['pixels']['changedPixels'],2_000_000)
            self.assertEqual(source.read_bytes(),before)

    def test_source_asset_cannot_be_overwritten(self):
        b=self.builder();source=HERE/'green-brawler.glb';before=hashlib.sha256(source.read_bytes()).hexdigest()
        with self.assertRaises(ValueError):b.build_variant(source,source,'brown')
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)


if __name__=='__main__':unittest.main()
