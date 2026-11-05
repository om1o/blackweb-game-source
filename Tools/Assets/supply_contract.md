# Original survival supplies

Authored on 2026-11-04 in Blender 5.2 through the Higgsfield 3D Jutsu workspace. Geometry is original scripted modelling; no recovered art was uploaded, no marketplace asset was imported, and no AI 3D generation job was started.

Source project: https://higgsfield.ai/3d-jutsu/cbb2a308-f6ab-4f01-ac1f-18a7c3338114, revision 2.

## Files

- `supply_blockout.py` creates the source scene, material placeholders, cameras and lights.
- `supply_detail.py` replaces the blockout with final geometry. The hosted service exported the GLB from revision 2.
- `supply_source.blend` is the editable final source, 1,109,003 bytes; SHA256 `36387ED7B5E58C8318828DD36E850A1F45E73BC9E5507E25B633B9EBE4F99D33`.
- `../../Godot/assets/generated/supply_blender/supply_kit.glb` is the runtime asset, 236,652 bytes; SHA256 `DB78456E89653C15EAC9BAD560026F977A3E5502F728C3BBCE58186325E967A2`.
- `supply_blender_preview.png` is the verified source render. It shows plain source materials; the generated labels are applied in Godot.
- `supply_validate.gd` and `supply_validation.json` record Godot import and shared-factory checks.

## Runtime contract

`res://scripts/supply_models.gd` is a standalone `RefCounted` factory. Call `make_variant(node_name)` and add the returned `Node3D` to the desired parent. An unknown name or unavailable GLB returns `null`. It has no player dependency. It removes the requested root from the imported scene, resets its display transform, and frees the other source objects, including studio camera and lights.

Godot dimensions are in metres, with near-centred origins. Battery and flare long axes are Y; packet and roll long axes are X.

| Node | X × Y × Z | Triangles | Detail |
| --- | --- | ---: | --- |
| BatteryCell | 0.0145 × 0.05055 × 0.0145 | 1,192 | Stepped metal crimps, insulating rings, positive terminal, printed sleeve |
| BandagePack | 0.114 × 0.026 × 0.072 | 728 | Filled folded paper shell, crimped seams |
| FlareStick | 0.0274 × 0.1904 × 0.0274 | 2,928 | Paper tube, ribbed ignition cap, striker disk |
| BandageRoll | 0.05574 × 0.0454 × 0.0454 | 2,496 | Hollow gauze roll, visible spiral layer edges |

The entire kit is 7,344 triangles. Battery bounds centre is 0.025 mm below the origin; flare bounds centre is 0.2 mm above it. Packet and roll bounds are centred exactly. These small terminal offsets are intentional geometry extents, not placement transforms.

The factory duplicates only label materials and applies `res://assets/generated/supply_labels_worn_v1.png`, an original imagegen atlas supplied by the main task. Surface UVs cover 0..1. All label materials use UV scale `(0.5, 0.5, 1)` and linear filtering with mipmaps:

| Material | UV offset | Atlas quadrant |
| --- | --- | --- |
| BatteryLabel | (0, 0, 0) | Upper left |
| BandageLabel | (0.5, 0, 0) | Upper right |
| FlareLabel | (0, 0.5, 0) | Lower left |

`supply_pickup.gd` instantiates two cells, one packet, or a horizontal flare. It retains the previous primitive mesh fallback if the shared factory cannot load a model. Collection, inventory limits, reset and interactions are unchanged. The loose roll is available to the player's use animation, not a separate inventory item.

## Verification and limitations

The final source render was inspected and the final hosted scene displayed once. Godot 4.7.2 headless validation passed all 28 checks: four variants, finite geometry and normals, dimensions, identity transforms, UV survival, correct runtime label assignment/crops, removal of studio objects, triangle budget, and invalid-name handling. The standalone validation does not prove hand alignment or animation quality; the main task owns native review of those changes.

These are detailed original game props with simple material surfaces. The packet silhouette is intentionally faceted and the gauze has no woven cloth normal map. The assets are not photogrammetry and this pass does not establish AAA visual quality. A native screenshot is needed to assess atlas legibility in gameplay lighting.

Account balance was 1.7 credits before and after the hosted Blender edit/render/export sequence. No paid generation job, credit purchase or license acceptance was made. This is observed cost for this operation, not a guarantee about future service pricing.
