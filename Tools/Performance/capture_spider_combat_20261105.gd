extends SceneTree
## Staged native animation review in the real five-room house, not a human playtest.
## Run with isolated APPDATA/LOCALAPPDATA/TEMP/TMP. Source assets are not modified.

var game: Node3D
var camera: Camera3D
var fill: OmniLight3D
var caption: Label
var rows: Array[Dictionary] = []
var failures: Array[String] = []
const CENTRE := Vector3(5.6, 0.45, -2.1)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		push_error("Spider combat review: actual house did not load")
		quit(1)
		return
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in range(12): await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	_stop_audio_hide_ui(game)
	game.player.set_physics_process(false)
	game.player.hide()
	game.player.global_position = CENTRE + Vector3(-1.35, 0, 0)
	for juvenile in get_nodes_in_group("mini_spider"): juvenile.hide()
	_setup_view()
	var adult = game.spider
	adult.activate(game.player)
	adult.set_physics_process(false)
	adult.global_position = CENTRE
	adult.rotation.y = PI * 0.5
	adult._actual_speed = 0.0
	adult._attack_kind = &"lunge"
	adult._set_state(adult.State.STALKING)
	adult._update_animation(0.3)
	adult._update_attack_tell()
	await _capture("adult-ready", "Recovered adult / resting pose", adult, 0.0)
	adult._set_state(adult.State.WINDUP)
	adult._state_elapsed = 0.60
	adult._update_animation(0.60)
	adult._update_attack_tell()
	await _capture("adult-windup", "Recovered adult / windup at 0.60 s", adult, 0.60)
	adult._set_state(adult.State.LUNGING)
	adult._state_elapsed = 0.33
	adult._actual_speed = adult.lunge_speed
	adult._update_animation(0.33)
	adult._update_attack_tell()
	await _capture("adult-strike", "Recovered adult / strike at 0.33 s; travel frozen", adult, 0.33)
	adult.take_damage(4.0)
	adult._state_elapsed = 0.12
	adult._hurt_remaining = 0.10
	adult._actual_speed = 0.0
	adult._update_animation(0.12)
	adult._update_attack_tell()
	await _capture("adult-stagger", "Recovered adult / hit stagger at 0.12 s", adult, 0.12)
	adult.take_damage(adult.health + 1.0)
	adult._state_elapsed = adult.death_seconds
	adult._update_animation(adult.death_seconds)
	adult._update_attack_tell()
	await _capture("adult-death", "Recovered adult / procedural collapse at 1.10 s", adult, adult.death_seconds)
	adult.hide()
	var mini = game.get_node("MiniSpider1")
	if not mini._visual_is_literock:
		failures.append("Expected licensed Literock juvenile, found fallback")
	else:
		mini.activate(game.player)
		mini.set_physics_process(false)
		mini.global_position = CENTRE
		mini.rotation.y = PI * 0.5
		mini._visual_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		camera.global_position = CENTRE + Vector3(-0.72, 0.55, 0.62)
		camera.look_at(CENTRE + Vector3.UP * 0.16)
		fill.global_position = CENTRE + Vector3(-0.35, 0.80, 0.40)
		fill.light_energy = 0.65
		fill.omni_range = 2.0
		mini._play_visual("idle")
		mini._visual_animation.advance(0.30)
		await _capture("juvenile-ready", "Literock juvenile / idle", mini, 0.0)
		mini._visual_animation.stop()
		mini._play_visual("attack")
		mini._visual_animation.advance(0.28)
		mini._set_combat_state(mini.CombatState.RECOVERY)
		await _capture("juvenile-impact", "Literock bite / 0.28 s gameplay, 0.644 s source", mini, 0.28)
		mini.take_damage(mini.health + 1.0)
		mini._death_remaining = maxf(0.65, mini.corpse_hold_seconds) - 0.65
		await physics_frame
		mini._physics_process(0.0)
		await _capture("juvenile-death", "Literock juvenile / collapse at 0.65 s; travel frozen", mini, 0.65)
	var record := {"kind": "staged native animation review; not a human playtest", "qa_fill": true,
		"adult_position": CENTRE, "user_data_directory": OS.get_user_data_dir(),
		"source_spider_sha256": FileAccess.get_sha256("res://scripts/spider.gd"),
		"source_juvenile_sha256": FileAccess.get_sha256("res://scripts/mini_spider.gd"),
		"rendering_method": RenderingServer.get_current_rendering_method(), "rows": rows, "failures": failures}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/spider-combat-20261105.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	_stop_audio_hide_ui(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("SPIDER_COMBAT_REVIEW captures=", rows.size(), " failures=", failures.size())
	quit(0 if rows.size() == 8 and failures.is_empty() else 1)

func _setup_view() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.03
	root.add_child(camera)
	camera.global_position = Vector3(5.6, 1.60, -0.80)
	camera.look_at(CENTRE + Vector3.UP * 0.32)
	camera.current = true
	fill = OmniLight3D.new()
	fill.name = "QAOnlySpiderCombatFill"
	fill.light_color = Color(1.0, 0.86, 0.78)
	fill.light_energy = 0.60
	fill.omni_range = 3.5
	fill.shadow_enabled = false
	root.add_child(fill)
	fill.global_position = Vector3(4.9, 1.95, -2.9)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 5)
	overlay.add_child(caption)

func _capture(pose: String, description: String, creature: Node3D, staged_time: float) -> void:
	caption.text = "STAGED ANIMATION REVIEW | QA FILL LIGHT | NOT A HUMAN PLAYTEST\n" + description
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var filename := "spider-combat-20261105-" + pose + ".png"
	var saved := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../Evidence/" + filename)) == OK
	if not saved: failures.append("Could not save " + filename)
	var row := {"pose": pose, "saved": saved, "staged_time": staged_time, "camera": camera.global_transform,
		"qa_fill_position": fill.global_position, "qa_fill_energy": fill.light_energy,
		"creature_position": creature.global_position, "health": creature.health,
		"collision_layer": creature.collision_layer, "collision_mask": creature.collision_mask}
	if creature == game.spider:
		row["state"] = creature.State.keys()[creature.state]
		row["base_animation"] = creature.animation_player.current_animation
		row["bone_rotations"] = {}
		for bone_name in ["LegSegmentA_L_001", "LegSegmentB_L_001", "Fang_L", "PedopalpSegmentA_L"]:
			var index: int = creature._attack_skeleton.find_bone(bone_name)
			row.bone_rotations[bone_name] = creature._attack_skeleton.get_bone_pose_rotation(index)
		row["visual_position"] = creature.visual_root.position
		row["visual_rotation"] = creature.visual_root.rotation
	else:
		row["state"] = creature.CombatState.keys()[creature.combat_state]
		row["base_animation"] = creature._visual_animation.current_animation
		row["source_clip_position"] = creature._visual_animation.current_animation_position
		row["playback_speed"] = creature._visual_animation.speed_scale
		row["visual_position"] = creature._visual_root.position
		row["visual_rotation"] = creature._visual_root.rotation
		var skeleton: Skeleton3D = creature._visual_root.find_child("*Skeleton3D*", true, false)
		var head := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin)
		var abdomen := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("abdomen_01")).origin)
		var alignment := (head - abdomen).normalized().dot(-creature.global_basis.z.normalized())
		row["anatomical_forward_dot_actor_forward"] = alignment
		if pose == "juvenile-ready" and alignment < 0.90:
			failures.append("Juvenile anatomical forward does not match attack forward")
	rows.append(row)
	print("SPIDER_COMBAT_CAPTURE ", filename)

func _stop_audio_hide_ui(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	if node is CanvasLayer: node.hide()
	for child in node.get_children(): _stop_audio_hide_ui(child)
