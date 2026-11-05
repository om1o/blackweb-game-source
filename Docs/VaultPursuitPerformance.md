# Vault pursuit and frame-time investigation

The expensive case was a juvenile repeatedly pushing toward Luke through the room partition and into a coffee-table collider. The fix makes directed juvenile pursuit require a clear static sightline. A blocked juvenile decelerates and idles while remaining active, collidable and subject to gravity. Opening a door or entering the same side of the wall restores pursuit immediately. Existing bite windup, impact checks, damage and animation remain intact.

## Diagnosis

The earlier full-route report's vault `TIME_PHYSICS_PROCESS` median of 16.999 ms was a median of repeated cached monitor values. Godot's main loop publishes the previous interval's **maximum** physics duration approximately once a second; it is not an average individual tick. See [Godot's main-loop implementation](https://github.com/godotengine/godot/blob/master/main/main.cpp).

The scene census found 62 static shapes, including 38 concave shapes and 17,809 triangle instances. The vault overlaps 16 shapes / 3,076 triangles, fewer than several other rooms. At the sampled vault point, 200 standing-capsule sweeps had a 3 µs p95; overlaps 4 µs; focus rays 15 µs. These synchronous headless queries exclude animation, movement integration and rendering and do not establish native frame performance.

The subsequent native callback trace isolated `MiniSpider1`, the supply-room juvenile, as the larger cost when Luke occupied the vault. A separate in-memory scope around its `move_and_slide()` accounted for 97.94% of that callback's measured wall-clock time in the traced contact case. It slid east along the spine toward an unseen target and repeatedly contacted the recovered coffee table near (3.069, 0.400, -0.274). Clock scopes include ordinary OS scheduling and are not a hardware CPU profiler.

The table's original bounds were (1.678, 0.400, -0.223) to (3.664, 1.066, 1.696), intersecting both the z=0 spine and x=3.2 crossing wall. Its relocation is a separate layout correction; **the comparison below did not move it or change any artwork**.

## Controlled native A/B/A comparison

Three separate source-runtime processes ran sequentially on 2026-11-05, after the hand animation changes and before new environment dressing. A1 and A2 replace only the new pursuit expression in memory with its previous through-wall behavior. B uses the corrected source expression. The resource is never written back. All three use the same timestamp instrumentation and unchanged on-disk source hashes.

Each run used the same vault location, an 8-second camera pan after 6 seconds of settling, active real encounter AI, original collision, original artwork and normal enemy HP. Luke received 1000 HP only to avoid a checkpoint reload truncating measurements. His ending HP was 972 in every run; nearby attacks remained active.

| Measured duration | A1: old pursuit | B: visible pursuit | A2: old pursuit |
|---|---:|---:|---:|
| Juvenile callback p50 | 4.211 ms | 0.098 ms | 3.960 ms |
| Juvenile callback p95 | 8.252 ms | 0.221 ms | 7.652 ms |
| Scene callback bracket p50 | 5.550 ms | 1.153 ms | 5.188 ms |
| Rendered frame interval p50 | 29.791 ms | 26.625 ms | 29.499 ms |
| Rendered frame interval p95 | 40.998 ms | 35.181 ms | 41.398 ms |
| Frame samples | 263 | 304 | 277 |
| Physics callback samples | 481 | 480 | 481 |

Relative to the mean of the two control percentiles, the corrected case reduced median frame duration by **10.19%**, p95 duration by **14.61%**, and the hot juvenile callback median by **97.60%**. This supports a targeted improvement in this vault workload. It is not a 100× whole-game claim or a new full-route benchmark.

Runtime: Godot 4.7.2 Compatibility, ANGLE D3D11 on Intel HD Graphics 530, driver 30.0.101.1339. Requested/reported window 960×540, VSync enabled, 2× MSAA and 3D scale 1. The ViewportTexture size getter reported 674×378 throughout all three runs; no framebuffer readback was performed, so internal rendered pixel dimensions are not asserted. All three used identical configuration. Before and after process inventories found zero other Godot processes; desktop applications and OS work still share the device. The previously blocked helper process was untouched.

The script wrappers preserve one actor callback per physics tick and the actors' child animations, but introduce instrumentation/scheduling overhead. Frame intervals include rendering, presentation, automation and OS scheduling. The early/late callback bracket excludes the engine physics-server step and later message flush. RenderingServer signal spans are not GPU execution timings. Teleports happen only before settling; this is an attribution workload rather than a traversal or balance test.

## Regression checks

- `juvenile_pursuit_tests.gd`: **12/12**, exit 0, clean diagnostics. Covers opaque wall, active collision, floor settling, authored idle/walk clips, reopening a door, closing it during pursuit, airborne gravity, target entering the same side, and awareness range.
- `juvenile_bite_occlusion_tests.gd`: **9/9**, exit 0, clean diagnostics after its test-only shutdown wait. Confirms closed-door and jumping protection, imported bite animation, authored damage, cooldown and impact-time revalidation.

The first bite regression invocation passed but exited with two audio references. The verbose diagnostic identified one generated AudioStreamWAV and its playback. Waiting 0.12 seconds **after** freeing the fixture lets the mixer release them; this changes test teardown only. The original warning/verbose logs remain available.

## Reproduction and evidence

From the project root:

```powershell
& '.\Godot\runtime\Godot_v4.7.2-stable_win64_console.exe' --path '.\Godot' --resolution 960x540 --script 'D:/GameProjects/BlackwebHouseRebuild-20261103/Tools/Performance/vault_phase_probe.gd' -- --seconds=8 --settle=6 --rooms=vault --trace-mini-move --output=D:/GameProjects/BlackwebHouseRebuild-20261103/Evidence/vault-repeat-B.json
```

Add `--legacy-through-wall-pursuit` for the old-behavior control; the harness refuses that control if the expected source expression no longer exists. Coordinate native slots and freeze active source/art for a fair comparison. New dressing or table placement requires separate integration checks.

Evidence directory:

- `vault-collision-audit.json` and `.log`: complete shape census and query probe.
- `vault-phase-native-baseline.json`: initial five-room attribution trace; cold render spikes make it unsuitable as a new full-route FPS result.
- `vault-contact-baseline-headless.json`: exact move scope, positions and collider names.
- `vault-native-A1.json`, `vault-native-B.json`, `vault-native-A2.json` and their logs: raw controlled samples.
- `vault-native-aba-manifest-before.json`, `vault-native-aba-manifest-after.json`: zero competing Godot processes and unchanged six-file source hashes.
- `vault-native-aba-summary.json`, `vault-performance-conclusion.json`: comparison and limitations.
- `juvenile-pursuit-tests.log`, `juvenile-bite-after-pursuit-clean.log`: final focused checks.
- `juvenile-bite-after-pursuit.log`, `juvenile-bite-after-pursuit-verbose.log`: preserved pre-cleanup warning evidence.

Source base was `fc7a2bc06747978261610d88f8a066707159b989` with uncommitted hand and pursuit fixes. Exact runtime source hashes are recorded in each JSON; this document does not identify a newly packaged build.
