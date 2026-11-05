"""Read the licensed Luke FBX in Blender; emit fitting measurements outside repo."""
from pathlib import Path
import json
import bpy
from mathutils import Vector

ROOT = Path('D:/GameProjects/BlackwebHouseRebuild-20261103')
WORK = Path('D:/CodexTemp/Blackweb-RealArmor-20261105')
SOURCE = ROOT / 'Godot/assets/luke/Export/Male_Adult_04.fbx'

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(SOURCE), use_anim=False, automatic_bone_orientation=False)
rigs = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
assert len(rigs) == 1, 'Expected the original single Luke armature'
rig = rigs[0]
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()

def bounds(points):
    if not points:
        return None
    low = [min(p[axis] for p in points) for axis in range(3)]
    high = [max(p[axis] for p in points) for axis in range(3)]
    return {'min': low, 'max': high, 'size': [high[i] - low[i] for i in range(3)]}

names = ['Bip01', 'Bip01 Pelvis']
names += [f'Bip01 {side} {part}' for side in ['L', 'R'] for part in ['Thigh', 'Calf', 'Foot', 'Toe0']]
report = {
    'source': str(SOURCE), 'blender_version': bpy.app.version_string,
    'rig': rig.name, 'rig_matrix_world': [list(row) for row in rig.matrix_world],
    'bone_count': len(rig.data.bones), 'bones': {}, 'meshes': [],
}
for name in names:
    bone = rig.data.bones.get(name)
    if bone:
        report['bones'][name] = {
            'head_world': list(rig.matrix_world @ bone.head_local),
            'tail_world': list(rig.matrix_world @ bone.tail_local),
            'matrix_local': [list(row) for row in bone.matrix_local],
            'parent': bone.parent.name if bone.parent else None,
        }
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue
    obj.data.calc_loop_triangles()
    positions = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    groups = {group.index: group.name for group in obj.vertex_groups}
    subsets = {name: [] for name in names if ' Foot' in name or ' Toe0' in name or ' Calf' in name}
    for vertex, position in zip(obj.data.vertices, positions):
        for weight in vertex.groups:
            name = groups.get(weight.group)
            if name in subsets and weight.weight >= 0.35:
                subsets[name].append(position)
    report['meshes'].append({
        'name': obj.name, 'vertices': len(obj.data.vertices),
        'triangles': len(obj.data.loop_triangles),
        'materials': [slot.material.name if slot.material else '' for slot in obj.material_slots],
        'matrix_world': [list(row) for row in obj.matrix_world],
        'bounds_world': bounds(positions),
        'weighted_regions': {name: {'vertex_count': len(points), 'bounds': bounds(points)} for name, points in subsets.items()},
    })
WORK.mkdir(parents=True, exist_ok=True)
(WORK / 'luke_fitting_measurements.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / 'luke_boots_reference.blend'))
print('LUKE_FITTING_REPORT', json.dumps(report), flush=True)
