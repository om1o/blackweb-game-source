class_name BlackwebSpider
extends CharacterBody3D
## Floor-bound encounter with local obstacle steering. Live movement never teleports.

signal state_changed(new_state: int)
signal threatened_player(player: Node3D)

enum State { DORMANT, ANTICIPATION, STALKING, WINDUP, LUNGING, RETREATING, COOLDOWN, RESOLVED }
const Progression = preload("res://scripts/progression.gd")
const ContactAudio = preload("res://scripts/spider_audio.gd")

@export var target: Node3D
@export var progression: Progression
@export var auto_bind_progression := true
@export var safe_exit_anchor: Node3D
@export var retreat_anchor: Node3D
@export_range(0.2, 10.0) var safe_exit_radius := 1.6
@export_range(0.0, 5.0) var safe_exit_hold := 1.25
@export_range(0.0, 3.0) var exit_resolution_delay := 1.0

@export_group("Movement and timing")
@export_range(0.5, 5.0) var anticipation_seconds := 1.5
@export_range(0.4, 3.0) var windup_seconds := 0.85
@export_range(0.2, 1.5) var lunge_seconds := 0.7
@export_range(1.0, 10.0) var cooldown_seconds := 2.6
@export var stalk_speed := 1.65
@export var lunge_speed := 5.6
@export var acceleration := 6.5
@export var turn_speed := 3.66
@export var windup_distance := 3.3
@export var awareness_radius := 12.0
@export var hit_distance := 0.95
@export var hit_damage := 35.0
@export var gravity := 18.0
@export_enum("common", "armored", "anomalous") var spider_type := "common"
@export var max_health := 100.0
@export var armor := 0.0 # Reserved for future flesh-spider variants; common starts at zero.

@export_group("Optional recovered visual")
@export var mesh_scene: PackedScene
@export var visual_root: Node3D
@export var animation_player: AnimationPlayer
@export var idle_animation: StringName = &""
@export var walk_animation: StringName = &""
@export var run_animation: StringName = &""
@export var windup_animation: StringName = &""
@export var walk_reference_speed := 1.65
@export var run_reference_speed := 4.2

var state: int = State.DORMANT
var _spawn_transform := Transform3D.IDENTITY
var _active_layer := 4
var _active_mask := 3
var _state_elapsed := 0.0
var _think_remaining := 0.0
var _safe_elapsed := 0.0
var _resolution_remaining := -1.0
var _desired_velocity := Vector3.ZERO
var _lunge_direction := Vector3.ZERO
var _lunge_goal := Vector3.ZERO
var _retreat_direction := Vector3.ZERO
var _last_position := Vector3.ZERO
var _stuck_seconds := 0.0
var _hit_this_lunge := false
var _steer_side := 1.0
var _attack_shape := SphereShape3D.new()
var _contact_audio: ContactAudio
var _attack_tell_light: OmniLight3D
var _visual_rest_position := Vector3.ZERO
var _visual_rest_scale := Vector3.ONE
var _visual_rest_rotation := Vector3.ZERO
var _attack_skeleton: Skeleton3D
var _attack_bones: Dictionary = {}
var _attack_bone_base: Dictionary = {}
var health := 100.0
var beam_damage_total := 0.0
var _beam_slow_remaining := 0.0
var _beam_slow_factor := 1.0


func _init() -> void:
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 0.18
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	floor_block_on_wall = true


func _ready() -> void:
	add_to_group("spider")
	_spawn_transform = global_transform
	_active_layer = collision_layer
	_active_mask = collision_mask
	_attack_shape.radius = 0.27
	_ensure_collision_shape()
	_contact_audio = ContactAudio.new()
	_contact_audio.name = "ContactAudio"
	add_child(_contact_audio)
	if mesh_scene != null and not is_instance_valid(visual_root):
		var visual := mesh_scene.instantiate()
		add_child(visual)
		if visual is Node3D: visual_root = visual
	if not is_instance_valid(animation_player):
		var animations := find_children("*", "AnimationPlayer", true, false)
		if not animations.is_empty(): animation_player = animations[0] as AnimationPlayer
	if is_instance_valid(visual_root):
		_visual_rest_position = visual_root.position
		_visual_rest_scale = visual_root.scale
		_visual_rest_rotation = visual_root.rotation
		_attack_skeleton = visual_root.find_child("*Skeleton3D*", true, false) as Skeleton3D
		if is_instance_valid(_attack_skeleton):
			if is_instance_valid(animation_player) and not idle_animation.is_empty() and animation_player.has_animation(idle_animation):
				animation_player.play(idle_animation)
				animation_player.advance(0.0)
			for bone_name in ["LegSegmentA_L_001", "LegSegmentA_R_001", "LegSegmentA_L_002", "LegSegmentA_R_002", "PedopalpSegmentA_L", "PedopalpSegmentA_R", "Fang_L", "Fang_R"]:
				var bone := _attack_skeleton.find_bone(bone_name)
				if bone >= 0:
					_attack_bones[bone_name] = bone
					_attack_bone_base[bone_name] = _attack_skeleton.get_bone_pose_rotation(bone)
	_attack_tell_light = OmniLight3D.new()
	_attack_tell_light.name = "AttackTellGlow"
	_attack_tell_light.position = Vector3(0.0, 0.45, -0.25)
	_attack_tell_light.light_color = Color(0.8, 0.18, 0.13)
	_attack_tell_light.light_energy = 0.0
	_attack_tell_light.omni_range = 1.8
	_attack_tell_light.shadow_enabled = false
	_attack_tell_light.visible = false
	add_child(_attack_tell_light)
	deactivate()
	if auto_bind_progression:
		if not is_instance_valid(progression):
			progression = get_tree().get_first_node_in_group("progression") as Progression
		if is_instance_valid(progression):
			progression.stage_changed.connect(_on_stage_changed)
			call_deferred("_sync_stage")


func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D: return
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.64
	collider.shape = capsule
	collider.position.y = 0.32
	add_child(collider)


func _sync_stage() -> void:
	if is_instance_valid(progression): _on_stage_changed(progression.stage)


func _on_stage_changed(new_stage: int) -> void:
	deactivate()
	if new_stage == Progression.Stage.ENCOUNTER:
		# A repeated Encounter event means checkpoint recovery, with a fresh telegraph.
		global_transform = _spawn_transform
		if not is_instance_valid(target):
			target = get_tree().get_first_node_in_group("player") as Node3D
		activate(target)
	elif new_stage < Progression.Stage.ENCOUNTER:
		global_transform = _spawn_transform
	else:
		_set_state(State.RESOLVED)


func activate(player: Node3D = null) -> void:
	if is_instance_valid(player): target = player
	if not is_instance_valid(target): return
	velocity = Vector3.ZERO
	_desired_velocity = Vector3.ZERO
	_safe_elapsed = 0.0
	_resolution_remaining = -1.0
	_think_remaining = 0.0
	_stuck_seconds = 0.0
	_last_position = global_position
	_hit_this_lunge = false
	health = maxf(1.0, max_health)
	beam_damage_total = 0.0
	_beam_slow_remaining = 0.0
	_beam_slow_factor = 1.0
	collision_layer = _active_layer
	collision_mask = _active_mask
	show()
	_set_state(State.ANTICIPATION)
	set_physics_process(true)


func deactivate() -> void:
	velocity = Vector3.ZERO
	_desired_velocity = Vector3.ZERO
	_resolution_remaining = -1.0
	_safe_elapsed = 0.0
	_beam_slow_remaining = 0.0
	collision_layer = 0
	collision_mask = 0
	hide()
	if is_instance_valid(_contact_audio): _contact_audio.silence()
	if is_instance_valid(animation_player): animation_player.pause()
	if is_instance_valid(_attack_tell_light): _attack_tell_light.visible = false
	if is_instance_valid(visual_root):
		visual_root.position = _visual_rest_position
		visual_root.scale = _visual_rest_scale
		visual_root.rotation = _visual_rest_rotation
	set_physics_process(false)
	_set_state(State.DORMANT)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		deactivate()
		return
	if _target_recovering():
		_desired_velocity = Vector3.ZERO
		_safe_elapsed = 0.0
		_resolution_remaining = -1.0
		_set_state(State.COOLDOWN)
		_move(delta)
		return
	_state_elapsed += delta
	_beam_slow_remaining = maxf(0.0, _beam_slow_remaining - delta)
	if _resolution_remaining >= 0.0:
		_resolution_remaining -= delta
		if _resolution_remaining <= 0.0:
			_finish_resolution()
			return
	else:
		_think_remaining -= delta
		if _think_remaining <= 0.0:
			_think_remaining = 0.1
			_think(0.1)
	_move(delta)
	_update_animation()
	_update_attack_tell()


func _target_recovering() -> bool:
	return is_instance_valid(target) and target.has_method("is_recovering") and bool(target.call("is_recovering"))


func _think(step_seconds: float) -> void:
	if is_instance_valid(safe_exit_anchor) and target.global_position.distance_to(safe_exit_anchor.global_position) <= safe_exit_radius:
		_safe_elapsed += step_seconds
		if _safe_elapsed >= safe_exit_hold:
			resolve_at_exit()
			return
	else:
		_safe_elapsed = 0.0
	match state:
		State.ANTICIPATION:
			if _state_elapsed >= anticipation_seconds: _set_state(State.STALKING)
		State.STALKING:
			if _horizontal(target.global_position - global_position).length() > awareness_radius:
				_desired_velocity = Vector3.ZERO
			elif _attack_lane_clear(windup_distance):
				_set_state(State.WINDUP)
			else:
				var direction := _horizontal(target.global_position - global_position).normalized()
				_desired_velocity = _choose_direction(direction) * maxf(0.0, stalk_speed)
				if _desired_velocity.length_squared() > 0.01 and global_position.distance_to(_last_position) < 0.025:
					_stuck_seconds += step_seconds
				else:
					_stuck_seconds = 0.0
				if _stuck_seconds >= 1.2: _set_state(State.COOLDOWN)
		State.WINDUP:
			if _state_elapsed >= windup_seconds: _start_lunge()
		State.LUNGING:
			if not _hit_this_lunge and _attack_lane_clear(hit_distance):
				_hit_this_lunge = true
				threatened_player.emit(target)
				if is_instance_valid(target) and target.has_method("take_damage"):
					target.call("take_damage", maxf(0.0, hit_damage))
				if is_instance_valid(_contact_audio): _contact_audio.play_impact()
				_start_retreat()
			elif _state_elapsed >= lunge_seconds or _horizontal(_lunge_goal - global_position).length() < 0.2:
				_start_retreat()
		State.RETREATING:
			_desired_velocity = _choose_direction(_retreat_direction) * maxf(0.0, stalk_speed)
			if _state_elapsed >= 1.35: _set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_elapsed >= cooldown_seconds:
				_stuck_seconds = 0.0
				_set_state(State.STALKING)
	_last_position = global_position


func _set_state(new_state: int) -> void:
	if state == new_state: return
	state = new_state
	_state_elapsed = 0.0
	if state not in [State.STALKING, State.LUNGING, State.RETREATING]:
		_desired_velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
	if state == State.WINDUP and is_instance_valid(progression):
		progression.show_notice("It draws back. Move aside.", windup_seconds)
	if state == State.WINDUP and is_instance_valid(_contact_audio):
		_contact_audio.play_windup()
	if state == State.LUNGING and is_instance_valid(_contact_audio): _contact_audio.play_lunge()
	state_changed.emit(state)


func _start_lunge() -> void:
	# The post-windup check gives stepping behind a door or outside range a real effect.
	if not _attack_lane_clear(windup_distance):
		_start_retreat()
		return
	_lunge_goal = target.global_position
	_lunge_direction = _horizontal(_lunge_goal - global_position).normalized()
	_hit_this_lunge = false
	_set_state(State.LUNGING)
	_desired_velocity = _lunge_direction * maxf(0.0, lunge_speed)


func _start_retreat() -> void:
	_set_state(State.RETREATING)
	if is_instance_valid(retreat_anchor):
		_retreat_direction = _horizontal(retreat_anchor.global_position - global_position).normalized()
	else:
		_retreat_direction = _horizontal(global_position - target.global_position).normalized()
	_desired_velocity = _choose_direction(_retreat_direction) * maxf(0.0, stalk_speed)


func _move(delta: float) -> void:
	var before_move := global_position
	var rate := maxf(0.1, acceleration) * (2.3 if state == State.LUNGING else 1.0)
	var light_factor := _beam_slow_factor if _beam_slow_remaining > 0.0 else 1.0
	velocity.x = move_toward(velocity.x, _desired_velocity.x * light_factor, rate * delta)
	velocity.z = move_toward(velocity.z, _desired_velocity.z * light_factor, rate * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - maxf(0.0, gravity) * delta
	var facing := _horizontal(velocity)
	if state == State.ANTICIPATION or state == State.WINDUP:
		facing = _horizontal(target.global_position - global_position)
	if facing.length_squared() > 0.001:
		var desired_yaw := atan2(-facing.x, -facing.z)
		rotation.y += clampf(wrapf(desired_yaw - rotation.y, -PI, PI), -turn_speed * delta, turn_speed * delta)
	move_and_slide()
	if is_instance_valid(_contact_audio):
		var moved := _horizontal(global_position - before_move).length()
		var audible := state not in [State.DORMANT, State.RESOLVED] and not _target_recovering()
		_contact_audio.advance_motion(moved, delta, is_on_floor(), audible)

func apply_flashlight_beam(intensity: float, delta: float) -> void:
	if state in [State.DORMANT, State.RESOLVED] or intensity <= 0.0 or delta <= 0.0: return
	var damage_rate := 0.12
	var slow_amount := 0.05
	match spider_type:
		"armored":
			damage_rate = 0.025
			slow_amount = 0.02
		"anomalous":
			damage_rate = 0.06
			slow_amount = 0.03
	var tiny_damage := minf(3.0 - beam_damage_total, damage_rate * intensity * delta)
	if tiny_damage > 0.0:
		beam_damage_total += tiny_damage
		health = maxf(1.0, health - tiny_damage)
	_beam_slow_factor = 1.0 - slow_amount * intensity
	_beam_slow_remaining = 0.25

func take_damage(amount: float) -> void:
	if state in [State.DORMANT, State.RESOLVED] or amount <= 0.0: return
	# The opening's large spider remains an escape encounter; a worn knife cannot
	# silently replace its exit resolution or one-shot it.
	health = maxf(1.0, health - maxf(0.0, minf(amount, 6.0) - armor))


func _exclusions() -> Array[RID]:
	var excluded: Array[RID] = [get_rid()]
	if target is CollisionObject3D: excluded.append((target as CollisionObject3D).get_rid())
	return excluded


func _horizontal(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _attack_lane_clear(maximum_distance: float) -> bool:
	if not is_instance_valid(target) or not is_on_floor(): return false
	var separation := target.global_position - global_position
	if _horizontal(separation).length() > maximum_distance or absf(separation.y) > 0.45:
		return false
	var start := global_position + Vector3.UP * 0.32
	var end := target.global_position + Vector3.UP * 0.32
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(start, end, _active_mask, _exclusions())
	if not space.intersect_ray(ray).is_empty(): return false
	var body_sweep := PhysicsShapeQueryParameters3D.new()
	body_sweep.shape = _attack_shape
	body_sweep.transform = Transform3D(Basis.IDENTITY, start)
	body_sweep.motion = end - start
	body_sweep.collision_mask = _active_mask
	body_sweep.exclude = _exclusions()
	var fractions: PackedFloat32Array = space.cast_motion(body_sweep)
	return fractions.size() >= 1 and fractions[0] >= 0.99


func _choose_direction(desired: Vector3) -> Vector3:
	if desired.length_squared() < 0.001: return Vector3.ZERO
	if _direction_clear(desired): return desired
	var best := Vector3.ZERO
	var best_score := -2.0
	# Local steering handles furnishings and corners; this is not a baked navigation mesh.
	for degrees in [35.0, -35.0, 70.0, -70.0, 100.0, -100.0]:
		var candidate := desired.rotated(Vector3.UP, deg_to_rad(degrees * _steer_side))
		if not _direction_clear(candidate): continue
		var score := candidate.dot(desired) + (0.04 if degrees > 0.0 else 0.0)
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _direction_clear(direction: Vector3) -> bool:
	if test_move(global_transform, direction * 0.65): return false
	var point := global_position + direction * 0.65
	var floor_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4,
		point - Vector3.UP * 0.65, _active_mask, _exclusions())
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(floor_ray)
	return not floor_hit.is_empty() and (floor_hit.normal as Vector3).dot(Vector3.UP) >= cos(floor_max_angle)


func resolve_at_exit() -> bool:
	if state in [State.DORMANT, State.RESOLVED] or _resolution_remaining >= 0.0 or _target_recovering():
		return false
	_set_state(State.COOLDOWN)
	_resolution_remaining = maxf(0.0, exit_resolution_delay)
	return true


func _finish_resolution() -> void:
	if _target_recovering():
		_resolution_remaining = -1.0
		return
	deactivate()
	_set_state(State.RESOLVED)
	if is_instance_valid(progression): progression.resolve_encounter()


func _update_animation() -> void:
	if not is_instance_valid(animation_player): return
	var speed := _horizontal(velocity).length()
	var running := speed > stalk_speed * 1.25 and not run_animation.is_empty()
	var clip := idle_animation
	if state == State.WINDUP and not windup_animation.is_empty():
		clip = windup_animation
	elif speed >= 0.05:
		clip = run_animation if running else walk_animation
	if clip.is_empty() or not animation_player.has_animation(clip):
		animation_player.pause()
		return
	var reference := run_reference_speed if running else walk_reference_speed
	animation_player.speed_scale = 1.0 if speed < 0.05 else clampf(speed / maxf(0.01, reference), 0.35, 1.65)
	if animation_player.current_animation != clip or not animation_player.is_playing():
		animation_player.play(clip, 0.15)

func _update_attack_tell() -> void:
	if not is_instance_valid(_attack_tell_light): return
	var windup := state == State.WINDUP
	var lunging := state == State.LUNGING
	_attack_tell_light.visible = windup or lunging
	_attack_tell_light.light_energy = 0.26 + 0.16 * sin(_state_elapsed * 24.0) if windup else (0.38 if lunging else 0.0)
	if not is_instance_valid(visual_root): return
	var offset := Vector3.ZERO
	var scale_factor := Vector3.ONE
	var rotation_offset := Vector3.ZERO
	if windup:
		var weight := clampf(_state_elapsed / maxf(0.01, windup_seconds), 0.0, 1.0)
		offset = Vector3(0.0, -0.065 * weight, 0.10 * weight)
		scale_factor = Vector3(1.0 + 0.035 * weight, 1.0 - 0.09 * weight, 1.0 + 0.07 * weight)
		rotation_offset.x = 0.10 * weight
	elif lunging:
		var weight := clampf(_state_elapsed / maxf(0.01, lunge_seconds), 0.0, 1.0)
		offset = Vector3(0.0, 0.07 * sin(PI * weight), -0.08)
		rotation_offset.x = -0.15
	elif state in [State.RETREATING, State.COOLDOWN]:
		var weight := maxf(0.0, 1.0 - _state_elapsed / 0.45)
		offset = Vector3(0.0, -0.025 * weight, 0.0)
	visual_root.position = _visual_rest_position + offset
	visual_root.scale = _visual_rest_scale * scale_factor
	visual_root.rotation = _visual_rest_rotation + rotation_offset
	_update_attack_bone_pose()

func _update_attack_bone_pose() -> void:
	if not is_instance_valid(_attack_skeleton) or state not in [State.WINDUP, State.LUNGING]: return
	# The recovered spider includes 142 skinned bones but only idle, walk and run
	# clips. These eight authored additive poses animate its actual front legs,
	# pedipalps and fangs during an attack, instead of only moving the whole mesh.
	if is_instance_valid(animation_player): animation_player.advance(0.0)
	var lift := 0.0
	var fang := 0.0
	if state == State.WINDUP:
		var t := clampf(_state_elapsed / maxf(0.01, windup_seconds), 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		lift = -0.43 * eased
		fang = 0.17 * eased
	else:
		var t := clampf(_state_elapsed / maxf(0.01, lunge_seconds), 0.0, 1.0)
		lift = -0.43 + 0.88 * sin(minf(1.0, t * 1.4) * PI * 0.5)
		fang = 0.17 + 0.48 * sin(t * PI)
	_pose_attack_bone("LegSegmentA_L_001", Vector3.RIGHT, lift)
	_pose_attack_bone("LegSegmentA_R_001", Vector3.RIGHT, lift)
	_pose_attack_bone("LegSegmentA_L_002", Vector3.RIGHT, lift * 0.55)
	_pose_attack_bone("LegSegmentA_R_002", Vector3.RIGHT, lift * 0.55)
	_pose_attack_bone("PedopalpSegmentA_L", Vector3.FORWARD, fang * 0.55)
	_pose_attack_bone("PedopalpSegmentA_R", Vector3.FORWARD, -fang * 0.55)
	_pose_attack_bone("Fang_L", Vector3.UP, fang)
	_pose_attack_bone("Fang_R", Vector3.UP, -fang)

func _pose_attack_bone(bone_name: String, axis: Vector3, radians: float) -> void:
	if not _attack_bones.has(bone_name): return
	var bone: int = _attack_bones[bone_name]
	var base: Quaternion = _attack_bone_base[bone_name]
	_attack_skeleton.set_bone_pose_rotation(bone, base * Quaternion(axis, radians))
