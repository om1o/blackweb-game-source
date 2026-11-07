"""Prepare Microsoft Rocketbox Male_Adult_02 with bounded 1K textures.
Blender --background --python this.py -- SOURCE_FOLDER OUTPUT_GLB
The original MIT source files remain in the scratch acquisition directory.
"""
import bpy,sys
from pathlib import Path
source,output=map(Path,sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(source/'Male_Adult_02.fbx'),use_anim=False)
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH' and 'hipoly' not in obj.name.lower(): bpy.data.objects.remove(obj,do_unlink=True)
# FBX uses a centimetre-scaled armature. Bake object transforms so Godot's
# skeleton, attached equipment and armour all share metre-sized coordinates.
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj.type in {'MESH','ARMATURE'}: obj.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for obj in bpy.context.scene.objects:
    if obj.type!='MESH': continue
    for slot in obj.material_slots:
        mat=slot.material
        part='opacity' if 'opacity' in mat.name.lower() else ('head' if 'head' in mat.name.lower() else 'body')
        mat.use_nodes=True
        nodes=mat.node_tree.nodes; nodes.clear()
        surface=nodes.new('ShaderNodeBsdfPrincipled'); out=nodes.new('ShaderNodeOutputMaterial')
        mat.node_tree.links.new(surface.outputs['BSDF'],out.inputs['Surface'])
        surface.inputs['Roughness'].default_value=.82 if part=='body' else .67
        for kind in ['color'] if part=='opacity' else ['color','normal']:
            image=bpy.data.images.load(str(source/f'm003_{part}_{kind}.tga'),check_existing=True)
            image.scale(1024,1024)
            image.file_format='PNG' if part=='opacity' else 'JPEG'
            image.filepath_raw=str(source/f'm003_{part}_{kind}.{ "png" if part=="opacity" else "jpg" }')
            image.save()
            tex=nodes.new('ShaderNodeTexImage'); tex.image=image
            if kind=='color':
                mat.node_tree.links.new(tex.outputs['Color'],surface.inputs['Base Color'])
                if part=='opacity':
                    mat.node_tree.links.new(tex.outputs['Alpha'],surface.inputs['Alpha'])
                    mat.surface_render_method='DITHERED'
            else:
                image.colorspace_settings.name='Non-Color'
                normal=nodes.new('ShaderNodeNormalMap')
                mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
                mat.node_tree.links.new(normal.outputs['Normal'],surface.inputs['Normal'])
        mat.name='LukeV2_'+part
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False,
                         export_image_format='AUTO',export_materials='EXPORT')
print('LUKE_REPLACEMENT_READY',output,output.stat().st_size,flush=True)
