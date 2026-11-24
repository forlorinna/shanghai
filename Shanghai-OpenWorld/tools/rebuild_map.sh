#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export PYTHONPATH="$root/tools/local${PYTHONPATH:+:$PYTHONPATH}"
python3 tools/generate_map.py "$@"
# The Godot dummy renderer drops MultiMesh instance buffers on save.
# Run the baker with a real GL backend, on the current display or on Xvfb.
if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  tools/godot.sh --rendering-method gl_compatibility --audio-driver Dummy --script tools/bake_map.gd
elif command -v xvfb-run >/dev/null; then
  xvfb-run -a tools/godot.sh --rendering-method gl_compatibility --audio-driver Dummy --script tools/bake_map.gd
else
  printf 'Map baking requires a display or xvfb-run to persist MultiMesh instance transforms.\n' >&2
  exit 1
fi
