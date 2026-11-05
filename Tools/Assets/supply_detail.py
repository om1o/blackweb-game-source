import bpy, math
from mathutils import Vector
scene=bpy.context.scene
for name in ['BatteryBlockout','BandageBlockout','FlareBlockout']:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
metal=bpy.data.materials['SupplyNickel'];dark=bpy.data.materials['SupplyDarkRubber'];paper=bpy.data.materials['SupplyPaperEdges'];battery=bpy.data.materials['BatteryLabel'];bandage=bpy.data.materials['BandageLabel'];flare=bpy.data.materials['FlareLabel']
def material(name,color,rough,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;m.diffuse_color=(*color,1);return m
cloth=material('BandageGauze',(0.70,0.67,0.57),.97)
cloth_edge=material('BandageLayerEdges',(.49,.48,.41),.96)
def lathe(name,profile,material,parent,n=32,cap=True):
 verts=[];faces=[];uvcoords=[]
 for r,(z,rad) in enumerate(profile):
  for i in range(n+1):
   a=2*math.pi*i/n;verts.append((math.cos(a)*rad,math.sin(a)*rad,z));uvcoords.append((i/n,r/(len(profile)-1)))
 for r in range(len(profile)-1):
  for i in range(n): faces.append((r*(n+1)+i,r*(n+1)+i+1,(r+1)*(n+1)+i+1,(r+1)*(n+1)+i))
 if cap:
  faces += [tuple(range(n-1,-1,-1)), tuple((len(profile)-1)*(n+1)+i for i in range(n))]
 mesh=bpy.data.meshes.new(name+'_mesh');mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  for li in p.loop_indices:uv.data[li].uv=uvcoords[mesh.loops[li].vertex_index]
 o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.parent=parent;mesh.materials.append(material)
 for p in mesh.polygons:p.use_smooth=len(p.vertices)==4
 return o
r=bpy.data.objects['BatteryCell']
lathe('Battery_PrintSleeve',[(-.0234,.00695),(-.0229,.00725),(.0215,.00725),(.0224,.00698)],battery,r)
lathe('Battery_NegativeCrimp',[(-.02525,.0060),(-.0247,.0070),(-.0237,.0071),(-.0232,.0068)],metal,r)
lathe('Battery_NegativeInset',[(-.0253,.0049),(-.02515,.0050)],dark,r)
lathe('Battery_PositiveShoulder',[(.0214,.0066),(.0224,.0070),(.0233,.0062),(.0235,.0044)],metal,r)
lathe('Battery_InsulationRing',[(.02345,.0043),(.02365,.0043)],dark,r)
lathe('Battery_PositiveContact',[(.02355,.0028),(.0252,.0028),(.02525,.0025)],metal,r)
# Packet top and bottom are one filled pillow shell, with crimped ends.
r=bpy.data.objects['BandagePack']
xs=[-.057,-.053,-.046,-.031,-.015,0,.015,.031,.046,.053,.057]
ys=[-.036,-.032,-.024,-.012,0,.012,.024,.032,.036]
verts=[];faces=[];uvcoords=[]
def h(x,y):
 return .0016+.0114*(max(0,1-(x/.054)**6))*(max(0,1-(y/.034)**6))
for side in [1,-1]:
 for j,y in enumerate(ys):
  for i,x in enumerate(xs):
   wrinkle=.0006*math.sin(i*2.9+j*1.7)*(abs(x)/.057)**3
   z=side*(h(x,y)+wrinkle)
   verts.append((x,y,z));uvcoords.append(((x+.057)/.114,(y+.036)/.072))
w=len(xs);height=len(ys);base=w*height
for side in range(2):
 for j in range(height-1):
  for i in range(w-1):
   f=(side*base+j*w+i,side*base+j*w+i+1,side*base+(j+1)*w+i+1,side*base+(j+1)*w+i)
   faces.append(f if side==0 else tuple(reversed(f)))
boundary=list(range(w))+[j*w+w-1 for j in range(1,height)]+list(range(base-2,base-w-1,-1))+[j*w for j in range(height-2,0,-1)]
for j,a in enumerate(boundary):
 b=boundary[(j+1)%len(boundary)];faces.append((a,b,b+base,a+base))
mesh=bpy.data.meshes.new('BandagePacket_mesh');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(bandage);mesh.materials.append(paper);uv=mesh.uv_layers.new(name='UVMap')
for p in mesh.polygons:
 p.material_index=0 if p.index<(height-1)*(w-1) else 1
 for li in p.loop_indices:uv.data[li].uv=uvcoords[mesh.loops[li].vertex_index]
o=bpy.data.objects.new('Bandage_FoldedPaperPacket',mesh);scene.collection.objects.link(o);o.parent=r
# Distinct soft edge seals, shallow rather than oversized ribs.
for sx in [-1,1]:
 for j in range(14):
  bpy.ops.mesh.primitive_cube_add(size=1,location=(sx*.0545,-.0325+j*.005,.0013))
  o=bpy.context.object;o.name='Bandage_Crimp';o.dimensions=(.004,.0008,.0005);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=r;o.data.materials.append(paper)
r=bpy.data.objects['FlareStick']
lathe('Flare_PaperTube',[(-.092,.0116),(-.089,.0124),(.057,.0124),(.061,.0119)],flare,r)
lathe('Flare_BaseSeal',[(-.095,.0105),(-.094,.012),(-.091,.0123),(-.089,.0117)],dark,r)
profile=[(.059,.0121),(.061,.0135)]
for i in range(8):
 z=.062+i*.0036;profile.extend([(z,.0132),(z+.0010,.0137),(z+.0021,.0137),(z+.0031,.0132)])
profile.extend([(.092,.0131),(.095,.0121)])
lathe('Flare_RibbedIgnitionCap',profile,dark,r)
lathe('Flare_StrikerDisc',[(.0951,.0107),(.0954,.0107)],paper,r)
# A separate unwrapped gauze roll for the forearm-application action.
r=bpy.data.objects.new('BandageRoll',None);scene.collection.objects.link(r);r.location=(-.08,.07,.0225)
o=lathe('Bandage_GauzeRoll',[(-.0275,.006),(-.0275,.0209),(-.026,.0225),(-.018,.0227),(0,.0223),(.018,.0227),(.026,.0225),(.0275,.0209),(.0275,.006),(-.0275,.006)],cloth,r,n=32,cap=False)
o.rotation_euler.y=math.pi/2
# Two visible wound edges spiral into the hollow centre; low-sided bevel curves export to mesh.
for sign in [-1,1]:
 curve=bpy.data.curves.new('GauzeSpiral','CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_depth=.00032;curve.bevel_resolution=1
 sp=curve.splines.new('POLY');sp.points.add(80)
 for i,p in enumerate(sp.points):
  t=i/80;a=t*math.pi*8;rad=.0064+t*.0146;p.co=(sign*.02755,math.cos(a)*rad,math.sin(a)*rad,1)
 o=bpy.data.objects.new('Bandage_WoundEdge',curve);scene.collection.objects.link(o);o.parent=r;curve.materials.append(cloth_edge)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
# Join by material per root; the packet retains its two assigned surfaces.
for name in ['BatteryCell','BandagePack','FlareStick','BandageRoll']:
 root=bpy.data.objects[name]
 bymat={}
 for o in list(root.children):
  if o.type=='MESH':
   key=tuple(m.name if m else '' for m in o.data.materials);bymat.setdefault(key,[]).append(o)
 for objects in bymat.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name=name+'_'+('_'.join(m.name for m in bpy.context.object.data.materials if m))
# Source scene presentation is separate from all four centred object roots.
bpy.data.objects['CAM_main'].data.ortho_scale=.40
result={'roots':{name:[o.name for o in bpy.data.objects[name].children] for name in ['BatteryCell','BandagePack','FlareStick','BandageRoll']},'base_faces':sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH')}
