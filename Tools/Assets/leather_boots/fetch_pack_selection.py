"""Download selected public MakeHuman ZIP members using validated HTTP ranges.

Usage: python fetch_pack_selection.py URL OUT_DIR [substring ...]
No patterns lists members only. SHA256/CRC provenance is saved for each file.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import sys
import urllib.request
import zlib

url, destination, *patterns = sys.argv[1:]
out = Path(destination)
out.mkdir(parents=True, exist_ok=True)

def fetch(start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "Blackweb-asset-acquisition/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f"Expected HTTP 206, got {response.status}; refusing whole archive transfer")
        expected = f"bytes {start}-{end}/"
        if not response.headers.get("Content-Range", "").startswith(expected):
            raise RuntimeError("Unexpected Content-Range")
        payload = response.read()
        if len(payload) != end - start + 1:
            raise RuntimeError("Truncated range")
        return payload

with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60) as response:
    size = int(response.headers["Content-Length"])
    print("ARCHIVE", size, response.headers.get("Accept-Ranges"), flush=True)
tail = fetch(max(0, size - 65557), size - 1)
end = tail.rfind(b"PK\x05\x06")
if end < 0:
    raise RuntimeError("No ZIP central directory")
eocd = struct.unpack_from("<4s4H2IH", tail, end)
count, cdsize, cdoffset = eocd[4], eocd[5], eocd[6]
central = fetch(cdoffset, cdoffset + cdsize - 1)
entries = []
offset = 0
while offset < len(central):
    row = struct.unpack_from("<4s6H3I5H2I", central, offset)
    assert row[0] == b"PK\x01\x02"
    nlen, xlen, clen = row[10:13]
    name = central[offset+46:offset+46+nlen].decode("utf-8" if row[3] & 2048 else "cp437")
    entry = dict(name=name, compression=row[4], crc32=row[7], compressed_size=row[8], size=row[9], header_offset=row[16])
    entries.append(entry)
    offset += 46 + nlen + xlen + clen
assert len(entries) == count
(out / "archive-index.json").write_text(json.dumps(dict(url=url, archive_bytes=size, entries=entries), indent=2))
selected = [e for e in entries if any(p.lower() in e["name"].lower() for p in patterns)]
if not patterns:
    print(json.dumps(entries, indent=2))
    raise SystemExit(0)
manifest = []
for entry in selected:
    name = entry["name"]
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or ":" in name or "\\" in name:
        raise RuntimeError(f"Unsafe ZIP path: {name}")
    if name.endswith("/"):
        continue
    target = out.joinpath(*path.parts)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        payload = target.read_bytes()
    else:
        start = entry["header_offset"]
        header = fetch(start, start + 29)
        local = struct.unpack("<4s5H3I2H", header)
        assert local[0] == b"PK\x03\x04"
        begin = start + 30 + local[9] + local[10]
        compressed = fetch(begin, begin + entry["compressed_size"] - 1)
        if entry["compression"] == 8:
            payload = zlib.decompress(compressed, -15)
        elif entry["compression"] == 0:
            payload = compressed
        else:
            raise RuntimeError("Unsupported ZIP compression")
        assert len(payload) == entry["size"] and zlib.crc32(payload) == entry["crc32"]
        with target.open("xb") as output:
            output.write(payload)
    assert len(payload) == entry["size"] and zlib.crc32(payload) == entry["crc32"]
    record = dict(entry, sha256=hashlib.sha256(payload).hexdigest())
    manifest.append(record)
    print("VERIFIED", name, len(payload), flush=True)
(out / "selection-provenance.json").write_text(json.dumps(dict(url=url, archive_bytes=size, files=manifest), indent=2))
print("COMPLETE", len(manifest), sum(e["size"] for e in manifest), flush=True)
