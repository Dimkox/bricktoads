"""Original authored chiptune atlases. Python standard library, deterministic PCM.

No ROM audio, instrument data, note sequences or melodies are read. The source
informs event placement only; all pitches, rhythms and envelopes below are new.
"""
from __future__ import annotations
import array
import hashlib
import json
import math
from pathlib import Path
import sys
import wave

RATE = 22050
PAD = 0.18
PIN = "f1a43b69577246850d136473700a333b3cdfe93f"


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def tone(seconds, frequency, wave_kind="pulse", end_frequency=None, duty=.25, decay=0):
    count = round(seconds * RATE)
    phase, noise, filtered = 0.0, 0x4D35, 0.0
    output = []
    for i in range(count):
        u = i / max(1, count - 1)
        f = frequency if end_frequency is None else frequency * (end_frequency / frequency) ** u
        phase = (phase + f / RATE) % 1
        if wave_kind == "noise":
            # 15-bit polynomial noise, reset for each authored note.
            noise = (noise >> 1) | (((noise ^ (noise >> 1)) & 1) << 14)
            value = (noise & 1) * 2 - 1
        elif wave_kind == "triangle":
            value = 1 - 4 * abs(phase - .5)
        else:
            value = (1 if phase < duty else -1) - (2 * duty - 1)
        filtered += .62 * (value - filtered)
        envelope = min(1, i / (RATE * .003), (count - 1 - i) / (RATE * .012))
        output.append(filtered * max(0, envelope) * math.exp(-decay * u))
    return output


def mix(target, signal, at=0, gain=1):
    offset = round(at * RATE)
    for i in range(min(len(signal), len(target) - offset)):
        target[offset+i] += signal[i] * gain


def sequence(notes, unit=.09, kind="pulse"):
    output = [0.0] * round((len(notes) * unit + .04) * RATE)
    for i, midi in enumerate(notes):
        mix(output, tone(unit * .95, note(midi), kind, decay=1.0), i*unit, .7)
    return output


def impact(duration, start, end, noise_gain=.5):
    output = tone(duration, start, "triangle", end, decay=4)
    mix(output, tone(duration, 100, "noise", decay=6), gain=noise_gain)
    return output


def sfx():
    return {
        "Hit": impact(.22, 330, 55, .75),
        "Shield": sequence([90, 95, 90], .045, "triangle"),
        "Miss": tone(.16, 150, "noise", 60, decay=3),
        "Club": impact(.30, 190, 38, .95),
        "Throw": tone(.25, 220, "pulse", 880, decay=2),
        "Fly": sequence([76, 83, 88, 95], .07),
        "Spawn": sequence([55, 62, 67, 74, 79], .075, "triangle"),
        "BossWarning": sequence([45, 45, 52, 45, 57], .115),
        "BossHit": impact(.42, 520, 45, 1.0),
        "Crash": impact(.65, 100, 20, 1.4),
        "Bomb": sequence([84, 79, 72, 67, 60], .065),
        "Victory": sequence([60, 67, 74, 72, 79, 84], .12),
        "Defeat": sequence([67, 63, 58, 55, 48], .15, "triangle"),
        "Death": tone(.48, 440, "pulse", 44, decay=3),
        "Equip": sequence([67, 79], .065),
        "EnemyDeath": impact(.32, 270, 35, .4),
    }


def music(name):
    # Eight bars, newly authored four-channel arrangements. These tables are the
    # complete composition; no source audio driver or ROM bytes are consulted.
    choices = {
        "Level": (150, [45, 48, 43, 50, 45, 52, 48, 43], [0, 7, 12, 10, 7, 3, 5, 12, 14, 10, 7, 5, 3, 7, 10, 2]),
        "Boss": (168, [38, 38, 41, 37, 38, 43, 41, 37], [0, 1, 7, 6, 0, 12, 7, 3, 0, 6, 13, 7, 3, 1, 6, 0]),
        "Result": (120, [48, 53, 55, 60], [0, 4, 7, 12, 9, 7, 4, 2, 5, 9, 12, 16, 14, 12, 7, 4]),
        "Lobby": (108, [48, 45, 53, 55], [7, 12, 14, 16, 12, 9, 7, 4, 5, 9, 12, 14, 9, 7, 4, 2]),
    }
    bpm, roots, melody = choices[name]
    beat = 60 / bpm
    length = len(roots) * 4 * beat
    output = [0.0] * round(length * RATE)
    for bar, root in enumerate(roots):
        base = bar * 4 * beat
        for step in range(8):
            pitch = root + 24 + melody[(bar*3+step) % len(melody)]
            mix(output, tone(beat * .42, note(pitch), duty=.125 if name == "Boss" else .25, decay=.6), base + step * beat / 2, .15)
            chord = root + 12 + [0, 7, 12, 7][step % 4]
            mix(output, tone(beat * .42, note(chord), duty=.5, decay=1.8), base + step * beat / 2, .07)
        for b in range(4):
            mix(output, tone(beat * .86, note(root + (12 if b % 2 else 0)), "triangle", decay=.5), base+b*beat, .32)
            mix(output, tone(.075, 120, "triangle", 38, decay=4), base+b*beat, .30)
            if b % 2:
                mix(output, tone(.1, 100, "noise", decay=4), base+b*beat, .14)
            for half in range(2):
                mix(output, tone(.026, 100, "noise", decay=5), base+(b+half*.5)*beat, .07)
    return output


def pcm(samples):
    # Short whole-region ramps guarantee zero endpoints and click-free joins.
    fade = round(.006 * RATE)
    for i in range(min(fade, len(samples)//2)):
        gain = i / fade
        samples[i] *= gain
        samples[-1-i] *= gain
    peak = max(abs(v) for v in samples)
    gain = min(1, .84 / peak) if peak else 1
    return array.array("h", (round(v * gain * 32767) for v in samples))


def atlas(output_dir, kind, regions):
    filename = f"bricktoads-{kind}-atlas.wav"
    all_samples = array.array("h")
    rows = {}
    for name, signal in regions.items():
        all_samples.extend([0] * round(PAD * RATE))
        start = len(all_samples)
        values = pcm(signal)
        all_samples.extend(values)
        end = len(all_samples)
        rows[name] = {
            "start": start / RATE, "finish": end / RATE,
            "startFrame": start, "endFrame": end, "duration": len(values) / RATE,
            "rms": round(math.sqrt(sum(v*v for v in values) / len(values)) / 32767, 8),
            "peak": round(max(abs(v) for v in values) / 32767, 8),
        }
    all_samples.extend([0] * round(PAD * RATE))
    path = output_dir / filename
    with wave.open(str(path), "wb") as w:
        w.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        w.writeframes(all_samples.tobytes())
    return {"file": filename, "sampleRate": RATE, "duration": len(all_samples)/RATE,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "regions": rows}


def generate(output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": 1,
        "authorship": "Original authored pulse/triangle/noise synthesis; no ROM samples or melodies",
        "sourceCommit": PIN,
        "assetIds": {"sfx": None, "music": None},
        "sfx": atlas(output_dir, "sfx", sfx()),
        "music": atlas(output_dir, "music", {name: music(name) for name in ("Level", "Boss", "Result", "Lobby")}),
    }
    (output_dir / "atlas.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    manifest = generate(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parent)
    print(json.dumps({k: {"file": manifest[k]["file"], "duration": manifest[k]["duration"], "regions": len(manifest[k]["regions"])} for k in ("sfx", "music")}, indent=2))
