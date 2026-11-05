extends SceneTree
## Read-only scene census and narrow-phase query probe; no renderer FPS claims.

const ROOMS := {
	"entry": AABB(Vector3(-5.6, 0.3, -4.25), Vector3(4.9, 3.1, 8.5)),
	"record": AABB(Vector3(-0.7, 0.3, 0.1), Vector3(4.0, 3.1, 4.15)),
	"vault": AABB(Vector3(3.3, 0.3, 0.1), Vector3(4.5, 3.1, 4.15)),
	"supply": AABB(Vector3(-0.7, 0.3, -4.25), Vector3(4.0, 3.1, 4.35)),
	"infested": AABB(Vector3(3.3, 0.3, -4.25), Vector3(4.5, 3.1, 4.35))
}
const POINTS := {"entry": Vector3(-2.2, 0.425, 0.0), "record": Vector3(1.2, 0.425, 1.8), "vault": Vector3(5.4, 0.425, 1.8), "supply": Vector3(1.4, 0.425, -1.6), "infested": Vector3(5.4, 0.425, -1.6)}
var game: Node3D
var report := {"kind": "static collision census and headless query probe", "shapes": [], "rooms": {}, "query_cost": {}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	if not game._loaded:
		printerr("Scene load failed")
		quit(1)
		return
	game._resume()
	for door in game._tutorial_doors: door.toggle()
	await create_timer(0.8).timeout
	var resources: Dictionary = {}
	var totals := {"shapes": 0, "concave_shapes": 0, "triangle_instances": 0, "unique_triangle_resources": 0, "unique_triangles": 0, "types": {}}
	for room in ROOMS: report.rooms[room] = {"overlapping_shapes": 0, "triangle_instances": 0, "within_2m_shapes": 0, "within_2m_triangles": 0}
	for node in game.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as CollisionObject3D
		if body == null or body.collision_layer & 1 == 0 or collision.disabled or collision.shape == null: continue
		var shape: Shape3D = collision.shape
		var kind := shape.get_class()
		var bounds := _local_bounds(shape)
		var world: AABB = collision.global_transform * bounds
		var triangles: int = shape.get_faces().size() / 3 if shape is ConcavePolygonShape3D else 0
		var ancestor: Node = body
		var source := ""
		while ancestor != null and ancestor != game:
			if ancestor.has_meta("ue_mesh_path"):
				source = str(ancestor.get_meta("ue_mesh_path"))
				break
			if not ancestor.scene_file_path.is_empty(): source = ancestor.scene_file_path
			ancestor = ancestor.get_parent()
		totals.shapes += 1
		totals.triangle_instances += triangles
		totals.types[kind] = int(totals.types.get(kind, 0)) + 1
		if triangles > 0:
			totals.concave_shapes += 1
			if not resources.has(shape.get_instance_id()):
				resources[shape.get_instance_id()] = true
				totals.unique_triangle_resources += 1
				totals.unique_triangles += triangles
		var overlapping: Array = []
		for room in ROOMS:
			if world.grow(0.02).intersects(ROOMS[room]):
				overlapping.append(room)
				report.rooms[room].overlapping_shapes += 1
				report.rooms[room].triangle_instances += triangles
			var near := AABB(POINTS[room] - Vector3(2.0, 0.1, 2.0), Vector3(4.0, 2.1, 4.0))
			if world.grow(0.02).intersects(near):
				report.rooms[room].within_2m_shapes += 1
				report.rooms[room].within_2m_triangles += triangles
		report.shapes.append({"path": str(collision.get_path()), "body_class": body.get_class(), "shape_class": kind,
			"source": source, "triangles": triangles, "resource_path": shape.resource_path,
			"bounds_min": _vec(world.position), "bounds_max": _vec(world.end), "rooms": overlapping})
	report.totals = totals
	var space := game.player.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = game.player._standing_capsule.duplicate()
	capsule.collision_mask = 1
	for room in POINTS:
		var feet: Vector3 = POINTS[room]
		var rays: Array = []
		var sweeps: Array = []
		var overlaps: Array = []
		for index in 220:
			var angle := float(index % 8) * TAU / 8.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			capsule.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.875)
			capsule.motion = direction * 0.4
			var begin := Time.get_ticks_usec()
			space.cast_motion(capsule)
			var duration := Time.get_ticks_usec() - begin
			if index >= 20: sweeps.append(duration)
			capsule.motion = Vector3.ZERO
			begin = Time.get_ticks_usec()
			space.intersect_shape(capsule, 8)
			duration = Time.get_ticks_usec() - begin
			if index >= 20: overlaps.append(duration)
			var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.2, feet + Vector3.UP * 1.2 + direction * 4.8, 1)
			begin = Time.get_ticks_usec()
			space.intersect_ray(ray)
			duration = Time.get_ticks_usec() - begin
			if index >= 20: rays.append(duration)
		report.query_cost[room] = {"standing_sweep_usec": _stats(sweeps), "standing_overlap_usec": _stats(overlaps), "focus_ray_usec": _stats(rays)}
	report.context = {"utc": Time.get_datetime_string_from_system(true), "engine": Engine.get_version_info().string,
		"headless": DisplayServer.get_name() == "headless", "base_commit": "fc7a2bc06747978261610d88f8a066707159b989",
		"main_sha256": FileAccess.get_sha256("res://scripts/main.gd"), "player_sha256": FileAccess.get_sha256("res://scripts/player.gd"),
		"limits": "One static scene/point per room with 8 query directions. Headless synchronous query costs exclude AI, movement integration, animation and rendering; this is attribution evidence, not a frame-time benchmark. Bounds counts approximate broad-phase overlap, not engine candidate counts."}
	var output := "D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/vault-collision-audit.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VAULT_COLLISION_AUDIT ", JSON.stringify({"totals": totals, "rooms": report.rooms, "query_cost": report.query_cost, "output": output}))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0)

func _local_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D: return AABB(-shape.size * 0.5, shape.size)
	if shape is SphereShape3D: return AABB(Vector3.ONE * -shape.radius, Vector3.ONE * shape.radius * 2.0)
	if shape is CapsuleShape3D or shape is CylinderShape3D:
		var size := Vector3(shape.radius * 2.0, shape.height, shape.radius * 2.0)
		return AABB(-size * 0.5, size)
	var points: PackedVector3Array = shape.get_faces() if shape is ConcavePolygonShape3D else shape.points if shape is ConvexPolygonShape3D else PackedVector3Array()
	if points.is_empty(): return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points: result = result.expand(point)
	return result

func _stats(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values: total += float(value)
	return {"samples": values.size(), "mean": total / values.size(), "p50": values[ceili(values.size() * 0.5) - 1], "p95": values[ceili(values.size() * 0.95) - 1], "max": values.back()}

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)
