class_name BlackwebStorage
extends BlackwebInteraction

signal clue_found(text: String)
signal supplies_found(text: String)

const SupplyVisual = preload("res://scripts/supply_pickup.gd")

## Lightweight fixture with one deterministic loot roll per new opening.
var storage_kind: StringName = &"drawer"
var player: BlackwebPlayer
var loot_entries: Array = []
var loot_seed := 0
var opened := false
var _moving: Node3D
var _animation_tween: Tween
var clue_text := ""
var _clue_shown := false
var _loot_rolled := false
var _searched_once := false
var _searched_this_open := false
var _pending_loot: Array = []
var _loot_anchor: Node3D
var _loot_visuals: Node3D

func _ready() -> void:
	add_to_group("storage")
	kind = &"storage"
	label = "Open drawer" if storage_kind == &"drawer" else "Open cabinet"
	super._ready()
	var trigger := get_child(0) as CollisionShape3D
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(0.88, 0.55, 0.35)
	trigger.shape = trigger_shape
	trigger.position.y = -0.18
	_build_fixture()

func prompt() -> String:
	var noun := "drawer" if storage_kind == &"drawer" else "cabinet"
	if not opened:
		return "E   ·   Open " + noun
	if not _searched_this_open and (not _searched_once or not _pending_loot.is_empty()):
		return "E   ·   Search " + noun
	return "E   ·   Close " + noun

func interact() -> void:
	if opened and not _searched_this_open and (not _searched_once or not _pending_loot.is_empty()):
		_searched_once = true
		_searched_this_open = true
		supplies_found.emit(_collect_loot())
		return
	opened = not opened
	if opened:
		_searched_this_open = false
		_roll_loot()
		if not _clue_shown and not clue_text.is_empty():
			_clue_shown = true
			clue_found.emit(clue_text)
	if is_instance_valid(_animation_tween): _animation_tween.kill()
	_animation_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_animation_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if storage_kind == &"drawer":
		_animation_tween.tween_property(_moving, "position:z", -0.38 if opened else 0.0, 0.42)
	else:
		_animation_tween.tween_property(_moving, "rotation:y", 1.28 if opened else 0.0, 0.55)

func reset_loot(new_seed: int) -> void:
	loot_seed = new_seed
	_loot_rolled = false
	_searched_once = false
	_searched_this_open = false
	_pending_loot.clear()
	_clue_shown = false
	opened = false
	if is_instance_valid(_animation_tween): _animation_tween.kill()
	if is_instance_valid(_moving):
		_moving.position.z = 0.0 if storage_kind == &"drawer" else _moving.position.z
		_moving.rotation.y = 0.0
	_refresh_loot_visuals()

func _roll_loot() -> void:
	if _loot_rolled: return
	_loot_rolled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed
	for raw_entry in loot_entries:
		if not raw_entry is Dictionary: continue
		var entry: Dictionary = raw_entry
		var chance := clampf(float(entry.get("chance", 1.0)), 0.0, 1.0)
		if rng.randf() < chance:
			_pending_loot.append(entry.duplicate(true))
	_refresh_loot_visuals()

func _collect_loot() -> String:
	var found: Array[String] = []
	var remaining: Array = []
	for entry in _pending_loot:
		var item := StringName(str(entry.get("item", "")))
		var amount := maxf(0.0, float(entry.get("amount", 1)))
		if item == &"battery":
			if not is_instance_valid(player) or not player.add_battery_pack(amount):
				remaining.append(entry)
				continue
			found.append("battery pack +%d%%" % roundi(amount))
		elif item in [&"bandage", &"flare"] and is_instance_valid(player):
			var count := maxi(1, roundi(amount))
			var before := player.item_count(item)
			var after := player.add_item(item, count)
			if after == before:
				remaining.append(entry)
			else:
				found.append("%s ×%d" % [str(item), after - before])
	_pending_loot = remaining
	_refresh_loot_visuals()
	if not found.is_empty():
		return "FOUND  /  " + ", ".join(found).to_upper()
	if not remaining.is_empty():
		return "INVENTORY FULL  /  SUPPLY REMAINS HERE"
	return "NOTHING ELSE USEFUL INSIDE"

func _refresh_loot_visuals() -> void:
	if is_instance_valid(_loot_visuals):
		_loot_visuals.queue_free()
	if not is_instance_valid(_loot_anchor): return
	_loot_visuals = Node3D.new()
	_loot_visuals.name = "VisibleSupplies"
	_loot_anchor.add_child(_loot_visuals)
	for index in range(_pending_loot.size()):
		var kind := StringName(str(_pending_loot[index].get("item", "")))
		var visual: Node3D = SupplyVisual.make_visual(kind)
		visual.position = Vector3(-0.15 + float(index) * 0.22,
			-0.30 if storage_kind == &"drawer" else -0.015,
			-0.08)
		_loot_visuals.add_child(visual)

func _build_fixture() -> void:
	var wood := _material(Color(0.17, 0.125, 0.095))
	var inside := _material(Color(0.085, 0.065, 0.055))
	var metal := _material(Color(0.38, 0.37, 0.31), 0.55)
	var width := 0.93 if storage_kind == &"drawer" else 1.04
	var height := 0.72 if storage_kind == &"drawer" else 1.32
	var depth := 0.54
	var body := Node3D.new()
	body.name = "StorageBody"
	body.position = Vector3(0, -height * 0.50 + 0.05, 0.30)
	add_child(body)
	_box(body, "LeftSide", Vector3(-width * 0.5, 0, 0), Vector3(0.04, height, depth), wood)
	_box(body, "RightSide", Vector3(width * 0.5, 0, 0), Vector3(0.04, height, depth), wood)
	_box(body, "Top", Vector3(0, height * 0.5, 0), Vector3(width, 0.05, depth), wood)
	_box(body, "Bottom", Vector3(0, -height * 0.5, 0), Vector3(width, 0.05, depth), wood)
	_box(body, "Back", Vector3(0, 0, depth * 0.5), Vector3(width, height, 0.035), inside)
	if storage_kind == &"drawer":
		_box(body, "Divider", Vector3(0, -0.10, 0), Vector3(width, 0.035, depth), wood)
		_moving = Node3D.new()
		_moving.name = "AnimatedDrawer"
		body.add_child(_moving)
		_loot_anchor = _moving
		_box(_moving, "DrawerFront", Vector3(0, -0.22, -depth * 0.5 - 0.02), Vector3(width - 0.06, 0.28, 0.045), wood)
		_box(_moving, "DrawerTray", Vector3(0, -0.33, -0.06), Vector3(width - 0.10, 0.035, depth - 0.06), inside)
		_box(_moving, "Pull", Vector3(0, -0.22, -depth * 0.5 - 0.065), Vector3(0.17, 0.025, 0.03), metal)
		if not clue_text.is_empty():
			_box(_moving, "ExperimentRecord", Vector3(0, -0.307, -0.04), Vector3(0.25, 0.003, 0.18), _material(Color(0.57, 0.55, 0.44)))
	else:
		_box(body, "Shelf", Vector3(0, -0.04, 0), Vector3(width - 0.06, 0.035, depth), wood)
		_moving = Node3D.new()
		_moving.name = "AnimatedCabinetDoor"
		_moving.position = Vector3(-width * 0.5, 0, -depth * 0.5 - 0.015)
		body.add_child(_moving)
		_loot_anchor = body
		_box(_moving, "DoorPanel", Vector3(width * 0.5, 0, 0), Vector3(width - 0.04, height - 0.08, 0.04), wood)
		_box(_moving, "Handle", Vector3(width - 0.15, 0, -0.045), Vector3(0.025, 0.19, 0.035), metal)
	# The fixed case is solid to the player; only the door/tray is animated.
	var solid := StaticBody3D.new()
	solid.name = "StorageCollision"
	solid.collision_layer = 1
	solid.collision_mask = 0
	body.add_child(solid)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, depth * 0.7)
	collision.position.z = depth * 0.15
	collision.shape = shape
	solid.add_child(collision)

func _box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)

func _material(color: Color, metalness := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metalness
	material.roughness = 0.78
	return material
