extends RefCounted
## Small authored waypoint graph for the five-room house. Every edge is checked
## against current world collision, so a closing door invalidates the next route.
## Physics movement still owns the body; this never teleports or opens doors.

var points: PackedVector3Array = []
var _shape := CapsuleShape3D.new()
var _edges: Dictionary = {}
var _cache_remaining := 0.0

func _init() -> void:
	_shape.radius = 0.32
	_shape.height = 0.64

func advance(delta: float) -> void:
	_cache_remaining -= delta
	if _cache_remaining <= 0.0:
		_edges.clear()
		_cache_remaining = 0.6

func next_direction(body: CharacterBody3D, destination: Vector3) -> Vector3:
	var start := body.global_position
	var direct := destination - start
	direct.y = 0.0
	if direct.length() < 0.25: return Vector3.ZERO
	if _clear(body, start, destination): return direct.normalized()
	if points.is_empty(): return Vector3.ZERO
	var nodes := PackedVector3Array([start, destination])
	nodes.append_array(points)
	var distances: Dictionary = {0: 0.0}
	var previous: Dictionary = {}
	var open: Array[int] = [0]
	var closed: Dictionary = {}
	while not open.is_empty():
		var current := open[0]
		for candidate in open:
			if float(distances[candidate]) < float(distances[current]): current = candidate
		open.erase(current)
		if current == 1:
			var step := 1
			while int(previous.get(step, 0)) != 0: step = int(previous[step])
			var direction := nodes[step] - start
			direction.y = 0.0
			return direction.normalized()
		closed[current] = true
		for next in range(nodes.size()):
			if next == current or closed.has(next): continue
			var distance := nodes[current].distance_to(nodes[next])
			if distance > 3.2: continue
			var key := Vector2i(mini(current, next), maxi(current, next))
			var clear: bool
			# Player/body endpoints move; only fixed waypoint edges can be cached.
			if current >= 2 and next >= 2 and _edges.has(key):
				clear = bool(_edges[key])
			else:
				clear = _clear(body, nodes[current], nodes[next])
				if current >= 2 and next >= 2: _edges[key] = clear
			if not clear: continue
			var cost := float(distances[current]) + distance
			if cost < float(distances.get(next, INF)):
				distances[next] = cost
				previous[next] = current
				if next not in open: open.append(next)
	return Vector3.ZERO

func _clear(body: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * 0.34)
	query.motion = to - from
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
	if not space.intersect_shape(query, 1).is_empty(): return false
	var fractions := space.cast_motion(query)
	if fractions.is_empty() or fractions[0] < 0.99: return false
	var samples := maxi(1, ceili(from.distance_to(to) / 0.8))
	for sample in range(1, samples + 1):
		var point := from.lerp(to, float(sample) / samples)
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.18, point - Vector3.UP * 0.3, 1)
		var floor_hit := space.intersect_ray(ray)
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).dot(Vector3.UP) < 0.75: return false
	return true
