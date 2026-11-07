class_name BlackwebMiniSpider
extends CharacterBody3D

## Small spider threat with a skinned, animated visual and simple collision.
## The licensed Literock mesh is packaged with the game but omitted from Git.
## The CC0 model remains a source-checkout fallback.
const Progression = preload("res://scripts/progression.gd")
const CombatEffects = preload("res://scripts/combat_effects.gd")
const Presentation = preload("res://scripts/spider_presentation.gd")
const LITEROCK_VISUAL_PATH := "res://assets/third_party/literock/Giant_Spider_Lite_1K.glb"
const FALLBACK_VISUAL_PATH := "res://assets/third_party/poly_pizza/quaternius_spider/quaternius_spider.glb"

signal health_changed(current: float, maximum: float)
signal combat_state_changed(next: int)
signal bite_resolved(hit: bool)
signal died

enum CombatState { DORMANT, WAITING, PURSUING, WINDUP, RECOVERY, STAGGERED, DEAD }

@export var target: Node3D
@export var progression: Progression
@export var auto_bind_progression := true
@export var walk_speed := 1.35
@export var hit_damage := 6.0
@export var max_health := 12.0
@export var armor := 0.0
@export var awareness_radius := 8.0
@export var bite_windup_seconds := 0.28
@export var bite_reach := 0.52
@export_range(0.0, 180.0) var bite_half_angle_degrees := 55.0
@export var attack_cooldown_seconds := 1.6
@export var bite_recovery_seconds := 0.50
@export var hit_stagger_seconds := 0.22
@export var corpse_hold_seconds := 1.50
@export_range(1.0, 2.0) var visual_size := 1.60

var health := 12.0
var active := false
var combat_state: CombatState = CombatState.DORMANT
var light_slow_remaining := 0.0
var light_speed_factor := 1.0
var _attack_cooldown := 0.0
var _bite_windup_remaining := 0.0
var _bite_direction := Vector3.FORWARD
var _stagger_remaining := 0.0
var _body_visual: MeshInstance3D
var _bite_audio: AudioStreamPlayer3D
var _visual_root: Node3D
var _visual_rest_scale := Vector3.ONE
var _visual_rest_position := Vector3.ZERO
var _visual_rest_rotation := Vector3.ZERO
var _visual_is_literock := false
var _visual_animation: AnimationPlayer
var _visual_clips: Dictionary = {}
var _death_remaining := 0.0
var _spawn_transform := Transform3D.IDENTITY
var _combat_effects: CombatEffects
var _hurt_skeleton: Skeleton3D
var _hurt_bones: Dictionary = {}
var _contact_distance := 0.0
var _contact_cooldown := 0.0
var _contact_index := 0

func _ready() -> void:
	_spawn_transform = global_transform
	add_to_group("mini_spider")
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 0.12
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.13 * visual_size
	capsule.height = 0.27 * visual_size
	collision.shape = capsule
	collision.position.y = 0.135 * visual_size
	add_child(collision)
	_create_visual()
	_hurt_skeleton = find_child("*Skeleton3D*", true, false) as Skeleton3D
	if _visual_is_literock and is_instance_valid(_hurt_skeleton):
		for bone_name in ["head", "abdomen_01", "abdomen_02"]:
			_hurt_bones[bone_name] = _hurt_skeleton.find_bone(bone_name)
	call_deferred("_prepare_combat_effects")
	_bite_audio = AudioStreamPlayer3D.new()
	_bite_audio.name = "JuvenileBiteCue"
	_bite_audio.volume_db = -17.0
	_bite_audio.unit_size = 2.3
	_bite_audio.max_distance = 8.0
	_bite_audio.stream = _make_bite_cue()
	add_child(_bite_audio)
	deactivate()
	if auto_bind_progression:
		if not is_instance_valid(progression): progression = get_tree().get_first_node_in_group("progression") as Progression
		if is_instance_valid(progression):
			progression.stage_changed.connect(_on_stage_changed)
			call_deferred("_sync_stage")

func _create_visual() -> void:
	for path in [LITEROCK_VISUAL_PATH, FALLBACK_VISUAL_PATH]:
		if not ResourceLoader.exists(path): continue
		var source := load(path) as PackedScene
		if source != null:
			var animated := source.instantiate() as Node3D
			if animated != null:
				animated.name = "JuvenileAnimatedSpider"
				_visual_is_literock = path == LITEROCK_VISUAL_PATH
				# A 1.06 m juvenile leg span is readable against the dressed floor.
				# Scale only the visual; physics keeps explicit metre dimensions.
				animated.scale = Vector3.ONE * (0.30 if _visual_is_literock else 0.055) * visual_size
				animated.position.y = (0.015 if _visual_is_literock else 0.11) * visual_size
				# This rig's rest head/fangs point +Z; locomotion and committed
				# attacks use actor-forward -Z. Keep the correction on this visual
				# only, before capturing the pose restored by hit/death/reset code.
				if _visual_is_literock: animated.rotation.y = PI
				add_child(animated)
				Presentation.prepare(animated)
				_visual_root = animated
				_visual_rest_scale = animated.scale
				_visual_rest_position = animated.position
				_visual_rest_rotation = animated.rotation
				_visual_animation = animated.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
				if _visual_animation != null:
					for clip in _visual_animation.get_animation_list():
						var name := str(clip).to_lower()
						if name == "bite": _visual_clips["attack"] = clip
						elif name == "run": _visual_clips["run"] = clip
						elif name == "walk": _visual_clips["walk"] = clip
						elif name == "idle": _visual_clips["idle"] = clip
						else:
							for kind in ["attack", "death", "idle", "jump", "walk"]:
								if name.contains("_" + kind): _visual_clips[kind] = clip
					_play_visual("idle")
				return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.10, 0.095)
	material.roughness = 0.92
	var body := SphereMesh.new()
	body.radius = 0.16
	body.height = 0.24
	body.radial_segments = 8
	body.rings = 4
	var body_instance := MeshInstance3D.new()
	body_instance.name = "MiniBody"
	body_instance.mesh = body
	body_instance.material_override = material
	body_instance.scale = Vector3.ONE * visual_size
	body_instance.position.y = 0.16 * visual_size
	add_child(body_instance)
	_body_visual = body_instance
	var leg := BoxMesh.new()
	leg.size = Vector3(0.025, 0.025, 0.29)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = leg
	multi.instance_count = 8
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var offset := Vector3(sin(angle), 0.0, cos(angle)) * 0.18
		multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), offset + Vector3.UP * 0.12))
	var legs := MultiMeshInstance3D.new()
	legs.name = "EightLegs"
	legs.multimesh = multi
	legs.material_override = material
	legs.scale = Vector3.ONE * visual_size
	add_child(legs)
	_visual_root = body_instance
	_visual_rest_scale = body_instance.scale
	_visual_rest_position = body_instance.position
	_visual_rest_rotation = body_instance.rotation

func _play_visual(kind: String) -> void:
	if not is_instance_valid(_visual_animation): return
	var clip: StringName = _visual_clips.get(kind, &"")
	if clip.is_empty() or not _visual_animation.has_animation(clip): return
	# Literock's 1 s Bite finishes in ~0.435 s at this speed. The 0.28 s
	# gameplay impact falls during fang closure; recovery preserves its ending.
	_visual_animation.speed_scale = 2.3 if _visual_is_literock and kind == "attack" else 1.0
	if _visual_animation.current_animation != clip or not _visual_animation.is_playing():
		_visual_animation.play(clip, 0.08)

func _set_combat_state(value: CombatState) -> void:
	if combat_state == value: return
	combat_state = value
	combat_state_changed.emit(value)

func _sync_stage() -> void:
	if is_instance_valid(progression): _on_stage_changed(progression.stage)

func _on_stage_changed(stage: int) -> void:
	if stage == Progression.Stage.ENCOUNTER:
		global_transform = _spawn_transform
		activate(target)
	else: deactivate()

func activate(player: Node3D = null) -> void:
	if is_instance_valid(player): target = player
	if not is_instance_valid(target): target = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(target): return
	if is_instance_valid(_combat_effects): _combat_effects.cancel_source(self)
	velocity = Vector3.ZERO
	health = maxf(1.0, max_health)
	light_slow_remaining = 0.0
	light_speed_factor = 1.0
	_attack_cooldown = 0.0
	_contact_distance = 0.0
	_contact_cooldown = 0.0
	_bite_windup_remaining = 0.0
	_stagger_remaining = 0.0
	_death_remaining = 0.0
	active = true
	collision_layer = 4
	collision_mask = 3
	show()
	_restore_visual_pose()
	if is_instance_valid(_bite_audio):
		_bite_audio.pitch_scale = 0.86
		_bite_audio.play() # One spatial dry contact identifies the arrival direction.
	if is_instance_valid(_visual_animation): _visual_animation.stop()
	_set_combat_state(CombatState.WAITING)
	health_changed.emit(health, max_health)
	_play_visual("idle")
	set_physics_process(true)

func deactivate() -> void:
	if is_instance_valid(_combat_effects): _combat_effects.cancel_source(self)
	active = false
	velocity = Vector3.ZERO
	_bite_windup_remaining = 0.0
	_stagger_remaining = 0.0
	_death_remaining = 0.0
	_set_combat_state(CombatState.DORMANT)
	_restore_visual_pose()
	if is_instance_valid(_visual_animation): _visual_animation.pause()
	if is_instance_valid(_bite_audio): _bite_audio.stop()
	collision_layer = 0
	collision_mask = 0
	hide()
	set_physics_process(false)

func _restore_visual_pose() -> void:
	if is_instance_valid(_visual_root):
		_visual_root.scale = _visual_rest_scale
		_visual_root.position = _visual_rest_position
		_visual_root.rotation = _visual_rest_rotation

func _physics_process(delta: float) -> void:
	if _death_remaining > 0.0:
		_death_remaining -= delta
		_move_grounded(Vector3.ZERO, delta)
		if is_instance_valid(_visual_root) and not _visual_clips.has("death"):
			var fall := clampf((maxf(0.65, corpse_hold_seconds) - _death_remaining) / 0.65, 0.0, 1.0)
			_visual_root.rotation.z = _visual_rest_rotation.z + 0.40 * fall
			_visual_root.position.y = _visual_rest_position.y - 0.07 * fall
		if _death_remaining <= 0.0: deactivate()
		return
	if not active: return
	light_slow_remaining = maxf(0.0, light_slow_remaining - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _stagger_remaining > 0.0:
		_stagger_remaining = maxf(0.0, _stagger_remaining - delta)
		_set_combat_state(CombatState.STAGGERED)
		_move_grounded(Vector3.ZERO, delta)
		if is_instance_valid(_visual_root):
			var recoil := sin(PI * _stagger_remaining / maxf(0.01, hit_stagger_seconds))
			_visual_root.rotation.x = _visual_rest_rotation.x - 0.13 * recoil
			_visual_root.position.y = _visual_rest_position.y + 0.025 * recoil
		if _stagger_remaining <= 0.0: _restore_visual_pose()
		return
	if _bite_windup_remaining > 0.0:
		_set_combat_state(CombatState.WINDUP)
		_bite_windup_remaining = maxf(0.0, _bite_windup_remaining - delta)
		var phase := 1.0 - _bite_windup_remaining / maxf(.01,bite_windup_seconds)
		# A committed forward dart, followed by fang contact. Physics resolves
		# the motion so a closing door or sidestep can still defeat the attack.
		_move_grounded(_bite_direction * (1.65 if phase > .48 else 0.0), delta)
		if is_instance_valid(_visual_root):
			_visual_root.position.y = _visual_rest_position.y + sin(phase*PI)*.065
			_visual_root.rotation.x = _visual_rest_rotation.x - sin(phase*PI)*.22
		if _bite_windup_remaining <= 0.0:
			_attack_cooldown = maxf(attack_cooldown_seconds, bite_recovery_seconds)
			var hit := _can_bite_target(bite_reach) and _inside_committed_bite()
			if hit and target.has_method("take_damage"):
				var before_health: Variant = target.get("health")
				target.call("take_damage", hit_damage)
				var after_health: Variant = target.get("health")
				if not (before_health is float or before_health is int) or (after_health is float or after_health is int) and float(after_health) < float(before_health):
					_prepare_combat_effects()
					_combat_effects.burst(self, target.global_position + Vector3.UP * 0.14, -_bite_direction, &"contact", 0.55)
			bite_resolved.emit(hit)
			_set_combat_state(CombatState.RECOVERY)
		return
	# Let the authored Bite finish and leave a punishable pause. Do not restart
	# the clip every frame or replace it with Walk immediately after impact.
	if _attack_cooldown > maxf(0.0, attack_cooldown_seconds - bite_recovery_seconds):
		_set_combat_state(CombatState.RECOVERY)
		_restore_visual_pose()
		_move_grounded(Vector3.ZERO, delta)
		return
	if not _target_can_fight():
		_set_combat_state(CombatState.WAITING)
		_move_grounded(Vector3.ZERO, delta)
		_play_visual("idle")
		return
	var toward := target.global_position - global_position
	toward.y = 0.0
	var factor := light_speed_factor if light_slow_remaining > 0.0 else 1.0
	# A juvenile only pursues a visible target. Directly chasing through a room
	# partition made it grind into the wall/furniture corner every physics tick.
	# Keep gravity and collision running while it waits; an opening door or a
	# player crossing its sightline immediately permits normal pursuit again.
	var desired := toward.normalized() * walk_speed * factor if toward.length() < awareness_radius and _can_see_target() else Vector3.ZERO
	if desired.length_squared() > 0.001: rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, delta * 7.0))
	_move_grounded(desired, delta)
	_set_combat_state(CombatState.PURSUING if desired.length_squared() > 0.001 else CombatState.WAITING)
	var actual_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_play_visual("walk" if actual_speed > 0.08 else "idle")
	if actual_speed > 0.08 and is_instance_valid(_visual_animation):
		_visual_animation.speed_scale = clampf(actual_speed / maxf(0.1, walk_speed * visual_size), 0.35, 1.25)
	if _attack_cooldown <= 0.0 and _can_bite_target(bite_reach + .18):
		_bite_direction = toward.normalized() if toward.length_squared() > 0.001 else -global_basis.z
		rotation.y = atan2(-_bite_direction.x, -_bite_direction.z)
		_bite_windup_remaining = maxf(0.01, bite_windup_seconds)
		_set_combat_state(CombatState.WINDUP)
		# Explicitly restart once per attack, even if a previous clip was paused.
		if is_instance_valid(_visual_animation): _visual_animation.stop()
		_play_visual("attack")
		if is_instance_valid(_bite_audio):
			_bite_audio.pitch_scale = 0.80
			_bite_audio.play()

func _move_grounded(desired: Vector3, delta: float) -> void:
	var before := global_position
	var acceleration := 8.0 if desired.length_squared() < 0.001 else 5.0
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	# Motion-driven contacts stop at closed doors and on corpses; one existing
	# mono voice per juvenile is enough to locate it without an audio pile-up.
	if not active or not is_on_floor() or moved / maxf(delta, 0.001) < 0.12:
		_contact_distance = 0.0
		return
	_contact_distance += minf(moved, 0.20)
	if _contact_distance >= 0.32 and _contact_cooldown <= 0.0 and _bite_windup_remaining <= 0.0:
		_contact_distance = fmod(_contact_distance, 0.32)
		_contact_cooldown = 0.16
		_contact_index += 1
		if is_instance_valid(_bite_audio):
			_bite_audio.pitch_scale = 0.94 if _contact_index % 2 == 0 else 1.06
			_bite_audio.play()

func _inside_committed_bite() -> bool:
	if not is_instance_valid(target): return false
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001: return true
	return _bite_direction.dot(offset.normalized()) >= cos(deg_to_rad(bite_half_angle_degrees))

func _can_see_target() -> bool:
	if not is_instance_valid(target): return false
	var eye := global_position + Vector3.UP * 0.14
	var target_feet := target.global_position + Vector3.UP * 0.14
	var query := PhysicsRayQueryParameters3D.create(eye, target_feet, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _can_bite_target(reach: float) -> bool:
	if not _target_can_fight(): return false
	# Feet-level bite path: use full 3D distance so jumping out of reach works,
	# and check again at impact in case a door closes during the windup.
	var bite_from := global_position + Vector3.UP * 0.14
	var bite_to := target.global_position + Vector3.UP * 0.14
	if bite_from.distance_to(bite_to) > reach: return false
	var query := PhysicsRayQueryParameters3D.create(bite_from, bite_to, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _target_can_fight() -> bool:
	if not is_instance_valid(target): return false
	if target.has_method("is_recovering") and bool(target.call("is_recovering")): return false
	var target_health: Variant = target.get("health")
	if target_health is float or target_health is int:
		return is_finite(float(target_health)) and float(target_health) > 0.0
	return true

func apply_flashlight_beam(intensity: float, _delta: float) -> void:
	if not active or intensity <= 0.0: return
	light_speed_factor = 1.0 - 0.20 * clampf(intensity, 0.0, 1.0)
	light_slow_remaining = 0.42

func is_alive() -> bool:
	return active and health > 0.0

func take_damage(amount: float) -> void:
	receive_hit(amount, global_position + Vector3.UP * 0.16, Vector3.UP)

func receive_hit(amount: float, world_point: Vector3, world_normal: Vector3) -> void:
	if not active or not is_finite(amount) or amount <= 0.0: return
	if get_tree().paused: return
	var received := maxf(0.0, amount - maxf(0.0, armor))
	if received <= 0.0: return
	health = maxf(0.0, health - received)
	health_changed.emit(health, max_health)
	_prepare_combat_effects()
	var point := world_point if world_point.is_finite() else global_position + Vector3.UP * 0.16
	_combat_effects.burst(self, point, world_normal, &"death" if health <= 0.0 else &"hit", 0.55)
	_bite_windup_remaining = 0.0
	_restore_visual_pose()
	if health <= 0.0:
		active = false
		_set_combat_state(CombatState.DEAD)
		collision_layer = 0
		# The corpse no longer blocks the player, but still settles on the floor.
		collision_mask = 1
		velocity = Vector3.ZERO
		_play_visual("death")
		_death_remaining = maxf(0.65, corpse_hold_seconds)
		if is_instance_valid(_visual_animation) and _visual_clips.has("death"):
			_death_remaining = maxf(_death_remaining, _visual_animation.get_animation(_visual_clips["death"]).length)
		elif is_instance_valid(_visual_animation):
			_visual_animation.pause()
		set_physics_process(true)
		died.emit()
	else:
		_stagger_remaining = maxf(0.01, hit_stagger_seconds)
		_attack_cooldown = maxf(_attack_cooldown, attack_cooldown_seconds)
		_set_combat_state(CombatState.STAGGERED)
		_play_visual("idle")

func _prepare_combat_effects() -> void:
	if not is_instance_valid(_combat_effects): _combat_effects = CombatEffects.for_source(self)

func get_hurt_spheres() -> Array[Dictionary]:
	if not is_alive(): return []
	var head := to_global(Vector3(0.0, 0.16, -0.11) * visual_size)
	var abdomen := to_global(Vector3(0.0, 0.163, 0.118) * visual_size)
	if _visual_is_literock and is_instance_valid(_hurt_skeleton):
		var head_bone: int = _hurt_bones.get("head", -1)
		var rear_a: int = _hurt_bones.get("abdomen_01", -1)
		var rear_b: int = _hurt_bones.get("abdomen_02", -1)
		if head_bone >= 0: head = _hurt_skeleton.to_global(_hurt_skeleton.get_bone_global_pose(head_bone).origin)
		if rear_a >= 0 and rear_b >= 0:
			abdomen = _hurt_skeleton.to_global((_hurt_skeleton.get_bone_global_pose(rear_a).origin + _hurt_skeleton.get_bone_global_pose(rear_b).origin) * 0.5)
	var actor_scale := global_basis.get_scale().abs()
	var factor := actor_scale[actor_scale.max_axis_index()] * visual_size
	return [{"center": head, "radius": 0.095 * factor}, {"center": abdomen, "radius": 0.12 * factor}]

func _make_bite_cue() -> AudioStreamWAV:
	var count := 1800
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 9137
	for index in range(count):
		var t := float(index) / 22050.0
		var sample := random.randf_range(-1.0, 1.0) * exp(-85.0 * t) * 0.42
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream
