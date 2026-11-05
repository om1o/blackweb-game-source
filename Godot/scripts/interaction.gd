class_name BlackwebInteraction
extends Area3D

var kind: StringName
var label := ""
var progression: Node
var item_visual: Node3D
var activation_handler: Callable

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.35, 0.4) if kind != &"exit" else Vector3(0.9, 1.6, 0.25)
	shape.shape = box
	add_child(shape)
	progression.inventory_changed.connect(_refresh)
	progression.checkpoint_restored.connect(_refresh)
	_refresh()

func prompt() -> String:
	if kind == &"phone":
		return "E / CLICK   ·   Answer Mica" if progression.can_interact(kind) else ("Mica is speaking…" if progression.stage == progression.Stage.MESSAGE else "E / CLICK   ·   Check phone")
	return "E   ·   " + label

func interact() -> void:
	if activation_handler.is_valid() and progression.can_interact(kind):
		activation_handler.call()
		return
	progression.interact(kind)
	_refresh()

func _refresh() -> void:
	var taken: bool = (kind == &"keys" and progression.has_keys) or (kind == &"flashlight" and progression.has_flashlight)
	if is_instance_valid(item_visual): item_visual.visible = not taken
	collision_layer = 0 if taken else 8
