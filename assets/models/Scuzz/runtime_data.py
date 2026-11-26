"""Refresh Luau palette, pivots, fallback shapes and pose targets from the same sculpt."""
from pathlib import Path
from sculpt import bones,pieces,palette,sockets,poses,envelope
import json
out=Path(__file__).resolve().parents[3]/'src/server/gameplay/ScuzzModel.lua'
def num(n):return ('%.4f'%n).rstrip('0').rstrip('.') or '0'
def vec(p):return 'V('+', '.join(map(num,p))+')'
rows=['-- BT-88. Articulated local-asset fallback for the common group rat.',
      '-- Regenerate these tables with assets/models/Scuzz/runtime_data.py.',
      'local V = Vector3.new','local colors = {']
for name,col in palette.items():rows.append('    %s = Color3.fromRGB(%s),'%(name,', '.join(map(str,col))))
rows+=['}','local pivots = {']
for name,(parent,p) in bones.items():rows+=['    {"%s", "%s", %s},'%(name,parent or '',vec(p))]
rows+=['}','local sockets = {']
for name,(bone,p) in sockets.items():rows+=['    {"%s", "%s", %s},'%(name,bone,vec(p))]
rows+=['}','-- Each section spans a start and end point with a transverse width and depth.','local shapes = {']
def runtime_shapes():
 for name,bone,color,sections,detail in pieces:
    # Bound the live grouped actor cost. The skin export retains individual whiskers and teeth.
    if detail and not (name.startswith('Whisker') and name.endswith('1')):continue
    if name.startswith('Ruff') and not name.endswith('1'):continue
    if name.startswith('Cheek') and name.endswith('1'):continue
    if name=='Bridge':
        parts=[('Bridge',sections[:4]),('Snout',sections[2:])]
    else:parts=[(name,sections)]
    for part,seg in parts:
        wedge=len(sections)==3 and not name.startswith('Whisker')
        yield part,bone,color,seg[0][:3],seg[-1][:3],max(s[3] for s in seg)*2,max(s[4] for s in seg)*2,wedge
for part,bone,color,p,q,w,d,wedge in runtime_shapes():
    rows+=['    {"%s", "%s", "%s", %s, %s, %s, %s, %s},'%(part,bone,color,vec(p),vec(q),num(w),num(d),str(wedge).lower())]
rows+=['}','local poses = {']
for name,targets in poses.items():
    rows+=['    '+name+' = {'+', '.join(k+' = '+vec(p) for k,p in targets.items())+'},']
rows+=['}','local envelopes = {']
for name in poses:
    keys=envelope(name);duration=keys[-1][0]-1
    rows+=['    '+name+' = {'+', '.join('{'+num((frame-1)/duration)+', '+num(factor)+'}' for frame,factor in keys)+'},']
rows+=['}','local floorTracks = {']
tracks=json.loads(Path(__file__).with_name('floor_tracks.json').read_text())
for name,heights in tracks.items():rows+=['    '+name+' = {'+', '.join(map(num,heights))+'},']
rows+=['}','-- END SCULPT DATA','']
tail=out.read_text(encoding='utf-8').split('-- END SCULPT DATA\n',1)[-1] if out.exists() else ''
if __name__=='__main__':out.write_text('\n'.join(rows)+tail,encoding='utf-8')
