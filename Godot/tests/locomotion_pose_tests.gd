extends SceneTree
## Tests visible recovered-skeleton squat and airborne leg tuck without a store asset.

const PoseScript = preload("res://scripts/locomotion_pose.gd")
var checks := 0
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _bone_world(rig: Skeleton3D, name: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)

func _run() -> void:
	var luke = load("res://scenes/luke.tscn").instantiate()
	root.add_child(luke)
	await process_frame
	var rig: Skeleton3D = luke.find_children("*", "Skeleton3D", true, false)[0]
	var pose = PoseScript.new()
	_check(pose.bind(rig), "Recovered Luke has pelvis, spine, both thighs, calves, and feet")
	var pelvis_before := _bone_world(rig, "Bip01 Pelvis")
	var head_before := _bone_world(rig, "Bip01 Head")
	var ankle_l_before := _bone_world(rig, "Bip01 L Foot")
	var ankle_r_before := _bone_world(rig, "Bip01 R Foot")
	var knee_l_before := _bone_world(rig, "Bip01 L Calf")
	var knee_r_before := _bone_world(rig, "Bip01 R Calf")
	for frame in range(30): pose.apply(1.0 / 60.0, true, false, 0.0, Vector3.FORWARD)
	_check(pose.crouch_weight > 0.99 and pose.jump_weight == 0.0, "Crouch pose blends to a stable squat")
	_check(_bone_world(rig, "Bip01 Pelvis").y < pelvis_before.y - 0.36, "Crouch lowers Luke's actual pelvis")
	_check(_bone_world(rig, "Bip01 Head").y < head_before.y - 0.32, "Crouch lowers Luke's visible head")
	_check(_bone_world(rig, "Bip01 L Calf").distance_to(knee_l_before) > 0.08 and _bone_world(rig, "Bip01 R Calf").distance_to(knee_r_before) > 0.08, "Both knees visibly bend in crouch")
	_check(absf(_bone_world(rig, "Bip01 L Foot").y - ankle_l_before.y) < 0.08 and absf(_bone_world(rig, "Bip01 R Foot").y - ankle_r_before.y) < 0.08, "Squatting feet remain near their starting floor height")
	pose.clear()
	for frame in range(20): pose.apply(1.0 / 60.0, false, true, 5.0, Vector3.FORWARD)
	_check(pose.jump_weight > 0.99 and pose.crouch_weight == 0.0, "Airborne pose blends into leg tuck")
	_check(_bone_world(rig, "Bip01 L Foot").y > ankle_l_before.y + 0.12 and _bone_world(rig, "Bip01 R Foot").y > ankle_r_before.y + 0.09, "Both legs visibly lift during jump")
	_check(absf(_bone_world(rig, "Bip01 L Foot").y - _bone_world(rig, "Bip01 R Foot").y) > 0.025, "Airborne feet are staggered rather than frozen together")
	pose.clear()
	_check(_bone_world(rig, "Bip01 Pelvis").distance_to(pelvis_before) < 0.02 and _bone_world(rig, "Bip01 Head").distance_to(head_before) < 0.02, "Landing resets lower-body overrides")
	var file := FileAccess.open("res://data/locomotion_pose_test_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"kind": "recovered Luke procedural locomotion pose", "checks": checks, "failures": failures, "results": results}, "  "))
		file.close()
	print("Locomotion pose: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
