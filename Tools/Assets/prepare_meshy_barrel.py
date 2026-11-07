"""Optimize the user's Meshy Rusty Barrel for the small Godot house."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/GameProjects/BlackwebHouseRebuild-20261103')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath='D:/CodexTemp/Blackweb-EscapePass/meshy-barrel.glb')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
center=(lo+hi)*.5; center.z=lo.z
factor=.86/(hi.z-lo.z)
for o in meshes:
    matrix=o.matrix_world.copy()
    for v in o.data.vertices: v.co=(matrix @ v.co-center)*factor
    o.matrix_world.identity()
    bpy.context.view_layer.objects.active=o
    o.select_set(True)
    o.data.calc_loop_triangles()
    if len(o.data.loop_triangles)>4500:
        mod=o.modifiers.new('Gameplay budget','DECIMATE'); mod.ratio=4500/len(o.data.loop_triangles)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.name='RecoveredContainmentDrum'
for img in bpy.data.images:
    if img.size[0]>1024 or img.size[1]>1024:
        ratio=1024/max(img.size)
        img.scale(max(1,int(img.size[0]*ratio)),max(1,int(img.size[1]*ratio)))
dest=ROOT/'Godot/assets/generated/meshy_containment_drum.glb'
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_animations=False,export_image_format='JPEG',export_jpeg_quality=85)
print('MESHY_DRUM_READY',dest.stat().st_size,flush=True)
