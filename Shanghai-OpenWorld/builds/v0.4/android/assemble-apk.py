"""Rebuild the signed Android APK from the four GitHub downloads."""
import hashlib
import os
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parent
expected, filename = (root / "SHA256SUMS").read_text().split()
parts = [root / f"{filename}.part{number:02d}" for number in range(1, 5)]
missing = [path.name for path in parts if not path.is_file()]
if missing:
    raise SystemExit("Missing files: " + ", ".join(missing))
digest = hashlib.sha256()
temporary_path = None
try:
    with tempfile.NamedTemporaryFile(dir=root, prefix="assembled-", delete=False) as target:
        temporary_path = Path(target.name)
        for part in parts:
            with part.open("rb") as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
                    target.write(block)
    if digest.hexdigest() != expected:
        raise SystemExit("APK SHA256 does not match SHA256SUMS.")
    os.replace(temporary_path, root / filename)
finally:
    if temporary_path is not None:
        temporary_path.unlink(missing_ok=True)
print(f"Verified SHA256. APK: {root / filename}")
