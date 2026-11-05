import bpy, math, random
from mathutils import Vector
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
random.seed(20261105)
mat=bpy.data.materials.new('WebSilkRough');mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF')
p.inputs['Base Color'].default_value=(.40,.415,.385,1)
p.inputs['Roughness'].default_value=.88
p.inputs['Metallic'].default_value=0
mat.diffuse_color=(.40,.415,.385,1)

def root(name,loc):
 o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.location=loc;return o

def strands(name,paths,parent,radius=.0016,sides=3):
 verts=[];faces=[]
 for path in paths:
  if len(path)<2:continue
  start=len(verts)
  for j,co in enumerate(path):
   t=Vector(path[min(j+1,len(path)-1)])-Vector(path[max(j-1,0)])
   if t.length<1e-8:t=Vector((1,0,0))
   t.normalize();ref=Vector((0,0,1)) if abs(t.z)<.9 else Vector((0,1,0))
   u=t.cross(ref).normalized();v=t.cross(u).normalized()
   taper=.65+.35*math.sin(math.pi*j/max(len(path)-1,1))
   for k in range(sides):
    off=radius*taper*(math.cos(k*math.tau/sides)*u+math.sin(k*math.tau/sides)*v)
    verts.append(tuple(Vector(co)+off))
   if j:
    a=start+(j-1)*sides;b=start+j*sides
    for k in range(sides):faces.append((a+k,a+(k+1)%sides,b+(k+1)%sides,b+k))
  faces.append(tuple(start+k for k in range(sides-1,-1,-1)))
  end=start+(len(path)-1)*sides;faces.append(tuple(end+k for k in range(sides)))
 mesh=bpy.data.meshes.new(name+'Mesh');mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
 for poly in mesh.polygons:poly.use_smooth=True
 return o

def radial(theta,r):
 return (r*1.10*math.cos(theta),.065*math.sin(theta*3)*r*r,r*.91*math.sin(theta))
r=root('WebRadialTorn',(-3,0,1.35));paths=[]
for i in range(24):
 a=math.tau*i/24+.025*math.sin(i*3)
 paths.append([radial(a,j/6) for j in range(7)])
for ring in range(1,10):
 path=[]
 for j in range(49):
  a=math.tau*j/48;rr=ring/10*(1+.035*math.sin(a*5+ring));path.append(radial(a,rr))
 paths.append(path)
strands('Radial_Blockout',paths,r)

def canopy(u,v):
 return (u*1.35,v*.95,-.54*(1-u*u)*(1-v*v)+.04*math.sin(u*4+v*3)*(1-u*u))
r=root('WebSaggingCanopy',(0,0,1.7));paths=[]
for i in range(15):
 v=-1+2*i/14;paths.append([canopy(-1+2*j/20,v) for j in range(21)])
for i in range(13):
 u=-1+2*i/12;paths.append([canopy(u,-1+2*j/18) for j in range(19)])
strands('Canopy_Blockout',paths,r)

def cocoon(a,h):
 x=.63*math.copysign(abs(math.cos(a))**.55,math.cos(a));y=.43*math.copysign(abs(math.sin(a))**.55,math.sin(a))
 scale=.91+.09*math.sin(h*math.pi);return (x*scale,y*scale,.10+h*.87+.035*math.sin(a*3+h*8))
r=root('WebFurnitureCocoon',(3,0,0));paths=[]
for i in range(18):paths.append([cocoon(math.tau*j/40,i/17) for j in range(41)])
for i in range(12):paths.append([cocoon(math.tau*i/12,j/12) for j in range(13)])
strands('Cocoon_Blockout',paths,r)

def aim(o,t):o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('CAM_main');o=bpy.data.objects.new('CAM_main',d);scene.collection.objects.link(o);o.location=(6,-12,6.5);aim(o,(0,0,1));d.type='ORTHO';d.ortho_scale=10.5;scene.camera=o
for name,loc,energy,radius in [('LGT_key',(-3,-3,6),1700,2),('LGT_fill',(4,1,5),700,2)]:
 d=bpy.data.lights.new(name,'POINT');d.energy=energy;d.shadow_soft_size=radius;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc
scene.world=bpy.data.worlds.new('WebStudioWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.018,.025,.026,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1200;scene.render.resolution_y=700;scene.render.resolution_percentage=100
result={'objects':len(scene.objects),'roots':[o.name for o in scene.objects if o.type=='EMPTY']}


# Original deterministic mesh authoring; prepend the strands() helper from blockout.py.
random.seed(51026)
for o in list(bpy.data.objects):
 if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
mat=bpy.data.materials['WebSilkRough'];p=mat.node_tree.nodes.get('Principled BSDF')
p.inputs['Base Color'].default_value=(.57,.585,.535,1);p.inputs['Roughness'].default_value=.84
mat.diffuse_color=(.57,.585,.535,1)

# Orb web: radial supports share an offset hub, with a broken spiral tied to them.
N=30
angles=[math.tau*i/N+.022*math.sin(i*2.7) for i in range(N)]
lengths=[.95+.10*math.sin(i*1.67)+.035*math.cos(i*4.3) for i in range(N)]
def radial_point(i,r):
 i=i%N;a=angles[i];scale=lengths[i]
 return Vector((-.075+r*1.08*scale*math.cos(a),.045*math.sin(a*2.2)*r*r,.035+r*.92*scale*math.sin(a)))
r=bpy.data.objects['WebRadialTorn'];supports=[];fine=[]
for i in range(N):
 end=1.16+.08*math.sin(i*2.1)
 supports.append([tuple(radial_point(i,end*j/7)) for j in range(8)])
# The cut-outs deliberately interrupt the spiral while retaining the radial frame.
for ring in range(1,19):
 line=[]
 for j in range(N+1):
  i=j%N;rr=(ring+(j/N)*.6)/20
  cut=(9<=i<=13 and ring>=10) or (23<=i<=25 and 5<=ring<=10)
  if cut:
   if len(line)>1:fine.append(line)
   line=[];continue
  v=radial_point(i,rr)
  v.y+=.0035*math.sin(j*4.5+ring)
  line.append(tuple(v))
 if len(line)>1:fine.append(line)
# Broken spiral ends sag under their last intact tie, rather than ending cleanly.
for i,ring in [(9,11),(13,13),(9,15),(13,17),(23,6),(25,9)]:
 p0=radial_point(i,ring/20);fine.append([tuple(p0),tuple(p0+Vector((.012,.018,-.045))),tuple(p0+Vector((.020,.032,-.105)))])
for k in range(14):
 i=random.randrange(N);a=radial_point(i,random.uniform(.80,1.08));b=radial_point(i+random.choice([-1,1]),random.uniform(.76,1.0))
 mid=(a+b)*.5+Vector((0,.014,-.017));fine.append([tuple(a),tuple(mid),tuple(b)])
strands('Radial_AnchorBundles',supports,r,.00135,3)
strands('Radial_TornSpiral',fine,r,.00085,3)

# Sheet web: individual tie lines cross a gravity-sagged surface at non-grid angles.
def canopy(u,v):
 z=-.51*(1-u*u)*(1-v*v)+.065*math.sin(3*u+2*v)*(1-u*u)+.025*math.sin(8*v)*(1-v*v)
 return Vector((1.35*u,.95*v,z))
def sheet_path(u0,v0,u1,v1,steps,phase=0):
 pts=[]
 for j in range(steps+1):
  t=j/steps;u=u0+(u1-u0)*t;v=v0+(v1-v0)*t
  v+=.018*math.sin(t*math.pi)*math.sin(7*t+phase)
  pt=canopy(u,v);pt.z-=.009*math.sin(t*math.pi);pts.append(tuple(pt))
 return pts
r=bpy.data.objects['WebSaggingCanopy'];supports=[];fine=[]
for i in range(13):
 v=-.98+1.96*i/12+.015*math.sin(i*3.7)
 supports.append(sheet_path(-1,v,1,max(-1,min(1,v+.18*math.sin(i*2))),20,i))
for i in range(11):
 u=-.98+1.96*i/10+.02*math.sin(i*2.7)
 supports.append(sheet_path(u,-1,max(-1,min(1,u+.22*math.cos(i*2))),1,18,i))
for i in range(33):
 v=random.uniform(-.95,.95);u=random.uniform(-.95,.95)
 if i%2:fine.append(sheet_path(-1,v,1,random.uniform(-.95,.95),18,i))
 else:fine.append(sheet_path(u,-1,random.uniform(-.95,.95),1,18,i))
# Local connecting fibres leave open tears, with density concentrated around low pockets.
for i in range(70):
 u=random.uniform(-.88,.88);v=random.uniform(-.86,.86)
 if (u-.35)**2+(v+.20)**2<.05:continue
 du=random.uniform(-.19,.19);dv=random.uniform(-.25,.25)
 fine.append(sheet_path(u,v,max(-1,min(1,u+du)),max(-1,min(1,v+dv)),3,i))
for i in range(8):
 a=canopy(-.9+i*.24,random.choice([-.96,.96]));fine.append([tuple(a),tuple(a+Vector((.018,0,-.10))),tuple(a+Vector((.028,.008,-.19-random.random()*.12)))])
strands('Canopy_LoadThreads',supports,r,.0014,3)
strands('Canopy_TangledSheet',fine,r,.00085,3)

# Cocoon: uneven wrapping passes follow a rounded, lopsided furniture volume.
def cocoon(a,h):
 ca=math.cos(a);sa=math.sin(a)
 taper=1-.19*max(0,(h-.45)/.55)
 x=.64*math.copysign(abs(ca)**.55,ca)*taper
 y=.45*math.copysign(abs(sa)**.55,sa)*taper+.065*h
 z=.045+h*.94+.028*math.sin(3*a+h*8)+.017*math.sin(7*a+h*5)
 return Vector((x,y,z))
r=bpy.data.objects['WebFurnitureCocoon'];supports=[];fine=[]
for i in range(20):
 h=.05+.90*i/19
 line=[]
 for j in range(37):
  a=math.tau*j/36;hh=h+.024*math.sin(a*2+i*.8)+.018*math.sin(a*5+i)
  line.append(tuple(cocoon(a,hh)))
 fine.append(line)
for i in range(12):
 a=math.tau*i/12;line=[]
 for j in range(15):
  h=j/14;line.append(tuple(cocoon(a+.22*math.sin(h*3+i),h)))
 supports.append(line)
# Diagonal binding crosses side faces and folds over the crown. Irregular negative space stays open.
for i in range(17):
 a=random.uniform(0,math.tau);h=random.uniform(.04,.85)
 fine.append([tuple(cocoon(a+.85*j/11,min(.98,h+.35*j/11))) for j in range(12)])
for i in range(12):
 a=math.tau*i/12;start=cocoon(a,.98);end=cocoon(a+math.pi,.97);line=[]
 for j in range(10):
  t=j/9;pt=start.lerp(end,t);pt.z-=.13*math.sin(math.pi*t);line.append(tuple(pt))
 fine.append(line)
for i in range(8):
 a=math.tau*i/8;pt=cocoon(a,.05)
 fine.append([tuple(pt),tuple(pt+Vector((.04*math.cos(a),.04*math.sin(a),-.025))),tuple(pt+Vector((.15*math.cos(a),.12*math.sin(a),-.07)))])
strands('Cocoon_AnchorThreads',supports,r,.00125,3)
strands('Cocoon_IrregularWrap',fine,r,.0009,3)

# Source scene is a reusable studio; runtime export removes studio nodes and resets root placement.
scene=bpy.context.scene
scene.render.resolution_x=1200;scene.render.resolution_y=700
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
result={'triangles':{},'material':'WebSilkRough'}
for o in scene.objects:
 if o.type=='MESH':
  o.data.calc_loop_triangles();result['triangles'][o.name]=len(o.data.loop_triangles)
result['total_triangles']=sum(result['triangles'].values())


# Prepend imports plus strands() from blockout.py. Keep only two mesh surfaces per variant.
random.seed(51126)
def merge_into(target, extra):
 a=bpy.data.objects[target];old=a.data
 verts=[tuple(v.co) for v in old.vertices]+[tuple(v.co) for v in extra.data.vertices]
 offset=len(old.vertices);faces=[tuple(p.vertices) for p in old.polygons]+[tuple(offset+i for i in p.vertices) for p in extra.data.polygons]
 mesh=bpy.data.meshes.new(target+'DetailedMesh');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(mat)
 for p in mesh.polygons:p.use_smooth=True
 a.data=mesh;bpy.data.objects.remove(extra,do_unlink=True)
 if old.users==0:bpy.data.meshes.remove(old)

def canopy(u,v):
 return Vector((1.35*u,.95*v,-.51*(1-u*u)*(1-v*v)+.065*math.sin(3*u+2*v)*(1-u*u)+.025*math.sin(8*v)*(1-v*v)))
paths=[]
for i in range(90):
 centre=random.choice([(-.45,-.25),(-.12,.35),(.50,.42)])
 u=centre[0]+random.uniform(-.28,.28);v=centre[1]+random.uniform(-.28,.28)
 du=random.uniform(-.32,.32);dv=random.uniform(-.40,.40)
 paths.append([tuple(canopy(max(-.98,min(.98,u+du*j/4)),max(-.98,min(.98,v+dv*j/4)))) for j in range(5)])
extra=strands('Canopy_ClusterTemp',paths,bpy.data.objects['WebSaggingCanopy'],.00065,3)
merge_into('Canopy_TangledSheet',extra)

def cocoon(a,h):
 ca=math.cos(a);sa=math.sin(a);taper=1-.19*max(0,(h-.45)/.55)
 return Vector((.64*math.copysign(abs(ca)**.55,ca)*taper,.45*math.copysign(abs(sa)**.55,sa)*taper+.065*h,.045+h*.94+.028*math.sin(3*a+h*8)+.017*math.sin(7*a+h*5)))
paths=[]
for i in range(100):
 a=random.uniform(0,math.tau);h=random.uniform(.07,.92)
 da=random.uniform(-.95,.95);dh=random.uniform(-.31,.31)
 paths.append([tuple(cocoon(a+da*j/4,max(.025,min(.99,h+dh*j/4)))) for j in range(5)])
extra=strands('Cocoon_ClusterTemp',paths,bpy.data.objects['WebFurnitureCocoon'],.00065,3)
merge_into('Cocoon_IrregularWrap',extra)
result={'triangles':{}}
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.calc_loop_triangles();result['triangles'][o.name]=len(o.data.loop_triangles)
result['total_triangles']=sum(result['triangles'].values())
