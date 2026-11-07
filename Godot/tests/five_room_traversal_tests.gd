extends SceneTree
## Regression for furniture that lets a center ray through a doorway while
## blocking Luke's full standing body. Uses the actual scene collision and rig.

const OFFSETS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var game: Node3D
var cells: Dictionary = {}
var visited: Dictionary = {}
var checks: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "label": label})
	if not passed: failures.append(label)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	_check(game._loaded, "Actual five-room tutorial scene loads")
	if not game._loaded:
		_finish()
		return
	game._resume()
	for door in game._tutorial_doors:
		door.locked = false # Puzzle access is exercised by the escape/journey suites.
		door.toggle()
	await create_timer(0.75).timeout
	for door in game._tutorial_doors:
		_check(door.opened and door._hinge.rotation.y < -1.35, "%s completes its physical opening" % door.name)
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.player._standing_capsule.duplicate()
	query.collision_mask = 1
	var capsule_offset: Vector3 = game.player._capsule_shape.position
	for x in range(68):
		for z in range(39):
			var world_x := -5.0 + x * 0.2
			var world_z := -3.8 + z * 0.2
			# Test horizontal body clearance at the measured common floor height;
			# validate supporting floor independently at every destination.
			var feet := Vector3(world_x, 0.425, world_z)
			query.transform = Transform3D(Basis.IDENTITY, feet + capsule_offset)
			query.motion = Vector3.ZERO
			if space.intersect_shape(query, 1).is_empty(): cells[Vector2i(x, z)] = feet
	var start := _nearest(game.player.global_position)
	query.transform = Transform3D(Basis.IDENTITY, game.player.global_position + capsule_offset)
	query.motion = cells.get(start, Vector3.ZERO) - game.player.global_position
	var spawn_sweep := space.cast_motion(query)
	var connected := not spawn_sweep.is_empty() and spawn_sweep[0] > 0.99 and cells.has(start)
	_check(connected, "Standing player connects from the real spawn to the clearance grid")
	var queue: Array = []
	if connected:
		queue.append(start)
		visited[start] = start
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for offset in OFFSETS:
			var next: Vector2i = cell + offset
			if not cells.has(next) or visited.has(next): continue
			query.transform = Transform3D(Basis.IDENTITY, cells[cell] + capsule_offset)
			query.motion = cells[next] - cells[cell]
			var sweep := space.cast_motion(query)
			if not sweep.is_empty() and sweep[0] > 0.99:
				visited[next] = cell
				queue.append(next)
	for room in [
		{"name": "entry lore", "feet": Vector3(-2.2, 0.425, 0.0)},
		{"name": "record lore", "feet": Vector3(1.2, 0.425, 1.8)},
		{"name": "supply spider", "feet": Vector3(1.4, 0.425, -1.6)},
		{"name": "infested spider", "feet": Vector3(5.4, 0.425, -1.6)},
		{"name": "vault spider", "feet": Vector3(5.4, 0.425, 1.8)},
		{"name": "exit key case", "feet": Vector3(7.1, 0.425, 2.2)},
		{"name": "expanded rear floor", "feet": Vector3(8.1, 0.425, -2.0)}
	]:
		var floor_ray := PhysicsRayQueryParameters3D.create(room.feet + Vector3.UP * 0.1, room.feet + Vector3.DOWN * 0.2, 1)
		var floor_hit := space.intersect_ray(floor_ray)
		_check(not floor_hit.is_empty() and absf(floor_hit.position.y - 0.4) < 0.05, "Recovered floor supports " + room.name)
		_check(_reachable(room.feet, 0.45), "Full standing capsule can traverse from spawn into " + room.name)
	# A path to the room center must not hide a door blocked on one side.
	for door in game._tutorial_doors:
		var west := Vector3(door.global_position.x - 0.6, 0.425, door.global_position.z)
		var east := Vector3(door.global_position.x + 0.6, 0.425, door.global_position.z)
		_check(_reachable(west, 0.45) and _reachable(east, 0.45), "Both sides of %s join the full-body route" % door.name)
	_check_record_table()
	_finish()

func _check_record_table() -> void:
	var house := game.get_node("RecoveredHouse")
	var table: Node3D
	for child in house.get_children():
		if child.has_meta("tutorial_record_table"): table = child
	_check(table != null, "Retained record table is identified for compact-room placement")
	if table == null: return
	var visible_bounds := AABB()
	var first := true
	for mesh in table.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		visible_bounds = bounds if first else visible_bounds.merge(bounds)
		first = false
	_check(not first and visible_bounds.position.x > -0.59 and visible_bounds.end.x < 3.19
		and visible_bounds.position.z > 0.23 and visible_bounds.end.z < 3.70,
		"Record table visual stays entirely between the new room partitions")
	var body := house.get_node_or_null(str(table.name) + "_Collision") as StaticBody3D
	var collision_bounds := AABB()
	first = true
	if body != null:
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			if not shape.shape is ConcavePolygonShape3D: continue
			for vertex in shape.shape.get_faces():
				var point: Vector3 = shape.global_transform * vertex
				collision_bounds = AABB(point, Vector3.ZERO) if first else collision_bounds.expand(point)
				first = false
	_check(not first and collision_bounds.position.distance_to(visible_bounds.position) < 0.01
		and collision_bounds.end.distance_to(visible_bounds.end) < 0.01,
		"Rotated table collision matches the visible table bounds")

func _nearest(point: Vector3) -> Vector2i:
	var best := Vector2i.ZERO
	var distance := INF
	for cell in cells:
		var candidate: float = cells[cell].distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			best = cell
	return best

func _reachable(point: Vector3, distance: float) -> bool:
	for cell in visited:
		if cells[cell].distance_to(point) <= distance: return true
	return false

func _finish() -> void:
	print("FIVE_ROOM_TRAVERSAL ", JSON.stringify({"checks": checks.size(), "failures": failures,
		"results": checks, "walkable_cells": cells.size(), "spawn_connected_cells": visited.size(),
		"method": "0.20 m grid at common floor height, destination floor rays, actual standing-capsule overlap and swept collision tests against the complete house, furniture and opened doors; no scene changes beyond opening the doors"}))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	# AudioServer disposes stopped door playbacks on its mixer cycle.
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _stop_audio(child)
