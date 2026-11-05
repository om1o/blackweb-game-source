"""Relocated handoff entry point; execute with Blender, not ordinary Python."""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
source = PROJECT / 'Tools/Assets/leather_boots/fit_armor.py'
if not (HERE / 'luke_boots_reference.blend').is_file():
    raise RuntimeError('The full Handoff/Authoring/Armor payload is required.')
code = source.read_text(encoding='utf-8')
for name, path in [('ROOT', PROJECT), ('WORK', HERE)]:
    code, count = re.subn(rf'(?m)^{name} = Path\([^\n]+\)$',
                          lambda match: f'{name} = Path({str(path)!r})', code)
    if count != 1:
        raise RuntimeError(f'Expected exactly one {name} directory declaration.')
# Only the two directory constants change. Keep the fitted geometry, skinning
# and export implementation from the committed source, with no external cache.
exec(compile(code, str(source), 'exec'), {'__name__': '__main__', '__file__': str(source)})
