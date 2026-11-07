extends Node3D
const Art = preload("res://scripts/horror_theme.gd")
const Player = preload("res://scripts/player.gd")
const Boss = preload("res://scripts/smiling_spider.gd")
const Progression = preload("res://scripts/progression.gd")
const BossHud = preload("res://scripts/boss_health_bar.gd")
const StatusHud = preload("res://scripts/status_hud.gd")
var qa_mode := false
var player: BlackwebPlayer
var boss: BlackwebSmilingSpider
var progression: BlackwebProgression
var boss_bar: BlackwebBossHealthBar
var status_hud: BlackwebStatusHud
var dialogue: Node
var caption: Label
var tell: Label
var panel: PanelContainer
var begin_button: Button
var retry_button: Button
var panel_title: Label
var started := false
var introduction_remaining := 0.0
var _tell_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_install_input()
	var settings := preload("res://scripts/menu_settings.gd").new()
	if not qa_mode: settings.load_preferences()
	settings.configure_graphics(OS.get_cmdline_user_args())
	settings.apply(false)
	settings.apply_graphics(get_viewport())
	_build_room()
	progression = Progression.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	progression.process_mode = Node.PROCESS_MODE_PAUSABLE
	progression.stage = Progression.Stage.ENCOUNTER
	add_child(progression)
	progression.set_process(false)
	player = Player.new()
	player.name = "Luke"
	player.progression = progression
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.position = Vector3(0, 0.04, 6.0)
	player.spawn_transform = player.transform
	player.set_view(0.0)
	player.attach_model(load("res://scenes/luke.tscn"))
	player.camera.current = true
	progression.player = player
	progression.checkpoint_restored.connect(_retry)
	boss = Boss.new()
	boss.position = Vector3(0, 0.04, -3.7)
	boss.rotation.y = PI
	add_child(boss)
	dialogue = preload("res://scripts/boss_dialogue.gd").new()
	add_child(dialogue)
	_build_hud()
	player.health_changed.connect(status_hud.set_health)
	player.stamina_changed.connect(status_hud.set_stamina)
	player.battery_changed.connect(func(v: float): status_hud.set_battery(v, player._light_on))
	player.inventory_changed.connect(_inventory_changed)
	player.quick_slot_changed.connect(status_hud.set_selected_slot)
	player.recovery_changed.connect(func(recovering: bool):
		if recovering:
			boss.stop()
			boss_bar.reset()
			dialogue.reset()
			tell.text = "YOU WERE CAUGHT"
			introduction_remaining = 0.0)
	boss.health_changed.connect(boss_bar.update_health)
	boss.attack_started.connect(_attack_tell)
	boss.phase_changed.connect(func(value: int):
		if value == 2: dialogue.say("phase_two"))
	boss.defeated.connect(_won)
	dialogue.caption_changed.connect(func(text: String): caption.text = text)
	_inventory_changed()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_panel("GREENHOUSE / COMBAT PREVIEW", false)

func _install_input() -> void:
	var keys := {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"sprint":KEY_SHIFT,"crouch":KEY_C,"jump":KEY_SPACE,"interact":KEY_E,"flashlight":KEY_F,"pause_game":KEY_ESCAPE,"hotbar_1":KEY_1,"hotbar_2":KEY_2,"hotbar_3":KEY_3,"inventory_toggle":KEY_I}
	for action in keys:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func _build_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080d0e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da6a6")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	_box("Floor", Vector3(0,-0.12,0), Vector3(16,0.24,22), Color("303632"), true)
	for x in [-8.0,8.0]: _box("SideWall", Vector3(x,2.5,0), Vector3(0.3,5,22), Color("1d2b29"), true)
	for z in [-11.0,11.0]: _box("EndWall", Vector3(0,2.5,z), Vector3(16,5,0.3), Color("172421"), true)
	for z in [-10.0,-6.0,-2.0,2.0,6.0,10.0]:
		for x in [-7.5,7.5]:
			_box("SteelUpright",Vector3(x,2.6,z),Vector3(0.14,5.2,0.14),Color("52635b"),false)
		_box("RoofTie",Vector3(0,5.0,z),Vector3(15,0.14,0.14),Color("52635b"),false)
	for z in [-8.0,-3.0,2.0,7.0]:
		for x in [-6.9,6.9]:
			_box("GrowingBed",Vector3(x,0.65,z),Vector3(1.4,1.3,3.1),Color("29312a"),true)
			_box("Soil",Vector3(x,1.32,z),Vector3(1.35,0.06,3),Color("181b15"),false)
	for x in [-5.0,5.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x,3.8,-2.5)
		light.light_color = Color("a7c4bb")
		light.light_energy = 2.4
		light.omni_range = 14.0
		light.shadow_enabled = false
		add_child(light)
	var exit_light := OmniLight3D.new()
	exit_light.position = Vector3(0,3,-9)
	exit_light.light_color = Color("ba4d38")
	exit_light.light_energy = 1.5
	exit_light.omni_range = 8
	add_child(exit_light)
	var web_scene := load("res://assets/generated/web_master/web_masters.glb") as PackedScene
	if web_scene:
		var source := web_scene.instantiate()
		var web := source.find_child("WebRadialTorn",true,false) as Node3D
		if web:
			for x in [-5.5,0.0,5.5]:
				var instance := web.duplicate() as Node3D
				instance.position = Vector3(x,3.4,-10.7)
				instance.scale = Vector3.ONE * 1.4
				add_child(instance)
		var canopy := source.find_child("WebSaggingCanopy",true,false) as Node3D
		if canopy:
			for z in [-5.0,3.0]:
				var instance := canopy.duplicate() as Node3D
				instance.position = Vector3(0,4.7,z)
				instance.scale = Vector3(2,0.5,1.5)
				add_child(instance)
		source.free()

func _box(label: String, at: Vector3, dimensions: Vector3, color: Color, solid: bool) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	node.material_override = material
	node.position = at
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		node.add_child(body)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Art.apply_theme(root)
	layer.add_child(root)
	status_hud = StatusHud.new()
	status_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(status_hud)
	status_hud.set_layout(2)
	status_hud.equip_requested.connect(func(cell: int, slot: int): player.equip_inventory_cell(cell, slot))
	status_hud.set_objective("Learn its attacks. Strike during recovery.")
	boss_bar = BossHud.new()
	boss_bar.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(boss_bar)
	caption = _label("",22)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 170
	caption.offset_right = -170
	caption.offset_top = -180
	caption.offset_bottom = -105
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_outline_size",5)
	root.add_child(caption)
	tell = _label("",16)
	tell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tell.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tell.offset_top = 108
	tell.offset_bottom = 150
	tell.offset_left = 80
	tell.offset_right = -80
	root.add_child(tell)
	var note := _label("COMBAT PREVIEW · temporary spider body · Esc: pause",12)
	note.position = Vector2(22,14)
	note.size = Vector2(260,42)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -255
	panel.offset_right = 255
	panel.offset_top = -175
	panel.offset_bottom = 175
	panel.add_theme_stylebox_override("panel",Art.steel_panel(24))
	root.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",14)
	panel.add_child(stack)
	panel_title = _label("",28)
	Art.heading(panel_title,28)
	stack.add_child(panel_title)
	stack.add_child(_label("Six attacks. Read the wind-up and strike during recovery. The approved stone-crown model is pending export; this preview uses the existing spider rig.",16))
	stack.add_child(_label("WASD move · Shift sprint · C crouch · Space jump\n2 knife · Click attack · 3 candy · F flashlight\nYour tutorial save is kept separately.",15))
	begin_button = _button("Begin encounter",_start_or_resume)
	stack.add_child(begin_button)
	retry_button = _button("Restart encounter",_retry)
	stack.add_child(retry_button)
	stack.add_child(_button("Return to main menu",_return_menu))

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	Art.button(button,17)
	button.pressed.connect(action)
	return button

func _inventory_changed() -> void:
	status_hud.set_inventory_model(player.inventory_slots(), player.equipped_items())
	status_hud.set_inventory_counts(player.inventory_counts())
	status_hud.set_selected_slot(player.selected_quick_index)
	status_hud.set_battery(player.battery_charge, player._light_on)

func _show_panel(title: String, resume: bool) -> void:
	panel_title.text = title
	begin_button.text = "Resume" if resume else "Begin encounter"
	begin_button.visible = not (started and boss.state == Boss.State.DEAD)
	retry_button.visible = started
	panel.show()
	begin_button.grab_focus()

func _start_or_resume() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.active = true
	if not started:
		started = true
		dialogue.say("arrival")
		dialogue.say("greeting")
		introduction_remaining = 9.0
		tell.text = "The greenhouse is occupied. Keep your distance."

func _retry() -> void:
	get_tree().paused = false
	introduction_remaining = 0.0
	dialogue.reset()
	boss.stop()
	boss.position = Vector3(0,0.04,-3.7)
	boss.rotation.y = PI
	player.restore_checkpoint()
	player.battery_charge = 60.0
	player.inventory.reset()
	player.select_quick_slot(1)
	_inventory_changed()
	player.active = true
	started = true
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	boss.begin(player)
	boss_bar.begin(boss.health,boss.max_health)
	tell.text = "Read its movement. Counterattack after it misses."
	_tell_remaining = 4.0

func _process(delta: float) -> void:
	if get_tree().paused: return
	if introduction_remaining > 0.0:
		introduction_remaining -= delta
		if introduction_remaining <= 0.0:
			boss.begin(player)
			boss_bar.begin(boss.health,boss.max_health)
			dialogue.say("warning")
	if _tell_remaining > 0.0:
		_tell_remaining -= delta
		if _tell_remaining <= 0.0: tell.text = ""

func _attack_tell(_id: String, hint: String) -> void:
	tell.text = hint
	_tell_remaining = 2.8

func _won() -> void:
	boss_bar.finish()
	dialogue.reset()
	dialogue.say("victory")
	tell.text = "ENCOUNTER COMPLETE · Esc to restart or return"
	_tell_remaining = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle") and started and not panel.visible and not player.is_recovering():
		get_viewport().set_input_as_handled()
		status_hud.toggle_inventory()
		get_tree().paused = status_hud.is_inventory_open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		if status_hud.is_inventory_open():
			status_hud.hide_inventory()
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if panel.visible and started and boss.state != Boss.State.DEAD: _start_or_resume()
		elif started:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_show_panel("ENCOUNTER COMPLETE" if boss.state == Boss.State.DEAD else "PAUSED",true)

func _return_menu() -> void:
	dialogue.reset()
	boss.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")
