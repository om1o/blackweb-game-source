class_name BlackwebCombatEffects
extends Node3D
## Shared per-world pool: four 16-particle emitters and eight reusable floor marks.
## No lights, shadows or unbounded transient node allocation.
const SLOT_COUNT := 4
const PARTICLES_PER_BURST := 16
const BURST_LIFETIME := 0.48
const RATE := 22050
var _slots: Array[Dictionary] = []
var _streams: Dictionary = {}
var emitted_count := 0
var _marks: Array[MeshInstance3D] = []
var _mark_index := 0

static func for_source(source: Node3D) -> BlackwebCombatEffects:
	var world := source.get_parent()
	var existing := world.get_node_or_null("BlackwebCombatEffects") as BlackwebCombatEffects
	if existing != null: return existing
	var pool: BlackwebCombatEffects = load("res://scripts/combat_effects.gd").new()
	pool.name = "BlackwebCombatEffects"
	world.add_child(pool)
	return pool

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mesh := SphereMesh.new()
	mesh.radius = .019
	mesh.height = .038
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = .26
	material.emission_enabled = false
	mesh.material = material
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	for index in SLOT_COUNT:
		var particles := CPUParticles3D.new()
		particles.name = "ContactBurst%d" % index
		particles.emitting = false
		particles.one_shot = true
		particles.amount = PARTICLES_PER_BURST
		particles.lifetime = BURST_LIFETIME
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.mesh = mesh
		particles.color_ramp = fade
		particles.gravity = Vector3(0.0, -4.8, 0.0)
		particles.spread = 38.0
		particles.initial_velocity_min = 0.65
		particles.initial_velocity_max = 1.45
		particles.scale_amount_min = 0.45
		particles.scale_amount_max = 1.0
		particles.fixed_fps = 30
		particles.visibility_aabb = AABB(Vector3(-0.6, -0.4, -0.6), Vector3(1.2, 1.2, 1.2))
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.hide()
		add_child(particles)
		var audio := AudioStreamPlayer3D.new()
		audio.name = "ContactTransient%d" % index
		audio.max_polyphony = 1
		audio.max_distance = 8.0
		audio.unit_size = 1.0
		add_child(audio)
		_slots.append({"particles": particles, "audio": audio, "remaining": 0.0, "owner": 0, "kind": &""})
	for kind in [&"hit", &"death", &"contact"]: _streams[kind] = _make_transient(kind)
	var mark_mesh := CylinderMesh.new()
	mark_mesh.top_radius = .12
	mark_mesh.bottom_radius = .12
	mark_mesh.height = .001
	mark_mesh.radial_segments = 10
	mark_mesh.rings = 1
	for i in 8:
		var mark := MeshInstance3D.new()
		mark.mesh = mark_mesh
		var wet := StandardMaterial3D.new()
		wet.albedo_color = Color(.055,.047,.024)
		wet.roughness = .18
		mark.material_override = wet
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.hide()
		add_child(mark)
		_marks.append(mark)
	set_physics_process(false)

func burst(source: Node3D, at: Vector3, normal: Vector3, kind: StringName = &"hit", size := 1.0) -> void:
	if get_tree().paused or not is_instance_valid(source) or not at.is_finite(): return
	var slot_index := 0
	for index in _slots.size():
		if float(_slots[index].remaining) <= 0.0:
			slot_index = index
			break
		if float(_slots[index].remaining) < float(_slots[slot_index].remaining): slot_index = index
	var slot: Dictionary = _slots[slot_index]
	var particles: CPUParticles3D = slot.particles
	var audio: AudioStreamPlayer3D = slot.audio
	var outward := normal.normalized() if normal.is_finite() and normal.length_squared() > 0.001 else Vector3.UP
	outward.y = maxf(0.4, outward.y)
	particles.global_position = at
	particles.direction = outward.normalized()
	particles.color = Color(.46,.055,.035,.9) if kind == &"contact" else Color(.22,.21,.07,.95)
	if kind == &"silk": particles.color = Color(.72,.75,.64,.8)
	var scale_factor := clampf(size, 0.4, 1.2)
	particles.scale_amount_min = 0.45 * scale_factor
	particles.scale_amount_max = scale_factor
	particles.show()
	particles.restart()
	particles.emitting = true
	audio.global_position = at
	audio.stop()
	audio.stream = _streams.get(kind, _streams[&"hit"])
	audio.volume_db = -14.0 if kind == &"death" else -17.0
	audio.pitch_scale = 1.1 if size < 0.75 else 1.0
	audio.play()
	slot.remaining = BURST_LIFETIME + 0.04
	slot.owner = source.get_instance_id()
	slot.kind = kind
	emitted_count += 1
	if kind != &"silk": _wet_mark(at,kind)
	set_physics_process(true)

func _wet_mark(at: Vector3, kind: StringName) -> void:
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*2.0,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < .6: return
	var mark := _marks[_mark_index]
	_mark_index = (_mark_index+1)%_marks.size()
	mark.global_position = hit.position + hit.normal*.006
	mark.rotation.y = float(emitted_count)*2.39996
	mark.scale = Vector3(1.4 if kind == &"death" else .8,1,.65)
	(mark.material_override as StandardMaterial3D).albedo_color = Color(.16,.018,.012) if kind == &"contact" else Color(.055,.047,.024)
	mark.show()

func cancel_source(source: Node3D) -> void:
	for slot in _slots:
		if int(slot.owner) == source.get_instance_id(): _clear_slot(slot)
	if active_count() == 0: set_physics_process(false)

func clear_all() -> void:
	for slot in _slots: _clear_slot(slot)
	for mark in _marks: mark.hide()
	set_physics_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED: clear_all()

func _physics_process(delta: float) -> void:
	for slot in _slots:
		if float(slot.remaining) <= 0.0: continue
		slot.remaining = maxf(0.0, float(slot.remaining) - delta)
		if float(slot.remaining) <= 0.0 or not is_instance_id_valid(int(slot.owner)): _clear_slot(slot)
	if active_count() == 0: set_physics_process(false)

func active_count() -> int:
	var count := 0
	for slot in _slots:
		if float(slot.remaining) > 0.0: count += 1
	return count

func _clear_slot(slot: Dictionary) -> void:
	slot.remaining = 0.0
	slot.owner = 0
	var particles: CPUParticles3D = slot.particles
	particles.emitting = false
	particles.hide()
	(slot.audio as AudioStreamPlayer3D).stop()

func _make_transient(kind: StringName) -> AudioStreamWAV:
	var duration := 0.18 if kind == &"death" else 0.085
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 7261 + int(kind.hash() % 999)
	var low := 0.0
	for index in count:
		var t := float(index) / RATE
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.22)
		var envelope := exp(-32.0 * t) * minf(1.0, t * 2200.0)
		if kind == &"death": envelope *= 0.5 + 0.5 * pow(sin(t * 115.0), 2.0)
		var sample := (low * 0.45 + (noise - low) * 0.22) * envelope
		data.encode_s16(index * 2, int(clampf(sample, -0.8, 0.8) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
