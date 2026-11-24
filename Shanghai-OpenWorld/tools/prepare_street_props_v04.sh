#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="${GLTF_TRANSFORM:-gltf-transform}"
source_dir="${1:-scratch/v04-input/polyhaven}"
output=assets/scenery/lujiazui
mkdir -p "$output"
"$cli" simplify "$source_dir/tree_small_02/tree_small_02.gltf" "$output/tree.glb" --ratio .004 --error .065 --lock-border false
"$cli" simplify "$source_dir/street_lamp_01/street_lamp_01.gltf" "$output/lamp.glb" --ratio .095 --error .01
"$cli" copy "$source_dir/painted_wooden_bench/painted_wooden_bench.gltf" "$output/bench.glb"
"$cli" simplify "$source_dir/planter_box_01/planter_box_01.gltf" "$output/planter.glb" --ratio .26 --error .02
