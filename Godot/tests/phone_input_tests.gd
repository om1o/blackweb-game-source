extends SceneTree
## Native input, physical focus rays, real sound routing, and a fresh attempt.
const ProgressionScript = preload("res://scripts/progression.gd")
const InteractionScript = preload("res://scripts/interaction.gd")
const SoundScript = preload("res://scripts/soundscape.gd")

class TestPlayer extends BlackwebPlayer:
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 1
		pivot = Node3D.new()
		pivot.position.y = 1.48
		add_child(pivot)
		camera = Camera3D.new()
		camera.current = true
		pivot.add_child(camera)
		lamp = SpotLight3D.new()
		camera.add_child(lamp)
		_item_audio = ItemAudio.new()
		add_child(_item_audio)
	func _physics_process(_delta: float) -> void:
		if active: _update_focus()

var rows: Array[Dictionary] = []
var failures := 0
var player: BlackwebPlayer
var story: BlackwebProgression
var sound: Node3D

func _initialize() -> void: call_deferred("_run")

func check(value: bool, label: String) -> void:
	rows.append({"label": label, "passed": value})
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "Native display supports captured mouse input")
	for action in ["interact", "flashlight", "hotbar_1", "hotbar_2", "hotbar_3"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var stage := Node3D.new()
	root.add_child(stage)
	story = ProgressionScript.new()
	story.auto_load = false
	story.auto_save = false
	story.auto_advance_atmosphere = false
	stage.add_child(story)
	player = TestPlayer.new()
	player.progression = story
	stage.add_child(player)
	story.player = player
	player.active = true
	player.health = 45.0
	var phone := InteractionScript.new()
	phone.kind = &"phone"
	phone.progression = story
	phone.position = Vector3(0, 1.1, -1.3)
	stage.add_child(phone)
	sound = SoundScript.new()
	sound.player = player
	sound.progression = story
	sound.phone_position = phone.position
	stage.add_child(sound)
	player.camera.look_at(phone.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	player._update_focus()
	check(player._focused == phone and "CLICK" in phone.prompt(), "Real camera/reach rays find a phone advertising click or E")
	player.select_quick_slot(2)
	var candy_before := player.item_count(&"candy_bar")
	var light_before := player._light_on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Native window captures the mouse")
	sound._phone_timer = 0.0
	sound._process(0.01)
	check(sound._phone.playing and sound._phone.stream.get_length() > 1.2 and sound._phone.volume_db >= -8.0, "Recognizable double ring plays before answering at an audible gain")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var bus := AudioServer.get_bus_index(SoundScript.DIALOGUE_BUS)
	AudioServer.add_bus_effect(bus, capture)
	await _click()
	check(story.stage == story.Stage.MESSAGE and sound._mara_warning.playing, "Parsed left click on the physical phone starts Mica's actual voice")
	check(not sound._phone.playing and "speaking" in phone.prompt(), "Answering stops ringing and changes the physical prompt")
	check(player.item_count(&"candy_bar") == candy_before and player._action_kind == &"" and player.health == 45.0 and player._light_on == light_before, "Answering neither eats candy nor toggles the held flashlight")
	await create_timer(.4).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(frames.size() > 1000 and peak > .02, "Phone voice produces real nonzero mixer samples after mouse input")
	var elapsed := story._elapsed
	await _click()
	check(story._elapsed >= elapsed and player._action_kind == &"", "Clicking again cannot restart dialogue or use a supply")
	paused = true
	var before_pause := story._elapsed
	await create_timer(.2, true).timeout
	check(is_equal_approx(before_pause, story._elapsed), "Menu pause freezes the current phone attempt")
	paused = false
	story.restart_opening()
	await process_frame
	check(story.stage == story.Stage.NORMAL and not sound._mara_warning_played and not sound._mara_warning.playing, "New Game resets the phone stage and spoken-once flags")
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	Input.flush_buffered_events()
	await process_frame
	check(story.stage == story.Stage.MESSAGE and sound._mara_warning.playing, "The E action also answers the phone after New Game")
	var release := interact.duplicate() as InputEventAction
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var report_path := ProjectSettings.globalize_path("res://").path_join("../Evidence/phone-input-tests.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": rows.size(), "failures": failures, "results": rows, "audio": sound.get_audio_status(), "mixed_peak": peak, "limitations": "Native input and mixer evidence; physical speaker audibility still depends on Windows output and volume."}, "  "))
		file.close()
	sound._on_recovery(true)
	stage.queue_free()
	await process_frame
	print("Phone input: %d checks, %d failures" % [rows.size(), failures])
	quit(0 if failures == 0 else 1)

func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_visible_rect().size * .5
	event.global_position = event.position
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
