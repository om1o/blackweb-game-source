extends Node3D
## Knife-only web obstruction. The lock still needs the separate exit key.
var progression: Node
var strands: Node3D
var health := 8.0
var _notice_clock := 0.0

func _ready() -> void:
	add_to_group("cuttable")
	strands = Node3D.new()
	add_child(strands)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.56,.59,.53)
	material.roughness = .88
	var lines := MultiMesh.new()
	lines.transform_format = MultiMesh.TRANSFORM_3D
	var strand := CylinderMesh.new()
	strand.top_radius = .003
	strand.bottom_radius = .004
	strand.height = 1
	strand.radial_segments = 4
	strand.rings = 1
	lines.mesh = strand
	lines.instance_count = 52
	var rng := RandomNumberGenerator.new()
	rng.seed = 8417
	for i in 52:
		var a := Vector3(0,rng.randf_range(-.55,.65),rng.randf_range(-.42,.42))
		var b := Vector3(rng.randf_range(-.04,.04),rng.randf_range(-.55,.65),rng.randf_range(-.42,.42))
		var axis := b-a
		lines.set_instance_transform(i,Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled(Vector3(1,axis.length(),1)),(a+b)*.5))
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh = lines
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strands.add_child(mesh)
	progression.inventory_changed.connect(refresh)
	progression.checkpoint_restored.connect(func():
		health = 0.0 if progression.exit_web_cleared else 8.0
		refresh())
	refresh()

func refresh() -> void:
	visible = not progression.exit_web_cleared
	if visible and health <= 0: health = 8.0

func is_alive() -> bool:
	return not progression.exit_web_cleared

func get_hurt_spheres() -> Array[Dictionary]:
	return [{"center":global_position,"radius":.38}]

func take_damage(amount: float) -> void:
	receive_hit(amount,global_position,Vector3.RIGHT)

func receive_hit(amount: float, at: Vector3, normal: Vector3) -> void:
	if not is_alive() or not is_finite(amount) or amount <= 0 or get_tree().paused: return
	health = maxf(0,health-amount)
	preload("res://scripts/combat_effects.gd").for_source(self).burst(self,at,normal,&"silk")
	if health <= 0:
		progression.clear_exit_web()
	else:
		progression.show_notice("The silk is tearing. One more cut.",3)
