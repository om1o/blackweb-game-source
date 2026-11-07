extends Control
## A surveyed floor plan: no second camera or extra 3D render pass.
const ROOMS := [Rect2(-5.6,-4.25,4.8,8.5), Rect2(-.8,-4.25,4,4.25), Rect2(-.8,0,4,4.25), Rect2(3.2,-4.25,5.6,4.25), Rect2(3.2,0,5.6,4.25)]
const NAMES := ["ENTRY", "SUPPLIES", "RECORDS", "NEST", "VAULT"]
var player: Node3D
var progression: Node
var visited := {0:true}
var room := 0
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	offset_left = -254
	offset_right = -24
	offset_top = 24
	offset_bottom = 206
	clip_contents = true

func room_at(point: Vector3) -> int:
	for index in ROOMS.size():
		if ROOMS[index].has_point(Vector2(point.x,point.z)): return index
	return 0

func project_point(point: Vector3) -> Vector2:
	return Vector2(22 + (point.x+5.6)*13, 42 + (point.z+4.25)*13)

func _process(delta: float) -> void:
	visible = not get_tree().paused and is_instance_valid(player) and player.active
	if not visible: return
	_clock += delta
	if _clock < .10: return
	_clock = 0.0
	room = room_at(player.global_position)
	visited[room] = true
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	draw_style_box(_panel(), Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(15,22),"GREYHAVEN  /  GROUND FLOOR",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c7cbbd"))
	for index in ROOMS.size():
		var r: Rect2 = ROOMS[index]
		var mapped := Rect2(project_point(Vector3(r.position.x,0,r.position.y)),r.size*13)
		var known: bool = visited.has(index)
		draw_rect(mapped.grow(-2),Color("32423c") if index == room else Color("1a2424") if known else Color("101717"))
		draw_rect(mapped.grow(-1),Color("9aab9b") if known else Color("35403b"),false,1)
		if known and index != 0:
			draw_string(font,mapped.position+Vector2(5,17),NAMES[index],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("a1afa2"))
	for x in [-.8,3.2]:
		for z in [-2.0,2.0]:
			var door := project_point(Vector3(x,0,z))
			draw_line(door+Vector2(0,-7),door+Vector2(0,7),Color("c0aa72"),3)
	var exit_point := project_point(Vector3(-5.3,0,.4))
	draw_rect(Rect2(exit_point-Vector2(3,5),Vector2(6,10)),Color("b7d5b1") if progression.has_exit_keys and progression.exit_web_cleared else Color("a76f5a"))
	if is_instance_valid(player):
		var p := project_point(player.global_position)
		var direction: Vector3 = -player.camera.global_basis.z
		var f := Vector2(direction.x,direction.z).normalized()
		var side := Vector2(-f.y,f.x)
		draw_colored_polygon(PackedVector2Array([p+f*6,p-f*4+side*4,p-f*4-side*4]),Color("e5e2cb"))
	draw_string(font,Vector2(15,171),NAMES[room]+"  /  I  BACKPACK",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("a6b3a6"))

func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(.025,.04,.04,.88)
	panel.border_color = Color(.32,.37,.32,.7)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	return panel
