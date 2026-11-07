extends RefCounted
## Compact PINOC rest-relative animation; the X Bot mesh is never loaded at runtime.
const DATA := "res://assets/generated/pinoc_motion_samples.json"
var rig: Skeleton3D
var clips: Dictionary = {}
var rest: Dictionary = {}
var indices: Dictionary = {}
var axes := Basis.IDENTITY
var hip_height := 1.0
var clock := 0.0
var weight := 0.0
var touched: Array[int] = []
var last_clip := ""

func bind(target: Skeleton3D) -> void:
	rig = target
	if not FileAccess.file_exists(DATA): return
	clips = JSON.parse_string(FileAccess.get_file_as_string(DATA)).clips
	for i in rig.get_bone_count():
		indices[rig.get_bone_name(i)] = i
		rest[i] = rig.get_bone_global_rest(i)
	var hip: Vector3 = rest[indices["Bip01 Pelvis"]].origin
	var up: Vector3 = (rest[indices["Bip01 Head"]].origin-hip).normalized()
	var right: Vector3 = (rest[indices["Bip01 R UpperArm"]].origin-rest[indices["Bip01 L UpperArm"]].origin).normalized()
	var back := right.cross(up).normalized()
	axes = Basis(right,back.cross(right).normalized(),back)
	hip_height = (hip-rest[indices["Bip01 L Foot"]].origin).dot(up)

func clear_overrides() -> void:
	if not is_instance_valid(rig): return
	for i in touched: rig.set_bone_global_pose_override(i,Transform3D.IDENTITY,0.0,false)
	touched.clear()

func reset() -> void:
	clear_overrides()
	clock=0.0
	weight=0.0
	last_clip=""

func locomotion(delta: float,crouching: bool,airborne: bool,vertical: float,speed: float) -> bool:
	if clips.is_empty(): return false
	clock += delta
	weight = move_toward(weight,1.0 if crouching or airborne else 0.0,delta*7.0)
	if weight <= .001: return false
	if crouching:
		last_clip="Crouch_Walk_Forward" if speed>.15 else "Crouching_Idle"
		apply_clip(last_clip,fmod(clock,float(clips[last_clip].duration)),weight,false,true)
	elif airborne:
		last_clip="Jump"
		apply_clip(last_clip,lerpf(.65,1.45,clampf((5.0-vertical)/10.0,0.0,1.0)),weight,false,false)
	else:
		apply_clip(last_clip,0.85 if last_clip=="Jump" else fmod(clock,float(clips[last_clip].duration)),weight,false,last_clip!="Jump")
	return true

func attack(normalized_time: float) -> void:
	if not clips.has("Knife_Slash"): return
	var phase := clampf(normalized_time,0.0,1.0)
	var blend := smoothstep(0.0,.15,phase)*(1.0-smoothstep(.78,1.0,phase))
	apply_clip("Knife_Slash",phase*float(clips.Knife_Slash.duration),blend,true,false)

func reaction(elapsed: float) -> void:
	if not clips.has("Hit_Reaction_Front"): return
	apply_clip("Hit_Reaction_Front",elapsed*2.0,sin(clampf(elapsed/.65,0,1)*PI)*.55,true,false)

func apply_clip(id: String,time: float,blend: float,upper_only: bool,lower_hip: bool) -> void:
	if not clips.has(id) or blend<=.001: return
	var clip: Dictionary=clips[id]
	var frame := clampf(time*30.0,0,float(clip.samples.size()-1))
	var a: Dictionary=clip.samples[int(frame)]
	var b: Dictionary=clip.samples[mini(int(frame)+1,clip.samples.size()-1)]
	var fraction := fmod(frame,1.0)
	var targets: Dictionary={}
	for n in clip.bones.size():
		var name: String=clip.bones[n]
		if not indices.has(name): continue
		if upper_only and (name.contains("Pelvis") or name.contains("Thigh") or name.contains("Calf") or name.contains("Foot") or name.contains("Toe")): continue
		# Hand IK remains authoritative during locomotion, preserving item grip.
		if not upper_only and (name.contains("Arm") or name.contains("Forearm") or name.contains("Hand")): continue
		var qa: Array=a.q[n]
		var qb: Array=b.q[n]
		var q := Quaternion(qa[0],qa[1],qa[2],qa[3]).normalized().slerp(Quaternion(qb[0],qb[1],qb[2],qb[3]).normalized(),fraction)
		targets[int(indices[name])] = axes*Basis(q)*axes.inverse()*rest[int(indices[name])].basis
	var ordered := targets.keys()
	ordered.sort()
	for index in ordered:
		var current := rig.get_bone_global_pose(index)
		var desired := Transform3D(targets[index],current.origin)
		if index==indices["Bip01 Pelvis"] and lower_hip:
			var dy := lerpf(float(a.hip[1]),float(b.hip[1]),fraction)
			desired.origin = rest[index].origin + axes.y*clampf(dy,-.65,0.0)*hip_height
		rig.set_bone_global_pose_override(index,desired,blend,true)
		if not touched.has(index): touched.append(index)
