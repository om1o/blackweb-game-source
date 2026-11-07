"""Original bevelled key ring, authored in Blender. Metres; face lies on XZ."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
out=root/'Godot/assets/generated/exit_keys.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def metal(name,color,roughness):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=.86
    bs.inputs['Roughness'].default_value=roughness
    return m
brass=metal('Aged brushed brass',(.34,.22,.08),.37)
nickel=metal('Worn nickel',(.42,.45,.47),.3)
def finish(obj,mat):
    obj.data.materials.append(mat)
    mod=obj.modifiers.new('Machined softened edges','BEVEL');mod.width=.00055;mod.segments=2
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:p.use_smooth=True
def profile(name,points,thickness):
    n=len(points)
    verts=[(x,z,y) for y in (-thickness/2,thickness/2) for x,z in points]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj
bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,major_radius=.018,minor_radius=.0015,rotation=(0,0,0),location=(0,0,.004))
ring=bpy.context.object;ring.name='SplitSteelRing';finish(ring,nickel)
for index,angle in enumerate((-.34,.30)):
    points=[(-.012,0),(-.016,.009),(-.012,.025),(-.005,.029),(-.005,.076),(.004,.076),(.004,.07),(.009,.07),(.009,.065),(.004,.065),(.004,.058),(.01,.058),(.01,.052),(.004,.052),(.004,.029),(.012,.025),(.016,.009),(.012,0)]
    key=profile('ExitKey' if index==0 else 'SpareKey',points,.0024)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.0055,depth=.012,location=(0,.012,0),rotation=(0,0,0))
    hole=bpy.context.object
    mod=key.modifiers.new('Ring aperture','BOOLEAN');mod.operation='DIFFERENCE';mod.object=hole
    bpy.context.view_layer.objects.active=key;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(hole,do_unlink=True)
    finish(key,brass if index==0 else nickel)
    key.rotation_euler.z=angle;key.location=(index*.006,.009,.005+index*.003)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,0))
    groove=bpy.context.object;groove.name='RecessedKeyway'
    groove.scale=(.001,.022,.00015);groove.location=(.002,.057,.0066+index*.003)
    groove.data.materials.append(metal('Keyway shadow '+str(index),(.06,.05,.03),.6))
    groove.rotation_euler.z=angle
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_apply=True)
report={'asset':'exit_keys.glb','author':'Original Blackweb Blender geometry','license':'Project-authored','objects':len(bpy.context.scene.objects),'triangles':sum(len(o.data.polygons)*2 for o in bpy.context.scene.objects if o.type=='MESH')}
out.with_suffix('.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
