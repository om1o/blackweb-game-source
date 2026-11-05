extends SceneTree
## Fixed-time inspection of the actual Luke rig. Gameplay timing is tested separately.

var game: Node3D
var player: BlackwebPlayer
var inspection: Camera3D
var fill: OmniLight3D
var rows: Array[Dictionary] = []
var label := "current"

func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0: label = OS.get_cmdline_user_args()[0]
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	player = game.player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(12): await physics_frame
	player.set_physics_process(false)
	player._animation.pause()
	game.status_hud.hide()
	inspection = Camera3D.new()
	inspection.fov = 48.0
	inspection.near = 0.02
	root.add_child(inspection)
	fill = OmniLight3D.new()
	fill.light_energy = 0.45
	fill.omni_range = 0.9
	root.add_child(fill)
	for sample in [[0, "torch-level", -0.09, 0.0], [0, "torch-up", 0.55, 0.0], [1, "knife-ready", -0.09, 0.0], [1, "knife-cut", -0.09, 0.24], [2, "candy-ready", -0.09, 0.0], [2, "candy-bite", -0.09, 0.60]]:
		player._cancel_item_action()
		player.select_quick_slot(sample[0])
		player._pitch = sample[2]
		player.set_view(0.0)
		player.pivot.rotation = Vector3(player._pitch, 0.0, 0.0)
		if sample[3] > 0.0:
			player.health = 50.0
			player.use_selected_item()
			player._tick_item_action(sample[3])
		for frame in range(4):
			player._update_left_supply_arm()
			player._update_right_arm_pose(1.0)
			player._update_held_item_visuals(true, 1.0)
			player._tick_equipment(0.0)
			await process_frame
		await _capture(sample[1])
	var output := ProjectSettings.globalize_path("res://../Evidence/hand-contact-" + label + ".json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "fixed-time native actual-rig contact inspection", "rows": rows}, "  "))
	file.close()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if rows.size() == 6 and rows.all(func(row): return row.saved) else 1)

func _capture(pose_name: String) -> void:
	var hand := player._hand_mount
	var right := player.camera.global_basis.x.normalized()
	var back := player.camera.global_basis.z.normalized()
	var centre := hand.global_position + Vector3.UP * 0.035
	inspection.global_position = centre + right * 0.46 + back * 0.30 + Vector3.UP * 0.12
	if pose_name == "candy-bite":
		centre = player._candy_mouth_world() + right * 0.055
		inspection.global_position = centre - right * 0.40 + back * 0.34 + Vector3.UP * 0.08
	inspection.look_at(centre, Vector3.UP)
	inspection.current = true
	fill.global_position = centre + right * 0.25 + back * 0.15 + Vector3.UP * 0.15
	await RenderingServer.frame_post_draw
	var filename := "hand-contact-" + label + "-" + pose_name + ".png"
	var saved := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Evidence/" + filename)) == OK
	var candy_body := player._hand_candy.get_node("CandyBarBody") as Node3D
	rows.append({"pose": pose_name, "saved": saved, "action_time": player._action_time,
		"candy_tip_mouth_distance": candy_body.to_global(Vector3(0.0685, 0, 0)).distance_to(player._candy_mouth_world()),
		"knife_local_position": player._hand_knife.position, "candy_local_position": player._hand_candy.position,
		"torch_local_rotation": player._hand_flashlight.rotation})
	print("Hand contact capture ", filename)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)
