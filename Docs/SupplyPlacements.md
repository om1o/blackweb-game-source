# House supplies and storage

The source table is [`Godot/data/supply_spawns.json`](../Godot/data/supply_spawns.json). The active house creates three fixed world pickups and two searchable fixtures from that table. The world pickups are guaranteed in every new opening; optional storage entries use independent rolls once per new opening. QA mode uses seed `20261103` for reproducible tests, while normal play gets a new seed on an explicit restart.

| Placement | Item | Chance | Effect |
| --- | --- | ---: | --- |
| Front-room side table near Mara's phone, `(-3.18, 1.07, 1.57)` | Battery cells | 100% | Stores one +35% pack in inventory |
| Counter beside the car keys, `(0.78, 1.46, 3.33)` | Bandage pack | 100% | One bandage; heals 55 when used |
| Middle coffee table, `(3.18, 1.07, 1.19)` | Emergency flare | 100% | One flare; 10 seconds of light when used |
| Entry drawer, `(6.10, 1.15, 2.65)` | Battery cells | 100% | Stores one +30% pack in inventory |
| Entry drawer | Bandage pack | 35% | One bandage |
| Hall cabinet, `(7.35, 1.67, 2.65)` | Bandage pack | 100% | One bandage |
| Hall cabinet | Emergency flare | 40% | One flare |

The player starts with a weak working flashlight at 22% charge, a worn low-damage knife, and one candy bar. The original flashlight plot interaction remains a charged backup flashlight that Mara's warning asks the player to gather. Batteries, bandages and flares are optional and do not alter the phone, keys, encounter or exit requirements. Battery packs enter the 50-cell backpack even when the flashlight is full. Equip a pack to one of three quick slots and use it to apply its exact charge value. The entry drawer carries a short optional Project 08 record about the company experiment; no unrelated book or prop is needed to understand the opening.

The common and mini spiders drop no loot and give no kill reward. The opening is an escape encounter; the authored world supplies and seeded storage contents are the only sources in this pass.

Use `E` to open a drawer or cabinet, `E` again to search, and `E` to close. `I` opens the 50-cell inventory; click an occupied cell, then one of the three quick slots to equip. `1`–`3` use the equipped items, while `F` toggles the flashlight only if equipped. Bandages, flares and battery packs have no separate 4/5 shortcuts. `F1`–`F4` change the selectable status HUD; Minimal is the default. Pickups and fixture visuals are small code-native meshes without additional imported textures or shadow maps.

`Godot/tests/supply_integration_tests.gd` passed against the real house scene in Godot 4.7.2 headless mode. It covers starter items, three world pickups, both searchable fixtures, exact battery-pack restoration after equip/use, one-time loot, seeded rerolls, full-charge pack storage, checkpoint retry preservation, and explicit new-opening reset. `Godot/tests/inventory_50_tests.gd` passed 21/21 checks for the real 50-cell grid and three active slots. `Godot/tools/inspect_opening.gd` passed all 16 current checks and found all nine interaction locations reachable from the actual player spawn without crossing audited geometry. This is route validation, not a frame-rate measurement or a full manual combat playthrough.

Plot milestones are saved to disk by `progression.gd`; optional supplies currently persist through an in-process fatal checkpoint retry but reset after closing and relaunching the app. Persistent supply inventory would require a coordinated save-format change in a later pass.
