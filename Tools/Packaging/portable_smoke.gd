extends SceneTree

var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _report_path := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): _report_path = arg.trim_prefix("--report=")
	call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = null) -> void:
	_checks.append({"label": label, "passed": passed, "detail": detail})
	if not passed: _failures.append(label)

func _run() -> void:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://package-build-info.json"))
	_check("Embedded package manifest is readable", info is Dictionary)
	if not info is Dictionary:
		_finish()
		return
	var missing: Array[String] = []
	var wrong_size: Array[String] = []
	for entry in info.files:
		var file := FileAccess.open(str(entry.path), FileAccess.READ)
		if file == null: missing.append(str(entry.path))
		elif file.get_length() != int(entry.bytes): wrong_size.append(str(entry.path))
	_check("All packaged raw and imported files are readable", missing.is_empty(), {"count": info.files.size(), "missing": missing})
	_check("Every packaged file has its recorded size", wrong_size.is_empty(), wrong_size)
	var texture_placeholders: Array[String] = []
	var missing_imported_textures: Array[String] = []
	for entry in info.files:
		var path: String = str(entry.path)
		if path.begins_with("res://assets/recovered/Arachnophobia/") and path.ends_with(".png") and int(entry.bytes) == 0:
			texture_placeholders.append(path)
			if not ResourceLoader.exists(path): missing_imported_textures.append(path)
	_check("All slim recovered textures resolve through their Godot import mappings", texture_placeholders.size() == int(info.get("elided_source_png_count", 0)) and missing_imported_textures.is_empty(), {"placeholders": texture_placeholders.size(), "missing_imports": missing_imported_textures})
	var sample_texture: Resource = load(texture_placeholders[0]) if not texture_placeholders.is_empty() else null
	_check("Slim texture placeholder loads its imported image", texture_placeholders.is_empty() or (sample_texture is Texture2D and (sample_texture as Texture2D).get_width() > 0), {"sample": texture_placeholders[0] if not texture_placeholders.is_empty() else "none"})
	var wrong_hash: Array[String] = []
	for resource in info.critical_source_sha256:
		if FileAccess.get_sha256(str(resource)).to_upper() != str(info.critical_source_sha256[resource]).to_upper(): wrong_hash.append(str(resource))
	_check("Critical scenes, scripts and layout match source hashes", wrong_hash.is_empty(), wrong_hash)
	var ui_theme := load("res://scripts/horror_theme.gd")
	var film_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/town_intro.json"))
	_check("Generated town cinematic is ready in the package", film_manifest is Dictionary and film_manifest.get("status", "") == "ready_generated_movie")
	var movie: Resource = load(str(film_manifest.get("video_path",""))) if film_manifest is Dictionary else null
	_check("Full-motion town movie loads from package", movie is VideoStreamTheora)
	var film_hash_matches := false
	var film_timeline_valid := false
	if film_manifest is Dictionary:
		var provenance: Variant = film_manifest.get("render_provenance", {})
		var expected_video_hash := str(provenance.get("video_sha256", "")) if provenance is Dictionary else ""
		film_hash_matches = expected_video_hash.length() == 64 and FileAccess.get_sha256(str(film_manifest.get("video_path", ""))).to_lower() == expected_video_hash.to_lower()
		var film_duration := float(film_manifest.get("duration_seconds", 0.0))
		film_timeline_valid = is_equal_approx(film_duration, 42.0)
		for cue in film_manifest.get("captions", []):
			film_timeline_valid = film_timeline_valid and cue is Dictionary and float(cue.get("start", -1.0)) >= 0.0 and float(cue.get("end", 0.0)) > float(cue.get("start", 0.0)) and float(cue.get("end", INF)) <= film_duration
	_check("Reviewed intro movie matches the delivery manifest hash", film_hash_matches)
	_check("Intro keeps its complete 42-second voice and caption timeline", film_timeline_valid)
	var town_audio: Resource = load("res://assets/generated/cinematics/town_audio.ogg")
	_check("Town cinematic has its complete voiced soundtrack", town_audio is AudioStreamOggVorbis and town_audio.get_length() >= 41.9)
	_check("Bundled Barlow interface fonts load from the portable PCK", ui_theme.body_font().data.size() > 10000 and ui_theme.heading_font().data.size() > 10000)
	var document_source := load("res://scripts/tutorial_evidence.gd")
	for title in ["transfer log", "Project 08 record"]:
		var document: Texture2D = document_source.document_texture(title)
		_check("Generated document texture is packaged: " + title, document != null and document.get_width() == 1024 and document.get_height() == 1536)
	var menu_art := load("res://assets/generated/blackweb_menu_corridor_v1.png") as Texture2D
	_check("Original menu corridor artwork loads from the PCK", menu_art != null and menu_art.get_width() > 1000)
	_check("All 102 recovered geometry GLBs are packaged", int(info.raw_recovered_geometry_glb_count) == 102, info.raw_recovered_geometry_glb_count)
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check("Main scene loads from the PCK", scene != null)
	if scene == null:
		_finish()
		return
	var game: Node = scene.instantiate()
	game.set("qa_mode", true)
	root.add_child(game)
	for frame in 3: await process_frame
	_check("Recovered house and runtime props load", bool(game.get("_loaded")))
	var code_note := game.get_node_or_null("PlantCodeNote")
	_check("Folded note contains the updated readable code and exit-key clue", code_note != null and code_note.folded_in_world and code_note.record_text.contains("0  4  1  7") and code_note.record_text.contains("exit keys"))
	_check("Separate exit keys, cuttable lock silk and surveyed map are packaged", game.has_node("VaultExitKeys") and game.has_node("FrontLockWeb") and game.get("house_map") != null)
	_check("Optimized Meshy containment model loads from PCK", game.has_node("ContainmentDrum") and game.get_node("ContainmentDrum").find_children("*","MeshInstance3D",true,false).size()>0)
	var house: Node = game.get_node_or_null("RecoveredHouse")
	var compact_geometry_count := _geometry_instances(house)
	_check("Compact tutorial retains recovered house mesh geometry", compact_geometry_count >= 70 and compact_geometry_count <= 120, compact_geometry_count)
	var tutorial_doors: Array = game.get("_tutorial_doors")
	_check("Five-room tutorial has four operable interior doors", tutorial_doors.size() == 4, tutorial_doors.size())
	var juvenile_spiders := get_nodes_in_group("mini_spider")
	var literock_visuals := 0
	for juvenile in juvenile_spiders:
		if bool(juvenile.get("_visual_is_literock")): literock_visuals += 1
	_check("Packaged tutorial activates the licensed 1K juvenile spider visual", juvenile_spiders.size() >= 3 and literock_visuals >= 3, {"juveniles": juvenile_spiders.size(), "literock_visuals": literock_visuals})
	var enlarged_juveniles := not juvenile_spiders.is_empty()
	for juvenile in juvenile_spiders:
		enlarged_juveniles = enlarged_juveniles and is_equal_approx(float(juvenile.get("visual_size")), 1.6) and is_equal_approx(juvenile.get("_visual_rest_scale").x, 0.48) and juvenile.scale.is_equal_approx(Vector3.ONE)
	_check("Every packaged juvenile uses the larger visual on an unscaled physics actor", enlarged_juveniles)
	var player: Node = game.get("player")
	var spider: Node = game.get("spider")
	_check("Player controller exists", player != null)
	var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/protagonist.json"))
	_check("The packaged protagonist is the requested 21-year-old Luke", identity is Dictionary and identity.get("name", "") == "Luke" and int(identity.get("age", 0)) == 21)
	var luke_source_matches := false
	var luke_scene_matches := false
	if identity is Dictionary:
		var source_hash := str(identity.get("runtime_model_sha256", ""))
		var scene_hash := str(identity.get("runtime_scene_sha256", ""))
		luke_source_matches = source_hash.length() == 64 and FileAccess.get_sha256(str(identity.get("runtime_model_path", ""))).to_lower() == source_hash.to_lower()
		luke_scene_matches = scene_hash.length() == 64 and FileAccess.get_sha256(str(identity.get("scene", ""))).to_lower() == scene_hash.to_lower()
	_check("Luke's packaged model matches his reviewed identity manifest", luke_source_matches)
	_check("The baked runtime Luke scene matches his reviewed identity manifest", luke_scene_matches)
	var adult_body: CollisionShape3D
	for child in spider.get_children():
		if child is CollisionShape3D: adult_body = child
	var adult_navigation: RefCounted = spider.get("_navigation")
	_check("Enlarged adult movement and navigation use the same capsule", adult_body != null and adult_body.shape is CapsuleShape3D
		and is_equal_approx(float(spider.get("visual_size")), 1.3)
		and is_equal_approx(adult_body.shape.radius, 0.37)
		and is_equal_approx(adult_body.shape.radius, adult_navigation.get("_shape").radius)
		and is_equal_approx(adult_body.shape.height, adult_navigation.get("_shape").height))
	var motions: Dictionary = player.get("_pinoc_motion").clips
	_check("Fourteen CC0 authored motion clips are packaged", motions.size()==14 and motions.has("Sword_Attack") and motions.has("Crouch_Fwd_Loop") and motions.has("Jump_Loop"))
	_check("Licensed fluid splash and splatter textures load", load("res://assets/third_party/opengameart_blood/splash_0.png") is Texture2D and load("res://assets/third_party/opengameart_blood/blood_splatter.png") is Texture2D)
	_check("Three story voice assets are packaged", game.get_node("StoryVoice")._data.size()==3)
	var armor = player.get("_armor_visuals")
	_check("All four credited garment meshes bind in the isolated package", armor != null and armor.visual_state().size() == 4 and not armor.visual_state().values().has(true))
	_check("Inventory preview can resolve every starter model from the package", player.item_preview_source(&"flashlight") != null and player.item_preview_source(&"knife") != null and player.item_preview_source(&"candy_bar") != null)
	var covers = load("res://scripts/item_covers.gd")
	for cover_id in covers.IDS:
		var texture: Texture2D = covers.texture(cover_id)
		_check("Baked model cover is packaged: " + str(cover_id), texture != null and texture.get_width() == 256)
	_check("Objective tracker and expanded survey are packaged", game.objective.has_method("update_state") and game.house_map.has_method("set_expanded"))
	var candy: Node = player.get("_hand_candy") if player != null else null
	_check("Original Blender candy and bitten variant load from the PCK", candy != null and candy.has_node("CandyBarBody/CandyReady") and candy.has_node("CandyBarBody/CandyBitten"))
	var supply_factory := load("res://scripts/supply_models.gd")
	var loaded_supplies: Array[String] = []
	for variant in ["BatteryCell", "BandagePack", "FlareStick", "BandageRoll"]:
		var prop: Node3D = supply_factory.make_variant(variant)
		if prop != null:
			if not prop.find_children("*", "MeshInstance3D", true, false).is_empty(): loaded_supplies.append(variant)
			prop.free()
	_check("All four original Blender supply variants load from the PCK", loaded_supplies.size() == 4, loaded_supplies)
	var supply_atlas := load("res://assets/generated/supply_labels_worn_v1.png") as Texture2D
	_check("Worn supply label atlas resolves through its packed import", supply_atlas != null and supply_atlas.get_width() > 1000)
	var residue_texture := load("res://assets/generated/blood_goo_smears_v2.png") as Texture2D
	_check("Preserved earlier transparent blood/goo atlas loads from its packed import", residue_texture != null and residue_texture.get_width() > 1000)
	var new_environment := load("res://scripts/environment_surfaces.gd")
	var blood := new_environment.blood_material() as StandardMaterial3D
	var wall_goo := new_environment.goo_material(false) as ShaderMaterial
	var floor_goo := new_environment.goo_material(true) as ShaderMaterial
	_check("Dry blood and both wet residue materials load from the PCK", blood.albedo_texture != null
		and wall_goo.get_shader_parameter("atlas") is Texture2D
		and wall_goo.get_shader_parameter("detail_normal") is Texture2D
		and floor_goo.get_shader_parameter("detail_normal") is Texture2D)
	var modeled_webs := house.get_node_or_null("BlackwebModeledSilk")
	_check("All eight modeled web placements load in the packaged house", modeled_webs != null and modeled_webs.get_child_count() == 8)
	var orb_material := new_environment.orb_material() as ShaderMaterial
	var pbr_maps_ok := true
	for channel in ["silk_color", "silk_opacity", "silk_normal", "silk_roughness", "silk_ao"]:
		var texture := orb_material.get_shader_parameter(channel) as Texture2D
		pbr_maps_ok = pbr_maps_ok and texture != null and texture.get_width() == 2048
	_check("Five cobweb PBR channels load at the 2048-pixel runtime limit", pbr_maps_ok)
	_check("Replacement Luke's 80-bone skeleton is packaged", _has_skeleton(player, 80))
	_check("Spider skeleton is preserved", _has_skeleton(spider, 142))
	_check("Interactive exit door exists", game.get("_exit_door") != null)
	var adapter: RefCounted = game.get("_material_adapter")
	var materials: Dictionary = adapter.call("get_report") if adapter != null else {}
	_check("Runtime props and door receive recovered material overrides", int(materials.get("applied_surface_count", 0)) > 0, materials.get("applied_surface_count", 0))
	_check("Raw GLB/metadata/PNG imports resolve without missing material channels", bool(materials.get("override_coverage_complete", false)), materials)
	var layout: Dictionary = game.get("_layout")
	var exit_count := 0
	for interaction in layout.get("interactions", []):
		if str(interaction.get("kind", "")) == "exit": exit_count += 1
	_check("Tutorial opening has exactly one configured exit", exit_count == 1 and game.get("_exit_door") != null, exit_count)
	var audio: Dictionary = layout.get("audio", {})
	var audio_paths: Array = audio.get("steps", []).duplicate()
	for key in ["presence", "door"]:
		if audio.has(key): audio_paths.append(audio[key])
	var bad_audio: Array[String] = []
	for audio_path in audio_paths:
		if not load(str(audio_path)) is AudioStream: bad_audio.append(str(audio_path))
	_check("All six recovered audio clips load", audio_paths.size() == 6 and bad_audio.is_empty(), bad_audio)
	var luke_voice := game.find_child("LukeWebRevealVoice", true, false) as AudioStreamPlayer
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/phone_dialogue.json"))
	_check("Luke web-reveal neural voice matches the packaged shared timeline", luke_voice != null and luke_voice.stream != null and is_equal_approx(luke_voice.stream.get_length(), float(dialogue.get("web_reaction", {}).get("duration_seconds", -1))), luke_voice.stream.get_length() if luke_voice != null and luke_voice.stream != null else -1.0)
	var mara_voice := game.find_child("MicaPhoneWarningVoice", true, false) as AudioStreamPlayer
	var phone_reply := game.find_child("LukePhoneReplyVoice", true, false) as AudioStreamPlayer
	_check("Mica's warning and Luke's reply match packaged metadata", mara_voice != null and mara_voice.stream != null and is_equal_approx(mara_voice.stream.get_length(), float(dialogue.get("warning", {}).get("duration_seconds", -1))) and phone_reply != null and phone_reply.stream != null and is_equal_approx(phone_reply.stream.get_length(), float(dialogue.get("reply", {}).get("duration_seconds", -1))))
	game.call("_resume")
	for tick in 5: await physics_frame
	_check("Packed game resumes actual physics", not paused)
	_check("QA run does not read or write player checkpoints", game.get("progression") != null and not bool(game.get("progression").get("auto_save")) and not bool(game.get("progression").get("auto_load")))
	if player is CharacterBody3D:
		await _check_world_evidence(game, player, true)
		await _check_world_evidence(game, player)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	for frame in 3: await process_frame
	var boss_scene := load("res://scenes/boss_encounter.tscn") as PackedScene
	_check("Boss preview scene is packaged", boss_scene != null)
	if boss_scene:
		var preview := boss_scene.instantiate()
		preview.set("qa_mode", true)
		root.add_child(preview)
		for frame in 3: await process_frame
		_check("All six authored boss clips load from the PCK", int(preview.boss.animation_count) == 6)
		_check("Boss preview keeps tutorial saves isolated", not preview.progression.auto_save and not preview.progression.auto_load)
		preview._retry()
		preview.boss.set_physics_process(false)
		preview.boss.take_damage(4)
		_check("Packaged boss damage updates top-screen health bar", preview.boss_bar.visible and preview.boss_bar.meter.value == 116)
		for id in ["arrival", "greeting", "warning", "phase_two", "victory"]:
			var line: Dictionary = preview.dialogue.data.get(id, {})
			var stream: Resource = load(str(line.get("path", ""))) if not line.is_empty() else null
			_check("Packaged boss voice loads: " + id, stream is AudioStream and stream.get_length() > 1)
		preview.dialogue.reset()
		_stop_audio(preview)
		preview.queue_free()
		for frame in 3: await process_frame
	await create_timer(0.12).timeout
	_finish()

func _check_world_evidence(game: Node, player: CharacterBody3D, before_vault_unlock := false) -> void:
	# Use the assembled PCK collision, not direct interaction calls or an assigned
	# focus target. A bounded grid proves a standing route from the real spawn.
	player.set_physics_process(false)
	game.get("progression").set_process(false)
	for group in [&"spider", &"mini_spider"]:
		for actor in get_nodes_in_group(group): actor.set_physics_process(false)
	for door in game.get("_tutorial_doors"):
		if before_vault_unlock and door.name == &"RearNorthDoor":
			door.call("reset_closed")
			door.set("locked", true)
			continue
		door.set("locked", false) # The keypad/unlock transaction has a separate suite.
		if not bool(door.get("opened")): door.call("toggle")
	await create_timer(0.72).timeout
	await physics_frame
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get("_standing_capsule")
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var capsule: CollisionShape3D = player.get("_capsule_shape")
	var cells: Dictionary = {}
	var nearest := Vector2i.ZERO
	var nearest_distance := INF
	for x in range(37):
		for z in range(23):
			var feet := Vector3(-5.05 + x * 0.35, 0.425, -3.85 + z * 0.35)
			query.transform = Transform3D(Basis.IDENTITY, feet + capsule.position)
			query.motion = Vector3.ZERO
			if not space.intersect_shape(query, 1).is_empty(): continue
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.08, feet + Vector3.DOWN * 0.15, 1))
			if floor_hit.is_empty() or floor_hit.normal.y < 0.75: continue
			var cell := Vector2i(x, z)
			cells[cell] = feet
			var distance := feet.distance_squared_to(player.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = cell
	var connected: Array[Vector3] = []
	var pending: Array[Vector2i] = []
	var visited: Dictionary = {}
	if cells.has(nearest):
		query.transform = Transform3D(Basis.IDENTITY, player.global_position + capsule.position)
		query.motion = cells[nearest] - player.global_position
		var initial_sweep := space.cast_motion(query)
		if not initial_sweep.is_empty() and initial_sweep[0] > 0.99:
			pending.append(nearest)
			visited[nearest] = true
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		connected.append(cells[cell])
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not cells.has(next) or visited.has(next): continue
			query.transform = Transform3D(Basis.IDENTITY, cells[cell] + capsule.position)
			query.motion = cells[next] - cells[cell]
			var sweep := space.cast_motion(query)
			if not sweep.is_empty() and sweep[0] > 0.99:
				visited[next] = true
				pending.append(next)
	var condition := " while the vault is locked" if before_vault_unlock else ""
	_check("Standing capsule connects spawn to supported house approaches" + condition, not connected.is_empty(), {"sampled_cells": 851, "connected_cells": connected.size()})
	var camera: Camera3D = player.get("camera")
	var original_pose := player.global_transform
	var original_camera := camera.global_transform
	var paper_focused := false
	# Keep the paper last so its real focused object can receive the input event.
	var targets := ["PlantCodeNote"] if before_vault_unlock else ["PhoneInteraction", "EntryTransferLog", "RecordRoomPage", "VaultCash", "VaultFieldKit", "PlantCodeNote"]
	for name in targets:
		var evidence := game.get_node_or_null(NodePath(name)) as Node3D
		var found := false
		var approach := Vector3.ZERO
		if evidence != null:
			for feet in connected:
				if feet.distance_to(evidence.global_position) >= 2.05: continue
				var eye := feet + Vector3.UP * 1.48
				var aim := evidence.global_position - eye
				var pitch := atan2(aim.y, Vector2(aim.x, aim.z).length())
				if pitch < -1.05 or pitch > 0.65: continue
				player.global_position = feet
				# Position the actual camera at a supported eye-height viewpoint;
				# this tests focus/LOS, not SpringArm camera framing or rendered QA.
				camera.global_position = eye
				camera.look_at(evidence.global_position, Vector3.UP)
				player.call("_update_focus")
				if player.get("_focused") == evidence:
					found = true
					approach = feet
					break
		_check("Actual collision and focus rays can reach " + name + condition, found, {"approach": str(approach), "target": str(evidence.global_position) if evidence != null else "missing"})
		if name == "PlantCodeNote": paper_focused = found
	var headless_input := DisplayServer.get_name() == "headless"
	var input_check := ("E input" if headless_input else "Left click") + " on physically focused paper opens paused readable overlay" + condition
	if paper_focused:
		player.set("active", true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var interaction_event: InputEvent
		if headless_input:
			# Dummy display cannot capture the mouse. Exercise the real E route;
			# only a native run can approve the production captured-click guard.
			var key := InputEventKey.new()
			key.keycode = KEY_E
			key.physical_keycode = KEY_E
			key.pressed = true
			interaction_event = key
		else:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = root.get_visible_rect().size * 0.5
			interaction_event = click
		Input.parse_input_event(interaction_event)
		Input.flush_buffered_events()
		await process_frame
		var overlay: Control = game.get("field_overlay")
		_check(input_check, overlay.visible and overlay.get("mode") == "paper" and paused and bool(game.get("campaign").get("code_found")))
		var release_event := interaction_event.duplicate() as InputEvent
		release_event.set("pressed", false)
		Input.parse_input_event(release_event)
		if overlay.visible: overlay.call("close_overlay")
	else:
		_check(input_check, false, "No reachable physical paper focus was found")
	player.global_transform = original_pose
	camera.global_transform = original_camera
	if before_vault_unlock:
		var vault = game.get_node("RearNorthDoor")
		_check("The clue is readable before obtaining the key or unlocking the vault", vault.locked and not vault.opened and not game.progression.has_keys and not game.campaign.vault_unlocked)
	paused = false

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)

func _has_skeleton(node: Node, bones: int) -> bool:
	if node == null: return false
	for skeleton in node.find_children("*", "Skeleton3D", true, false):
		if skeleton.get_bone_count() == bones: return true
	return false

func _geometry_instances(node: Node) -> int:
	if node == null: return 0
	var count := node.find_children("*", "MeshInstance3D", true, false).size()
	for batch in node.find_children("*", "MultiMeshInstance3D", true, false):
		if batch.multimesh != null: count += batch.multimesh.instance_count
	return count

func _finish() -> void:
	var result := {
		"kind": "isolated portable PCK smoke test",
		"engine": Engine.get_version_info(),
		"resource_directory": ProjectSettings.globalize_path("res://"),
		"working_directory": DirAccess.open(".").get_current_dir(),
		"user_data_directory": OS.get_user_data_dir(),
		"headless": DisplayServer.get_name() == "headless",
		"checks": _checks,
		"failures": _failures,
		"passed": _failures.is_empty(),
		"limits": "Headless package/dependency/startup verification; no rendered approval or full-route human playtest."
	}
	if not _report_path.is_empty():
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "\t"))
		else:
			push_error("Cannot write portable smoke report: " + _report_path)
			quit(2)
			return
	print("PORTABLE_SMOKE checks=%d passed=%s failures=%s cwd=%s user_data=%s" % [_checks.size(), str(_failures.is_empty()), str(_failures), DirAccess.open(".").get_current_dir(), OS.get_user_data_dir()])
	quit(0 if _failures.is_empty() else 1)
