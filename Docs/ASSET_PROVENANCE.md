# Asset provenance

The user stated **"i have permition contiune"** on 2026-11-03 in response to the explicit question about the game's creator permission/asset licenses. Recovery proceeds on that user-confirmed permission. The exact license documents, grant wording, attribution terms, and redistribution conditions were not supplied; they are not represented here as independently verified.

`ASSET_INVENTORY.csv` records all 509 project packages from the supplied manifest. The source game remains unchanged. IoStore-to-legacy conversion succeeded; use the interchange export reports to identify which assets have actually been converted into editable import formats.

| Content | Creator/source | Rights record | Modification/use |
|---|---|---|---|
| Maps, original interactions, UI, sequences | Likely [Arachnophobia by MilkerBretzel404](https://milkerbretzel404.itch.io/arachnophobia); filename, size, engine and premise match | User-confirmed permission; original license text not provided | Map recovery for reconstruction; original compiled gameplay is replaced by new Godot GDScript rather than described as recovered graphs |
| OldBrickHouse assets (370 packages) | Strong filename match to [Gabro Media / Gabor Somogyi](https://www.fab.com/listings/d89c5c69-2737-45cb-9964-27ced2d25024) | User-confirmed permission; acquisition/license documents not supplied | Furnishings, materials and textures for house recovery. This does not identify the entire house layout as the pack's demo |
| Spider (14 packages) | Creator/source not established by package metadata | User-confirmed permission; exact license/attribution terms not supplied | Mesh, skeleton, animation and texture recovery; recovered GLB rig and original Idle/Walk/Run clips; actual runtime QA recorded separately |
| VHExterior, audio, fonts, Megascans/MSPresets and remaining packages | Original creators and individual licenses not established | User-confirmed permission covering supplied assets; details retained as unknown | Recovery inventory; actual import/use must be read from exporter/import reports |
| retoc 0.1.5 | [Truman Kilen and Archengius](https://github.com/trumank/retoc/releases/tag/v0.1.5), MIT | Tool license retained with downloaded tool; not a license for game assets | Unmodified recovery tool in D:/C: workspace scratch; not a runtime dependency |
| CUE4Parse / CUE4Parse-Conversion | [FabianFG and contributors](https://github.com/FabianFG/CUE4Parse), Apache-2.0 | Pinned NuGet dependencies in Tools/Recovery; transitive notices remain with packages | Offline asset parsing/export; not game runtime code |
| Original BLACKWEB GDScript, procedural props and earlier C++/tools | Authored during this task | New implementation for the user | Godot/scripts, Godot/tools, Source/Blackweb and recovery/build tools |

Initial recovery sources were accessed 2026-11-03. The later Blackweb corner-web and blood/goo textures were generated for this project with imagegen; their prompts and file details are recorded in [WebAndVoicePass.md](WebAndVoicePass.md). No new paid production assets were acquired. Asset permission confirmation does not establish a separate right to the original game's title or other branding.

## Additional runtime content

| Asset | Creator and pinned source | License and obligations | Modifications and use |
|---|---|---|---|
| Luke interim model, Male_Adult_04 and idle/walk/run clips | Microsoft and Rocketbox contributors; [Microsoft-Rocketbox](https://github.com/microsoft/Microsoft-Rocketbox/tree/0943055db6ec570bcef9f2c8b41c9e5467c808f9), accessed2026-11-03 | MIT; commercial use, modification and redistribution permitted with copyright and permission notice retained. Exact notice and file hashes in Godot/assets/luke. | Imported FBX, canonical texture bindings, one visible LOD, motion extraction removed, grounded/scaled and facing adjusted for Godot. This is interim character art, not a bespoke scan of Luke. |
| Giant Spider Lite juvenile visual | Literock Studios, [official itch.io listing](https://literock-studios.itch.io/giant-spider-lite), acquired 2026-11-04 | Included `LICENSE` permits compiled/packaged game use and forbids standalone/raw-asset redistribution. Local ZIP SHA-256 `AAA5EBA63507E0CAF79DE3D18E5E13DEEBB973635ADA89EDD518D151B4438AB5`. | The active local game uses a derived 1K GLB for one harmless sighting and two combat juveniles. Raw files stay outside the GitHub source mirror under ignored `Godot/assets/third_party/literock/`; a CC0 spider is the source-checkout fallback. Godot imported one skinned mesh, idle/walk/run/bite clips and 46 bones, versus 49 advertised. Rig, bite, doorway visibility and native-render QA passed; the model remains prototype-quality art. |
| Key ring and flashlight pickups | Original geometry authored in this task | No third-party asset license | Godot/scripts/props.gd; procedural PBR pickup meshes |
| Interface phone ping and power cue | Original generated waveforms authored in this task | No third-party recording license | Godot/scripts/soundscape.gd |
| Godot4.7.2 portable runtime | Godot contributors; official release | MIT and bundled third-party notices retained in Godot/licenses | Local editor/runtime; no Unreal Editor required |

The recovered house retains its original structure and editable source capture. Removed gift props, instructions, holiday hat, stacked entrance furniture and oversized entrance book barrier are enumerated in Godot/data/opening_edits.json. Runtime Unreal shader graphs and compiled gameplay were not recovered as editable source; standard-material approximations and new gameplay must not be presented as exact original behavior.

## Recovered material mapping and visual adaptation

The generated house uses original geometry, captured runtime material references and exported source textures. Surface order is resolved through each original LOD0 section's MaterialIndex, validated against the GLB material name and triangle count. Equal material counts do not imply matching slot order. Mesh_Floor_Attic_02 maps GLB surfaces to UE slots [1, 2, 0]: upward parquet, downward plaster, brick edges. Mesh_Wall_13 maps [3, 1, 0, 2]. This corrected 68 floor and 309 wall components in the retained capture. All 97 retained mesh assets passed the section mapping audit. A five-component saved/reloaded fixture preserved all 15 surface materials and texture paths.

Imported node ownership is flattened into the generated house while shared mesh/texture resources remain external. The builder compares every surface material and texture path after saving and reloading; a live-only override is not counted as successful serialization.

The cooked Mat_Base and ColorTexture/BaseTexture/Normal function metadata contain no shader expression connections. Primary textures and named values are recovered, but exact tint arithmetic, layer blending, detail normals and MTRAO channel wiring remain unknown. MTRAO channels are not assigned speculatively. Coverage complete means all requested surfaces were mapped; it does not mean exact Unreal shader fidelity.

The following deliberate Godot art adaptations were added after reviewing the correctly mapped entrance. They are authored approximations, not recovered source shader values. Original images and packages remain unchanged.

| Source material | Godot adaptation | Basis and limitation |
|---|---|---|
| Inst_Brick_01 | UV scale (1.0, 1.5); normal strength 0.35; roughness 0.92; metallic 0; dielectric specular 0.25 | Original wall UVs measure about one unit/metre. The atlas contains roughly five bricks across and ten courses vertically, producing about 0.20 m by 0.067 m courses. This replaces the visibly oversized source-scalar preview and reduces exaggerated relief. Mortar, irregular brick edges and transformed components vary. |
| Inst_Concrete_01 | UV scale (1, 1); normal strength 0.12; roughness 0.95; metallic 0; dielectric specular 0.20 | Fine aged plaster approximation. Recovered linear base tint (0.165, 0.143296, 0.096768) is blended 30% toward white, yielding approximately (0.4155, 0.4003, 0.3677), converted with Godot linear_to_srgb() to approximately (0.6767, 0.6654, 0.6404) and applied uniformly. Godot material colors use sRGB input, so assigning the linear numbers directly would darken the plaster twice. The original alpha-controlled tint operation is not available. |
| Inst_Parquet | No additional art adjustment | Retains recovered parquet diffuse/normal references and the existing primary UV approximation (05.Scale = 0.1). Exact layered gloss and tint are not claimed. |

Each affected material records its source UV approximation, final values and rationale in house_import_report.json under art_adaptation and approximations. These settings require a regenerated house scene; the art pass itself did not run a full build or renderer. Final visual validation is recorded separately from parser and serialization checks.
