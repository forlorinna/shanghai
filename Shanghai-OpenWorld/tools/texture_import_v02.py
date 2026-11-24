#!/usr/bin/env python3
"""Set GPU import options shared by Mobile (ETC2/ASTC) and desktop (S3TC/BPTC)."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
for meta in (root / 'assets/textures/pbr').glob('*.import'):
    if '.exr.' in meta.name:
        continue
    text = meta.read_text()
    for key, value in [('compress/mode', '2'), ('mipmaps/generate', 'true'),
                       ('detect_3d/compress_to','0'), ('compress/normal_map','1' if '_normal.' in meta.name else '2')]:
        text = re.sub(r'^' + re.escape(key) + r'=.*$', f'{key}={value}', text, flags=re.M)
    meta.write_text(text)
