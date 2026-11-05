extends SceneTree
## Real input dispatch, timed damage, physical grip, and world-obstruction tests.

const PlayerScript = preload("res://scripts/player.gd")
const ProgressionScript = preload("res://scripts/progression.gd")

class KnifeTarget extends Node3D:
	var health := 12.0
	var hits := 0
	func take_damage(amount: float) -> void:
		health -= amount
		hits += 1

var checks := 0
var failures := 0
var results: Array[Dictionary] = []
var player: BlackwebPlayer

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _frames(count: int) -> void:
	for frame in range(count): await physics_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Knife mouse-input checks require a native window: omit --headless.")
		quit(2)
		return
	for action_name in ["interact", "flashlight", "hotbar_1", "hotbar_2", "hotbar_3", "crouch", "jump", "sprint", "move_left", "move_right", "move_forward", "move_back"]:
		if not InputMap.has_action(action_name): InputMap.add_action(action_name)
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10.0, 0.3, 10.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.15
	stage.add_child(floor_body)
	var progression := ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	player = PlayerScript.new()
	player.progression = progression
	stage.add_child(player)
	player.attach_model(load("res://scenes/luke.tscn"))
	player.active = true
	player.set_view(0.0)
	player.select_quick_slot(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(30)
	var target := KnifeTarget.new()
	target.position = Vector3(0.0, 0.0, -0.95)
	stage.add_child(target)
	target.add_to_group("mini_spider")
	var grip := player._hand_knife.transform
	_check(player._hand_knife.visible and player._action_kind == &"", "Knife is drawn and remains held before input")
	_mouse(true)
	await process_frame
	_check(player._action_kind == &"knife", "Real left mouse press begins the selected knife action")
	_check(is_equal_approx(target.health, 12.0), "Click does not deal instant damage")
	var first_damage_time := -1.0
	var max_grip_drift := 0.0
	var max_grip_rotation := 0.0
	var hand_samples: Array[Vector3] = []
	for frame in range(42):
		await physics_frame
		if target.hits > 0 and first_damage_time < 0.0: first_damage_time = player._action_time
		max_grip_drift = maxf(max_grip_drift, player._hand_knife.position.distance_to(grip.origin))
		max_grip_rotation = maxf(max_grip_rotation, player._hand_knife.quaternion.angle_to(grip.basis.get_rotation_quaternion()))
		hand_samples.append(player._hand_mount.global_position)
	_check(first_damage_time >= player.KNIFE_HIT_TIME - 0.0001 and first_damage_time <= player.KNIFE_HIT_TIME + 0.035, "Damage lands at the 0.24 second cut crossing")
	_check(target.hits == 1 and is_equal_approx(target.health, 8.0), "One click applies exactly one four-damage hit")
	_check(max_grip_drift < 0.0001 and max_grip_rotation < 0.001, "Handle transform stays fixed in the animated right hand throughout the cut")
	var high := -INF
	var low := INF
	var left := INF
	var right := -INF
	for hand in hand_samples:
		high = maxf(high, hand.y)
		low = minf(low, hand.y)
		left = minf(left, hand.x)
		right = maxf(right, hand.x)
	_check(high - low > 0.35 and right - left > 0.18, "Rendered skeleton hand sweeps diagonally across height and width")
	await _frames(60)
	_check(target.hits == 1, "Holding the mouse does not repeat damage after recovery")
	_check(player._action_kind == &"" and player._hand_knife.visible, "Recovery returns to the held ready pose")
	_mouse(false)
	await process_frame
	_mouse(true)
	await process_frame
	_check(player._action_kind == &"knife", "A fresh click can begin the next swing")
	for press in range(4):
		_mouse(false)
		_mouse(true)
		await process_frame
	await _frames(50)
	_check(target.hits == 2 and is_equal_approx(target.health, 4.0), "Extra clicks during one swing cannot restart its timer or stack hits")
	_mouse(false)
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(1.2, 1.6, 0.1)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector3(0.0, 0.8, -0.50)
	stage.add_child(wall)
	await _frames(3)
	_mouse(true)
	await _frames(50)
	_check(target.hits == 2, "Solid wall between the player and spider blocks the cut")
	_mouse(false)
	wall.queue_free()
	await _frames(3)
	target.position.z = -1.8
	_mouse(true)
	await _frames(50)
	_check(target.hits == 2, "Spider beyond the physical short-knife reach is not hit")
	_mouse(false)
	target.position.z = 0.95
	_mouse(true)
	await _frames(50)
	_check(target.hits == 2, "A spider behind the player is outside the forward slash")
	_mouse(false)
	target.position.z = -0.95
	var other := KnifeTarget.new()
	other.position = Vector3(0.4, 0.0, -1.15)
	stage.add_child(other)
	other.add_to_group("mini_spider")
	_mouse(true)
	await _frames(50)
	_check(target.hits == 3 and other.hits == 0, "A swing damages only the nearest valid target once")
	_mouse(false)
	player.select_quick_slot(0)
	await _frames(3)
	_check(not player._knife_wrist_override_applied and not player._knife_chest_override_applied and not player._hand_knife.visible and player._hand_flashlight.visible, "Switching to the flashlight clears knife wrist and chest overrides")
	var file := FileAccess.open("res://data/knife_swing_test_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "real mouse input, skeleton swing, and melee obstruction checks", "checks": checks, "failures": failures, "first_damage_seconds": first_damage_time, "hand_vertical_sweep_m": high - low, "hand_horizontal_sweep_m": right - left, "max_grip_translation_drift": max_grip_drift, "max_grip_rotation_drift": max_grip_rotation, "results": results}, "  "))
	file.close()
	print("Knife swing: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
