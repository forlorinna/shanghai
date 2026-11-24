#!/usr/bin/env python3
"""Build metrically scaled landmark meshes in Blender and export two geometry LODs."""
import math
import sys
from collections import defaultdict
from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parents[1] / 'assets/landmarks/models'
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau
PALETTE = {
    'Limestone': ('b7afa1', 0.0, .79), 'Plinth': ('737779', 0.0, .71),
    'Silver': ('8e9c9e', .63, .42), 'Steel': ('515e61', .61, .45),
    'Glazing': ('506b7c', .37, .26), 'GlassDark': ('233842', .48, .31),
    'Rose': ('824358', .46, .37), 'Copper': ('36574e', .49, .51),
    'NightWarm': ('ebac65', .05, .46), 'NightRose': ('db456f', .1, .40),
    'NightCool': ('66b6ca', .11, .34), 'Clock': ('c2b38d', 0, .58),
}
def rgb(hex_string):
    srgb = [int(hex_string[i:i+2], 16)/255 for i in (0,2,4)]
    return [x/12.92 if x < .04045 else ((x+.055)/1.055)**2.4 for x in srgb]

class Meshes:
    def __init__(self, close):
        self.close = close
        self.groups = defaultdict(lambda: [[], []])
    def face(self, mat, *p):
        verts, faces = self.groups[mat]
        start = len(verts)
        verts.extend((x, -z, y) for x, y, z in p)
        faces.append(tuple(range(start, start+len(p)))[::-1])
    def box(self, mat, pos, w, h, d):
        x,y,z=pos
        vertices = [(x+a*w*.5,y+b*h*.5,z+c*d*.5) for a,b,c in
                    [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
        for face in ((0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)):
            self.face(mat, *(vertices[i] for i in face))
    def loft(self, levels, fn, sides, material, closed=False):
        rings = [[fn(y,j*TAU/sides) for j in range(sides)] for y in levels]
        for i in range(len(levels)-1):
            for j in range(sides):
                k=(j+1)%sides
                name = material(i,j) if callable(material) else material
                self.face(name,rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j])
        if closed:
            mat = material(0,0) if callable(material) else material
            self.face(mat, *rings[0][::-1]); self.face(mat, *rings[-1])
    def lathe(self, mat, x,z, levels, sides):
        heights = [row[0] for row in levels]
        def point(t,a):
            radius = levels[heights.index(t)][1]
            return (x+math.cos(a)*radius,t,z+math.sin(a)*radius)
        self.loft(heights,point,sides,mat,True)
    def sphere(self,x,z,y,rx,ry,mat, bands):
        steps=26 if self.close else 12
        sides=64 if self.close else 28
        def point(t,a):
            return (x+math.cos(a)*rx*math.cos(t),y+math.sin(t)*ry,z+math.sin(a)*rx*math.cos(t))
        stages=[-.5*math.pi+math.pi*i/steps for i in range(steps+1)]
        self.loft(stages,point,sides,lambda i,j: bands.get(i, mat))
    def beam(self, mat, a,b,r, sides=8):
        dx,dy,dz=(b[i]-a[i] for i in range(3))
        ln=math.sqrt(dx*dx+dy*dy+dz*dz)
        yaw=math.atan2(dx,dz)
        pitch=math.atan2(math.hypot(dx,dz),dy)
        u=(math.cos(yaw),0,-math.sin(yaw))
        v=(math.sin(yaw)*math.cos(pitch),-math.sin(pitch),math.cos(yaw)*math.cos(pitch))
        def rim(p,j):
            angle=j*TAU/sides
            return tuple(p[k]+r*(u[k]*math.cos(angle)+v[k]*math.sin(angle)) for k in range(3))
        for j in range(sides):
            self.face(mat,rim(a,j),rim(b,j),rim(b,j+1),rim(a,j+1))
        if ln > .1:
            self.face(mat, *(rim(a,j) for j in range(sides)))
            self.face(mat, *(rim(b,j) for j in range(sides-1,-1,-1)))

def pearl(m):
    n=48 if m.close else 22
    m.lathe('Limestone',0,0,[(0,29),(1.1,29),(1.2,26.8),(4.8,26.8),(5.0,25.3)],n)
    if m.close:
        m.lathe('Plinth',0,0,[(.18,32.4),(.48,32.4),(.70,31.2),(1.04,31.2)],96)
        m.lathe('Glazing',0,0,[(1.28,27.4),(4.30,27.4)],96)
        m.lathe('Silver',0,0,[(4.26,28.2),(4.52,28.2),(4.63,27.7)],96)
        m.lathe('Limestone',0,0,[(4.55,29.3),(4.95,29.3),(5.48,28.1),(5.62,26.2)],96)
        for panel in range(96):
            a = (panel+.5)*TAU/96
            x,z=math.cos(a),math.sin(a)
            m.beam('Steel',(x*27.61,1.15,z*27.61),(x*27.61,4.43,z*27.61),.065,6)
            if panel % 12 in (4,5,6,7):
                m.beam('NightWarm',(x*28.48,4.3,z*28.48),(x*28.48,4.49,z*28.48),.05,5)
            if panel % 16 == 0:
                m.beam('Plinth',(x*28.07,.22,z*28.07),(x*28.07,4.52,z*28.07),.315,12)
        for angle in (-1.57, .51, 2.61):
            cx, cz = math.cos(angle)*29.6, math.sin(angle)*29.6
            for side in (-1,1):
                x,z = cx+side*2.36*math.sin(angle),cz-side*2.36*math.cos(angle)
                m.beam('Silver',(x,.12,z),(x,3.52,z),.16,8)
            a = (cx+2.58*math.sin(angle),3.42,cz-2.58*math.cos(angle))
            b = (cx-2.58*math.sin(angle),3.42,cz+2.58*math.cos(angle))
            c = (b[0]+math.cos(angle)*3.4,3.33,b[2]+math.sin(angle)*3.4)
            d = (a[0]+math.cos(angle)*3.4,3.33,a[2]+math.sin(angle)*3.4)
            m.face('Glazing',a,b,c,d)
            for start,end in ((a,b),(b,c),(c,d),(d,a)):
                m.beam('Steel',start,end,.073,6)
    for j in range(3):
        a=TAU*j/3+.2
        x,z=math.cos(a),math.sin(a)
        m.beam('Limestone',(x*37,1,z*37),(x*11,93,z*11),4.6,16 if m.close else 9)
        m.beam('Limestone',(x*8,3,z*8),(x*5.2,269,z*5.2),3.25,16 if m.close else 9)
        for h in ([122,153,184,213,238] if m.close else [153,214]):
            m.sphere(x*7.4,z*7.4,h,4.25,3.6,'GlassDark',{})
    m.lathe('Silver',0,0,[(77,9),(110,9.4),(263,5.9),(285,4.7),(351,3.3),(375,2.8)],n)
    for height,radius,stretch in [(90,25,22.2),(263,22.5,20.6),(351,8.7,8.8)]:
        bands={13:'GlassDark',14:'NightRose',15:'Silver',11:'GlassDark'} if m.close else {6:'NightRose',7:'GlassDark'}
        m.sphere(0,0,height,radius,stretch,'Rose',bands)
        m.lathe('Steel', 0,0,[(height-3.4,radius*.998),(height-2.6,radius*1.012),(height+1.5,radius*1.009),(height+2.4,radius*.991)],n)
        m.lathe('NightRose',0,0,[(height+1.52,radius*1.011),(height+1.86,radius*1.011)],n)
    m.lathe('Silver',0,0,[(355,2.8),(399,2.2),(420,1.45),(437,.85),(457,.43),(468,.078)],n//2)
    for y in [399,414,432,450,464]:
        m.lathe('Rose',0,0,[(y-.76,max(.21,2.1-(y-396)*.028)),(y+.76,max(.21,2.1-(y-396)*.028))],n//2)

def tower(m):
    rows=126 if m.close else 49
    sides=66 if m.close else 27
    def wall(t,a):
        angle=a+t*2.094
        phase = a + .55
        radius=(43.5-18.6*t)*(1+.108*math.cos(3*phase)+.027*math.cos(6*phase))
        crown=max(0,(t-.94)/.06)
        return (math.cos(angle)*radius,632*t-16*crown*(.5+.5*math.sin(a)),math.sin(angle)*radius)
    m.loft([j/rows for j in range(rows+1)],wall,sides,
           lambda i,j:'Silver' if i in {round(rows*k/9) for k in range(1,9)} else
           ('GlassDark' if j%13 in (2,3) else 'Glazing'), True)
    if m.close:
        for i in range(1,rows):
            t=i/rows
            for j in range(sides):
                a,b=j*TAU/sides,(j+1)*TAU/sides
                p=wall(t,a); q=wall(t,b)
                inset=lambda v: (v[0]*1.004,v[1],v[2]*1.004)
                ip,iq=inset(p),inset(q)
                m.face('Silver',ip,iq,(iq[0],iq[1]+.12,iq[2]),(ip[0],ip[1]+.12,ip[2]))
                if (i*69+j*17)%49 in (0,1,2):
                    zp,zq=wall(t-.004,a+.012),wall(t-.004,b-.012)
                    dp,dq=(zp[0]*1.005,zp[1],zp[2]*1.005),(zq[0]*1.005,zq[1],zq[2]*1.005)
                    m.face('NightCool',dp,dq,(dq[0],dq[1]+1.28,dq[2]),(dp[0],dp[1]+1.28,dp[2]))
    for p in range(3):
        angle=(p+.42)*TAU/3
        for level in range(1,48):
            low=wall(level/48,angle); high=wall((level+1)/48,angle)
            m.beam('NightCool',(low[0]*1.007,low[1],low[2]*1.007),(high[0]*1.007,high[1],high[2]*1.007),.14,4)
    m.lathe('Plinth',0,0,[(0,38),(3,38),(8,35),(17,33)],33)

def jinmao(m):
    base=33.
    m.box('Limestone',(0,15,0),59,30,60)
    for i in range(15):
        high=base+(42.2-i*1.82)
        w=52.6*(.882**i)
        m.box('Glazing',(0,(base+high)/2,0),w,high-base,w)
        m.box('Silver',(0,high-1.1,0),w+2.1,2.1,w+2.1)
        m.box('NightWarm',(0,high+.015,0),w+2.25,.12,w+2.25)
        for sx in (-1,1):
            for sz in (-1,1):
                m.box('Silver',(sx*(w*.48), (base+high)/2, sz*(w*.48)),.54,high-base,.54)
        if m.close:
            for j in range(1,int((high-base)/3.6)):
                y=base+3.6*j
                for sign in (-1,1):
                    m.box('Steel',(0,y,sign*w*.501),w*.982,.13,.18)
                    m.box('Steel',(sign*w*.501,y,0),.18,.13,w*.982)
        base=high
        if base>390:
            break
    m.lathe('Silver',0,0,[(base,3.1),(min(base+8,413),2.1),(419,.62),(420.5,.24)],14)

def wfc(m):
    count=82 if m.close else 31
    def wing(y):
        return 29.5-6.2*(y/492)
    def thickness(y):
        return 23.2-9.8*(y/492)
    def rect(y,xx):
        w=wing(y); z=thickness(y); b=2.5
        return [(-w+b,y,-z),(w-b,y,-z),(w,y,-z+b),(w,y,z-b),
                (w-b,y,z),(-w+b,y,z),(-w,y,z-b),(-w,y,-z+b)][xx]
    m.loft([416*j/count for j in range(count+1)], lambda y,t: rect(y,round(t*8/TAU)%8),8,
           lambda i,j:'Silver' if i%12==0 or j%2 else 'Glazing',True)
    for side in (-1,1):
        for j in range(20 if m.close else 8):
            loops=20 if m.close else 8
            a,b=416+j*60/loops,416+(j+1)*60/loops
            for face in (-1,1):
                m.face('Glazing',(side*(wing(a)-8.0),a,face*thickness(a)),(side*wing(a),a,face*thickness(a)),
                       (side*wing(b),b,face*thickness(b)),(side*(wing(b)-5.2),b,face*thickness(b)))
                m.beam('NightCool',(side*(wing(a)-7.8),a,face*thickness(a)),(side*(wing(b)-5.0),b,face*thickness(b)),.124,4)
                m.face('Steel',(side*(wing(a)-8),a,-thickness(a)),(side*(wing(a)-8),a,thickness(a)),
                       (side*(wing(b)-5.2),b,thickness(b)),(side*(wing(b)-5.2),b,-thickness(b)))
    m.box('Silver',(0,484,0),47.7,16,27.5)
    m.box('NightCool',(0,476.3,13.95),46.2,.45,.32)
    m.box('Plinth',(0,3,0),62,6,47)

def convention(m):
    m.box('Limestone',(0,9.5,0),119,19,61)
    m.box('Silver',(0,15.0,-17),119,2.3,58)
    for x in (-47,47):
        m.sphere(x,-22,18.5,20.6,18.1,'Glazing',{8:'Silver',9:'NightCool',13:'Silver',16:'NightCool'} if m.close else {3:'Silver',7:'NightCool'})
        for y in [6.7,12.3,24,32]:
            rad=20.5*math.sqrt(max(.03,1-((y-18.5)/18.1)**2))
            m.lathe('Silver',x,-22,[(y-.12,rad),(y+.12,rad)],50 if m.close else 18)
    for j in range(-10,11):
        x=j*3.75
        m.box('Glazing',(x,7,-30.52),3.36,10.3,.15)
        if j%2==0:
            m.box('Limestone',(x,5.3,30.8),.47,10.3,1.04)

def heritage(m,w,d,h):
    m.box('Limestone',(0,h*.5,0),w,h,d)
    m.box('Plinth',(0,.46,0),w+.42,.92,d+.42)
    for z_sign in (-1,1):
        z=z_sign*(d*.5)
        n=round(w/3.55)
        for row in range(0,max(2,int((h-3)/4.28))):
            floor=1.15+row*4.28
            for j in range(n):
                x=(j-(n-1)*.5)*(w-3.6)/n
                width=1.77 if row>0 else 2.2
                height=2.45 if row>0 else 3.07
                m.box('Plinth',(x,floor+height*.5,z+z_sign*.035),width+.38,height+.32,.17)
                glass='NightWarm' if (j*17+row*5)%13==0 else 'GlassDark'
                m.box(glass,(x,floor+height*.5,z+z_sign*.149),width,height,.078)
                m.box('Limestone',(x,floor-.09,z+z_sign*.206),width+.59,.18,.38)
                if m.close:
                    m.box('Steel',(x,floor+height*.5,z+z_sign*.208),.077,height,.05)
                    m.box('Steel',(x,floor+height*.67,z+z_sign*.208),width,.069,.05)
                    for side in (-1,1):
                        m.box('Limestone',(x+side*(width*.5+.13),floor+height*.5,z+z_sign*.196),.22,height+.20,.29)
                    if row==0:
                        k=x+width*.6
                        m.lathe('Limestone',k,z+z_sign*.52,[(.05,.32),(.39,.30),(3.92,.25),(4.24,.36)],12)
        for y in [4.35,h-3.0,h-1.32,h+.12]:
            m.box('Limestone',(0,y,z+z_sign*.24),w+.55,.25,.56)
            if y>7:
                m.box('NightWarm',(0,y+.135,z+z_sign*.528),w+.31,.038,.035)
    m.box('Plinth',(0,h+.50,0),w-2,.8,d-3.3)

def peace(m):
    heritage(m,55,46,31.0)
    m.box('Limestone',(11,33.1,5),21,5,19.0)
    m.lathe('Copper',11,5,[(35.5,14),(39,12.4),(49,5.3),(54,1.0),(55,.48)],4)
    m.lathe('Silver',11,5,[(54.7,.35),(61.6,.07)],9)
    m.box('NightWarm',(11,36.4,14.55),10,.16,.13)

def customs(m):
    heritage(m,36,28,26.0)
    m.box('Limestone',(0,42.65,3),12.3,36.3,13.8)
    for z in (-4.0,10.0):
        y=52.8
        for j in range(36 if m.close else 18):
            step=36 if m.close else 18
            a=j*TAU/step; b=(j+1)*TAU/step
            m.face('Clock',(0,y,z),(math.cos(a)*2.23,y+math.sin(a)*2.23,z),(math.cos(b)*2.23,y+math.sin(b)*2.23,z))
        for k in range(12):
            a=k*TAU/12
            m.beam('Steel',(math.sin(a)*1.68,y+math.cos(a)*1.68,z-.04),(math.sin(a)*1.99,y+math.cos(a)*1.99,z-.04),.055,5)
        m.beam('Steel',(0,y,z-.07),(.90,y+1.26,z-.07),.07,5)
        m.beam('Steel',(0,y,z-.08),(-.89,y+.12,z-.08),.09,5)
    m.box('Copper',(0,61.4,3),11.8,2.3,13.4)
    m.lathe('Copper',0,3,[(62.5,8.6),(65.4,6.7),(69.8,2.1),(71,.43)],4)

def bridge(m):
    for side in (-1,1):
        x=side*6.1
        for span in range(2):
            for j in range(8):
                def p(t): return (-53+53*(span+t))
                a=j/8; b=(j+1)/8
                z1,z2=p(a),p(b)
                h1,h2=2.15+6.9*math.sin(a*math.pi),2.15+6.9*math.sin(b*math.pi)
                m.beam('Steel',(x,h1,z1),(x,h2,z2),.25,6)
                m.beam('Steel',(x,.15,z1),(x,.15,z2),.29,6)
                m.beam('Steel',(x,.15,z1),(x,h1,z1),.16,6)
                m.beam('Steel',(x,h1,z1),(x,.15,z2),.13,6)
                if m.close:
                    m.beam('Silver',(x+side*.31,1.2,z1),(x+side*.31,1.2,z2),.069,5)
            m.box('Plinth',(0,-1.8,p(0)),13.3,3.7,2.4)
    for z in [-45,-35,-25,-15,-5,5,15,25,35,45]:
        rise=2.15+6.9*abs(math.sin((z+53)*math.pi/53))
        m.beam('Steel',(-6.15,rise,z),(6.15,rise,z),.15,6)

def save_landmark(name, detail, function):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh=Meshes(detail=='near')
    function(mesh)
    for label,(vertices,faces) in mesh.groups.items():
        material=bpy.data.materials.new(label)
        material.use_nodes=True
        material.use_backface_culling=False
        bsdf=material.node_tree.nodes.get('Principled BSDF')
        shade, metal, rough=PALETTE[label]
        bsdf.inputs['Base Color'].default_value=(*rgb(shade),1)
        bsdf.inputs['Metallic'].default_value=metal
        bsdf.inputs['Roughness'].default_value=rough
        data=bpy.data.meshes.new(label)
        data.from_pydata(vertices,[],faces)
        data.update()
        obj=bpy.data.objects.new(label,data)
        bpy.context.collection.objects.link(obj)
        data.materials.append(material)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}_{detail}.glb'),export_format='GLB',
                            export_yup=True,export_cameras=False,export_lights=False)
    print('LANDMARK',name,detail,sum(len(g[1]) for g in mesh.groups.values()))

for name, function in [('pearl',pearl),('shanghai',tower),('jinmao',jinmao),('swfc',wfc),
                       ('convention',convention),('peace',peace),('customs',customs),('bridge',bridge)]:
    chosen = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if not chosen or name in chosen:
        for detail in ('near','far'):
            save_landmark(name,detail,function)
