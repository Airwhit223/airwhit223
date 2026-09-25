#!/usr/bin/env bash
# Renders a preview PNG of some assets with the same toon look as the game.
#
#   tools/preview/render.sh out.png "monsters/goblin.glb:0:0" [CAM=0,1.2,3 LOOK=0,0.6,0 FOV=40 BG=room]
#
# Item format: path.glb:x:z[:y[:yaw[:animation[:time 0..1]]]], several joined with ';'.
# Paths are relative to the repo root. Needs Godot 4.7 (set GODOT) and a display;
# on a headless machine it uses xvfb-run automatically.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$(realpath -m "$1")"; ITEMS="$2"; shift 2
for kv in "$@"; do export "$kv"; done
GODOT="${GODOT:-godot}"
mkdir -p "$HERE/assets"
IFS=';' read -ra list <<< "$ITEMS"
for it in "${list[@]}"; do
  rel="${it%%:*}"
  mkdir -p "$HERE/assets/$(dirname "$rel")"
  cp "$ROOT/$rel" "$HERE/assets/$rel"
done
"$GODOT" --headless --path "$HERE" --import >/dev/null 2>&1 || true
cmd=("$GODOT" --path "$HERE" preview.tscn --resolution "${RES:-1600x900}")
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
  cmd=(xvfb-run -a -s "-screen 0 ${RES:-1600x900}x24" "${cmd[@]}")
fi
ITEMS="$ITEMS" OUT="$OUT" "${cmd[@]}" >/dev/null 2>&1
echo "wrote $OUT"
