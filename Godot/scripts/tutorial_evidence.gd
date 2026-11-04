class_name BlackwebTutorialEvidence
extends BlackwebInteraction

signal discovered(text: String, title: String)

const PAPER_TEXTURE := "res://assets/recovered/Arachnophobia/Content/Megascans/Decals/Parchment_Paper_vimfffnh/T_Parchment_Paper_vimfffnh_1K_D.png"

var evidence_type := "paper"
var title := "Field paper"
var record_text := ""

func _ready() -> void:
	kind = &"tutorial_evidence"
	label = "Read " + title if evidence_type == "paper" else "Inspect " + title
	super._ready()
	var trigger := get_child(0) as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(0.48, 0.42, 0.42)
	trigger.shape = box
	if evidence_type == "cash": _make_cash()
	else: _make_paper()

func interact() -> void:
	discovered.emit(record_text, title)

func _make_paper() -> void:
	var paper := BoxMesh.new()
	paper.size = Vector3(0.32, 0.004, 0.23)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.80, 0.74, 0.59)
	material.roughness = 0.96
	if ResourceLoader.exists(PAPER_TEXTURE): material.albedo_texture = load(PAPER_TEXTURE)
	var page := MeshInstance3D.new()
	page.name = "RecoveredPaperEvidence"
	page.mesh = paper
	page.material_override = material
	page.rotation.y = 0.17
	add_child(page)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.08, 0.09, 0.09)
	ink.roughness = 1.0
	for index in range(5):
		var line := BoxMesh.new()
		line.size = Vector3(0.17 if index < 4 else 0.10, 0.0008, 0.004)
		var mark := MeshInstance3D.new()
		mark.name = "InkLine%d" % index
		mark.mesh = line
		mark.material_override = ink
		mark.position = Vector3(-0.025, 0.003, -0.068 + index * 0.028)
		mark.rotation.y = 0.17
		add_child(mark)

func _make_cash() -> void:
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.28, 0.31, 0.23)
	band.roughness = 0.94
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.37, 0.42, 0.31)
	paper.roughness = 0.98
	for bundle in range(3):
		var block := BoxMesh.new()
		block.size = Vector3(0.15, 0.025, 0.065)
		var stack := MeshInstance3D.new()
		stack.name = "CashBundle%d" % bundle
		stack.mesh = block
		stack.material_override = paper
		stack.position = Vector3(-0.13 + bundle * 0.13, bundle * 0.022, 0.0)
		stack.rotation.y = -0.10 + bundle * 0.08
		add_child(stack)
		var strap := BoxMesh.new()
		strap.size = Vector3(0.025, 0.026, 0.067)
		var wrap := MeshInstance3D.new()
		wrap.name = "Band%d" % bundle
		wrap.mesh = strap
		wrap.material_override = band
		wrap.position = stack.position + Vector3.UP * 0.001
		wrap.rotation = stack.rotation
		add_child(wrap)
