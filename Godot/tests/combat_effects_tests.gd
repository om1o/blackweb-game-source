extends SceneTree
const Spider = preload("res://scripts/spider.gd")
const Mini = preload("res://scripts/mini_spider.gd")
const Effects = preload("res://scripts/combat_effects.gd")
var checks := 0
var failures: Array[String] = []

class Target extends Node3D:
	var health := 100.0
	var hits := 0
	func take_damage(amount: float) -> void:
		health = maxf(0.0, health - amount)
		hits += 1

func _initialize() -> void: call_deferred("_run")
func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 0.4, 40.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.2
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	var target := Target.new()
	world.add_child(target)
	target.position = Vector3(20, 0, 0)
	var adult = Spider.new()
	adult.auto_bind_progression = false
	adult.mesh_scene = load("res://scenes/spider_visual.tscn")
	adult.idle_animation = &"idle"
	world.add_child(adult)
	var juvenile = Mini.new()
	juvenile.auto_bind_progression = false
	world.add_child(juvenile)
	await process_frame
	adult.activate(target)
	juvenile.activate(target)
	adult.set_physics_process(false)
	juvenile.set_physics_process(false)
	var pool = adult._combat_effects
	_check(pool == juvenile._combat_effects and world.get_node("BlackwebCombatEffects") == pool,
		"Adult and juvenile reuse one shared world effect pool")
	_check(pool._slots.size() == 4 and pool.get_child_count() == 8 and not pool.is_physics_processing(),
		"Idle pool has four emitters and four audio voices with no per-frame script work")
	var particle_budget := 0
	var natural := true
	for slot in pool._slots:
		var particles: CPUParticles3D = slot.particles
		particle_budget += particles.amount
		var material: StandardMaterial3D = particles.mesh.material
		natural = natural and particles.one_shot and particles.lifetime <= 0.34 and not particles.local_coords
		natural = natural and not material.emission_enabled and particles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(particle_budget == 32 and natural, "Effects cap at thirty-two short world-space particles without emission or shadows")
	adult._set_state(Spider.State.WINDUP)
	adult._update_attack_tell()
	_check(not adult._attack_tell_light.visible and is_zero_approx(adult._attack_tell_light.light_energy),
		"Normal spider windup has no magical red attack light")
	adult._set_state(Spider.State.LUNGING)
	adult._update_attack_tell()
	_check(not adult._attack_tell_light.visible and is_zero_approx(adult._attack_tell_light.light_energy),
		"Normal spider strike keeps the attack light disabled")
	var adult_spheres: Array[Dictionary] = adult.get_hurt_spheres()
	var juvenile_spheres: Array[Dictionary] = juvenile.get_hurt_spheres()
	_check(adult_spheres.size() == 2 and is_equal_approx(adult_spheres[0].radius, 0.22)
		and is_equal_approx(adult_spheres[1].radius, 0.25), "Adult hurt spheres cover the two measured body sections")
	_check(juvenile_spheres.size() == 2 and is_equal_approx(juvenile_spheres[0].radius, 0.095)
		and is_equal_approx(juvenile_spheres[1].radius, 0.12), "Juvenile gets appropriately smaller head and abdomen hurt spheres")
	_check((adult_spheres[0].center as Vector3).y > 0.25 and (adult_spheres[1].center as Vector3).y > 0.25,
		"Adult body hurt spheres use the visible torso height instead of a floor point")
	_check((juvenile_spheres[0].center as Vector3).z < (juvenile_spheres[1].center as Vector3).z,
		"Juvenile body hurt spheres follow the corrected forward-facing model")
	var local_before: Vector3 = adult.to_local(adult_spheres[0].center)
	adult.rotation.y = 0.9
	adult.position = Vector3(2, 0, 1)
	_check(adult.to_local(adult.get_hurt_spheres()[0].center).is_equal_approx(local_before),
		"Hurt volumes follow actor translation and turning without changing movement collision")
	var adult_body := adult.get_child(0) as CollisionShape3D
	var juvenile_body := juvenile.get_child(0) as CollisionShape3D
	_check(adult_body != null and is_equal_approx(adult_body.shape.radius, 0.32)
		and juvenile_body != null and is_equal_approx(juvenile_body.shape.radius, 0.13),
		"Movement capsule radii remain unchanged for door and route clearance")
	var contact: Vector3 = adult.get_hurt_spheres()[0].center + Vector3.LEFT * 0.22
	adult.receive_hit(4.0, contact, Vector3.LEFT)
	_check(is_equal_approx(adult.health, 96.0) and pool.active_count() == 1,
		"An accepted worn-knife hit produces one restrained effect and four damage")
	var slot: Dictionary = pool._slots[0]
	_check((slot.particles as CPUParticles3D).global_position.is_equal_approx(contact)
		and (slot.audio as AudioStreamPlayer3D).global_position.is_equal_approx(contact),
		"Particle and sound originate at the actual supplied world contact")
	adult.position += Vector3.RIGHT * 2.0
	_check((slot.particles as CPUParticles3D).global_position.is_equal_approx(contact),
		"Moving the creature does not drag a previous impact through space")
	pool.clear_all()
	var count_before: int = pool.emitted_count
	adult.armor = 10.0
	adult.receive_hit(4.0, contact, Vector3.LEFT)
	adult.receive_hit(NAN, contact, Vector3.LEFT)
	adult.armor = 0.0
	_check(pool.emitted_count == count_before and is_equal_approx(adult.health, 96.0),
		"Absorbed or invalid damage produces no false impact feedback")
	for index in 100: pool.burst(adult, contact, Vector3.UP)
	_check(pool.active_count() == 4 and pool.get_child_count() == 8,
		"A burst storm reuses four slots without spawning unbounded particles or audio nodes")
	pool._physics_process(0.4)
	_check(pool.active_count() == 0 and not pool.is_physics_processing(),
		"All slots retire after their short lifetime and the pool stops processing")
	pool.burst(adult, contact, Vector3.UP)
	pool.burst(juvenile, juvenile.position + Vector3.UP * 0.16, Vector3.UP)
	adult.activate(target)
	adult.set_physics_process(false)
	_check(pool.active_count() == 1, "Resetting one enemy cancels its effects without deleting another enemy's feedback")
	juvenile._on_stage_changed(Mini.Progression.Stage.ENCOUNTER)
	juvenile.set_physics_process(false)
	_check(pool.active_count() == 0, "Juvenile checkpoint restart cancels its outstanding effects")
	pool.burst(adult, contact, Vector3.UP)
	paused = true
	await create_timer(0.05, true).timeout
	_check(pool.active_count() == 0, "Pausing immediately clears particle and sound feedback")
	pool.burst(adult, contact, Vector3.UP)
	_check(pool.active_count() == 0, "Paused gameplay cannot start new feedback")
	paused = false
	pool.clear_all()
	adult.receive_hit(999.0, contact, Vector3.LEFT)
	_check(pool.active_count() == 1 and pool._slots[0].kind == &"death" and adult.get_hurt_spheres().is_empty(),
		"Fatal damage produces one death burst and removes the adult hurt volumes")
	count_before = pool.emitted_count
	adult.receive_hit(4.0, contact, Vector3.LEFT)
	_check(pool.emitted_count == count_before, "A corpse cannot emit repeated hit effects")
	pool.clear_all()
	juvenile.position = Vector3(-0.2, 0.025, 0.0)
	juvenile.walk_speed = 0.0
	juvenile.hit_damage = 4.0
	target.position = Vector3(0.2, 0.025, 0.0)
	juvenile.activate(target)
	juvenile.set_physics_process(false)
	juvenile._physics_process(0.01)
	juvenile._physics_process(0.30)
	_check(target.hits == 1 and pool.active_count() == 1 and pool._slots[0].kind == &"contact",
		"A successful juvenile bite emits a single contact burst at the player")
	count_before = pool.emitted_count
	juvenile._physics_process(0.10)
	_check(target.hits == 1 and pool.emitted_count == count_before,
		"Bite recovery cannot repeat either contact damage or its effect")
	pool.clear_all()
	adult.deactivate()
	juvenile.deactivate()
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print(JSON.stringify({"suite": "normal spider effects and hurt volumes", "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
