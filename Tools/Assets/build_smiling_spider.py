"""Author the local Smiling Spider mesh, rig, motion clips and studio render.

Blender 4.5 --background --threads 4 --python this.py
The stone portraits adapt the project's MIT Rocketbox mesh. All creature geometry,
materials and animation in this file are locally authored; no Meshy viewer data.
Editable master stays in the D: workshop to respect the active project's 5 GB cap.
"""
import bpy, bmesh, math, random, json, faulthandler
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
from mathutils.noise import noise_vector, noise

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Godot/assets/generated/smiling_spider'
WORK=Path('D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2')
OUT.mkdir(parents=True,exist_ok=True); WORK.mkdir(parents=True,exist_ok=True)
random.seed(1204)
faulthandler.dump_traceback_later(120,repeat=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Extract a real facial mesh, retaining its eyes/nose/lips, and turn it into stone.
bpy.ops.import_scene.gltf(filepath=str(ROOT/'Godot/assets/third_party/rocketbox_luke_v2/luke_v2.glb'))
src=bpy.data.objects['Luke21_hipoly']; source_head=src.data.copy()
bm=bmesh.new();bm.from_mesh(source_head)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<1.48],context='VERTS')
bm.to_mesh(source_head);bm.free()
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)

def material(name,color,rough=.4,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
chitin=material('Oxblood / carved chitin',(.12,.022,.015),.30)
ridge=material('Raised carapace ridges',(.25,.063,.035),.34)
joint=material('Graphite joint membrane',(.018,.012,.01),.58)
eye=material('Black glass eyes',(.003,.004,.003),.12)
gum=material('Dark crimson mouth edge',(.16,.013,.016),.27)
cavity=material('Mouth recess',(.002,.001,.001),.7)
ivory=material('Aged ivory teeth',(.58,.46,.29),.32)
stone=material('Carved limestone / sculpture',(.42,.40,.34),.88)
silk=material('Old silk cords',(.42,.37,.26),.66)

# Procedural master shaders. Vertex colours preserve large-scale variation in GLB;
# a small reusable detail normal map supplies pores in both Blender and Godot.
def detail_shader(m,scale,amount):
    n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    tc=n.new('ShaderNodeTexCoord');tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=scale
    tex.inputs['Detail'].default_value=3.0
    l.new(tc.outputs['Generated'],tex.inputs['Vector'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=amount;bump.inputs['Distance'].default_value=.018
    l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
    attr=n.new('ShaderNodeVertexColor');attr.layer_name='SurfaceTint';l.new(attr.outputs['Color'],p.inputs['Base Color'])
for m in [chitin,ridge,joint,ivory,stone,silk,gum]:detail_shader(m,75 if m==stone else 32,.34)

parts=[];bone_defs={};weights={}
def finish(o,name,mat,bone='Root'):
    o.name=name;o.data.materials.clear();o.data.materials.append(mat)
    o.data.transform(Matrix.LocRotScale(o.location,o.rotation_euler.to_quaternion(),o.scale))
    o.matrix_world=Matrix.Identity(4)
    for p in o.data.polygons:p.use_smooth=True
    ca=o.data.color_attributes.new(name='SurfaceTint',type='BYTE_COLOR',domain='CORNER')
    col=mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value[:3]
    for poly in o.data.polygons:
        for li in poly.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            variation=.72+.38*noise(co*11.3)+.17*noise(co*59.7)
            if mat==stone:variation=.82+.24*noise(co*65)
            ca.data[li].color=(*(min(1,max(.001,c*variation)) for c in col),1)
    if bone:
        vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
    parts.append(o);return o
def ellipsoid(name,loc,scale,mat,bone='Root',segments=32,rings=20,sculpt=0):
    mesh=bpy.data.meshes.new(name);bm=bmesh.new()
    bmesh.ops.create_uvsphere(bm,u_segments=segments,v_segments=rings,radius=1)
    bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=loc;o.scale=scale
    if sculpt:
        for v in o.data.vertices:v.co*=1+sculpt*noise(v.co*9.0)
    return finish(o,name,mat,bone)
def tube(name,points,radii,mat,bone='Root',sides=8):
    verts=[];faces=[]
    pts=[Vector(p) for p in points]
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        u=tangent.cross(Vector((0,0,1)))
        if u.length<.01:u=tangent.cross(Vector((0,1,0)))
        u.normalize();v=tangent.cross(u).normalized()
        for j in range(sides):verts.append(tuple(p+radii[i]*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides))))
    for i in range(len(pts)-1):
        for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,mat,bone)
def box(name,loc,scale,mat,bone='Root',bevel=.025):
    mesh=bpy.data.meshes.new(name);bm=bmesh.new()
    bmesh.ops.create_cube(bm,size=1,matrix=Matrix.Diagonal(Vector((*scale,1))))
    bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES')
    bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=loc
    return finish(o,name,mat,bone)
def bone(name,a,b,parent='Root'):bone_defs[name]=(Vector(a),Vector(b),parent)

bone('Root',(0,0,1.1),(0,.8,1.1),None)
bone('Back',(0,-.4,1.3),(0,-1.6,1.55))
bone('Jaw',(0,.7,.94),(0,1.25,.76))
ellipsoid('Cephalothorax',(0,.27,1.12),(.89,.94,.62),chitin,segments=56,rings=36,sculpt=.07)
ellipsoid('Pedicel',(0,-.63,1.25),(.35,.45,.35),joint)
ellipsoid('Great abdomen',(0,-1.10,1.52),(1.14,1.43,1.10),chitin,'Back',64,40,.11)
# Layered anatomical carapace ribs and abdomen seams: real geometry, not decals.
for j in range(9):
    theta=.32+j*.30;pts=[]
    for k in range(25):
        phi=-1.25+k*2.5/24
        pts.append((1.15*math.sin(theta)*math.sin(phi),-1.1+1.46*math.cos(theta),1.52+1.12*math.sin(theta)*math.cos(phi)))
    tube('Abdomen seam %02d'%j,pts,[.015+.01*math.sin(k*math.pi/24) for k in range(25)],ridge,'Back',6)
for side in [-1,1]:
    for k in range(4):
        pts=[(side*(.12+.65*t),.97-k*.24-.28*t,1.58-.20*t+.04*math.sin(t*math.pi)) for t in [j/12 for j in range(13)]]
        tube('Shell scroll',pts,[.035]*13,ridge,sides=8)

legs=[]
for side,suffix in [(-1,'L'),(1,'R')]:
    for i in range(4):
        # Fan of eight knees and hooked tarsi, front legs longest toward the face.
        hip=Vector((side*.60,.68-i*.42,1.14))
        knee=Vector((side*(1.6+.14*math.sin(i)),1.24-i*.96,1.72+(.22 if i==3 else 0)))
        ankle=Vector((side*(2.55+.13*math.sin(i)),1.94-i*1.22,.36))
        toe=ankle+Vector((side*.17,.16 if i<2 else -.17,-.31))
        names=[f'LegSegment{letter}_{suffix}_{i+1:03d}' for letter in 'ABC']
        for j,(a,b) in enumerate(zip([hip,knee,ankle],[knee,ankle,toe])):
            bone(names[j],a,b,'Root' if j==0 else names[j-1])
            pts=[]
            for q in range(9):
                t=q/8;pt=a.lerp(b,t);pt.z+=math.sin(t*math.pi)*(.09 if j<2 else .025);pts.append(pt)
            r0=[.18,.135,.058][j];r1=[.14,.065,.008][j]
            tube(f'Leg {suffix}{i+1} segment {j}',pts,[r0*(1-q/8)+r1*q/8 for q in range(9)],chitin,names[j],12)
            # Overlapping edge ridges and tapered setae follow each rigid segment.
            for q in range(1,7):
                t=q/8;p=a.lerp(b,t);p.z+=math.sin(t*math.pi)*.09
                rad=r0*(1-t)+r1*t
                ellipsoid('Chitin scale',p,(rad*1.07,rad*.73,rad*.75),ridge,names[j],12,8)
                if j<2:
                    for h in [-1,1]:
                        start=p+Vector((h*rad*.8,0,rad*.45));end=start+Vector((h*.08,-.08,.09))
                        tube('Sensory spine',[start,start.lerp(end,.5)+Vector((0,0,.025)),end],[.013,.008,.001],joint,names[j],4)
        ellipsoid('Knee membrane',knee,(.15,.15,.15),joint,names[1],20,12)
        legs.append((names,hip,knee,ankle,toe,i,side))

# Socket rings and eight black eyes; large forward eyes remain readable in shadow.
for idx,(x,z,r) in enumerate([(-.25,1.46,.19),(.25,1.46,.19),(-.51,1.54,.105),(.51,1.54,.105),(-.63,1.68,.075),(.63,1.68,.075),(-.13,1.73,.08),(.13,1.73,.08)]):
    y=1.04-.22*abs(x)
    ellipsoid('Eye socket %d'%idx,(x,y,z),(r*1.28,r*.66,r*1.25),ridge,segments=24,rings=16)
    ellipsoid('Glass eye %d'%idx,(x,y+.055,z),(r,r*.68,r),eye,segments=24,rings=16)

ellipsoid('Grin recess',(0,1.055,.99),(.69,.21,.31),cavity,segments=40,rings=24)
def mouth(x,lower=False):
    q=abs(x/.69);return Vector((x,1.24-.20*q*q,(.75+.40*q*q) if lower else (1.10+.17*q*q)))
for lower in [False,True]:
    pts=[mouth(-.68+1.36*k/32,lower) for k in range(33)]
    tube('Lower lip' if lower else 'Upper lip',pts,[.043]*33,gum,'Jaw' if lower else 'Root',10)
    for k in range(17):
        x=-.62+1.24*k/16;pt=mouth(x,lower);pt.y+=.006
        length=(.15 if lower else .185)*(1-.43*abs(x/.65))
        pt.z+=length*.36 if lower else -length*.38
        tooth=ellipsoid('Tooth',pt,(.036+random.uniform(-.005,.005),.052,length*.56),ivory,'Jaw' if lower else 'Root',12,10)
for side,suf in [(-1,'L'),(1,'R')]:
    base=(side*.68,.93,1.03);tip=(side*.47,1.48,.48)
    bone('Fang_'+suf,base,tip)
    tube('Hooked fang '+suf,[base,(side*.81,1.25,.88),(side*.69,1.48,.64),tip],[.135,.115,.065,.005],ridge,'Fang_'+suf,14)
    palm=(side*.81,.67,.94);end=(side*1.18,1.55,.39)
    bone('PedopalpSegmentA_'+suf,palm,end)
    tube('Sensory palp '+suf,[palm,(side*1.14,1.09,.81),end],[.13,.10,.012],chitin,'PedopalpSegmentA_'+suf,12)

# Four intact, visibly carved portrait sculptures mounted on square stone plinths.
for i,x in enumerate([-.63,-.22,.22,.63]):
    z=1.75+(.12 if i in [1,2] else 0);y=.48-abs(x)*.06
    box('Sculpture plinth %d'%(i+1),(x,y,z),(.34,.29,.18),stone)
    ellipsoid('Stone shoulders %d'%(i+1),(x,y,z+.15),(.18,.11,.12),stone,segments=24,rings=16)
    mesh=source_head.copy();o=bpy.data.objects.new('Stone portrait %d'%(i+1),mesh);bpy.context.collection.objects.link(o)
    # Source face points -Y. Turn toward the creature's +Y; soften the jaw in stone.
    for v in mesh.vertices:
        q=v.co.copy();q.z-=1.48
        v.co=Vector((-q.x*1.14,-q.y*1.12,q.z*1.03))+Vector((x,y,z+.14))
    finish(o,o.name,stone)
    sub=o.modifiers.new('Sculpture surface','SUBSURF');sub.levels=1
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=sub.name);o.select_set(False)
    # Drapery, a distinct stone hairline and silk lashings sell the object as a bust.
    for j in range(5):
        a=-.13+j*.065
        tube('Carved drapery',[(x+a,y+.10,z+.21),(x+a*.7,y+.13,z+.13),(x+a*.8,y+.12,z+.05)],[.01,.012,.009],stone)
    for j in range(9):
        t=j*math.tau/9
        ellipsoid('Stone carved hair',(x+math.cos(t)*.09,y+math.sin(t)*.075,z+.445),(.037,.036,.035),stone,segments=10,rings=8)
    for j in [-1,1]:
        tube('Crown silk knot',[(x+j*.13,y+.17,z-.1),(x+j*.12,y+.18,z+.11),(x-j*.1,y+.18,z-.08)],[.012]*3,silk,sides=6)
for j in range(11):
    pts=[]
    for k in range(30):
        x=-.85+k*1.7/29;pts.append((x,.48+random.uniform(-.013,.013),1.91+j*.024-.12*math.sin(k*math.pi/29)))
    tube('Fine crown web',pts,[.0028]*len(pts),silk,sides=3)
# Sparse glint-catching hairs and seams on the abdomen, bounded draw cost after join.
for i in range(170):
    t=random.uniform(.2,2.85);p=random.uniform(-1.35,1.35)
    at=Vector((1.14*math.sin(t)*math.sin(p),-1.1+1.44*math.cos(t),1.52+1.1*math.sin(t)*math.cos(p)))
    normal=Vector((at.x,(at.y+1.1)*.7,at.z-1.52)).normalized()
    end=at+normal*random.uniform(.05,.10)+Vector((0,-.035,0))
    tube('Carapace seta',[at,at.lerp(end,.5),end],[.009,.004,.0005],joint,'Back',4)

print('GEOMETRY_READY',len(parts),flush=True)
# Join by material to minimize surfaces/draw calls; all rigid segments are skinned.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();model=bpy.context.object;model.name='SmilingSpider_Sculpt'
arm_data=bpy.data.armatures.new('SmilingSpiderSkeleton');arm=bpy.data.objects.new('SmilingSpiderRig',arm_data);bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm;model.select_set(False);arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,(a,b,parent) in bone_defs.items():
    eb=arm_data.edit_bones.new(name);eb.head=a;eb.tail=b
    if parent:eb.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');model.parent=arm
mod=model.modifiers.new('Articulated spider skin','ARMATURE');mod.object=arm

# Quaternion keying with two-link inverse kinematics keeps each planted foot still.
fps=30;bpy.context.scene.render.fps=fps
pose_goals={}
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def pulse(t,a,b,c):return smooth((t-a)/(b-a))*(1-smooth((t-b)/(c-b))) if a<t<c else 0
def setbone(name,head,tail):
    pb=arm.pose.bones[name];direction=(Vector(tail)-Vector(head)).normalized()
    rot=Vector((0,1,0)).rotation_difference(direction).to_matrix().to_4x4();rot.translation=Vector(head)
    # Compute local basis from desired parent transforms, not stale evaluated
    # pose matrices. This keeps child segments attached during fast attacks.
    if pb.parent:
        parent_pose=pose_goals.get(pb.parent.name,pb.parent.matrix.copy())
        pb.matrix_basis=pb.bone.matrix_local.inverted() @ pb.parent.bone.matrix_local @ parent_pose.inverted() @ rot
    else:pb.matrix_basis=pb.bone.matrix_local.inverted() @ rot
    pose_goals[name]=rot
def ik_leg(item,root_delta,foot_delta,lift=0,sweep=0):
    names,hip,knee,ankle,toe,idx,side=item
    h=hip+root_delta;a=ankle+foot_delta
    # The knee bends outward in the original anatomical plane.
    d=a-h;dist=max(.001,d.length);direction=d.normalized();L1=(knee-hip).length;L2=(ankle-knee).length
    along=max(.02,min(L1,(dist*dist+L1*L1-L2*L2)/(2*dist)))
    bend=(knee-hip)-direction*(knee-hip).dot(direction);bend.normalize()
    k=h+direction*along+bend*math.sqrt(max(.008,L1*L1-along*along))
    setbone(names[0],h,k);setbone(names[1],k,a);setbone(names[2],a,toe+foot_delta)
def pose(clip,t,total,tell=0,active=0):
    pose_goals.clear()
    for pb in arm.pose.bones:pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
    d=Vector((0,0,.018*math.sin(t*math.tau/2.4)));pitch=0;jaw=0
    feet=[Vector((0,0,0)) for _ in legs]
    if clip=='walk':
        d.z=.03*math.sin(t*math.tau/1.05)
        for n,item in enumerate(legs):
            phase=(t/1.05+((item[5]+(0 if item[6]<0 else 1))%2)*.5)%1
            if phase<.5:
                swing=phase*2;feet[n].y=-.34+.68*smooth(swing);feet[n].z=math.sin(swing*math.pi)*.24
            else:
                stance=(phase-.5)*2;feet[n].y=.34-.68*stance;feet[n].z=0
    elif clip not in ['idle','death']:
        wind=smooth(t/tell);recover=1-smooth((t-tell-active)/(total-tell-active))
        q=max(0,min(1,(t-tell)/active));charge=wind*recover
        if clip=='fang_rush':
            d.y=-.23*charge if t<tell else .24*recover;d.z=-.18*charge;pitch=.10*charge
            for n,item in enumerate(legs):
                feet[n].y=.20*math.sin(t*math.tau*5+n*2)*recover if t>=tell and t<tell+active else 0
                feet[n].z=max(0,math.sin(t*math.tau*5+n*2))*.22*charge
            jaw=.4*pulse(t,tell-.2,tell+.05,tell+active)
        elif clip=='reaping_sweep':
            for n,item in enumerate(legs):
                if item[5]==0 and item[6]>0:
                    feet[n]=Vector((-3.7*smooth(q)*recover, .2*charge,1.2*charge))
            d.x=-.10*charge
        elif clip=='double_bite':
            snap=pulse(t,tell-.15,tell+active*.17,tell+active*.40)+pulse(t,tell+active*.5,tell+active*.79,tell+active*1.05)
            d.y=.32*snap;d.z=-.1*snap;jaw=.48*(charge-snap)
        elif clip=='silk_spit':
            spit=pulse(t,tell-.1,tell+active*.45,tell+active*.9)
            d.z=.10*charge;d.y=-.15*spit;jaw=.6*charge;pitch=-.08*charge
        elif clip=='ground_slam':
            raise_up=wind if t<tell else (1-smooth(q/.45))
            d.z=.30*raise_up-.12*pulse(t,tell,tell+active*.45,tell+active+.25)
            for n,item in enumerate(legs):
                if item[5]<2:feet[n]=Vector((-.14*item[6]*raise_up,.1*raise_up,1.36*raise_up))
        elif clip=='marked_leap':
            # Whole-character translation is collision-controlled by Godot.
            tuck=wind if t<tell else math.sin(q*math.pi)
            d.z=-.28*wind if t<tell else -.16*pulse(t,tell+active*.75,tell+active,total)
            for n,item in enumerate(legs):
                feet[n]=Vector((-item[6]*.65*tuck,0,.45*tuck if t>=tell else 0))
    elif clip=='death':
        f=smooth(t/1.1);d.z=-.36*f
        for n,item in enumerate(legs):feet[n]=Vector((-item[6]*.9*f,0,.16*f))
    root=arm.pose.bones['Root'];root.location=d;root.rotation_quaternion=Quaternion((1,0,0),pitch)
    pose_goals['Root']=root.bone.matrix_local @ root.matrix_basis
    for n,item in enumerate(legs):ik_leg(item,d,feet[n])
    for side,s in [(-1,'L'),(1,'R')]:
        arm.pose.bones['Fang_'+s].rotation_quaternion=Quaternion((0,1,0),side*jaw*.7)
        arm.pose.bones['PedopalpSegmentA_'+s].rotation_quaternion=Quaternion((0,0,1),side*(jaw*.5+.035*math.sin(t*4)))
    arm.pose.bones['Jaw'].rotation_quaternion=Quaternion((1,0,0),-jaw*.5)
    arm.pose.bones['Back'].rotation_quaternion=Quaternion((1,0,0),.026*math.sin(t*3))

attacks=json.loads((ROOT/'Godot/data/smiling_spider_attacks.json').read_text())['attacks']
clips=[('idle',2.4,0,0),('walk',1.05,0,0),('death',2.0,0,0)]+[(a['id'],a['tell']+a['active']+a['recover'],a['tell'],a['active']) for a in attacks]
arm.animation_data_create()
for name,duration,tell,active in clips:
    act=bpy.data.actions.new(name);act.use_fake_user=True;arm.animation_data.action=act
    count=math.ceil(duration*fps)
    for frame in range(count+1):
        t=min(duration,frame/fps);pose(name,t,duration,tell,active)
        for pb in arm.pose.bones:
            pb.keyframe_insert('location',frame=t*fps,group=pb.name)
            pb.keyframe_insert('rotation_quaternion',frame=t*fps,group=pb.name)
    print('AUTHORED_CLIP',name,duration,flush=True)
arm.animation_data.action=None;pose('idle',0,2.4)

# Export conventional glTF skin and actions. Portable base-color vertices, nine
# material surfaces, no runtime procedural geometry or high-resolution hair system.
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);model.select_set(True)
bpy.context.view_layer.objects.active=arm
output=OUT/'smiling_spider.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'smiling_spider_geometry.blend'))
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=True,
    export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
    export_def_bones=True,export_skins=True,export_materials='EXPORT',export_vertex_color='MATERIAL')

# Editable master and a real Eevee studio render of the exported model design.
def aim(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
floor_mat=material('Studio slate',(.012,.017,.018),.4)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));floor=bpy.context.object;floor.name='Render floor';floor.data.materials.append(floor_mat)
for name,loc,energy,color,size in [('Key',(-4,4,7),1550,(.78,.88,1),5),('Edge',(3,-3,5),2000,(1,.31,.18),3),('Face',(1,6,3),850,(1,.80,.58),4)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.color=color;data.shape='DISK';data.size=size
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.location=loc;aim(o,(0,0,1))
camdata=bpy.data.cameras.new('Hero camera');cam=bpy.data.objects.new('Hero camera',camdata);bpy.context.collection.objects.link(cam)
cam.location=(4.7,8.8,4.1);aim(cam,(0,-.2,1.25));camdata.lens=48;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1440;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
if scene.world is None:scene.world=bpy.data.worlds.new('Night studio')
scene.world.color=(.035,.035,.035);scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(WORK/'smiling-spider-render.png')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'smiling_spider.blend'))
report={'model_bytes':output.stat().st_size,'vertices':len(model.data.vertices),'triangles':sum(len(p.vertices)-2 for p in model.data.polygons),'bones':len(arm.data.bones),'clips':[x[0] for x in clips],'portrait_count':4,'source':'Locally authored Blender geometry and motion; portraits adapt MIT Microsoft Rocketbox Luke mesh','master':str(WORK/'smiling_spider.blend')}
(OUT/'model_manifest.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
bpy.ops.render.render(write_still=True)
