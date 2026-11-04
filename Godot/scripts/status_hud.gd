class_name BlackwebStatusHud
extends Control

class MinimalItemGlyph:
	extends Control
	var item_id: StringName
	func _init(id: StringName = &"") -> void:
		item_id = id
		custom_minimum_size = Vector2(42, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Color(0.91, 0.93, 0.89, 0.96)
		match item_id:
			&"flashlight":
				draw_line(Vector2(5, 20), Vector2(12, 16), ink, 2.0, true)
				draw_line(Vector2(12, 16), Vector2(22, 10), ink, 2.0, true)
				draw_line(Vector2(22, 10), Vector2(27, 18), ink, 2.0, true)
				draw_line(Vector2(27, 18), Vector2(13, 24), ink, 2.0, true)
				draw_line(Vector2(13, 24), Vector2(12, 16), ink, 2.0, true)
				draw_line(Vector2(22, 10), Vector2(29, 6), ink, 2.0, true)
				draw_line(Vector2(29, 6), Vector2(34, 15), ink, 2.0, true)
				draw_line(Vector2(34, 15), Vector2(27, 18), ink, 2.0, true)
				draw_line(Vector2(35, 8), Vector2(39, 7), ink, 1.3, true)
				draw_line(Vector2(36, 12), Vector2(41, 12), ink, 1.3, true)
			&"knife":
				draw_line(Vector2(6, 25), Vector2(19, 16), ink, 2.4, true)
				draw_line(Vector2(9, 28), Vector2(22, 19), ink, 2.4, true)
				draw_line(Vector2(19, 16), Vector2(22, 19), ink, 2.0, true)
				draw_line(Vector2(21, 15), Vector2(38, 3), ink, 2.0, true)
				draw_line(Vector2(38, 3), Vector2(34, 15), ink, 2.0, true)
				draw_line(Vector2(34, 15), Vector2(22, 19), ink, 2.0, true)
			&"candy_bar":
				draw_line(Vector2(4, 10), Vector2(34, 7), ink, 2.0, true)
				draw_line(Vector2(34, 7), Vector2(38, 20), ink, 2.0, true)
				draw_line(Vector2(38, 20), Vector2(8, 23), ink, 2.0, true)
				draw_line(Vector2(8, 23), Vector2(4, 10), ink, 2.0, true)
				draw_line(Vector2(11, 9), Vector2(15, 22), ink, 1.2, true)
				draw_line(Vector2(29, 8), Vector2(33, 21), ink, 1.2, true)
				draw_line(Vector2(18, 14), Vector2(25, 13), ink, 1.2, true)
			&"bandage":
				draw_rect(Rect2(8, 7, 27, 18), ink, false, 2.0)
				draw_line(Vector2(15, 16), Vector2(28, 16), ink, 2.0, true)
				draw_line(Vector2(21, 10), Vector2(21, 22), ink, 2.0, true)
			&"flare":
				draw_line(Vector2(7, 24), Vector2(29, 9), ink, 4.0, true)
				draw_line(Vector2(29, 9), Vector2(35, 4), Color(0.96, 0.52, 0.32), 3.0, true)
			_:
				if str(item_id).begins_with("battery_"):
					draw_rect(Rect2(8, 8, 27, 16), ink, false, 2.0)
					draw_rect(Rect2(35, 12, 4, 8), ink)
					draw_line(Vector2(18, 11), Vector2(15, 17), ink, 2.0, true)
					draw_line(Vector2(15, 17), Vector2(23, 17), ink, 2.0, true)

const LAYOUT_NAMES := ["FIELD", "SURVIVAL", "MINIMAL", "VERTICAL"]

var layout_index := 2
var stamina := 100.0
var health := 100.0
var flashlight_owned := true
var flashlight_on := true
var battery_charge := 22.0
var inventory_counts: Dictionary = {&"knife": 1, &"candy_bar": 1, &"bandage": 0, &"flare": 0}
var inventory_slots: Array[Dictionary] = []
var equipped_items: Array[StringName] = [&"flashlight", &"knife", &"candy_bar"]
var selected_quick_index := 0
var objective_text := "Find the source of the warning."
var record_found := false
var _shell: Control
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _battery_bar: ProgressBar
var _battery_label: Label
var _slot_labels: Array[Label] = []
var _slot_glyphs: Array[MinimalItemGlyph] = []
var _slot_roots: Array[Control] = []
var _inventory_backdrop: ColorRect
var _inventory_root: PanelContainer
var _inventory_loadout: Label
var _inventory_supplies: Label
var _inventory_condition: Label
var _inventory_records: Label
var _inventory_cell_buttons: Array[Button] = []
var _quick_buttons: Array[Button] = []
var _inventory_capacity_label: Label
var _inventory_hint: Label
var _selected_cell := -1

signal equip_requested(cell_index: int, quick_index: int)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_inventory()
	_build()

func set_layout(index: int) -> void:
	layout_index = clampi(index, 0, LAYOUT_NAMES.size() - 1)
	if is_inside_tree(): _build()

func set_selected_slot(index: int) -> void:
	selected_quick_index = clampi(index, 0, 2)
	_refresh_slots()

func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, 100.0)
	if is_instance_valid(_stamina_bar): _stamina_bar.value = stamina
	_refresh_inventory()

func set_health(value: float) -> void:
	health = clampf(value, 0.0, 100.0)
	if is_instance_valid(_health_bar): _health_bar.value = health
	_refresh_inventory()

func set_flashlight(owned: bool, on: bool) -> void:
	flashlight_owned = owned
	flashlight_on = on
	_refresh_slots()
	_refresh_battery()

func set_battery(value: float, on: bool) -> void:
	battery_charge = clampf(value, 0.0, 100.0)
	flashlight_on = on
	_refresh_battery()
	_refresh_slots()

func set_inventory_counts(counts: Dictionary) -> void:
	inventory_counts = counts.duplicate()
	_refresh_slots()
	_refresh_inventory()

func set_inventory_model(cells: Array[Dictionary], equipped: Array[StringName]) -> void:
	inventory_slots = cells.duplicate(true)
	equipped_items = equipped.duplicate()
	_refresh_slots()
	_refresh_inventory()
	_refresh_inventory_grid()

func set_objective(text: String) -> void:
	objective_text = text
	_refresh_inventory()

func set_record_found(found: bool) -> void:
	record_found = found
	_refresh_inventory()

func toggle_inventory() -> void:
	if not is_instance_valid(_inventory_root): return
	_inventory_root.visible = not _inventory_root.visible
	_inventory_backdrop.visible = _inventory_root.visible
	if is_instance_valid(_shell): _shell.visible = not _inventory_root.visible

func hide_inventory() -> void:
	if is_instance_valid(_inventory_root): _inventory_root.visible = false
	if is_instance_valid(_inventory_backdrop): _inventory_backdrop.visible = false
	if is_instance_valid(_shell): _shell.visible = true

func is_inventory_open() -> bool:
	return is_instance_valid(_inventory_root) and _inventory_root.visible

func _build() -> void:
	if is_instance_valid(_shell): _shell.queue_free()
	_slot_labels.clear()
	_slot_glyphs.clear()
	_slot_roots.clear()
	if layout_index == 2:
		_build_minimal()
		_refresh_battery()
		_refresh_slots()
		if is_instance_valid(_inventory_root):
			move_child(_inventory_backdrop, get_child_count() - 2)
			move_child(_inventory_root, get_child_count() - 1)
			_shell.visible = not is_inventory_open()
		return
	_shell = PanelContainer.new()
	_shell.name = "Status%s" % LAYOUT_NAMES[layout_index]
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_theme_stylebox_override("panel", _panel_style())
	add_child(_shell)
	_position_shell()
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5 if layout_index == 2 else 8)
	_shell.add_child(column)
	if layout_index != 2:
		var title := Label.new()
		title.text = "BLACKWEB  /  %s" % LAYOUT_NAMES[layout_index]
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(0.70, 0.75, 0.72))
		column.add_child(title)
	var health_label := Label.new()
	health_label.text = "HEALTH"
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.68))
	column.add_child(health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size.y = 7 if layout_index == 2 else 9
	_health_bar.max_value = 100.0
	_health_bar.value = health
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background", _bar_style(Color(0.10, 0.13, 0.14, 0.95)))
	_health_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.65, 0.35, 0.29)))
	column.add_child(_health_bar)
	var stamina_label := Label.new()
	stamina_label.text = "STAMINA"
	stamina_label.add_theme_font_size_override("font_size", 12)
	stamina_label.add_theme_color_override("font_color", Color(0.85, 0.84, 0.76))
	column.add_child(stamina_label)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size.y = 7 if layout_index == 2 else 10
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = stamina
	_stamina_bar.show_percentage = false
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.add_theme_stylebox_override("background", _bar_style(Color(0.10, 0.13, 0.14, 0.95)))
	_stamina_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.75, 0.66, 0.43) if layout_index != 3 else Color(0.60, 0.74, 0.72)))
	column.add_child(_stamina_bar)
	_battery_label = Label.new()
	_battery_label.add_theme_font_size_override("font_size", 12)
	_battery_label.add_theme_color_override("font_color", Color(0.87, 0.79, 0.58))
	column.add_child(_battery_label)
	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size.y = 7 if layout_index == 2 else 9
	_battery_bar.max_value = 100.0
	_battery_bar.show_percentage = false
	_battery_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battery_bar.add_theme_stylebox_override("background", _bar_style(Color(0.10, 0.13, 0.14, 0.95)))
	column.add_child(_battery_bar)
	var slots: BoxContainer = VBoxContainer.new() if layout_index == 3 else HBoxContainer.new()
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.add_theme_constant_override("separation", 5)
	column.add_child(slots)
	for index in range(3):
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(164 if layout_index == 3 else (131 if layout_index == 2 else 110), 37 if layout_index == 3 else 41)
		slot.add_theme_stylebox_override("panel", _slot_style(_equipped_count(index) > 0))
		slots.add_child(slot)
		_slot_roots.append(slot)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.79))
		slot.add_child(label)
		_slot_labels.append(label)
	_refresh_battery()
	_refresh_slots()
	if is_instance_valid(_inventory_root):
		move_child(_inventory_backdrop, get_child_count() - 2)
		move_child(_inventory_root, get_child_count() - 1)
		_shell.visible = not is_inventory_open()

func _build_minimal() -> void:
	_shell = Control.new()
	_shell.name = "StatusMINIMAL"
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shell)
	var meters := VBoxContainer.new()
	meters.name = "MinimalMeters"
	meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meters.anchor_top = 1.0
	meters.anchor_bottom = 1.0
	meters.offset_left = 40.0
	meters.offset_right = 530.0
	meters.offset_top = -120.0
	meters.offset_bottom = -25.0
	meters.add_theme_constant_override("separation", 8)
	_shell.add_child(meters)
	_health_bar = _minimal_meter(meters, "HEALTH", Color(0.91, 0.39, 0.37))[1] as ProgressBar
	_stamina_bar = _minimal_meter(meters, "STAMINA", Color(0.89, 0.71, 0.36))[1] as ProgressBar
	var battery_nodes: Array = _minimal_meter(meters, "BATTERY", Color(0.29, 0.86, 0.90))
	_battery_label = battery_nodes[0] as Label
	_battery_bar = battery_nodes[1] as ProgressBar
	var items := HBoxContainer.new()
	items.name = "MinimalItems"
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.anchor_left = 1.0
	items.anchor_right = 1.0
	items.anchor_top = 1.0
	items.anchor_bottom = 1.0
	items.offset_left = -460.0
	items.offset_right = -27.0
	items.offset_top = -105.0
	items.offset_bottom = -26.0
	items.add_theme_constant_override("separation", 13)
	_shell.add_child(items)
	for index in range(3):
		if index > 0:
			var divider := ColorRect.new()
			divider.color = Color(0.75, 0.79, 0.79, 0.42)
			divider.custom_minimum_size = Vector2(1, 46)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			items.add_child(divider)
		var item := VBoxContainer.new()
		item.custom_minimum_size.x = 126
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 1)
		items.add_child(item)
		_slot_roots.append(item)
		var upper := HBoxContainer.new()
		upper.alignment = BoxContainer.ALIGNMENT_CENTER
		upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		upper.add_theme_constant_override("separation", 7)
		item.add_child(upper)
		var glyph := MinimalItemGlyph.new(equipped_items[index])
		upper.add_child(glyph)
		_slot_glyphs.append(glyph)
		var key := Label.new()
		key.text = str(index + 1)
		key.add_theme_font_size_override("font_size", 18)
		key.add_theme_color_override("font_color", Color(0.93, 0.94, 0.90))
		upper.add_child(key)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.86))
		item.add_child(label)
		_slot_labels.append(label)

func _minimal_meter(parent: VBoxContainer, title: String, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 11)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 103
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.91))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = health if title == "HEALTH" else (stamina if title == "STAMINA" else battery_charge)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.24, 0.28, 0.29, 0.75)))
	bar.add_theme_stylebox_override("fill", _bar_style(color))
	row.add_child(bar)
	return [label, bar]

func _position_shell() -> void:
	match layout_index:
		0:
			_set_rect(1.0, 0.0, -392, 28, -24, 235)
		1:
			_set_rect(0.0, 1.0, 28, -238, 400, -25)
		2:
			_set_rect(0.5, 1.0, -224, -170, 224, -20)
		3:
			_set_rect(1.0, 0.5, -201, -188, -24, 188)

func _set_rect(anchor_x: float, anchor_y: float, left: float, top: float, right: float, bottom: float) -> void:
	_shell.anchor_left = anchor_x
	_shell.anchor_right = anchor_x
	_shell.anchor_top = anchor_y
	_shell.anchor_bottom = anchor_y
	_shell.offset_left = left
	_shell.offset_top = top
	_shell.offset_right = right
	_shell.offset_bottom = bottom

func _refresh_slots() -> void:
	if _slot_labels.size() != 3: return
	for index in range(3):
		var id: StringName = equipped_items[index]
		var label := BlackwebInventoryGrid.display_name(id)
		var count := _equipped_count(index)
		var state := ""
		if id == &"flashlight":
			state = "EMPTY" if battery_charge <= 0.0 else ("ON" if flashlight_on else "OFF")
		elif id == &"knife":
			state = "LOW DAMAGE"
		elif count <= 0:
			state = "USED"
		else:
			state = "x%d" % count
		_slot_labels[index].text = "%s  /  %s" % [label, state] if layout_index == 2 else "%d  %s\n%s" % [index + 1, label, state]
		if index < _slot_roots.size():
			_slot_roots[index].modulate = Color(1.0, 0.90, 0.66) if index == selected_quick_index else Color(0.72, 0.75, 0.75)
		if index < _slot_glyphs.size():
			_slot_glyphs[index].item_id = id
			_slot_glyphs[index].queue_redraw()
	_refresh_inventory()

func _equipped_count(index: int) -> int:
	if index < 0 or index >= equipped_items.size(): return 0
	var id: StringName = equipped_items[index]
	if str(id).begins_with("battery_"):
		var total := 0
		for cell in inventory_slots:
			if cell.get("id", &"") == id: total += int(cell.get("count", 0))
		return total
	return int(inventory_counts.get(id, 0))

func _refresh_battery() -> void:
	if is_instance_valid(_battery_bar):
		_battery_bar.value = battery_charge
		_battery_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.76, 0.33, 0.22) if battery_charge <= 8.0 else (Color(0.82, 0.60, 0.29) if battery_charge <= 25.0 else Color(0.68, 0.75, 0.52))))
	if is_instance_valid(_battery_label):
		var warning := "  /  EMPTY" if battery_charge <= 0.0 else ("  /  FLICKERING" if battery_charge <= 25.0 and flashlight_on else "")
		_battery_label.text = "BATTERY  %d%%" % ceili(battery_charge) if layout_index == 2 else "BATTERY  %d%%%s" % [ceili(battery_charge), warning]
	_refresh_inventory()

func _build_inventory() -> void:
	_inventory_backdrop = ColorRect.new()
	_inventory_backdrop.name = "InventoryBackdrop"
	_inventory_backdrop.color = Color(0.006, 0.010, 0.014, 0.86)
	_inventory_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_inventory_backdrop)
	_inventory_backdrop.visible = false
	_inventory_root = PanelContainer.new()
	_inventory_root.name = "FiftySlotInventory"
	_inventory_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_root.anchor_left = 0.5
	_inventory_root.anchor_right = 0.5
	_inventory_root.anchor_top = 0.5
	_inventory_root.anchor_bottom = 0.5
	_inventory_root.offset_left = -505
	_inventory_root.offset_right = 505
	_inventory_root.offset_top = -345
	_inventory_root.offset_bottom = 345
	var frame := _panel_style()
	frame.bg_color = Color(0.025, 0.038, 0.045, 0.97)
	frame.set_content_margin_all(15)
	_inventory_root.add_theme_stylebox_override("panel", frame)
	add_child(_inventory_root)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	_inventory_root.add_child(stack)
	var title := Label.new()
	title.text = "BLACKWEB   /   FIELD INVENTORY                                   I  CLOSE"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.87, 0.84, 0.73))
	stack.add_child(title)
	var quick_heading := Label.new()
	quick_heading.text = "QUICK ACCESS    /    THREE ACTIVE ITEMS"
	quick_heading.add_theme_font_size_override("font_size", 13)
	quick_heading.add_theme_color_override("font_color", Color(0.75, 0.65, 0.43))
	stack.add_child(quick_heading)
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 8)
	stack.add_child(quick_row)
	for index in range(3):
		var quick := Button.new()
		quick.custom_minimum_size = Vector2(318, 49)
		quick.add_theme_font_size_override("font_size", 14)
		quick.pressed.connect(_on_quick_button.bind(index))
		quick_row.add_child(quick)
		_quick_buttons.append(quick)
	var grid_heading := HBoxContainer.new()
	stack.add_child(grid_heading)
	var bag_label := Label.new()
	bag_label.text = "BACKPACK    /    50 CELLS"
	bag_label.add_theme_font_size_override("font_size", 13)
	bag_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.43))
	grid_heading.add_child(bag_label)
	_inventory_capacity_label = Label.new()
	_inventory_capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inventory_capacity_label.add_theme_font_size_override("font_size", 12)
	grid_heading.add_child(_inventory_capacity_label)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	stack.add_child(grid)
	for index in range(BlackwebInventoryGrid.CAPACITY):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(92, 46)
		cell.add_theme_font_size_override("font_size", 11)
		cell.pressed.connect(_select_cell.bind(index))
		grid.add_child(cell)
		_inventory_cell_buttons.append(cell)
	var information := HBoxContainer.new()
	information.add_theme_constant_override("separation", 8)
	stack.add_child(information)
	_inventory_loadout = _inventory_panel(information, "01  /  LOADOUT")
	_inventory_supplies = _inventory_panel(information, "02  /  SUPPLIES")
	_inventory_condition = _inventory_panel(information, "03  /  CONDITION")
	_inventory_records = _inventory_panel(information, "04  /  RECORDS")
	_inventory_hint = Label.new()
	_inventory_hint.text = "CLICK AN ITEM, THEN A QUICK SLOT TO EQUIP   /   1–3 ACTIVE   /   I CLOSE"
	_inventory_hint.add_theme_font_size_override("font_size", 12)
	_inventory_hint.add_theme_color_override("font_color", Color(0.73, 0.77, 0.73))
	stack.add_child(_inventory_hint)
	_inventory_root.visible = false
	_refresh_inventory()
	_refresh_inventory_grid()

func _inventory_panel(row: HBoxContainer, title: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(238, 127)
	var style := _panel_style()
	style.bg_color = Color(0.07, 0.10, 0.11, 0.92)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.75, 0.65, 0.43))
	stack.add_child(heading)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(212, 89)
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.87, 0.86, 0.81))
	stack.add_child(body)
	return body

func _refresh_inventory() -> void:
	if not is_instance_valid(_inventory_loadout): return
	_inventory_loadout.text = "1  %s\n2  %s\n3  %s\nOnly equipped items can be used." % [BlackwebInventoryGrid.display_name(equipped_items[0]), BlackwebInventoryGrid.display_name(equipped_items[1]), BlackwebInventoryGrid.display_name(equipped_items[2])]
	_inventory_supplies.text = "Battery charge: %d%%\nPacks: %d  ·  Bandages: %d\nFlares: %d\nSelect cell → quick slot to equip." % [ceili(battery_charge), int(inventory_counts.get(&"battery", 0)), int(inventory_counts.get(&"bandage", 0)), int(inventory_counts.get(&"flare", 0))]
	_inventory_condition.text = "Health: %d / 100\nStamina: %d / 100\nArmor: 0 / none\n%s" % [ceili(health), ceili(stamina), objective_text]
	_inventory_records.text = "PROJECT 08\nPrisoner tissue was grafted to spiders; the altered subjects drew in a demonic presence." if record_found else "No field record found yet.\nSearch the house's drawers and cabinets."
	for index in range(_quick_buttons.size()):
		var id: StringName = equipped_items[index]
		_quick_buttons[index].text = "%d    %s    /    %s" % [index + 1, BlackwebInventoryGrid.display_name(id), "x%d" % _equipped_count(index) if id not in [&"flashlight", &"knife"] else ("ON" if flashlight_on else "OFF") if id == &"flashlight" else "READY"]

func _refresh_inventory_grid() -> void:
	if _inventory_cell_buttons.size() != BlackwebInventoryGrid.CAPACITY: return
	var occupied := 0
	for index in range(BlackwebInventoryGrid.CAPACITY):
		var cell: Dictionary = inventory_slots[index] if index < inventory_slots.size() else {}
		var button := _inventory_cell_buttons[index]
		var id := StringName(str(cell.get("id", "")))
		var count := int(cell.get("count", 0))
		if id == &"":
			button.text = "%02d\n·" % (index + 1)
			button.modulate = Color(0.68, 0.72, 0.72, 0.74)
		else:
			occupied += 1
			var short_name := BlackwebInventoryGrid.display_name(id)
			button.text = "%02d  %s\nx%d%s" % [index + 1, short_name, count, "  [E]" if equipped_items.has(id) else ""]
			button.modulate = Color(1.0, 0.88, 0.58) if index == _selected_cell else (Color(0.78, 0.94, 0.92) if equipped_items.has(id) else Color(0.92, 0.93, 0.88))
	if is_instance_valid(_inventory_capacity_label):
		_inventory_capacity_label.text = "%d / 50 OCCUPIED" % occupied
	_refresh_inventory()

func _select_cell(index: int) -> void:
	if index < 0 or index >= inventory_slots.size() or inventory_slots[index].is_empty():
		_selected_cell = -1
		_inventory_hint.text = "EMPTY CELL   /   SELECT AN ITEM TO EQUIP"
	else:
		_selected_cell = index
		_inventory_hint.text = "SELECTED %s   /   CLICK QUICK SLOT 1, 2, OR 3" % BlackwebInventoryGrid.display_name(StringName(str(inventory_slots[index].get("id", ""))))
	_refresh_inventory_grid()

func _on_quick_button(quick_index: int) -> void:
	if _selected_cell < 0 or _selected_cell >= inventory_slots.size():
		_inventory_hint.text = "SELECT A BACKPACK ITEM FIRST, THEN THIS QUICK SLOT"
		return
	if inventory_slots[_selected_cell].is_empty():
		_selected_cell = -1
		_inventory_hint.text = "ITEM USED   /   SELECT ANOTHER BACKPACK CELL"
		return
	equip_requested.emit(_selected_cell, quick_index)
	_inventory_hint.text = "EQUIPPED   /   PRESS %d TO DRAW, THEN LEFT CLICK TO USE" % (quick_index + 1)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.06, 0.82 if layout_index != 2 else 0.66)
	style.border_color = Color(0.44, 0.49, 0.42, 0.75)
	style.set_border_width_all(1)
	style.set_content_margin_all(11 if layout_index != 2 else 7)
	style.set_corner_radius_all(3)
	return style

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style

func _slot_style(available: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.17, 0.95) if available else Color(0.07, 0.09, 0.10, 0.8)
	style.border_color = Color(0.44, 0.47, 0.40, 0.9) if available else Color(0.27, 0.30, 0.31, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	return style
