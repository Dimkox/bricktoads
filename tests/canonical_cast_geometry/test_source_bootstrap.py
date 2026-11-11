"""Pinned-source cache integrity; network bytes are supplied at the HTTP boundary."""
from pathlib import Path
import importlib.util
import io
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'canonical_source_fetch', ROOT / 'research/canonical-visuals/fetch_pinned_source.py')
FETCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FETCH)
RECORD = {'bytes': 3, 'sha256': 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'}


class SourceBootstrap(unittest.TestCase):
    def fetch(self, cache, records, opener):
        self.assertTrue(callable(getattr(FETCH, 'fetch_sources', None)),
                        'Missing explicit SHA-verified source bootstrap')
        return FETCH.fetch_sources(cache, records, opener=opener)

    def test_verified_bytes_are_cached_and_reused_without_network(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / 'cache'
            def download(url, *, timeout):
                self.assertEqual(url, 'https://raw.githubusercontent.com/feos-tas/DisAssemble/'
                                 'f1a43b69577246850d136473700a333b3cdfe93f/Battletoads/gfx/sprite0.chr')
                self.assertGreater(timeout, 0)
                return io.BytesIO(b'abc')
            self.fetch(cache, {'gfx/sprite0.chr': RECORD}, download)
            self.assertEqual((cache / 'gfx/sprite0.chr').read_bytes(), b'abc')
            def offline(*args, **kwargs):
                self.fail('A verified cache entry must work offline')
            self.fetch(cache, {'gfx/sprite0.chr': RECORD}, offline)
            self.assertEqual((cache / 'gfx/sprite0.chr').read_bytes(), b'abc')

    def test_tampered_existing_cache_is_rejected_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / 'gfx').mkdir()
            target = cache / 'gfx/sprite0.chr'
            target.write_bytes(b'bad')
            with self.assertRaises(ValueError):
                self.fetch(cache, {'gfx/sprite0.chr': RECORD}, lambda *a, **k: io.BytesIO(b'abc'))
            self.assertEqual(target.read_bytes(), b'bad')

    def test_wrong_download_hash_is_never_published(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            with self.assertRaises(ValueError):
                self.fetch(cache, {'gfx/sprite0.chr': RECORD}, lambda *a, **k: io.BytesIO(b'bad'))
            self.assertFalse((cache / 'gfx/sprite0.chr').exists())
            self.assertFalse(list(cache.rglob('*.tmp')))

    def test_wrong_download_size_is_never_published(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            record = {**RECORD, 'bytes': 4}
            with self.assertRaises(ValueError):
                self.fetch(cache, {'gfx/sprite0.chr': record}, lambda *a, **k: io.BytesIO(b'abc'))
            self.assertFalse((cache / 'gfx/sprite0.chr').exists())

    def test_catalog_path_cannot_escape_the_owned_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / 'cache'
            with self.assertRaises(ValueError):
                self.fetch(cache, {'../outside.chr': RECORD}, lambda *a, **k: io.BytesIO(b'abc'))
            self.assertFalse((Path(directory) / 'outside.chr').exists())


if __name__ == '__main__':
    unittest.main()
