extends SceneTree

const MiniSpider = preload("res://scripts/mini_spider.gd")
const AdultSpider = preload("res://scripts/spider.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _literock_faces_forward(juvenile: Node3D) -> bool:
	var skeleton := juvenile.find_child("*Skeleton3D*", true, false) as Skeleton3D
	if skeleton == null: return false
	var head := skeleton.find_bone("head")
	var abdomen := skeleton.find_bone("abdomen_01")
	var fang := skeleton.find_bone("fang_L")
	if mini(head, mini(abdomen, fang)) < 0: return false
	var head_at := juvenile.to_local(skeleton.to_global(skeleton.get_bone_global_rest(head).origin))
	var abdomen_at := juvenile.to_local(skeleton.to_global(skeleton.get_bone_global_rest(abdomen).origin))
	var fang_at := juvenile.to_local(skeleton.to_global(skeleton.get_bone_global_rest(fang).origin))
	return fang_at.z < head_at.z and head_at.z < abdomen_at.z

func _run() -> void:
	var player := Node3D.new()
	player.position = Vector3(10, 0, 0)
	root.add_child(player)
	var juvenile := MiniSpider.new()
	juvenile.auto_bind_progression = false
	root.add_child(juvenile)
	await process_frame
	var literock_available := ResourceLoader.exists(MiniSpider.LITEROCK_VISUAL_PATH)
	_check(is_instance_valid(juvenile._visual_root) and juvenile._visual_root.name == "JuvenileAnimatedSpider",
		"Animated juvenile model imports into the real runtime")
	_check(is_instance_valid(juvenile._visual_animation), "Imported model has an AnimationPlayer")
	_check(juvenile._visual_is_literock == literock_available,
		"Packaged Literock spider is preferred, with CC0 fallback for source checkout")
	for clip in ["attack", "idle", "walk"]:
		_check(juvenile._visual_clips.has(clip), "Imported model includes " + clip + " clip")
	if literock_available:
		_check(juvenile._visual_clips.has("run") and not juvenile._visual_clips.has("death"),
			"Licensed GLB exposes bite, idle, walk and run without inventing a death clip")
		_check(is_equal_approx(juvenile._visual_root.scale.x, 0.30),
			"Juvenile stays under one metre across at its imported metre scale")
		var skeleton := juvenile._visual_root.find_child("*Skeleton3D*", true, false) as Skeleton3D
		_check(is_instance_valid(skeleton) and skeleton.get_bone_count() >= 40,
			"Juvenile has a skinned multi-bone rig")
		_check(_literock_faces_forward(juvenile),
			"Literock head and fangs face actor-forward minus Z rather than chasing backwards")
	juvenile.show()
	juvenile._play_visual("idle")
	_check(juvenile._visual_animation.is_playing(), "Passive early sighting resumes its idle animation")
	juvenile.activate(player)
	if literock_available:
		juvenile.rotation.y = 0.70
		_check(_literock_faces_forward(juvenile), "Activation and world turning preserve the Literock anatomical forward axis")
	juvenile._play_visual("walk")
	_check(juvenile._visual_animation.is_playing() and juvenile._visual_animation.current_animation == juvenile._visual_clips["walk"],
		"Juvenile locomotion selects authored walk animation")
	juvenile._play_visual("attack")
	_check(juvenile._visual_animation.is_playing() and juvenile._visual_animation.current_animation == juvenile._visual_clips["attack"],
		"Juvenile bite selects authored attack animation")
	if literock_available:
		var bite_skeleton := juvenile._visual_root.find_child("*Skeleton3D*", true, false) as Skeleton3D
		var fang := bite_skeleton.find_bone("fang_L")
		_check(fang >= 0, "Imported bite rig has a left fang")
		var before := bite_skeleton.get_bone_pose_rotation(fang)
		await create_timer(0.15).timeout
		var during := bite_skeleton.get_bone_pose_rotation(fang)
		_check(before.angle_to(during) > 0.01, "Authored bite animation visibly moves the fang")
	juvenile.take_damage(20.0)
	_check(not juvenile.active and juvenile._death_remaining > 0.0,
		"Fatal hit leaves a short visible collapse before hiding")
	if not juvenile._visual_clips.has("death"):
		juvenile._physics_process(0.30)
		_check(juvenile._visual_root.rotation.z > 0.15,
			"Model without an authored death clip visibly collapses")
	if literock_available:
		juvenile._on_stage_changed(MiniSpider.Progression.Stage.ENCOUNTER)
		_check(_literock_faces_forward(juvenile), "Checkpoint revival restores the Literock facing correction after death posing")
	juvenile.free()
	var adult := AdultSpider.new()
	adult.auto_bind_progression = false
	adult.mesh_scene = load("res://scenes/spider_visual.tscn") as PackedScene
	adult.idle_animation = &"idle"
	root.add_child(adult)
	await process_frame
	_check(is_instance_valid(adult._attack_skeleton) and adult._attack_bones.has("Fang_L") and adult._attack_bones.has("LegSegmentA_L_001"),
		"Recovered adult exposes front-leg and fang bones for attack posing")
	adult._set_state(AdultSpider.State.WINDUP)
	adult._state_elapsed = adult.windup_seconds * 0.6
	adult._update_attack_tell()
	var front_bone: int = adult._attack_bones.get("LegSegmentA_L_001", -1)
	if front_bone >= 0:
		var base: Quaternion = adult._attack_bone_base["LegSegmentA_L_001"]
		var wound: Quaternion = adult._attack_skeleton.get_bone_pose_rotation(front_bone)
		_check(base.angle_to(wound) > 0.1, "Adult windup moves the skinned front leg")
		adult._set_state(AdultSpider.State.LUNGING)
		adult._state_elapsed = adult.lunge_seconds * 0.7
		adult._update_attack_tell()
		var striking: Quaternion = adult._attack_skeleton.get_bone_pose_rotation(front_bone)
		_check(wound.angle_to(striking) > 0.15, "Adult lunge changes front-leg pose after windup")
	adult.free()
	player.free()
	print("Creature visuals: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
