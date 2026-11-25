import base64
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SOURCE = Path(r'C:\Users\User\.codex\visualizations\2026\11\09\01a1c0c4-cc81-7911-b6e8-ca3a3fcc14b3\battletoads-cast-data.json')
OUT = Path(__file__).resolve().parent
DATA = json.loads(SOURCE.read_text(encoding='utf-8-sig'))
W, H = 3840, 2160
BG, CELL, LINE = '#111522', '#1c2435', '#3f506a'
FONTS = {k: ImageFont.truetype(r'C:\Windows\Fonts\arialbd.ttf', k) for k in (30, 40, 48, 70)}

def sheet(entries, title, filename, rows, first_number=1):
    image = Image.new('RGB', (W, H), BG)
    draw = ImageDraw.Draw(image)
    draw.text((64, 36), title, fill='white', font=FONTS[70])
    draw.text((66, 119), 'ORIGINAL NES SPRITES / NEAREST-NEIGHBOR REFERENCE / ALL VARIANTS SHOWN', fill='#aabbd6', font=FONTS[30])
    margin, gutter, top = 64, 28, 190
    cw = (W - margin * 2 - gutter * 2) // 3
    ch = (H - top - margin - gutter * (rows - 1)) // rows
    for i, entry in enumerate(entries):
        col, row = i % 3, i // 3
        x, y = margin + col * (cw + gutter), top + row * (ch + gutter)
        draw.rounded_rectangle((x, y, x + cw, y + ch), radius=18, fill=CELL, outline=LINE, width=3)
        heading = f'{first_number + i:02d}  {entry["en"]}'
        headfont = FONTS[48]
        if draw.textlength(heading, font=headfont) > cw - 52:
            headfont = FONTS[40]
        draw.text((x + 26, y + 22), heading, fill='white', font=headfont)
        sprites = []
        for source in entry['images']:
            sprite = Image.open(io.BytesIO(base64.b64decode(source['src'].split(',', 1)[1]))).convert('RGBA')
            assert sprite.size == (source['nativeWidth'], source['nativeHeight'])
            sprites.append((source, sprite))
        area_top, area_bottom = y + 100, y + ch - 96
        area_height = area_bottom - area_top
        available_width = cw - 80
        gap = 160
        total_native_width = sum(s.width for _, s in sprites)
        max_native_height = max(s.height for _, s in sprites)
        scale = max(1, min(12, int((available_width - gap * (len(sprites) - 1)) // total_native_width), int(area_height // max_native_height)))
        group_width = total_native_width * scale + gap * (len(sprites) - 1)
        sx = x + (cw - group_width) // 2
        for source, sprite in sprites:
            enlarged = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
            sy = area_top + (area_height - enlarged.height) // 2
            image.paste(enlarged, (sx, sy), enlarged)
            label = source['label']
            tx = sx + enlarged.width / 2 - draw.textlength(label, font=FONTS[30]) / 2
            draw.text((tx, y + ch - 73), label, fill='#b9cce9', font=FONTS[30])
            sx += enlarged.width + gap
        draw.text((x + 26, y + ch - 35), f'Source {first_number + i:02d} / {len(sprites)} sprite' + ('s' if len(sprites) > 1 else ''), fill='#8294ae', font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf', 22))
    dest = OUT / filename
    image.save(dest)
    return str(dest)

paths = []
paths.append(sheet(DATA['bosses'], 'BATTLETOADS NES — BOSS REFERENCE', 'bosses.png', 2))
for n in range(3):
    paths.append(sheet(DATA['enemies'][n * 9:(n + 1) * 9], f'BATTLETOADS NES — ENEMY REFERENCE {n + 1}/3', f'enemies-{n + 1:02d}.png', 3, n * 9 + 1))
manifest = {'source': str(SOURCE), 'bosses': [{'number': i + 1, 'name': e['en'], 'variants': [s['label'] for s in e['images']]} for i, e in enumerate(DATA['bosses'])], 'enemy_sheets': [{'file': f'enemies-{n + 1:02d}.png', 'entries': [{'number': n * 9 + i + 1, 'name': e['en'], 'variants': [s['label'] for s in e['images']]} for i, e in enumerate(DATA['enemies'][n * 9:(n + 1) * 9])]} for n in range(3)]}
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(paths, indent=2))
