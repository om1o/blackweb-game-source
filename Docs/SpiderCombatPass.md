# Spider combat — 2026-11-05

The active Godot game now supports a killable adult and two combat juveniles. Reaching the exit refuge still resolves the encounter; defeating the adult also unlocks that same exit. The earlier complete ZIP is an unchanged snapshot from before this pass.

## Balance and behavior

| | Adult common flesh spider | Juvenile common flesh spider |
| --- | --- | --- |
| Health / armor | 100 / 0 | 12 / 0 |
| Worn knife | 4 damage; 25 hits from full health | 4 damage; 3 hits |
| Attacks | Stationary close bite: 18; committed straight lunge: 35 | Bite: 4 in the house |
| Tell | Bite 0.55 s; lunge 0.85 s | 0.28 s |
| Contact | Bite 0.12–0.32 s after tell; lunge 0.10–0.60 s | One contact at the end of the tell |
| Recovery | Retreat, then 2.6 s cooldown | 0.50 s stationary recovery; 1.6 s cooldown |
| Hit reaction | 0.32 s stagger; cannot stagger again for 1.5 s | 0.22 s stagger; cancels bite |
| Death | 1.1 s rig collapse; visible nonblocking corpse | 1.5 s corpse hold, then hidden |

The house reads numerical balance from `Godot/data/common_flesh_spider.json` through `scripts/spider_profile.gd`. Test fixtures can still override exported values. The JSON also describes fixed implementation details such as the contact windows; changing those descriptive fields alone does not change their code constants.

Attack direction is committed when the tell begins. Contact requires range, floor/height checks, the forward cone and current unobstructed geometry. The adult tests both a ray and body-width sweep, including initial overlap, on physics ticks. Damage happens once per attack. A closed door, sidestep, retreat or player recovery can prevent a hit. Repeated knife swings cannot reset adult recovery forever: after stagger it can counterattack while its stagger resistance is active. Corpses and the harmless sighting are excluded from knife target selection.

The adult sees within 12 m and a 240-degree cone, with close-range awareness inside 2.4 m. Moving at least 2.5 m/s within 4.5 m supplies a hearing cue. This is a speed-based approximation of running footsteps, not an acoustic simulation. The predator remembers a sensed position for 4.5 seconds; it does not continually read a hidden stationary player's position to steer. On losing that memory it stops and searches. A small doorway waypoint graph routes around the retained partitions; every edge checks body clearance and floor support. Fixed edges expire after 0.6 seconds, route decisions run at most every 0.35 seconds, and actual movement always obeys collision. Closed doors block pursuit; spiders do not open doors or climb walls.

Flashlight behavior stays weak: adults lose at most 3 total HP and cannot die from the beam, with up to 5% slowing for the common type. Juveniles slow by up to 20%. Checkpoint restart clears attacks, death, health and movement, and returns enemies to their placed spawn positions. Pausing the game pauses combat.

## Animation and sources

The adult keeps its recovered 142-joint rig and idle/walk/run clips. Its close bite, lunge, flinch and death use authored poses on that rig. Base clips advance manually in physics before additive posing, preventing a later idle update from erasing the attack. Locomotion speed follows actual displacement. There is no claimed imported adult bite/death clip or contact-aware leg IK.

The juvenile uses the existing Literock model and its actual one-second Bite clip at 2.3× playback. The hit at 0.28 seconds falls during fang closure; recovery preserves the rest of the animation. Native review found that its anatomical forward is +Z, while the actor moves along -Z. A Literock-only 180-degree visual correction now points its head and fangs toward the attack; tests cover activation, world turning and checkpoint revival. The local Lite asset lacks hurt/death clips, so those remain procedural. The CC0 source-checkout fallback retains its own compatible clips.

[SpiderCombatSources.md](SpiderCombatSources.md) records the inspected rigs, publisher links, Godot APIs and primary combat-design references. It distinguishes source facts from this game's tuning decisions. This pass did not download or purchase new assets.

## Verification

The source regressions cover attack timing, one hit per attack, blocked/closing doors, sidesteps, dead targets, pause, recovery, sustained knife pressure, health, death, checkpoint cancellation and reset. Navigation fixtures check detours, closed/reopened doors, missing floor and overlap. House integration and portable checks validate the shipped runtime; native staged captures review poses separately from automated behavior. The final package passed 141 combat/navigation/house/rig checks and 31 startup checks. Source equipment (53), traversal (23) and progression (56) checks also passed. [SpiderCombatValidation.json](SpiderCombatValidation.json) records the artifact hash and suite counts; the local copy is `Evidence/spider-combat-validation.json`. Staged captures are not a human playtest or a guarantee of final production animation quality.

The local headless route-query sample on the i5-6600 measured warm median 2.506 ms and p95 4.899 ms, with an initial cold query of 13.350 ms. Cache-invalidated median was 4.336 ms. An existing native game was running, so these are elapsed micro-measurements, not controlled FPS results. A tested A* ordering experiment lacked a consistent improvement and was reverted; the cached/throttled collision-checked route implementation ships unchanged. Reproduce with `Tools/Performance/measure_spider_navigation.gd`.

Run `Tools/Packaging/TestSpiderCombat.ps1` to repeat the five combat/rig suites against the actual PCK from an isolated directory; `TestPortable.ps1` separately checks packaged dependencies and startup.
