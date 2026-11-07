"""Final UV/export and mouth clearance pass on the refined studio master."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WORK=Path('D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2')
OUT=ROOT/'Godot/assets/generated/smiling_spider'
bpy.ops.wm.open_mainfile(filepath=str(WORK/'smiling_spider.blend'))
model=bpy.data.objects['SmilingSpider_Sculpt'];arm=bpy.data.objects['SmilingSpiderRig']
uv=model.data.uv_layers['ChitinDetail'];model.data.uv_layers.active=uv;uv.active_render=True
for m in model.data.materials:
    for tex in list(m.node_tree.nodes):
        if tex.type=='TEX_IMAGE':
            coordinates=m.node_tree.nodes.new('ShaderNodeUVMap');coordinates.uv_map='ChitinDetail'
            m.node_tree.links.new(coordinates.outputs['UV'],tex.inputs['Vector'])
root_index=model.vertex_groups['Root'].index;jaw_index=model.vertex_groups['Jaw'].index
for v in model.data.vertices:
    groups={g.group for g in v.groups if g.weight>.5}
    if jaw_index in groups:v.co.z+=.08
    # Recess the front carapace behind the sculpted lips, eliminating intersections.
    if root_index in groups and .85<v.co.y<1.21 and abs(v.co.x)<.65 and .62<v.co.z<1.105+.17*(abs(v.co.x)/.69)**2:
        v.co.y=min(v.co.y,.88)
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);model.select_set(True);bpy.context.view_layer.objects.active=arm
output=OUT/'smiling_spider.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=True,
    export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
    export_def_bones=True,export_skins=True,export_materials='EXPORT',export_vertex_color='MATERIAL',
    export_image_format='JPEG',export_image_quality=92)
bpy.context.scene.render.filepath=str(WORK/'smiling-spider-render.png')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'smiling_spider_final.blend'))
report=json.loads((OUT/'model_manifest.json').read_text());report['model_bytes']=output.stat().st_size
report['master']=str(WORK/'smiling_spider_final.blend');report['material']='Original imagegen chitin albedo, 92-quality JPEG embedded in GLB; physical roughness and pores'
(OUT/'model_manifest.json').write_text(json.dumps(report,indent=2))
print('FINAL_GLB',output.stat().st_size,flush=True)
bpy.ops.render.render(write_still=True)
