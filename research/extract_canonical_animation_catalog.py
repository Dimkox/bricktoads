"""Read-only source index. Emits research facts, never runtime assets or combat logic."""
from pathlib import Path
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'build/canonical-source'
PIN='f1a43b69577246850d136473700a333b3cdfe93f'
FILES={'main.asm':'Battletoads (U) [!].asm','anims_moves.asm':'data/anims_moves.asm',
       'levels_cfgs1.asm':'data/levels_cfgs1.asm','levels_cfgs2.asm':'data/levels_cfgs2.asm'}
EXPECTED_SHA256={
 'main.asm':'71042cf2a4a8fad952e9eb3bcb591cece666c5a790d7ea177b1908d052fca074',
 'anims_moves.asm':'5dfbe797fa1299d6f6342dbd3a0b6af9e45ff44a0c214bf0cac676ef85e5d181',
 'levels_cfgs1.asm':'378eaf70e0865a25f42a40a9e0f0723941631f2ac740d38e8e9c47dec7e1c1db',
 'levels_cfgs2.asm':'58f1ae597eaaf83eb1ec8796c54bdc0bc446b90d2d5fd5342706e877c5e98e36'}
for file,expected in EXPECTED_SHA256.items():
    assert hashlib.sha256((SOURCE/file).read_bytes()).hexdigest()==expected,('Pinned source hash mismatch',file)
texts={name:(SOURCE/name).read_bytes().decode('cp1251') for name in FILES}
lines={name:text.splitlines() for name,text in texts.items()}
def literal(token):
    token=token.strip()
    return int(token[1:],16) if token.startswith('$') else int(token)
def data_blocks(name):
    blocks={};active=None
    for lineno,line in enumerate(lines[name],1):
        code=line.split(';',1)[0]
        found=re.match(r'^([A-Za-z_][\w?]*):',code)
        if found:
            active=found.group(1)
            blocks[active]={'line':lineno,'endLine':lineno,'values':[],'positions':[]}
        if '.BYTE' in code and active:
            row=blocks[active];row['endLine']=lineno
            for token in code.split('.BYTE',1)[1].split(','):
                if token.strip():
                    try: value=literal(token)
                    except ValueError:
                        if name!='main.asm': raise
                        continue
                    row['values'].append(value);row['positions'].append(lineno)
    return blocks
anim_blocks=data_blocks('anims_moves.asm')
ptr_prefix=texts['anims_moves.asm'].split('udar_small_punch:',1)[0]
anim_ptrs=re.findall(r'\.WORD\s+([\w?]+)',ptr_prefix)
OPCODES={
0xE0:('XSpeed',1),0xE1:('ZSpeed',1),0xE2:('HitOpportunity',2),0xE3:('PickupObject',0),
0xE4:('LinkObject',0),0xE5:('DamageLinked',0),0xE6:('SetFlag4',0),0xE7:('AddXSpeed',1),
0xE8:('SwapDirection',0),0xE9:('Tongue',0),0xEA:('WriteDirection',1),0xEB:('XSpeedByShadow',0),
0xEC:('SwapDirection',0),0xED:('CreateImpactFrame37',0),0xEE:('CreateImpactFrame38',0),
0xEF:('CreateObject32',0),0xF0:('SoundFlag',1),0xF1:('PlaySound',2),0xF2:('AddZ',0),
0xF3:('CreateWeapon',1),0xF4:('HeldJumpZSpeed',0),0xF5:('ClearDamageLatch',0),0xF6:('DirectionByX',0)}
def decode(row):
    values=row['values'];i=0;advances=0;frames=[];events=[]
    while i<len(values):
        byte=values[i]
        if byte==0:
            return {'frameRuns':frames,'events':events,'displayAdvances':advances,'terminatorByte':i,
                    'sourceEffectiveEndLine':row['positions'][i]}
        if byte<0xE0:
            if frames and frames[-1]['frameId']==byte and frames[-1]['startAdvance']+frames[-1]['advances']==advances:
                frames[-1]['advances']+=1
            else: frames.append({'frameId':byte,'startAdvance':advances,'advances':1})
            advances+=1;i+=1;continue
        label,count=OPCODES[byte]
        params=values[i+1:i+1+count]
        assert len(params)==count
        events.append({'byteIndex':i,'sourceLine':row['positions'][i],'opcode':byte,'command':label,
                       'params':params,'atDisplayAdvance':advances})
        i+=1+count
    raise ValueError('No terminator')
def label_line(label):
    for i,line in enumerate(lines['main.asm'],1):
        if re.match(r'^'+re.escape(label)+r':(?:\s|$)',line):return i
    return None
catalog={'schema':1,'reference':{'repository':'feos-tas/DisAssemble','commit':PIN,
 'game':'Battletoads USA NES (1991)','sourceKind':'static disassembly analysis, no emulator timing trace',
 'files':[{'cache':name,'upstream':rel,'sha256':hashlib.sha256((SOURCE/name).read_bytes()).hexdigest()}
          for name,rel in FILES.items()]},
 'interpretation':{'frameId':'Source graphics frame, NOT R15/R6 animation or tile ID',
 'displayAdvance':'One literal frame byte; control commands consume no extra display advance',
 'timing':'Caller FrameCounter mask controls pointer advance; interruption/lag/phase can change elapsed time',
 'damage':'E2 events are opportunities; only authoritative source latch/contact confirms a successful effect',
 'proportions':'See canonical visual source sheet/metadata; frame IDs alone do not establish mesh dimensions'},
 'opcodes':[{'opcode':byte,'name':value[0],'parameterBytes':value[1]} for byte,value in OPCODES.items()],
 'animations':[]}
for index,label in enumerate(anim_ptrs,1):
    row=anim_blocks[label]
    ordered=sorted(anim_blocks.values(),key=lambda v:v['line'])
    tail=[v for v in ordered if v['line']>=row['line']]
    extended={**row,'values':sum((v['values'] for v in tail),[]),'positions':sum((v['positions'] for v in tail),[])}
    decoded=decode(extended)
    decoded['fallsThroughDeclaredBlock']=decoded['terminatorByte']>=len(row['values'])
    catalog['animations'].append({'animationId':index*2,'animationHex':f'{index*2:02X}',
       'label':label,'sourceFile':'data/anims_moves.asm','sourceLine':row['line'],'sourceEndLine':row['endLine'],**decoded})
catalog['interpretation']['callerPostprocessing']='Some callers transform frame values (Walker articulated geometry; bosses OR0x80). Decode the caller before treating an ID as a complete sprite frame.'
dash=anim_blocks['udar_s_razbega']
catalog['dashLowLifeTail']={'sourceLines':[15829,15840],
    'condition':'Actual effect-time victim Life <0x10 and attacker animation0x16',
    'pointerOverride':0x36,'immediateEffectReaderEntryByte':0x37,
    'warning':'Main anim_make_hit restores Y from overridden tmp_var_22 and then INY before reading; this alternate tail follows the ordinary zero terminator.',
    'playbackFromEffectEntry':decode({**dash,'values':dash['values'][0x37:],'positions':dash['positions'][0x37:]})}
assert len(catalog['animations'])==69
dispatch=texts['main.asm'].split('obj_code_ptrs:',1)[1].split('objects_unk_dat1:',1)[0]
handlers=re.findall(r'\.WORD\s+([\w?]+)',dispatch)
catalog['objectDispatch']=[{'typeId':i,'typeHex':f'{i:02X}','handler':h,'handlerLine':label_line(h),
                           'animationTrace':'DISPATCH_ONLY'} for i,h in enumerate(handlers)]
assert len(handlers)==128
family_map={
 'Hero':[1,2],'PsykoPig':[0xB,0x1F,0x20],'TallWalker':[0x11,0x12],
 'Raven':[0x13],'LargeRaven':[0x16],'Invader':[0x15],'Dragon':[0x17],
 'RocketRat':[0x28,0x66],'SaturnToadtrap':[0x2D],'RetroBlaster':[0x31],
 'Snowman':[0x33],'Snake':[0x4C,0x4D,0x4E],
 'SentryDrone':[0x50],'Slime':[0x51],'GasTurret':[0x52],
 'Hordhead':[0x5C],'FlyingHead':[0x5D,0x5E,0x60],'Swellcheeks':[0x62],
 'Robot':[0x6D],'Electrofish':[0x6E],'Hammerfish':[0x6F],'Shark':[0x70,0x71],'Duck':[0x72],
 'BossWalker':[0xD,0xE,0xF],'BigBlag':[0x79],'Buzzball':[0x7A,0x7B],
 'GeneralSlaughter':[0x7C],'RoboManus':[0x7D],'DarkQueen':[0x7E]}
catalog['families']=[{'name':name,'types':ids,'status':'PARTIAL_TRACE' if name in ('Hero','PsykoPig','TallWalker','Dragon','BossWalker') else 'DISPATCH_ONLY',
                     'unknown':['complete appearance/animation state trace','dynamic spawn count','all intro conditions']}
                    for name,ids in family_map.items()]
level_names={1:"Ragnarok's Canyon",2:'Wookie Hole',3:'Turbo Tunnel',4:'Arctic Caverns',12:'Surf City',
             8:"Karnath's Lair",6:"Volkmire's Inferno",7:'Intruder Excluder',11:'Terra Tubes',9:'Rat Race',
             10:'Clinger-Winger',5:'The Revolution',13:'Armageddon'}
catalog['levels']=[]
cfg_blocks={}
for file in ('levels_cfgs1.asm','levels_cfgs2.asm'):
    active=None
    for line in lines[file]:
        code=line.split(';',1)[0]
        label=re.match(r'^(level\d+_cfg):',code)
        if label: active=label.group(1);cfg_blocks[active]={'values':[]}
        if active and '.BYTE' in code:
            cfg_blocks[active]['values'].extend(literal(v) for v in code.split('.BYTE',1)[1].split(',') if v.strip())
for order,(level_id,name) in enumerate(level_names.items(),1):
    row=cfg_blocks[f'level{level_id}_cfg'];values=row['values'];types=[];index=0
    markers=[]
    while index<len(values):
        if values[index] in (0xFE,0xFF):
            markers.append({'byteOffset':index,'marker':values[index]});index+=1;continue
        assert index+11<=len(values),(level_id,index,len(values))
        types.append(values[index]);index+=11
    catalog['levels'].append({'order':order,'sourceLevelId':level_id,'name':name,
        'staticTypeIds':sorted(set(types)),
        'authoredRecordsAcrossSegments':len(types),
        'streamMarkers':markers,
        'familiesReferenced':[name for name,ids in family_map.items() if set(ids)&set(types)],
        'status':'STATIC_CONFIG_ONLY_NOT_COMPLETE_DYNAMIC_ROSTER',
        'warning':'Indexes all authored stream segments, including after FE stop markers and checkpoint labels; not one unconditional spawn order. FF target words are excluded. Transformations/created actors may add families absent from direct static types.'})
main_blocks=data_blocks('main.asm')
catalog['heroLocomotion']={name:main_blocks[name]['values'] for name in ('rash_walk_frames','rash_run_frames','rash_with_obj_frames','rash_move_UD_frames')}
catalog['heroLocomotion'].update({'tableLines':[13635,13636,13637,13638],
  'phaseSelectorLines':[8298,8346],'idleFrames':[1,2],'jumpFrames':[5,0x2D],'holdingJumpFrame':0x2E,
  'jumpSelector':'Airborne without held object: unsigned((Zspeed+2)&255)<5 selects0x2D near apex, otherwise0x05; held object selects0x2E.',
  'idleLines':[8369,8385],'jumpLines':[8190,8204],
  'timing':'Speed/counter/direction-driven, not a fixed fps walk clip; source run renderer also checks both players speed/floor conditions.'})
catalog['dragonFinalFrames']={'sourceHandler':'object_dragon','sourceLines':[2943,3056],
  'normalCycle':[9,9,10,10],'approachFrame':9,'heavyDisabledFrame':10,'lightReactionFrame':12,
  'headbuttAndCaptureFrame':11,
  'warning':'Shared loc_0_96F7/byte_0_9942 writes intermediate1C/1D/1E; object_dragon overwrites these when AnimID==0. They are not the final Dragon locomotion frames.'}
catalog['priorityBindings']=[
 {'family':'Hero','sourceAnimations':[2,4,6,0xE,0x12,0x14,0x16,0x18,0x1A,0x36,0x70],
  'callerMask':1,'sourceCallsPerAdvance':2,'callerLine':7268,
  'unknown':['global FrameCounter phase at action entry','complete B hold/cancel windows','hit-triggered Dash pointer override'],
  'meaning':{'02':'jab A','04':'jab B','06':'uppercut','0E':'power punch morph','12':'heavy follow-up kick',
             '14':'large boot morph','16':'running strike','18':'tongue','1A':'club swing','36':'Dragon-target elbow','70':'boss ball throw'}},
 {'family':'PsykoPig','sourceAnimations':[0x28,0x2A,0x40],'callerMask':3,'sourceCallsPerAdvance':4,'callerLine':16787},
 {'family':'TallWalker','sourceAnimations':[0x3A,0x3C],'callerMask':0,'sourceCallsPerAdvance':1,'callerLine':4676,
  'warning':'Procedural articulated-leg geometry also uses counters and frame-minus18 transform; generic hero pose is not canonical walker animation.'},
 {'family':'Dragon','sourceAnimations':[0x32,0x34],'callerMask':3,'sourceCallsPerAdvance':4,'callerLine':5358,
  'warning':'Flight/turn/disabled states use source caller overrides09/0A/0C and physics; shared frame table1C/1D/1E is intermediate, not final Dragon art.'}]
catalog['bossIntros']=[
 {'boss':'BossWalker','status':'PARTIAL_STATIC_TRACE','sourceLines':[4074,4084,4103,4206],
  'counter':{'field':'Objects_cnt2','initial':0,'advance':'increment once per active unpaused object update before comparison','deleteAt':255},
  'events':[{'counter':48,'kind':'impact','soundId':0x62,'shakeByte':0xF8},
            {'counter':80,'kind':'foot-motion-start','graphicsFrame':0x12},
            {'counter':100,'kind':'impact','soundId':0x62,'shakeByte':0xF8},
            {'counter':224,'kind':'arena-camera-cut-and-music','musicLevelId':14,'bank6Function':0x5D,'fearCallSkipped':True,
             'function':'sub_6000_8E74','sourceLines':[34374,34445],
             'cameraSourcePixels':{'x':1728,'y':8},'clearsHeroStateFlagsNotHealth':True,
             'heroCoordinates':'Recomputes X from previous Y; sets Y=0x0108 and adds0x40 to Z; source 2D perspective setup, not a Roblox position mapping.'},
            {'counter':255,'kind':'delete-intro-foot'}],
  'heroFear':[{'counterFrom':1,'counterThrough':223,'animationId':0x2C,'graphicsFrame':0x32},
              {'counterFrom':225,'counterThrough':254,'animationId':0x2E,'graphicsFrame':0x33}],
  'heroHandling':{'sourceSlots':[0,1],'animPointerMask':7,'dropsStick':True,'unlinksCarriedObject':True,
                  'linkedObjectXSpeed':64,'linkedObjectZSpeed':2,'newInvulnerability':'NOT ESTABLISHED; do not invent'},
  'control':'Nonzero animation follows hero animation branch before ordinary locomotion; B selector can still run. Not proof of total input lock.',
  'nominal60HzSeconds':{'impactA':.8,'motionStart':80/60,'impactB':100/60,'music':224/60,'delete':255/60},
  'unknown':['exact foot model/camera trajectories in world units','PCM/lag/PAL elapsed-time parity','same-update input ordering effects','three-player adaptation']},
 {'boss':'BigBlag','status':'PARTIAL_STATIC_TRACE','sourceLines':[13055,13071],
  'finding':'At initial graphicsFrame0 set Obj_various_cnt=0x80; decrement, force direction0x80, call write_anim_fear while nonzero.',
  'unknown':['full spawn/intro camera path','exact complete intro visual frame sequence']},
 {'boss':'GeneralSlaughter','status':'PARTIAL_STATIC_TRACE','sourceLines':[13345,13458],
  'finding':'Initial graphicsFrame0 starts boss music. Before cnt2 reaches0xB5 calls write_dir_and_anim_fear; helper increments cnt2. First0x20 phase cameraY2=0x0C; later grounded state starts Zspeed6.',
  'unknown':['complete sprite-frame phase table and spawn camera trajectory']},
 {'boss':'RoboManus','status':'PARTIAL_STATIC_TRACE','sourceLines':[13462,13518],
  'finding':'Initial frame0 gates on camera, applies player positioning/protection branch; setup disables PPU, initializes frame1/cnt3=0x40 and bank3 function4; while cnt2 positive calls write_dir_and_anim_fear.',
  'unknown':['all setup frame transitions and camera/graphics upload timing']},
 {'boss':'Buzzball','status':'PARTIAL_STATIC_TRACE','sourceLines':[14809,14878],
  'finding':'Chase-to-fight transition: zero Xspeed increments cnt3, pulses gfx/sound on FrameCounter&4, calls write_anim_fear, then changes existing type7A→7B when cnt3 sign becomes negative; boss music changes.',
  'unknown':['first chase appearance choreography','complete combat-phase visual progression']},
 {'boss':'DarkQueen','status':'UNKNOWN_INTRO_TRACE','sourceLines':[14307,14500],
  'finding':'Combat source handler and anim8A verified, but first appearance/interstitial setup not yet followed to completion.',
  'unknown':['both appearance sequences and end-game scene choreography']}]
catalog['verification']={'animationPointers':len(anim_ptrs),'objectDispatchEntries':len(handlers),'levels':len(catalog['levels']),
 'allAnimationsTerminated':all('terminatorByte' in a for a in catalog['animations']),
 'runtimeParity':'NOT IMPLEMENTED BY THIS EXTRACTION','emulatorTrace':'NOT RUN'}
by_id={a['animationId']:a for a in catalog['animations']}
assert by_id[2]['displayAdvances']==12 and by_id[6]['displayAdvances']==29
assert {r['frameId'] for r in by_id[6]['frameRuns']}=={0x18,0x1D,0x22},'Do not decode E2 argument0x23 as an uppercut frame'
assert by_id[0x26]['fallsThroughDeclaredBlock'] and by_id[0x38]['fallsThroughDeclaredBlock']
assert by_id[0x14]['events'][2]['opcode']==0xE2 and by_id[0x14]['events'][2]['params']==[0x86,0x37]
assert handlers[0x17]=='object_dragon' and handlers[0xD]=='object_level1_boss_noga'
assert set(catalog['levels'][8]['staticTypeIds'])>={0x6D,0x6E,0x6F,0x70,0x72},'Do not truncate later Terra Tubes stream segments at the first FE'
assert catalog['levels'][0]['authoredRecordsAcrossSegments']==40
catalog['verification']['pinnedHashesVerified']=4
catalog['verification']['semanticParserChecks']=7
destination=ROOT/'research/2026-11-09-canonical-character-animation-catalog.json'
destination.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(catalog['verification']))
