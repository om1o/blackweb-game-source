# Fitted armor garments

These are real artist-authored meshes adapted for Blackweb, not generated primitive armor. Their original designs were not a matched armor set.

| Runtime piece | Original asset | Artist | License | Official source |
| --- | --- | --- | --- | --- |
| Boots | Shoes Biker Boots Male | Mindfront (Sweden) | CC BY 4.0 | https://static.makehumancommunity.org/assets/assetpacks/shoes03.html |
| Pants | Male Trousers 1 | Mindfront (Sweden) | CC BY 4.0 | https://static.makehumancommunity.org/assets/assetpacks/pants02.html |
| Shirt | Hooded Sweat Jacket 1 / ladieshoodiedown1 | Elvaerwyn | CC BY 4.0 | https://static.makehumancommunity.org/assets/assetpacks/shirts02.html |
| Hood | Monk's Robe Hood | Donitz | CC0 1.0 | https://static.makehumancommunity.org/assets/assetpacks/suits02.html |

CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ and https://creativecommons.org/licenses/by/4.0/legalcode

CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/

MakeHuman's license guide identifies CC-BY assets as Attribution 4.0: https://static.makehumancommunity.org/oldsite/faq/what_do_i_need_to_do_when_i_use_a_ccby_asset.html

Changes: fitted and reweighted to the existing Microsoft Rocketbox Luke rig; corrected the jacket's lowered arms and torso proportions; retained artist UVs, seams and original normal detail; converted larger maps to 2048 for runtime export; changed the clothing material to worn brown leather using Rob Tuytel's CC0 Poly Haven `brown_leather` maps. The jacket, trousers and hood were not originally sold or described as leather armor. No endorsement by the original artists is implied.

Leather source and license: https://polyhaven.com/a/brown_leather and https://polyhaven.com/license. The material's original metadata is in `../poly_haven/brown_leather/source.json`.

The existing Luke rest rig and transferred skin weights derive from Microsoft Rocketbox Male_Adult_04 under MIT; the project's Luke license remains at `../../luke/LICENSE.md` (see `Docs/LukeAsset.md`). This GLB includes garments and their bind rig only, not a second copy of Luke's body geometry or animations.

`source-manifest.json` records exact archive URLs, per-member CRC32, byte sizes and SHA256 values. Downloads and the editable Blender fitting source remain at `D:/CodexTemp/Blackweb-RealArmor-20261105`, outside the project's size budget. `Tools/Assets/leather_boots/fetch_pack_selection.py` and `fit_armor.py` reproduce acquisition and conversion.

Required shipped credit: “Armor garment meshes: Mindfront and Elvaerwyn (CC BY 4.0), Donitz (CC0); fitted and materially adapted for Blackweb. Brown leather PBR: Rob Tuytel / Poly Haven (CC0).” Include the license and source links above in the game's credits or bundled attribution documentation.
