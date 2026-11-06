extends SceneTree
## Runs the assembled house route. --visual also captures the actual UI viewport.
var game: Node
var failures: Array[String] = []
var checks := 0
var visual := false
var output := ""

func _initialize() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	output = ProjectSettings.globalize_path("user://qa/tutorial-journey")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _capture(label: String) -> void:
	if not visual: return
	await create_timer(0.3, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	print("JOURNEY: loading scene resource")
	game = load("res://scenes/main.tscn").instantiate()
	print("JOURNEY: scene instantiated")
	game.qa_mode = true
	root.add_child(game)
	await process_frame
	print("JOURNEY: first process frame")
	if visual:
		game.menu.hide()
		var intro = load("res://scripts/tutorial_intro.gd").new()
		root.add_child(intro)
		_check(intro.begin(game.player, game.status_hud.get_parent()), "arrival starts on actual house camera")
		var before_intro: float = game.progression._elapsed
		await create_timer(3.2, true).timeout
		_check(is_equal_approx(game.progression._elapsed,before_intro) and paused, "cinematic holds house progression and phone timing until control returns")
		await _capture("arrival-intro")
		intro.skip()
		intro.queue_free()
	game._resume()
	_check(game.player.inventory.slots.size() == 50, "50 backpack cells")
	_check(game.player.inventory.occupied_count() == 3, "three original starting tools")
	_check(game.player.equipped_items().size() == 3, "three quick slots")
	_check(not game._sighting_spider.visible and not game.player._flashlight_flicker_allowed(), "quiet arrival keeps spiders hidden and the starter torch steady")
	_check(game.player._armor_visuals != null and not game.player._armor_visuals.visual_state().values().has(true), "fresh character has four bound but unequipped garments")
	_key(KEY_I)
	await process_frame
	_check(game.status_hud.is_inventory_open() and paused and not game.player.active, "I opens paused inventory through input pipeline")
	await process_frame
	await process_frame
	_check(game._item_preview != null and game.status_hud._inventory_preview.texture != null, "actual flashlight model reaches the inventory preview")
	_key(KEY_I)
	await process_frame
	_check(not game.status_hud.is_inventory_open() and not paused and game.player.active, "I closes inventory through input pipeline")
	var note = game.get_node("PlantCodeNote")
	var arrival_position: Vector3 = game.player.global_position
	var arrival_rotation: Vector3 = game.player.camera.global_rotation
	game.player.global_position = Vector3(1.7, .44, 2.3)
	game.player.camera.look_at(note.global_position)
	await physics_frame
	game.player._update_focus()
	_check(note.folded_in_world and note.get_node_or_null("FoldedNoteFlap") != null, "plant clue conceals its code inside a physical fold")
	_check(game.player._focused == note, "real camera and reach rays acquire the plant clue")
	var paper_click := InputEventMouseButton.new()
	paper_click.button_index = MOUSE_BUTTON_LEFT
	paper_click.position = root.get_visible_rect().size * .5
	paper_click.global_position = paper_click.position
	paper_click.button_mask = MOUSE_BUTTON_MASK_LEFT
	paper_click.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.parse_input_event(paper_click)
	Input.flush_buffered_events()
	await process_frame
	paper_click = paper_click.duplicate()
	paper_click.pressed = false
	paper_click.button_mask = 0
	Input.parse_input_event(paper_click)
	Input.flush_buffered_events()
	await process_frame
	_check(game.field_overlay.visible and game.field_overlay.mode == "paper" and paused, "paper opens readable modal")
	_check(game.campaign.code_found, "hidden plant paper records discovery")
	await _capture("paper-closeup")
	_key(KEY_ENTER)
	await process_frame
	_check(not paused and not game.field_overlay.visible, "focused paper close works with keyboard Enter")
	game.player.global_position = arrival_position
	game.player.camera.global_rotation = arrival_rotation
	var door = game.get_node("RearNorthDoor")
	_check(door.locked and not door.opened, "vault starts physically locked")
	door.toggle()
	_check(game.field_overlay.mode == "vault" and not door.opened, "locked door opens keypad instead of hinge")
	game._submit_vault_code("0417")
	_check(not game.campaign.vault_unlocked, "correct code without key denied")
	game.field_overlay.close_overlay()
	game.progression.interact(&"phone")
	if visual:
		var call_deadline := Time.get_ticks_msec() + 20000
		while game.progression.stage == game.progression.Stage.MESSAGE and Time.get_ticks_msec() < call_deadline:
			await process_frame
		_check(game.progression.stage != game.progression.Stage.MESSAGE, "the actual phone audio and subtitle sequence completes within twenty seconds")
	else:
		game.progression.step(20.0)
	_check(game.progression.warning_heard and game.progression.stage == game.progression.Stage.PREPARATION, "Mica warning reaches preparation")
	var prior_rotation: Vector3 = game.player.camera.global_rotation
	game.player.camera.look_at(game.EARLY_SPIDER_START.lerp(game.EARLY_SPIDER_END, 0.5) + Vector3.UP * .16)
	game.progression._elapsed = 6.1
	await physics_frame
	game._update_early_sighting(.1)
	_check(game._sighting_spider.visible and game._early_sighting_time > 0 and not game.campaign.vault_unlocked, "early visible spider does not require solving the vault")
	await _capture("early-spider")
	game.player.camera.global_rotation = prior_rotation
	game.progression.interact(&"keys")
	game.progression.interact(&"flashlight")
	_check(game.progression.stage == game.progression.Stage.PREPARATION, "vault puzzle gates encounter")
	game._inspect_vault()
	game._submit_vault_code("9999")
	_check(door.locked and not game.campaign.vault_unlocked, "wrong code denied with key")
	await _capture("vault-keypad")
	for code in [KEY_KP_0, KEY_KP_4, KEY_KP_1, KEY_KP_7]: _key(code)
	await process_frame
	_check(game.field_overlay.digits == "0417", "numpad input preserves leading zero without Unicode")
	_key(KEY_KP_ENTER)
	await process_frame
	_check(game.campaign.vault_unlocked and not door.locked and door.opened, "key plus correct code opens real door")
	_check(game.progression.stage == game.progression.Stage.PREPARATION, "vault unlock preserves the initial exploration beat")
	game.progression.step(game.progression.exploration_seconds)
	_check(game.progression.stage == game.progression.Stage.PRESENCE and game._sighting_spider.visible, "prepared exploration leads to the first harmless sighting")
	game.get_node("VaultFieldKit").interact()
	await _capture("vault-leather-kit")
	for item in game.CampaignScript.ARMOR:
		game._claim_armor(item)
		game._claim_armor(item)
		_check(game.player.item_count(item) == 1, "armor grant is once: " + str(item))
	_check(game.player.inventory.occupied_count() == 7, "four armor pieces consume four cells")
	game.field_overlay.close_overlay()
	for index in range(50):
		if game.player.inventory.is_armor(game.player.inventory.item_at(index)):
			game.status_hud._select_cell(index)
			game.status_hud._armor_equip_button.pressed.emit()
			_check(game.player.get_armor_state().values().has(game.player.inventory.item_at(index)), "selected armor equips through inventory button")
	_check(is_equal_approx(game.player.armor_reduction_percent(), 18.0), "full leather kit yields18percent")
	_check(game.player.equipped_items() == [&"flashlight", &"knife", &"candy_bar"], "armor preserves three quick tools")
	_check(game.player._armor_visuals.visual_state().values().count(true) == 4, "equipping the kit shows all four fitted clothing meshes")
	game.get_node("VaultCash").interact()
	game.get_node("VaultCash").interact()
	_check(game.campaign.wallet == 120 and game.get_node("VaultCash").taken, "cash awarded once and removed")
	_key(KEY_I)
	await _capture("armor-inventory")
	_key(KEY_I)
	game.player.health = 60.0
	game.player.health_changed.emit(60.0)
	game.player.select_quick_slot(2)
	if visual:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		await create_timer(1.5, false).timeout
		_check(game.player.health == 90.0 and game.player.item_count(&"candy_bar") == 0, "native input candy click heals30 once")
	game.player.select_quick_slot(0)
	var snapshot: Dictionary = game.player.survival_snapshot()
	var world := {"seed": 5, "pickups": {}, "storage": {}}
	game.campaign.save_path = output + "/isolated-campaign.json"
	_check(game.campaign.save_state(game.progression.snapshot(), snapshot, world), "complete story and inventory saved atomically")
	var restored = game.CampaignScript.new()
	restored.save_path = game.campaign.save_path
	_check(restored.load_state() and restored.wallet == 120 and restored.vault_unlocked and restored.claimed.size() == 5, "cash vault and four claims restored together")
	_check(game.player.restore_survival_state(restored.loaded.survival), "restored survival state accepted")
	_check(game.player.armor_reduction_percent() == 18.0, "armor loadout survives save")
	_check(game.player._armor_visuals.visual_state().values().count(true) == 4, "restoring equipped armor also restores its worn appearance")
	await _capture("house-after-vault")
	# Run the production restart path after acquiring gear and cash. This catches
	# stale world claims and already-open vaults that isolated menu tests cannot.
	game._restart()
	await process_frame
	_check(game.player.active and not paused and not game.menu.visible, "New Game returns to active gameplay")
	_check(game.progression.stage == game.progression.Stage.NORMAL and not game.progression.warning_heard, "New Game restores Mica's unanswered call")
	_check(not game._sighting_spider.visible and not game.player._flashlight_flicker_allowed(), "New Game restores the quiet opening without stale scares")
	_check(game.campaign.wallet == 0 and not game.campaign.code_found and not game.campaign.vault_unlocked and game.campaign.claimed.is_empty(), "New Game resets wallet code vault and one-time claims")
	_check(game.player.inventory.occupied_count() == 3 and game.player.armor_reduction_percent() == 0.0 and game.player.item_count(&"candy_bar") == 1, "New Game restores three starters and removes acquired armor")
	_check(not game.player._armor_visuals.visual_state().values().has(true), "New Game removes the worn armor meshes")
	_check(is_equal_approx(game.player.health, 100.0) and game.player.battery_charge > 21.8 and game.player.battery_charge <= 22.0, "New Game resets health stamina and starting battery")
	_check(door.locked and not door.opened and not game.get_node("VaultCash").taken, "New Game physically closes the vault and restores cash")
	_key(KEY_ESCAPE)
	await process_frame
	_check(game.menu.visible and paused and not game.player.active, "Escape opens the new pause menu after restart")
	_key(KEY_ESCAPE)
	await process_frame
	_check(not game.menu.visible and not paused and game.player.active, "Escape resumes the same fresh run")
	if visual and OS.get_cmdline_user_args().has("--profile-graphics"):
		await load("res://tests/graphics_profile.gd").new().run(game, self, output)
	var report := {"checks": checks, "failed": failures.size(), "failures": failures, "visual": visual}
	var file := FileAccess.open(output + "/tutorial-journey-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
