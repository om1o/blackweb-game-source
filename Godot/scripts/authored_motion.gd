extends RefCounted
## CC0 Quaternius poses. Rest-direction alignment corrects T-pose to Luke's A-pose.
const DATA := "res://assets/generated/authored_motion_samples.json"
var rig: Skeleton3D
var clips: Dictionary = {}
var rest: Dictionary = {}
var indices: Dictionary = {}
var alignment: Dictionary = {}
var axes := Basis.IDENTITY
var hip_height := 1.0
var clock := 0.0
var air_time := 0.0
var land_time := 1.0
var was_airborne := false
var touched: Array[int] = []
var last_clip := "Idle_Loop"
var previous_clip := "Idle_Loop"
var transition := 1.0

func bind(target: Skeleton3D) -> void:
	rig = target
	if not FileAccess.file_exists(DATA): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	clips = data.clips
	for i in rig.get_bone_count():
		indices[rig.get_bone_name(i)] = i
		rest[i] = rig.get_bone_global_rest(i)
	var hip: Vector3 = rest[indices["Bip01 Pelvis"]].origin
	var up: Vector3 = (rest[indices["Bip01 Head"]].origin-hip).normalized()
	var right: Vector3 = (rest[indices["Bip01 R UpperArm"]].origin-rest[indices["Bip01 L UpperArm"]].origin).normalized()
	var back := right.cross(up).normalized()
	axes = Basis(right,back.cross(right).normalized(),back)
	hip_height = (hip-rest[indices["Bip01 L Foot"]].origin).dot(up)
	var children := {"Pelvis":"Spine","Spine":"Spine1","Spine1":"Spine2","Spine2":"Neck","Neck":"Head"}
	for side in ["L ","R "]:
		for pair in [["Clavicle","UpperArm"],["UpperArm","Forearm"],["Forearm","Hand"],["Hand","Finger2"],["Thigh","Calf"],["Calf","Foot"],["Foot","Toe0"]]:
			children[side+pair[0]] = side+pair[1]
	for key in data.rest_directions:
		var short: String = key.trim_prefix("Bip01 ")
		if not indices.has(key) or not children.has(short): continue
		var child := "Bip01 " + str(children[short])
		if not indices.has(child): continue
		var direction: Vector3 = axes.inverse() * (rest[indices[child]].origin-rest[indices[key]].origin).normalized()
		var v: Array = data.rest_directions[key]
		alignment[key] = Basis(Quaternion(direction,Vector3(v[0],v[1],v[2]).normalized()))

func clear_overrides() -> void:
	if not is_instance_valid(rig): return
	for i in touched: rig.set_bone_global_pose_override(i,Transform3D.IDENTITY,0.0,false)
	touched.clear()

func reset() -> void:
	clear_overrides()
	clock=0.0
	air_time=0.0
	land_time=1.0
	was_airborne=false
	last_clip="Idle_Loop"
	previous_clip=last_clip
	transition=1.0

func locomotion(delta: float,crouching: bool,airborne: bool,vertical: float,speed: float,base_time := -1.0) -> bool:
	if clips.is_empty(): return false
	clock += delta * (clampf(speed/1.65,.45,1.3) if speed>.15 and not airborne else 1.0)
	air_time = air_time+delta if airborne else 0.0
	land_time = 0.0 if was_airborne and not airborne else land_time+delta
	was_airborne = airborne
	var selected := "Idle_Loop"
	if crouching: selected="Crouch_Fwd_Loop" if speed>.15 else "Crouch_Idle_Loop"
	elif airborne: selected="Jump_Loop"
	elif land_time<.18: selected="Jump_Land"
	elif speed>2.3: selected="Jog_Fwd_Loop"
	elif speed>.15: selected="Walk_Loop"
	if selected!=last_clip:
		previous_clip=last_clip
		last_clip=selected
		transition=0.0
	transition=minf(1.0,transition+delta/0.16)
	var baked := selected in ["Idle_Loop","Walk_Loop","Jog_Fwd_Loop"] and base_time>=0.0
	# Those three exact retargets are already baked into Luke's AnimationPlayer.
	# Avoid a second full skeleton solve on every ordinary idle/walking frame.
	if baked and transition>=1.0: return true
	var sample_time := fmod(clock,float(clips[selected].duration))
	if baked: sample_time=fmod(base_time,float(clips[selected].duration))
	if selected=="Jump_Loop": sample_time=clampf(air_time,.0,.6)
	if selected=="Jump_Land": sample_time=land_time
	if transition<1.0: apply_clip(previous_clip,fmod(clock,float(clips[previous_clip].duration)),1.0,false,not airborne)
	apply_clip(selected,sample_time,smoothstep(0.0,1.0,transition),false,not airborne)
	return true

func attack(normalized_time: float,moving := false) -> void:
	var phase := clampf(normalized_time,0.0,1.0)
	# One authored strike, with a short entry and a settled recovery. No second IK swing.
	var blend := smoothstep(0.0,.10,phase)*(1.0-smoothstep(.72,1.0,phase))
	apply_clip("Sword_Attack",phase*float(clips.Sword_Attack.duration),blend,moving,not moving)

func reaction(elapsed: float) -> void:
	apply_clip("Hit_Chest",minf(elapsed,.333),sin(clampf(elapsed/.45,0,1)*PI)*.4,true,false)

func apply_clip(id: String,time: float,blend: float,upper_only: bool,move_hip: bool) -> void:
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
		var qa: Array=a.q[n]
		var qb: Array=b.q[n]
		var q := Quaternion(qa[0],qa[1],qa[2],qa[3]).normalized().slerp(Quaternion(qb[0],qb[1],qb[2],qb[3]).normalized(),fraction)
		targets[int(indices[name])] = axes*Basis(q)*alignment.get(name,Basis.IDENTITY)*axes.inverse()*rest[int(indices[name])].basis
	var ordered := targets.keys()
	ordered.sort()
	for index in ordered:
		var current := rig.get_bone_global_pose(index)
		# A child may still have the previous layer's GLOBAL override. Its origin
		# must follow the newly blended parent, not that stale world position.
		# Blend rotations first, then rebuild the chain at its authored lengths.
		var parent := rig.get_bone_parent(index)
		var origin := current.origin
		if parent>=0: origin=rig.get_bone_global_pose(parent)*rig.get_bone_pose_position(index)
		var rotation := current.basis.orthonormalized().slerp((targets[index] as Basis).orthonormalized(),blend)
		var desired := Transform3D(rotation,origin)
		if index==indices["Bip01 Pelvis"] and move_hip:
			var dy := lerpf(float(a.hip[1]),float(b.hip[1]),fraction)
			desired.origin = current.origin.lerp(rest[index].origin + axes.y*clampf(dy,-.65,.08)*hip_height,blend)
		rig.set_bone_global_pose_override(index,desired,1.0,true)
		if not touched.has(index): touched.append(index)
