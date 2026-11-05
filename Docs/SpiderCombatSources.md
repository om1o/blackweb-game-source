# Spider combat: verified assets and implementation sources

Checked 2026-11-05 for Blackweb's Godot 4.7.2 runtime. This is a research and integration record, not a claim that every recommendation is implemented. The code baseline inspected was `5d02124`; the adult and juvenile combat passes are being implemented separately. No asset was downloaded, purchased, uploaded, or replaced for this research.

Use this document for the current Godot implementation. `Docs/SpiderEncounter.md` describes the earlier Unreal/C++ proposal; its `ACharacter`, NavMesh and UE compilation instructions do not describe the running game.

## Local assets that actually fit

The following counts and source clip durations were read directly from local GLB JSON/accessors. Duration is source animation time, before gameplay playback scaling. These assets have different skeletons; matching words such as “bite” do not make animations interchangeable.

| Visual and local source | Actual rig | Available source clips | Practical use |
| --- | --- | --- | --- |
| Recovered adult: `Godot/assets/recovered/Arachnophobia/Content/Spider/SpiderAnimated.glb` | One skinned mesh, 142 skin joints | `Idle` 1.64948 s; `Walk` 1.64948 s; `Run` 0.31615 s | Keep the adult visual and author its attack poses on its own bones. No bite, leap, death or hit-reaction clip is present. |
| Literock juvenile: `Godot/assets/third_party/literock/Giant_Spider_Lite_1K.glb` | One mesh, 46 skin joints | `bite` 1.00000 s; `idle_loop` 3.00000 s; `walk_loop` 1.06667 s; `run_loop` 0.53333 s | Already compatible with the juvenile. Use the existing authored bite and preserve its recovery. |
| Quaternius source-checkout fallback: `Godot/assets/third_party/poly_pizza/quaternius_spider/quaternius_spider.glb` | One mesh, 39 skin joints | `SpiderArmature\|Spider_Attack` 0.75000 s; `...Death` 1.04167 s; `...Idle` 4.16667 s; `...Jump` 0.70833 s; `...Walk` 0.83333 s | Keep as a functional fallback; its stylized low-poly appearance does not meet the requested realism. Its clips belong to this rig. |

The [Literock publisher](https://literock-studios.itch.io/giant-spider-lite) lists four clips, a 9,974-triangle mesh, embedded 2K base-color/normal/metallic-roughness maps and GLB support for Godot. It advertises 49 bones. **Both local original 2K and derived 1K GLBs contain 46 skin joints**, so 49 must not be hard-coded as an import requirement. This is a discrepancy between the published description and local asset, not a confirmed import loss. The 1K file is 4,469,232 bytes; the preserved original is 16,370,364 bytes. The publisher identifies AI-assisted mesh/texture creation and authored rigging/animation; this is not motion-capture provenance.

The local `LICENSE.txt` allows modified assets packaged inside an end product and prohibits standalone asset redistribution. Keep the existing Literock Git exclusion. Its publisher mentions a larger pack on matching bone names, but no purchase is required for this pass and compatibility with the recovered adult is not implied. The [Quaternius listing](https://poly.pizza/m/yRYJiAJyiM) identifies the fallback as animated FBX/GLTF under CC0.

## Actual bindings and useful bones

`Godot/data/house_layout.json` selects `res://scenes/spider_visual.tscn`. `main.gd::_create_spider()` binds adult `idle`, `walk`, and `run`; it does not bind `windup_animation`. `tools/build_spider.gd` builds the scene from the recovered asset, resamples at 60 Hz, freezes idle to a one-second resting pose, removes horizontal root displacement, and produces approximately 1.09965-second walk and 0.45164-second run loops. The capsule controls travel; replaying raw root motion as well would introduce a second movement source.

The existing adult attack poses use these verified, case-sensitive names:

- Front legs: `LegSegmentA_L_001`, `LegSegmentA_R_001`, `LegSegmentA_L_002`, `LegSegmentA_R_002`.
- Pedipalps: `PedopalpSegmentA_L`, `PedopalpSegmentA_R`.
- Fangs: `Fang_L`, `Fang_R`.
- Additional source body anchors include `Root` and `Back`.

Literock instead has `body`, `abdomen_01`, `abdomen_02`, `head`, `fang_L`, `fang_R`, and five segments per leg: `coxa_`, `femur_`, `tibia_`, `metatarsus_`, `tarsus_` with `L1`–`L4` and `R1`–`R4` suffixes. Do not paste the adult bone map into this rig.

Raw Literock names have `_loop` suffixes; the imported runtime uses `idle`, `walk`, `run` and `bite`. Godot's [import suffix documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html) explains that suffix processing may change import behavior. Query `get_animation_list()`/`has_animation()` when integrating instead of guessing raw names. Existing `juvenile_visual_tests.gd` exercises these imported clips and fang motion; its pre-pass log records 19 checks passing, not a new test run by this research lane.

### Juvenile bite timing

Read-only source-key analysis finds left-fang rotation furthest from its initial pose at 0.300 s (33.26 degrees); it is almost back by 0.733 s. Body pitch peaks at 0.500 s (14 degrees) and returns by 1.000 s. These are measured rotations, **not a verified fang-to-player contact frame**.

The juvenile implementation uses 2.3× bite playback: the one-second source clip therefore lasts about 0.435 real seconds. The combat lane retained a 0.28-second gameplay impact (about 0.644 source seconds, while fangs are closing) and added 0.50 seconds of post-impact recovery. That choice is our combat design, not a publisher specification or mocap guarantee. Preserve the remainder of the clip rather than switching immediately back to walk at impact. A side-view native capture should still confirm that the visual contact, sound and health change read together.

## Engine facts and how they apply here

| Primary source | Verified behavior | Blackweb integration recommendation |
| --- | --- | --- |
| [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) | Supports animation libraries and transition blends. `play()` updates when processed; `advance(0)` applies it immediately. | Resolve names against the loaded rig. Select attacks on state entry, blend between states, and prevent walk selection from cutting off a bite. |
| [AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html) | Offers physics, idle and manual processing. Manual processing requires `advance()`. Looping clips do not emit `animation_finished`. | Give pose evaluation one clear owner. If physics code adds adult bone poses after evaluating a base clip, ensure an automatic idle update does not overwrite them later. Do not wait for a looping locomotion clip to finish before attacking. |
| [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) | `move_and_slide()` resolves movement collisions. `get_position_delta()` and `get_real_velocity()` report movement resulting from that call. | Keep capsule movement authoritative and choose locomotion/stride speed from actual travel, so a blocked spider does not keep running in place. |
| [Ray casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) | Direct-space queries should run in `_physics_process()` because the space can otherwise be locked. | Keep perception and damage geometry checks in physics updates; animation events may request a hit check, not bypass it. |
| [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) | Rays report obstruction; `cast_motion()` returns safe/unsafe movement fractions. A shape already overlapping at the start is ignored by `cast_motion()`; overlap queries are separate. | Check range, elevation, obstruction and attack volume at impact. Use an initial-overlap check where needed; a successful sweep alone is not proof that the start is clear. |
| [PhysicsRayQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters3d.html) | Queries take a layer mask and excluded RIDs. `hit_from_inside` handles interior starts for supported solid shapes, but not concave polygon or heightmap shapes. | Use the project's world mask for doors/walls, exclude the attacking body, and test closing doors and corner starts. Do not treat this flag as a universal inside-mesh solution. |

These links are the official stable documentation checked on the date above. The installed runtime reports 4.7.2; runtime regression tests remain the authority for this project rather than assuming every future stable-doc addition exists locally.

## Primary combat guidance, separated from our design

[Michael Booth's Valve presentation](https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf), pages 38–43, separates locomotion, body animation, vision and intention, and describes sight/lost-sight events. Its fairness discussion on page 48 concerns survivor bots and imperfect knowledge. **Our adaptation:** keep target perception separate from collision movement; a hidden player's current position should not continuously drive pursuit through a closed partition. Store a bounded last-seen position only after actual sight, stop at blocked routes, and clear memory on checkpoint/recovery. This does not import Valve's whole AI architecture or its teammate-teleport behavior.

[Epic's AI Perception documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine) distinguishes sight acquisition, losing sight, hearing stimuli and expiration. **Our adaptation in Godot:** explicit acquisition/forgetting rules and optional short memory make sense; Unreal components or Blueprint nodes are not dependencies. Hearing would require actual emitted noise events, not invented omniscience. Exact ranges, cone widths and memory seconds are Blackweb tuning decisions.

[Guerrilla AI programmer Romi Geleijn](https://www.guerrilla-games.com/read/guerrilla-spotlight-Romi-Geleijn) emphasizes communicating an enemy's intended attack so the player can form a counter-strategy. [Beca Vessal's Psychonauts 2 boss presentation](https://media.gdcvault.com/gdc2023/Slides/CraftingEpicBoss_Vessal_Beca.pdf), pages 26–29, separates telegraph, attack and recovery. **Our adaptation:** readable front-leg lift, fang/pedipalp motion and a restrained audio cue before damage; a committed attack direction; then visible recovery. Exact adult/juvenile damage, durations and effects are our design, not values prescribed by these talks.

For this five-room tutorial, retain one common type with adult/juvenile presentations, make the first sighting harmless, and let geometry and recovery provide counterplay. Check one-hit-per-attack, sidestep, jumping out of juvenile reach, door closure during windup, death/checkpoint interruption, and large frame steps that cross the impact time. Damage should occur once when the timer crosses its threshold, never depend on an exact floating-point frame and never replay after cancellation. These are proposed acceptance cases, not new test results in this document.

## Remaining art limits

The adult has no source attack/death/hit clips; its current front-leg and fang attack is procedural posing of the real rig. Literock Lite has no death, hit, leap, turn or web-spit clip. The local juvenile collapse is procedural unless the fallback's own death clip is used. Neither asset provides wall/ceiling crawling or contact-aware leg IK in this implementation. Additional polish requires authored rig-specific animation and native review; generic humanoid animation packs, rendered video, larger texture files and unrelated spider clips do not solve skeleton compatibility or physical contact.
