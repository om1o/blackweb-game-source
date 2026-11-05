extends SceneTree
## Actual recovered-rig contact checks independent of the environment and art budget.

var player: BlackwebPlayer
var checks: Array[Dictionary] = []
var metrics: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks.append({"check": description, "passed": condition})
	if not condition:
		failures += 1
		push_error(description)

func _frames(count: int) -> void:
	for frame in range(count): await physics_frame

func _palm_centre() -> Vector3:
	var rig := player._luke_skeleton
	var centre := Vector3.ZERO
	for finger in range(1, 5):
		var bone := rig.find_bone("Bip01 R Finger%d" % finger)
		centre += rig.to_global(rig.get_bone_global_pose(bone).origin)
	return centre / 4.0

func _run() -> void:
	for action in ["interact", "flashlight", "hotbar_1", "hotbar_2", "hotbar_3", "crouch", "jump", "sprint", "move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 0.2, 8.0)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.1
	stage.add_child(floor_body)
	var progression := BlackwebProgression.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	player = BlackwebPlayer.new()
	player.progression = progression
	stage.add_child(player)
	player.attach_model(load("res://scenes/luke.tscn"))
	player.active = true
	player.set_view(0.0)
	await _frames(20)
	var torch_grip := player._hand_flashlight.transform
	var initial_wrist := player._hand_mount.global_basis
	for pitch in [-0.80, -0.09, 0.55]:
		player._pitch = pitch
		await _frames(12)
		var contact := player._hand_flashlight.global_position.distance_to(_palm_centre())
		var alignment := (-player._hand_flashlight.global_basis.z.normalized()).dot(-player.camera.global_basis.z.normalized())
		metrics.append({"pose": "torch", "pitch": pitch, "palm_distance": contact, "beam_dot_camera": alignment})
		_check(player._hand_flashlight.transform.is_equal_approx(torch_grip), "Torch cannot slide or spin within the palm at pitch %.2f" % pitch)
		_check(contact < 0.045 and alignment > 0.93, "Torch stays at the anatomical finger base and inside the aim cone at pitch %.2f" % pitch)
	_check(not player._hand_mount.global_basis.is_equal_approx(initial_wrist), "The real wrist changes orientation to aim the fixed torch")
	_check(player.lamp.global_position.distance_to(player._hand_flashlight.to_global(Vector3(0, 0, -0.13))) < 0.002, "Visible beam starts at the held torch lens")
	player._pitch = -0.09
	player.select_quick_slot(2)
	await _frames(15)
	var candy_grip := player._hand_candy.transform
	var body := player._hand_candy.get_node("CandyBarBody") as Node3D
	var wrapper_grip := body.transform
	var ready_contact := player._hand_candy.global_position.distance_to(_palm_centre())
	_check(ready_contact < 0.045 and player._hand_candy.position.length() > 0.05, "Candy wrapper rests in the fingers rather than at the wrist joint")
	player.health = 50.0
	player.use_selected_item()
	while player._action_time < 0.58: await physics_frame
	var bite_contact := player._hand_candy.global_position.distance_to(_palm_centre())
	var tip := body.to_global(Vector3(0.0685, 0.0, 0.0))
	var mouth := player._candy_mouth_world()
	metrics.append({"pose": "candy_bite", "palm_distance": bite_contact, "mouth_tip_distance": tip.distance_to(mouth), "wrist_mouth_distance": player._hand_mount.global_position.distance_to(mouth)})
	_check(player._hand_candy.transform.is_equal_approx(candy_grip) and body.transform.is_equal_approx(wrapper_grip), "Candy and wrapper keep their palm contact throughout the lift")
	_check(bite_contact < 0.045 and tip.distance_to(mouth) < 0.04 and player._hand_mount.global_position.distance_to(mouth) > 0.09, "Chocolate reaches the lips while the wrist remains outside the face")
	while player._action_kind != &"": await physics_frame
	player.select_quick_slot(1)
	await _frames(12)
	_check(player._hand_knife.visible and player._knife_wrist_override_applied and not player._item_wrist_override_applied, "Knife returns to its own unchanged grip after eating")
	player.add_item(&"bandage", 1)
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == &"bandage": player.equip_inventory_cell(index, 2)
	player.select_quick_slot(2)
	player.use_selected_item()
	await _frames(12)
	_check(not player._item_wrist_override_applied and not player._knife_wrist_override_applied and player._hand_bandage_roll.visible, "Two-handed supply actions clear the item-specific wrist override")
	var report := {"kind": "actual rig palm contact and action transitions", "checks": checks.size(), "failures": failures, "results": checks, "metrics": metrics}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/hand-contact-tests.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("Hand contact: %d checks, %d failures" % [checks.size(), failures])
	print("Contact metrics: ", JSON.stringify(metrics))
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(stage)
	stage.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures == 0 else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)
