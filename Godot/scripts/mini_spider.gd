class_name BlackwebMiniSpider
extends CharacterBody3D

## Small spider threat with a skinned, animated visual and simple collision.
## The licensed Literock mesh is packaged with the game but omitted from Git.
## The CC0 model remains a source-checkout fallback.
const Progression = preload("res://scripts/progression.gd")
const LITEROCK_VISUAL_PATH := "res://assets/third_party/literock/Giant_Spider_Lite_1K.glb"
const FALLBACK_VISUAL_PATH := "res://assets/third_party/poly_pizza/quaternius_spider/quaternius_spider.glb"

@export var target: Node3D
@export var progression: Progression
@export var auto_bind_progression := true
@export var walk_speed := 1.35
@export var hit_damage := 6.0
@export var max_health := 12.0
@export var armor := 0.0
@export var awareness_radius := 8.0
@export var bite_windup_seconds := 0.28

var health := 12.0
var active := false
var light_slow_remaining := 0.0
var light_speed_factor := 1.0
var _attack_cooldown := 0.0
var _bite_windup_remaining := 0.0
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

func _ready() -> void:
	add_to_group("mini_spider")
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 0.12
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.13
	capsule.height = 0.27
	collision.shape = capsule
	collision.position.y = 0.135
	add_child(collision)
	_create_visual()
	_bite_audio = AudioStreamPlayer3D.new()
	_bite_audio.name = "JuvenileBiteCue"
	_bite_audio.volume_db = -22.0
	_bite_audio.max_distance = 6.0
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
				# Literock is metres; at 0.30 scale its 2.2 m leg span reads as
				# a large house juvenile. The old CC0 fallback uses FBX units.
				animated.scale = Vector3.ONE * (0.30 if _visual_is_literock else 0.055)
				animated.position.y = 0.015 if _visual_is_literock else 0.11
				add_child(animated)
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
	body_instance.position.y = 0.16
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
	add_child(legs)
	_visual_root = body_instance
	_visual_rest_scale = body_instance.scale

func _play_visual(kind: String) -> void:
	if not is_instance_valid(_visual_animation): return
	var clip: StringName = _visual_clips.get(kind, &"")
	if clip.is_empty() or not _visual_animation.has_animation(clip): return
	_visual_animation.speed_scale = 2.3 if _visual_is_literock and kind == "attack" else 1.0
	if _visual_animation.current_animation != clip or not _visual_animation.is_playing():
		_visual_animation.play(clip, 0.08)

func _sync_stage() -> void:
	if is_instance_valid(progression): _on_stage_changed(progression.stage)

func _on_stage_changed(stage: int) -> void:
	if stage == Progression.Stage.ENCOUNTER: activate(target)
	else: deactivate()

func activate(player: Node3D = null) -> void:
	if is_instance_valid(player): target = player
	if not is_instance_valid(target): target = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(target): return
	health = maxf(1.0, max_health)
	light_slow_remaining = 0.0
	light_speed_factor = 1.0
	_attack_cooldown = 0.0
	_bite_windup_remaining = 0.0
	_death_remaining = 0.0
	active = true
	collision_layer = 4
	collision_mask = 3
	show()
	_play_visual("idle")
	set_physics_process(true)

func deactivate() -> void:
	active = false
	velocity = Vector3.ZERO
	_bite_windup_remaining = 0.0
	_death_remaining = 0.0
	if is_instance_valid(_body_visual): _body_visual.scale = Vector3.ONE
	if is_instance_valid(_visual_root):
		_visual_root.scale = _visual_rest_scale
		_visual_root.position = _visual_rest_position
		_visual_root.rotation = _visual_rest_rotation
	if is_instance_valid(_visual_animation): _visual_animation.pause()
	if is_instance_valid(_bite_audio): _bite_audio.stop()
	collision_layer = 0
	collision_mask = 0
	hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _death_remaining > 0.0:
		_death_remaining -= delta
		if is_instance_valid(_visual_root) and not _visual_clips.has("death"):
			var fall := clampf(1.0 - _death_remaining / 0.65, 0.0, 1.0)
			_visual_root.rotation.z = _visual_rest_rotation.z + 0.40 * fall
			_visual_root.position.y = _visual_rest_position.y - 0.07 * fall
		if _death_remaining <= 0.0: deactivate()
		return
	if not active or not is_instance_valid(target): return
	light_slow_remaining = maxf(0.0, light_slow_remaining - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var toward := target.global_position - global_position
	toward.y = 0.0
	if _bite_windup_remaining > 0.0:
		_bite_windup_remaining = maxf(0.0, _bite_windup_remaining - delta)
		if is_instance_valid(_body_visual): _body_visual.scale = Vector3(1.10, 0.80, 1.10)
		if is_instance_valid(_visual_root) and not is_instance_valid(_body_visual):
			_visual_root.scale = _visual_rest_scale * Vector3(1.08, 0.85, 1.08)
		_play_visual("attack")
		if _bite_windup_remaining <= 0.0:
			if is_instance_valid(_body_visual): _body_visual.scale = Vector3.ONE
			if is_instance_valid(_visual_root): _visual_root.scale = _visual_rest_scale
			_attack_cooldown = 1.6
			if _can_bite_target(0.52):
				if target.has_method("take_damage"): target.call("take_damage", hit_damage)
				_bite_audio.play()
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		return
	var factor := light_speed_factor if light_slow_remaining > 0.0 else 1.0
	var desired := toward.normalized() * walk_speed * factor if toward.length() < awareness_radius else Vector3.ZERO
	velocity.x = move_toward(velocity.x, desired.x, 5.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 5.0 * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	if desired.length_squared() > 0.001: rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, delta * 7.0))
	move_and_slide()
	_play_visual("walk" if desired.length_squared() > 0.001 else "idle")
	if _attack_cooldown <= 0.0 and _can_bite_target(0.50):
		_bite_windup_remaining = bite_windup_seconds
		_play_visual("attack")

func _can_bite_target(reach: float) -> bool:
	if not is_instance_valid(target): return false
	if target.has_method("is_recovering") and target.call("is_recovering"): return false
	# Feet-level bite path: use full 3D distance so jumping out of reach works,
	# and check again at impact in case a door closes during the windup.
	var bite_from := global_position + Vector3.UP * 0.14
	var bite_to := target.global_position + Vector3.UP * 0.14
	if bite_from.distance_to(bite_to) > reach: return false
	var query := PhysicsRayQueryParameters3D.create(bite_from, bite_to, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func apply_flashlight_beam(intensity: float, _delta: float) -> void:
	if not active or intensity <= 0.0: return
	light_speed_factor = 1.0 - 0.20 * clampf(intensity, 0.0, 1.0)
	light_slow_remaining = 0.42

func take_damage(amount: float) -> void:
	if not active or amount <= 0.0: return
	health = maxf(0.0, health - maxf(0.0, amount - armor))
	if health <= 0.0:
		active = false
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		_play_visual("death")
		_death_remaining = 0.65
		if is_instance_valid(_visual_animation) and _visual_clips.has("death"):
			_death_remaining = maxf(0.65, _visual_animation.get_animation(_visual_clips["death"]).length)
		elif is_instance_valid(_visual_animation):
			_visual_animation.pause()
		set_physics_process(true)

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
