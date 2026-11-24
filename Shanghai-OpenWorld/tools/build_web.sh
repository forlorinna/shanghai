#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p builds/v0.4/web
tools/godot.sh --headless --editor --import
tools/godot.sh --headless --export-release Web "$root/builds/v0.4/web/index.html"
python3 tools/finalize_web.py builds/v0.4/web
(cd builds/v0.4/web && zip -q -9 "$root/builds/v0.4/Shanghai-OpenWorld-v0.4.0-web.zip" index.*)
unzip -tq "$root/builds/v0.4/Shanghai-OpenWorld-v0.4.0-web.zip"
