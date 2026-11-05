# Editable armor source

This folder contains the final fitted Blender scene, Luke's reference scene and the selected OBJ/color/normal inputs used by the fitting pipeline. The input list is explicit: no whole asset packs, unused model candidates, source thumbnails, unused specular maps or Blender backup/cache files are included. The supplied `.blend` files were created with Blender 4.5.15 LTS. Blender itself is not included and is not needed to play the game.

The `.blend` files retain their original image paths as provenance. To make an extraction-relative copy, run this command from the extracted `Blackweb` folder, substituting your Blender executable:

```powershell
& 'C:\path\to\blender.exe' --background --python '.\Handoff\Authoring\Armor\relink_blend.py'
```

Open the resulting `luke_fitted_armor_relinked.blend` in Blender. The helper links the eight supplied garment maps and the already-included Rocketbox textures, saves a new copy, and preserves the delivered original. It refuses to overwrite an existing relinked file. Add `-- --reference` to prepare the separate Luke reference scene. Moving the entire extracted folder afterward keeps these relative paths valid.

To repeat the fitting/export pipeline from the supplied inputs:

```powershell
& 'C:\path\to\blender.exe' --background --python '.\Handoff\Authoring\Armor\rebuild_armor.py' -- --no-render
```

The wrapper executes the committed `Tools/Assets/leather_boots/fit_armor.py` with only its two directory constants relocated. It requires no `D:` scratch tree, downloaded asset archive or model cache. It writes the fitted `.blend` in this folder, temporary converted textures under `runtime_textures`, and the GLB/report under `Godot/assets/third_party/makehuman_armor`. Preserve any personal edits before rebuilding. Import the changed GLB in Godot and rerun the armor fixtures before building a new PCK; this operation does not update `Playable/Blackweb.pck`.

The `.blend` scenes contain artist garments, Luke's reference geometry/rig and image materials. The runtime leather shader and its three Poly Haven maps live in the adjacent Godot project; Blender's preview material is not an exact rendering of that Godot shader. The original jacket, pants and hood were not advertised as leather armor. Fitting, skinning and the material adaptation are documented in `Docs/ArmorIntegrationPlan.md`.

Credits and terms are copied into `Licenses/`: Mindfront's biker boots and trousers and Elvaerwyn's jacket use CC BY 4.0; Donitz's hood and Rob Tuytel/Poly Haven's leather use CC0; Luke's Microsoft Rocketbox reference and transferred rig data use MIT. The source `.mhclo` headers and runtime source manifest preserve the individual artist records. Changes are not endorsed by those artists. The private recovered-house content elsewhere in this handoff retains its separate redistribution restriction.

The handoff's SHA-256 manifest covers these files, including the two `.blend` scenes. Packaging does not launch Blender or claim that regeneration has been rerun after relocation. Other optional generation tools may still depend on their documented external services or caches; this folder makes the armor workflow self-contained apart from Blender/Godot.
