"""Sample the acquired PINOC Open Door Push motion for the 42-second intro.

Blender --background --python SampleDoorMotion.py -- SOURCE_GLB OUTPUT_JSON
Only skeletal animation is shipped; the source preview character stays external.
"""
import bpy, sys, json, math, hashlib
from pathlib import Path
from mathutils import Matrix

source, output = map(Path, sys.argv[sys.argv.index('--') + 1:])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
names = {bone.name.split(':')[-1]: bone.name for bone in rig.data.bones}
mapping = {'Hips': 'Bip01 Pelvis', 'Spine': 'Bip01 Spine', 'Spine1': 'Bip01 Spine1',
           'Spine2': 'Bip01 Spine2', 'Neck': 'Bip01 Neck', 'Head': 'Bip01 Head'}
children = {'Hips': 'Spine', 'Spine': 'Spine1', 'Spine1': 'Spine2',
            'Spine2': 'Neck', 'Neck': 'Head'}
for side, short in [('Left', 'L'), ('Right', 'R')]:
    for src, dst in [('Shoulder', 'Clavicle'), ('UpLeg', 'Thigh'), ('Leg', 'Calf'),
                     ('Foot', 'Foot'), ('ToeBase', 'Toe0'), ('Arm', 'UpperArm'),
                     ('ForeArm', 'Forearm'), ('Hand', 'Hand')]:
        mapping[side + src] = 'Bip01 ' + short + ' ' + dst
    for parent, child in [('Shoulder', 'Arm'), ('UpLeg', 'Leg'), ('Leg', 'Foot'),
                          ('Foot', 'ToeBase'), ('Arm', 'ForeArm'), ('ForeArm', 'Hand'),
                          ('Hand', 'HandMiddle1')]:
        children[side + parent] = side + child

def rest(key):
    return rig.matrix_world @ rig.data.bones[names[key]].matrix_local

up = (rest('Head').translation - rest('Hips').translation).normalized()
right = (rest('RightArm').translation - rest('LeftArm').translation).normalized()
back = right.cross(up).normalized()
up = back.cross(right).normalized()
axes = Matrix((right, up, back)).transposed()
inverse = axes.inverted()
hip_height = (rest('Hips').translation - (rest('LeftFoot').translation + rest('RightFoot').translation) * .5).dot(up)
directions = {mapping[key]: list(inverse @ (rest(child).translation - rest(key).translation).normalized())
              for key, child in children.items() if key in names and child in names}
joints = [key for key in mapping if key in names]
action = rig.animation_data.action
for track in rig.animation_data.nla_tracks:
    track.mute = True
first, last = action.frame_range
fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
duration = (last - first) / fps
samples = []
for index in range(math.ceil(duration * 30) + 1):
    frame = first + min(duration, index / 30) * fps
    bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
    rotations = []
    for key in joints:
        current = rig.matrix_world @ rig.pose.bones[names[key]].matrix
        delta = inverse @ (current.to_3x3().normalized() @ rest(key).to_3x3().normalized().inverted()) @ axes
        quat = delta.to_quaternion().normalized()
        rotations.append([round(quat.x, 6), round(quat.y, 6), round(quat.z, 6), round(quat.w, 6)])
    hip = rig.matrix_world @ rig.pose.bones[names['Hips']].matrix
    shift = inverse @ (hip.translation - rest('Hips').translation) / hip_height
    samples.append({'q': rotations, 'hip': [round(value, 6) for value in shift]})

result = {'schema': 2, 'provider': 'PINOC curated motion library',
          'asset_id': '17881667-eebd-4eb0-8035-6b0a34c0dfc4',
          'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'fps': 30, 'rest_directions': directions,
          'clips': {'Open_Door_Push': {'duration': round(duration, 6),
                                     'bones': [mapping[key] for key in joints], 'samples': samples}}}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, separators=(',', ':')), encoding='utf8')
print('PINOC_DOOR_READY', duration, len(samples), len(joints), output.stat().st_size, flush=True)
