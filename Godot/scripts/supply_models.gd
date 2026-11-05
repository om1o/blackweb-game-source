class_name BlackwebSupplyModels
extends RefCounted
## Original Blender props shared by pickups and held-item presentation.
## No dependency on the player or interaction scripts.

const KIT_PATH := "res://assets/generated/supply_blender/supply_kit.glb"
const ATLAS_PATH := "res://assets/generated/supply_labels_worn_v1.png"
const LABEL_OFFSETS := {
 "BatteryLabel": Vector3(0.0, 0.0, 0.0),
 "BandageLabel": Vector3(0.5, 0.0, 0.0),
 "FlareLabel": Vector3(0.0, 0.5, 0.0)
}
static var _kit: PackedScene
static var _atlas: Texture2D

static func make_variant(node_name: String) -> Node3D:
 if node_name not in ["BatteryCell", "BandagePack", "FlareStick", "BandageRoll"]:
  return null
 if _kit == null:
  if not ResourceLoader.exists(KIT_PATH): return null
  _kit = load(KIT_PATH) as PackedScene
 if _kit == null: return null
 var imported := _kit.instantiate() as Node3D
 if imported == null: return null
 var variant := imported.find_child(node_name, true, false) as Node3D
 if variant == null:
  imported.free()
  return null
 variant.get_parent().remove_child(variant)
 variant.transform = Transform3D.IDENTITY
 imported.free()
 if _atlas == null and ResourceLoader.exists(ATLAS_PATH):
  _atlas = load(ATLAS_PATH) as Texture2D
 for mesh_instance in variant.find_children("*", "MeshInstance3D", true, false):
  mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in range(mesh_instance.mesh.get_surface_count()):
   var original: Material = mesh_instance.mesh.surface_get_material(surface)
   if original == null or not original is StandardMaterial3D: continue
   if not LABEL_OFFSETS.has(original.resource_name) or _atlas == null: continue
   var label := original.duplicate() as StandardMaterial3D
   label.albedo_color = Color.WHITE
   label.albedo_texture = _atlas
   label.uv1_scale = Vector3(0.5, 0.5, 1.0)
   label.uv1_offset = LABEL_OFFSETS[original.resource_name]
   label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
   label.roughness = 0.86 if original.resource_name != "BandageLabel" else 0.96
   mesh_instance.set_surface_override_material(surface, label)
 variant.set_meta("asset_provenance", "Original Blackweb supply prop authored in Blender 5.2 through Higgsfield 3D Jutsu")
 return variant
