# Original web mesh masters — integration contract

Created for Blackweb in Higgsfield 3D Jutsu hosted Blender 5.2, project `d27bc245-6bad-46df-b021-f465408ffe17`, revision 3. All mesh construction is original deterministic Python geometry. No third-party meshes, recovered artwork, uploaded art, paid generation jobs, credit purchase or agreement acceptance was used. Balance was 1.7 credits before and after the work: observed credit spend 0. The account remains on the free plan; no claim of a general future pricing guarantee is made.

Runtime file: `res://assets/generated/web_master/web_masters.glb` (471,596 bytes). Editable source: `Tools/Assets/web_master/web_masters_source.blend` (1,425,130 bytes). The source studio camera and two lights are retained in the `.blend` for inspection, and removed from the runtime GLB. `prepare_runtime_glb.cjs` resets the three semantic roots to identity and removes only studio JSON nodes; exported mesh buffers remain untouched. `web_masters_studio.glb` is the unmodified authorized service download.

| Root | Godot size X, Y, Z (metres) | Local bounds minimum | Triangles |
|---|---|---|---:|
| `WebRadialTorn` | 2.748752, 2.065946, 0.134875 | -1.481935, -0.974635, -0.066695 | 4,438 |
| `WebSaggingCanopy` | 2.701477, 0.626528, 1.901249 | -1.350514, -0.562754, -0.950613 | 10,258 |
| `WebFurnitureCocoon` | 1.580384, 1.046844, 1.140497 | -0.790192, -0.020703, -0.573498 | 9,932 |

Total: 24,628 triangles. Each root has exactly two mesh children, each with one opaque `WebSilkRough` material surface. No alpha planes, textures, collisions, cameras, or lights exist in the runtime asset. Base colour is muted grey-ivory, roughness 0.84, metallic 0. No UVs are supplied because this geometry uses a plain material and does not need texture coordinates. Godot import preserves finite vertices/normals, opacity, dimensions, hierarchy and triangle counts.

`WebRadialTorn` lies in local XY; local Z is its shallow depth. Place its origin near the intended wall attachment centre; the hub is deliberately offset and the anchor tips are uneven. Rotate about local Z for variation, then orient XY to a wall, doorway corner or window. Inspect anchor tip intersections so they attach to real surfaces rather than float.

`WebSaggingCanopy` spans local XZ. Its origin is near the upper attachment plane and it sags about 0.56 m along negative Y. Place it below a ceiling or between furniture attachment points; use existing loose ends as hanging fibres. It has three denser regions and open negative space, rather than a solid sheet. Keep it out of the player's sightline where dense overlap would obscure navigation.

`WebFurnitureCocoon` wraps an irregular rounded furniture volume with crown sag and crossed binding. Origin is near the base centre, with loose ends extending approximately 0.021 m below it. Place the origin at floor height +0.022 m when desired; otherwise tuck those ends into the floor or furniture. It is a generic wrap, not a scanned model fitted to a particular chair. Match scale and position to each prop and review clipping/contact.

Extract the desired root from an instantiated PackedScene, remove it from that scene, free the unused scene, and then attach it to the dressing parent. Root transforms are already identity. Reuse the same PackedScene/resource cache. Runtime selection/placement is deliberately left to the integration owner; these files do not alter `house_dressing.gd`, `player.gd`, `main.gd`, the site, or packaging.

The two mesh draws per instance are intentional structural/fine-strand groups. Visibility range and shadow settings belong to the game integration; dense placement should be profiled. Prefer a modest number of these near anchor points and use the existing texture approach for distant fine silk. This task did not run a native gameplay/performance test after placement because placement is not part of this lane.

## Verification and visual limits

Godot 4.7.2 headless editor imported the GLB successfully. The only editor warnings concerned pre-existing Luke `Textures`/`textures` path casing, unrelated to this asset. The standalone validation completed **28/28**, exit 0, without warnings/errors/leaks; see `validation.json` and `godot_validation.log`.

Inspected hosted Blender renders: `radial-detail.png` (radial unchanged after revision 2), `canopy-final.png`, and `cocoon-final.png` (revision 3). Intermediate blockout/detail images are retained to explain the refinement. The final canopy and cocoon contain crossed, uneven strands rather than the initial regular grid. Fine strands are still deliberately oversized compared with real microscopic spider silk for visibility at game distance. This is a game geometry treatment, not a photographic scan, cloth simulation, or AAA certification. It does not fulfill the separate 90 MB surface-art request by itself. Fibre softness, subpixel shimmer, placement contact and scene lighting still need in-game review.

## Reproduction

`build_all.py` concatenates the original blockout, detail and density stages and can be run in an empty Blender scene. Hosted creation used separate revision-guarded stages and visual checks. `prepare_runtime_glb.cjs` converts the authorized studio export into the clean runtime GLB. Run `validate.gd` with the project's Godot binary after import. No runtime integration source was edited by this pass.
