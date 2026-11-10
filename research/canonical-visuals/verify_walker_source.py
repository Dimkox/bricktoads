"""Check the prepared renderer against a tiny interpreter of the literal ASM path.

This is not a NES emulator. It runs only the required arithmetic/sprite-writing
instructions and stops before the generic body renderer; no guessed R6 motion.
"""
from pathlib import Path
import hashlib,json,re,sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from extract_source_frames import CACHE,OUT,ROOT,number,numeric_block,signed


class SourceCPU:
    def __init__(self,text):
        self.symbols={}
        for line in (CACHE/'symbols.map').read_text(errors='replace').splitlines():
            match=re.match(r'\s*([0-9A-F]+):([0-9A-F]+)\s+(?:Abs\s+)?(\S+)',line)
            if match:self.symbols[match[3].lower()]=int(match[2],16)
        self.code=[];self.labels={}
        for raw in text.splitlines():
            line=raw.split(';',1)[0].strip()
            match=re.match(r'^([^\s:]+):',line)
            if match:self.labels[match[1]]=len(self.code);line=line[match.end():].strip()
            match=re.match(r'^([A-Z]{3})\b\s*(.*)',line)
            if match:self.code.append((match[1],match[2].strip()))
        self.m={};self.A=self.X=self.Y=0;self.C=self.N=self.Z=0;self.stack=[];self.leg_setups=[]
        for label in ('hoduli_tiles','byte_6000_87F5'):
            address=self.symbols.get(label.lower())
            if address is None:
                address=int(label.rsplit('_',1)[1],16);self.symbols[label.lower()]=address
            for i,value in enumerate(numeric_block(text,label)):self.m[address+i]=value

    def address(self,operand):
        pieces=operand.split(',');base=pieces[0].strip()
        match=re.match(r'^([\w?]+)(?:\s*([+-])\s*([\d$A-Fa-f]+))?$',base)
        assert match,operand
        value=self.symbols[match[1].lower()]
        if match[2]:value+=(1 if match[2]=='+'else-1)*number(match[3])
        if len(pieces)>1:value+=getattr(self,pieces[1].strip())
        return value

    def read(self,operand):
        if operand.startswith('#'):return number(operand[1:])
        if operand=='A':return self.A
        return self.m.get(self.address(operand),0)

    def write(self,operand,value):self.m[self.address(operand)]=value&255
    def flags(self,value):self.Z=int(value==0);self.N=int(bool(value&128));return value&255

    def run(self,entry='tall_walker_sprites',stop_after_store=None):
        pc=self.labels[entry]if isinstance(entry,str)else entry;steps=0;new_leg=False
        while True:
            if pc==self.labels['hoduli_spr_sub']:new_leg=True
            if new_leg and pc==self.labels['loc_6000_8A0F']:
                self.leg_setups.append({'segments':self.read('tmp_var_22'),'integerStep':signed(self.read('tmp_var_1C')),
                    'fractionByte':self.read('tmp_var_1B'),'slopeIndex':self.Y,
                    'start':{'x':self.read('tmp_var_8b')-128,'y':self.read('tmp_var_8c')-200}})
                new_leg=False
            steps+=1;assert steps<10000
            op,arg=self.code[pc];pc+=1
            if op in ('LDA','LDX','LDY'):setattr(self,op[-1],self.flags(self.read(arg)))
            elif op in ('STA','STX','STY'):
                self.write(arg,getattr(self,op[-1]))
                if stop_after_store==arg:return steps
            elif op=='SEC':self.C=1
            elif op=='CLC':self.C=0
            elif op=='CMP':value=self.read(arg);self.C=int(self.A>=value);self.flags((self.A-value)&255)
            elif op in ('ADC','SBC'):
                value=self.read(arg);total=self.A+value+self.C if op=='ADC'else self.A-value-(1-self.C)
                self.C=int(total>255)if op=='ADC'else int(total>=0);self.A=self.flags(total&255)
            elif op in ('EOR','AND','ORA'):
                value=self.read(arg)
                self.A=self.flags(self.A^value if op=='EOR'else self.A&value if op=='AND'else self.A|value)
            elif op in ('ASL','LSR','ROL','ROR'):
                target=arg or 'A';value=self.read(target);old_c=self.C
                if op=='ASL':self.C=value>>7;value=value<<1
                elif op=='LSR':self.C=value&1;value=value>>1
                elif op=='ROL':self.C=value>>7;value=(value<<1)|old_c
                else:self.C=value&1;value=(value>>1)|(old_c<<7)
                value=self.flags(value&255)
                if target=='A':self.A=value
                else:self.write(target,value)
            elif op in ('DEC','INC'):
                value=self.flags((self.read(arg)+(1 if op=='INC'else-1))&255);self.write(arg,value)
            elif op in ('INX','INY','DEX','DEY'):
                reg=op[-1];setattr(self,reg,self.flags((getattr(self,reg)+(1 if op.startswith('IN')else-1))&255))
            elif op=='TXA':self.A=self.flags(self.X)
            elif op=='TYA':self.A=self.flags(self.Y)
            elif op=='TAY':self.Y=self.flags(self.A)
            elif op in ('BEQ','BNE','BCS','BCC','BMI','BPL'):
                take={'BEQ':self.Z,'BNE':not self.Z,'BCS':self.C,'BCC':not self.C,'BMI':self.N,'BPL':not self.N}[op]
                if take:pc=self.labels[arg]
            elif op=='JSR':self.stack.append(pc);pc=self.labels[arg]
            elif op=='RTS':
                if not self.stack:return steps
                pc=self.stack.pop()
            elif op=='JMP':
                if arg=='std_objects_sprites':return steps
                pc=self.labels[arg]
            else:raise AssertionError((op,arg))


def main():
    source=(CACHE/'main.asm').read_text(encoding='utf-8',errors='replace')
    catalog=json.loads((OUT/'tall-walker-procedural-leg-catalog.json').read_text())
    rows=[];goldens=[]
    for expected in catalog['frames']:
        cpu=SourceCPU(source);cpu.X=4;cpu.Y=3
        cpu.write('tmp_var_16',3)
        for name,value in {'Objects_TypeID':expected['objectType'],'Objects_X_shadow':128,'Objects_Xpos_L':128,
            'Objects_Y_shad':200,'Objects_Z_floor':0,'Objects_death_timer':0,
            'objects_some_anim':128+expected['footDeltas'][0],'Objects_cnt3':128+expected['footDeltas'][1]}.items():
            cpu.write(name+',Y',value)
        steps=cpu.run();parts=[]
        for i in range(4,cpu.X,4):
            cpu.X=i
            parts.append({'tile':cpu.read('Sprites_Adress,X'),'attributes':cpu.read('Sprites_Attrib,X'),
                          'x':cpu.read('Sprites_Xpos,X')-128,'y':cpu.read('Sprites_Ypos,X')-200})
        assert parts==expected['parts'][:len(parts)],('leg sprite mismatch',expected['frameId'],
            [(i,a,b)for i,(a,b)in enumerate(zip(parts,expected['parts']))if a!=b][:4])
        head_y=cpu.read('Objects_Y_shad,Y')-cpu.read('Objects_Z_floor,Y')-200
        assert head_y==expected['headAnchor']['y'],('body height mismatch',expected['frameId'])
        rows.append({'poseId':expected['frameId'],'instructions':steps,'legSprites':len(parts),'status':'PASS'})
        goldens.append({'poseId':expected['frameId'],'objectType':expected['objectType'],
            'firstDelta':expected['footDeltas'][0],'secondDelta':expected['footDeltas'][1],
            'headAnchor':{'x':0,'y':head_y},'legs':cpu.leg_setups,'legSprites':parts})
    animation_catalog=json.loads((OUT.parent/'2026-11-09-canonical-character-animation-catalog.json').read_text())
    attack_rows=[]
    probe=SourceCPU(source)
    tail=next(i+1 for i,(op,arg)in enumerate(probe.code)if op=='JSR'and arg=='sub_0_95BA'
              and probe.code[i+1]==('LDA','Objects_AnimID,X'))
    for animation in (0x3a,0x3c):
        clip=next(a for a in animation_catalog['animations']if a['animationId']==animation)
        for value in sorted(set(r['frameId']for r in clip['frameRuns'])):
            for left in (False,True):
                cpu=SourceCPU(source);cpu.X=3;cpu.A=(value-0x18)&255
                cpu.write('Objects_Xpos_L,X',128);cpu.write('Objects_dir,X',0x80 if left else 0)
                cpu.write('Objects_AnimID,X',animation)
                cpu.run('sub_0_95BA');cpu.run(tail,'Objects_cnt3,X')
                attack_rows.append({'animationId':animation,'streamValue':value,'facingLeft':left,
                    'firstDelta':signed((cpu.read('objects_some_anim,X')-128)&255),
                    'secondDelta':signed((cpu.read('Objects_cnt3,X')-128)&255)})
    report={'status':'PASS','method':'Literal source arithmetic/sprite-path interpreter compared with independently transcribed renderer',
            'sourceSha256':hashlib.sha256((CACHE/'main.asm').read_bytes()).hexdigest(),'poses':rows,'attackOffsets':attack_rows,
            'limits':'Prepared safe-screen counters; no death blink, clipping, OAM exhaustion, full NES execution or Roblox acceptance'}
    (OUT/'tall-walker-source-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    def lua(value):
        if isinstance(value,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(v)for k,v in value.items())+'}'
        if isinstance(value,list):return '{'+','.join(lua(v)for v in value)+'}'
        if isinstance(value,bool):return 'true'if value else'false'
        return json.dumps(value)
    body=json.loads((OUT/'hero-frame-catalog.json').read_text())
    body_parts=next(f for f in body['objectFrames']if f['frameId']==0x19)['parts']
    fixture={'sourcePin':'f1a43b69577246850d136473700a333b3cdfe93f','sourceSha256':report['sourceSha256'],
             'method':'Golden pose and attack results emitted by literal SourceCPU, not CanonicalWalker or the transcribed renderer',
             'bodyParts':body_parts,'poses':goldens,'attackOffsets':attack_rows}
    target=ROOT/'tests/gameplay/fixtures/canonical_walker_pose_goldens.lua';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text('-- Generated by research/canonical-visuals/verify_walker_source.py from pinned literal ASM.\nreturn '+lua(fixture)+'\n')
    print(json.dumps({'status':'PASS','poses':len(rows),'attackOffsets':len(attack_rows),
                      'instructionCounts':sorted(set(r['instructions']for r in rows))}))


if __name__=='__main__':main()
