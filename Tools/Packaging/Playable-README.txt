ARACHNOPHOBIA: BLACKWEB — PLAYABLE HOUSE REBUILD

Double-click "Launch Blackweb.cmd" on Windows x86_64. Keep this folder together.
On a slower PC, double-click "Launch Blackweb Fast.cmd" for a 960x540
window. A paired Intel HD 530 entrance spot check improved median frame
time at that size, but did not prove stable 30 FPS; visual sharpness drops.
No Unreal Engine, Godot installation, export templates, source asset junction,
network connection, or account is needed to run this package. A compatible
graphics driver is required; Godot selects its OpenGL/ANGLE backend.
Godot 4.7.2 is bundled unchanged.

The default keeps room lights illuminated without their two expensive shadow
maps; the flashlight still casts shadows. To opt into the original room-shadow
setting, run "Launch Blackweb.cmd" --room-shadows from a command prompt.
This costs performance. Native 1280x720 and 2x MSAA are retained.

Controls: WASD move; mouse look; Shift sprint; C crouch; Space jump;
E interact; 1-3 use the three equipped items; F toggles the flashlight
while equipped; I opens the 50-cell inventory; F1-F4 choose one of four
status HUD layouts; Escape pauses or closes inventory. Sprinting and
jumping use stamina. The Minimal HUD is selected by default. The three
starter quick items are weak flashlight, worn knife and one candy bar.
In the inventory, click an occupied backpack cell, then a quick-slot
button to equip it. Only those three items can be used during play.

Battery packs, bandages and flares can be found on house surfaces and by
opening and searching the entry drawer and hall cabinet with E. Search
each opened fixture once. Battery packs go into inventory and must be
equipped and used to restore their listed +35% or +30% charge, including
when found at full charge. Optional supplies do not gate the phone, keys,
backup flashlight, encounter or exit. The drawer also contains an
optional Project 08 record.
Follow Mara's message, gather keys and the charged backup flashlight,
survive the encounter, then leave through the opening door.

The launcher stores saves and logs in this folder's UserData directory.
It changes environment variables only for its own child process. Source-project
saves are separate. Copy UserData too if transferring your progress. Use a
writable folder. A new game replaces this portable copy's current checkpoint.

This package plays the tutorial opening of the Blackweb game, which is still
in development. Materials approximate the original shaders. Pickups lack
authored hand animation. Some spider motions are procedural; authored creature
clips are still needed. Plot milestones are saved, but optional supply counts
and picked-up state currently reset after closing the app.
Read the project Docs/Phase0Report.md, Docs/HouseDressing.md and
Docs/SupplyPlacements.md for the measured baseline and remaining work.

Blackweb.pck contains scripts, scenes, recovered GLBs/JSON, imported textures
and import mappings. Original PNG payloads stay in the source project, while
the portable package uses their imported images. package-build-info.json
records source hashes; build-report.json records artifact hashes and the
packaging test state.
licenses contains Godot, Luke/MIT, and asset provenance notices. The user's
permission to reuse their supplied assets is not a blanket redistribution grant.

Rebuild from the source repository using Tools/Packaging/BuildPortable.ps1.
This package uses the official editor executable as a runtime with --main-pack;
it is not a separately compiled release-template executable.
