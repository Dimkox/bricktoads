"""Decode the exact pinned object-bike metasprites; no ROM required."""
from pathlib import Path
import hashlib,json,re,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'research/canonical-visuals'))
import extract_cast_frames as src

def main():
    text=(src.CACHE/'main.asm').read_text(errors='replace');memory=src.sprite_memory()
    _,_,gfx=src.byte_blocks(src.CACHE/'gfx/rash.asm')
    refs=re.findall(r'\.WORD\s+(\w+)',src.main_block(text,'gfx_ptrs'))
    palette=src.numeric_block(text,'palette_chars')[:16]
    contexts,events=src.authored_palette_contexts(palette)
    # Stage 7 Volkmire inherits the Turbo Tunnel object-bank graphics; its
    # separate volkmire_inf_gfx_set writes at $1000 (background pattern bank).
    recipes=[('Speeder',3,'Tunnel',[0x2a]),('Surfboard',12,'Surf',[0xd2]),
             ('Jet',7,'Tunnel',[0x8b]),('ClingerVehicle',10,'Clinger',[0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b])]
    results=[];frames=[];(HERE/'references').mkdir(parents=True,exist_ok=True)
    for kind,level,recipe,ids in recipes:
        tiles,valid,patches=src.tile_bank(recipe)
        candidates=[c for c in contexts[level] if c['typeId']==0x18]
        selected=candidates[0] if candidates else {'actorPaletteXor':0,'paletteIndices':palette,'source':'palette_chars baseline; dynamic vehicle trace unresolved'}
        decoded=[];unknown=[]
        for fid in ids:
            try:
                f=src.decode(fid,'object',text,memory,tiles,valid,gfx,refs,selected['paletteIndices'],selected['actorPaletteXor'])
                filename=f'references/{kind.lower()}-{fid:02x}.png';src.png(HERE/filename,f['width'],f['height'],f['pixels'])
                decoded.append({**{k:v for k,v in f.items() if k!='pixels'},'png':filename});frames.append(f)
            except (ValueError,IndexError,KeyError) as e:unknown.append({'frameId':fid,'reason':str(e)})
        assert decoded,(kind,unknown)
        colors=sorted(set(tuple(f['pixels'][i:i+3]) for f in frames[-len(decoded):] for i in range(0,len(f['pixels']),4) if f['pixels'][i+3]))
        results.append({'kind':kind,'level':level,'bankRecipe':recipe,'sourceEvidence':'main.asm:9148-9208 object_bike and bike_frame_id; frames_koleso at main.asm:8955',
                        'paletteContext':selected,'bankLoads':patches,'frames':decoded,'rgbColors':colors,'unknown':unknown})
    src.sheet(frames,HERE/'vehicle-source-contact-sheet.png',scale=8,columns=4)
    inputs=['main.asm','source.lst','levels_cfgs1.asm','levels_cfgs2.asm','data/spr_lists1.asm','data/spr_lists2.asm','gfx/turbotunnel_obj.4','gfx/surfcity_obj.4','gfx/clign_wing_obj.4']
    catalog={'schema':1,'sourcePin':src.PIN,'sourceUrl':'https://github.com/feos-tas/DisAssemble/tree/'+src.PIN+'/Battletoads',
             'method':'Exact source object metasprite tables plus source CHR recipes and representative authored actor palette; no ROM or emulator.',
             'limitations':['Source is 2D. All 3D depth and unseen surfaces are authored.','Source RGB is illustrative 2C02 conversion.','Repeated Surf/Clinger palette loops and exact interpreter scheduling are not reproduced.'],
             'vehicles':results,'inputs':{p:hashlib.sha256((src.CACHE/p).read_bytes()).hexdigest() for p in inputs}}
    (HERE/'vehicle-source-catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
    print(json.dumps([{'kind':v['kind'],'frames':len(v['frames']),'rgbColors':v['rgbColors']} for v in results],indent=2))
if __name__=='__main__':main()
