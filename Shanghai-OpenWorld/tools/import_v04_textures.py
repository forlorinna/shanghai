"""Enable mipmapped mobile/desktop VRAM compression on the imported V0.4 textures."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1] / "assets"
for directory in ("characters/models", "vehicles/models", "scenery/lujiazui", "textures/lujiazui"):
    for path in (root/directory).glob("*.import"):
        settings = path.read_text()
        if 'importer="texture"' not in settings:
            continue
        options = {
            "compress/mode":"2", "mipmaps/generate":"true", "detect_3d/compress_to":"0",
        }
        if "_nor_gl" in path.name or "normal" in path.name:
            options["compress/normal_map"] = "1"
        for key, value in options.items():
            settings = re.sub(r"^" + re.escape(key) + r"=.*$", f"{key}={value}", settings, flags=re.M)
        if path.read_text() != settings:
            path.write_text(settings)
