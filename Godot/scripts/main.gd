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
const CampaignScript = preload("res://scripts/tutorial_campaign.gd")
const FieldOverlay = preload("res://scripts/field_overlay.gd")

@export var qa_mode := false

var progression: Node
var player: BlackwebPlayer
var spider: Node3D
var hud: CanvasLayer
var menu
var heading: Label
var objective: Control
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
var _early_sighting_time := 0.0
var _early_spider_spawned := false
# In front of the arrival shoulder camera, between the two lower HUD clusters.
# The body clears the room partition, and the original grace period still applies.
const EARLY_SPIDER_START := Vector3(-1.52, 0.44, 0.50)
const EARLY_SPIDER_END := Vector3(-2.7, 0.44, 1.0)
var campaign = CampaignScript.new()
var field_overlay: BlackwebFieldOverlay
var _item_preview: Node
var _loading_campaign := true
var _save_queued := false
var _intro: Node
var _warming_house := false
var _house_warmed := false
var house_warmup_ms := 0
var house_map: Control
var _room_spiders: Array[Node3D] = []
var _room_spider_started: Dictionary = {}

func _ready() -> void:
	if qa_mode: print("JOURNEY LOAD: main ready")
	_install_input()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not qa_mode: campaign.load_state()
	progression = ProgressionScript.new()
	progression.requires_vault = true
	progression.auto_save = false
	if not campaign.loaded.is_empty(): progression.auto_load = false
	if qa_mode:
		progression.auto_load = false
		progression.auto_save = false
	progression.name = "Progression"
	add_child(progression)
	if not campaign.loaded.is_empty() and not progression.restore_snapshot(campaign.loaded.story, false):
		campaign.writes_blocked = true
		progression.show_notice("Story save could not be read. Restart opening to create a new game.", 9.0)
	# Legacy checkpoint loading is a one-time migration. Retries use this run's
	# milestone, while the unified campaign owns durable saves from now on.
	progression.auto_load = false
	if campaign.writes_blocked:
		progression.show_notice("This campaign needs a different version. Your save is protected; Restart opening creates a new game.", 9.0)
	progression.process_mode = Node.PROCESS_MODE_PAUSABLE
	_create_environment()
	_loaded = _load_house()
	if qa_mode: print("JOURNEY LOAD: house loaded")
	_supply_table = _read_supply_table()
	_supply_seed = 20261103 if qa_mode else randi()
	if not campaign.loaded.is_empty(): _supply_seed = int(campaign.loaded.get("world", {}).get("seed", _supply_seed))
	_create_hud()
	if qa_mode: print("JOURNEY LOAD: HUD built")
	if _loaded:
		player = PlayerScript.new()
		player.progression = progression
		player.name = "Luke"
		add_child(player)
		if qa_mode: print("JOURNEY LOAD: player ready")
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.position = _vec(_layout.get("player", [0, 0.1, 0]))
		player.spawn_transform = player.transform
		player.set_view(float(_layout.get("player_yaw", 0)))
		progression.player = player
		house_map.player = player
		house_map.progression = progression
		if not campaign.loaded.is_empty():
			if not player.restore_survival_state(campaign.loaded.survival):
				campaign.writes_blocked = true
				progression.show_notice("Inventory save could not be read. Restart opening to create a new game.", 9.0)
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
		status_hud.armor_equip_requested.connect(func(cell: int): player.equip_armor(cell))
		status_hud.armor_remove_requested.connect(func(slot: StringName): player.unequip_armor(slot))
		player.health_changed.connect(func(v: float):
			status_hud.set_health(v)
			_queue_campaign_save())
		player.recovery_changed.connect(_on_recovery)
		var model_path: String = _layout.get("player_model", "")
		if not model_path.is_empty() and ResourceLoader.exists(model_path): player.attach_model(load(model_path))
		_item_preview = load("res://scripts/item_preview.gd").new()
		_item_preview.name = "InventoryModelPreview"
		add_child(_item_preview)
		_item_preview.preview_ready.connect(status_hud.set_item_preview)
		status_hud.item_preview_requested.connect(func(item_id: StringName):
			_item_preview.show_model(player.item_preview_source(item_id), item_id))
		if qa_mode: print("JOURNEY LOAD: body loaded")
		_create_interactions()
		_create_storage()
		_create_supplies()
		_create_evidence()
		if qa_mode: print("JOURNEY LOAD: interactions ready")
		_restore_world_claims()
		_create_spider()
		_create_mini_spiders()
		_create_sighting_spider()
		_create_room_spiders()
		var exit_web := preload("res://scripts/exit_web.gd").new()
		exit_web.name = "FrontLockWeb"
		exit_web.progression = progression
		exit_web.position = Vector3(-4.85,1.02,.42)
		add_child(exit_web)
		if qa_mode: print("JOURNEY LOAD: spiders ready")
		var sounds := SoundScript.new()
		sounds.name = "Soundscape"
		sounds.player = player
		sounds.progression = progression
		sounds.assets = _layout.get("audio", {})
		sounds.phone_position = _vec(_layout.get("phone_position", [-3.4, 1.1, 1.7]))
		add_child(sounds)
		sounds.process_mode = Node.PROCESS_MODE_PAUSABLE
		var voice := preload("res://scripts/story_voice.gd").new()
		voice.name = "StoryVoice"
		voice.progression = progression
		voice.soundscape = sounds
		add_child(voice)
	progression.stage_changed.connect(_on_stage)
	progression.power_changed.connect(func(on: bool): _power_target = 1.0 if on else 0.0)
	progression.subtitle_changed.connect(func(t: String): subtitle.text = t)
	progression.notice_changed.connect(func(t: String): notice.text = t)
	progression.inventory_changed.connect(func():
		_refresh_objective()
		status_hud.set_escape_state(progression.has_exit_keys, progression.exit_web_cleared)
		_queue_campaign_save())
	if is_instance_valid(player):
		status_hud.set_flashlight(true, player._light_on)
		status_hud.set_battery(player.battery_charge, player._light_on)
		status_hud.set_health(player.health)
		_update_inventory_hud()
	_refresh_objective()
	status_hud.set_escape_state(progression.has_exit_keys, progression.exit_web_cleared)
	subtitle.text = progression.subtitle
	notice.text = progression.notice
	_on_stage(progression.stage)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_loading_campaign = false
	menu.present("complete" if progression.stage == progression.Stage.COMPLETE else "main", _has_menu_progress(), _loaded, not campaign.loaded.is_empty())
	var autosave := Timer.new()
	autosave.wait_time = 5.0
	autosave.autostart = true
	autosave.timeout.connect(_queue_campaign_save)
	add_child(autosave)
	if qa_mode: print("JOURNEY LOAD: complete")

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
		if interaction.kind == &"phone": interaction.name = "PhoneInteraction"
		interaction.label = entry.label
		if interaction.kind == &"keys": interaction.label = "Take vault key"
		if interaction.kind == &"flashlight": interaction.label = "Salvage spare flashlight cells"
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
		{"name": "PlantCodeNote", "kind": "paper", "title": "Mica's hidden note", "position": Vector3(2.08, 1.0782, 3.57),
			"text": "Luke,\n\nI couldn't leave this on the phone. Use the small key from the record-room shelf, then enter:\n\n0  4  1  7\n\nYour exit keys are inside the vault with the field kit. Cut the silk off the front lock before turning the exit key.\n\nDad hid the company records here. He was trying to get the prisoners out. Take the records. Come find me.\n\n— Mica"},
		{"name": "VaultFieldKit", "kind": "kit", "title": "leather field kit", "position": Vector3(7.9, 0.98, 1.25),
			"text": "Four leather armor pieces."},
		{"name": "VaultExitKeys", "kind": "exit_keys", "title": "exit keys", "position": Vector3(7.65,.99,1.05), "text": "The exit keys."},
		{"name": "FathersLetter", "kind": "paper", "title": "Dad's last shift", "position": Vector3(1.65,1.075,2.95),
			"text": "LUKE — I kept the night maintenance job because it gave me access to the transfer corridor. They called the prisoners volunteers. None of them could leave. I copied the manifests and sent Mica to your house with them. If anyone asks, you never saw me. — Dad\n\nPencil beneath the signature: Do not follow the voices in the vents."},
		{"name": "ContainmentMemo", "kind": "paper", "title": "Containment notice", "position": Vector3(6.9,.46,-3.0),
			"text": "GREYHAVEN / FIELD CONTAINMENT\n\nThe spiders in residential buildings are ordinary colony animals displaced by the underground tests. Do not confuse them with the grafted subjects. Silk fouls latch mechanisms: isolate the strands before using a key.\n\nProject 08 combined prisoner tissue with spider subjects. The microphones recorded replies after the test chamber was empty. Management ordered every recording destroyed."},
	]:
		var evidence: Node3D = EvidenceScript.new()
		evidence.name = entry.name
		evidence.evidence_type = entry.kind
		evidence.title = entry.title
		evidence.record_text = entry.text
		evidence.folded_in_world = entry.name == "PlantCodeNote"
		evidence.progression = progression
		evidence.position = entry.position
		evidence.discovered.connect(_show_tutorial_evidence)
		add_child(evidence)
		_tutorial_evidence.append(evidence)
	_create_clue_plant()
	_create_containment_drum()
	var case_body := StaticBody3D.new()
	case_body.name = "LeatherKitCase"
	case_body.position = Vector3(7.9, 0.68, 1.25)
	add_child(case_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.75, 0.48, 0.50)
	shape.shape = box
	case_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var case_mesh := BoxMesh.new()
	case_mesh.size = box.size
	mesh.mesh = case_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3d3429")
	material.roughness = 0.93
	mesh.material_override = material
	case_body.add_child(mesh)
	# A small battery-powered case lamp makes the actual loot readable in the
	# dark vault. Its short range stays away from the separating walls.
	var kit_light := OmniLight3D.new()
	kit_light.name = "FieldCaseLamp"
	kit_light.position = Vector3(0,.82,.10)
	kit_light.omni_range = 1.65
	kit_light.light_energy = .75
	kit_light.light_color = Color(.86,.79,.60)
	kit_light.shadow_enabled = false
	case_body.add_child(kit_light)

func _show_tutorial_evidence(text: String, title: String) -> void:
	if title == "exit keys":
		if progression.collect_exit_keys():
			get_node("StoryVoice").enqueue("exit_keys")
			get_node("VaultExitKeys").set_taken(true)
			campaign.claimed["VaultExitKeys"] = true
			_queue_campaign_save()
		return
	if title == "unmarked cash":
		if campaign.collect_cash("VaultCash", 120):
			get_node("VaultCash").set_taken(true)
			progression.show_notice("+$120  /  WALLET $%d" % campaign.wallet, 4.0)
			_update_inventory_hud()
		return
	if title == "leather field kit":
		_open_field_modal()
		field_overlay.show_armor(campaign.claimed)
		return
	if title == "Mica's hidden note": campaign.code_found = true
	if title == "Dad's last shift": get_node("StoryVoice").enqueue("records")
	if title == "Containment notice": get_node("StoryVoice").enqueue("containment")
	status_hud.set_record_found(true)
	status_hud.set_vault_code_found(campaign.code_found)
	_refresh_objective()
	_open_field_modal()
	field_overlay.show_paper(title, text)
	_queue_campaign_save()

func _create_containment_drum() -> void:
	var path := "res://assets/generated/meshy_containment_drum.glb"
	if not ResourceLoader.exists(path): return
	var body := StaticBody3D.new()
	body.name = "ContainmentDrum"
	body.position = Vector3(8.05,.405,-3.05)
	add_child(body)
	body.add_child(load(path).instantiate())
	var collider := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .31
	cylinder.height = .86
	collider.shape = cylinder
	collider.position.y = .43
	body.add_child(collider)

func _create_clue_plant() -> void:
	var props_script = load("res://scripts/tutorial_props.gd")
	if props_script == null: return
	var plant: Node3D = props_script.make_plant()
	plant.name = "MicasPlant"
	# The pot stands beside the table; the folded code note rests on the tabletop.
	plant.position = Vector3(2.28, 0.405, 3.50)
	add_child(plant)
	var kit: Node3D = preload("res://scripts/field_kit_display.gd").new()
	kit.name = "LeatherKitContents"
	kit.position = Vector3(7.9, 0.925, 1.25)
	add_child(kit)
	kit.build(player)
	kit.refresh(campaign.claimed)

func _open_field_modal() -> void:
	status_hud.hide_inventory()
	var parent := field_overlay.get_parent()
	parent.move_child(field_overlay, parent.get_child_count() - 1)
	get_tree().paused = true
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt_label.text = ""

func _close_field_modal() -> void:
	get_tree().paused = false
	player.active = not _leaving
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_queue_campaign_save()

func _inspect_vault() -> void:
	_open_field_modal()
	field_overlay.show_vault(progression.has_keys, campaign.code_found)

func _submit_vault_code(code: String) -> void:
	if not progression.has_keys:
		field_overlay.set_message("The vault key is missing. Search the record-room shelf.")
		return
	if not campaign.try_unlock(code, progression.has_keys):
		field_overlay.set_message("Code rejected. Check Mica's paper beside the plant.")
		field_overlay.digits = ""
		return
	var vault := get_node_or_null("RearNorthDoor")
	if vault != null:
		vault.locked = false
		if not vault.opened: vault.toggle()
	progression.unlock_vault()
	field_overlay.close_overlay()
	progression.show_notice("VAULT OPEN  /  Recover your exit keys and field kit. Equip armor with I.", 6.0)
	_queue_campaign_save()

func _claim_armor(item: StringName) -> void:
	if not campaign.vault_unlocked or not CampaignScript.ARMOR.has(item) or campaign.claimed.has(str(item)): return
	var before := player.item_count(item)
	if player.add_item(item, 1) <= before:
		field_overlay.set_message("Backpack full. Leave a cell free and return for this piece.")
		return
	campaign.claimed[str(item)] = true
	get_node("LeatherKitContents").refresh(campaign.claimed)
	field_overlay.show_armor(campaign.claimed)
	_update_inventory_hud()
	_queue_campaign_save()

func _test_voice_audio() -> void:
	var sounds := get_node_or_null("Soundscape")
	var started: bool = sounds != null and sounds.play_voice_test()
	menu.report_voice_test(sounds.get_audio_status() if sounds != null else {}, started)

func _queue_campaign_save() -> void:
	if _loading_campaign or qa_mode or _save_queued: return
	_save_queued = true
	_save_campaign.call_deferred()

func _save_campaign() -> void:
	_save_queued = false
	if _loading_campaign or qa_mode or not is_instance_valid(player) or player.health <= 0.0 or player.is_recovering(): return
	var world := {"seed": _supply_seed, "pickups": {}, "storage": {}, "explored_rooms": house_map.visited.keys()}
	for pickup in _supply_pickups:
		world.pickups[str(pickup.name)] = pickup.taken
	for storage in _storage_units:
		world.storage[str(storage.name)] = {"rolled": storage._loot_rolled, "searched": storage._searched_once,
			"clue_shown": storage._clue_shown, "pending": storage._pending_loot.duplicate(true)}
	if not campaign.save_state(progression.snapshot(), player.survival_snapshot(), world):
		if not campaign.writes_blocked: push_warning("Campaign save failed; previous complete record is retained.")

func _restore_world_claims() -> void:
	if campaign.loaded.is_empty():
		# Migrate a completed pre-vault checkpoint without removing owned progress.
		campaign.vault_unlocked = progression.vault_unlocked
		return
	var world: Dictionary = campaign.loaded.get("world", {})
	house_map.restore_explored(world.get("explored_rooms", [0]))
	var pickups: Dictionary = world.get("pickups", {}) if world.get("pickups", {}) is Dictionary else {}
	for pickup in _supply_pickups:
		pickup.taken = bool(pickups.get(str(pickup.name), false))
		pickup._refresh()
	var fixtures: Dictionary = world.get("storage", {}) if world.get("storage", {}) is Dictionary else {}
	for storage in _storage_units:
		var state: Variant = fixtures.get(str(storage.name), {})
		if not state is Dictionary: continue
		storage._loot_rolled = bool(state.get("rolled", false))
		storage._searched_once = bool(state.get("searched", false))
		storage._clue_shown = bool(state.get("clue_shown", false))
		if state.get("pending", []) is Array: storage._pending_loot = state.get("pending", []).duplicate(true)
		storage._refresh_loot_visuals()
	for evidence in _tutorial_evidence:
		if evidence.evidence_type == "cash": evidence.set_taken(campaign.claimed.has(str(evidence.name)))
		if evidence.evidence_type == "exit_keys": evidence.set_taken(progression.has_exit_keys)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _save_campaign()

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
		status_hud.set_armor_state(player.get_armor_state(), player.armor_reduction_percent())
		status_hud.set_wallet(campaign.wallet)
		status_hud.set_vault_code_found(campaign.code_found)
		_refresh_objective()
		_queue_campaign_save()

func _show_supply_notice(text: String) -> void:
	notice.text = text
	await get_tree().create_timer(3.5, false).timeout
	if is_instance_valid(notice) and notice.text == text:
		notice.text = progression.notice

func _show_optional_clue(text: String) -> void:
	_show_tutorial_evidence(text, "Project 08 / drawer record")

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
	# This former decorative sighting now uses the normal juvenile combat model.
	# Arrival has a short grace period and phone dialogue remains safe.
	var sighting := MiniSpiderScript.new()
	sighting.name = "SupplyRoomSighting"
	sighting.auto_bind_progression = false
	sighting.target = player
	SpiderProfile.apply_to(sighting, "juvenile")
	sighting.position = EARLY_SPIDER_START
	add_child(sighting)
	sighting.hide()
	sighting._play_visual("idle")
	sighting.process_mode = Node.PROCESS_MODE_PAUSABLE
	_sighting_spider = sighting
	progression.checkpoint_restored.connect(_reset_early_spider)

func _create_room_spiders() -> void:
	for index in 2:
		var resident := MiniSpiderScript.new()
		resident.name = "RoomSpider%d" % (index+1)
		resident.auto_bind_progression = false
		resident.target = player
		SpiderProfile.apply_to(resident,"juvenile")
		resident.position = Vector3(1.7,.44,-2.8) if index == 0 else Vector3(5.7,.44,-2.15)
		add_child(resident)
		resident.process_mode = Node.PROCESS_MODE_PAUSABLE
		_room_spiders.append(resident)

func _update_room_spiders() -> void:
	if progression.stage < progression.Stage.PREPARATION or progression.stage >= progression.Stage.ENCOUNTER: return
	if not is_instance_valid(player) or not player.active or player.is_recovering(): return
	for resident in _room_spiders:
		if _room_spider_started.has(str(resident.name)): continue
		if resident.global_position.distance_to(player.global_position) > 4.0: continue
		if not resident._can_see_target(): continue
		_room_spider_started[str(resident.name)] = true
		resident.activate(player)
		resident._attack_cooldown = 1.6

func _reset_early_spider() -> void:
	_room_spider_started.clear()
	for resident in _room_spiders:
		resident.deactivate()
		resident.global_transform = resident._spawn_transform
	_early_spider_spawned = false
	_early_sighting_time = 0.0
	if is_instance_valid(_sighting_spider):
		_sighting_spider.deactivate()
		_sighting_spider.position = EARLY_SPIDER_START

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
	preload("res://scripts/horror_theme.gd").apply_theme(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	status_hud = StatusScript.new()
	status_hud.name = "SelectableStatusHUD"
	root.add_child(status_hud)
	status_hud.inventory_close_requested.connect(_toggle_inventory)
	status_hud.set_layout(2)
	house_map = preload("res://scripts/house_map.gd").new()
	house_map.name = "HouseMap"
	root.add_child(house_map)
	house_map.world = self
	house_map.room_discovered.connect(func(_index: int): _queue_campaign_save())
	objective = preload("res://scripts/objective_bar.gd").new()
	objective.name = "ObjectiveTracker"
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
	menu = preload("res://scripts/horror_menu.gd").new()
	menu.name = "BlackwebMenu"
	menu.qa_mode = qa_mode
	root.add_child(menu)
	heading = menu.heading
	menu_state = menu.menu_state
	resume_button = menu.resume_button
	restart_button = menu.restart_button
	hud_picker = menu.hud_picker
	menu.resume_requested.connect(_resume)
	menu.restart_requested.connect(_restart)
	menu.quit_requested.connect(func():
		_save_campaign()
		get_tree().quit())
	menu.voice_test_requested.connect(_test_voice_audio)
	menu.boss_test_requested.connect(_open_boss_test)
	menu.hud_layout_selected.connect(_set_hud_layout)
	status_hud.set_layout(menu.settings.hud_layout)
	menu.present("main", _has_menu_progress(), _loaded, _has_menu_progress())
	field_overlay = FieldOverlay.new()
	root.add_child(field_overlay)
	field_overlay.closed.connect(_close_field_modal)
	field_overlay.code_submitted.connect(_submit_vault_code)
	field_overlay.armor_claimed.connect(_claim_armor)

func _open_boss_test() -> void:
	if _started: _save_campaign()
	menu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/boss_encounter.tscn")

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
	if not _loaded or _warming_house or progression.stage == progression.Stage.COMPLETE: return
	_started = true
	menu.hide()
	status_hud.hide_inventory()
	if not qa_mode and not _house_warmed:
		await warm_house_renderer()
	if not qa_mode and not campaign.intro_seen and progression.stage == progression.Stage.NORMAL:
		player.active = false
		get_tree().paused = true
		_intro = load("res://scripts/tutorial_intro.gd").new()
		add_child(_intro)
		_intro.finished.connect(_finish_intro)
		if _intro.begin(player, status_hud.get_parent()): return
		_finish_intro()
		return
	get_tree().paused = false
	player.active = not _leaving
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func warm_house_renderer() -> void:
	if _house_warmed or _warming_house or DisplayServer.get_name() == "headless": return
	_warming_house = true
	var began := Time.get_ticks_msec()
	var tree := get_tree()
	var prior_pause := tree.paused
	var prior_active: bool = player.active
	var prior_camera: Transform3D = player.camera.global_transform
	var prior_disable := get_viewport().disable_3d
	var prior_lamp: bool = player.lamp.visible
	tree.paused = true
	player.active = false
	get_viewport().disable_3d = false
	var cover := CanvasLayer.new()
	cover.layer = 100
	add_child(cover)
	var black := ColorRect.new()
	black.color = Color("080c0e")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	var message := _label("Preparing house lighting…", 20)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.position = Vector2(-220,-20)
	message.size = Vector2(440,40)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	black.add_child(message)
	var visuals: Array[Node3D] = []
	for candidate in [spider, _sighting_spider, get_node("MiniSpider1"), get_node("MiniSpider2"), player._hand_flashlight, player._hand_knife, player._hand_candy]:
		if is_instance_valid(candidate): visuals.append(candidate)
	if is_instance_valid(player._armor_visuals):
		for garment in player._armor_visuals._garments.values(): visuals.append(garment)
	visuals.append(player.visual)
	var visibility: Array[bool] = []
	for visual in visuals:
		visibility.append(visual.visible)
		visual.show()
	player.lamp.show()
	# Compile skinned leather and contact-effect materials while the loading
	# cover is up. Loot ownership and equipment are not changed by this draw.
	player.camera.global_position = player.global_position + Vector3(1.5,1.4,-1.5)
	player.camera.look_at(player.global_position + Vector3.UP*.9)
	var effects := preload("res://scripts/combat_effects.gd").for_source(player)
	var particles: CPUParticles3D = effects._slots[0].particles
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.global_position = player.global_position + Vector3(.5,1.0,.3)
	particles.show()
	particles.restart()
	particles.emitting = true
	effects._marks[0].global_position = player.global_position + Vector3(.5,.01,.5)
	effects._marks[0].show()
	for frame in 4: await RenderingServer.frame_post_draw
	effects.clear_all()
	particles.process_mode = Node.PROCESS_MODE_INHERIT
	# Draw the real materials before the first interactive camera pan. No AI,
	# pickups, phone clocks, player simulation or damage advance behind the cover.
	for eye in [Vector3(-4.3,1.82,.4),Vector3(.6,1.82,2.5),Vector3(4,1.82,2),Vector3(.6,1.82,-2.5),Vector3(4,1.82,-2.8)]:
		for direction in [-1.0,1.0]:
			player.camera.global_position = eye
			player.camera.look_at(eye+Vector3(direction*2,-.65,-.2))
			for frame in 3: await RenderingServer.frame_post_draw
	for index in visuals.size(): visuals[index].visible = visibility[index]
	player.camera.global_transform = prior_camera
	player.lamp.visible = prior_lamp
	get_viewport().disable_3d = prior_disable
	player.active = prior_active
	tree.paused = prior_pause
	cover.queue_free()
	house_warmup_ms = Time.get_ticks_msec()-began
	_house_warmed = true
	_warming_house = false

func _has_menu_progress() -> bool:
	if not _loaded or progression.stage == progression.Stage.COMPLETE: return false
	if _started: return true
	if campaign.writes_blocked or progression.save_writes_blocked: return false
	if not campaign.loaded.is_empty(): return campaign._valid(campaign.loaded)
	# Keep valid pre-campaign checkpoints available during the existing migration.
	if not qa_mode:
		for path in [progression.save_path, progression.save_path + ".backup"]:
			if not progression._normalized(progression._read_json(path)).is_empty(): return true
	return false

func _finish_intro() -> void:
	campaign.intro_seen = true
	if is_instance_valid(_intro): _intro.queue_free()
	_intro = null
	_resume()
	_queue_campaign_save()

func _restart() -> void:
	if not _loaded: return
	_loading_campaign = true
	campaign.reset()
	progression.restart_opening()
	player.restore_checkpoint()
	player.reset_starting_inventory()
	_reset_supplies()
	get_node("LeatherKitContents").refresh(campaign.claimed)
	house_map.visited = {0:true}
	house_map.set_expanded(false)
	for evidence in _tutorial_evidence: evidence.set_taken(false)
	var vault := get_node_or_null("RearNorthDoor")
	if vault != null: vault.locked = true
	_loading_campaign = false
	_update_inventory_hud()
	status_hud.set_record_found(false)
	menu.present("main", false, _loaded, false)
	_resume()

func _input(event: InputEvent) -> void:
	if _warming_house:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo: return
	if is_instance_valid(_intro):
		if event.is_action_pressed("pause_game") or event.is_action_pressed("jump") or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
			_intro.skip()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(menu) and menu.visible:
		if event.is_action_pressed("pause_game"):
			menu.back()
			get_viewport().set_input_as_handled()
		return # Buttons and option controls receive the normal GUI event next.
	if is_instance_valid(field_overlay) and field_overlay.visible:
		var handled := false
		if event.is_action_pressed("pause_game") or (field_overlay.mode != "vault" and event.is_action_pressed("interact")):
			field_overlay.close_overlay()
			handled = true
		elif field_overlay.mode == "vault" and event is InputEventKey and event.pressed:
			handled = field_overlay.handle_vault_key(event)
		if handled: get_viewport().set_input_as_handled()
		return
	if house_map.expanded:
		if event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
			_toggle_map()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inventory_toggle"):
			_toggle_map()
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_M and _started and not status_hud.is_inventory_open():
		_toggle_map()
		get_viewport().set_input_as_handled()
		return
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
		get_tree().paused = true
		player.active = false
		status_hud.hide_inventory()
		menu.present("pause", true, _loaded, true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_queue_campaign_save()
		get_viewport().set_input_as_handled()

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
	if stage in [progression.Stage.NORMAL, progression.Stage.MESSAGE]:
		_reset_early_spider()
	if is_instance_valid(objective):
		_refresh_objective()
	if stage == progression.Stage.PRESENCE:
		_power_target = 0.72
		var reveal_door := get_node_or_null("SouthEntryDoor")
		if reveal_door != null and not reveal_door.opened: reveal_door.toggle()
		_start_presence()
	if stage >= progression.Stage.POWER_LOSS: _power_target = 0.0
	if stage >= progression.Stage.ENCOUNTER:
		if is_instance_valid(_sighting_spider): _sighting_spider.deactivate()
		for resident in _room_spiders: resident.deactivate()
	if stage == progression.Stage.COMPLETE:
		get_tree().paused = true
		menu.present("complete", false, _loaded, true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_recovery(recovering: bool) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", 0.94 if recovering else 0.0, 0.55)

func _process(delta: float) -> void:
	if is_instance_valid(objective): objective.gameplay_visible = _started and is_instance_valid(player) and player.active and not is_instance_valid(_intro)
	if get_tree().paused: return
	_update_early_sighting(delta)
	_update_room_spiders()
	var next_power := move_toward(_power, _power_target, delta * 2.2)
	if next_power == _power: return
	_power = next_power
	for i in _lamps.size(): _lamps[i].light_energy = _base_energy[i] * _power
	_environment.ambient_light_energy = lerpf(BLACKOUT_AMBIENT, POWERED_AMBIENT, _power)

func _update_early_sighting(delta: float) -> void:
	if not is_instance_valid(_sighting_spider) or not is_instance_valid(player): return
	if _early_spider_spawned or player.is_recovering(): return
	if progression.stage == progression.Stage.MESSAGE or progression.stage >= progression.Stage.ENCOUNTER: return
	# A fixed, navigable starting-room spawn. Never depend on the camera, key,
	# code, or vault. The phone and paused screens remain safe.
	var delay := 8.0 if progression.stage == progression.Stage.NORMAL else 6.0
	if progression._elapsed < delay: return
	_early_sighting_time += delta
	_early_spider_spawned = true
	_sighting_spider.position = EARLY_SPIDER_START
	_sighting_spider.activate(player)
	_sighting_spider._attack_cooldown = 2.0
	progression.show_notice("Spider nearby. Press 2 for the knife; left click to strike.", 5.0)

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
		if door.door_label == "vault door":
			door.locked = not (campaign.vault_unlocked or progression.vault_unlocked)
			door.locked_interaction.connect(_inspect_vault)
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
	_presence_tween.tween_interval(6.0)
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

func _refresh_objective() -> void:
	if not is_instance_valid(objective): return
	objective.update_state(progression, campaign.code_found)
	house_map.objective_state = objective.state
	status_hud.set_objective(objective.text)

func _toggle_map() -> void:
	var opened: bool = not house_map.expanded
	house_map.set_expanded(opened)
	get_tree().paused = opened
	player.active = not opened and not _leaving
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opened else Input.MOUSE_MODE_CAPTURED
