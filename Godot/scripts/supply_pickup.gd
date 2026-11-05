class_name BlackwebSupplyPickup
extends BlackwebInteraction
## Small authored pickups. These are independent of the phone/keys/exit route.

const SupplyModels = preload("res://scripts/supply_models.gd")

signal picked_up(text: String)
signal unavailable(text: String)

var item_id: StringName = &"battery"
var amount := 1.0
var player: BlackwebPlayer
var taken := false


func _ready() -> void:
	kind = &"supply"
	label = _description()
	super._ready()
	item_visual = make_visual(item_id)
	add_child(item_visual)
	_refresh()


func interact() -> void:
	if taken or not is_instance_valid(player):
		return
	if item_id == &"battery":
		if not player.add_battery_pack(amount):
			unavailable.emit("INVENTORY FULL  /  LEAVE CELLS FOR LATER")
			return
		picked_up.emit("BATTERY CELLS  /  +%d%% PACK STORED" % roundi(amount))
	else:
		var before := player.item_count(item_id)
		if player.add_item(item_id, roundi(amount)) <= before:
			unavailable.emit("INVENTORY FULL  /  LEAVE SUPPLY FOR LATER")
			return
		picked_up.emit("FOUND  /  %s" % _description().to_upper())
	taken = true
	_refresh()


func reset_pickup() -> void:
	taken = false
	_refresh()


func _refresh() -> void:
	if is_instance_valid(item_visual): item_visual.visible = not taken
	collision_layer = 0 if taken else 8


func _description() -> String:
	match item_id:
		&"battery": return "Battery cells"
		&"bandage": return "Bandage pack"
		&"flare": return "Emergency flare"
	return "Supply"


static func make_visual(kind: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "SupplyVisual"
	if _add_blender_visual(root, kind):
		return root
	match kind:
		&"battery":
			var casing := _material(Color(0.21, 0.24, 0.24), 0.36)
			var cap := _material(Color(0.66, 0.55, 0.32), 0.72)
			for side in [-1, 1]:
				var x := float(side) * 0.019
				_cylinder(root, "Cell", 0.014, 0.061, Vector3(x, 0.032, 0), casing)
				_cylinder(root, "Contact", 0.009, 0.004, Vector3(x, 0.064, 0), cap)
		&"bandage":
			var cloth := _material(Color(0.72, 0.70, 0.62))
			var seam := _material(Color(0.24, 0.33, 0.28))
			_box(root, "WrappedGauze", Vector3(0.105, 0.030, 0.070), Vector3(0, 0.017, 0), cloth)
			_box(root, "PackageStripe", Vector3(0.016, 0.002, 0.071), Vector3(0, 0.033, 0), seam)
		&"flare":
			var body := _material(Color(0.47, 0.11, 0.085))
			var end := _material(Color(0.08, 0.09, 0.10), 0.25)
			var tube := _cylinder(root, "FlareTube", 0.012, 0.16, Vector3(0, 0.017, 0), body)
			tube.rotation.z = PI * 0.5
			var cap := _cylinder(root, "FlareCap", 0.013, 0.018, Vector3(0.087, 0.017, 0), end)
			cap.rotation.z = PI * 0.5
	return root


static func _add_blender_visual(root: Node3D, kind: StringName) -> bool:
	match kind:
		&"battery":
			var first := SupplyModels.make_variant("BatteryCell")
			if first == null: return false
			var second := SupplyModels.make_variant("BatteryCell")
			if second == null:
				first.free()
				return false
			first.position = Vector3(-0.010, 0.0253, 0.0)
			second.position = Vector3(0.010, 0.0253, 0.0)
			root.add_child(first)
			root.add_child(second)
		&"bandage":
			var pack := SupplyModels.make_variant("BandagePack")
			if pack == null: return false
			pack.position.y = 0.0131
			root.add_child(pack)
		&"flare":
			var stick := SupplyModels.make_variant("FlareStick")
			if stick == null: return false
			stick.rotation.z = PI * 0.5
			stick.position.y = 0.014
			root.add_child(stick)
		_:
			return false
	return true


static func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.82
	return material


static func _box(parent: Node3D, name: String, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = position
	parent.add_child(instance)
	return instance


static func _cylinder(parent: Node3D, name: String, radius: float, height: float,
		position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = position
	parent.add_child(instance)
	return instance
