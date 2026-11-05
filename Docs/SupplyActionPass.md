# Supply models and timed use

The tutorial now uses original Blender meshes for a battery cell, sealed gauze packet, loose gauze roll and emergency flare. The same assets appear in the world and in Luke's hands. The complete kit has 7,344 triangles and a 236,652-byte GLB. Editable Blender source, exact dimensions, provenance and the 28-check import report are in [the supply contract](../Tools/Assets/supply_contract.md).

Supplies occupy the existing 50-cell inventory and must be equipped in one of three quick slots. Number keys draw an item; left click uses it. The initial flashlight, worn knife and candy loadout is unchanged.

| Action | Effect time | Recovery ends | Result |
| --- | ---: | ---: | --- |
| Battery replacement | 1.05 s | 1.65 s | Uses one pack and adds its exact charge, capped at 100% |
| Bandage | 2.25 s | 2.80 s | Uses one pack and heals 55, capped at 100 health |
| Flare ignition | 0.50 s | 0.95 s | Uses one stick and starts ten seconds of light |
| Candy bite | 0.78 s | 1.16 s | Uses one bar and heals 30 |
| Worn knife slash | 0.24 s | 0.68 s | 4 damage to one nearby unobstructed target; 0.75 s cooldown |

Luke supports the torch in his left hand while his right brings a cell toward its tail. Bandaging raises the opposite forearm and replaces the sealed packet with a gauze roll. An unlit flare is held before ignition; the burning flare moves to the left hand, allowing a right-hand item. Starting a two-handed supply action puts an already burning flare on the floor for its remaining lifetime. The light does not duplicate or gain extra fuel. A collision ray places the flare on the supporting floor even when a supply action begins mid-jump; an actual-house regression verifies the landing.

Inventory effects occur once at the contact event. Repeated clicks and changing quick-slot equipment cannot bypass an active action. Interrupted actions before contact preserve the unconsumed item. Full health or a full battery rejects unnecessary use. Battery replacement, bandaging and ignition reduce walking speed and prevent sprint/jump until recovery ends.

## Original label atlas

`Godot/assets/generated/supply_labels_worn_v1.png` was created with the built-in Imagegen tool, visually inspected, copied into the project and applied to named label materials in the shared supply factory. It has four opaque quadrants: battery, gauze, flare and unused wear detail. The factory crops UVs to the first three quadrants. No external brand assets or recovered assets were uploaded. The bottom-right quadrant is not a separate runtime material.

Prompt: "Create one production game texture atlas, square 2048x2048 if supported, for original Blackweb survival-horror supplies. A FLAT orthographic UV albedo texture, not a photograph of objects. Exactly FOUR equal square quadrants, aligned at x=50%, y=50%, no gutters, no labels outside those quadrants, every quadrant fills its square edge-to-edge. TOP LEFT: worn charcoal and muted brass disposable battery sleeve, small believable generic text 'CELL 1.5V', tiny plus symbol, creased printed foil, scuffs, fine scratches and rubbed ink. TOP RIGHT: aged off-white emergency gauze packet artwork, generic text 'STERILE GAUZE' and tiny 'FIELD DRESSING', subdued olive-gray stripe, fine paper fibers, realistic creasing and light water staining. BOTTOM LEFT: scuffed red-orange emergency flare paper wrap, generic text 'SIGNAL FLARE' and understated tiny 'KEEP DRY', tiny black instructions, abraded edges and soot smudges. BOTTOM RIGHT: weathered dark graphite rubber and metal surface, dense fine scratches and subtle corrosion, no text. The atlas should look materially convincing at close range, neutral diffuse/albedo illumination without cast shadows, no perspective, no bevel illusion, no scene, no objects, no currency, no logos, no graphic borders. All four square regions are opaque. Restrained realistic wear, not cartoon, illustration, concept art or showroom rendering."

The delivered image is 1254 × 1254, rather than the requested optional 2048 size. No upscaling or duplicate padding was used.

## Rendered review and remaining work

Native captures in `Evidence/` show ready, replacement/wrapping, and burning states, with separate `-gameplay.png` and `-inspection.png` files. Inspection views use a close camera and extra fill light; gameplay views use the real shoulder camera and room lighting. Initial inspection found the central action hidden behind Luke and an open left hand; the working position and finger curl were corrected before the final captures.

These actions use procedural skeletal IK on the recovered rig, not purchased motion capture. The battery cap is not separately unscrewed, gauze does not simulate an unwinding cloth strip, and fingers still need a dedicated authored contact pass. Small props remain subtle at the normal camera distance. The kit improves shape and material detail but does not establish AAA realism or a 100-fold performance gain. The requested 90 MB minimum of dedicated blood/web/goo assets is still unmet.

Final affected headless checks passed: inventory 23/23, supply integration 41/41, equipment 53/53, and supply actions 24/24. All four final verbose logs exited cleanly with no warnings or leaks. The model factory independently passed 28/28 checks.
