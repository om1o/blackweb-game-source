extends SceneTree
## Collision-backed route tests independent of recovered house assets.
const SpiderNavigation = preload("res://scripts/spider_navigation.gd")

var checks := 0
var failures: Array[String] = []
var world: Node3D
var body: CharacterBody3D

func _initialize() -> void: call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	solid.add_child(collider)
	world.add_child(solid)
	solid.position = at
	return solid

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor := _box(Vector3(14.0, 0.4, 14.0), Vector3(0.0, -0.2, 0.0))
	var partition := _box(Vector3(0.20, 2.4, 2.6), Vector3(0.0, 1.2, 0.0))
	body = CharacterBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	world.add_child(body)
	body.position = Vector3(-1.6, 0.03, 0.0)
	var destination := Vector3(1.6, 0.03, 0.0)
	var nav = SpiderNavigation.new()
	nav.points = PackedVector3Array([Vector3(-1.0, 0.03, -1.9), Vector3(1.0, 0.03, -1.9)])
	await physics_frame
	await physics_frame
	_check(not nav._clear(body, body.position, destination), "The wall blocks the straight-line shortcut")
	var direction: Vector3 = nav.next_direction(body, destination)
	_check(direction.z < -0.7 and direction.x > 0.0, "The route heads toward the available floor waypoints around the wall")
	var crossed_solid := false
	for step in 160:
		nav.advance(1.0 / 60.0)
		direction = nav.next_direction(body, destination)
		if direction.is_zero_approx(): break
		var next := body.position + direction * 0.08
		if not nav._clear(body, body.position, next):
			crossed_solid = true
			break
		body.position = next
	_check(not crossed_solid and body.position.distance_to(destination) < 0.26,
		"Following the waypoint route reaches the target without a step through the partition")
	body.position = Vector3(-1.6, 0.03, 0.0)
	var detour_door := _box(Vector3(0.20, 2.4, 1.4), Vector3(0.0, 1.2, -1.9))
	await physics_frame
	nav.advance(0.61)
	_check(nav.next_direction(body, destination).is_zero_approx(),
		"A door blocking the only waypoint detour removes the indirect route")
	detour_door.position.y = 5.0
	await physics_frame
	nav.advance(0.61)
	_check(not nav._clear(body, body.position, destination) and nav.next_direction(body, destination).z < -0.7
		and nav._edges.values().has(true),
		"Opening the detour door refreshes a cached graph edge while the direct path stays blocked")
	detour_door.position.y = 1.2
	await physics_frame
	nav.advance(0.61)
	_check(nav.next_direction(body, destination).is_zero_approx(),
		"Closing the detour door clears a cached traversable edge within the refresh interval")
	detour_door.position.y = 5.0

	# A corridor has exactly one door-width connection. Longer endpoints force
	# the route to use cached fixed-waypoint edges across that connection.
	partition.position = Vector3(0.0, 1.2, 5.0)
	_box(Vector3(10.0, 2.4, 0.2), Vector3(0.0, 1.2, -1.0))
	_box(Vector3(10.0, 2.4, 0.2), Vector3(0.0, 1.2, 1.0))
	var door := _box(Vector3(0.20, 2.4, 1.8), Vector3(0.0, 1.2, 0.0))
	body.position = Vector3(-4.0, 0.03, 0.0)
	destination = Vector3(4.0, 0.03, 0.0)
	var corridor = SpiderNavigation.new()
	corridor.points = PackedVector3Array([Vector3(-2.0, 0.03, 0.0), Vector3(-0.8, 0.03, 0.0),
		Vector3(0.8, 0.03, 0.0), Vector3(2.0, 0.03, 0.0)])
	await physics_frame
	await physics_frame
	corridor.advance(0.01)
	_check(corridor.next_direction(body, destination).is_zero_approx(),
		"A closed door rejects the only corridor route")
	_check(not corridor._edges.is_empty(), "The corridor fixture exercises cached fixed-waypoint edges")
	door.position.y = 5.0
	await physics_frame
	corridor.advance(0.61)
	_check(corridor.next_direction(body, destination).x > 0.9,
		"Opening the door restores a route after the 0.6-second cache refresh")
	door.position.y = 1.2
	await physics_frame
	corridor.advance(0.61)
	_check(corridor.next_direction(body, destination).is_zero_approx(),
		"Closing the door invalidates a previously traversable corridor route")

	body.position = Vector3(0.0, 0.03, 0.0)
	_check(not corridor._clear(body, body.position, Vector3(0.8, 0.03, 0.0)),
		"A sweep starting inside the closed door is rejected")
	_check(corridor.next_direction(body, destination).is_zero_approx(),
		"A body overlapping a solid cannot plan an escape through that solid")
	door.position.y = 5.0
	floor.position.y = -5.0
	body.position = Vector3(-2.0, 0.03, 0.0)
	await physics_frame
	await physics_frame
	corridor.advance(0.61)
	_check(not corridor._clear(body, body.position, Vector3(-1.0, 0.03, 0.0)),
		"A clear horizontal sweep without floor support is rejected")
	_check(corridor.next_direction(body, destination).is_zero_approx(),
		"Waypoints cannot create a walkable route across unsupported void")
	world.queue_free()
	await process_frame
	print(JSON.stringify({"suite": "spider navigation", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
