extends SceneTree
## Real GUI event regression for image inspection. No house or heavy actor load.

const OverlayScript = preload("res://scripts/field_overlay.gd")
const EvidenceScript = preload("res://scripts/tutorial_evidence.gd")
const ProgressionScript = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []
var overlay: BlackwebFieldOverlay
var stage: Node
var close_count := 0
var submitted_codes: Array[String] = []
var claimed_items: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	rows.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	stage = Node.new()
	root.add_child(stage)
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	overlay = OverlayScript.new()
	canvas.add_child(overlay)
	overlay.closed.connect(func(): close_count += 1)
	overlay.code_submitted.connect(func(value: String): submitted_codes.append(value))
	overlay.armor_claimed.connect(func(item: StringName): claimed_items.append(item))
	var progression := ProgressionScript.new()
	progression.auto_load = false
	progression.auto_save = false
	progression.auto_advance_atmosphere = false
	stage.add_child(progression)
	for title in EvidenceScript.DOCUMENT_TEXTURES:
		var texture := EvidenceScript.document_texture(title)
		_check(texture != null, "Generated document texture loads: " + title)
		if texture == null: continue
		_check(texture.get_height() >= 1000 and texture.get_width() >= 700, "Document has readable source resolution: " + title)
		var evidence := EvidenceScript.new()
		evidence.title = title
		evidence.progression = progression
		stage.add_child(evidence)
		var face := evidence.get_node_or_null("GeneratedDocumentFace") as MeshInstance3D
		_check(face != null and (face.material_override as StandardMaterial3D).albedo_texture == texture, "World paper uses the exact reader image: " + title)
		evidence.queue_free()
	var texture := EvidenceScript.document_texture("Mica's hidden note")
	if texture == null:
		await _finish()
		return
	paused = true
	overlay.show_paper("Mica's hidden note", "Luke,\nThe vault code is 0  4  1  7.\n— Mica")
	await process_frame
	await process_frame
	_check(overlay._paper_image.texture == texture and overlay._paper_viewport.visible and not overlay._paper_transcript.visible, "Reader opens the generated image first while paused")
	var available := overlay._paper_viewport.size
	var fit_size := overlay._paper_image.size
	_check(fit_size.x <= available.x + 1.0 and fit_size.y <= available.y + 1.0 and is_equal_approx(fit_size.aspect(), texture.get_size().aspect()), "Fit shows the full image with its original aspect ratio")
	await _capture("paper-fit")
	var origin := overlay._paper_viewport.global_position
	var cursor := origin + available * 0.5
	await _mouse_button(MOUSE_BUTTON_WHEEL_UP, cursor, true)
	_check(overlay._paper_zoom > 1.0 and overlay._paper_image.size.y > fit_size.y, "Parsed wheel event magnifies the image through the actual GUI")
	await _key(KEY_EQUAL)
	await _key(KEY_EQUAL)
	_check(overlay._paper_zoom > 2.0, "Keyboard zoom provides readable magnification above 2x")
	await _capture("paper-zoom")
	await _mouse_button(MOUSE_BUTTON_LEFT, cursor, true)
	var motion := InputEventMouseMotion.new()
	var drag_to := cursor + Vector2(45, 65)
	motion.position = root.get_screen_transform() * drag_to
	motion.global_position = motion.position
	motion.relative = motion.position - root.get_screen_transform() * cursor
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	await _mouse_button(MOUSE_BUTTON_LEFT, drag_to, false)
	_check(overlay._paper_pan.length() > 10.0 and not overlay._paper_dragging, "Parsed drag pans the magnified paper and releases cleanly")
	await _key(KEY_F)
	_check(is_equal_approx(overlay._paper_zoom, 1.0) and overlay._paper_pan == Vector2.ZERO, "Fit key resets zoom and pan")
	await _key(KEY_T)
	_check(overlay._paper_transcript.visible and not overlay._paper_viewport.visible, "Exact-text accessibility view is available without replacing the image default")
	await _key(KEY_T)
	_check(overlay._paper_viewport.visible, "Text view switches back to the original document")
	await _key(KEY_ESCAPE)
	_check(not overlay.visible and overlay.mode.is_empty() and close_count == 1, "Escape closes once; owner retains pause-state control")
	_check(paused, "Reader never changes the gameplay owner's pause state")
	overlay.show_paper("Mica's hidden note", "0 4 1 7")
	await process_frame
	_check(overlay._paper_zoom == 1.0 and overlay._paper_pan == Vector2.ZERO and overlay._paper_viewport.visible, "Reopening starts at fit with the image restored")
	await _key(KEY_E)
	_check(not overlay.visible and close_count == 2, "E puts down the paper")
	overlay.show_vault(true, true)
	await process_frame
	await process_frame
	await _capture("vault-before-input")
	for digit in ["0", "4", "1", "7", "9"]: await _click_control(_find_button(overlay, digit))
	if overlay.digits != "0417": print("Vault input observed: ", overlay.digits, " ; card ", overlay._card.get_global_rect(), " ; key0 ", _find_button(overlay, "0").get_global_rect())
	_check(overlay.digits == "0417", "Physical keypad buttons retain the four-digit input limit")
	await _click_control(_find_button(overlay, "ENTER"))
	_check(submitted_codes == ["0417"], "Physical ENTER key emits the entered vault code once")
	await _click_control(_find_button(overlay, "DEL"))
	_check(overlay.digits == "041", "Physical DEL key removes one digit")
	await _capture("vault-keypad")
	overlay.show_armor({"leather_shirt": true})
	await process_frame
	await process_frame
	var shirt := _armor_button(&"leather_shirt")
	_check(shirt != null and shirt.disabled, "Already collected armor remains disabled")
	await _click_control(_armor_button(&"leather_pants"))
	_check(claimed_items == [&"leather_pants"], "Restyled armor row emits the correct item identity once")
	await _capture("armor-kit")
	overlay.close_overlay()
	await _finish()

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var match_button := _find_button(child, text)
		if match_button != null: return match_button
	return null

func _armor_button(item: StringName) -> Button:
	for node in overlay.find_children("*", "Button", true, false):
		if node.get_meta("armor_item", &"") == item: return node
	return null

func _click_control(control: Control) -> void:
	if control == null:
		_check(false, "Expected control exists")
		return
	var at := control.get_global_rect().get_center()
	await _mouse_button(MOUSE_BUTTON_LEFT, at, true)
	await _mouse_button(MOUSE_BUTTON_LEFT, at, false)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.2, true).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../Evidence/PaperReader")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

func _mouse_button(button: MouseButton, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	# Parsed events enter in window coordinates, before project stretch is undone.
	event.position = root.get_screen_transform() * at
	event.global_position = event.position
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _finish() -> void:
	paused = false
	var output := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/paper-reader-tests.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"kind": "generated document mesh/material and real GUI zoom/pan input", "display_driver": DisplayServer.get_name(), "checks": checks, "failures": failures, "results": rows}, "  "))
	stage.queue_free()
	await process_frame
	print("Paper reader: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
