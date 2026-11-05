# Interface, physical documents and tutorial pacing

The house opening now uses one coherent interface: Barlow typography, an original corridor menu, restrained worn steel panels, clear button focus, the chosen thin Minimal meters and model previews in the 50-cell inventory. Three quick items and four separate armor slots retain their existing gameplay roles. See [HorrorInterfacePass.md](HorrorInterfacePass.md) for presentation behavior and [InterfaceAssetPrompts.md](InterfaceAssetPrompts.md) for the original artwork prompts.

## Read and listen

Physical papers and the reader share the same three generated document images. Wheel or +/- zooms from fit to four times fit, dragging pans, F fits the image, and T switches to the transcript. Reading pauses the house. E, Escape and the close button dismiss the reader without consuming an item.

A focused ringing phone accepts E or left click. Answering consumes the interaction instead of swinging a knife, using candy or toggling the flashlight. A louder original two-burst ring helps locate it. Options contains game-local Master and Dialogue volume, output-device selection and a voice test. Automated native audio checks inspect mixed PCM; they cannot certify the user's physical speaker volume or routing.

The latest Mica take is a continuous 6.344-second local fp32 Kokoro performance with subtitle changes aligned to measured pauses. A 1.2-second lost-connection beat precedes Luke's fresh reply. The web reaction and Options voice check also have new complete takes. Final-waveform transcription checks retained the required words, including the plant clue, and signal checks found no clipped samples. These are stock synthetic voices, not recordings of human actors. The original takes are preserved; generation settings, processing, source audio and timing are documented in `Tools/Audio/README.md` and `Godot/data/phone_dialogue.json`.

Spoken subtitles follow the actual mixer position with an 80 ms lead limit. The wall clock advances the silent gap, while the completion guard preserves both spoken endings under render stalls. Missing/stopped audio leaves the readable story timeline usable; a stuck playback object falls back after three active seconds instead of trapping the player. The final native audio suite passed 38 checks, including induced stalls, no overlap, pause/retry and the frozen-output fallback. Pacing and progression passed 40 and 56 checks respectively.

## The opening has room to breathe

The eight-second arrival establishes Luke's return from his maintenance shift. It can be skipped and respects reduced motion. Mica's interrupted call directs the player toward the vault key and the note beside the plant. The ordinary house spiders are separate from the company's experiments described in the optional records.

The plant and code note remain in the records room, outside the locked vault. The packaged collision fixture passed: it reaches and reads the note from the actual spawn while the vault is closed and the key has not been collected, so the puzzle does not depend on entering its own locked reward room.

Preparation requires the call, key, spare flashlight cells and unlocked vault, plus at least 18 seconds of active exploration after the call. Reading, inventory, menus and recovery do not consume this time. There is no deadline on clue hunting. The first harmless spider appears only in the 14-second Presence beat. A brief spatial cue follows the visual warning, then the power loss leaves eight seconds before the active encounter. No continuous horror music is added.

The weak starter retains 22% charge, 0.22 percentage points per second drain while lit, and the spare-cell +35 charge milestone. Its beam stays steady during onboarding; low-charge flicker becomes available only from Presence onward. Switching it off or holding another item conserves charge. Restoring a milestone restarts its current safety beat; New Game resets the sights, sound flags, gear, wallet, puzzle and timers.

## Rendering cost

Quality retains full 3D resolution and 2x MSAA. Performance retains full 3D resolution with MSAA disabled. Intel HD Graphics 530 initially selects Performance; a saved preference takes precedence. The command-line overrides `--graphics=quality` and `--graphics=performance` support repeatable comparisons and lock the picker for that run. The setting does not change Windows graphics preferences or drivers.

An open main/pause/options menu suspends 3D drawing behind its opaque artwork and restores the prior viewport state on close or removal. Inventory previews render the selected real model once into a small separate viewport. Hidden inventory text does not rebuild on every stamina update; it refreshes when opened. These are bounded implementation changes, not a promise of a particular frame rate.

The Fast launcher selects 960x540 and Performance. Both launchers accept `--graphics=quality` or `--graphics=performance`, including cmd.exe's unquoted equals-sign argument splitting; an explicit override after the Fast launcher takes precedence.

## Equipment and source

The four worn clothing meshes come from credited MakeHuman artists and are fitted to Luke's existing skeleton in Blender, with a leather material adaptation. They respect ownership, saved loadout and removal without duplicating the body rig. Source links, licenses, changes and remaining art limits are recorded in [ArmorIntegrationPlan.md](ArmorIntegrationPlan.md) and the bundled attribution. The folded vault pickup and plant remain prototype props.

## Reproduce verification

`Tools/BuildGodot.ps1 -Action Check` imports the project and runs the headless gameplay, save, reader, pacing and menu lifecycle suites. Native fixtures separately cover physical mouse input, rendered UI bounds, voice output, worn clothing and the assembled journey. `Godot/tests/tutorial_journey_tests.gd -- --visual --profile-graphics` also compares Quality/Performance/Quality in three fixed views of the already-loaded house. That comparison pauses simulation to isolate render cost; `Tools/Performance/profile_tutorial_route.gd` supplies the separate live five-room movement, attack and AI workload.

The release's actual results, launch conditions and limitations are recorded with the local `Evidence/InterfaceRelease` reports. Portable packaging checks run from an isolated directory outside the source tree before the live PCK is replaced.

The native assembled tutorial journey passed 51/51 checks, including actual inventory input, physical document viewing, phone dialogue completion, vault key/code flow, one-time rewards, worn clothing, candy use, save/restore and New Game reset. That run's first 3D presentation took several minutes on this machine; the interface changes do not establish fast cold startup.

The first live five-room route of this release completed without traversal failures with all four clothing pieces, walking, camera turns, knife actions and active spider AI. At an actual 960x539 framebuffer, Performance at 75% scale and no MSAA produced 1,687 frame intervals: 31.09 ms mean (about 32.2 FPS), 39.42 ms p95 and 1,270.88 ms maximum. About 1.19% exceeded 50 ms. No other Godot process was observed at launch. This is one scripted desktop run with VSync, not a stable-60-FPS or minimum-spec claim. The long stalls remain a limitation.

A controlled six-phase comparison in the same loaded house then measured Quality/native-no-AA/scaled-no-AA/scaled-no-AA/native-no-AA/Quality, with three fixed views, prewarmed configurations and no concurrent Godot process. At 1280x719, native-no-AA medians were 16.67–17.45 ms across both passes; 75%-scale/no-AA was consistently slower at 24.54–27.99 ms. Consequently the shipped Performance preset uses native resolution and no MSAA. Quality varied between passes, so these measurements do not establish a precise anti-aliasing speedup. This paused-scene comparison does not replace the separate live route.

The final live route with the shipped native/no-MSAA Performance setting completed with no failures. At 960x539 with all four garments and active spiders, 2,430 intervals measured 20.92 ms mean (about 47.8 FPS), 27.84 ms p95, 35.17 ms p99 and 579.43 ms maximum; 0.29% exceeded 50 ms. Before/after process snapshots contain no other Godot renderer. This later run improved on the 75%-scale baseline, but the separate live runs are subject to ordinary desktop and thermal variation. Occasional hitches and slower initial loading still prevent a claim of perfect smoothness. See `performance-live-final.json`; the earlier report remains preserved as `performance-live-route.json`.

The final portable package passed 50/50 checks from an isolated directory outside the project, with exit 0 and no runtime errors. Its 1,920 files include generated documents, Barlow fonts, new voices, four bound garment meshes, original inventory models, licensed juvenile spiders and all required imported textures. Hash checks now cover every real packaged payload, including art, speech and imported derivatives; the deliberate zero-byte recovered-PNG placeholders are verified through their real imported images. The PCK is 1,143,908,448 bytes, SHA-256 `8316d20d066b0537dada7b86fdc74a3417f3ad05f63caa0bb4ee7a138d76e063`. The separate ZIP adds editable armor Blender sources and selected credited source meshes/maps without copying personal saves.
