"""Convert KTX2 images in a dequantized CC0 bus GLB to Godot-compatible PNG."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

source, destination, ktx = map(Path, sys.argv[1:])
data = source.read_bytes()
magic, version, size, json_size, json_kind = struct.unpack_from("<4sIIII", data)
assert (magic, version, size, json_kind) == (b"glTF", 2, len(data), 0x4E4F534A)
doc = json.loads(data[20:20+json_size])
bin_size, bin_kind = struct.unpack_from("<II", data, 20+json_size)
assert bin_kind == 0x004E4942 and len(doc["buffers"]) == 1
buffer = bytearray(data[28+json_size:28+json_size+bin_size])
with tempfile.TemporaryDirectory() as tmp:
    for image in doc["images"]:
        if image["mimeType"] != "image/ktx2":
            continue
        old = doc["bufferViews"][image["bufferView"]]
        start = old.get("byteOffset", 0)
        src, dst = Path(tmp, "image.ktx2"), Path(tmp, "image.png")
        src.write_bytes(buffer[start:start+old["byteLength"]])
        subprocess.run([str(ktx), "extract", "--transcode", "rgba8", str(src), str(dst)], check=True)
        png = dst.read_bytes()
        assert png.startswith(b"\x89PNG\r\n\x1a\n")
        image.update(bufferView=len(doc["bufferViews"]), mimeType="image/png")
        buffer.extend(b"\0"*((-len(buffer)) % 4))
        doc["bufferViews"].append({"buffer":0, "byteOffset":len(buffer), "byteLength":len(png)})
        buffer.extend(png)
for texture in doc["textures"]:
    extensions = texture.get("extensions", {})
    data = extensions.pop("KHR_texture_basisu", None)
    if data:
        texture["source"] = data["source"]
    if not extensions:
        texture.pop("extensions", None)
for key in ("extensionsUsed","extensionsRequired"):
    values = doc.get(key, [])
    if "KHR_texture_basisu" in values:
        values.remove("KHR_texture_basisu")
    if not values:
        doc.pop(key, None)
doc["buffers"][0]["byteLength"] = len(buffer)
buffer.extend(b"\0"*((-len(buffer)) % 4))
metadata = json.dumps(doc,separators=(",", ":")).encode()
metadata += b" "*((-len(metadata)) % 4)
destination.write_bytes(struct.pack("<4sIIII",b"glTF",2,28+len(metadata)+len(buffer),len(metadata),0x4E4F534A)
                        + metadata + struct.pack("<II",len(buffer),0x004E4942)+buffer)
