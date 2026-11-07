class_name BlackwebSmilingSpider
extends CharacterBody3D
signal health_changed(current: float, maximum: float)
signal attack_started(id: String, hint: String)
signal phase_changed(phase: int)
signal defeated
const Motion = preload("res://scripts/boss_animation.gd")
const ContactAudio = preload("res://scripts/spider_audio.gd")
const Effects = preload("res://scripts/combat_effects.gd")
enum State { DORMANT, STALK, ATTACK, DEAD }
var target: Node3D
var state := State.DORMANT
var health := 120.0
var max_health := 120.0
var phase := 1
var attacks: Array = []
var attack: Dictionary = {}
var attack_time := 0.0
var visual: Node3D
var animation: AnimationPlayer
var animation_count := 0
var _cooldown := 2.0
var _sequence := 0
var _hit_tokens: Dictionary = {}
var _locked_direction := Vector3.FORWARD
var _landing := Vector3.ZERO
var _attack_start := Vector3.ZERO
var _previous_contact := Vector3.ZERO
var _cast: ShapeCast3D
var _audio: Node3D
var _effects: Node3D
var _marker: MeshInstance3D
var _pulse: MeshInstance3D
var _bolt: MeshInstance3D
var _bolt_velocity := Vector3.ZERO
var _bolt_life := 0.0
var _pulse_life := 0.0
var _launched := false
var _attack_impacted := false
var _flash_slow := 0.0
var mouth_amount := 0.0
var _skeleton: Skeleton3D
var _jaw := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("spider")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.2
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/smiling_spider_attacks.json"))
	attacks = data.attacks
	max_health = float(data.max_health)
	health = max_health
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.02
	capsule.height = 2.1
	shape.shape = capsule
	shape.position.y = 1.05
	add_child(shape)
	visual = load("res://assets/generated/smiling_spider/smiling_spider.glb").instantiate()
	visual.name = "SmilingSpiderModel"
	add_child(visual)
	_prepare_model_surfaces()
	animation = visual.find_child("*AnimationPlayer*",true,false)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_count = Motion.install(visual, animation, attacks)
	_skeleton = visual.find_child("*Skeleton3D*",true,false)
	if _skeleton: _jaw = _skeleton.find_bone("Jaw")
	_cast = ShapeCast3D.new()
	_cast.shape = SphereShape3D.new()
	_cast.collision_mask = 1 | 2
	_cast.max_results = 8
	_cast.enabled = false
	_cast.top_level = true
	add_child(_cast)
	_audio = ContactAudio.new()
	add_child(_audio)
	call_deferred("_prepare_effects")
	_marker = _ring(Color(0.64, 0.29, 0.17), 1.7)
	_pulse = _ring(Color(0.66, 0.58, 0.43), 1.0)
	_bolt = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	_bolt.mesh = sphere
	_bolt.material_override = _material(Color("d4cbb6"))
	_bolt.top_level = true
	_bolt.visible = false
	add_child(_bolt)

func _prepare_model_surfaces() -> void:
	# Shared small detail normal, no per-frame geometry generation. Large colour
	# variation and hard details are already stored in the actual skinned GLB.
	var noise := FastNoiseLite.new()
	noise.seed = 1204
	noise.frequency = .16
	var pores := NoiseTexture2D.new()
	pores.width = 256
	pores.height = 256
	pores.seamless = true
	pores.as_normal_map = true
	pores.bump_strength = .35
	pores.noise = noise
	for node in visual.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		mesh.custom_aabb = AABB(Vector3(-4,-1,-4),Vector3(8,6,8))
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source: continue
			var material := source.duplicate() as StandardMaterial3D
			if not "eyes" in material.resource_name.to_lower():
				material.normal_enabled = true
				material.normal_texture = pores
				material.normal_scale = .24
				material.uv1_triplanar = true
				material.uv1_scale = Vector3.ONE * 3.0
			mesh.set_surface_override_material(surface,material)

func _prepare_effects() -> void:
	_effects = Effects.for_source(self)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _ring(color: Color, radius: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.035
	torus.outer_radius = radius + 0.035
	torus.rings = 32
	torus.ring_segments = 6
	mesh.mesh = torus
	mesh.material_override = _material(color)
	mesh.top_level = true
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	add_child(mesh)
	return mesh

func begin(player: Node3D) -> void:
	target = player
	health = max_health
	phase = 1
	_sequence = 0
	_clear_attack()
	state = State.STALK
	_cooldown = 2.0
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	health_changed.emit(health, max_health)
	phase_changed.emit(phase)

func stop() -> void:
	_clear_attack()
	state = State.DORMANT
	velocity = Vector3.ZERO
	if animation: animation.play("idle")

func _clear_attack() -> void:
	attack = {}
	attack_time = 0.0
	_hit_tokens.clear()
	_bolt_life = 0.0
	_pulse_life = 0.0
	if _bolt: _bolt.hide()
	if _marker: _marker.hide()
	if _pulse: _pulse.hide()
	if visual: visual.position = Vector3.ZERO

func is_alive() -> bool:
	return state != State.DEAD and health > 0.0

func get_hurt_spheres() -> Array:
	return [{"center": to_global(Vector3(0,1.1,-.35)), "radius": 1.0}, {"center": to_global(Vector3(0,1.5,1.1)), "radius": 1.12}]

func receive_hit(amount: float, point: Vector3, normal: Vector3) -> void:
	if state in [State.DEAD, State.DORMANT]: return
	take_damage(amount)
	if _effects: _effects.burst(self, point, normal, &"hit", 1.2)

func take_damage(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or state in [State.DEAD, State.DORMANT]: return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_clear_attack()
		state = State.DEAD
		velocity = Vector3.ZERO
		animation.play("death",.12)
		defeated.emit()
	elif phase == 1 and health <= max_health * 0.5:
		phase = 2
		phase_changed.emit(phase)

func apply_flashlight_beam(_strength: float, _seconds: float) -> void:
	# A weak starter torch cannot lock the boss out of its attacks.
	_flash_slow = 0.15

func start_attack(id: String) -> bool:
	if state != State.STALK or not is_instance_valid(target): return false
	var chosen: Dictionary = {}
	for entry: Dictionary in attacks:
		if entry.id == id: chosen = entry; break
	if chosen.is_empty(): return false
	attack = chosen
	attack_time = 0.0
	state = State.ATTACK
	_hit_tokens.clear()
	_launched = false
	_attack_impacted = false
	_attack_start = global_position
	var direction := target.global_position - global_position
	direction.y = 0.0
	_locked_direction = direction.normalized() if direction.length() > 0.01 else -global_basis.z
	rotation.y = atan2(-_locked_direction.x, -_locked_direction.z)
	_landing = global_position + _locked_direction * minf(6.0, direction.length())
	_landing.y = 0.04
	_previous_contact = to_global(Vector3(0, 0.8, -1.1))
	if id == "marked_leap":
		_marker.global_position = _landing
		_marker.show()
	animation.play("boss/" + id, 0.1)
	animation.speed_scale = 1.0
	animation.advance(0.0)
	_audio.play_windup()
	attack_started.emit(id, str(chosen.hint))
	return true

func _physics_process(delta: float) -> void:
	if state in [State.DEAD, State.DORMANT]:
		if animation: animation.advance(delta)
		if state == State.DORMANT: _speech_pose()
		return
	if not is_instance_valid(target) or target.is_recovering():
		stop()
		return
	_flash_slow = maxf(0.0, _flash_slow - delta)
	_tick_bolt(delta)
	# Taking damage can synchronously emit player recovery and stop this boss.
	if state in [State.DEAD, State.DORMANT]: return
	_pulse_life = maxf(0.0, _pulse_life - delta)
	_pulse.visible = _pulse_life > 0.0
	if _pulse.visible: _pulse.scale = Vector3.ONE * lerpf(3.8, 0.5, _pulse_life / 0.5)
	velocity = Vector3(0, -1.0, 0)
	if state == State.STALK:
		_cooldown -= delta
		var toward := target.global_position - global_position
		toward.y = 0
		if toward.length() > 2.4:
			var direction := toward.normalized()
			velocity += direction * (0.95 if _flash_slow > 0.0 else 1.2)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 3.0))
		_play_base("walk" if velocity.length_squared() > 1.5 else "idle")
		_speech_pose()
		if _cooldown <= 0.0:
			var order := ["fang_rush", "reaping_sweep", "double_bite", "silk_spit"] if phase == 1 else ["ground_slam", "marked_leap", "silk_spit", "double_bite", "reaping_sweep", "fang_rush"]
			var id: String = order[_sequence % order.size()]
			_sequence += 1
			if toward.length() > 4.0 and id in ["double_bite", "reaping_sweep", "ground_slam"]: id = "silk_spit"
			start_attack(id)
	elif state == State.ATTACK:
		attack_time += delta
		animation.advance(delta)
		var tell := float(attack.tell)
		var active := float(attack.active)
		if attack_time >= tell and not _attack_impacted:
			_audio.play_lunge()
			_attack_impacted = true
		if attack_time >= tell and attack_time < tell + active:
			_active_attack(delta, (attack_time - tell) / active)
			if state != State.ATTACK: return
		if attack_time >= tell + active:
			if attack.id == "marked_leap" and not _hit_tokens.has("landing_done"):
				_hit_tokens["landing_done"] = true
				_radial_hit(1.7, float(attack.damage), "landing", false)
				if state != State.ATTACK: return
				_audio.play_impact()
			_marker.hide()
			visual.position.y = 0.0
		if attack_time >= tell + active + float(attack.recover):
			state = State.STALK
			attack = {}
			_cooldown = 0.8 if phase == 1 else 0.55
	var before_move := global_position
	move_and_slide()
	_audio.advance_motion(global_position.distance_to(before_move), delta, is_on_floor(), state == State.STALK)

func _play_base(clip: String) -> void:
	if animation.current_animation != clip: animation.play(clip, 0.2)
	animation.speed_scale = 1.0
	animation.advance(get_physics_process_delta_time())

func _speech_pose() -> void:
	if _jaw >= 0 and mouth_amount > .01:
		var pose := _skeleton.get_bone_pose_rotation(_jaw)
		_skeleton.set_bone_pose_rotation(_jaw,pose*Quaternion(Vector3.RIGHT,-mouth_amount*.26))

func _active_attack(_delta: float, fraction: float) -> void:
	var damage := float(attack.damage)
	match str(attack.id):
		"fang_rush":
			velocity += _locked_direction * 5.0
			var point := to_global(Vector3(0, 0.8, -1.3))
			_sweep_hit(_previous_contact, point, 0.65, damage, "rush")
			_previous_contact = point
		"reaping_sweep":
			var angle := lerpf(-1.1, 1.1, fraction)
			var point := to_global(Vector3(sin(angle) * 2.5, 1.42, -cos(angle) * 2.5))
			if fraction < 0.08: _previous_contact = point
			if not target.is_crouching(): _sweep_hit(_previous_contact, point, 0.32, damage, "sweep")
			_previous_contact = point
		"double_bite":
			if fraction >= 0.12 and fraction < 0.26: _sweep_hit(to_global(Vector3(0, 0.75, -0.9)), to_global(Vector3(0, 0.75, -2.05)), 0.43, damage, "bite_one")
			elif fraction > 0.72: _sweep_hit(to_global(Vector3(0, 0.75, -0.9)), to_global(Vector3(0, 0.75, -2.05)), 0.43, damage, "bite_two")
		"silk_spit":
			if not _launched and fraction >= 0.45:
				_launched = true
				_bolt.global_position = to_global(Vector3(0, 0.85, -1.4))
				_bolt_velocity = _locked_direction * 7.0
				_bolt_life = 1.8
				_bolt.show()
		"ground_slam":
			if fraction >= 0.45 and not _hit_tokens.has("pulse_done"):
				_hit_tokens["pulse_done"] = true
				_radial_hit(3.8, damage, "slam", true)
				if state != State.ATTACK: return
				_pulse.global_position = global_position + Vector3.UP * 0.06
				_pulse_life = 0.5
				_audio.play_impact()
		"marked_leap":
			velocity += (_landing - _attack_start) / float(attack.active)
			visual.position.y = sin(fraction * PI) * 1.5

func _line_clear(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _sweep_hit(from: Vector3, to: Vector3, radius: float, damage: float, token: String) -> bool:
	if _hit_tokens.has(token) or state != State.ATTACK or not is_instance_valid(target): return false
	_cast.shape.radius = radius
	_cast.global_position = from
	_cast.global_basis = Basis.IDENTITY
	_cast.target_position = to - from
	_cast.force_shapecast_update()
	for index in _cast.get_collision_count():
		if _cast.get_collider(index) == target and _line_clear(from, target.global_position + Vector3.UP * 0.7):
			_hit_tokens[token] = true
			target.take_damage(damage)
			return true
	return false

func _radial_hit(radius: float, damage: float, token: String, can_jump: bool) -> bool:
	if _hit_tokens.has(token) or not is_instance_valid(target): return false
	if can_jump and target.global_position.y - global_position.y > 0.52: return false
	if target.global_position.distance_to(global_position) > radius + 0.3: return false
	if not _line_clear(global_position + Vector3.UP * 0.7, target.global_position + Vector3.UP * 0.7): return false
	_hit_tokens[token] = true
	target.take_damage(damage)
	return true

func _tick_bolt(delta: float) -> void:
	if _bolt_life <= 0.0: return
	_bolt_life -= delta
	var from := _bolt.global_position
	var to := from + _bolt_velocity * delta
	_cast.shape.radius = 0.19
	_cast.global_position = from
	_cast.global_basis = Basis.IDENTITY
	_cast.target_position = to - from
	_cast.force_shapecast_update()
	if _cast.get_collision_count() > 0:
		if _line_clear(from, target.global_position + Vector3.UP * 0.7):
			for index in _cast.get_collision_count():
				if _cast.get_collider(index) == target:
					target.take_damage(6.0)
					if target.has_method("apply_web_slow"): target.apply_web_slow(1.6)
		_bolt_life = 0.0
	_bolt.global_position = to
	_bolt.visible = _bolt_life > 0.0
