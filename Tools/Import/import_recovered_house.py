"""Import the actual recovered USD scene into a new, isolated reference level.

Run through Tools/Build.ps1 -Action Import after a successful recovery export.
This preserves source placements; it does not invent layout or silently overwrite
an artist-edited level. Gameplay placement is a separate, reviewed step.
"""
import json
from pathlib import Path
import unreal

ROOT = Path(__file__).resolve().parents[2]
RECOVERED = ROOT / "RecoveredAssets"
LEVEL_PATH = "/Game/Recovery/HouseReference"
CONTENT_PATH = "/Game/Recovered"
REPORT_PATH = ROOT / "Evidence" / "unreal-house-import.json"


def main():
    candidates = sorted(
        path for path in RECOVERED.rglob("Map_House.*")
        if path.suffix.lower() in (".usd", ".usda", ".usdc")
    )
    if len(candidates) != 1:
        raise RuntimeError(
            "Expected exactly one successfully exported Map_House USD scene; "
            f"found {len(candidates)}. Complete recovery before importing."
        )
    if unreal.EditorAssetLibrary.does_asset_exist(LEVEL_PATH):
        raise RuntimeError(
            "HouseReference already exists. It may contain reviewed edits. "
            "Use a new level name for another import; this script does not overwrite it."
        )
    required = ("UsdStageImportFactory", "UsdStageImportOptions")
    if any(not hasattr(unreal, name) for name in required):
        raise RuntimeError("Enable the project's USDImporter plugin and restart the editor.")

    level_editor = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    actor_editor = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    if not level_editor.new_level(LEVEL_PATH):
        raise RuntimeError("Could not create the isolated recovery level.")

    options = unreal.UsdStageImportOptions()
    for key, value in {
        "import_actors": True,
        "import_geometry": True,
        "import_materials": True,
        "import_skeletal_animations": True,
        "import_level_sequences": False,
        "import_groom_assets": False,
        "interpret_lo_ds": True,
        "override_stage_options": False,
        "kinds_to_collapse": 0,
        "prim_path_folder_structure": True,
        "nanite_triangle_threshold": 2147483647,
    }.items():
        options.set_editor_property(key, value)
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", str(candidates[0]))
    task.set_editor_property("destination_path", CONTENT_PATH)
    task.set_editor_property("factory", unreal.UsdStageImportFactory())
    task.set_editor_property("options", options)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", False)
    task.set_editor_property("save", True)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])

    actors = actor_editor.get_all_level_actors()
    placements = []
    meshes = {}
    for actor in actors:
        location = actor.get_actor_location()
        rotation = actor.get_actor_rotation()
        scale = actor.get_actor_scale3d()
        components = actor.get_components_by_class(unreal.StaticMeshComponent)
        references = []
        for component in components:
            mesh = component.get_editor_property("static_mesh")
            if mesh:
                references.append(mesh.get_path_name())
                meshes[mesh.get_path_name()] = mesh
        placements.append({
            "label": actor.get_actor_label(),
            "class": actor.get_class().get_name(),
            "location_cm": [location.x, location.y, location.z],
            "rotation_degrees": [rotation.pitch, rotation.yaw, rotation.roll],
            "scale": [scale.x, scale.y, scale.z],
            "static_meshes": references,
        })
    if not meshes:
        raise RuntimeError("USD import produced no placed static meshes; inspect the recovery report.")

    # This stage preserves recovered appearance and transforms only. Do not
    # report walkable collision/navmesh before the dedicated editor review.
    unreal.EditorAssetLibrary.save_directory(CONTENT_PATH, only_if_is_dirty=True, recursive=True)
    if not level_editor.save_current_level():
        raise RuntimeError("Imported reference level could not be saved.")
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps({
        "source_scene": str(candidates[0]),
        "level": LEVEL_PATH,
        "unique_static_meshes": len(meshes),
        "placements": placements,
        "collision_validated": False,
        "navigation_validated": False,
        "gameplay_wired": False,
        "render_review_completed": False,
    }, indent=2), encoding="utf-8")
    unreal.log("Recovered house reference imported. Collision, navigation, lighting and gameplay review remain.")


if __name__ == "__main__":
    main()
