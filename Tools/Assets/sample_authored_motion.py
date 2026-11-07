"""Bake selected CC0 Quaternius Standard clips, preserving source rest directions.

Blender --background --python sample_authored_motion.py -- SOURCE_GLB OUTPUT_JSON
No character geometry from the animation pack is included in the runtime data.
"""
import bpy, sys, json, math, hashlib
from pathlib import Path
from mathutils import Matrix

source, output = map(Path, sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mapping = {'pelvis':'Bip01 Pelvis','spine_01':'Bip01 Spine','spine_02':'Bip01 Spine1',
           'spine_03':'Bip01 Spine2','neck_01':'Bip01 Neck','Head':'Bip01 Head'}
for side, short in [('l','L'),('r','R')]:
    for a,b in [('clavicle','Clavicle'),('thigh','Thigh'),('calf','Calf'),('foot','Foot'),
                ('ball','Toe0'),('upperarm','UpperArm'),('lowerarm','Forearm'),('hand','Hand')]:
        mapping[a+'_'+side]='Bip01 '+short+' '+b
children = {'pelvis':'spine_01','spine_01':'spine_02','spine_02':'spine_03','spine_03':'neck_01','neck_01':'Head'}
for s in ['l','r']:
    for a,b in [('clavicle','upperarm'),('upperarm','lowerarm'),('lowerarm','hand'),('hand','middle_01'),('thigh','calf'),('calf','foot'),('foot','ball')]:
        children[a+'_'+s]=b+'_'+s
def rest(k): return rig.matrix_world @ rig.data.bones[k].matrix_local
up=(rest('Head').translation-rest('pelvis').translation).normalized()
right=(rest('upperarm_r').translation-rest('upperarm_l').translation).normalized()
back=right.cross(up).normalized(); up=back.cross(right).normalized()
axes=Matrix((right,up,back)).transposed(); inv=axes.inverted()
height=(rest('pelvis').translation-(rest('foot_l').translation+rest('foot_r').translation)*.5).dot(up)
joints=list(mapping)
directions={mapping[k]:list(inv @ (rest(child).translation-rest(k).translation).normalized()) for k,child in children.items()}
names=['Idle_Loop','Walk_Loop','Jog_Fwd_Loop','Sprint_Loop','Crouch_Idle_Loop','Crouch_Fwd_Loop',
       'Jump_Start','Jump_Loop','Jump_Land','Sword_Idle','Sword_Attack','Hit_Chest','Interact','Idle_Torch_Loop']
result={'schema':2,'provider':'Quaternius / Gonzalo Furnier','license':'CC0-1.0',
        'source':'https://quaternius.itch.io/universal-animation-library',
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'fps':30,
        'rest_directions':directions,'clips':{}}
for track in rig.animation_data.nla_tracks: track.mute=True
for name in names:
    action=next(a for a in bpy.data.actions if a.name==name or a.name.startswith(name+'_'))
    rig.animation_data.action=action
    if hasattr(action,'slots') and action.slots: rig.animation_data.action_slot=action.slots[0]
    first,last=action.frame_range
    fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
    duration=(last-first)/fps
    samples=[]
    for i in range(math.ceil(duration*30)+1):
        frame=first+min(duration,i/30)*fps
        bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
        rotations=[]
        for k in joints:
            current=rig.matrix_world @ rig.pose.bones[k].matrix
            delta=inv @ (current.to_3x3().normalized() @ rest(k).to_3x3().normalized().inverted()) @ axes
            q=delta.to_quaternion().normalized()
            rotations.append([round(q.x,6),round(q.y,6),round(q.z,6),round(q.w,6)])
        hip=rig.matrix_world @ rig.pose.bones['pelvis'].matrix
        shift=inv @ (hip.translation-rest('pelvis').translation)/height
        samples.append({'q':rotations,'hip':[round(v,6) for v in shift]})
    result['clips'][name]={'duration':round(duration,6),'bones':[mapping[k] for k in joints],'samples':samples}
    print('AUTHORED_CLIP',name,round(duration,3),len(samples),flush=True)
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
print('AUTHORED_MOTION_READY',output,output.stat().st_size,flush=True)
