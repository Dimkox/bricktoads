"""The checked-in source literal must survive Git's Windows/Linux line endings."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CATALOG = Path('research/2026-11-09-canonical-character-animation-catalog.json')
MODULE = Path('src/server/gameplay/CanonicalAnimation.lua')
GENERATOR = Path('research/generate_canonical_animation_data.py')


class CanonicalDataCheckoutTests(unittest.TestCase):
    def test_check_is_identical_for_lf_and_crlf_catalog_checkouts(self):
        text = (ROOT / CATALOG).read_text(encoding='utf-8')
        for ending in ('\n', '\r\n'):
            with self.subTest(ending=repr(ending)), tempfile.TemporaryDirectory() as directory:
                checkout = Path(directory)
                for relative in (CATALOG, MODULE, GENERATOR):
                    (checkout / relative).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / relative, checkout / relative)
                (checkout / CATALOG).write_bytes(text.replace('\n', ending).encode('utf-8'))
                before = (checkout / MODULE).read_bytes()
                result = subprocess.run([sys.executable, str(checkout / GENERATOR), '--check'],
                                        capture_output=True, text=True, encoding='utf-8')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((checkout / MODULE).read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
