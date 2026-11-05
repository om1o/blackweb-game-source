import bpy, math
from mathutils import Vector
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
def material(name,color,rough,metal=0):
 m=bpy.data.materials.new(name); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
 m.diffuse_color=(*color,1); return m
choc=material('Candy_Chocolate',(0.105,0.042,0.019),0.54)
foil=material('Candy_InnerFoil',(0.38,0.40,0.39),0.36,0.88)
paper=material('Candy_WornWrapper',(0.20,0.045,0.025),0.88)
stripe=material('Candy_FadedPrint',(0.39,0.30,0.16),0.86)
def root(name,y):
 r=bpy.data.objects.new(name,None); scene.collection.objects.link(r); r.location.y=y; return r
def box(name,size,loc,mat,parent,bevel):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat); o.parent=parent
 if bevel:
  m=o.modifiers.new('Manufactured soft edges','BEVEL'); m.width=bevel; m.segments=3
  m=o.modifiers.new('Face normals','WEIGHTED_NORMAL')
 return o
for label,y in [('CandyReady',-0.05),('CandyBitten',0.05)]:
 r=root(label,y)
 box(label+'_ChocolateBase',(0.137,0.055,0.012),(0,0,0.006),choc,r,0.0013)
 for i in range(5):
  for j in range(2):
   box(label+'_MouldedSquare_%d_%d'%(i,j),(0.0248,0.0253,0.006),(-0.052+i*0.026,j*0.027-0.0135,0.014),choc,r,0.0016)
 box(label+'_WrapperBlockout',(0.079,0.059,0.022),(-0.034,0,0.009),paper,r,0.001)
 box(label+'_FoilBlockout',(0.025,0.061,0.023),(0.002,0,0.009),foil,r,0.0005)
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
camd=bpy.data.cameras.new('CAM_main'); cam=bpy.data.objects.new('CAM_main',camd); scene.collection.objects.link(cam); cam.location=(0.19,-0.24,0.31); aim(cam,(0,0,0.009)); camd.type='ORTHO'; camd.ortho_scale=0.29; camd.clip_start=0.001; scene.camera=cam
for name,loc,energy,radius in [('LGT_key',(-0.2,-0.18,0.28),14,0.14),('LGT_fill',(0.16,0.25,0.15),4,0.12)]:
 d=bpy.data.lights.new(name,'POINT'); d.energy=energy; d.shadow_soft_size=radius; o=bpy.data.objects.new(name,d); scene.collection.objects.link(o); o.location=loc
scene.world=bpy.data.worlds.new('CandyStudioWorld'); scene.world.color=(0.18,0.18,0.18)
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=900; scene.render.resolution_y=700; scene.render.resolution_percentage=100
scene.render.film_transparent=True
result={'objects':len(bpy.data.objects),'length_m':0.137,'width_m':0.061,'height_m':0.023,'roots':['CandyReady','CandyBitten']}

