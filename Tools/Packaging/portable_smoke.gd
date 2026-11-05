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
	var player: Node = game.get("player")
	var spider: Node = game.get("spider")
	_check("Player controller exists", player != null)
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
	_check("All six original modeled web placements load in the packaged house", modeled_webs != null and modeled_webs.get_child_count() == 6)
	var orb_material := new_environment.orb_material() as ShaderMaterial
	var pbr_maps_ok := true
	for channel in ["silk_color", "silk_opacity", "silk_normal", "silk_roughness", "silk_ao"]:
		var texture := orb_material.get_shader_parameter(channel) as Texture2D
		pbr_maps_ok = pbr_maps_ok and texture != null and texture.get_width() == 2048
	_check("Five cobweb PBR channels load at the 2048-pixel runtime limit", pbr_maps_ok)
	_check("Luke skeleton is preserved", _has_skeleton(player, 81))
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
	_check("Luke web-reveal neural voice loads in the packaged opening", luke_voice != null and luke_voice.stream != null and luke_voice.stream.get_length() > 3.0, luke_voice.stream.get_length() if luke_voice != null and luke_voice.stream != null else -1.0)
	var mara_voice := game.find_child("MaraPhoneWarningVoice", true, false) as AudioStreamPlayer
	var phone_reply := game.find_child("LukePhoneReplyVoice", true, false) as AudioStreamPlayer
	_check("Mara's warning and Luke's reply load in the packaged opening", mara_voice != null and mara_voice.stream != null and is_equal_approx(mara_voice.stream.get_length(), 11.5) and phone_reply != null and phone_reply.stream != null and phone_reply.stream.get_length() > 2.0)
	game.call("_resume")
	for tick in 5: await physics_frame
	_check("Packed game resumes actual physics", not paused)
	_check("QA run does not read or write player checkpoints", game.get("progression") != null and not bool(game.get("progression").get("auto_save")) and not bool(game.get("progression").get("auto_load")))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	for frame in 3: await process_frame
	await create_timer(0.12).timeout
	_finish()

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
