"""Render the serialized NEW wide-fear GLB's actual baked albedo and geometry."""
from pathlib import Path
import io,json,math,struct
import numpy as np
from PIL import Image,ImageDraw
HERE=Path(__file__).resolve().parent

def decode(path):
    blob=path.read_bytes();jl=struct.unpack_from('<I',blob,12)[0];j=json.loads(blob[20:20+jl]);start=28+jl
    def array(i):
        a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']]
        return np.frombuffer(blob,dtype=dtype,count=a['count']*n,offset=start+v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],n).copy()
    image=j['images'][0];view=j['bufferViews'][image['bufferView']]
    atlas=np.asarray(Image.open(io.BytesIO(blob[start+view['byteOffset']:start+view['byteOffset']+view['byteLength']])).convert('RGB'))/255
    out={}
    for node in j['nodes']:
        m=j['meshes'][node['mesh']];p=m['primitives'][0];attrs=p['attributes']
        vs=array(attrs['POSITION'])/.28;ns=array(attrs['NORMAL']);uv=array(attrs['TEXCOORD_0'])
        xy=np.floor(uv*np.array((atlas.shape[1],atlas.shape[0]))).astype(int);xy=np.clip(xy,0,np.array((atlas.shape[1]-1,atlas.shape[0]-1)))
        rgb=atlas[xy[:,1],xy[:,0]];rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
        fs=array(p['indices']).reshape(-1,3)
        out[node['name']]={'v':vs,'n':ns,'c':rgb,'f':fs}
    return out

def render(path=None):
    path=path or HERE/'hero-fear-wide-mouth.glb';meshes=decode(path)
    pw,ph=450,520;width,height=pw*3,ph*4
    canvas=Image.new('RGB',(width,height),(23,28,30));draw=ImageDraw.Draw(canvas)
    light=np.array((-.55,.80,-.85));light/=np.linalg.norm(light)
    for row,(name,m) in enumerate(meshes.items()):
        for col,az in enumerate((0,56,90)):
            az=math.radians(az);camera=np.array((math.sin(az),0,-math.cos(az)))
            right=np.array((math.cos(az),0,math.sin(az)));up=np.cross(right,camera)
            vs=m['v'];projected=np.stack((vs@right,vs@up,vs@camera),axis=-1)
            lo=projected[:,:2].min(0);hi=projected[:,:2].max(0)
            scale=min((pw-60)/(hi[0]-lo[0]),(ph-80)/(hi[1]-lo[1]))
            projected[:,0]=(projected[:,0]-(lo[0]+hi[0])/2)*scale+pw/2
            projected[:,1]=ph/2+15-(projected[:,1]-(lo[1]+hi[1])/2)*scale
            shade=.34+.70*np.maximum(0,m['n']@light);linear=np.clip(m['c']*shade[:,None],0,1)
            rgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)*255
            pixels=np.full((ph,pw,3),(23,28,30),dtype=np.uint8);depth=np.full((ph,pw),-1e30)
            for f in m['f']:
                p,q,r=projected[f];area=(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
                if abs(area)<1e-7:continue
                x0=max(0,int(min(p[0],q[0],r[0])));x1=min(pw-1,int(max(p[0],q[0],r[0]))+1)
                y0=max(0,int(min(p[1],q[1],r[1])));y1=min(ph-1,int(max(p[1],q[1],r[1]))+1)
                if x0>x1 or y0>y1:continue
                xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
                a=((q[0]-xx)*(r[1]-yy)-(q[1]-yy)*(r[0]-xx))/area
                b=((r[0]-xx)*(p[1]-yy)-(r[1]-yy)*(p[0]-xx))/area;c=1-a-b
                z=a*p[2]+b*q[2]+c*r[2];region=depth[y0:y1+1,x0:x1+1]
                valid=(a>=0)&(b>=0)&(c>=0)&(z>region)
                if not valid.any():continue
                region[valid]=z[valid];out=pixels[y0:y1+1,x0:x1+1]
                value=a[...,None]*rgb[f[0]]+b[...,None]*rgb[f[1]]+c[...,None]*rgb[f[2]]
                out[valid]=np.clip(value[valid],0,255).astype(np.uint8)
            canvas.paste(Image.fromarray(pixels),(col*pw,row*ph))
            draw.text((col*pw+12,row*ph+12),name+' '+('front','three-quarter','side')[col],fill=(231,237,240))
    canvas.save(HERE/'hero-fear-wide-mouth-preview.png')
    return {'source':'serialized GLB positions/normals and baked-albedo UV vertex samples',
            'views':['front','three-quarter','side'],'parts':list(meshes)}

if __name__=='__main__':print(json.dumps(render()))
