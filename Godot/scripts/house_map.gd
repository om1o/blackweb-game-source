extends Control
## Surveyed geometry in 2D at 10Hz; no second camera or 3D pass.
signal room_discovered(index: int)
const Art = preload("res://scripts/horror_theme.gd")
const ROOMS := [Rect2(-5.6,-4.25,4.8,8.5),Rect2(-.8,-4.25,4,4.25),Rect2(-.8,0,4,4.25),Rect2(3.2,-4.25,5.6,4.25),Rect2(3.2,0,5.6,4.25)]
const NAMES := ["ENTRY","SUPPLIES","RECORDS","NEST","VAULT"]
const DOORS := [{"name":"SouthEntryDoor","at":Vector2(-.8,-2),"rooms":[0,1]},{"name":"NorthEntryDoor","at":Vector2(-.8,2),"rooms":[0,2]},{"name":"RearSouthDoor","at":Vector2(3.2,-2),"rooms":[1,3]},{"name":"RearNorthDoor","at":Vector2(3.2,2),"rooms":[2,4]}]
var player: Node3D
var progression: Node
var world: Node
var objective_state: Dictionary = {}
var visited := {0:true}
var room := 0
var expanded := false
var _clock := 0.0
var _panel: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Art.panel(Color(.023,.031,.03,.94),Color(.36,.40,.35,.60),0,1)
	set_expanded(false)
	clip_contents = true

func set_expanded(value: bool) -> void:
	expanded = value
	set_anchors_and_offsets_preset(PRESET_CENTER if value else PRESET_TOP_RIGHT)
	if value:
		offset_left = -380
		offset_right = 380
		offset_top = -270
		offset_bottom = 270
	else:
		offset_left = -324
		offset_right = -24
		offset_top = 24
		offset_bottom = 264
	queue_redraw()

func room_at(point: Vector3) -> int:
	for index in ROOMS.size():
		if ROOMS[index].has_point(Vector2(point.x,point.z)): return index
	return 0

func map_rect() -> Rect2:
	return Rect2(54,94,652,385) if expanded else Rect2(24,54,252,148.75)

func project_point(point: Vector3) -> Vector2:
	var area := map_rect()
	return area.position + Vector2((point.x+5.6)/14.4,(point.z+4.25)/8.5)*area.size

func restore_explored(values: Array) -> void:
	visited = {0:true}
	for value in values:
		if (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value < 5: visited[int(value)] = true

func _process(delta: float) -> void:
	visible = expanded or (not get_tree().paused and is_instance_valid(player) and player.active)
	if not visible: return
	_clock += delta
	if _clock < .10: return
	_clock = 0.0
	if is_instance_valid(player):
		room = room_at(player.global_position)
		if not visited.has(room):
			visited[room] = true
			room_discovered.emit(room)
	queue_redraw()

func _line(a: Vector2,b: Vector2,color: Color,width: float = 2) -> void:
	draw_line(project_point(Vector3(a.x,0,a.y)),project_point(Vector3(b.x,0,b.y)),color,width,true)

func _text(value: String,at: Vector2,points: int,color: Color,width: float = -1,align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(Art.medium_font(),at,value,align,width,points,color)

func _draw() -> void:
	if _panel == null: return
	draw_style_box(_panel,Rect2(Vector2.ZERO,size))
	var area := map_rect()
	_text("GREYHAVEN / THE HOUSE" if expanded else "HOUSE / GROUND FLOOR",Vector2(22,32 if expanded else 26),22 if expanded else 12,Art.INK)
	if expanded: _text("SURVEY / " + NAMES[room] + " / %d OF 5 ROOMS EXPLORED" % visited.size(),Vector2(24,61),14,Art.MUTED)
	draw_line(Vector2(22,72 if expanded else 37),Vector2(size.x-22,72 if expanded else 37),Color("3f4941"),1)
	for index in ROOMS.size():
		var r: Rect2 = ROOMS[index]
		var rect := Rect2(project_point(Vector3(r.position.x,0,r.position.y)),r.size*area.size/Vector2(14.4,8.5))
		var known: bool = visited.has(index)
		draw_rect(rect.grow(-2),Color("303a31") if index == room else Color("1b2420") if known else Color("111715"))
		if known: _text(NAMES[index],rect.position+Vector2(4,rect.size.y*.42),20 if expanded else 10,Art.GREEN,rect.size.x-8,HORIZONTAL_ALIGNMENT_CENTER)
	var wall := Color("a4b09d")
	_line(Vector2(-5.6,-4.25),Vector2(8.8,-4.25),wall)
	_line(Vector2(8.8,-4.25),Vector2(8.8,4.25),wall)
	_line(Vector2(8.8,4.25),Vector2(-5.6,4.25),wall)
	_line(Vector2(-5.6,-4.25),Vector2(-5.6,-.25),wall)
	_line(Vector2(-5.6,1.05),Vector2(-5.6,4.25),wall)
	_line(Vector2(-.8,0),Vector2(8.8,0),wall)
	for x in [-.8,3.2]:
		for span in [[-4.25,-2.8],[-1.2,1.2],[2.8,4.25]]: _line(Vector2(x,span[0]),Vector2(x,span[1]),wall)
	for entry in DOORS:
		var door: Node = world.get_node_or_null(entry.name) if is_instance_valid(world) else null
		var known: bool = visited.has(entry.rooms[0]) or visited.has(entry.rooms[1])
		var locked: bool = door != null and door.get("locked") == true
		var opened: bool = door != null and door.get("opened") == true
		var hinge: Vector2 = entry.at + Vector2(0,-.8)
		var door_ink := Color("d5a080") if locked and known else Color("c2b58c") if known else Color("515e52")
		_line(hinge,hinge+Vector2(0,1.6),Color("101713"),5)
		_line(hinge,hinge+Vector2(1.3,0) if opened else hinge+Vector2(0,1.6),door_ink,1.5)
		if known:
			var origin := project_point(Vector3(hinge.x,0,hinge.y))
			draw_arc(origin,1.3*area.size.x/14.4,0,PI*.5,14,Color(door_ink,.35),1,true)
			draw_circle(origin,2,door_ink)
		if locked and known: _lock(project_point(Vector3(entry.at.x,0,entry.at.y)))
	var exit_at := project_point(Vector3(-5.6,0,.4))
	var unlocked: bool = is_instance_valid(progression) and progression.can_interact(&"exit")
	draw_rect(Rect2(exit_at-Vector2(3,6),Vector2(6,12)),Art.GREEN if unlocked else Color("b48270"))
	var target: int = int(objective_state.get("target_room",-1))
	if target >= 0 and target < 5:
		var center: Vector2 = ROOMS[target].get_center()+Vector2(0,.8)
		var marker := project_point(Vector3(center.x,0,center.y))
		if objective_state.get("kind") == "exit": marker = exit_at+Vector2(11,0)
		_diamond(marker,8 if expanded else 5,Color("d8b675"))
	if is_instance_valid(player):
		var point := project_point(player.global_position).clamp(area.position+Vector2(4,4),area.end-Vector2(4,4))
		var direction: Vector3 = -player.camera.global_basis.z
		var f := Vector2(direction.x,direction.z).normalized()
		var side := Vector2(-f.y,f.x)
		var radius := 9.0 if expanded else 6.0
		draw_circle(point,radius+4,Color(0,0,0,.75))
		draw_colored_polygon(PackedVector2Array([point+f*radius,point-f*radius*.65+side*radius*.6,point-f*radius*.65-side*radius*.6]),Color("f0ecda"))
	_text("N",Vector2(size.x-36,30),11,Art.MUTED)
	if expanded:
		_text("YOU / DIAMOND: SEARCH AREA / PADLOCK: LOCKED",Vector2(24,511),13,Art.MUTED)
		_text("M / ESC  CLOSE",Vector2(size.x-156,511),13,Art.INK)
	else:
		_text(NAMES[room],Vector2(22,225),11,Art.GREEN)
		_text("M  EXPAND",Vector2(211,225),11,Art.MUTED)

func _diamond(center: Vector2,radius: float,color: Color) -> void:
	draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)]),color,1.6,true)

func _lock(at: Vector2) -> void:
	draw_circle(at,7,Color("111715"))
	draw_rect(Rect2(at+Vector2(-3,-1),Vector2(6,5)),Color("c99a79"))
	draw_arc(at+Vector2(0,-1),2.4,PI,TAU,8,Color("c99a79"),1.4,true)
