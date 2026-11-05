# Real clothing integration and validation

Four credited artist-made garments now appear on Luke when their armor slots are equipped: a fitted jacket, trousers, hood and biker boots. They follow Luke's existing skeleton and animations, and removing a piece restores the covered original clothing. The existing armor ownership, save data, 100 HP maximum, three quick items and 18% full-set damage reduction remain unchanged.

This document records the rig audit, Blender fitting work and bounded native validation on 2026-11-05. The sources are community clothing models adapted with a CC0 leather material. They are not a matched commercial armor set, and this pass does not establish AAA fidelity or complete animation coverage. The final correction removes jagged sleeve deformation, the protruding scalp triangle and old cuff fragments while preserving the complete hands. The source jacket's folded collar and separate hood retain a layered silhouette.

## Delivered assets

| Runtime piece | Artist and source | License |
| --- | --- | --- |
| Boots | Mindfront, Shoes Biker Boots Male, [Shoes 03 pack](https://static.makehumancommunity.org/assets/assetpacks/shoes03.html) | CC BY 4.0 |
| Pants | Mindfront, Male Trousers 1, [Pants 02 pack](https://static.makehumancommunity.org/assets/assetpacks/pants02.html) | CC BY 4.0 |
| Shirt | Elvaerwyn, Hooded Sweat Jacket 1 / ladieshoodiedown1, [Shirts 02 pack](https://static.makehumancommunity.org/assets/assetpacks/shirts02.html) | CC BY 4.0 |
| Hood | Donitz, Monk's Robe Hood, [Suits 02 pack](https://static.makehumancommunity.org/assets/assetpacks/suits02.html) | CC0 1.0 |
| Leather material | Rob Tuytel, [Poly Haven Brown Leather](https://polyhaven.com/a/brown_leather) | CC0 |

The fitted runtime file is `Godot/assets/third_party/makehuman_armor/luke_fitted_armor.glb` (25,231,860 bytes). It contains `Boots`, `Pants`, `Shirt` and `Hood`, totaling 47,662 triangles before the runtime trouser cuff trim. The GLB contains the reference rig for importing skin data; the live character uses its original single 81-bone skeleton. The original Luke body is not duplicated in the GLB.

Final GLB SHA-256: `a13b5829902917a8ded91e17b7d026225d6b63bc6a4e08a237d915d037bbb668`.

The editable fitting scene is `D:\CodexTemp\Blackweb-RealArmor-20261105\luke_fitted_armor.blend`. The repeatable fitting/export script is `Tools/Assets/leather_boots/fit_armor.py`; acquired OBJ files and original materials are retained outside the project beside that scene. The download manifest records official archive URLs, selected file CRC32 values and SHA-256 hashes. `Godot/licenses/MakeHumanArmor.txt` and the asset folder's `ATTRIBUTION.md` identify authors, licenses and modifications. The jacket, trousers and hood were originally clothing rather than leather armor.

## Current character contract

Luke is Microsoft Rocketbox `Male_Adult_04`, licensed under MIT and documented in [LukeAsset.md](LukeAsset.md). It is separately sourced, not recovered Arachnophobia artwork. The original FBX is `Godot/assets/luke/Export/Male_Adult_04.fbx`; the assembled runtime scene is `Godot/scenes/luke.tscn`.

| Property | Verified value |
| --- | --- |
| Skeleton path | `Luke/Model/Skeleton3D` |
| Skeleton | 81 bones, 80 skin binds |
| Visible mesh | `m006_hipoly_81_bones_opacity`, one mesh with three surfaces |
| Geometry | 8,684 triangles, 5,448 vertices across the three surfaces |
| Material surfaces | `Luke_body`, `Luke_head`, `Luke_opacity` |
| Runtime model transform | Uniform scale 0.9392465353, Y rotation 180 degrees, Y offset -0.0038824491 m |
| Assembled dimensions | Idle height 1.75 m; feet at local Y=0; forward local -Z |
| Existing clips | `RESET`, `idle`, `walk`, `run`; controller adds procedural crouch/jump and item poses |

The original body albedo/normal, head albedo/normal and opacity albedo live under `Godot/assets/luke/Textures/`. The original jacket, trousers and shoes are combined with the body mesh; its three material surfaces are not four modular clothing parts. Existing hair uses opacity geometry. Keep the source FBX, original textures, license and notice unchanged.

## Rigging and body coverage

| Garment slot | Relevant exact bone names | Coverage mask needed |
| --- | --- | --- |
| Shirt/jacket | `Bip01 Pelvis`, `Bip01 Spine`, `Bip01 Spine1`, `Bip01 Spine2`; both `Bip01 L/R Clavicle`, `UpperArm`, `Forearm` | Existing jacket and sleeves, including its folded hood as appropriate; preserve hands, exposed neck and any intended undershirt |
| Pants | `Bip01 Pelvis`, `Bip01 Spine`; both `Bip01 L/R Thigh`, `Calf` | Existing trousers from waist through cuffs; preserve adjacent exposed skin |
| Hood | `Bip01 Head`, `Bip01 Neck`, possibly `Bip01 Spine2` for the shoulder opening | Only covered hair/scalp and conflicting old hood; preserve face, eyes and mouth |
| Shoes | Both `Bip01 L/R Foot`, `Toe0`, and optionally `Calf` at a tall cuff | Existing trainers and overlapping cuff geometry |

`L/R` in the table means two names, for example `Bip01 L Foot` and `Bip01 R Foot`. These are a Biped-derived rig, not Mixamo names. Both thigh bones are children of `Bip01 Spine` in this asset; do not reconstruct an assumed generic hierarchy.

The implemented controller filters covered triangle indices while preserving original vertices, normals, UVs, weights and skin binds. It caches body variants by the four equipment coverage bits rather than rebuilding geometry each frame. The hood hides the separate hair-card surface and covered scalp; the face, eyes and mouth remain visible. When boots are worn, a second pants mesh removes the covered lower cuffs to prevent protrusion through the boot shafts. Mask zero restores the original body resource.

The hand skin boundary uses Luke's authored body-atlas UV islands together with hand bone weights. Cuff and palm share bones and height, so neither a weight threshold nor a wrist-plane cutoff reliably separates them. The pants mask is also limited to the hip/leg width: a height-only mask wrongly removed the lowered A-pose palms. Regression checks now cover both failures. This coverage contract is specific to the unchanged Rocketbox Luke atlas; a future replacement body requires an updated mask.

Luke's verified rest pose is an A pose with lowered arms. The fitting script maps smooth source sleeve sections onto the shoulder/elbow/wrist axis, blends normalized arm weights and transfers up to four influences elsewhere. It fits the hood outside a rounded scalp clearance envelope and assigns stable head/neck weights. The runtime controller resolves each named bone, transforms the imported garment into Luke's model rest space, and constructs inverse binds from Luke's actual global bone rests. The existing skeleton hierarchy is retained.

## Blender and Godot workflow

1. Inspect the acquired source files and license. Prefer a coherent clothing set with separate jacket, trousers, hood and shoes, usable PBR maps and topology suitable for deformation. A different character rig is not a drop-in fit.
2. Import Luke's original FBX or a neutral, verified export of the assembled Luke scene as the fitting reference. Preserve its actual rest transforms, hierarchy and names. Work in metres and verify axes/scale against the runtime contract above; do not apply Luke's assembly scale twice.
3. Fit each garment to the neutral body. Transfer vertex groups from Luke, normalize and limit weights, then correct shoulders, elbows, crotch, knees, collar and ankles. Bind the garment to Luke's armature. Transferring names alone cannot repair a different rest pose or inverse-bind space. Blender's [Data Transfer modifier](https://docs.blender.org/manual/en/5.0/modeling/modifiers/modify/data_transfer.html) transfers vertex groups; the [Armature modifier](https://docs.blender.org/manual/en/latest/modeling/modifiers/deform/armature.html) deforms matching bone/group names.
4. Export garment meshes with skin data and their reference armature as GLB. Preserve material slots, UVs and tangents, and use four normalized influences per vertex for the current compatibility renderer. Export baked image-based PBR materials rather than unsupported procedural shader graphs. Blender documents skin export and PBR channels in its [glTF exporter manual](https://docs.blender.org/manual/en/4.0/addons/import_export/scene_gltf2.html).
5. Import with named skins. At runtime, use each garment's `MeshInstance3D` and valid `Skin` against the existing Luke `Skeleton3D`, with an explicit skeleton path. Keep garment-specific inverse-bind matrices; do not blindly copy the body skin onto an unrelated mesh. Names must resolve and bind spaces must match. Godot explains the relationship between mesh weights, skeleton, bone names and inverse-bind matrices in [import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html).
6. Keep one live skeleton and Luke's existing animations and hand mounts. Shirt and trousers need skinning across several bones. A rigid `BoneAttachment3D` is suitable only for genuinely rigid pieces; it cannot bend sleeves or trouser knees. Avoid runtime cloth simulation for this first integration on the current machine.

## Equipment integration

Keep existing item IDs `leather_shirt`, `leather_pants`, `leather_hood`, `leather_shoes`, ownership and save schema. The four armor slots remain separate from three quick items. Current mitigation is 6%, 5%, 4% and 3%, capped at 18%; maximum HP is 100.

`player.gd` exposes `get_armor_state()`, `equip_armor()`, `unequip_armor()`, `restore_armor_state()` and `restore_survival_state()`. Changes emit `inventory_changed`. The new `Godot/scripts/armor_visuals.gd` exposes `setup(luke_model: Node3D) -> bool`, `apply_state(state: Dictionary)` and `visual_state() -> Dictionary`. It reads equipment state and updates garment visibility and body masks without granting or removing items. Initialization fails safely if all four garment skins cannot bind.

Initialization order matters: `main.gd` restores survival/armor before calling `player.attach_model()`. The integrated player hook sets up the visual controller after model attachment, immediately applies the already-restored armor state, and updates it on `inventory_changed`. The native fixture verifies this exact order with the real player implementation and checks inventory conservation while each piece is removed and equipped.

All eight extracted garment texture maps are at most 2048 pixels on either axis; the jacket maps are 1024. Those maps and the three Poly Haven maps have mipmap generation enabled. The authored import settings are tracked so a fresh checkout preserves them. Texture imports currently use lossless compression. The leather shader reconstructs normal Z from RG, which also permits a future RGTC normal import without interpreting missing blue data as surface direction. It combines source seam/normal detail with the leather grain and raises roughness to limit a plastic appearance.

## Validation and remaining acceptance checks

`Tools/Assets/leather_boots/validate_armor.gd` passed 35/35 checks for named skin binding, four variants, metre-scale bounds, shader assignment, all 16 body coverage combinations, restoration of the original body and preservation of the hands. The final native fixture `Tools/Assets/leather_boots/capture_worn_armor.gd` passed 32/32 checks after the final fit and mask changes. It uses real `player.gd`, restores armor before attaching Luke, equips and removes all four pieces without increasing inventory counts, and exercises actual crouch and jump input.

The final native process exited 0 with no shader/runtime errors or resource leaks. The Intel HD 530 Compatibility renderer issued its expected ANGLE fallback notice. Results are in `Evidence/armor-model-tests.json` and `Evidence/armor-native-tests.json`; the final native log is `Evidence/armor-native.log`.

The front, back, crouch, jump and knife captures were visually reviewed. Boots remain aligned with the feet, knees bend during actual crouching, the jump raises the character and tucks a leg, and the original clothes return after all armor is removed. Final close views confirm smooth sleeves, a rounded hood without the side scalp penetration, and complete flashlight/knife hands. Captures are `Evidence/armor-native-front.png`, `armor-native-back.png`, `armor-native-walk.png`, `armor-native-crouch.png`, `armor-native-jump.png`, `armor-native-knife.png` and `armor-native-unequipped.png`; close views are `armor-native-front-detail.png`, `armor-native-back-detail.png` and `armor-native-knife-detail.png`. Earlier diagnostic and external Workbench images are fitting aids and do not represent the final accepted fit.

This is a bounded pose and integration review, not a complete playthrough or a guarantee of clipping-free clothing. The source folded collar plus separate hood creates a layered silhouette; leather grain and folds remain adaptations of the source community garments. Candy, reload, bandage and all locomotion transitions need wider pose review; cloth simulation and a matched bespoke armor design are not included. Whole-game performance is measured by the root integration pass, not inferred from these small fixtures.

The initial read-only audit found no local Blender executable in the checked locations. Existing original prop work used Higgsfield hosted Blender 5.2; the clothing pass used the portable official Blender installation below.

## Verified portable Blender setup

On 2026-11-05, Blender 4.5.15 LTS was downloaded from [Blender's official mirror](https://mirror.blender.org/release/Blender4.5/) after the main download server returned a browser challenge. The version was selected from the [official 4.5 release listing](https://download.blender.org/release/Blender4.5/). D: had 1,712,759,046,144 free bytes before download.

- Executable: `D:\Tools\Blender\blender.exe`
- Self-contained settings directory: `D:\Tools\Blender\portable`, following [Blender's portable installation documentation](https://docs.blender.org/manual/en/4.5/advanced/blender_directory_layout.html#portable-installation).
- Source ZIP: `D:\Tools\BlenderDownload\blender-4.5.15-windows-x64.zip`, 398,649,826 bytes.
- SHA-256: `52dd02fd74877fa08e74b67d7854cf32468a232c02aaa19b6844c91285574f8d`, matched against the [official checksum file](https://mirror.blender.org/release/Blender4.5/blender-4.5.15.sha256).
- Extracted payload: 924,669,131 bytes; all archive paths were checked before extraction into the previously absent target directory. No other tool directory was overwritten.
- Verification: `blender.exe --version` exited 0 and reported `Blender 4.5.15 LTS`, release build `5afeabba6097`, dated 2026-10-22.
- Setup provenance: `D:\Tools\BlenderDownload\setup-verification.json`.

This portable tool is outside the game project's size budget. Setup ran no installer, changed no file associations and accepted no agreement. After setup, the fitting scripts used Blender in background mode; Godot import and the separate native fixtures produced the runtime validation described above.
