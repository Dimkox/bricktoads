"""Production PCM and atlas contracts; no external dependencies."""
import array
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets/audio"


class AudioAssets(unittest.TestCase):
    def test_uploaded_atlases_have_audible_bounded_regions_and_clean_seams(self):
        manifest = json.loads((AUDIO / "atlas.json").read_text())
        self.assertEqual(manifest["authorship"], "Original authored pulse/triangle/noise synthesis; no ROM samples or melodies")
        for kind, count in (("sfx", 16), ("music", 4)):
            atlas = manifest[kind]
            path = AUDIO / atlas["file"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), atlas["sha256"])
            with wave.open(str(path)) as w:
                self.assertEqual((w.getnchannels(), w.getsampwidth(), w.getframerate()), (1, 2, 22050))
                pcm = array.array("h", w.readframes(w.getnframes()))
                self.assertLess(w.getnframes() / 22050, 420)
            self.assertEqual(len(atlas["regions"]), count)
            previous = 0
            for name, row in atlas["regions"].items():
                start, end = row["startFrame"], row["endFrame"]
                self.assertGreaterEqual(start, previous)
                self.assertGreater(end, start)
                samples = pcm[start:end]
                peak = max(abs(v) for v in samples) / 32767
                rms = math.sqrt(sum(v*v for v in samples) / len(samples)) / 32767
                self.assertGreater(rms, .015, name)
                self.assertLessEqual(peak, .91, name)
                self.assertAlmostEqual(row["rms"], rms, places=5)
                self.assertLess(abs(samples[0]), 40, name)
                self.assertLess(abs(samples[-1]), 40, name)
                self.assertTrue(all(v == 0 for v in pcm[previous:start]), name)
                previous = end
            if kind == "music":
                self.assertEqual(set(atlas["regions"]), {"Level", "Boss", "Result", "Lobby"})
                hashes = {hashlib.sha256(pcm[r["startFrame"]:r["endFrame"]].tobytes()).hexdigest() for r in atlas["regions"].values()}
                self.assertEqual(len(hashes), 4)

    def test_generator_is_deterministic(self):
        spec = importlib.util.spec_from_file_location("audio_generator", AUDIO / "generate_audio.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            module.generate(Path(tmp))
            for name in ("atlas.json", "bricktoads-sfx-atlas.wav", "bricktoads-music-atlas.wav"):
                self.assertEqual((AUDIO / name).read_bytes(), (Path(tmp) / name).read_bytes(), name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
