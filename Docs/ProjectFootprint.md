**Project storage footprint — current build 2026-11-04; historical Phase 0 snapshot below**

The current [build report](../Playable/build-report.json), built 2026-11-05T02:41:34.728823Z, measured **4,136,731,766 logical project bytes**, below the 5,000,000,000-byte cap. The self-contained PCK is **889,371,772 bytes** with **1,741 files**. The Playable folder was **1,131,024,532 bytes**, including preserved UserData. PCK SHA-256: **67116D7D34F15DF2147D5333213108993E833FB877F85AC5E5086989E2BB30FF**.

The isolated outside-project package test passed **28/28** checks with empty stderr. All four new Blender supply variants, label atlas, Mara warning and Luke reply load from the PCK. A separate final-package full-capsule traversal passed **20/20**, including all five rooms. Packaging still omits duplicate recovered PNG source payloads while preserving imported texture caches; original source textures are untouched. Native route performance and its limits are recorded in [WholeRoutePerformance.md](WholeRoutePerformance.md).

The detailed table below is the historical Phase 0 footprint snapshot. [Phase1Progress.md](Phase1Progress.md) records a separate early Phase 1 controller checkpoint; neither is the current package measurement.

The complete source project plus portable playable contains **4,599,114,815 logical file bytes (4.599 GB / 4.283 GiB)** on D:. This is below the strict **5,000,000,000-byte** project limit, leaving approximately 400.9 MB. It includes recovered assets, source, import caches, both bundled runtime copies, tools, evidence, existing portable UserData and the self-contained PCK. It measures regular-file lengths, not allocated disk blocks.

Directory junctions and symbolic links were skipped. In particular, Godot/assets/recovered points to RecoveredAssets, whose source payload is counted once. The PCK is an additional physical copy for portable use and is correctly counted separately.

| Project area | Logical bytes | GiB |
| --- | ---: | ---: |
| Playable | 1,926,078,176 | 1.794 |
| RecoveredAssets | 1,397,509,291 | 1.302 |
| Godot | 1,132,678,913 | 1.055 |
| Tools | 124,004,321 | 0.115 |
| Evidence | 18,498,899 | 0.017 |
| Docs | 219,919 | 0.000 |
| Source | 88,303 | 0.000 |
| .git | 27,276 | 0.000 |
| root files | 7,465 | 0.000 |
| Config | 2,252 | 0.000 |

The [portable launcher](../Playable/Launch%20Blackweb.cmd) folder uses **1,926,078,176 bytes (1.926 GB / 1.794 GiB)** at this snapshot. Blackweb.pck itself is **1,723,201,068 bytes**, with 1,566 packaged files. Its SHA-256 is 53E7E5894C53F8487F278FEBC380FE5A6710F9496E9987282B6B71EAB49E5939. The rebuilt [isolated package test](../Evidence/portable-smoke.json) passed all 17 checks, exit 0, with empty stderr. [Optimization report](OptimizationReport.md).

The count excludes the separate original-game/archive backup and SDK/recovery/packaging scratch under D:/CodexTemp. The replacement PCK was staged outside the project, then replaced the prior generated PCK after successful completion. Existing saves and cache were preserved and included in preflight. The playable can add UserData saves/logs after this snapshot. [ProjectFootprint.json](ProjectFootprint.json) records file counts, category totals and skipped links.

The separate C: relocation moved **1,535,358,578 bytes (1.430 GiB)**. It did **not** free the requested 5 GB. [StorageRelocation.md](StorageRelocation.md) contains exact paths and integrity checks.
