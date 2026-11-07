"""Bake PINOC clips into compact canonical rest-relative samples for Luke.
Source GLBs stay in scratch; no bundled X Bot mesh enters the game package.
Run Blender --background --python this.py -- SOURCE_DIR OUTPUT_JSON.
"""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector, Matrix

src, dest = map(Path, sys.argv[sys.argv.index('--')+1:])
mapping = {'Hips':'Bip01 Pelvis','Spine':'Bip01 Spine','Spine1':'Bip01 Spine1','Spine2':'Bip01 Spine2','Neck':'Bip01 Neck','Head':'Bip01 Head'}
for side, short in [('Left','L'),('Right','R')]:
    for a,b in [('UpLeg','Thigh'),('Leg','Calf'),('Foot','Foot'),('ToeBase','Toe0'),('Arm','UpperArm'),('ForeArm','Forearm'),('Hand','Hand')]:
        mapping[side+a]='Bip01 '+short+' '+b
result={'schema':1,'provider':'PINOC','fps':30,'space':'anatomical right/up/back, rest-relative global rotation','clips':{}}
for path in sorted(src.glob('*.glb')):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    names={b.name.split(':')[-1]:b.name for b in rig.data.bones}
    def rest(k): return rig.matrix_world @ rig.data.bones[names[k]].matrix_local
    up=(rest('Head').translation-rest('Hips').translation).normalized()
    right=(rest('RightArm').translation-rest('LeftArm').translation).normalized()
    back=right.cross(up).normalized(); up=back.cross(right).normalized()
    canonical=Matrix((right,up,back)).transposed(); inv=canonical.inverted()
    height=(rest('Hips').translation-(rest('LeftFoot').translation+rest('RightFoot').translation)*.5).dot(up)
    action=rig.animation_data.action
    first,last=action.frame_range
    fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
    duration=(last-first)/fps
    joints=[k for k in mapping if k in names]
    samples=[]
    for i in range(int(math.ceil(duration*30))+1):
        frame=first+min(duration,i/30)*fps
        bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
        q=[]
        for k in joints:
            current=rig.matrix_world @ rig.pose.bones[names[k]].matrix
            delta=inv @ (current.to_3x3().normalized() @ rest(k).to_3x3().normalized().inverted()) @ canonical
            quat=delta.to_quaternion().normalized()
            q.append([round(quat.x,6),round(quat.y,6),round(quat.z,6),round(quat.w,6)])
        hip=rig.matrix_world @ rig.pose.bones[names['Hips']].matrix
        shift=inv @ (hip.translation-rest('Hips').translation)/height
        samples.append({'q':q,'hip':[round(v,6) for v in shift]})
    result['clips'][path.stem]={'duration':duration,'bones':[mapping[k] for k in joints],'samples':samples}
    print('SAMPLED',path.stem,duration,len(samples),height,flush=True)
dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
print('PINOC_SAMPLES_READY',dest, dest.stat().st_size,flush=True)
