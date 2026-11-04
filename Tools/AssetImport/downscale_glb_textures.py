"""Downscale embedded glTF textures without touching a mesh, rig, or animation.

Usage: python downscale_glb_textures.py source.glb output.glb 1024
The source and output files remain subject to the source asset's own licence.
"""

import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image


def align4(data: bytes, pad: bytes = b"\0") -> bytes:
    return data + pad * ((-len(data)) % 4)


def optimize(source: Path, target: Path, max_side: int) -> None:
    blob = source.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", blob)
    if magic != b"glTF" or version != 2 or total != len(blob):
        raise ValueError("Expected one valid glTF 2.0 binary file")
    json_size, json_type = struct.unpack_from("<I4s", blob, 12)
    if json_type != b"JSON":
        raise ValueError("Missing glTF JSON chunk")
    document = json.loads(blob[20 : 20 + json_size])
    binary_header = 20 + json_size
    binary_size, binary_type = struct.unpack_from("<I4s", blob, binary_header)
    if binary_type != b"BIN\0" or binary_header + 8 + binary_size != len(blob):
        raise ValueError("Expected one binary chunk")
    binary = blob[binary_header + 8 :]
    image_views = {image["bufferView"]: image for image in document.get("images", [])}
    rewritten = bytearray()
    for index, view in enumerate(document["bufferViews"]):
        offset = view.get("byteOffset", 0)
        payload = binary[offset : offset + view["byteLength"]]
        if index in image_views:
            image = image_views[index]
            with Image.open(io.BytesIO(payload)) as bitmap:
                bitmap.load()
                before = bitmap.size
                bitmap.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
                output = io.BytesIO()
                if image["mimeType"] == "image/jpeg":
                    bitmap.save(output, format="JPEG", quality=90, optimize=True)
                elif image["mimeType"] == "image/png":
                    bitmap.save(output, format="PNG", optimize=True)
                else:
                    raise ValueError("Unsupported embedded texture: " + image["mimeType"])
                payload = output.getvalue()
                print(f"{image.get('name', index)}: {before} -> {bitmap.size}, {view['byteLength']} -> {len(payload)} bytes")
        rewritten.extend(b"\0" * ((-len(rewritten)) % 4))
        view["byteOffset"] = len(rewritten)
        view["byteLength"] = len(payload)
        rewritten.extend(payload)
    binary_out = align4(bytes(rewritten))
    document["buffers"][0]["byteLength"] = len(binary_out)
    json_out = align4(json.dumps(document, separators=(",", ":")).encode("utf-8"), b" ")
    result = (
        struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(json_out) + 8 + len(binary_out))
        + struct.pack("<I4s", len(json_out), b"JSON")
        + json_out
        + struct.pack("<I4s", len(binary_out), b"BIN\0")
        + binary_out
    )
    target.write_bytes(result)
    print(f"{source.stat().st_size} -> {target.stat().st_size} bytes")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    optimize(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]))
