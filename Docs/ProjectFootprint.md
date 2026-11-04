**Project storage footprint — current build 2026-11-04; historical Phase 0 snapshot below**

The current Blackweb tutorial-opening [build report](../Playable/build-report.json), dated 2026-11-04, measured **4,074,135,247 logical project bytes** at build time, below the 5,000,000,000-byte cap by 925,864,753 bytes. The self-contained PCK is **878,467,740 bytes** with 1,725 packaged files; the full Playable folder was **1,118,847,716 bytes**, including retained UserData. PCK SHA-256: **5F6B60ACCF9B704A48A36B129385C98D04D41A4E7849D9467686953DAF7FCEC7**.

The last large PCK was 1,748,896,840 bytes. The current one is **870,429,100 bytes smaller (49.8%)**. Packaging replaced 248 recovered source PNG payloads, totaling 906,794,748 bytes, with zero-byte placeholders at the same resource paths. Godot `.import` mappings and all referenced imported texture caches remain in the package; the original PNGs remain untouched in the editable source project. The [isolated package test](../Playable/portable-smoke.json) passed **23/23 checks**, including every imported texture remap, an actual texture load, runtime material channels, the compact house and four opening interior doors, the active Literock juvenile visual, Luke's voice clip, and exactly one configured tutorial exit. Its stderr was empty. A headless package test does not establish rendered quality or route-wide performance.

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
