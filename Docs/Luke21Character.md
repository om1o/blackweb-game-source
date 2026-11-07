Luke is a fictional 21-year-old man with mixed Black and white heritage, as specified by the creator. This is his authored identity; it is not a demographic claim about the people represented by source artwork.

The new Meshy reference establishes short dark textured curls, brown eyes, warm brown skin and practical olive/charcoal clothing. The runtime character is a licensed mesh adaptation, not an export of that generated portrait or a photographic scan. The body, hand coordinates, rest skeleton and skinning remain compatible with the existing equipment and armour system. The face uses a different Rocketbox source head with modest cheek, jaw, chin and brow shaping.

The character pipeline is reproducible with `Tools/Assets/prepare_luke21.py`, followed by `Godot/tools/build_luke.gd --replacement`. Source FBX files and full-size textures remain in external acquisition storage. The game carries the compact GLB, Godot scene and licence/provenance records.

Hair uses the [MakeHuman system assets](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html) `afro01` mesh and texture under CC0. It is fitted to the new head and shortened to a compact crop. The body, face and hair total 8,746 triangles, with 2,192 of those for hair. The four surfaces use 1K textures. Material separation keeps clothing colour changes off the hands, and the hair uses alpha scissor without specular highlights to avoid bright solid card strips.

The final facial albedo is an imagegen edit of the licensed head texture, guided by the Meshy reference. It removes heavy stubble and baked folds, softens the mouth and brow, adds subtle freckles, and gives the eyes a warm brown iris with natural ivory sclera. This is used on the actual mesh. The full prompt is retained in `Docs/Luke21ImagePrompt.txt`, and the full-resolution generation is `Tools/Assets/References/luke21_head_albedo.png`. The compact runtime texture is included in the project and GLB.

The asset review included:

- [Microsoft Rocketbox](https://github.com/microsoft/Microsoft-Rocketbox): MIT rigged source meshes, chosen for the established rig and portable licence.
- [Quaternius Universal Animation Library on itch.io](https://quaternius.itch.io/universal-animation-library): the existing CC0 authored locomotion/combat clips remain compatible.
- [Diesel character on itch.io](https://theunseenvulga.itch.io/3d-charater-riggeddiesel): a free CC0 hand-painted rigged character, reviewed as an alternate but not included.
- [Realistic Male Character on Fab](https://www.fab.com/listings/b7f30b50-005c-4760-b0b8-802337607006): a free rigged FBX listing, reviewed but not downloaded or included; its visible page did not expose a licence text.

PINOC's character search returned no existing matching character. PINOC character generation produces Gaussian splats, which are unsuitable for this ordinary skeletal-mesh Godot pipeline without another renderer. Meshy's account had no downloadable character model; its new image serves as a design reference. These limitations were not bypassed.
