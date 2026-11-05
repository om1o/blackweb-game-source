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
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)

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
		await create_timer(3.2, true).timeout
		await _capture("arrival-intro")
		intro.skip()
		intro.queue_free()
	game._resume()
	_check(game.player.inventory.slots.size() == 50, "50 backpack cells")
	_check(game.player.inventory.occupied_count() == 3, "three original starting tools")
	_check(game.player.equipped_items().size() == 3, "three quick slots")
	_key(KEY_I)
	await process_frame
	_check(game.status_hud.is_inventory_open() and paused and not game.player.active, "I opens paused inventory through input pipeline")
	_key(KEY_I)
	await process_frame
	_check(not game.status_hud.is_inventory_open() and not paused and game.player.active, "I closes inventory through input pipeline")
	game.get_node("PlantCodeNote").interact()
	await process_frame
	_check(game.field_overlay.visible and game.field_overlay.mode == "paper" and paused, "paper opens readable modal")
	_check(game.campaign.code_found, "hidden plant paper records discovery")
	await _capture("paper-closeup")
	_key(KEY_ENTER)
	await process_frame
	_check(not paused and not game.field_overlay.visible, "focused paper close works with keyboard Enter")
	var door = game.get_node("RearNorthDoor")
	_check(door.locked and not door.opened, "vault starts physically locked")
	door.toggle()
	_check(game.field_overlay.mode == "vault" and not door.opened, "locked door opens keypad instead of hinge")
	game._submit_vault_code("0417")
	_check(not game.campaign.vault_unlocked, "correct code without key denied")
	game.field_overlay.close_overlay()
	game.progression.interact(&"phone")
	game.progression.step(20.0)
	_check(game.progression.warning_heard and game.progression.stage == game.progression.Stage.PREPARATION, "Mica warning reaches preparation")
	game.progression.interact(&"keys")
	game.progression.interact(&"flashlight")
	_check(game.progression.stage == game.progression.Stage.PREPARATION, "vault puzzle gates encounter")
	game._inspect_vault()
	game._submit_vault_code("9999")
	_check(door.locked and not game.campaign.vault_unlocked, "wrong code denied with key")
	await _capture("vault-keypad")
	game._submit_vault_code("0417")
	_check(game.campaign.vault_unlocked and not door.locked and door.opened, "key plus correct code opens real door")
	_check(game.progression.stage == game.progression.Stage.PRESENCE, "unlocked vault advances story")
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
	await _capture("house-after-vault")
	var report := {"checks": checks, "failed": failures.size(), "failures": failures, "visual": visual}
	var file := FileAccess.open(output + "/tutorial-journey-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
