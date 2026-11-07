class_name BlackwebCombatEffects
extends Node3D
## Shared per-world pool: four 24-particle emitters, four splash cards, eight marks.
## No lights, shadows or unbounded transient node allocation.
const SLOT_COUNT := 4
const PARTICLES_PER_BURST := 24
const BURST_LIFETIME := 0.64
const ART := "res://assets/third_party/opengameart_blood/"
const RATE := 22050
var _slots: Array[Dictionary] = []
var _streams: Dictionary = {}
var emitted_count := 0
var _marks: Array[MeshInstance3D] = []
var _mark_index := 0
var _splash_frames: Array[Texture2D] = []
var _mark_life: Array[float] = []

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
	mesh.radius = .024
	mesh.height = .072
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
	for i in 6: _splash_frames.append(load(ART+"splash_%d.png"%i))
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
		particles.initial_velocity_min = 0.85
		particles.initial_velocity_max = 1.8
		particles.scale_amount_min = 0.45
		particles.scale_amount_max = 1.0
		particles.fixed_fps = 30
		particles.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.hide()
		add_child(particles)
		var audio := AudioStreamPlayer3D.new()
		audio.name = "ContactTransient%d" % index
		audio.max_polyphony = 1
		audio.max_distance = 8.0
		audio.unit_size = 1.0
		add_child(audio)
		var splash := Sprite3D.new()
		splash.name = "AuthoredFluidSplash%d"%index
		splash.texture = _splash_frames[0]
		splash.pixel_size = .0012
		splash.offset = Vector2(0,220)
		splash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		splash.no_depth_test = false
		splash.shaded = true
		splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splash.hide()
		add_child(splash)
		_slots.append({"particles": particles, "audio": audio, "splash":splash, "remaining": 0.0, "owner": 0, "kind": &""})
	for kind in [&"hit", &"death", &"contact"]: _streams[kind] = _make_transient(kind)
	var mark_mesh := QuadMesh.new()
	mark_mesh.size = Vector2(.65,.65)
	for i in 8:
		var mark := MeshInstance3D.new()
		mark.mesh = mark_mesh
		var wet := StandardMaterial3D.new()
		wet.albedo_color = Color(.055,.047,.024)
		wet.albedo_texture = load(ART+"blood_splatter.png")
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet.uv1_scale = Vector3(.5,.5,1)
		wet.uv1_offset = Vector3(float(i%2)*.5,float((i>>1)%2)*.5,0)
		wet.roughness = .18
		mark.material_override = wet
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.hide()
		add_child(mark)
		_marks.append(mark)
		_mark_life.append(0.0)
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
	particles.color = Color(.50,.045,.028,.95) if kind == &"contact" else Color(.30,.035,.022,.95)
	if kind == &"silk": particles.color = Color(.72,.75,.64,.8)
	var scale_factor := clampf(size, 0.4, 1.2)
	particles.scale_amount_min = 0.45 * scale_factor
	particles.scale_amount_max = scale_factor
	particles.show()
	particles.restart()
	particles.emitting = true
	var splash: Sprite3D = slot.splash
	splash.global_position = at
	splash.texture = _splash_frames[0]
	splash.modulate = Color(.65,.32,.22,.82)
	splash.scale = Vector3.ONE*scale_factor*(1.3 if kind==&"death" else 1.0)
	splash.visible = kind!=&"silk"
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
	_mark_life[_mark_index] = 35.0
	_mark_index = (_mark_index+1)%_marks.size()
	mark.global_position = hit.position + hit.normal*.006
	mark.rotation = Vector3(-PI*.5,float(emitted_count)*2.39996,0)
	mark.scale = Vector3.ONE*(1.2 if kind == &"death" else .65)
	(mark.material_override as StandardMaterial3D).albedo_color = Color(.65,.22,.18,.86) if kind == &"contact" else Color(.48,.23,.18,.9)
	mark.show()

func cancel_source(source: Node3D) -> void:
	for slot in _slots:
		if int(slot.owner) == source.get_instance_id(): _clear_slot(slot)
	if active_count() == 0 and not _marks.any(func(mark):return mark.visible): set_physics_process(false)

func clear_all() -> void:
	for slot in _slots: _clear_slot(slot)
	for mark in _marks: mark.hide()
	_mark_life.fill(0.0)
	set_physics_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED: clear_all()

func _physics_process(delta: float) -> void:
	for slot in _slots:
		if float(slot.remaining) <= 0.0: continue
		slot.remaining = maxf(0.0, float(slot.remaining) - delta)
		if float(slot.remaining) <= 0.0 or not is_instance_id_valid(int(slot.owner)): _clear_slot(slot)
		else:
			var age := BURST_LIFETIME+.04-float(slot.remaining)
			var splash: Sprite3D = slot.splash
			splash.visible = slot.kind!=&"silk" and age<.30
			splash.texture = _splash_frames[mini(5,int(age*20.0))]
	for i in _marks.size():
		if _mark_life[i]<=0.0: continue
		_mark_life[i]=maxf(0.0,_mark_life[i]-delta)
		var mat := _marks[i].material_override as StandardMaterial3D
		mat.albedo_color.a=minf(.9,_mark_life[i]/4.0)
		if _mark_life[i]<=0.0: _marks[i].hide()
	if active_count() == 0 and not _marks.any(func(mark):return mark.visible): set_physics_process(false)

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
	(slot.splash as Sprite3D).hide()
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
