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
