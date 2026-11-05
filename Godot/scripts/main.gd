extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const InteractionScript = preload("res://scripts/interaction.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
const SpiderScript = preload("res://scripts/spider.gd")
const MiniSpiderScript = preload("res://scripts/mini_spider.gd")
const SpiderProfile = preload("res://scripts/spider_profile.gd")
const Props = preload("res://scripts/props.gd")
const SoundScript = preload("res://scripts/soundscape.gd")
const MaterialAdapter = preload("res://tools/recovered_materials.gd")
const HouseBatching = preload("res://scripts/house_batching.gd")
const HouseDressing = preload("res://scripts/house_dressing.gd")
const TutorialHouse = preload("res://scripts/tutorial_house.gd")
const TutorialDoor = preload("res://scripts/tutorial_door.gd")
const EvidenceScript = preload("res://scripts/tutorial_evidence.gd")
const StatusScript = preload("res://scripts/status_hud.gd")
const StorageScript = preload("res://scripts/storage.gd")
const POWERED_AMBIENT := 0.075
const BLACKOUT_AMBIENT := 0.018
const PRACTICAL_DIM := 0.68
const SupplyScript = preload("res://scripts/supply_pickup.gd")

@export var qa_mode := false

var progression: Node
var player: BlackwebPlayer
var spider: Node3D
var hud: CanvasLayer
var menu: Control
var heading: Label
var objective: Label
var subtitle: Label
var notice: Label
var prompt_label: Label
var status_hud
var hud_picker: OptionButton
var fade: ColorRect
var resume_button: Button
var restart_button: Button
var menu_state: Label
var _layout: Dictionary
var _started := false
var _loaded := false
var _lamps: Array[Light3D] = []
var _base_energy: Array[float] = []
var _power := 1.0
var _power_target := 1.0
var _environment: Environment
var _audio: AudioStreamPlayer
var _exit_door: Node3D
var _exit_tween: Tween
var _leaving := false
var _prop_materials: Dictionary = {}
var _material_adapter = MaterialAdapter.new()
var _presence_model: Node3D
var _presence_tween: Tween
var _batching_report: Dictionary = {}
var _supply_table: Dictionary = {}
var _supply_seed := 0
var _supply_pickups: Array[Node3D] = []
var _storage_units: Array[BlackwebStorage] = []
var _tutorial_doors: Array[Node3D] = []
var _tutorial_evidence: Array[Node3D] = []
var _sighting_spider: Node3D

func _ready() -> void:
	_install_input()
	process_mode = Node.PROCESS_MODE_ALWAYS
	progression = ProgressionScript.new()
	if qa_mode:
		progression.auto_load = false
		progression.auto_save = false
	progression.name = "Progression"
	add_child(progression)
	progression.process_mode = Node.PROCESS_MODE_PAUSABLE
	_create_environment()
	_loaded = _load_house()
	_supply_table = _read_supply_table()
	_supply_seed = 20261103 if qa_mode else randi()
	_create_hud()
	if _loaded:
		player = PlayerScript.new()
		player.progression = progression
		player.name = "Luke"
		add_child(player)
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.position = _vec(_layout.get("player", [0, 0.1, 0]))
		player.spawn_transform = player.transform
		player.set_view(float(_layout.get("player_yaw", 0)))
		progression.player = player
		progression.checkpoint_restored.connect(player.restore_checkpoint)
		progression.checkpoint_restored.connect(_reset_door)
		player.focus_changed.connect(func(t: String): prompt_label.text = t)
		player.stamina_changed.connect(func(v: float): status_hud.set_stamina(v))
		player.flashlight_changed.connect(func(on: bool):
			status_hud.set_flashlight(true, on)
			status_hud.set_battery(player.battery_charge, on))
		player.battery_changed.connect(func(v: float): status_hud.set_battery(v, player._light_on))
		player.inventory_changed.connect(_update_inventory_hud)
		player.quick_slot_changed.connect(func(index: int): status_hud.set_selected_slot(index))
		status_hud.set_selected_slot(player.selected_quick_index)
		status_hud.equip_requested.connect(func(cell_index: int, quick_index: int):
			player.equip_inventory_cell(cell_index, quick_index))
		player.health_changed.connect(func(v: float):
			status_hud.set_health(v))
		player.recovery_changed.connect(_on_recovery)
		var model_path: String = _layout.get("player_model", "")
		if not model_path.is_empty() and ResourceLoader.exists(model_path): player.attach_model(load(model_path))
		_create_interactions()
		_create_storage()
		_create_supplies()
		_create_evidence()
		_create_spider()
		_create_mini_spiders()
		_create_sighting_spider()
		var sounds := SoundScript.new()
		sounds.name = "Soundscape"
		sounds.player = player
		sounds.progression = progression
		sounds.assets = _layout.get("audio", {})
		sounds.phone_position = _vec(_layout.get("phone_position", [-3.4, 1.1, 1.7]))
		add_child(sounds)
		sounds.process_mode = Node.PROCESS_MODE_PAUSABLE
	progression.stage_changed.connect(_on_stage)
	progression.power_changed.connect(func(on: bool): _power_target = 1.0 if on else 0.0)
	progression.subtitle_changed.connect(func(t: String): subtitle.text = t)
	progression.notice_changed.connect(func(t: String): notice.text = t)
	progression.inventory_changed.connect(func():
		objective.text = progression.objective()
		status_hud.set_objective(objective.text))
	if is_instance_valid(player):
		status_hud.set_flashlight(true, player._light_on)
		status_hud.set_battery(player.battery_charge, player._light_on)
		status_hud.set_health(player.health)
		_update_inventory_hud()
	status_hud.set_objective(progression.objective())
	subtitle.text = progression.subtitle
	notice.text = progression.notice
	_on_stage(progression.stage)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _install_input() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_C, "jump": KEY_SPACE, "interact": KEY_E, "flashlight": KEY_F, "pause_game": KEY_ESCAPE, "hud_1": KEY_F1, "hud_2": KEY_F2, "hud_3": KEY_F3, "hud_4": KEY_F4, "hotbar_1": KEY_1, "hotbar_2": KEY_2, "hotbar_3": KEY_3, "inventory_toggle": KEY_I}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.004, 0.006, 0.010)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.25, 0.32, 0.42)
	_environment.ambient_light_energy = POWERED_AMBIENT
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = _environment
	add_child(world)

func _load_house() -> bool:
	if not FileAccess.file_exists("res://data/house_layout.json"):
		push_error("Recovered house layout has not been generated. See recovery status.")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/house_layout.json"))
	if not parsed is Dictionary: return false
	_layout = parsed
	var components = JSON.parse_string(FileAccess.get_file_as_string("res://data/recovered_components.json"))
	if components is Array:
		for component in components:
			var key: String = str(component.mesh).get_file().get_slice(".", 0).to_lower()
			if not _prop_materials.has(key): _prop_materials[key] = component.get("materials", [])
	var scene_path: String = _layout.get("house_scene", "res://scenes/recovered_house.tscn")
	if not ResourceLoader.exists(scene_path): return false
	var scene = load(scene_path)
	if not scene is PackedScene: return false
	var house: Node = scene.instantiate()
	house.name = "RecoveredHouse"
	add_child(house)
	HouseDressing.apply(house)
	var tutorial: Dictionary = TutorialHouse.apply(house)
	if not bool(tutorial.get("success", false)): return false
	_collect_lights(house)
	_prepare_exit_door(house)
	_create_tutorial_doors(house)
	_setup_house_visibility(house)
	if not OS.get_cmdline_user_args().has("--no-static-batching"):
		_batching_report = HouseBatching.new().apply(house)
	# Additional practicals may be placed by the conversion manifest where the
	# cooked asset contained light parameters that did not survive interchange.
	# Omni shadow cubemaps dominate frame time on the target Intel GPU. Keep
	# the practical illumination, and reserve dynamic shadows for Luke's torch.
	var room_shadows := OS.get_cmdline_user_args().has("--room-shadows")
	for settings in _layout.get("lights", []):
		var position := _vec(settings.get("position", [0, 2, 0]))
		if position.x < -5.6 or position.x > 7.8 or position.z < -4.25 or position.z > 4.25:
			continue
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = Color(settings.get("color", "ffd9a5"))
		light.light_energy = float(settings.get("energy", 1.4)) * PRACTICAL_DIM
		light.omni_range = float(settings.get("range", 5.0))
		light.light_specular = 0.35
		light.shadow_enabled = room_shadows and bool(settings.get("shadows", false))
		add_child(light)
		_lamps.append(light)
		_base_energy.append(light.light_energy)
	for entry in _layout.get("additional_props", []):
		var model: String = entry.get("model", "")
		if not model.is_empty() and ResourceLoader.exists(model):
			var prop: Node3D = load(model).instantiate()
			add_child(prop)
			prop.position = _vec(entry.position)
			prop.rotation.y = float(entry.get("yaw", 0))
			prop.scale *= float(entry.get("scale", 1.0))
			if model.ends_with("/SM_Coffeetable.glb") and prop.position.distance_to(Vector3(-1.6, 0.4, -2.0)) < 0.01:
				# The old mansion placement fills the new supply-room doorway:
				# a center ray passes, but Luke's standing capsule cannot enter.
				# Keep the table as entry-room dressing beside the west wall.
				prop.position = Vector3(-4.2, 0.4, -2.0)
			elif model.ends_with("/SM_Couch.glb"):
				# Leave standing-body clearance between the sofa front and the
				# opened supply door, while keeping the sofa inside the south wall.
				prop.position = Vector3(1.2, 0.4, -3.10)
				prop.scale *= 0.90
			_apply_prop_materials(prop, model)
			for mesh in prop.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh: mesh.create_trimesh_collision()
	return true

func _collect_lights(node: Node) -> void:
	if node is Light3D:
		_lamps.append(node)
		_base_energy.append(node.light_energy)
	for child in node.get_children(): _collect_lights(child)

func _create_interactions() -> void:
	for entry in _layout.get("interactions", []):
		var interaction := InteractionScript.new()
		interaction.kind = StringName(entry.kind)
		interaction.label = entry.label
		interaction.progression = progression
		if interaction.kind == &"exit": interaction.activation_handler = _leave_house
		interaction.position = _vec(entry.position)
		interaction.rotation.y = float(entry.get("yaw", 0))
		add_child(interaction)
		var asset: String = entry.get("model", "")
		if not asset.is_empty() and ResourceLoader.exists(asset):
			var visual: Node3D = load(asset).instantiate()
			interaction.add_child(visual)
			visual.scale *= float(entry.get("scale", 1.0))
			_apply_prop_materials(visual, asset)
			interaction.item_visual = visual
			interaction._refresh()
		elif interaction.kind in [&"keys", &"flashlight"]:
			var visual: Node3D = Props.create(interaction.kind)
			interaction.add_child(visual)
			interaction.item_visual = visual
			interaction._refresh()

func _create_storage() -> void:
	# Optional supplies roll once per new opening. Neither fixture gates the route.
	var storage_table: Dictionary = _supply_table.get("storage", {})
	for entry in [
		{"name": "EntryDrawer", "type": &"drawer", "position": Vector3(1.25, 1.15, 2.55)},
		{"name": "HallCabinet", "type": &"cabinet", "position": Vector3(5.35, 1.67, 2.55)}
	]:
		var storage = StorageScript.new()
		storage.name = entry.name
		storage.storage_kind = entry.type
		storage.progression = progression
		storage.player = player
		storage.loot_entries = storage_table.get(entry.name, [])
		storage.loot_seed = _supply_seed + str(entry.name).hash()
		storage.supplies_found.connect(_show_supply_notice)
		if storage.storage_kind == &"drawer":
			storage.clue_text = "PROJECT 08 / Internal record: prisoner tissue was grafted to spider subjects. The altered spiders draw a demonic presence into themselves."
			storage.clue_found.connect(_show_optional_clue)
		storage.position = entry.position
		add_child(storage)
		_storage_units.append(storage)

func _create_evidence() -> void:
	for entry in [
		{"name": "EntryTransferLog", "kind": "paper", "title": "transfer log", "position": Vector3(-3.20, 1.09, 2.12),
			"text": "GREYHAVEN TRANSFER / Prisoner tissue was grafted into common spiders. Subject A14 was moved to this house before dawn."},
		{"name": "RecordRoomPage", "kind": "paper", "title": "Project 08 record", "position": Vector3(2.72, 1.42, 3.20),
			"text": "PROJECT 08 / The altered spiders answer voices that no staff member can hear. The company ordered the records hidden before containment failed."},
		{"name": "VaultCash", "kind": "cash", "title": "unmarked cash", "position": Vector3(5.35, 1.75, 2.82),
			"text": "The company left unmarked cash beside the supplies. Someone was paid to keep this house quiet."},
	]:
		var evidence: Node3D = EvidenceScript.new()
		evidence.name = entry.name
		evidence.evidence_type = entry.kind
		evidence.title = entry.title
		evidence.record_text = entry.text
		evidence.progression = progression
		evidence.position = entry.position
		evidence.discovered.connect(_show_tutorial_evidence)
		add_child(evidence)
		_tutorial_evidence.append(evidence)

func _show_tutorial_evidence(text: String, title: String) -> void:
	subtitle.text = text
	notice.text = "FOUND  /  " + title.to_upper()
	if title != "unmarked cash": status_hud.set_record_found(true)
	await get_tree().create_timer(8.0, false).timeout
	if is_instance_valid(subtitle) and subtitle.text == text:
		subtitle.text = progression.subtitle
		notice.text = progression.notice

func _read_supply_table() -> Dictionary:
	var path := "res://data/supply_spawns.json"
	if not FileAccess.file_exists(path):
		push_warning("Supply spawn table is missing; optional supplies will be absent")
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
		push_warning("Supply spawn table has an invalid schema")
		return {}
	return parsed

func _create_supplies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _supply_seed
	for raw_entry in _supply_table.get("world_pickups", []):
		if not raw_entry is Dictionary: continue
		var entry: Dictionary = raw_entry
		var item := StringName(str(entry.get("item", "")))
		var coordinates: Variant = entry.get("position", [])
		if item not in [&"battery", &"bandage", &"flare"] or not coordinates is Array or coordinates.size() != 3:
			continue
		if rng.randf() >= clampf(float(entry.get("chance", 1.0)), 0.0, 1.0):
			continue
		var pickup: Node3D = SupplyScript.new()
		pickup.name = str(entry.get("id", "Supply"))
		pickup.item_id = item
		pickup.amount = maxf(1.0, float(entry.get("amount", 1)))
		pickup.player = player
		pickup.progression = progression
		pickup.position = _vec(coordinates)
		pickup.picked_up.connect(_show_supply_notice)
		pickup.unavailable.connect(_show_supply_notice)
		add_child(pickup)
		_supply_pickups.append(pickup)

func _reset_supplies() -> void:
	_supply_seed = 20261103 if qa_mode else randi()
	for pickup in _supply_pickups:
		if is_instance_valid(pickup): pickup.reset_pickup()
	for storage in _storage_units:
		if is_instance_valid(storage): storage.reset_loot(_supply_seed + str(storage.name).hash())

func _update_inventory_hud() -> void:
	if is_instance_valid(player) and is_instance_valid(status_hud):
		status_hud.set_inventory_counts(player.inventory_counts())
		status_hud.set_inventory_model(player.inventory_slots(), player.equipped_items())

func _show_supply_notice(text: String) -> void:
	notice.text = text
	await get_tree().create_timer(3.5, false).timeout
	if is_instance_valid(notice) and notice.text == text:
		notice.text = progression.notice

func _show_optional_clue(text: String) -> void:
	var readable := text.replace(" The altered", "\nThe altered")
	subtitle.text = readable
	notice.text = "EXPERIMENT RECORD FOUND  /  OPTIONAL CLUE"
	status_hud.set_record_found(true)
	await get_tree().create_timer(9.0, false).timeout
	if is_instance_valid(subtitle) and subtitle.text == readable:
		subtitle.text = progression.subtitle
		notice.text = progression.notice

func _create_spider() -> void:
	spider = SpiderScript.new()
	SpiderProfile.apply_to(spider, "adult")
	spider.name = "Spider"
	spider.target = player
	spider.progression = progression
	var spider_path: String = _layout.get("spider_model", "")
	if not spider_path.is_empty() and ResourceLoader.exists(spider_path): spider.mesh_scene = load(spider_path)
	spider.idle_animation = &"idle"
	spider.walk_animation = &"walk"
	spider.run_animation = &"run"
	# Doorway-centred routes keep the adult inside the five retained rooms.
	# Every route edge is swept against live collision, including cabinet/doors.
	for z in [-2.0, 2.0]:
		for x in [-2.2, -1.35, -0.20, 1.0, 2.65, 3.75, 4.9, 6.0]:
			spider.navigation_points.append(Vector3(x, 0.45, z))
	spider.navigation_points.append(Vector3(-2.2, 0.45, 0.0))
	spider.position = _vec(_layout.get("spider", [0, 0, -6]))
	if _layout.has("safe_exit"):
		var safe := Marker3D.new()
		safe.name = "ExitRefuge"
		safe.position = _vec(_layout.safe_exit)
		add_child(safe)
		spider.safe_exit_anchor = safe
	if _layout.has("spider_retreat"):
		var retreat := Marker3D.new()
		retreat.name = "SpiderRetreat"
		retreat.position = _vec(_layout.spider_retreat)
		add_child(retreat)
		spider.retreat_anchor = retreat
	add_child(spider)
	spider.process_mode = Node.PROCESS_MODE_PAUSABLE

func _create_mini_spiders() -> void:
	# Small threats join only at the encounter; the opening pickup and exit lane
	# remain clear. Each uses cheap geometry and a small contact-damage value.
	for index in range(2):
		var mini := MiniSpiderScript.new()
		mini.name = "MiniSpider%d" % (index + 1)
		mini.target = player
		mini.progression = progression
		mini.hit_damage = 4.0
		SpiderProfile.apply_to(mini, "juvenile")
		mini.position = Vector3(1.55, 0.44, -1.72) if index == 0 else Vector3(5.85, 0.44, 1.80)
		add_child(mini)
		mini.process_mode = Node.PROCESS_MODE_PAUSABLE

func _create_sighting_spider() -> void:
	# A harmless, visible juvenile in the supply room establishes the threat
	# before the late power-cut encounter. The combat juveniles stay dormant.
	var sighting := MiniSpiderScript.new()
	sighting.name = "SupplyRoomSighting"
	sighting.auto_bind_progression = false
	# Keep its first silhouette in front of the couch, in the line of sight
	# from the open entry doorway. Behind the couch it was never seen.
	sighting.position = Vector3(1.55, 0.44, -1.72)
	add_child(sighting)
	sighting.show()
	sighting._play_visual("idle")
	sighting.process_mode = Node.PROCESS_MODE_PAUSABLE
	_sighting_spider = sighting

func _label(text: String, size: int, color := Color(0.88, 0.86, 0.82)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	status_hud = StatusScript.new()
	status_hud.name = "SelectableStatusHUD"
	root.add_child(status_hud)
	status_hud.set_layout(2)
	objective = _label("", 18)
	objective.position = Vector2(44, 38)
	root.add_child(objective)
	subtitle = _label("", 23)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 44
	subtitle.offset_right = -44
	subtitle.offset_top = -160
	subtitle.offset_bottom = -78
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	prompt_label = _label("", 18)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -220
	prompt_label.offset_right = 220
	prompt_label.offset_top = 45
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	var reticle := _label("·", 26, Color(0.85, 0.9, 0.92, 0.65))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position -= Vector2(4, 17)
	root.add_child(reticle)
	notice = _label("", 17, Color(0.7, 0.75, 0.77))
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_top = -63
	notice.offset_bottom = -28
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(notice)
	fade = ColorRect.new()
	fade.color = Color(0.05, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.004, 0.008, 0.011, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(backdrop)
	var frame := PanelContainer.new()
	frame.position = Vector2(54, 53)
	frame.custom_minimum_size = Vector2(576, 660)
	frame.add_theme_stylebox_override("panel", _menu_panel_style(Color(0.012, 0.019, 0.023, 0.96), Color(0.33, 0.37, 0.34, 0.82)))
	menu.add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 27)
	margin.add_theme_constant_override("margin_right", 27)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	frame.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	stack.add_child(_label("A R A C H N O P H O B I A   /   BLACKWEB", 14, Color(0.68, 0.73, 0.69)))
	heading = _label("BLACKWEB", 62, Color(0.92, 0.9, 0.83))
	stack.add_child(heading)
	menu_state = _label("HOUSE TUTORIAL  /  A MESSAGE FROM GREYHAVEN", 15, Color(0.76, 0.62, 0.4))
	stack.add_child(menu_state)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	stack.add_child(spacer)
	resume_button = _button("Enter the house", _resume)
	resume_button.disabled = not _loaded
	stack.add_child(resume_button)
	restart_button = _button("Restart opening", _restart)
	restart_button.visible = false
	stack.add_child(restart_button)
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 14
	stack.add_child(separator)
	stack.add_child(_label("HUD STYLE", 14, Color(0.7, 0.74, 0.68)))
	hud_picker = OptionButton.new()
	hud_picker.custom_minimum_size = Vector2(0, 43)
	for title in StatusScript.LAYOUT_NAMES: hud_picker.add_item(title)
	hud_picker.select(2)
	hud_picker.item_selected.connect(_set_hud_layout)
	stack.add_child(hud_picker)
	var button_spacer := Control.new()
	button_spacer.custom_minimum_size.y = 13
	stack.add_child(button_spacer)
	stack.add_child(_button("Exit game", func(): get_tree().quit()))
	stack.add_child(_label("ONE EXIT   /   THREE STARTER ITEMS   /   FIFTY INVENTORY SPACES", 12, Color(0.48, 0.56, 0.55)))
	var briefing := PanelContainer.new()
	briefing.position = Vector2(674, 114)
	briefing.custom_minimum_size = Vector2(620, 483)
	briefing.add_theme_stylebox_override("panel", _menu_panel_style(Color(0.012, 0.019, 0.023, 0.88), Color(0.31, 0.33, 0.31, 0.72)))
	menu.add_child(briefing)
	var briefing_margin := MarginContainer.new()
	briefing_margin.add_theme_constant_override("margin_left", 30)
	briefing_margin.add_theme_constant_override("margin_right", 30)
	briefing_margin.add_theme_constant_override("margin_top", 28)
	briefing_margin.add_theme_constant_override("margin_bottom", 24)
	briefing.add_child(briefing_margin)
	var briefing_stack := VBoxContainer.new()
	briefing_stack.add_theme_constant_override("separation", 17)
	briefing_margin.add_child(briefing_stack)
	briefing_stack.add_child(_label("FIELD NOTES   /   01", 14, Color(0.76, 0.62, 0.4)))
	briefing_stack.add_child(_label("Mara's message broke off.\nSomething is inside.", 30, Color(0.91, 0.89, 0.82)))
	briefing_stack.add_child(_label("Find the keys and a way through the front door.\nSearch drawers and cabinets for supplies.", 18, Color(0.65, 0.71, 0.7)))
	briefing_stack.add_child(HSeparator.new())
	briefing_stack.add_child(_label("MOVE     W A S D     /     MOUSE  LOOK     /     SHIFT  SPRINT\nCROUCH  C               /     SPACE  JUMP    /     E  INTERACT\nDRAW       1–3           /     LEFT CLICK  USE /     F  TORCH\nINVENTORY  I           /     ESC  PAUSE     /     F1–F4  HUD", 16, Color(0.72, 0.77, 0.73)))
	briefing_stack.add_child(_label("Equipped items alone can be used. Change your three\nquick slots from the 50-space inventory.", 16, Color(0.76, 0.62, 0.4)))
	if not _loaded:
		var error := _label("House recovery is not ready. See the recovery report.", 18, Color(0.85, 0.55, 0.4))
		error.position = Vector2(74, 663)
		menu.add_child(error)
	else:
		resume_button.grab_focus()

func _menu_panel_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(0.86, 0.89, 0.84))
	button.add_theme_color_override("font_hover_color", Color(0.99, 0.91, 0.73))
	button.add_theme_stylebox_override("normal", _menu_panel_style(Color(0.07, 0.09, 0.09, 0.94), Color(0.23, 0.3, 0.28)))
	button.add_theme_stylebox_override("hover", _menu_panel_style(Color(0.13, 0.17, 0.16, 0.98), Color(0.72, 0.57, 0.32)))
	button.add_theme_stylebox_override("pressed", _menu_panel_style(Color(0.18, 0.2, 0.17, 0.98), Color(0.88, 0.68, 0.38)))
	button.add_theme_stylebox_override("focus", _menu_panel_style(Color(0, 0, 0, 0), Color(0.92, 0.73, 0.42)))
	button.pressed.connect(callback)
	return button

func _resume() -> void:
	if not _loaded or progression.stage == progression.Stage.COMPLETE: return
	_started = true
	menu.hide()
	status_hud.hide_inventory()
	get_tree().paused = false
	player.active = not _leaving
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	if not _loaded: return
	progression.restart_opening()
	player.restore_checkpoint()
	player.reset_starting_inventory()
	_reset_supplies()
	status_hud.set_record_found(false)
	heading.text = "BLACKWEB"
	menu_state.text = "HOUSE TUTORIAL  /  A MESSAGE FROM GREYHAVEN"
	resume_button.disabled = false
	resume_button.text = "Resume"
	restart_button.visible = true
	_resume()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle") and _started and not menu.visible:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if status_hud.is_inventory_open():
		for index in range(3):
			if event.is_action_pressed("hotbar_%d" % (index + 1)):
				status_hud._on_quick_button(index)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("pause_game"):
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return
	for index in range(4):
		if event.is_action_pressed("hud_%d" % (index + 1)):
			_set_hud_layout(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause_game") and _started and progression.stage != progression.Stage.COMPLETE:
		if menu.visible: _resume()
		else:
			get_tree().paused = true
			menu.show()
			status_hud.hide_inventory()
			resume_button.text = "Resume"
			menu_state.text = "PAUSED  /  HOUSE OPENING"
			restart_button.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			resume_button.grab_focus()

func _toggle_inventory() -> void:
	status_hud.toggle_inventory()
	var opened: bool = status_hud.is_inventory_open()
	var hud_root: Node = status_hud.get_parent()
	if opened:
		hud_root.move_child(status_hud, hud_root.get_child_count() - 1)
	else:
		hud_root.move_child(status_hud, 0)
	get_tree().paused = opened
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opened else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(player): player.active = not opened and not _leaving

func _set_hud_layout(index: int) -> void:
	status_hud.set_layout(index)
	if is_instance_valid(hud_picker) and hud_picker.selected != index: hud_picker.select(index)

func _on_stage(stage: int) -> void:
	_clear_presence()
	if is_instance_valid(objective):
		objective.text = progression.objective()
		status_hud.set_objective(objective.text)
	if stage == progression.Stage.PRESENCE:
		_power_target = 0.72
		var reveal_door := get_node_or_null("SouthEntryDoor")
		if reveal_door != null and not reveal_door.opened: reveal_door.toggle()
		_start_presence()
	if stage >= progression.Stage.POWER_LOSS: _power_target = 0.0
	if stage >= progression.Stage.ENCOUNTER and is_instance_valid(_sighting_spider): _sighting_spider.hide()
	if stage == progression.Stage.COMPLETE:
		get_tree().paused = true
		menu.show()
		heading.text = "GREYHAVEN"
		menu_state.text = "TUTORIAL COMPLETE  /  ONE EXIT FOUND"
		resume_button.text = "Opening complete"
		resume_button.disabled = true
		restart_button.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_recovery(recovering: bool) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", 0.94 if recovering else 0.0, 0.55)

func _process(delta: float) -> void:
	if get_tree().paused: return
	var next_power := move_toward(_power, _power_target, delta * 2.2)
	if next_power == _power: return
	_power = next_power
	for i in _lamps.size(): _lamps[i].light_energy = _base_energy[i] * _power
	_environment.ambient_light_energy = lerpf(BLACKOUT_AMBIENT, POWERED_AMBIENT, _power)

func _vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _prepare_exit_door(house: Node) -> void:
	var parts: Array[Node3D] = []
	for child in house.get_children():
		if not child is Node3D: continue
		var source := str(child.get_meta("ue_component_name", child.name))
		if source.contains("BP_Door_01_C_2"):
			parts.append(child)
	if parts.is_empty(): return
	_exit_door = Node3D.new()
	_exit_door.name = "FrontDoorHinge"
	house.add_child(_exit_door)
	_exit_door.position = Vector3(-5.080865, 0.422721, 0.851686)
	for part in parts: part.reparent(_exit_door, true)

func _create_tutorial_doors(house: Node3D) -> void:
	if not is_instance_valid(_exit_door): return
	var frame: Node3D
	for child in house.get_children():
		if child is Node3D and str(child.get_meta("ue_mesh_path", "")).contains("Mesh_Door_Frame_02"):
			frame = child
			break
	var creak: AudioStream
	var audio: Dictionary = _layout.get("audio", {})
	var creak_path: String = str(audio.get("door", ""))
	if not creak_path.is_empty() and ResourceLoader.exists(creak_path): creak = load(creak_path) as AudioStream
	for entry in [
		{"name": "SouthEntryDoor", "label": "supply-room door", "x": -0.80, "z": -2.0},
		{"name": "NorthEntryDoor", "label": "record-room door", "x": -0.80, "z": 2.0},
		{"name": "RearSouthDoor", "label": "infested-room door", "x": 3.20, "z": -2.0},
		{"name": "RearNorthDoor", "label": "vault door", "x": 3.20, "z": 2.0},
	]:
		var door: Node3D = TutorialDoor.new()
		door.name = entry.name
		door.door_label = entry.label
		door.progression = progression
		door.frame_template = frame
		door.hinge_template = _exit_door
		door.creak_stream = creak
		door.position = Vector3(float(entry.x), 1.40, float(entry.z))
		add_child(door)
		_tutorial_doors.append(door)
		progression.checkpoint_restored.connect(door.reset_closed)

func _leave_house() -> void:
	if _leaving or not progression.can_interact(&"exit"): return
	_leaving = true
	var sounds := get_node_or_null("Soundscape")
	if sounds != null and sounds.has_method("play_door"): sounds.play_door()
	player.active = false
	prompt_label.text = ""
	_exit_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if is_instance_valid(_exit_door):
		_exit_tween.tween_property(_exit_door, "rotation:y", -1.42, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_exit_tween.tween_interval(0.7)
	_exit_tween.tween_property(fade, "color:a", 1.0, 0.6)
	_exit_tween.tween_callback(func(): progression.interact(&"exit"))

func _reset_door() -> void:
	if is_instance_valid(_exit_tween): _exit_tween.kill()
	if is_instance_valid(_exit_door): _exit_door.rotation = Vector3.ZERO
	_leaving = false
	fade.color.a = 0.0

func _apply_prop_materials(prop: Node3D, path: String) -> void:
	var meshes: Array[MeshInstance3D] = []
	if prop is MeshInstance3D: meshes.append(prop)
	for child in prop.find_children("*", "MeshInstance3D", true, false): meshes.append(child)
	_material_adapter.apply_overrides(meshes, path, _prop_materials.get(path.get_file().get_basename().to_lower(), []), prop.name)

func _start_presence() -> void:
	var model_path: String = _layout.get("spider_model", "")
	if model_path.is_empty() or not ResourceLoader.exists(model_path): return
	var start := Vector3(6.2, 0.44, 1.4)
	var end := Vector3(6.2, 0.44, -1.4)
	var lane := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.35, end + Vector3.UP * 0.35, 1)
	if not get_world_3d().direct_space_state.intersect_ray(lane).is_empty(): return
	_presence_model = load(model_path).instantiate()
	_presence_model.name = "DistantMovement"
	add_child(_presence_model)
	_presence_model.process_mode = Node.PROCESS_MODE_PAUSABLE
	_presence_model.position = start
	_presence_model.hide()
	var animations := _presence_model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if animations != null and animations.has_animation("walk"): animations.play("walk")
	_presence_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_presence_tween.tween_interval(2.0)
	_presence_tween.tween_callback(func(): if is_instance_valid(_presence_model): _presence_model.show())
	_presence_tween.tween_property(_presence_model, "position", end, 2.0)
	_presence_tween.tween_callback(_clear_presence)

func _clear_presence() -> void:
	if is_instance_valid(_presence_tween): _presence_tween.kill()
	if is_instance_valid(_presence_model):
		_presence_model.queue_free()
		_presence_model = null

func _setup_house_visibility(house: Node) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for holder in house.get_children():
		if not holder is Node3D or not holder.has_meta("ue_mesh_path"): continue
		var source := str(holder.get_meta("ue_mesh_path"))
		var structural := source.contains("/Mesh_Wall_") or source.contains("/Mesh_Floor_")
		for child in holder.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if mesh.mesh == null: continue
			if source.contains("/OldBrickHouse/") and not structural:
				mesh.visibility_range_end = 24.0
			if structural:
				var faces: PackedVector3Array = mesh.mesh.get_faces()
				for vertex in faces:
					indices.append(vertices.size())
					vertices.append(mesh.global_transform * vertex)
	if vertices.is_empty(): return
	var occluder := ArrayOccluder3D.new()
	occluder.set_arrays(vertices, indices)
	var instance := OccluderInstance3D.new()
	instance.name = "OriginalWallsOccluder"
	instance.occluder = occluder
	add_child(instance)
	get_viewport().use_occlusion_culling = true
