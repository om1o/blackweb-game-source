# Asset and geometry performance opportunities

Static inventory, 2026-11-03. These are candidates, not measured speedups. The current project stays within the 5 GB logical footprint limit; do not make a full asset copy for experiments.

## Highest-value measured direction

The separate native profiler measured 37.45 ms at the entrance with static practical shadows, versus 28.31 ms with shadows off, and draw calls fell 496 to 161. The two shadowed practicals are at [0.211, 2.133, 0.408] (5 m) and [-3.439, 2.963, 0.226] (7 m). Disable only their shadow casting if the native A/B image is acceptable, while retaining their light and the player's flashlight shadow. Individual-light A/B belongs to the renderer profiler. The other 44 practical lights do not overlap the entrance spawn at [-2.16025, 1.48, 0.06718].

## Texture and material inventory

- 249 recovered PNGs: 158 at 2048x2048, 65 at 1024x1024, 11 at 4096x4096, and 15 smaller. Their full RGBA source footprint is approximately 3.50 GiB before VRAM compression, mipmaps, import size limits, or deduplication; this is **not** the actual video-memory usage.
- Godot imports already use S3TC/BPTC compression and mipmaps with `process/size_limit=2048` (example: `RecoveredAssets/Arachnophobia/Content/VHExterior/Textures/T_Parquet_D.png.import`). Resizing 4K source textures to 2K cannot reduce the imported maximum resolution. A targeted 1024 import limit for nonhero props could reduce their upper mip storage by up to 75% per texture, but actual frame-time benefit is unmeasured and visible softness needs review.
- `Godot/scenes/recovered_house.tscn` has 877 MeshInstance3D nodes, 2,077 StandardMaterial3D resources, and 1,931 normal-map references. `T_Concrete_N_01.png` and `T_Brick_N_01.png` appear 686 times each; next are `T_Plates_N.png` (180) and `T_Parquet_N.png` (68). Concrete normal strength is only 0.12, brick is 0.35. A bounded probe could disable the concrete normal only while retaining brick, floor, and hero normals, then compare entrance frame time and image. Counted scene references are not the number of simultaneously visible surfaces.
- 41 materials explicitly enable transparency. Broad transparency changes have lower expected value and substantial visual risk.

## Geometry and culling

- Existing `Godot/scripts/house_batching.gd` batches 232 of 877 mesh instances into 78 batches, reducing estimated source surface submissions by 582. Native entrance draw calls only fell from 584 to 496 because ordinary view/occlusion culling already removed many offscreen instances. Validation `Godot/validation/batching/report.json` excludes 496 meshes due to per-instance 24 m visibility ranges set in `Godot/scripts/main.gd::_setup_house_visibility`, and 125 due to nonuniform/sheared transforms. Additional batching would require preserving source-by-source visibility and a measured draw-call bottleneck.
- The saved scene has 1,381 `cull_mode = 2` materials, including the structural wall/floor materials. The recovered Unreal source explicitly sets `TwoSided=true` on `Inst_Concrete_01` and `Inst_Brick_01`; current Godot material conversion preserves it. Leave source semantics intact unless a native visual/performance probe justifies a narrowly scoped change.
- The specific `Mesh_Wall_13.glb` is a closed 0.2 m slab: 12/12 triangles have index winding aligned with outward normals (0 reversed, 0 degenerate). `Mesh_Floor_Attic_02.glb` is a closed slab: 22/22 aligned (0 reversed, 0 degenerate). The raw component manifest contains 308 walls and 68 floors. Backface culling these two mesh types is geometrically plausible if all live transforms retain positive determinant and the camera stays outside slab volumes, but was **not** changed or rendered in this audit. Do not apply it to every two-sided material.

## Ranking

1. Preserve practical light colors and try removing only static practical shadow maps; this has the strongest measured win.
2. If the remaining frame time is shader-bound, A/B disable the subtle concrete normal on structural surfaces, then compare screenshot and timings.
3. Probe backface culling for the two verified closed structural meshes only, with wall/floor/ceiling visual checks and full traversal.
4. Consider 1024 import limits for selected nonhero prop textures only after visual inspection; mipmapping and current compression already mitigate this.
5. Revisit prop batching only if profiling shows submissions remain a bottleneck.
