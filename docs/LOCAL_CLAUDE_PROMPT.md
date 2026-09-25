# Prompt for the Claude working in the game project

Paste everything below the line into Claude Code (or Antigravity) opened in
`/Users/whitlow/Documents/Game_Development/Projects/life-sim-prototype`.

---

Import the latest art from my asset repo into this Godot 4.7 project.

1. Get the assets: `git clone -b claude/cloud-credits-explanation-hhe8y7 https://github.com/Airwhit223/airwhit223.git ~/tmp/art` (or `git pull` if it is already there). Read `~/tmp/art/CLAUDE.md` and `~/tmp/art/docs/GODOT_IMPORT.md` first.
2. Copy only `.glb`, `.tres`, `.gd`, `.gdshader` and `README.md` files from these folders into `res://assets/art/` keeping the folder structure: `pets/`, `farm/`, `characters/` (including `beastfolk/` and `weapons/`), `monsters/`, `props/restaurant/`, `props/farm/`, `props/house/`, `props/house_kit/`, `water/`. Do not copy `.blend` or `.py` files. If older copies of these assets exist elsewhere in the project, tell me where before replacing anything.
3. All models now face **+Z** (Godot's model front). Find any code or scenes that rotated these models by 180° to compensate for the old -Z facing and remove that rotation; list what you changed.
4. Set import settings: loop `idle` and `walk` animations; apply the toon material from each folder as the material override (thick outline for big things, `toon_small.tres` for small props); give meshes named `glow` an unshaded material.
5. Make a test scene `res://tests/art_gallery.tscn` that lays out one of each asset group on a floor with a camera, so I can check everything at a glance. Run the project's existing tests if there are any.
6. Do not change networking or gameplay code beyond step 3. Tell me what you imported, anything that failed to import, and anything you were unsure about instead of guessing.
