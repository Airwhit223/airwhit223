#!/usr/bin/env bash
# Rebuilds every asset in the repo from its Python build script.
#
#   tools/build_all.sh              # everything
#   tools/build_all.sh pets props   # only some groups
#
# Needs Blender's Python: set PYTHON to a python that has the `bpy` module
# (pip install bpy on Python 3.13), or to `blender --background --python`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"
LOGS="${LOGS:-$ROOT/.build_logs}"
mkdir -p "$LOGS"

run() {  # run <dir> <script> [args...]
  local dir="$1" script="$2"; shift 2
  local log="$LOGS/$(basename "$script" .py).log"
  echo "== $dir/$script $*"
  (cd "$ROOT/$dir" && $PYTHON "$script" "$@" >"$log" 2>&1) || { echo "FAILED: see $log"; tail -20 "$log"; exit 1; }
  grep -E "triangles|parts," "$log" | sed 's/^/   /' || true
}

groups=("$@")
[ ${#groups[@]} -eq 0 ] && groups=(pets farm characters monsters props)

for g in "${groups[@]}"; do
  case "$g" in
    pets)       run pets build_pets.py ;;
    farm)       run farm build_farm.py ;;
    characters) run characters build_hoodie_guy.py
                run characters build_casual_girl.py
                run characters build_queen_meshy.py
                run characters build_egyptian_queen.py
                run characters build_beastfolk.py
                run characters build_egypt_warriors.py
                run characters/weapons build_weapons.py ;;
    monsters)   run monsters build_monsters.py ;;
    props)      run props build_restaurant.py
                run props build_farm_props.py
                run props build_house_props.py
                run props build_house_kit.py ;;
    *) echo "unknown group: $g (pets farm characters monsters props)"; exit 1 ;;
  esac
done
find "$ROOT" -name "*.blend1" -delete
echo "done"
