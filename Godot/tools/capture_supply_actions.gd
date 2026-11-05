extends SceneTree
## Native gameplay and inspection views; extra fill exists in inspection only.

var game: Node
var player: BlackwebPlayer
var inspect_camera: Camera3D
var inspect_fill: OmniLight3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	player = game.player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(30): await physics_frame
	inspect_camera = Camera3D.new()
	inspect_camera.fov = 52.0
	inspect_camera.near = 0.02
	root.add_child(inspect_camera)
	inspect_fill = OmniLight3D.new()
	inspect_fill.light_energy = 0.7
	inspect_fill.omni_range = 1.0
	inspect_fill.shadow_enabled = false
	inspect_fill.visible = false
	root.add_child(inspect_fill)
	player.add_battery_pack(45.0)
	await _select(&"battery_45")
	await _capture("battery-ready")
	player.use_selected_item()
	for frame in range(44): await physics_frame
	await _capture("battery-inserting")
	for frame in range(70): await physics_frame
	player.add_item(&"bandage", 1)
	player.health = 20.0
	await _select(&"bandage")
	await _capture("bandage-ready")
	player.use_selected_item()
	for frame in range(66): await physics_frame
	await _capture("bandage-wrapping")
	for frame in range(125): await physics_frame
	player.add_item(&"flare", 1)
	await _select(&"flare")
	await _capture("flare-ready")
	player.use_selected_item()
	for frame in range(64): await physics_frame
	await _capture("flare-burning")
	print("Supply native captures completed")
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit()

func _select(id: StringName) -> void:
	for index in range(player.inventory.slots.size()):
		if player.inventory.item_at(index) == id:
			player.equip_inventory_cell(index, 2)
			player.select_quick_slot(2)
			break
	for frame in range(30): await physics_frame

func _capture(label: String) -> void:
	player.set_physics_process(false)
	if player._animation: player._animation.pause()
	player.camera.current = true
	inspect_fill.visible = false
	game.status_hud.show()
	await _save(label + "-gameplay.png")
	var hands := player._hand_mount.global_position
	if player._action_kind in [&"battery", &"bandage"] or player._flare_remaining > 0.0:
		hands = hands.lerp(player._left_hand_mount.global_position, 0.5)
	var back := player.camera.global_basis.z.normalized()
	var right := player.camera.global_basis.x.normalized()
	inspect_camera.global_position = hands + back * 0.20 + right * 0.43 + Vector3.UP * 0.14
	inspect_camera.look_at(hands + Vector3.UP * 0.025)
	inspect_camera.current = true
	inspect_fill.global_position = hands + back * 0.18 + Vector3.UP * 0.20
	inspect_fill.visible = true
	game.status_hud.hide()
	await _save(label + "-inspection.png")
	print("Supply pose ", label, " action=", player._action_kind, " time=", player._action_time,
		" right=", player._hand_mount.global_position, " left=", player._left_hand_mount.global_position)
	player.camera.current = true
	inspect_fill.visible = false
	game.status_hud.show()
	if player._animation: player._animation.play()
	player.set_physics_process(true)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../Evidence/" + name)
	print("Saved ", output, " error=", root.get_texture().get_image().save_png(output))

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
