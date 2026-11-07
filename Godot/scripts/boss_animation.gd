extends RefCounted
## Six authored skeletal clips for the recovered spider rig, not PINOC motions.
## Keep the animation timeline and combat windows on the same physics clock.
static func install(visual: Node3D, player: AnimationPlayer, attacks: Array) -> int:
	var skeleton := visual.find_child("*Skeleton3D*", true, false) as Skeleton3D
	if skeleton == null or player == null: return 0
	player.play("idle")
	player.advance(0.0)
	var library := AnimationLibrary.new()
	var count := 0
	for data: Dictionary in attacks:
		var clip := Animation.new()
		var tell := float(data.tell)
		var active := float(data.active)
		clip.length = tell + active + float(data.recover)
		var id := str(data.id)
		var timeline: Array[float] = [0.0, tell * 0.7, tell, tell + active * 0.5, tell + active, clip.length]
		if id == "double_bite": timeline = [0.0, tell * 0.75, tell, tell + 0.18, tell + 0.5, tell + 0.9, tell + active, clip.length]
		for bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone)
			if not (bone_name.begins_with("LegSegment") or bone_name.begins_with("Pedopalp") or bone_name.begins_with("Fang") or bone_name in ["Root", "Back"]): continue
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, NodePath(str(visual.get_path_to(skeleton)) + ":" + bone_name))
			clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			var rest := skeleton.get_bone_pose_rotation(bone)
			for time in timeline:
				var rotation := _pose(id, bone_name, time, tell, active, clip.length)
				clip.track_insert_key(track, time, rest * Quaternion.from_euler(rotation))
		library.add_animation(id, clip)
		count += 1
	if player.has_animation_library("boss"): player.remove_animation_library("boss")
	player.add_animation_library("boss", library)
	return count

static func _pose(id: String, bone: String, time: float, tell: float, active: float, total: float) -> Vector3:
	if time <= 0.0 or time >= total: return Vector3.ZERO
	var side := -1.0 if "_L" in bone else 1.0
	var foreleg := bone.begins_with("LegSegmentA_") and (bone.ends_with("001") or bone.ends_with("002"))
	var lower := bone.begins_with("LegSegmentB_")
	var fang := bone.begins_with("Fang")
	var palp := bone.begins_with("PedopalpSegmentA")
	var body := bone in ["Root", "Back"]
	var winding := time <= tell
	var w := smoothstep(0.0, tell, time) if winding else 1.0 - smoothstep(tell + active, total, time)
	var strike := clampf((time - tell) / active, 0.0, 1.0)
	match id:
		"fang_rush":
			if foreleg: return Vector3(-0.48 if winding else 0.35, side * 0.16, side * 0.20) * w
			if fang: return Vector3(0, 0, side * (0.36 if winding else -0.42)) * w
			if body: return Vector3(0.13 if winding else -0.12, 0, 0) * w
		"reaping_sweep":
			if foreleg and side > 0: return Vector3(-0.8, lerpf(-0.50, 0.72, strike), 0.48) * w
			if body: return Vector3(0, lerpf(-0.10, 0.16, strike), -0.07) * w
		"double_bite":
			var snap := 0.45 if winding else (-0.5 if (strike < 0.3 or strike > 0.65) else 0.38)
			if fang: return Vector3(0, 0, side * snap) * w
			if palp: return Vector3(-0.22, side * snap * 0.7, 0) * w
			if body: return Vector3(0.10 if winding else -0.12 * absf(snap), 0, 0) * w
		"silk_spit":
			if bone == "Back": return Vector3(-0.25, 0, 0) * w
			if bone == "Root": return Vector3(-0.18 if winding else 0.15, 0, 0) * w
			if fang or palp: return Vector3(0, side * 0.35, side * 0.3) * w
		"ground_slam":
			if foreleg: return Vector3(-1.0 if winding else 0.32, side * 0.18, side * 0.30) * w
			if body: return Vector3(-0.22 if winding else 0.14, 0, 0) * w
		"marked_leap":
			if lower: return Vector3(0.42, 0, side * 0.16) * w
			if foreleg: return Vector3(-0.62 if winding else 0.34, side * 0.25, side * 0.35) * w
			if body: return Vector3(0.16 if winding else -0.12, 0, 0) * w
	return Vector3.ZERO
