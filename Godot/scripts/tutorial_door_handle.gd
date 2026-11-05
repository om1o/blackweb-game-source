class_name BlackwebTutorialDoorHandle
extends BlackwebInteraction

var door

func _ready() -> void:
	kind = &"tutorial_door"
	super._ready()
	var trigger := get_child(0) as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 1.65, 0.42)
	trigger.shape = box

func prompt() -> String:
	if not is_instance_valid(door): return ""
	if door.locked: return "E   ·   Inspect vault lock"
	return "E   ·   %s %s" % ["Close" if door.opened else "Open", door.door_label]

func interact() -> void:
	if is_instance_valid(door): door.toggle()
