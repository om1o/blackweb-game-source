extends SceneTree
var game: Node
var checks := 0
var failures: Array[String] = []
var visual := false
var output := "D:/CodexTemp/Blackweb-EscapePass/escape"

func _initialize() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	_run.call_deferred()

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures.append(title)
		push_error(title)

func shot(label: String) -> void:
	if not visual: return
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")

func aim_at(point: Vector3) -> void:
	var toward: Vector3 = point-game.player.global_position
	game.player.camera.rotation = Vector3.ZERO
	game.player.set_view(atan2(-toward.x,-toward.z))
	game.player._pitch = -.32

func knife_click() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Escape mouse-input checks require a native window: omit --headless.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	game._resume()
	game.progression.auto_advance_atmosphere = false
	game.set_process(false)
	check(game._loaded,"Five-room house loads")
	check(game.house_map.room_at(Vector3(8,.44,2)) == 4,"Expanded vault maps correctly")
	check(game._room_spiders.size()==2,"Two staged exploration spiders added")
	check(not game.progression.has_exit_keys and not game.progression.exit_web_cleared,"Exit starts locked and webbed")
	check(not game.progression.collect_exit_keys(),"Exit keys cannot be claimed before the vault opens")
	check(game.get_node("LeatherKitContents").get_child_count()==4,"Vault shows four actual garment meshes")
	check(game.get_node("FrontLockWeb").visible,"Physical strands cover the lock")
	check(game.has_node("ContainmentDrum"),"Optimized Meshy containment model is in the lore room")
	check(["Crouch_Fwd_Loop", "Crouch_Idle_Loop", "Jump_Loop", "Hit_Chest", "Sword_Attack"].all(func(id): return game.player._pinoc_motion.clips.has(id)),"Current authored locomotion, reaction and attack samples are loaded")
	game.progression.warning_heard = true
	game.progression._set_stage(game.progression.Stage.PREPARATION)
	game.progression.interact(&"keys")
	game.progression.interact(&"flashlight")
	game._inspect_vault()
	game._submit_vault_code("0416")
	check(not game.campaign.vault_unlocked,"Wrong code keeps vault locked")
	game._submit_vault_code("0417")
	check(game.campaign.vault_unlocked and game.get_node("RearNorthDoor").opened,"Key plus code opens vault")
	game.player.global_position=Vector3(7.1,.44,2.2)
	aim_at(Vector3(7.9,1.0,1.25))
	game.player._pitch = -.72
	await shot("vault-models")
	check(game.player.camera.global_position.y<2.75,"Looking down keeps the gameplay camera below ceiling webs")
	game.get_node("VaultExitKeys").interact()
	check(game.progression.has_exit_keys and game.get_node("VaultExitKeys").taken,"Exit key pickup grants distinct key and disappears")
	game.player.global_position=Vector3(-3.95,.44,.42)
	game.player.select_quick_slot(1)
	aim_at(game.get_node("FrontLockWeb").global_position)
	await physics_frame
	await shot("lock-before-cut")
	knife_click()
	await create_timer(game.player.KNIFE_ACTION_DURATION + .15).timeout
	check(game.get_node("FrontLockWeb").health == 4,"Mouse click drives knife animation and strikes the webbed lock")
	check(not game.progression.exit_web_cleared,"First cut weakens silk without clearing it")
	knife_click()
	await create_timer(game.player.KNIFE_ACTION_DURATION + .15).timeout
	check(game.get_node("FrontLockWeb").health == 0,"Second mouse-driven knife strike reaches lock")
	check(game.progression.exit_web_cleared and not game.get_node("FrontLockWeb").visible,"Second cut removes physical obstruction")
	var saved: Dictionary=game.progression.snapshot()
	game.progression.has_exit_keys=false
	game.progression.exit_web_cleared=false
	check(game.progression.restore_snapshot(saved),"Escape objective saves restore")
	check(game.progression.has_exit_keys and game.progression.exit_web_cleared,"Key and cut state persist")
	game.player.global_position=Vector3(1.7,.44,-1.5)
	game._update_room_spiders()
	check(game._room_spiders[0].active,"Supply-room spider activates on visible approach")
	game._room_spiders[0].deactivate()
	game.player.global_position=Vector3(4.9,.44,-2.0)
	game._update_room_spiders()
	check(game._room_spiders[1].active,"Rear-room spider activates independently")
	game._room_spiders[1].deactivate()
	game.progression._set_stage(game.progression.Stage.ENCOUNTER)
	game.progression.resolve_encounter()
	check(game.progression.can_interact(&"exit"),"Escape requires cleared encounter, actual exit keys and cut silk")
	game.progression.exit_web_cleared=false
	check(not game.progression.can_interact(&"exit"),"Web obstruction independently blocks escape")
	game.progression.exit_web_cleared=true
	game.progression.has_exit_keys=false
	check(not game.progression.can_interact(&"exit"),"Vault key cannot substitute for exit keys")
	game.progression.has_exit_keys=true
	game.player.global_position=Vector3(-3.95,.44,.42)
	aim_at(Vector3(-5.08,1.2,.4))
	await shot("escape-ready")
	game._leave_house()
	await create_timer(3.0,true).timeout
	check(game.progression.departed,"Real exit animation completes the opening")
	game._restart()
	await process_frame
	check(not game.progression.has_exit_keys and not game.progression.exit_web_cleared,"New Game resets both new escape milestones")
	check(not game.get_node("VaultExitKeys").taken and game.get_node("FrontLockWeb").visible,"New Game restores keys and door silk")
	check(game.get_node("LeatherKitContents").get_children().all(func(n):return n.visible),"New Game restores kit display")
	check(game.get_node("StoryVoice")._data.size()==3,"All three discovery voice assets load")
	game.get_node("FrontLockWeb").health=4.0
	game._restart()
	check(game.get_node("FrontLockWeb").health==8.0,"New Game also resets partially cut silk")
	var report: Dictionary={"checks":checks,"failed":failures.size(),"failures":failures,"visual":visual}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	paused=false
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
