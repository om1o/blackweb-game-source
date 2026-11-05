extends SceneTree
const IntroScript = preload("res://scripts/tutorial_intro.gd")
class StandInPlayer extends Node3D:
	var active := false
	var camera: Camera3D
	var visual: Node3D
var checks := 0
var failures := 0
var completions := 0
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	rows.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := StandInPlayer.new()
	scene.add_child(player)
	player.camera = Camera3D.new()
	player.add_child(player.camera)
	player.camera.position = Vector3(-3.5, 1.7, .3)
	player.camera.make_current()
	player.visual = Node3D.new()
	player.add_child(player.visual)
	var held := Node3D.new()
	held.name = "VisibleCameraKnife"
	player.camera.add_child(held)
	var hidden := Node3D.new()
	hidden.name = "VisibleCameraCandy"
	hidden.visible = false
	player.camera.add_child(hidden)
	var hud := Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var health_hud := Label.new()
	health_hud.text = "Health / quick items / objective"
	hud.add_child(health_hud)
	var hidden_menu := Control.new()
	hidden_menu.visible = false
	hud.add_child(hidden_menu)
	var intro := IntroScript.new()
	scene.add_child(intro)
	intro.finished.connect(func(): completions += 1)
	paused = true
	_check(intro.begin(player, hud) and intro.is_running() and paused and not player.active, "Arrival starts from paused menu with inactive player")
	var arrival := intro._camera
	_check(arrival.current and root.get_camera_3d() == arrival and not intro.begin(player, hud), "Temporary camera owns view and duplicate begin is rejected")
	_check(not player.visual.visible and not held.visible and not hidden.visible, "Arrival hides Luke's body and camera-held props")
	_check(not health_hud.visible and not hidden_menu.visible and intro._overlay.visible, "Arrival hides existing HUD content while its own captions remain visible")
	await create_timer(.25, true).timeout
	_check(arrival.global_position.distance_to(IntroScript.ENTRY_POSITION) > .001 and intro._fade.color.a < .95, "Pause-safe camera and fade animate while world is paused")
	intro.skip()
	intro.skip()
	_check(not intro.is_running() and completions == 1 and paused and not player.active and player.camera.current, "Skip restores prior menu state and camera and emits exactly once")
	_check(player.visual.visible and held.visible and not hidden.visible, "Skipping restores each prior model visibility without showing unequipped items")
	_check(health_hud.visible and not hidden_menu.visible, "Skip restores visible HUD content without opening a previously hidden menu")
	await process_frame
	_check(not is_instance_valid(arrival) and hud.get_child_count() == 2, "Skip removes only the temporary camera and overlay")
	paused = false
	player.active = true
	_check(intro.begin(player, hud) and paused and not player.active, "Arrival also suspends an active unpaused player")
	await create_timer(IntroScript.DURATION + .2, true).timeout
	_check(not intro.is_running() and completions == 2 and not paused and player.active and player.camera.current, "Natural completion restores active gameplay and camera")
	_check(health_hud.visible and not hidden_menu.visible, "Natural completion restores original HUD visibility")
	intro.reduced_motion = true
	intro.begin(player, hud)
	var still_camera := intro._camera
	var still_transform: Transform3D = player.camera.global_transform
	await create_timer(.25, true).timeout
	_check(still_camera.global_transform.is_equal_approx(still_transform), "Reduced motion keeps arrival at the gameplay camera without sway")
	_check(intro.is_running() and intro._overlay.visible and paused, "Reduced motion retains captions and paused arrival lifecycle")
	intro.skip()
	_check(not intro.is_running() and player.camera.current and not paused and player.active, "Reduced motion skip restores normal gameplay")
	intro.reduced_motion = false
	completions = 2
	intro.begin(player, hud)
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(.05, true).timeout
	_check(not intro.is_running() and completions == 3 and not paused and player.active, "Enter skips through real input dispatch while paused")
	intro.begin(player, hud)
	intro.queue_free()
	await process_frame
	_check(not paused and player.active and player.camera.current, "Removing an active intro cannot strand the game paused")
	_check(health_hud.visible and not hidden_menu.visible, "Cancellation restores original HUD visibility")
	await process_frame
	_check(hud.get_child_count() == 2 and scene.find_children("ArrivalCamera", "Camera3D", true, false).is_empty(), "Interrupted intro leaves only the original HUD children")
	var report := {"checks": checks, "failures": failures, "results": rows, "kind": "Arrival lifecycle with stand-in player; not house visual approval"}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../Evidence/tutorial-intro-tests.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("Tutorial intro: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	hud.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
