extends SceneTree
## Attribution probe, not a playthrough. No persistent game/source mutation.

class ActorProbe extends Node:
	var target: Node
	var controller
	var label := ""
	func _physics_process(delta: float) -> void:
		# All actors are activated before wrapping. Their child AnimationPlayers
		# continue normally. Replacing only the script callback avoids double work.
		target.set_physics_process(false)
		var should_call := true
		if target is BlackwebSpider: should_call = target.state not in [target.State.DORMANT, target.State.RESOLVED]
		elif target is BlackwebMiniSpider: should_call = target.active or target._death_remaining > 0.0
		if not should_call: return
		if controller.trace_mini_move and target is BlackwebMiniSpider:
			target.set("_vault_move_usec", 0)
		var begin := Time.get_ticks_usec()
		target._physics_process(delta)
		var cost := Time.get_ticks_usec() - begin
		target.set_physics_process(false)
		if controller.measuring:
			controller.actor_costs[label] = cost
			if controller.trace_mini_move and target is BlackwebMiniSpider:
				var contacts: Array = []
				for index in target.get_slide_collision_count():
					var hit: KinematicCollision3D = target.get_slide_collision(index)
					contacts.append({"body": str(hit.get_collider().get_path()) if hit.get_collider() is Node else str(hit.get_collider()), "normal": controller._vec(hit.get_normal())})
				controller.actor_details[label] = {"move_usec": target.get("_vault_move_usec"), "feet": controller._vec(target.position), "velocity": controller._vec(target.velocity), "contacts": contacts}

class PhaseBoundary extends Node:
	var controller
	var first := false
	func _physics_process(delta: float) -> void:
		if first: controller._begin_physics(delta)
		else: controller._end_physics()

const LOCATIONS := [
	{"name": "entry", "feet": Vector3(-2.2, 0.425, 0.0)},
	{"name": "record", "feet": Vector3(1.2, 0.425, 1.8)},
	{"name": "vault", "feet": Vector3(5.4, 0.425, 1.8)},
	{"name": "supply", "feet": Vector3(1.4, 0.425, -1.6)},
	{"name": "infested", "feet": Vector3(5.4, 0.425, -1.6)}
]
var game: Node3D
var measuring := false
var room := "setup"
var actor_costs: Dictionary = {}
var actor_details: Dictionary = {}
var rows: Array = []
var physics_rows: Array = []
var output := "D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/vault-phase-probe.json"
var seconds := 4.0
var settle_seconds := 1.0
var physics_begin := 0
var previous_frame := 0
var render_begin := 0
var last_render_span := 0
var phase_start := 0
var yaw := 0.0
var rooms_filter := ""
var disable_occlusion := false
var instrument_actors := true
var trace_mini_move := false
var legacy_pursuit := false
var report := {"kind": "per-room callback/renderer attribution probe", "phases": [], "actors": [], "failures": []}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--settle="): settle_seconds = float(arg.trim_prefix("--settle="))
		if arg.begins_with("--rooms="): rooms_filter = arg.trim_prefix("--rooms=")
		if arg == "--no-occlusion": disable_occlusion = true
		if arg == "--no-actor-probes": instrument_actors = false
		if arg == "--trace-mini-move": trace_mini_move = true
		if arg == "--legacy-through-wall-pursuit": legacy_pursuit = true
	if not output.replace("\\", "/").begins_with("D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/"):
		quit(3)
		return
	if trace_mini_move or legacy_pursuit:
		# Modify a loaded Script resource in memory only. The on-disk production
		# file and its behavior stay intact; two timestamps surround the builtin.
		var mini_script := load("res://scripts/mini_spider.gd") as GDScript
		var instrumented := mini_script.source_code
		if legacy_pursuit:
			var current_condition := "toward.length() < awareness_radius and _can_see_target()"
			if not instrumented.contains(current_condition):
				printerr("Expected current pursuit expression missing; refusing invalid legacy control")
				quit(5)
				return
			instrumented = instrumented.replace(current_condition, "toward.length() < awareness_radius")
		if trace_mini_move:
			instrumented = instrumented.replace("var health :=", "var _vault_move_usec := 0\nvar health :=")
			for depth in [2, 1]:
				var indent := "\t".repeat(depth)
				instrumented = instrumented.replace("\n" + indent + "move_and_slide()", "\n" + indent + "var _vault_move_begin := Time.get_ticks_usec()\n" + indent + "move_and_slide()\n" + indent + "_vault_move_usec += Time.get_ticks_usec() - _vault_move_begin")
		mini_script.source_code = instrumented
		if mini_script.reload(true) != OK:
			printerr("In-memory move scope failed to compile")
			quit(4)
			return
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for door in game._tutorial_doors:
		if not door.opened: door.toggle()
	game.player.health = 1000.0
	game.player.position = Vector3(1.2, 0.425, 1.8)
	game.progression._set_stage(game.progression.Stage.ENCOUNTER)
	if disable_occlusion: root.use_occlusion_culling = false
	await create_timer(1.5).timeout
	if instrument_actors:
		var actors: Array = [game.player, game.spider]
		for mini in get_nodes_in_group("mini_spider"): actors.append(mini)
		for actor in actors:
			if not actor.is_physics_processing(): continue
			var probe := ActorProbe.new()
			probe.target = actor
			probe.controller = self
			probe.label = str(actor.name)
			probe.process_physics_priority = actor.process_physics_priority
			actor.set_physics_process(false)
			actor.get_parent().add_child(probe)
			actor.get_parent().move_child(probe, actor.get_index())
			report.actors.append(str(actor.get_path()))
	var first := PhaseBoundary.new()
	first.controller = self
	first.first = true
	first.process_physics_priority = -10000
	game.add_child(first)
	var last := PhaseBoundary.new()
	last.controller = self
	last.process_physics_priority = 10000
	game.add_child(last)
	process_frame.connect(_sample_frame)
	RenderingServer.frame_pre_draw.connect(func(): render_begin = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func(): last_render_span = Time.get_ticks_usec() - render_begin)
	var hashes := {}
	for file in ["main.gd", "player.gd", "spider.gd", "mini_spider.gd", "house_dressing.gd", "tutorial_house.gd"]:
		hashes[file] = FileAccess.get_sha256("res://scripts/" + file)
	report.metadata = {"utc": Time.get_datetime_string_from_system(true), "pid": OS.get_process_id(),
		"base_commit": "fc7a2bc06747978261610d88f8a066707159b989", "script_sha256": hashes,
		"headless": DisplayServer.get_name() == "headless", "engine": Engine.get_version_info(),
		"adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"window_size": [root.size.x, root.size.y], "vsync": DisplayServer.window_get_vsync_mode(),
		"msaa_3d": root.msaa_3d, "scale_3d": root.scaling_3d_scale,
		"occlusion_enabled": root.use_occlusion_culling, "actor_wrappers": instrument_actors,
		"in_memory_mini_move_timestamps": trace_mini_move,
		"legacy_through_wall_pursuit_control": legacy_pursuit, "settle_seconds_per_room": settle_seconds, "sample_seconds_per_room": seconds,
		"method": "Teleport only before a phase; settle for configured duration; pan at .8rad/s for timed phase. No timed I/O/screenshots. Actor callbacks are called once per physics tick by adjacent same-priority wrapper nodes; child animation/AI/collision preserved. Physics span brackets scene callbacks, excludes server step/message flush. Render span brackets RenderingServer signals and is not a GPU timer. Monitors are cached one-second maxima, not per-frame physics cost.",
		"limits": "Short attribution trace, not sustained performance or traversal proof. Wrapper scheduling/instrumentation adds overhead. Player gets1000HP solely to prevent reloads. NPCs retain normal HP/AI. Positions and states recorded to expose drift/deaths. Desktop/OS contention remains."}
	print("VAULT_PHASE_READY pid=", OS.get_process_id(), " headless=", report.metadata.headless, " actor_wrappers=", instrument_actors)
	for location in LOCATIONS:
		if not rooms_filter.is_empty() and not rooms_filter.split(",").has(location.name): continue
		room = location.name
		game.player.position = location.feet
		game.player.velocity = Vector3.ZERO
		game.player.set_view(0.0)
		yaw = 0.0
		await create_timer(settle_seconds).timeout
		var phase := {"room": room, "start_feet": _vec(game.player.position), "start_hp": game.player.health}
		phase_start = Time.get_ticks_usec()
		previous_frame = 0
		measuring = true
		await create_timer(seconds).timeout
		measuring = false
		phase.end_feet = _vec(game.player.position)
		phase.end_hp = game.player.health
		report.phases.append(phase)
	report.frame_rows = rows
	report.physics_rows = physics_rows
	report.summary = {}
	for location in LOCATIONS:
		var frame_values: Array = []
		var bracket_values: Array = []
		var render_values: Array = []
		var actor_values := {}
		for row in rows:
			if row.room == location.name:
				frame_values.append(row.frame_ms)
				render_values.append(row.render_span_ms)
		for row in physics_rows:
			if row.room != location.name: continue
			bracket_values.append(row.callback_span_usec)
			for key in row.actor_usec:
				if not actor_values.has(key): actor_values[key] = []
				actor_values[key].append(row.actor_usec[key])
		if frame_values.is_empty(): continue
		for key in actor_values: actor_values[key] = _stats(actor_values[key])
		report.summary[location.name] = {"frame_ms": _stats(frame_values), "callback_span_usec": _stats(bracket_values), "render_span_ms": _stats(render_values), "actor_usec": actor_values}
	report.metadata.viewport_texture_size_at_end = [root.get_texture().get_width(), root.get_texture().get_height()]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VAULT_PHASE_COMPLETE ", JSON.stringify(report.summary))
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_audio(game)
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	quit(0)

func _begin_physics(delta: float) -> void:
	if not measuring: return
	actor_costs = {}
	actor_details = {}
	yaw += delta * 0.8
	game.player.set_view(yaw)
	physics_begin = Time.get_ticks_usec()

func _end_physics() -> void:
	if not measuring or physics_begin == 0: return
	physics_rows.append({"room": room, "elapsed_ms": (Time.get_ticks_usec() - phase_start) / 1000.0,
		"callback_span_usec": Time.get_ticks_usec() - physics_begin, "actor_usec": actor_costs.duplicate(), "actor_details": actor_details.duplicate(true),
		"adult_state": game.spider.state, "feet": _vec(game.player.position), "health": game.player.health})

func _sample_frame() -> void:
	if not measuring: return
	var now := Time.get_ticks_usec()
	if previous_frame > 0:
		rows.append({"room": room, "elapsed_ms": (now - phase_start) / 1000.0, "frame_ms": (now - previous_frame) / 1000.0,
			"render_span_ms": last_render_span / 1000.0, "physics_monitor_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "health": game.player.health})
	previous_frame = now

func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var total := 0.0
	for value in values: total += float(value)
	return {"samples": values.size(), "mean": total / values.size(), "p50": values[ceili(values.size() * 0.5) - 1], "p95": values[ceili(values.size() * 0.95) - 1], "max": values.back()}

func _vec(value: Vector3) -> Array: return [value.x, value.y, value.z]

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): _stop_audio(child)
