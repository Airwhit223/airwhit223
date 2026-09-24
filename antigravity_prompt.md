# Prompt for Antigravity

Paste everything below the line into Antigravity.

---

In my Godot project at `/Users/whitlow/Documents/Game_Development/Projects/life-sim-prototype`, push a snapshot of the project to my GitHub repo `airwhit223/airwhit223` on a NEW branch named `local-project-snapshot`. Do not touch any other branch, and do not modify or delete anything in the original project folder.

Steps:
1. Clone `https://github.com/airwhit223/airwhit223.git` into a temporary folder, for example `~/tmp/airwhit223-snapshot`.
2. In that clone, run `git checkout --orphan local-project-snapshot`, then `git rm -rf .` to clear the checked-out files.
3. Copy the whole life-sim-prototype project into a `life-sim-prototype/` subfolder of that clone. Skip these:
   - `.godot/` and `.import/` folders
   - `*.import` files
   - `export/` or `build/` folders
   - `.DS_Store`
   - any file larger than 50 MB
4. Make sure the copy includes:
   - every script and scene: `.gd`, `.gdshader`, `.py`, `.tscn`, `.tres` and `project.godot`
   - the beastfolk/character build scripts and head-render test scripts Claude wrote
   - render PNGs such as the "v2 snub muzzle" head comparison
5. Commit with the message `Snapshot of local life-sim-prototype for cloud review`, then run `git push -u origin local-project-snapshot`.
6. Tell me the list of top-level folders you pushed and the total size.
