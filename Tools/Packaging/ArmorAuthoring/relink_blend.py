"""Create an extraction-relative copy of the supplied fitting scene in Blender."""
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
stem = 'luke_boots_reference' if '--reference' in sys.argv else 'luke_fitted_armor'
source = HERE / (stem + '.blend')
output = HERE / (stem + '_relinked.blend')
if output.exists():
    raise RuntimeError(f'Preserving existing relinked work: {output}')
bpy.ops.wm.open_mainfile(filepath=str(source))
image_paths = list(HERE.glob('*-selected/clothes/*/*.png'))
image_paths += list((PROJECT / 'Godot/assets/luke/Textures').glob('*.tga'))
lookup = {path.name.casefold(): path for path in image_paths}
missing = []
for image in bpy.data.images:
    if image.source != 'FILE' or image.packed_file:
        continue
    original_name = Path(bpy.path.abspath(image.filepath)).name.casefold()
    target = lookup.get(original_name)
    if target is None:
        missing.append(image.filepath)
        continue
    image.filepath = bpy.path.relpath(str(target))
    image.reload()
if missing:
    raise RuntimeError('Missing image inputs; no copy saved: ' + repr(missing))
bpy.ops.wm.save_as_mainfile(filepath=str(output), relative_remap=True)
print('Relinked authoring scene:', output)
