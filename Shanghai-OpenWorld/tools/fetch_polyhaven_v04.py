"""Download and verify the source files advertised by Poly Haven (CC0)."""
import hashlib
import json
from pathlib import Path
from subprocess import check_output

root = Path(__file__).resolve().parents[1]
cache = root / "scratch/v04-input/polyhaven"
surface = root / "assets/textures/lujiazui"
surface.mkdir(parents=True, exist_ok=True)

def fetch(entry, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    data = curl(entry["url"])
    assert len(data) == entry["size"] and hashlib.md5(data).hexdigest() == entry["md5"], entry["url"]
    target.write_bytes(data)
    print(target.name, hashlib.sha256(data).hexdigest(), flush=True)

def curl(url):
    return check_output(["curl", "-fsSL", "--retry", "2", "--max-time", "120", url])

def spec(name):
    return json.loads(curl(f"https://api.polyhaven.com/files/{name}"))

for name in ("asphalt_02", "precast_stone_paving"):
    files = spec(name)
    for kind in ("Diffuse", "nor_gl", "arm"):
        entry = files[kind]["1k"]["jpg"]
        fetch(entry, surface / Path(entry["url"]).name)

for name in ("street_lamp_01", "painted_wooden_bench", "planter_box_01", "tree_small_02"):
    entry = spec(name)["gltf"]["1k"]["gltf"]
    fetch(entry, cache / name / f"{name}.gltf")
    for path, dependency in entry["include"].items():
        fetch(dependency, cache / name / path)
