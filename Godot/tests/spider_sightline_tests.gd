extends SceneTree
## Verifies the introductory visible juvenile is actually visible through the
## open supply-room door at floor level, not hidden by recovered furniture.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		push_error("Tutorial house failed to load")
		quit(1)
		return
	game._resume()
	var door: Node3D = game.get_node("SouthEntryDoor")
	door.toggle()
	await create_timer(0.75).timeout
	var sighting: Node3D = game._sighting_spider
	_check(sighting.visible and sighting.global_position.z > -2.0,
		"The first spider sits in front of the sofa before the encounter")
	var main_ray := PhysicsRayQueryParameters3D.create(Vector3(-1.35, 1.35, -2.0), sighting.global_position + Vector3(0, 0.24, 0), 1)
	var main_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(main_ray)
	_check(main_hit.is_empty(), "Visible juvenile is unobstructed from open supply doorway")
	var combat_juvenile: Node3D = game.get_node("MiniSpider1")
	_check(combat_juvenile.global_position.distance_to(sighting.global_position) < 0.05,
		"First combat juvenile emerges from the same unobstructed supply-room spot")
	print("SPIDER_SIGHTLINE ", checks, " checks, ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
