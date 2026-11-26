"""Depth-tested smooth inspection renderer for the authored geometry."""
from math import cos, sin
import moderngl
import numpy as np
from PIL import Image
from author import pose

_CTX = None

def render_data(meshes):
    global _CTX
    if _CTX is None:
        _CTX=moderngl.create_standalone_context()
    ctx=_CTX
    prog=ctx.program(vertex_shader="""#version 330
    uniform mat4 model; uniform mat3 view;
    in vec3 p; in vec3 n; in vec3 c; in vec2 uv;
    out vec3 normal; out vec3 color; out vec2 st;
    void main() {
        vec3 v=view*(model*vec4(p,1)).xyz;
        gl_Position=vec4(v.xy*.33,v.z*.15,1);
        normal=view*mat3(model)*n; color=c; st=uv;
    }""",fragment_shader="""#version 330
    in vec3 normal; in vec3 color; in vec2 st; out vec4 rgba;
    void main(){
        vec3 n=normalize(normal);
        float grain=.02*sin(111.*st.x+4.*sin(39.*st.y))*cos(83.*st.y);
        float key=max(dot(n,normalize(vec3(-.52,.75,-.63))),0.);
        float bounce=max(dot(n,normalize(vec3(.7,.25,.65))),0.);
        float spec=pow(max(dot(n,normalize(vec3(-.32,.42,-1))),0.),32.)*.16;
        vec3 paint=color*(.44+1.39*key+.47*bounce+grain)+vec3(spec)*sqrt(color);
        rgba=vec4(pow(paint,vec3(1./2.2)),1);
    }""")
    vaos={}
    for name,(_,_,g) in meshes.items():
        if not g.p:continue
        pos=np.array(g.p);tri=np.array(g.tris);norm=np.zeros_like(pos)
        cross=np.cross(pos[tri[:,1]]-pos[tri[:,0]],pos[tri[:,2]]-pos[tri[:,0]])
        for k in range(3):np.add.at(norm,tri[:,k],cross)
        buckets={}
        for i,p in enumerate(pos):buckets.setdefault(tuple(p.round(6)),[]).append(i)
        for ids in buckets.values():norm[ids]=norm[ids].sum(axis=0)
        norm/=np.maximum(np.linalg.norm(norm,axis=1,keepdims=True),1e-10)
        data=np.concatenate([pos,norm,g.col,g.uv],axis=1).astype("f4")
        vaos[name]=ctx.vertex_array(prog,[(ctx.buffer(data.tobytes()),"3f 3f 3f 2f","p","n","c","uv")],
                                    ctx.buffer(tri.astype("i4").tobytes()))
    return prog,vaos,{}

def render(meshes,chunks,yaw,pitch,clip=None,t=0,sz=384):
    prog,vaos,fbos=chunks;ctx=_CTX
    if sz not in fbos:fbos[sz]=ctx.simple_framebuffer((sz*2,sz*2),components=3)
    fbo=fbos[sz];fbo.use();ctx.enable(moderngl.DEPTH_TEST)
    bg=np.array((23,32,36))/255
    fbo.clear(*bg,depth=1)
    rot=np.array([[-cos(yaw),0,-sin(yaw)],[-sin(yaw)*sin(pitch),cos(pitch),cos(yaw)*sin(pitch)],
                  [-sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch)]])
    prog["view"].write(rot.T.astype("f4").tobytes())
    transforms={}
    for name,(parent,origin,_) in meshes.items():
        delta,angle=pose(name,clip,t) if clip else (np.zeros(3),0)
        m=np.eye(4);m[:3,3]=origin+delta
        m[:2,:2]=[[cos(angle),-sin(angle)],[sin(angle),cos(angle)]]
        if parent:m=transforms[parent]@m
        transforms[name]=m
        if name in vaos:
            prog["model"].write(m.T.astype("f4").tobytes());vaos[name].render()
    img=Image.frombytes("RGB",fbo.size,fbo.read(components=3,alignment=1)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    img=img.resize((sz,sz),Image.Resampling.LANCZOS)
    return Image.blend(img,Image.new("RGB",img.size,(23,32,36)),t) if clip=="Defeat" else img
