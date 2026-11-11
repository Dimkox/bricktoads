"""Fetch only the explicitly used public source inputs; never downloads a ROM."""
from pathlib import Path
import argparse
import hashlib
import json
import tempfile
from urllib.parse import quote
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parents[2]
PIN='f1a43b69577246850d136473700a333b3cdfe93f'
FILES={'main.asm':'Battletoads (U) [!].asm','symbols.map':'Battletoads (U) [!].map',
       'source.lst':'Battletoads (U) [!].lst'}
for relative in ['data/spr_lists1.asm','data/spr_lists2.asm',
    *['gfx/'+n for n in ('rash.asm','sprite0.chr','game_std.chr','level1_obj.4','levels1_5_obj.4',
                         'tall_walker.4','stick.4','common.4','byte_BC65.chr','level1_lift.chr')]]:
    FILES[relative]=relative
for name in ('level1_boss.4','level4_obj.4','l1_boss2.chr','level4_obj2.4','zastavki_bkg.4'):
    FILES['gfx/'+name]='gfx/'+name
GEOMETRY_FILES = ('gfx/sprite0.chr', 'gfx/game_std.chr', 'gfx/level1_obj.4',
                  'gfx/levels1_5_obj.4', 'gfx/tall_walker.4')


def source_records(profile):
    records = {}
    for name in ('hero-frame-catalog.json', 'cast-source-catalog.json'):
        catalog = json.loads(Path(__file__).with_name(name).read_text(encoding='utf-8'))
        if catalog['pin'] != PIN:
            raise ValueError('Source catalog pin does not match the pinned downloader')
        records.update(catalog['inputs'])
    names = GEOMETRY_FILES if profile == 'cast-geometry' else FILES
    return {name: records[name] for name in names}


def fetch_sources(cache, records, *, opener=urlopen):
    """Accept only catalog-verified bytes, including when reusing an offline cache."""
    cache = Path(cache).resolve()
    downloaded = 0
    for local, record in records.items():
        target = cache / local
        if ('\\' in local or ':' in local or Path(local).is_absolute()
                or '..' in Path(local).parts or not target.resolve().is_relative_to(cache)):
            raise ValueError('Source path escapes the cache: ' + local)
        cached = target.exists()
        if cached:
            data = target.read_bytes()
        else:
            upstream = FILES.get(local, local)
            url = f'https://raw.githubusercontent.com/feos-tas/DisAssemble/{PIN}/Battletoads/' + quote(upstream, safe='/')
            with opener(url, timeout=45) as response:
                data = response.read()
        if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError('Pinned source size/SHA-256 mismatch: ' + local)
        if not cached:
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=target.parent, suffix='.tmp', delete=False) as output:
                    temporary = Path(output.name)
                    output.write(data)
                temporary.replace(target)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
            downloaded += 1
    return downloaded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=('references', 'cast-geometry'), default='references')
    parser.add_argument('--cache-dir', type=Path, default=ROOT / 'build/canonical-source')
    args = parser.parse_args()
    records = source_records(args.profile)
    downloaded = fetch_sources(args.cache_dir, records)
    print(f'Verified {len(records)} pinned source inputs; {downloaded} downloaded; pin {PIN}')


if __name__ == '__main__':
    main()
