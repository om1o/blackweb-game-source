# Original Blender candy prop

This prop was authored for Blackweb with Python geometry in Higgsfield 3D Jutsu's hosted Blender 5.2 on 2026-11-04 (local date). No third-party model, recovered artwork upload, paid generation, license acceptance, or external texture download was used.

Hosted project: https://higgsfield.ai/3d-jutsu/4d93c1bc-bfbb-468d-b0d4-68aa3cbb4ebd
Committed asset revision: 2. The recipe describes scene geometry scaffolding as no-cost and inspection queries as free. Observed balance was 1.7 credits before work and after both completed renders, editing, export and final scene display: zero observed credit spend. This is distinct from Tripo AI mesh generation, whose separate quote was 5 credits and was not submitted.

## Files and construction

- `Godot/assets/generated/candy_blender/candy_variants.glb`: 458,212 bytes, SHA-256 `A00AC0C6A81C02C03EDEF0C30A3D353DCD2C02A05AA113D264AA30A65845879D`.
- `Tools/Assets/candy_blender_source.blend`: 1,058,164 bytes, SHA-256 `44B661769AEEC5E40A7190AEF3314640412626DA81B01FF17F43CDF159A41A6A`.
- `Tools/Assets/candy_blender_blockout.py` and `candy_blender_detail.py` retain the original authored scene steps. Run the blockout in an empty scene, then the detail script. The hosted operations used were `candy-blockout-02` and `candy-detail-01`.
- `Tools/Assets/candy_blender_variants-godot.png` is the inspected native Godot render of the actual export.
- `Tools/Assets/candy_blender_validate.gd` and `candy_blender_validation.json` record structural import validation.

The bar has a beveled chocolate base and moulded squares, a thin crumpled inner foil sleeve, a torn outer paper sleeve, an uneven crimped tail and folded foil tabs. The bitten version removes two adjoining scallops from the edible end. Each version is consolidated into three material meshes.

## Runtime integration contract

The GLB contains two named roots, `CandyReady` and `CandyBitten`, plus a studio camera and lights for inspection. Extract the roots and free the rest of the imported scene. Reset both root transforms to identity when attaching them to the game's existing `CandyBarBody`: the exported display offsets are Godot Z +0.05 and -0.05 m.

Godot coordinates: X is the bar length, Y is thickness, Z is width. The edible end is +X; the wrapper/gripping end is -X. Ready bounds are 0.151 × 0.028641 × 0.066655 m, beginning at (-0.0825, -0.005121, -0.033559). The bitten version is 0.149939 m long. Runtime attachment needs no scale multiplier.

Material slots are `Candy_Chocolate`, `Candy_InnerFoil` and `Candy_WornWrapper`. Assign the existing aged wrapper image only to a duplicated `Candy_WornWrapper` material, with near-white albedo modulation to avoid multiplying the image by the plain brown studio swatch. UVs survive export. Keep the ready root visible before the bite and swap to the bitten root at the actual bite/chew moment. These files do not themselves change the player, heal timing, hand pose or consume state.

Ready has 4,016 triangles; bitten has 3,940. Only one variant should render at a time. The 13/13 headless checks cover actual GLB load, root existence, finite vertex/normal data, UVs, dimensions, three material meshes per variant and a 5,000-triangle ceiling. A native Godot render visually confirms the opened packaging, beveled squares and distinct bitten silhouette. These checks do not establish realistic hand contact or a final AAA-quality prop.

The hosted renderer produced a PNG, but this client's browser surfaces were unavailable and the signed image was not viewable through the web tool. Visual review instead used the downloaded, authorized GLB in the actual Godot renderer. The model has deliberately simple export-safe material values; its final worn wrapper appearance and game lighting require in-game integration.

## Integrated gameplay verification

The player now extracts both variants, removes their studio transforms/ownership, applies the existing original aged-wrapper image and keeps only one variant visible. The edible face is rolled outward for readability. The action raises over 0.32 s, holds at the mouth through 0.82 s, and recovers by 1.16 s. At 0.78 s it heals 30 HP, consumes one bar and shows the bitten silhouette. The wrapper hand stays beside the face; a geometric check places the exposed chocolate end within 4 cm of the mouth during the hold.

Combined equipment tests pass 51/51, including ready/bitten state and contact timing. Native captures `Evidence/candy-ready-qa.png`, `candy-eating-qa.png`, `candy-bitten-qa.png` and corresponding gameplay-distance frames were inspected. The prop is visibly improved, though its simple chocolate shading and the recovered hand/finger rig remain prototype limitations.
