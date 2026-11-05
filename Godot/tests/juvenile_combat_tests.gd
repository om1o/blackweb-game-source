extends SceneTree
## Real physics/rig fixture: attack commitment, counterplay and damage lifecycle.
const MiniSpider = preload("res://scripts/mini_spider.gd")

class TargetProbe extends Node3D:
	var damage_received := 0.0
	var hits := 0
	var recovering := false
	func take_damage(amount: float) -> void:
		damage_received += amount
		hits += 1
	func is_recovering() -> bool: return recovering

class HealthOnlyProbe extends Node3D:
	var health := 0.0
	var hits := 0
	func take_damage(_amount: float) -> void: hits += 1

var checks := 0
var failures: Array[String] = []
var world: Node3D
var mini: BlackwebMiniSpider
var target: TargetProbe
var wall: StaticBody3D
var deaths := 0
var health_events: Array[float] = []

func _initialize() -> void: call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var mesh := BoxShape3D.new()
	mesh.size = size
	shape.shape = mesh
	body.add_child(shape)
	world.add_child(body)
	body.position = at
	return body

func _reset() -> void:
	mini.position = Vector3(-0.20, 0.42, 0.0)
	mini.velocity = Vector3.ZERO
	mini.armor = 0.0
	target.position = Vector3(0.20, 0.42, 0.0)
	target.damage_received = 0.0
	target.hits = 0
	target.recovering = false
	mini.activate(target)
	mini.set_physics_process(false)

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(10, 0.4, 10), Vector3(0, 0.2, 0))
	wall = _box(Vector3(0.12, 2, 1.5), Vector3(0, 1.4, 3))
	target = TargetProbe.new()
	world.add_child(target)
	mini = MiniSpider.new()
	mini.auto_bind_progression = false
	mini.walk_speed = 0.0
	mini.hit_damage = 4.0
	mini.position = Vector3(-0.20, 0.42, 0.0)
	mini.rotation.y = 0.30
	world.add_child(mini)
	mini.died.connect(func() -> void: deaths += 1)
	mini.health_changed.connect(func(value: float, _maximum: float) -> void: health_events.append(value))
	await physics_frame
	await physics_frame
	_reset()
	_check(is_equal_approx(mini.health, 12.0) and mini.is_alive(), "Juvenile starts alive at its twelve-health archetype value")
	mini._physics_process(0.01)
	_check(mini.combat_state == MiniSpider.CombatState.WINDUP and target.hits == 0,
		"Nearby prey starts a visible tell with no immediate contact damage")
	_check(mini._visual_animation.current_animation == mini._visual_clips.get("attack"),
		"Combat starts the imported Bite animation")
	mini._physics_process(0.12)
	_check(target.hits == 0, "The first half of the tell cannot damage the player")
	mini._physics_process(0.17)
	_check(target.hits == 1 and is_equal_approx(target.damage_received, 4.0),
		"A completed in-range bite deals exactly four damage once")
	_check(mini.combat_state == MiniSpider.CombatState.RECOVERY,
		"Impact enters a punishable recovery state")
	mini._visual_animation.advance(0.1)
	var clip_position := mini._visual_animation.current_animation_position
	mini._physics_process(0.10)
	_check(mini._visual_animation.current_animation == mini._visual_clips.get("attack")
		and mini._visual_animation.current_animation_position >= clip_position,
		"Recovery preserves the Bite clip instead of restarting or cutting it at impact")
	_check(target.hits == 1, "Recovery cannot apply a second bite hit")

	_reset()
	mini._physics_process(0.01)
	var committed_rotation := mini.rotation.y
	target.position = Vector3(-0.55, 0.42, 0.0)
	mini._physics_process(0.30)
	_check(target.hits == 0 and is_equal_approx(mini.rotation.y, committed_rotation),
		"Dodging behind during the tell avoids the bite without a tracking turn")
	_reset()
	mini._physics_process(0.01)
	target.position.y += 0.85
	mini._physics_process(0.30)
	_check(target.hits == 0, "Jumping out of the bite volume before impact avoids damage")
	_reset()
	mini._physics_process(0.01)
	wall.position.z = 0.0
	await physics_frame
	mini._physics_process(0.30)
	_check(target.hits == 0, "A door closing during the tell blocks the active bite")
	wall.position.z = 3.0
	await physics_frame
	_reset()
	target.recovering = true
	mini._physics_process(0.30)
	_check(mini.combat_state == MiniSpider.CombatState.WAITING and target.hits == 0,
		"A recovering player is neither pursued nor attacked")

	_reset()
	mini._physics_process(0.01)
	mini.take_damage(4.0)
	_check(is_equal_approx(mini.health, 8.0) and mini.combat_state == MiniSpider.CombatState.STAGGERED,
		"The worn knife removes four HP and creates a visible hit reaction")
	_check(is_zero_approx(mini._bite_windup_remaining), "A knife hit interrupts an unfinished bite")
	mini._physics_process(0.10)
	_check(absf(mini._visual_root.rotation.x - mini._visual_rest_rotation.x) > 0.05,
		"Stagger visibly recoils the animated spider model")
	mini._physics_process(0.15)
	_check(target.hits == 0 and mini._visual_root.position.is_equal_approx(mini._visual_rest_position),
		"Interrupted attack stays harmless and the hit pose restores after stagger")
	mini.apply_flashlight_beam(1.0, 0.1)
	_check(is_equal_approx(mini.health, 8.0) and is_equal_approx(mini.light_speed_factor, 0.8),
		"The weak flashlight slows a juvenile by twenty percent without free damage")
	mini.take_damage(4.0)
	_check(is_equal_approx(mini.health, 4.0) and mini.active, "Two worn-knife hits leave four HP")
	mini.take_damage(4.0)
	_check(is_zero_approx(mini.health) and not mini.active and not mini.is_alive() and deaths == 1,
		"The third worn-knife hit kills and emits one death event")
	_check(mini.combat_state == MiniSpider.CombatState.DEAD and mini.visible
		and mini.collision_layer == 0 and mini.collision_mask == 1,
		"Dead spider is briefly visible, harmless to the player and supported by the floor")
	mini.take_damage(999.0)
	_check(deaths == 1 and is_zero_approx(mini.health), "A dead juvenile cannot be damaged or killed twice")
	mini._physics_process(0.30)
	_check(mini.visible and mini._visual_root.rotation.z > 0.15, "Unauthored death uses a visible collapse instead of instantly vanishing")
	mini._physics_process(2.0)
	_check(not mini.visible and not mini.is_physics_processing(), "Finished corpse retires without active AI or per-frame work")
	_check(health_events.has(8.0) and health_events.has(4.0) and health_events.has(0.0),
		"Health events expose the complete damage lifecycle for UI or effects")
	_reset()
	mini.armor = 10.0
	mini.take_damage(4.0)
	_check(is_equal_approx(mini.health, 12.0) and mini.combat_state != MiniSpider.CombatState.STAGGERED,
		"Fully absorbed damage cannot spuriously stagger the enemy")
	mini.armor = 0.0
	mini.take_damage(NAN)
	mini.take_damage(-2.0)
	_check(is_equal_approx(mini.health, 12.0), "Invalid or negative damage cannot corrupt health")

	var placed_transform := mini._spawn_transform
	mini._physics_process(0.01)
	mini.position = Vector3(2.0, 1.0, 2.0)
	mini.rotation.y = 2.0
	mini.velocity = Vector3(2.0, -4.0, 1.0)
	mini._on_stage_changed(MiniSpider.Progression.Stage.ENCOUNTER)
	mini.set_physics_process(false)
	_check(mini.global_transform.is_equal_approx(placed_transform) and mini.velocity.is_zero_approx(),
		"Encounter retry restores the placed position and orientation with zero velocity")
	_check(mini.is_alive() and is_equal_approx(mini.health, 12.0) and is_zero_approx(mini._bite_windup_remaining)
		and is_zero_approx(mini._attack_cooldown) and is_zero_approx(mini._stagger_remaining),
		"Encounter retry cancels an unfinished attack and restores health")
	mini.take_damage(99.0)
	mini._physics_process(0.30)
	mini._on_stage_changed(MiniSpider.Progression.Stage.ENCOUNTER)
	mini.set_physics_process(false)
	_check(mini.is_alive() and is_zero_approx(mini._death_remaining) and mini.visible
		and mini._visual_root.rotation.is_equal_approx(mini._visual_rest_rotation)
		and mini.collision_layer == 4 and mini.collision_mask == 3,
		"Encounter retry restores a collapsed corpse to a live animated threat")
	mini.position = Vector3(-2.0, 0.42, 1.0)
	mini.activate(target)
	mini.set_physics_process(false)
	_check(mini.position.is_equal_approx(Vector3(-2.0, 0.42, 1.0)),
		"Manual activation retains the caller-selected position")
	var dead_target := HealthOnlyProbe.new()
	world.add_child(dead_target)
	dead_target.position = mini.position + Vector3.RIGHT * 0.4
	mini.activate(dead_target)
	mini.set_physics_process(false)
	mini._physics_process(0.30)
	_check(mini.combat_state == MiniSpider.CombatState.WAITING and dead_target.hits == 0,
		"A zero-health target without a recovery method cannot trigger pursuit or bite")
	mini.deactivate()
	mini._bite_audio.stream = null
	await create_timer(0.25).timeout
	world.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print(JSON.stringify({"suite": "juvenile combat", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
