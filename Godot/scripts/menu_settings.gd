class_name BlackwebMenuSettings
extends RefCounted
## Game-local preferences only. Never changes the Windows mixer or device.
var path := "user://blackweb_settings.cfg"
var master_volume := 1.0
var dialogue_volume := 1.0
var output_device := "Default"
var fullscreen := false
var reduced_motion := false
var hud_layout := 2
var last_save_ok := true
var graphics_preset := "quality"
var graphics_override := ""

func _init() -> void:
	graphics_preset = "performance" if is_intel_hd530(RenderingServer.get_video_adapter_name()) else "quality"

static func is_intel_hd530(adapter: String) -> bool:
	var name := adapter.to_lower().replace(" ", "")
	return name.contains("intel") and name.contains("hdgraphics530")

func configure_graphics(arguments: PackedStringArray) -> void:
	graphics_override = ""
	for argument in arguments:
		if argument.begins_with("--graphics="):
			var choice := argument.trim_prefix("--graphics=")
			if choice in ["quality", "performance"]: graphics_override = choice

func active_graphics_preset() -> String:
	return graphics_override if not graphics_override.is_empty() else graphics_preset

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	master_volume = _volume(config.get_value("audio", "master", 1.0))
	dialogue_volume = _volume(config.get_value("audio", "dialogue", 1.0))
	var device: Variant = config.get_value("audio", "output_device", "Default")
	if device is String: output_device = device
	fullscreen = config.get_value("display", "fullscreen", false) == true
	reduced_motion = config.get_value("accessibility", "reduced_motion", false) == true
	var layout: Variant = config.get_value("interface", "hud_layout", 2)
	if layout is int: hud_layout = clampi(layout, 0, 3)
	var graphics: Variant = config.get_value("display", "graphics_preset", graphics_preset)
	if graphics in ["quality", "performance"]: graphics_preset = graphics

func save_preferences() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "dialogue", dialogue_volume)
	config.set_value("audio", "output_device", output_device)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "graphics_preset", graphics_preset)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("interface", "hud_layout", hud_layout)
	last_save_ok = config.save(path) == OK
	return last_save_ok

func apply(window_changes: bool = true) -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Dialogue", dialogue_volume)
	var available := AudioServer.get_output_device_list()
	var requested := output_device if available.has(output_device) else "Default"
	if AudioServer.output_device != requested: AudioServer.output_device = requested
	if window_changes and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_graphics(viewport: Viewport) -> void:
	if not is_instance_valid(viewport): return
	var performance := active_graphics_preset() == "performance"
	var samples := Viewport.MSAA_DISABLED if performance else Viewport.MSAA_2X
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# Native/no-MSAA consistently beat 75% scaling on this Intel ANGLE adapter.
	# Preserve full-resolution webs/torch; see the reverse-order comparison.
	if not is_equal_approx(viewport.scaling_3d_scale, 1.0): viewport.scaling_3d_scale = 1.0
	if viewport.msaa_3d != samples: viewport.msaa_3d = samples

func _set_bus(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(.0001, value)))

func _volume(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return 1.0
	return clampf(float(value), 0.0, 1.0)

static func prefers_reduced_motion() -> bool:
	var config := ConfigFile.new()
	if config.load("user://blackweb_settings.cfg") != OK: return false
	return config.get_value("accessibility", "reduced_motion", false) == true
