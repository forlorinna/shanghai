#!/usr/bin/env python3
"""Extract the selected ambientCG texture maps. Do not unpack executable or scene files."""
import hashlib
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
from PIL import Image, ImageEnhance

root = Path(__file__).resolve().parents[1]
downloads = root / 'tools/downloads/v2'
output = root / 'assets/textures/pbr'
output.mkdir(parents=True, exist_ok=True)
assets = {
    'asphalt': ('Asphalt012', 1024), 'concrete': ('Concrete034', 1024),
    'paving': ('PavingStones036', 1024), 'metal': ('Metal032', 512),
    'wood': ('Wood051', 512), 'grass': ('Grass001', 1024), 'fabric': ('Fabric030', 512),
}
for name, (asset, size) in assets.items():
    path = downloads / (asset + '.zip')
    with ZipFile(path) as bundle:
        def surface(kind, optional=False, default=0):
            members = [f for f in bundle.namelist() if f.endswith(f'_{kind}.jpg')]
            if not members and optional:
                return Image.new('L', (size, size), default)
            if len(members) != 1:
                raise ValueError((asset, kind, members))
            picture = Image.open(BytesIO(bundle.read(members[0])))
            return picture.resize((size, size), Image.Resampling.LANCZOS)
        color = surface('Color').convert('RGB')
        if name == 'fabric':
            color = ImageEnhance.Brightness(color).enhance(2.1)
        color.save(output / f'{name}_albedo.jpg', quality=92, optimize=True)
        surface('NormalGL').convert('RGB').save(output / f'{name}_normal.png', optimize=True)
        extra = surface('Metalness', True, 0) if name == 'metal' else surface('Displacement', True, 128)
        Image.merge('RGB', (surface('Roughness').convert('L'),
                            surface('AmbientOcclusion', True, 255).convert('L'), extra.convert('L'))).save(
                                output / f'{name}_rma.png', optimize=True)
    print(asset, hashlib.sha256(path.read_bytes()).hexdigest())
sky = downloads / 'industrial_sunset_02.exr'
assert hashlib.md5(sky.read_bytes()).hexdigest() == '74e2409a674c1d051e9d75c42b414001'
(output / 'industrial_sunset_02.exr').write_bytes(sky.read_bytes())
