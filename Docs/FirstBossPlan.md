# First major boss and the greenhouse transition

**Status: story and encounter proposal only. No boss is added to the tutorial house in this release.** The creator wants the first major boss to overwhelm Luke and explain his awakening in the company greenhouse laboratory. The adult-subject creature below is a proposed direction, pending creative review.

**Creator's revised backstory:** the adult subject was a killer responsible for twelve deaths, connected to the nearby orphanage. The company secretly acquired him from prison for its experiments. His crimes are revealed through records and dialogue; victims are not depicted in the creature concept. The generated [Subject 12 concept](Design/first-boss-subject12-v1.png) explores this adult character in the greenhouse. "Subject 12" is a proposed specimen label, separate from the confirmed victim count. The [exact prompt](Design/FirstBossSubject12Prompt.txt) records the built-in imagegen call. This is concept art, not a new 3D model or implemented encounter.

**3D draft update, 2026-11-07:** a textured Meshy draft now exists for the approved stone-crown design. The current connection exposes its viewer but no downloadable formats. See the [model record and actual preview](SmilingSpiderModel.md). No importable boss mesh, rig, animation or encounter has been added to the game.

**Combat preview update:** [six authored attacks, a boss health bar and spoken dialogue](SmilingSpiderCombat.md) are now available in a separate Extras test encounter using the existing spider rig. The exact Meshy crown model, final story encounter and capture cinematic remain pending. This prototype does not add a boss to the five-room tutorial.

## Place in the story

The five-room house teaches light, inventory, movement and ordinary spider combat. After escaping, Luke follows Mica's interrupted transmission across web-covered Greyhaven. A company transport tag and a damaged emergency message lead toward a greenhouse on the edge of town. The first major boss guards the service approach, linking the town outbreak directly to the experimental facility.

The nearby orphanage remains a missing-person mystery: abandoned rooms, an evacuation list, a broken intercom and company transport records. Those clues establish what Luke needs to investigate without showing injured children or turning them into the creature. The boss originates from the company's **adult prisoner experiments**, consistent with the established premise. Luke and the player do not learn the entire conspiracy here.

## Creature proposal: The Smiling Spider

The creator named this boss **The Smiling Spider** and requested a fully arachnid silhouette. The current [v2 concept](Design/smiling-spider-v2.png) supersedes the humanoid body in the earlier Subject 12 study: a low cephalothorax, narrow pedicel, huge oval abdomen and eight jointed spider legs. The human resemblance is confined to the fixed, unsettling grin integrated into the spider's face. Short pedipalps and chelicerae frame it. There are no human arms or hands. Bloody chitin, red-black secretions and blood-soaked silk extend across the greenhouse glass, supports and floor. Sound uses leg impacts, strained breathing and distorted adult vocal fragments, with moments of silence before movement. The [v2 prompt](Design/SmilingSpiderV2Prompt.txt) preserves the built-in imagegen edit instructions and reference. Both images are concept studies; neither is a finished 3D asset.

Its signature behaviour is retrieval: it wraps living prey and returns toward the greenhouse intake. Early clues show silk trails running into the drainage channel. This gives its later capture of Luke a cause and destination.

## A playable first encounter

**Current visual revision:** the [v3 crown concept](Design/smiling-spider-crown-v3.png) retains the v2 spider anatomy and adds four intact limestone child portrait sculptures, arranged as a crown on the cephalothorax. Small square stone plinths and silk bindings make these unmistakably artificial memorial objects. Their faces have carved stone eyes, mineral grain and no blood or injuries. This symbolic crown follows the creator's accepted statue alternative; it does not depict human remains. The [two exact imagegen prompts](Design/SmilingSpiderCrownV3Prompts.txt) record the crown addition and portrait refinement. V3 is the latest visual study and remains concept art only.

The player objective is **"Open the service gate and get through."** The encounter has a visible task and a successful completion condition. Reserve a conventional kill-health bar for the later rematch; this meeting introduces an enemy Luke cannot yet kill with his worn knife.

1. **Recognition:** the silhouette crosses behind greenhouse glass. Luke has a short safe view of the gate, two jammed cable housings and cover before the fight activates.
2. **Pressure:** a heavy forelimb lift and directional scrape warn of a committed sweep. A second attack pins a doorway with silk for several seconds. Both leave a clear recovery window for Luke to move or cut a housing free.
3. **Counterplay:** each housing needs three normal knife contacts. The boss can be briefly redirected with a flare; the weak flashlight helps reveal movement but does not stun-lock it. No mandatory item is consumed to finish the fight.
4. **Escape:** after both housings are clear, Luke can operate the gate. Completing this task earns the checkpoint and initiates the short capture scene.

Initial greybox targets, all **unimplemented and subject to playtesting**:

| Parameter | Starting target |
|---|---:|
| Luke health | Existing 100 HP and equipped armour rules |
| Worn knife | Existing 4 damage; three contacts per cable housing |
| Sweep tell / active / recovery | 1.2 s / 0.25 s / 1.6 s |
| Sweep damage | 18 before armour, one hit per attack |
| Pinning silk tell / duration | 1.0 s / 4 s; slows, leaves an alternate path |
| Flare distraction | 3 s, with an 8 s distraction cooldown |
| Encounter duration target | 90–150 s for a first successful attempt |
| Concurrent threat | Boss only for the initial version |

Attacks commit to a direction after the tell. Hit volumes follow the animated limbs and use swept physics checks; scenery blocks contact. Damage requires an active attack window, never mere proximity. Every attack cancels on pause, restart and phase transition. Tune the physical gate route before commissioning final animation.

## Capture and awakening

As Luke reaches the service passage, the boss strikes a visibly damaged support. The walkway gives way; Luke catches the rail, loses his grip and lands in hanging silk. The creature retrieves him through the intake. Show his defensive movement, the failed grab and the fall in continuous shots, keeping the violence non-graphic. Sound and camera motion make the defeat forceful without a prolonged injury sequence.

The company tracker emits a short identification tone. Cut to darkness with greenhouse fans and an approaching trolley, then wake on a laboratory cot overlooking glass growing bays, containment cages and human-spider experiment silhouettes. Luke's first interaction frees his wrist restraint. His belongings are sealed in a nearby evidence tray. Mica's damaged transmission provides the next objective: **"Recover your gear. Find a way out."**

Preserve every owned item, cash amount, armour piece and quick-slot assignment in a chapter-transfer snapshot. Retrieval restores that snapshot exactly once. Checkpoint health may recover to a documented floor, but supplies must not be silently consumed during the cinematic. Skipping reaches the identical awake state. Dying during the playable encounter retries before the gate; completing it leads to the same capture regardless of remaining health.

## Production and acceptance gates

- Block out the arena, alternate route and two cable interactions using existing assets first. Validate with the current knife, flare and armour systems.
- Author a dedicated rig with walk, turn, sweep tell, sweep, recoil, silk cast, stagger, grab and retrieval clips. Preview foot contact and hit windows in Godot before buying or generating final art. No asset expenditure is authorized by this plan.
- Use animation-driven staging for the capture so Luke, the boss and the actual level match. A prerendered version can be produced from those approved assets after the scene works. Do not promise a generated video will match the playable rig.
- Test encounter completion with only the three starting items, depleted flashlight, low health, keyboard/mouse and every graphics preset. Inspect clipping, camera obstruction, save/reload, pause, skip and repeated retries.
- Target the existing performance budget with one boss rig, pooled effects, no additional shadow-casting lights, and disabled AI during the cinematic. Measure on the current PC before calling it smooth.

This plan adds a concrete reason for the greenhouse awakening. The tutorial house and its current ordinary spiders remain the implemented content.
