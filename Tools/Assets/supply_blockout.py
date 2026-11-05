import bpy, math
from mathutils import Vector
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
def mat(name,color,rough,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;m.diffuse_color=(*color,1);return m
metal=mat('SupplyNickel',(0.32,0.35,0.35),0.36,0.82);dark=mat('SupplyDarkRubber',(0.025,0.029,0.026),0.84)
battery=mat('BatteryLabel',(0.14,0.19,0.16),0.68);bandage=mat('BandageLabel',(0.67,0.65,0.56),0.93);paper=mat('SupplyPaperEdges',(0.48,0.47,0.39),0.95);flare=mat('FlareLabel',(0.36,0.038,0.014),0.88)
def root(name,loc):
 o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.location=loc;return o
def cylinder(name,radius,depth,z,material,parent,vertices=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(0,0,z));o=bpy.context.object;o.name=name;o.parent=parent;o.data.materials.append(material);b=o.modifiers.new('Edge softening','BEVEL');b.width=0.00035;b.segments=2;return o
def box(name,size,mat,parent):
 bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=parent;o.data.materials.append(mat);b=o.modifiers.new('Paper edge','BEVEL');b.width=.002;b.segments=3;return o
r=root('BatteryCell',(-.125,-.025,.02525));cylinder('BatteryBlockout',.00725,.0505,0,battery,r)
r=root('BandagePack',(-.018,-.025,.013));box('BandageBlockout',(.114,.072,.026),bandage,r)
r=root('FlareStick',(.105,.015,.095));cylinder('FlareBlockout',.0135,.19,0,flare,r)
def aim(o,t):o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('CAM_main');o=bpy.data.objects.new('CAM_main',d);scene.collection.objects.link(o);o.location=(.38,-.48,.36);aim(o,(0,0,.070));d.type='ORTHO';d.ortho_scale=.38;d.clip_start=.001;scene.camera=o
for name,loc,energy,radius in [('LGT_key',(-.3,-.25,.35),5,.22),('LGT_fill',(.30,.20,.30),2,.20)]:
 d=bpy.data.lights.new(name,'POINT');d.energy=energy;d.shadow_soft_size=radius;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc
scene.world=bpy.data.worlds.new('SupplyStudioWorld');scene.world.color=(.12,.12,.12)
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=960;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.film_transparent=True
result={'roots':['BatteryCell','BandagePack','FlareStick'],'objects':len(bpy.data.objects)}
