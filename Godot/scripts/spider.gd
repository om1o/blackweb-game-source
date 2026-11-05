class_name BlackwebSpider
extends CharacterBody3D
## Floor-bound predator: perception, committed attacks, physical routing and death.

signal state_changed(new_state: int)
signal threatened_player(player: Node3D)
signal health_changed(current: float, maximum: float)
signal died

enum State { DORMANT, ANTICIPATION, STALKING, WINDUP, LUNGING, RETREATING, COOLDOWN, RESOLVED, SEARCHING, STAGGERED, DYING, DEAD }
const Progression = preload("res://scripts/progression.gd")
const ContactAudio = preload("res://scripts/spider_audio.gd")
const Navigation = preload("res://scripts/spider_navigation.gd")

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
@export var bite_distance := 1.1
@export var bite_damage := 18.0
@export var bite_windup_seconds := 0.55
@export var bite_seconds := 0.45
@export var stagger_seconds := 0.32
@export var stagger_resistance_seconds := 1.5
@export var death_seconds := 1.1

@export_group("Perception and routing")
@export var sight_angle_degrees := 240.0
@export var hearing_radius := 4.5
@export var memory_seconds := 4.5
@export var navigation_points: PackedVector3Array = []

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
var _attack_kind: StringName = &"lunge"
var _memory_remaining := 0.0
var _last_known_position := Vector3.ZERO
var _has_target_memory := false
var _target_visible := false
var _stagger_resistance := 0.0
var _hurt_remaining := 0.0
var _actual_speed := 0.0
var _navigation = Navigation.new()
var _route_direction := Vector3.ZERO
var _route_remaining := 0.0
var _pose_previous: Dictionary = {}


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
	if is_instance_valid(animation_player):
		# Advance base clips before authored additive poses, once per physics tick.
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
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
			for bone in range(_attack_skeleton.get_bone_count()):
				var bone_name := _attack_skeleton.get_bone_name(bone)
				if bone_name.begins_with("LegSegmentA_") or bone_name.begins_with("LegSegmentB_"):
					_attack_bones[bone_name] = bone
	_navigation.points = navigation_points
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
	# Killing the predator unlocks the same exit, while leaving its corpse visible.
	if new_stage > Progression.Stage.ENCOUNTER and state in [State.DYING, State.DEAD]: return
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
	_memory_remaining = 0.0
	_has_target_memory = false
	_target_visible = false
	_stagger_resistance = 0.0
	_hurt_remaining = 0.0
	_actual_speed = 0.0
	_route_remaining = 0.0
	_route_direction = Vector3.ZERO
	_reset_bone_pose()
	health_changed.emit(health, max_health)
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
	_reset_bone_pose()
	_hurt_remaining = 0.0
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
	if state in [State.DYING, State.DEAD]:
		_state_elapsed += delta
		_update_animation(delta)
		_update_attack_tell()
		if state == State.DYING and _state_elapsed >= death_seconds:
			_set_state(State.DEAD)
			_state_elapsed = death_seconds
			set_physics_process(false)
			if is_instance_valid(progression) and not _target_recovering(): progression.resolve_encounter()
		return
	if not is_instance_valid(target):
		deactivate()
		return
	if _target_recovering():
		_desired_velocity = Vector3.ZERO
		_safe_elapsed = 0.0
		_resolution_remaining = -1.0
		_set_state(State.COOLDOWN)
		_hit_this_lunge = true
		_move(delta)
		_update_animation(delta)
		_update_attack_tell()
		return
	_state_elapsed += delta
	_beam_slow_remaining = maxf(0.0, _beam_slow_remaining - delta)
	_stagger_resistance = maxf(0.0, _stagger_resistance - delta)
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_route_remaining -= delta
	_navigation.advance(delta)
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
	_resolve_attack_contact()
	_update_animation(delta)
	_update_attack_tell()


func _target_recovering() -> bool:
	if not is_instance_valid(target): return true
	var target_health: Variant = target.get("health")
	if (target_health is float or target_health is int) and float(target_health) <= 0.0: return true
	return target.has_method("is_recovering") and bool(target.call("is_recovering"))


func _think(step_seconds: float) -> void:
	if is_instance_valid(safe_exit_anchor) and target.global_position.distance_to(safe_exit_anchor.global_position) <= safe_exit_radius:
		_safe_elapsed += step_seconds
		if _safe_elapsed >= safe_exit_hold:
			resolve_at_exit()
			return
	else:
		_safe_elapsed = 0.0
	_sense_target(step_seconds)
	match state:
		State.ANTICIPATION:
			if _state_elapsed >= anticipation_seconds: _set_state(State.STALKING)
		State.STALKING:
			if not _has_target_memory:
				_desired_velocity = Vector3.ZERO
				_set_state(State.SEARCHING)
			elif _target_visible and _attack_lane_clear(windup_distance):
				_set_state(State.WINDUP)
			else:
				var direction := _pursuit_direction()
				_desired_velocity = _choose_direction(direction) * maxf(0.0, stalk_speed)
				if _desired_velocity.length_squared() > 0.01 and global_position.distance_to(_last_position) < 0.025:
					_stuck_seconds += step_seconds
				else:
					_stuck_seconds = 0.0
				if _stuck_seconds >= 1.2: _set_state(State.COOLDOWN)
		State.WINDUP:
			if _state_elapsed >= _windup_duration(): _start_lunge()
		State.LUNGING:
			if _state_elapsed >= _attack_duration():
				_start_retreat()
		State.RETREATING:
			_desired_velocity = _choose_direction(_retreat_direction) * maxf(0.0, stalk_speed)
			if _state_elapsed >= 1.35: _set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_elapsed >= cooldown_seconds:
				_stuck_seconds = 0.0
				_set_state(State.STALKING)
		State.SEARCHING:
			if _has_target_memory: _set_state(State.STALKING)
		State.STAGGERED:
			# Do not restart the full recovery on every knife hit: that would let
			# 0.75-second swings keep the adult stunned forever.
			if _state_elapsed >= stagger_seconds: _set_state(State.STALKING)
	_last_position = global_position


func _set_state(new_state: int) -> void:
	if state == new_state: return
	state = new_state
	_state_elapsed = 0.0
	if state not in [State.STALKING, State.LUNGING, State.RETREATING]:
		_desired_velocity = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
	if state == State.WINDUP and is_instance_valid(target):
		_attack_kind = &"bite" if _horizontal(target.global_position - global_position).length() <= bite_distance else &"lunge"
		_lunge_goal = target.global_position
		_lunge_direction = _horizontal(_lunge_goal - global_position).normalized()
		_hit_this_lunge = false
	if state == State.WINDUP and is_instance_valid(progression):
		progression.show_notice("Fangs open. Step back." if _attack_kind == &"bite" else "It draws back. Move aside.", _windup_duration())
	if state == State.WINDUP and is_instance_valid(_contact_audio):
		_contact_audio.play_windup()
	if state == State.LUNGING and is_instance_valid(_contact_audio): _contact_audio.play_lunge()
	state_changed.emit(state)


func _start_lunge() -> void:
	# The post-windup check gives stepping behind a door or outside range a real effect.
	if not _attack_lane_clear(bite_distance + 0.15 if _attack_kind == &"bite" else windup_distance) or not _inside_attack_cone():
		_start_retreat()
		return
	_hit_this_lunge = false
	_set_state(State.LUNGING)
	_desired_velocity = Vector3.ZERO if _attack_kind == &"bite" else _lunge_direction * maxf(0.0, lunge_speed)


func _windup_duration() -> float:
	return bite_windup_seconds if _attack_kind == &"bite" else windup_seconds


func _attack_duration() -> float:
	return bite_seconds if _attack_kind == &"bite" else lunge_seconds


func _inside_attack_cone() -> bool:
	var toward := _horizontal(target.global_position - global_position)
	return toward.length_squared() < 0.01 or _lunge_direction.dot(toward.normalized()) >= cos(deg_to_rad(50.0))


func _resolve_attack_contact() -> void:
	if state != State.LUNGING or _hit_this_lunge or _target_recovering(): return
	var active_start := 0.12 if _attack_kind == &"bite" else 0.10
	var active_end := 0.32 if _attack_kind == &"bite" else 0.60
	if _state_elapsed < active_start or _state_elapsed > active_end: return
	var reach := bite_distance + 0.15 if _attack_kind == &"bite" else hit_distance
	if not _inside_attack_cone() or not _attack_lane_clear(reach): return
	_hit_this_lunge = true
	threatened_player.emit(target)
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.call("take_damage", maxf(0.0, bite_damage if _attack_kind == &"bite" else hit_damage))
	if is_instance_valid(_contact_audio): _contact_audio.play_impact()
	# Finish the attack pose; the following recovery cannot deal contact damage.
	_desired_velocity = Vector3.ZERO


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
		facing = _lunge_direction if state == State.WINDUP else _horizontal(target.global_position - global_position)
	if state == State.SEARCHING:
		rotation.y += sin(_state_elapsed * 1.8) * delta * 0.6
	if facing.length_squared() > 0.001:
		var desired_yaw := atan2(-facing.x, -facing.z)
		rotation.y += clampf(wrapf(desired_yaw - rotation.y, -PI, PI), -turn_speed * delta, turn_speed * delta)
	move_and_slide()
	_actual_speed = _horizontal(global_position - before_move).length() / maxf(0.001, delta)
	if is_instance_valid(_contact_audio):
		var moved := _horizontal(global_position - before_move).length()
		var audible := state not in [State.DORMANT, State.RESOLVED] and not _target_recovering()
		_contact_audio.advance_motion(moved, delta, is_on_floor(), audible)

func apply_flashlight_beam(intensity: float, delta: float) -> void:
	if not is_alive() or intensity <= 0.0 or delta <= 0.0 or not is_finite(intensity) or not is_finite(delta): return
	intensity = clampf(intensity, 0.0, 1.0)
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
		health_changed.emit(health, max_health)
	_beam_slow_factor = 1.0 - slow_amount * intensity
	_beam_slow_remaining = 0.25

func take_damage(amount: float) -> void:
	if not is_alive() or amount <= 0.0 or not is_finite(amount): return
	var damage := maxf(0.0, amount - maxf(0.0, armor))
	if damage <= 0.0: return
	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)
	_hurt_remaining = 0.22
	if is_instance_valid(_contact_audio): _contact_audio.play_impact()
	if health <= 0.0:
		_resolution_remaining = -1.0
		_hit_this_lunge = true
		collision_layer = 0
		collision_mask = 0
		_set_state(State.DYING)
		died.emit()
	elif _stagger_resistance <= 0.0:
		_stagger_resistance = stagger_resistance_seconds
		_hit_this_lunge = true
		_set_state(State.STAGGERED)


func is_alive() -> bool:
	return health > 0.0 and state not in [State.DORMANT, State.RESOLVED, State.DYING, State.DEAD]


func _sense_target(delta: float) -> void:
	var offset := target.global_position - global_position
	var flat := _horizontal(offset)
	var in_cone := flat.length() <= 2.4 or (-global_basis.z).dot(flat.normalized()) >= cos(deg_to_rad(sight_angle_degrees * 0.5))
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.38, target.global_position + Vector3.UP * 0.6, 1, _exclusions())
	_target_visible = flat.length() <= awareness_radius and absf(offset.y) <= 2.0 and in_cone and get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	var audible := false
	if target is CharacterBody3D:
		audible = flat.length() <= hearing_radius and _horizontal((target as CharacterBody3D).velocity).length() >= 2.5
	if _target_visible or audible:
		_last_known_position = target.global_position
		_memory_remaining = memory_seconds
		_has_target_memory = true
	else:
		_memory_remaining = maxf(0.0, _memory_remaining - delta)
		_has_target_memory = _memory_remaining > 0.0


func _pursuit_direction() -> Vector3:
	var distance := _horizontal(_last_known_position - global_position).length()
	if distance < 0.35: return Vector3.ZERO
	if _route_remaining <= 0.0:
		_route_remaining = 0.35
		_route_direction = _navigation.next_direction(self, _last_known_position)
		if navigation_points.is_empty() and _route_direction.is_zero_approx():
			_route_direction = _horizontal(_last_known_position - global_position).normalized()
	return _route_direction


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
	if not space.intersect_shape(body_sweep, 1).is_empty(): return false
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
	if not is_alive() or _resolution_remaining >= 0.0 or _target_recovering():
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


func _update_animation(delta: float = 0.0) -> void:
	_reset_bone_pose()
	if not is_instance_valid(animation_player): return
	var speed := _actual_speed
	var running := speed > stalk_speed * 1.25 and not run_animation.is_empty()
	var clip := idle_animation
	if state == State.WINDUP and not windup_animation.is_empty():
		clip = windup_animation
	elif state in [State.DYING, State.DEAD, State.STAGGERED] or (state == State.LUNGING and _attack_kind == &"bite"):
		clip = idle_animation
	elif speed >= 0.05:
		clip = run_animation if running else walk_animation
	if clip.is_empty() or not animation_player.has_animation(clip):
		animation_player.pause()
		return
	var reference := run_reference_speed if running else walk_reference_speed
	animation_player.speed_scale = 1.0 if speed < 0.05 else clampf(speed / maxf(0.01, reference), 0.35, 1.65)
	if animation_player.current_animation != clip or not animation_player.is_playing():
		animation_player.play(clip, 0.15)
	animation_player.advance(delta)

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
		var weight := smoothstep(0.0, 1.0, _state_elapsed / maxf(0.01, _windup_duration()))
		offset = Vector3(0.0, -0.04 * weight, 0.10 * weight)
		rotation_offset.x = 0.10 * weight if _attack_kind == &"lunge" else -0.09 * weight
	elif lunging:
		var weight := clampf(_state_elapsed / maxf(0.01, _attack_duration()), 0.0, 1.0)
		var strike := sin(PI * weight)
		offset = Vector3(0.0, 0.045 * strike, -0.08 * strike)
		rotation_offset.x = -0.15 * strike
	elif state in [State.RETREATING, State.COOLDOWN]:
		var weight := maxf(0.0, 1.0 - _state_elapsed / 0.45)
		offset = Vector3(0.0, -0.025 * weight, 0.0)
	elif state in [State.DYING, State.DEAD]:
		var weight := smoothstep(0.0, 1.0, _state_elapsed / maxf(0.01, death_seconds))
		offset.y = -0.14 * weight
		rotation_offset.z = 0.24 * weight
		rotation_offset.x = 0.08 * weight
	elif _hurt_remaining > 0.0:
		rotation_offset.z = sin(_hurt_remaining * 50.0) * 0.07 * (_hurt_remaining / 0.22)
		offset.z = 0.055 * (_hurt_remaining / 0.22)
	visual_root.position = _visual_rest_position + offset
	visual_root.scale = _visual_rest_scale * scale_factor
	visual_root.rotation = _visual_rest_rotation + rotation_offset
	_update_attack_bone_pose()

func _update_attack_bone_pose() -> void:
	if not is_instance_valid(_attack_skeleton): return
	if state in [State.DYING, State.DEAD]:
		var collapse := smoothstep(0.0, 1.0, _state_elapsed / maxf(0.01, death_seconds))
		for bone_name in _attack_bones:
			if str(bone_name).begins_with("LegSegment"):
				var side := 1.0 if str(bone_name).contains("_L_") else -1.0
				_pose_attack_bone(bone_name, Vector3.FORWARD, side * collapse * 0.52)
		return
	if state not in [State.WINDUP, State.LUNGING]: return
	# The recovered spider includes 142 skinned bones but only idle, walk and run
	# clips. These eight authored additive poses animate its actual front legs,
	# pedipalps and fangs during an attack, instead of only moving the whole mesh.
	var lift := 0.0
	var fang := 0.0
	if state == State.WINDUP:
		var t := clampf(_state_elapsed / maxf(0.01, _windup_duration()), 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		lift = -0.43 * eased
		fang = 0.17 * eased
	else:
		var t := clampf(_state_elapsed / maxf(0.01, _attack_duration()), 0.0, 1.0)
		lift = -0.43 + 0.88 * sin(minf(1.0, t * 1.4) * PI * 0.5)
		fang = 0.17 + 0.48 * sin(t * PI)
	if _attack_kind == &"bite": lift *= 0.55
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
	var base := _attack_skeleton.get_bone_pose_rotation(bone)
	_pose_previous[bone] = base
	_attack_skeleton.set_bone_pose_rotation(bone, base * Quaternion(axis, radians))


func _reset_bone_pose() -> void:
	if is_instance_valid(_attack_skeleton):
		for bone in _pose_previous:
			_attack_skeleton.set_bone_pose_rotation(bone, _pose_previous[bone])
	_pose_previous.clear()
