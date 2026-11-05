class_name BlackwebTutorialIntro
extends Node
## Original in-engine arrival camera and captions; no prerecorded video asset.
## begin() owns the temporary pause/camera and restores them before finished.
signal finished

const DURATION := 8.0
const ENTRY_POSITION := Vector3(-4.3, 1.85, 0.4)
const CAPTIONS := [
	"Luke / Greyhaven maintenance worker",
	"Home after the late shift. Mica asked me to wait here.",
	"The front door has shut behind me. Her phone is ringing.",
]
var _player: Node3D
var _original_camera: Camera3D
var _camera: Camera3D
var _overlay: Control
var _fade: ColorRect
var _caption: Label
var _tween: Tween
var _running := false
var _prior_paused := false
var _prior_active := false
var _start_transform := Transform3D.IDENTITY
var _end_transform := Transform3D.IDENTITY
var _end_fov := 68.0
var _hidden_visuals: Array[Dictionary] = []
var _hidden_hud: Array[Dictionary] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin(player: Node3D, hud_parent: Control) -> bool:
	if _running or not is_instance_valid(player) or not is_instance_valid(hud_parent): return false
	var gameplay_camera := player.get("camera") as Camera3D
	if gameplay_camera == null or not player.is_inside_tree() or not hud_parent.is_inside_tree(): return false
	_player = player
	_original_camera = player.get_viewport().get_camera_3d()
	if _original_camera == null: _original_camera = gameplay_camera
	_prior_paused = get_tree().paused
	_prior_active = bool(player.get("active"))
	_end_transform = gameplay_camera.global_transform
	_end_fov = gameplay_camera.fov
	_player.set("active", false)
	_hidden_visuals.clear()
	var body := player.get("visual") as Node3D
	_hide_for_intro(body)
	for child in gameplay_camera.get_children():
		if child is Node3D and str(child.name).begins_with("VisibleCamera"):
			_hide_for_intro(child)
	get_tree().paused = true
	_camera = Camera3D.new()
	_camera.name = "ArrivalCamera"
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.near = gameplay_camera.near
	_camera.far = gameplay_camera.far
	_camera.cull_mask = gameplay_camera.cull_mask
	player.get_parent().add_child(_camera)
	_camera.global_position = ENTRY_POSITION
	_camera.look_at(Vector3(-1.5, 1.20, .4), Vector3.UP)
	_start_transform = _camera.global_transform
	_camera.fov = 62.0
	_camera.make_current()
	_build_overlay(hud_parent)
	_running = true
	_pose(0.0)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_pose, 0.0, DURATION, DURATION)
	_tween.tween_callback(_finish)
	return true

func is_running() -> bool:
	return _running

func _hide_for_intro(node: Node3D) -> void:
	if not is_instance_valid(node): return
	_hidden_visuals.append({"node": node, "visible": node.visible})
	node.visible = false

func skip() -> void:
	if _running: _finish()

func _build_overlay(parent: Control) -> void:
	_hidden_hud.clear()
	for child in parent.get_children():
		if child is CanvasItem:
			_hidden_hud.append({"node": child, "visible": child.visible})
			child.visible = false
	_overlay = Control.new()
	_overlay.name = "ArrivalCaptions"
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0, .68)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -130
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(.90, .89, .84))
	bottom.add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.offset_left = 32
	_caption.offset_right = -32
	_caption.offset_bottom = -24
	var hint := Label.new()
	hint.text = "Enter / Esc · Skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(.60, .62, .61))
	bottom.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -29
	hint.offset_bottom = -9

func _pose(elapsed: float) -> void:
	if not _running or not is_instance_valid(_camera): return
	var blend := smoothstep(0.0, DURATION, elapsed)
	var sway := sin(elapsed * 1.35) * .012 * (1.0 - blend)
	_camera.global_transform = _start_transform.interpolate_with(_end_transform, blend)
	_camera.global_position += Vector3(sway, sin(elapsed * .9) * .006 * (1.0 - blend), 0)
	_camera.fov = lerpf(62.0, _end_fov, blend)
	_fade.color.a = 1.0 - smoothstep(0.0, .8, elapsed)
	var index := 0 if elapsed < 2.1 else (1 if elapsed < 4.8 else 2)
	_caption.text = CAPTIONS[index]
	# Short fade at each caption boundary, not a flashing full-screen effect.
	var start := 0.0 if index == 0 else (2.1 if index == 1 else 4.8)
	var end := 2.1 if index == 0 else (4.8 if index == 1 else DURATION)
	_caption.modulate.a = minf(smoothstep(start, start + .3, elapsed), 1.0 - smoothstep(end - .25, end, elapsed))

func _unhandled_input(event: InputEvent) -> void:
	if not _running: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		skip()

func _finish() -> void:
	if not _running: return
	_running = false
	if _tween != null and _tween.is_valid(): _tween.kill()
	_restore()
	finished.emit()

func _restore() -> void:
	if is_instance_valid(_original_camera): _original_camera.make_current()
	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
	if is_instance_valid(_overlay):
		_overlay.visible = false
		_overlay.queue_free()
	for entry in _hidden_visuals:
		if is_instance_valid(entry.node): entry.node.visible = bool(entry.visible)
	_hidden_visuals.clear()
	for entry in _hidden_hud:
		if is_instance_valid(entry.node): entry.node.visible = bool(entry.visible)
	_hidden_hud.clear()
	if is_instance_valid(_player): _player.set("active", _prior_active)
	if is_inside_tree(): get_tree().paused = _prior_paused

func _exit_tree() -> void:
	# Removing the controller during an intro must not strand the game paused.
	if _running:
		_running = false
		if _tween != null and _tween.is_valid(): _tween.kill()
		_restore()
