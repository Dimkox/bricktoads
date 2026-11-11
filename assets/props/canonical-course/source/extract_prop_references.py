"""Reproduce course prop research from pinned disassembly bytes, never a ROM.

Only writes this source/ directory. Source object identities and runtime kind
names are separate; a source-inspired marker is never asserted to be an NES actor.
"""
from pathlib import Path
import hashlib,json,re,sys
from urllib.request import urlopen
from urllib.parse import quote

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'research/canonical-visuals'))
import extract_cast_frames as src

KINDS='AirMine BoardingPad Bomb Buzzball ElectricTrap Fan Gas Gear IceBlock Icicle Lift Log Mine MovingIcePlatform Ramp Rocket RocketLauncher Rope RotatingSpike Snowball Spike Spring Telegraph Tower TowerPlatform Warning Water Whirlpool'.split()

CUES={
 'AirMine':['Authored airborne mine adaptation: compact hazardous device repeated across the real full-depth gameplay volume; use the proved water-mine family only as an explicitly visual analogue.'],
 'BoardingPad':['Authored vehicle boarding objective marker; a low pad with clear BOARD/readable directional cue fits its runtime role.'],
 'Bomb':['Three-lobed bundled device: two round upper cylinders, long outer sides, lower central canister and dark triangular marking.','Representative source phase is green/black; the NES object cycles four palette flags.'],
 'Buzzball':['Circular red orb with a broad coral/pink spiral covering the face.','Four source frames rotate/change the spiral; silhouette is smooth and round, without a radial spike crown.'],
 'ElectricTrap':['Cyan semicircular mechanical endpoint with pale diagonal teeth/fins.','Paired mirrored endpoints surround a bright pale/yellow electrical arc component.'],
 'Fan':['Side-on upright circular fan housing; pale rim, diagonal/curved internal blades, dark yellow/olive rim shading.','The world updraft volume is much taller than the fan hardware and is not a solid fan body.'],
 'Gas':['Small pale yellow puff stretches into a lobed white/olive plume and disperses into separate ring fragments.'],
 'Gear':['Gray/black toothed circular wheel; source renders two linked mirrored half-wheel sprites.','Two frames shift the teeth around the circumference.'],
 'IceBlock':['White/lavender reflective block with a bright upper face, dark lower facets, and dotted specular highlights.','Rolling frames tilt its angular silhouette.'],
 'Icicle':['Long hanging white/lavender shard with black contour and pointed lower end; two authored lengths.'],
 'Lift':['Narrow upright orange/ochre platform column with bright cap, thin pale stripe, dark lower face and stippled shadow.','Runtime broad horizontal support footprint is an authored 3D adaptation; electrical variant frames are research only.'],
 'Log':['Narrow uneven brown/orange log with dark bark grooves, uneven taper and bright exposed end.','Runtime full-lane log orientation/depth is authored.'],
 'Mine':['Small round naval mine with short radial protrusions, dark contour and gray/white highlights in the source spawner palette context.'],
 'MovingIcePlatform':['Wide flat pale slab with a bright upper snow/ice edge and irregular downward teeth/icicles.','Selected direct source actor snapshot is pale yellow/olive/white; no invented blue palette claim.'],
 'Ramp':['White slanted wedge/diamond face with pink/dark-magenta outline.','Source type24 enters a specific launch branch; runtime ascending stepped footprint is authored.'],
 'Rocket':['Long narrow pointed rocket with small fins, opposite up/down graphics variants and dark outline.','First source spawner snapshot makes it gray/white/black; red baseline coloring is not this selected context.'],
 'RocketLauncher':['Authored visible emitter housing; the proved type68 source counterpart is a logical mine/fire/rocket creator with no proved visible cannon sprite.'],
 'Rope':['Source rope is a narrow repeated gold/cream strand; three raw tile shapes support bend/tilt variation.','Source procedural sprite placement determines swing, so tile samples do not claim a full rope pose.'],
 'RotatingSpike':['Pale yellow/olive radial star with sharp triangular points and a bright central hub.'],
 'Snowball':['Small round white ball with lavender shaded crescent/lower edge and dark contour.'],
 'Spike':['Cluster of multiple tall sharp pale prongs above a curved low elliptical base; source is a crown of spikes rather than one smooth cone.'],
 'Spring':['Orange lower block, pale yellow top block and crossed/coil-like middle connector; separate compressed and expanded frames.'],
 'Telegraph':['Authored temporary boss danger footprint with DODGE prompt; a clear luminous ring/sector is suitable for its circular runtime radius.'],
 'Tower':['Source background blocks show purple/magenta masonry courses with dark inset joints, alternating highlighted faces and vertical facets.','Cyan shapes in the background sheet belong to clouds/sky, not the tower masonry.'],
 'TowerPlatform':['Small orange/ochre rectangular projecting beam with bright end and dark patterned side; separate sparkle/disappearing component.','Runtime broad rotating surface and back/underside detail are authored.'],
 'Warning':['White exclamation mark with pink/dark-magenta edge and a separate dot.','Source toggles the camera-relative cue; runtime ground/air hazard footprint is authored.'],
 'Water':['Deep blue water field with cyan/teal serrated wave/foam strips in Surf City background components.','Runtime translucent 3D fluid volume and current dimensions are authored.'],
 'Whirlpool':['Flat elliptical pale white/lavender ring/spiral around a dark center, with separate outer foam flecks.'],
}

ROLES={'AirMine':'full-depth flight hazard','BoardingPad':'boarding objective marker','Bomb':'defuse objective',
 'Buzzball':'shared chaser and boss','ElectricTrap':'phased course hazard','Fan':'updraft force volume',
 'Gas':'phased course hazard','Gear':'moving course hazard','IceBlock':'pushable solid','Icicle':'moving falling hazard',
 'Lift':'moving solid support','Log':'full-depth surf hazard','Mine':'surf hazard','MovingIcePlatform':'moving solid support',
 'Ramp':'stepped launch surface','Rocket':'flight hazard and aimed projectile','RocketLauncher':'aimed projectile emitter',
 'Rope':'anchor-to-actor attachment','RotatingSpike':'orbiting hazard','Snowball':'moving ice hazard',
 'Spike':'moving/static hazard','Spring':'jump boost surface','Telegraph':'temporary boss danger footprint',
 'Tower':'noncollidable scenery around logical core','TowerPlatform':'rotating solid support',
 'Warning':'pre-hazard informational marker','Water':'fluid medium volume','Whirlpool':'surf hazard'}

# recipe, authored source stage id, source type, exact graphics assignment.
RECIPES={
 'Bomb':('Race',9,[0x5a],[0xb3],'object_ratrace_bomb','19909-19980'),
 'Buzzball':('Clinger',10,[0x7a,0x7b],[0x7c,0x7d,0x7e,0x7f],'object_electroball / electroball_set_gfx','14783-14837;34116-34126'),
 'ElectricTrap':('Wookie',2,[0x2e],[0x5a,0x5b],'object_electro_trap','10396-10473;33321-33349'),
 'Fan':('Race',7,[0x54,0x55],[0xa3,0xa4],'object_ventilyator','19279-19302'),
 'Gas':('Race',7,[0x53],[0xa6,0xa7,0xa8,0xa9,0xaa],'object_gas','19210-19270'),
 'Gear':('Tubes',11,[0x6b],[0xd0,0xd1],'object_shesterenka','11626-11730'),
 'IceBlock':('Ice',4,[0x38],[0x6f,0x70,0x71],'object_ice_cube / shared physics frame table','20333-20338;20652-20706'),
 'Icicle':('Ice',4,[0x39],[0x72,0x73],'object_sosulka / authored graphics parameter','20722-20774'),
 'Lift':('Race',7,[0x4a],[0x90,0xfa,0xac],'object_elevator_platform / bank3 helper','18804-18875;28103-28124'),
 'Log':('Surf',12,[0x77],[0xec],'object_brevno','12731-12809'),
 'Mine':('Surf',12,[0x78],[0xee],'object_surfcity_watermine','12841-12871'),
 'MovingIcePlatform':('Ice',4,[0x3e],[0x80],'object_level4_moving_platform','17935-17973'),
 'Ramp':('Tunnel',3,[0x24],[0x4b],'object_turbo_tunnel_obstacle / ramp launch branch','9747-9835;9846-9855;9945-9995'),
 'Rocket':('Tunnel',6,[0x6a],[0xcc,0xcd],'object_level7_rockets','11457-11491'),
 'RotatingSpike':('Tower',5,[0x37],[0x6a],'object_rotating_spike','18310-18348'),
 'Snowball':('Ice',4,[0x3a],[0x75],'object_snowball / electro_or_snow_gfx','20837-20865;20993-21014'),
 'Spike':('Ice',4,[0x40,0x45],[0x81],'object_level4_spike_moving','21294-21301'),
 'Spring':('Tower',5,[0x36],[0x67,0x68,0x69],'object_prujina','17765-17928'),
 'TowerPlatform':('Tower',5,[0x34],[0x65,0x66],'object_platform_last_level','18044-18087'),
 'Warning':('Tunnel',3,[0x49],[0x8a],'object_turbo_tunnel_warning_sprite','18762-18784'),
 'Whirlpool':('Surf',12,[0x76],[0xed],'object_vodovorot / sub_0_C9D5','12635-12708'),
}

def source_ref(cache_file,lines=None):
    upstream='Battletoads (U) [!].asm' if cache_file=='main.asm' else ('data/'+cache_file if cache_file in ('levels_cfgs1.asm','levels_cfgs2.asm') else cache_file)
    from urllib.parse import quote
    url='https://github.com/feos-tas/DisAssemble/blob/'+src.PIN+'/Battletoads/'+quote(upstream,safe='/')
    if lines:url+='#L'+str(lines).replace('-','-L')
    return {'cacheFile':cache_file,'lines':lines,'url':url}

def pinned_input(relative):
    """Fetch a public source block and verify its Git blob against pinned tree."""
    tree=json.loads((src.CACHE/'tree.json').read_text())
    assert tree['sha']==src.PIN
    entry=next(x for x in tree['tree'] if x['path']=='Battletoads/'+relative)
    path=HERE/'inputs'/relative
    if path.exists():data=path.read_bytes()
    else:
        url='https://raw.githubusercontent.com/feos-tas/DisAssemble/'+src.PIN+'/Battletoads/'+quote(relative,safe='/')
        with urlopen(url,timeout=45) as response:data=response.read()
    assert len(data)==entry['size'],relative
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==entry['sha'],relative
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    return data

def unpack4(data,size,allow_partial=False):
    zero,ones=data[:2];cursor=2;out=bytearray()
    while len(out)<size:
        if cursor>=len(data):
            if allow_partial:return bytes(out)
            raise ValueError('Source compressed block ended before the declared tile count')
        value=data[cursor];cursor+=1
        if value in (zero,ones):
            if cursor>=len(data):
                if allow_partial:return bytes(out)
                raise ValueError('Source compressed run length missing')
            n=data[cursor] or 256;cursor+=1
            out.extend(bytes([0 if value==zero else 255])*n)
        else:out.append(value)
    return bytes(out[:size])

def tile_pixels(data,palette,transparent=False):
    result=bytearray(8*8*4)
    assert len(data)==16
    for y in range(8):
        for x in range(8):
            bit=7-x;code=((data[y]>>bit)&1)|(((data[y+8]>>bit)&1)<<1)
            color=src.rgba(palette[code]) if code or not transparent else (0,0,0,0)
            result[(y*8+x)*4:(y*8+x+1)*4]=bytes(color)
    return result

def rope_components(baseline):
    tiles,valid,patches=src.tile_bank('Wookie');frames=[]
    for tile in (0x27,0x28,0x29):
        assert tile in valid
        f={'frameId':tile,'frameHex':f'TILE {tile:02X}','width':8,'height':8,
           'pixels':tile_pixels(tiles[tile*16:tile*16+16],baseline[8:12],True)}
        path=f'frames/rope-tile-{tile:02x}.png';src.png(HERE/path,8,8,f['pixels'])
        frames.append({**f,'png':path})
    src.sheet(frames,HERE/'rope-source.png',scale=12,columns=3)
    return frames,patches

def background_blocks(kind,gfx_file,count,block_prefix,palette_label):
    packed=pinned_input('gfx/'+gfx_file)
    following=[]
    if gfx_file=='large_planet.4':
        # main22758-22761 places byte_A6B2 immediately after large_planet.
        following=['gfx/byte_A6B2.4'];packed+=pinned_input(following[0])
    if gfx_file=='surf_city_bkg.4':
        # main29351-29358: FF71 RTI, FF72..FF77 literal .PAD $FF78,$FF.
        following=['main.asm:29351-29358 RTI and six FF padding bytes'];packed+=b'\x40'+b'\xff'*6
    tiles=unpack4(packed,count*16,allow_partial=True)
    valid_count=len(tiles)//16
    block_data=pinned_input('data/'+block_prefix+'_blk_tiles.bin')
    attributes=pinned_input('data/'+block_prefix+'_blk_attrib.bin')
    palette=src.numeric_block((src.CACHE/'main.asm').read_text(errors='replace'),palette_label)[:16]
    assert len(block_data)%16==0
    frames=[]
    for n in range(min(len(attributes),len(block_data)//16)):
        pixels=bytearray(32*32*4);valid=True
        for ty in range(4):
            for tx in range(4):
                tile=block_data[n*16+ty*4+tx]
                if tile>=valid_count:valid=False;break
                quadrant=(ty//2)*2+(tx//2);slot=(attributes[n]>>(quadrant*2))&3
                part=tile_pixels(tiles[tile*16:tile*16+16],palette[slot*4:slot*4+4])
                for y in range(8):
                    start=((ty*8+y)*32+tx*8)*4
                    pixels[start:start+32]=part[y*32:(y+1)*32]
            if not valid:break
        if valid:
            frames.append({'frameId':n,'frameHex':f'BLOCK {n:02X}','width':32,'height':32,'pixels':pixels})
    src.sheet(frames,HERE/(kind.lower()+'-background-blocks.png'),scale=3,columns=10)
    return {'sourceGfxFile':'gfx/'+gfx_file,'declaredTileCount':count,'decodedCompleteTileCount':valid_count,
            'unknownDeclaredTailBytes':max(0,count*16-len(tiles)),'followingSourceBlocks':following,
            'sourceBlockTilesFile':'data/'+block_prefix+'_blk_tiles.bin',
            'sourceBlockAttributesFile':'data/'+block_prefix+'_blk_attrib.bin',
            'paletteLabel':palette_label,'paletteIndices':palette,'decodedBlocks':len(frames),
            'contactSheet':kind.lower()+'-background-blocks.png',
            'scope':'Exact static source 32x32 background components; no level map reconstruction or live CHR animation.'},frames

def main():
    text=(src.CACHE/'main.asm').read_text(errors='replace');memory=src.sprite_memory()
    _,_,gfx=src.byte_blocks(src.CACHE/'gfx/rash.asm')
    refs=re.findall(r'\.WORD\s+(\w+)',src.main_block(text,'gfx_ptrs'))
    baseline=src.numeric_block(text,'palette_chars')[:16]
    contexts,events=src.authored_palette_contexts(baseline)
    output=[];all_frames=[];(HERE/'frames').mkdir(exist_ok=True)
    for kind in KINDS:
        row={'runtimeKind':kind,'sourceEvidence':[],'status':'authored-adaptation','sourceRefs':[],
             'sourceTypes':[],'graphicsFrameIds':[],'palette':None,'rgbColors':[],
             'frames':[],'appearanceCues':CUES[kind],'runtimeRole':ROLES[kind],
             'adaptationLimits':['All 3D depth, back faces and runtime proportions are authored.']}
        runtime_refs=[]
        for filename in ('CampaignDefinition.lua','CampaignModes.lua','CampaignWorld.lua','GameWorld.lua'):
            path=ROOT/'src/server/gameplay'/filename
            lines=path.read_text(errors='replace').splitlines()
            found=[n for n,line in enumerate(lines,1) if re.search(r"['\"]"+re.escape(kind)+r"['\"]",line)]
            if found:runtime_refs.append({'localFile':'src/server/gameplay/'+filename,'lines':found[:12]})
        row['runtimeRefs']=runtime_refs
        if kind in RECIPES:
            recipe,level,types,ids,handler,lines=RECIPES[kind]
            row.update(status='source-object-metasprite',sourceTypes=[f'{t:02X}' for t in types],
                       graphicsFrameIds=[f'{f:02X}' for f in ids],sourceHandler=handler,bankRecipe=recipe)
            row['sourceEvidence']=[{'statement':'Handler and graphics assignments proved in pinned main.asm.','cacheFile':'main.asm','lines':lines}]
            row['sourceRefs']=[source_ref('main.asm',p) for p in lines.split(';')]
            tiles,valid,patches=src.tile_bank(recipe)
            candidates=[c for c in contexts[level] if c['typeId'] in types]
            # Mine/gas and other dynamic children inherit a source spawner's
            # actor flags when there is no direct authored record. Do not label
            # baseline rendering as a proved child palette.
            selected=candidates[0] if candidates else {'actorPaletteXor':0,'paletteIndices':baseline,'source':'palette_chars baseline; dynamic actor palette not resolved','unresolvedActorPalette':True}
            if not candidates and kind in ('Mine','Rocket','Gas'):
                spawner_type=0x52 if kind=='Gas' else 0x68
                spawners=[c for c in contexts[level] if c['typeId']==spawner_type]
                if spawners:
                    selected={**spawners[0],'sourceSpawnerType':f'{spawner_type:02X}','typeId':types[0],
                              'actorPaletteXor':0,'actorFlagsEvidence':'main.asm:19188-19189' if kind=='Gas' else 'main.asm:11304-11307',
                              'scope':'First authored spawner trigger snapshot; child flags are explicitly zeroed in source.'}
            row['palette']={**selected,'rgbIsIllustrative':True,'scope':'Representative authored trigger snapshot; not a complete live palette trace.'}
            row['bankLoads']=patches;frames=[];unknown=[]
            for fid in ids:
                try:
                    namespace='heroStatic' if kind=='Buzzball' else 'object'
                    f=src.decode(fid,namespace,text,memory,tiles,valid,gfx,refs,selected['paletteIndices'],selected['actorPaletteXor'])
                    filename=f'frames/{kind.lower()}-{fid:02x}.png';src.png(HERE/filename,f['width'],f['height'],f['pixels'])
                    row['frames'].append({**{k:v for k,v in f.items() if k!='pixels'},'png':filename})
                    frames.append(f);all_frames.append(f)
                except (ValueError,IndexError,KeyError) as error:unknown.append({'frameId':f'{fid:02X}','reason':str(error)})
            row['rgbColors']=sorted({tuple(f['pixels'][i:i+3]) for f in frames for i in range(0,len(f['pixels']),4) if f['pixels'][i+3]})
            row['unknown']=unknown
            if frames:
                filename=f'{kind.lower()}-source.png';src.sheet(frames,HERE/filename,scale=7,columns=min(5,len(frames)));row['contactSheet']=filename
            if kind=='ElectricTrap':row['adaptationLimits'].append('gfx5A is a mirrored endpoint pair; gfx5B is the electrical component placed along the source variable span. These decoded components are not a complete source trap placement.')
            if kind=='Warning':row['adaptationLimits'].append('Source warning is a blinking camera-relative sprite. Runtime ground/air hazard marker position and footprint are original Roblox behavior.')
            if kind=='Rocket':row['adaptationLimits'].append('Source Volkmire inherits Tunnel sprite CHR while its separate $1000 bank changes background graphics. Runtime aimed emitter/projectile use is authored.')
            if kind in ('RotatingSpike','TowerPlatform','Spring'):row['adaptationLimits'].append('Tower source enum ID05 is Revolution, the original twelfth playable course. Internal source enum IDs and campaign ordinal stage numbers differ (main.asm:14643 Level_ID_Table).')
            if kind=='Gear':row['adaptationLimits'].append('D0/D1 each depict half a wheel; source spawns a second linked object with flags40 to mirror the other half (main.asm:11583-11589,11626-11636).')
            if kind=='Lift':row['adaptationLimits'].append('gfx90 is the normal elevator; FA/AC are its electrical variants. Runtime Lift should use the normal support appearance because it is not an electrical hazard.')
            if kind=='Ramp':row['adaptationLimits'].append('Type24 is singled out for the launch branch and uses frame4B. Runtime three ascending steps/launch dimensions are authored.')
            if kind=='Bomb':row['adaptationLimits'].append('Source AND3 cycles actor palette flags; the displayed green frame is representative phase0, not a constant full animation palette.')
        elif kind=='Rope':
            frames,patches=rope_components(baseline)
            row.update(status='procedural-source-components',sourceTypes=['06','07'],
                       chrTileIndices=['27','28','29'],bankRecipe='Wookie',bankLoads=patches,
                       sourceHandler='object_rope / rope_sprites / wookie_hole_ropes_gfx',
                       palette={'paletteIndices':baseline,'spriteAttributes':2,'source':'main.asm:36743 initial palette_chars; main.asm:33289-33295 procedural sprite attributes','rgbIsIllustrative':True},
                       contactSheet='rope-source.png')
            row['frames']=[{'namespace':'rawChrTile','chrTileIndex':f'{f["frameId"]:02X}',
                            'width':f['width'],'height':f['height'],'png':f['png']} for f in frames]
            row['rgbColors']=sorted({tuple(f['pixels'][i:i+3]) for f in frames for i in range(0,len(f['pixels']),4) if f['pixels'][i+3]})
            row['sourceEvidence']=[{'statement':'Source types06/07 render repeated raw CHR tiles chosen by a slope table; these are not object gfx frame IDs.','cacheFile':'main.asm','lines':'8876-8928;23024-23068;33219-33315'}]
            row['sourceRefs']=[source_ref('main.asm',p) for p in ('8876-8928','23024-23068','33219-33315')]
            row['adaptationLimits'].append('Only raw rope tile shapes and initial palette are decoded. Full source procedural swing shape, gaps and live palette scheduling are separate.')
            all_frames.extend(frames)
        elif kind in ('Tower','Water'):
            if kind=='Tower':
                bg,frames=background_blocks(kind,'large_planet.4',255,'revolution','byte_6000_A33D')
                evidence='The Revolution source enum05 selects background gfxID16 and paletteID0E in the 9-byte level table; archive16 selects large_planet_gfx_set. The same stage selects revolution block tables.'
                lines=('38610-38632','22163-22196','22432-22436','22758-22761','30228-30351')
                row['rgbColors']=[list(src.rgba(i)[:3]) for i in (0x04,0x14,0x24)]
            else:
                bg,frames=background_blocks(kind,'surf_city_bkg.4',224,'surf_city','byte_6000_A3BD')
                evidence='Surf City source enum0C selects background gfxID9E (bank4 archive1E) and paletteID1E; source bank4 references surf_city_bkg and its block tables.'
                lines=('38610-38632','29182-29199','29256-29259','29323-29358','30228-30351')
                row['rgbColors']=[list(src.rgba(i)[:3]) for i in (0x02,0x1c,0x2c)]
            row.update(status='source-background-adaptation',background=bg,contactSheet=bg['contactSheet'],
                       palette={'paletteIndices':bg['paletteIndices'],'source':bg['paletteLabel'],
                                'rgbIsIllustrative':True,'scope':'Source initial background palette, not sprite palette or live frame trace.'})
            row['sourceEvidence']=[{'statement':evidence,'cacheFile':'main.asm','lines':';'.join(lines)}]
            row['sourceRefs']=[source_ref('main.asm',p) for p in lines]
            row['sourceRefs'].extend(source_ref(f) for f in (bg['sourceGfxFile'],bg['sourceBlockTilesFile'],bg['sourceBlockAttributesFile']))
            row['adaptationLimits'].append('Source is a background presentation, not an object sprite or original source mesh. Runtime cylinder/water volume is authored.')
            if bg['unknownDeclaredTailBytes']:
                row['adaptationLimits'].append(f"Declared CHR tail remains unresolved ({bg['unknownDeclaredTailBytes']} bytes); only {bg['decodedBlocks']} blocks using fully decoded tiles are shown. No unknown bytes are synthesized.")
        elif kind=='RocketLauncher':
            row.update(status='invisible-source-spawner-adaptation',sourceTypes=['68'],sourceTypeRole='behavior-only, not a source visible launcher',
                       sourceHandler='object_mines_rokets_creator')
            row['sourceEvidence']=[{'statement':'Source type68 creates fire69, rocket6A and Surf mine78. No graphics assignment or visible cannon body is established for this creator.','cacheFile':'main.asm','lines':'5833-5835;11258-11384'}]
            row['sourceRefs']=[source_ref('main.asm',p) for p in ('5833-5835','11258-11384')]
            row['adaptationLimits'].append('A visible launcher barrel, housing, aim and 3D mount are wholly authored. Do not label it an NES launcher sprite or conflate it with Retro Blaster31.')
        elif kind=='AirMine':
            row.update(status='authored-adaptation-unproved-source-identity',sourceAnalogue={'runtimeKind':'Mine','relationship':'visual analogue only; no asserted AirMine source type mapping'})
            row['sourceEvidence']=[{'statement':'Runtime AirMine is a flight hazard across a depth44 volume. The proved source water mine78 is a possible visual family reference, not proof of an airborne mine identity.','localFile':'src/server/gameplay/CampaignDefinition.lua','lines':'75-81'}]
            row['sourceRefs']=[source_ref('main.asm','12841-12871'),*runtime_refs]
            row['adaptationLimits'].append('No exact NES source AirMine object/gfx mapping was proved. Full-depth mesh distribution is required by current Roblox hazard dimensions, not source sprite anatomy.')
        else:
            assert kind in ('BoardingPad','Telegraph')
            row['status']='authored-system-marker'
            row['sourceEvidence']=[{'statement':'This runtime marker is introduced by Roblox gameplay code. No exact NES object type, CHR frame or palette identity is claimed.','runtimeRefs':runtime_refs}]
            row['sourceRefs']=runtime_refs
            row['adaptationLimits'].append('Typography, ring/pad silhouette, glow and colors are authored gameplay communication, not transferred source actor graphics.')
        output.append(row)
    assert len(output)==28 and len({r['runtimeKind'] for r in output})==28
    assert all(r['sourceEvidence'] and r['sourceRefs'] and r['appearanceCues'] and r['adaptationLimits'] for r in output)
    from collections import Counter
    # All cached source inputs are checked against the established pinned
    # source catalog. New backgrounds are independently Git-blob verified.
    canonical=json.loads((ROOT/'research/canonical-visuals/cast-source-catalog.json').read_text())
    assert canonical['pin']==src.PIN
    inputs={}
    for relative,record in canonical['inputs'].items():
        path=src.CACHE/relative;data=path.read_bytes()
        assert hashlib.sha256(data).hexdigest()==record['sha256'],relative
        inputs[relative]={'bytes':len(data),'sha256':record['sha256'],'location':'build/canonical-source'}
    tree=json.loads((src.CACHE/'tree.json').read_text())
    for path in sorted((HERE/'inputs').rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(HERE/'inputs').as_posix();data=path.read_bytes()
        entry=next(x for x in tree['tree'] if x['path']=='Battletoads/'+relative)
        assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==entry['sha']
        inputs[relative]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'gitBlobSha1':entry['sha'],'location':'source/inputs'}
    catalog={'schema':1,'pin':src.PIN,'game':'Battletoads USA NES (1991)',
             'sourceRepository':'https://github.com/feos-tas/DisAssemble/tree/'+src.PIN+'/Battletoads',
             'method':'Pinned source handlers + metasprite tables + literal CHR load recipes. No ROM, emulator or generated image used.',
             'kinds':output,'coverage':{'required':28,'records':len(output),
                                      'statusCounts':dict(Counter(r['status'] for r in output)),
                                      'decodedMetaspriteFrames':sum(len(r['frames']) for r in output if r['status']=='source-object-metasprite'),
                                      'rawRopeChrTiles':3,
                                      'staticTowerBlocks':next(r['background']['decodedBlocks'] for r in output if r['runtimeKind']=='Tower'),
                                      'staticWaterBlocks':next(r['background']['decodedBlocks'] for r in output if r['runtimeKind']=='Water')},
             'inputs':inputs,
             'limitations':['Runtime kind names are authored Roblox vocabulary; source identities are claimed only by individually cited fields.','CHR and metasprite topology are source facts. RGB is illustrative NES 2C02 conversion.','Palette snapshots do not reproduce Surf/Clinger palette loops or exact scheduling.','Unseen 3D surfaces and runtime scaling are authored.']}
    src.sheet(all_frames,HERE/'source-contact-sheet.png',scale=4,columns=8)
    (HERE/'source-catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
    images=sorted(HERE.rglob('*.png'))
    for image in images:assert image.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
    verification={'pin':src.PIN,'requiredKinds':KINDS,'coverage':catalog['coverage'],
                  'allRecordsHaveEvidenceAndCues':True,'unknownMetaspriteDecodes':sum(len(r.get('unknown',[])) for r in output),
                  'sourceInputHashesVerified':len(inputs),'pngCount':len(images),
                  'catalogSha256':hashlib.sha256((HERE/'source-catalog.json').read_bytes()).hexdigest(),
                  'pngSha256':{p.relative_to(HERE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in images},
                  'explicitUnknowns':['AirMine exact source identity is not established.',
                                     'Water source background declared tail has 265 unresolved bytes; only complete decoded source tiles are used.',
                                     'Exact live palette scheduling and source procedural placement are not reproduced.',
                                     'All 3D back faces, depth and runtime volume adaptation remain authored.'],
                  'scope':'Static source research verification only; no claim of Studio integration, in-game playthrough, 3D mesh parity, or natural source population.'}
    (HERE/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
    print(json.dumps({'coverage':catalog['coverage'],'pngCount':len(images),'inputHashesVerified':len(inputs),'catalogSha256':verification['catalogSha256']},indent=2))

if __name__=='__main__':main()
