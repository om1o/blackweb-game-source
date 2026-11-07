"""Rebuild animations from desired parent transforms on the final model.
This pass does not rebuild geometry or change the UVs/materials.
"""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Godot/assets/generated/smiling_spider'
WORK=Path('D:/GameProjects/Blackweb-BossWorkshop/SmilingSpider-v2')
bpy.ops.wm.open_mainfile(filepath=str(WORK/'smiling_spider_final.blend'))
model=bpy.data.objects['SmilingSpider_Sculpt'];arm=bpy.data.objects['SmilingSpiderRig'];legs=[]
for side,suf in [(-1,'L'),(1,'R')]:
    for i in range(4):
        names=[f'LegSegment{letter}_{suf}_{i+1:03d}' for letter in 'ABC']
        a,b,c=[arm.data.bones[n] for n in names]
        legs.append((names,a.head_local.copy(),b.head_local.copy(),c.head_local.copy(),c.tail_local.copy(),i,side))
arm.animation_data.action=None
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
source=(ROOT/'Tools/Assets/build_smiling_spider.py').read_text()
exec(source[source.index('# Quaternion keying'):source.index('# Export conventional')])
bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);model.select_set(True);bpy.context.view_layer.objects.active=arm
bpy.context.scene.frame_set(0)
output=OUT/'smiling_spider.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=True,
    export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
    export_def_bones=True,export_skins=True,export_materials='EXPORT',export_vertex_color='MATERIAL',
    export_image_format='JPEG',export_image_quality=92)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'smiling_spider_final.blend'))
report=json.loads((OUT/'model_manifest.json').read_text());report['model_bytes']=output.stat().st_size
(OUT/'model_manifest.json').write_text(json.dumps(report,indent=2))
print('REBAKE_EXPORTED',output.stat().st_size,flush=True)
bpy.context.scene.render.filepath=str(WORK/'smiling-spider-render.png')
bpy.ops.render.render(write_still=True)
