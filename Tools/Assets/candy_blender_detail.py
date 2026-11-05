import bpy, math, random
from mathutils import Vector
scene=bpy.context.scene
rng=random.Random(71034)
paper=bpy.data.materials['Candy_WornWrapper']; foil=bpy.data.materials['Candy_InnerFoil']; choc=bpy.data.materials['Candy_Chocolate']
for name in ['CandyReady_WrapperBlockout','CandyReady_FoilBlockout','CandyBitten_WrapperBlockout','CandyBitten_FoilBlockout']:
 bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
# Layered sleeve geometry follows the bar rather than a solid enclosing box.
def sleeve(name,parent,x0,x1,width,height,mat,is_foil):
 perimeter=[]
 for i in range(24):
  a=2*math.pi*i/24
  cy=math.cos(a); sz=math.sin(a)
  perimeter.append((math.copysign(abs(cy)**0.30,cy)*width/2,math.copysign(abs(sz)**0.30,sz)*height/2))
 verts=[]; rings=9
 for r in range(rings):
  t=r/(rings-1)
  for i,(y,z) in enumerate(perimeter):
   a=2*math.pi*i/24
   wr=(math.sin(i*2.7+r*1.8)*0.00065+math.sin(r*3.3+i)*0.00040)
   flare=(0.0037 if is_foil else 0.0012)*max(0,(t-0.72)/0.28)
   x=x0+(x1-x0)*t
   if r==rings-1:x+=math.sin(i*1.8)*0.0022+math.sin(i*4.1)*0.0008
   verts.append((x,y+math.cos(a)*(wr+flare),z+0.009+math.sin(a)*(wr+flare)))
 faces=[]
 for r in range(rings-1):
  for i in range(24):
   faces.append((r*24+i,r*24+(i+1)%24,(r+1)*24+(i+1)%24,(r+1)*24+i))
 mesh=bpy.data.meshes.new(name+'_mesh');mesh.from_pydata(verts,[],faces);mesh.update()
 uv=mesh.uv_layers.new(name='WrapperUV')
 for p in mesh.polygons:
  for li in p.loop_indices:
   vi=mesh.loops[li].vertex_index
   uv.data[li].uv=(vi//24/(rings-1),(vi%24)/24)
 o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
 sol=o.modifiers.new('Layer thickness','SOLIDIFY');sol.thickness=0.00012 if is_foil else 0.00024
 return o
for label in ['CandyReady','CandyBitten']:
 r=bpy.data.objects[label]
 sleeve(label+'_FoilInnerSleeve',r,-0.074,0.003,0.0577,0.0202,foil,True)
 sleeve(label+'_TornOuterWrapper',r,-0.077,-0.014,0.0600,0.0224,paper,False)
 # Crimped folded back seal, closed packaging behind the gripping hand.
 verts=[];faces=[]
 for i in range(25):
  y=-0.0295+i*0.059/24
  for j in range(2):
   verts.append((-0.0795-j*0.003,y,0.009+math.sin(i*math.pi)*0.0002+(0.00075 if i%2 else -0.00075)))
 for i in range(24):faces.append((i*2,i*2+1,i*2+3,i*2+2))
 mesh=bpy.data.meshes.new(label+'_Crimp_mesh');mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(label+'_CrimpedSeal',mesh);scene.collection.objects.link(o);o.parent=r;mesh.materials.append(paper)
 sol=o.modifiers.new('Seal thickness','SOLIDIFY');sol.thickness=0.0004
 # Uneven folded foil tabs around the opened end.
 for side in [-1,1]:
  verts=[(-0.004,side*0.026,0.016),(0.006,side*0.029,0.015),(0.003,side*0.033,0.009),(-0.009,side*0.030,0.006)]
  mesh=bpy.data.meshes.new(label+'_FoilFold_mesh');mesh.from_pydata(verts,[],[(0,1,2),(0,2,3)]);mesh.update()
  o=bpy.data.objects.new(label+'_FoldedFoilTab_'+str(side),mesh);scene.collection.objects.link(o);o.parent=r;mesh.materials.append(foil)
  sol=o.modifiers.new('Foil thickness','SOLIDIFY');sol.thickness=0.00012
# Apply bevels before cutting the two bite scallops through the edible end.
bitten=bpy.data.objects['CandyBitten']
edible=[o for o in bitten.children if 'Chocolate' in o.name or 'Moulded' in o.name]
for o in edible:
 bpy.context.view_layer.objects.active=o
 for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
for k,cy in enumerate([-0.010,0.011]):
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=0.018,depth=0.06,location=(0.071,cy+bitten.location.y,0.010))
 cutter=bpy.context.object;cutter.name='BiteCutter'
 for o in edible:
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new('Bite scallop','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.data.objects.remove(cutter,do_unlink=True)
# Consolidate each semantic material to one mesh per variant for inexpensive game rendering.
for label in ['CandyReady','CandyBitten']:
 r=bpy.data.objects[label]
 for mat in [choc,foil,paper]:
  children=[o for o in r.children if o.type=='MESH' and len(o.data.materials) and o.data.materials[0]==mat]
  for o in children:
   bpy.context.view_layer.objects.active=o
   for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.ops.object.select_all(action='DESELECT')
  for o in children:o.select_set(True)
  bpy.context.view_layer.objects.active=children[0]
  bpy.ops.object.join();o=bpy.context.object;o.name=label+'_'+mat.name
# Export-safe principal material values, no procedural shader dependency.
bpy.data.lights['LGT_key'].energy=0.55
bpy.data.lights['LGT_fill'].energy=0.18
scene.world.color=(0.08,0.08,0.08)
result={'roots':[{'name':r.name,'parts':[o.name for o in r.children]} for r in [bpy.data.objects['CandyReady'],bpy.data.objects['CandyBitten']]],'mesh_faces':sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH')}

