extends SceneTree
## Run with --write-movie <external .avi> --fixed-fps 24 --resolution 1280x720.
var town: Node3D
var frame := 0
var source_hash := ""
func _initialize() -> void:
	root.msaa_3d = Viewport.MSAA_2X
	source_hash = FileAccess.get_sha256("res://scripts/town_cinematic.gd")
	town = load("res://scripts/town_cinematic.gd").new()
	root.add_child.call_deferred(town)
func _process(_delta: float) -> bool:
	if not is_instance_valid(town) or not town.is_node_ready(): return false
	town.pose(float(frame)/24.0)
	frame += 1
	if frame > 1008:
		var report := {"frames":1008,"fps":24,"scene_sha256":source_hash,"voice_envelope_sha256":FileAccess.get_sha256("res://data/town_voice_envelope.json")}
		# Godot consumes engine flags before exposing script arguments.
		var scratch := OS.get_environment("BLACKWEB_CINEMATIC_SCRATCH")
		if scratch.is_empty(): scratch = "D:/CodexTemp/Blackweb-TownIntro"
		FileAccess.open(scratch.path_join("town-motion.avi.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("TOWN_MOVIE_COMPLETE frames=1008 fps=24")
		quit()
	return false
