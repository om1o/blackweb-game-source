extends SceneTree
## Native-only input regression: real camera/reach rays and the inherited mouse
## handler, with no house or held-model assets. No direct _focused assignment.

const PlayerScript = preload("res://scripts/player.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
const EvidenceScript = preload("res://scripts/tutorial_evidence.gd")
const OverlayScript = preload("res://scripts/field_overlay.gd")

class PaperTestPlayer extends BlackwebPlayer:
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

var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var opened := 0
var closed := 0
var stage: Node3D
var player: BlackwebPlayer
var note: BlackwebTutorialEvidence
var overlay: BlackwebFieldOverlay
var prior_mouse_mode: int
var before_modal: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	rows.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	prior_mouse_mode = Input.mouse_mode
	_check(DisplayServer.get_name() != "headless", "Fixture has a native display for captured mouse input")
	if failures > 0:
		await _finish()
		return
	for action in ["interact", "flashlight", "hotbar_1", "hotbar_2", "hotbar_3"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	stage = Node3D.new()
	root.add_child(stage)
	var progression := ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	progression.set_process(false)
	_box("Floor", Vector3(0, -0.05, 0), Vector3(6, 0.1, 6))
	_box("NoteStand", Vector3(0, 0.45, -1.3), Vector3(0.55, 0.9, 0.55))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -20, 0)
	stage.add_child(light)
	player = PaperTestPlayer.new()
	player.progression = progression
	stage.add_child(player)
	progression.player = player
	player.health = 55.0
	player.active = true
	note = EvidenceScript.new()
	note.name = "PhysicalPaper"
	note.title = "Mica's hidden note"
	note.record_text = "The vault code is 0417. This physical note opens on a left click."
	note.progression = progression
	note.position = Vector3(0, 0.96, -1.3)
	stage.add_child(note)
	note.discovered.connect(_open_paper)
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	overlay = OverlayScript.new()
	canvas.add_child(overlay)
	overlay.closed.connect(_close_paper)
	player.camera.look_at(note.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	await process_frame
	player._update_focus()
	_check(player._focused == note, "Camera ray and player reach ray acquire the physical paper")
	_check("CLICK" in player._focus_prompt, "Focused paper advertises the click interaction")
	_check(player.select_quick_slot(2) and player.selected_quick_item() == &"candy_bar", "Real equipped candy is selected at injured health")
	var candy_before := player.item_count(&"candy_bar")
	await _capture_mouse()
	await _click_left()
	_check(opened == 1 and overlay.visible and overlay.mode == "paper", "Parsed captured left click opens the real readable overlay once")
	_check(paused and not player.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Reading pauses the world and releases the mouse")
	_check(_contains_text(overlay, note.record_text), "Readable overlay contains the note's actual text")
	_check(overlay._paper_image.texture != null and overlay._paper_image.texture == EvidenceScript.document_texture(note.title) and overlay._paper_viewport.visible, "Physical paper click opens its actual generated document image")
	_check(player._action_kind == &"" and player.item_count(&"candy_bar") == candy_before and is_equal_approx(player.health, 55.0), "Paper click does not begin eating, consume candy, or heal")
	await _click_left()
	_check(opened == 1 and player._action_kind == &"" and player.item_count(&"candy_bar") == candy_before, "A click inside the paused readable cannot reach item use")
	overlay.close_overlay()
	await process_frame
	_check(closed == 1 and not overlay.visible and not paused and player.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Putting the paper down restores the prior gameplay and mouse state")
	_check(player.select_quick_slot(0) and player.selected_quick_item() == &"flashlight", "Real torch selection works after closing the paper")
	await physics_frame
	await process_frame
	player._update_focus()
	_check(player._focused == note, "The physical note is reacquired after closing")
	var light_before := player._light_on
	var charge_before := player.battery_charge
	await _click_left()
	_check(opened == 2 and overlay.visible and paused, "A captured click also reads the paper while the torch is selected")
	_check(player._light_on == light_before and is_equal_approx(player.battery_charge, charge_before) and player._action_kind == &"", "Reading does not toggle the torch or spend battery")
	overlay.close_overlay()
	await process_frame
	# Positive control: the same event path must reach item use without a note.
	# Turn the camera away; let the production focus rays clear the target.
	player.camera.look_at(Vector3(2.0, 1.48, 0.0), Vector3.UP)
	await physics_frame
	await process_frame
	player._update_focus()
	_check(player._focused == null, "Looking away clears focus through the real raycast")
	await _click_left()
	_check(player._light_on != light_before and opened == 2 and not paused, "Positive control: the same parsed left click toggles the torch without a focused paper")
	await _finish()

func _open_paper(text: String, title: String) -> void:
	opened += 1
	before_modal = {"paused": paused, "active": player.active, "mouse_mode": Input.mouse_mode}
	paused = true
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.show_paper(title, text)

func _close_paper() -> void:
	closed += 1
	paused = bool(before_modal.get("paused", false))
	player.active = bool(before_modal.get("active", true))
	Input.mouse_mode = int(before_modal.get("mouse_mode", Input.MOUSE_MODE_CAPTURED))

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Native window accepts captured mouse mode")

func _click_left() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_visible_rect().size * 0.5
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

func _box(label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	body.add_child(mesh)
	stage.add_child(body)

func _contains_text(node: Node, text: String) -> bool:
	if node is Label and node.text == text: return true
	for child in node.get_children():
		if _contains_text(child, text): return true
	return false

func _finish() -> void:
	paused = false
	Input.mouse_mode = prior_mouse_mode
	var evidence_path := ProjectSettings.globalize_path("res://").path_join("../Evidence/paper-input-tests.json")
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"kind": "native parsed mouse input with physical paper focus rays", "display_driver": DisplayServer.get_name(), "checks": checks, "failures": failures, "results": rows, "limitations": "Small fixture verifies engine input routing and modal behavior, not physical mouse hardware or the full house layout."}, "  "))
		file.close()
	if is_instance_valid(player) and is_instance_valid(player._item_audio): player._item_audio.silence()
	if is_instance_valid(stage): stage.queue_free()
	await process_frame
	await create_timer(0.12, true).timeout
	print("Paper input: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
