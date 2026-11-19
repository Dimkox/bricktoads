"""Build a Studio preview or a tester place using an uploaded campaign soundtrack.

Usage: python tools/build_suno_music_preview.py SONG.mp3 PLAYBACK_TARGET OUTPUT_DIR [--campaign SUITE_FOLDER]
PLAYBACK_TARGET accepts a Studio sounds directory or the Roblox URI of the licensed campaign atlas.
Requires FFmpeg.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import wave

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_bricktoads_place import ROOT, build


# Downbeats measured by Suno for take b2ac95f0-e510-4532-8f35-edd3372746ff.
CUES = {
    "Lobby": (0.75379, 16.62975),
    "Level": (32.56663, 64.49208),
    "Boss": (126.80577, 159.07490),
    "Result": (183.43175, 191.62906),
}
RATE = 44100
ASSET = "bricktoads-back-alley-bounce-preview.ogg"
CAMPAIGN_ASSET = "bricktoads-campaign-score-preview.ogg"


def render(cuts, output, asset):
    regions = {}
    atlas = output / Path(asset).with_suffix(".wav")
    with wave.open(str(atlas), "wb") as writer:
        writer.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        for name, (song, start, stop) in cuts.items():
            duration = stop - start
            fades = f"afade=t=in:d=0.008,afade=t=out:st={duration - .008:.6f}:d=0.008"
            pcm = subprocess.check_output([
                "ffmpeg", "-v", "error", "-ss", str(start), "-i", str(song),
                "-t", str(duration), "-af", fades, "-ar", str(RATE), "-ac", "2",
                "-f", "s16le", "pipe:1",
            ])
            if abs(len(pcm) // 4 - duration * RATE) > 2:
                raise ValueError(f"Incomplete {name} loop")
            writer.writeframes(bytes(4 * round(.18 * RATE)))
            first = writer.getnframes() / RATE
            writer.writeframes(pcm)
            regions[name] = (first, writer.getnframes() / RATE)
        writer.writeframes(bytes(4 * round(.18 * RATE)))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(atlas),
                    "-c:a", "libvorbis", "-q:a", "6", str(output / asset)], check=True)
    if max(end for _, end in regions.values()) >= 420:
        raise ValueError("Music regions exceed the client's supported duration")
    return regions


def soundtrack_sources(regions, uri, studio_only):
    catalog_file = Path("src/shared/AudioCatalog.luau")
    catalog = (ROOT / catalog_file).read_text(encoding="utf-8")
    catalog, count = re.subn(r"music='rbxassetid://\d+'", f"music='{uri}'", catalog)
    if count != 1:
        raise ValueError("Expected one music asset")
    rows = [f"        {name}={{start={start:.9f},finish={end:.9f},volume=.22}},"
            for name, (start, end) in regions.items()]
    catalog, count = re.subn(r"    music=\{\n.*?\n    \},", "    music={\n" +
                             "\n".join(rows) + "\n    },", catalog, flags=re.DOTALL)
    if count != 1:
        raise ValueError("Expected one music region table")
    if not studio_only:
        if not re.fullmatch(r"rbxassetid://[1-9][0-9]*", uri):
            raise ValueError("Expected the uploaded Roblox soundtrack asset ID")
        return {catalog_file: catalog}
    audio_file = Path("src/client/GameAudio.luau")
    audio = (ROOT / audio_file).read_text(encoding="utf-8")
    marker = "local function asset(v) return "
    if audio.count(marker) != 1:
        raise ValueError("Expected the client asset validator")
    local_audio = f"(v=='{uri}' and game:GetService('RunService'):IsStudio()) or "
    return {catalog_file: catalog, audio_file: audio.replace(marker, marker + local_audio)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("song", type=Path)
    parser.add_argument("playback_target", help="Studio content/sounds directory or rbxassetid://ID of the uploaded atlas")
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--campaign", type=Path, metavar="SONG_FOLDER",
                        help="Add 13 level and six boss cues from the six downloaded Suno suites")
    args = parser.parse_args()
    if hashlib.sha256(args.song.read_bytes()).hexdigest() != (
            "df70a0b5573ad7dac394a61a121901e9fa666e2c7ada3e1bf794121a0fdceb2b"):
        raise ValueError("This arrangement requires the first Back Alley Bounce MP3 download")
    cloud = re.fullmatch(r"rbxassetid://[1-9][0-9]*", args.playback_target) is not None
    if cloud and not args.campaign:
        parser.error("The tester build requires --campaign and its 13 level and six boss cues")
    if not cloud and not Path(args.playback_target).is_dir():
        raise ValueError("Supply the installed Studio content/sounds directory")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    cuts = {name: (args.song, start, end) for name, (start, end) in CUES.items()}
    asset = ASSET
    if args.campaign:
        asset = CAMPAIGN_ASSET
        cuts = {name: cuts[name] for name in ("Lobby", "Result")}
        manifest = json.loads((ROOT / "assets/audio/suno-campaign.json").read_text(encoding="utf-8"))
        for suite in manifest["suites"]:
            song = args.campaign / suite["file"]
            if hashlib.sha256(song.read_bytes()).hexdigest() != suite["sha256"]:
                raise ValueError(f"Incorrect audio source: {song.name}")
            for cue in suite["cues"]:
                cuts[cue["key"]] = (song, cue["start"], cue["end"])
    regions = render(cuts, args.output_dir, asset)
    if args.campaign:
        regions.update(Level=regions["Level1"], Boss=regions["Boss1"])
    uri = args.playback_target if cloud else "rbxasset://sounds/" + asset
    place = build(ROOT, source_overrides=soundtrack_sources(regions, uri, studio_only=not cloud))
    if not cloud:
        shutil.copyfile(args.output_dir / asset, Path(args.playback_target) / asset)
    filename = "BrickToads-Playtest.rbxlx" if cloud else "BrickToads-Suno-Preview.rbxlx"
    (args.output_dir / filename).write_bytes(place)


if __name__ == "__main__":
    main()
