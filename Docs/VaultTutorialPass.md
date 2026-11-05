# Vault, leather armor and tutorial interaction pass

The five-room house now includes a readable paper close-up, a physical locked vault door with an original keypad interface, four leather armor pieces and a persistent cash wallet. The three initial tools remain the weak flashlight, worn knife and candy bar. The 50-cell backpack retains three quick-item slots; shirt, pants, hood and shoes use four separate armor slots.

## Play the tutorial

Enter the house to see the eight-second arrival camera and captions explaining Luke's return from his maintenance shift. Enter, Space or Escape skips it. Listen to Mica's call. Take the vault key and salvage cells from the spare flashlight. Mica's last line points toward a plant: inspect the hidden note beside the potted plant in the record room. Papers pause gameplay, animate into a large readable sheet and remain open until dismissed. The code is also recorded in inventory after discovery.

Use the vault key and four-digit code at the reinforced door. The code is **0417**. The door uses its existing animated hinge and moving collision. Inside, open the leather field kit to take each piece. Press **I**, select a piece, then **Equip selected armor**. Click a worn slot to remove it. Armor never displaces a quick item.

| Item | Effect |
| --- | --- |
| Leather shirt | 6% damage reduction |
| Leather pants | 5% damage reduction |
| Leather hood | 4% damage reduction |
| Leather shoes | 3% damage reduction |
| Full kit | 18% total reduction; maximum health remains 100 |
| Worn knife | 4 damage at its delayed swing contact; checks body volumes and wall obstruction |
| Candy bar | 30 health after the eating action commits; no consumption at full health |
| Starting flashlight | 22% battery, intermittent low-charge flicker |
| Spare cells | Add 35 percentage points; battery drain remains 0.22 points/second while lit |
| Vault cash | $120 once, retained in the wallet; no shop or real-money transactions |

Interrupted unfinished healing/reload actions keep their item. Item use now reports full-health refusal, action start, result and interruption. Batteries have low/empty notices and replacement feedback. The tutorial spiders are ordinary animals: no magical attack glow. Small pooled natural-colored impact effects accompany the existing physical attacks, recoil and death behavior. See [NormalSpiderEffects.md](NormalSpiderEffects.md) for budgets and tests.

## Save and audio behavior

`user://blackweb_campaign_v2.json` stores story, survival inventory, equipment, armor, wallet, code/vault state and one-time loot claims together. The game writes a temporary complete record before replacing the primary and keeps the previous valid backup. Invalid nested data can fall back to the backup; unknown future save versions are protected. The old story checkpoint is loaded once for migration. Death retries use the current milestone. Restart opening intentionally clears this run's progress.

Mica's phone warning cuts off after the plant clue without speaking the code. Luke's response and web reaction use the same name. A shared dialogue JSON drives audio duration and subtitles. The pause menu's **Test voice audio** button plays a separate check line. The dedicated Dialogue bus runs at 0 dB; no Windows volume settings are changed. Voices are stock synthetic Kokoro voices, not recorded actors or actor clones. Detailed generation provenance and measured output are in [the audio README](../Tools/Audio/README.md).

## Visual provenance and limits

The paper reader, vault keypad, inventory armor row, plant and folded leather kit are original code-authored assets. The plant and garments are lightweight prototype geometry, not scanned or production-finished character clothing. Equipping armor applies protection and records the loadout; it does not replace Luke's character costume with a new clothing rig.

Higgsfield's Cinema Studio Video 3.0 quoted 40 credits for an eight-second intro. Submission was rejected for insufficient credits; the account reported 1.7 available and no usable free generation. No video was produced and no trial was activated. The shipped arrival is an in-engine camera sequence with captions, not a Higgsfield clip.

## Implementation references

- [Godot input event flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html): inventory toggle is handled before GUI focus can consume it, while gameplay remains in unhandled input.
- [Godot Control](https://docs.godotengine.org/en/stable/classes/class_control.html): modal controls handle their own mouse input and retain keyboard navigation.
- [Godot pause/process modes](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html): the house pauses during reading, inventory and keypad use while their controls and arrival tween continue.
- [Godot AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html): native audio checks inspect real mixed PCM without altering the output.

Focused automated evidence: player survival 66/66; campaign/save recovery 54/54; native phone audio 34/34; intro lifecycle 16/16; effects/hurt volumes 25/25; native paper mouse input 17/17. The assembled native game passed 34/34 journey checks, including inventory input, readable papers, the key/code gate, four once-only leather rewards, equipping armor through the actual GUI, cash persistence and a mouse-triggered candy heal. Six captured screens were inspected. That review led to hiding the normal HUD during the arrival sequence; the intro lifecycle tests cover visibility restoration on finish, skip and cancellation.

The native paper fixture uses the actual player focus rays, captured mouse handler, paper object and reader. Clicking a physically focused paper opens the modal without consuming candy, healing, toggling the flashlight or draining its battery. Closing restores gameplay, and a click with no paper focused still uses the flashlight. House collision checks separately found the original plant note below a retained table; it now rests on that table at y=1.0782 beside the floor-supported plant. Headless package tests use real E input because the dummy display cannot capture a mouse; they do not claim native mouse coverage.

The native audio test measured mixed output from Windows WASAPI; physical speaker audibility still depends on the user's output device. Native startup on the test Intel HD 530 took several minutes, so this pass does not establish a loading-time or frame-rate improvement.

The final isolated portable build passed 36/36 checks outside the source project, with no test failures: packaged resources and critical hashes, actual scene startup, 400 connected standing-capsule approach cells, physical focus on cash/kit/note, and E opening the reader. Godot emitted one test-harness warning during synthetic key-release cleanup about reusing an input-event object; the interaction assertion had already passed. This event injection is not part of normal gameplay. The PCK contains 1,809 files and is 1,013,311,948 bytes; its SHA-256 is `4713FBB34E7C27A49511A50688DD2A0C9234FE36B996B295551E403E450F6510`. The full portable folder is about 1.19 GB. Reports and screenshots are retained locally under `Evidence/VaultTutorial`.
