# Starter Street — build notes

The first playable street: one house, one shop, a curving road (dirt → cobble), props clustered at the doors.
Targets: `references/characters/style_targets/street_player.jpg` (player view) and `street_overview.jpg` (overview).
The design spec (layout, 7-colour palette, prop list, placement rules, lighting presets) came from the user on
2026-09-18; this file records how it was built and where the build departs from it.

## Files
- `tools/build_starter_street.gd` — **generator**. Builds every material, every prop scene, the house, the shop and
  `world/starter_street/starter_street.tscn`. Edit layout/props here and re-run; hand edits to generated scenes are lost.
  Run WITHOUT `--headless` (headless drops MultiMesh data and shader defaults on save):
  `Godot --path . -s res://tools/build_starter_street.gd`
- `world/starter_street/props/*.tscn` — 24 reusable prop scenes; `house.tscn`, `shop.tscn` beside them.
- `world/starter_street/materials/*.tres` — one ShaderMaterial per palette entry (shared, so lighting changes reach all).
- `world/starter_street/street_lighting.gd` (StreetLighting) — golden hour / night, follows TimeManager (night 20:00–6:00).
- `world/starter_street/starter_street.gd` (StarterStreet) — registers spots with WorldState, closer player camera.
- `world/shaders/toon_world.gdshader` — the two-tone surface; `toon_world_noink.gdshader` (grass tufts);
  `ink_screen.gdshader` (outlines); `toon_sky.gdshader`; `blob_shadow.gdshader`.
- `tests/starter_street_test.gd` — structure + placement-rule checks, screenshots to `user://starter_street/`.
- Look-test boards: `outputs/world_system/starter_street/compare_*.png`.

## How the look works
- **Exactly two tones per material, hard cut.** The shadow tone is emitted (so it is the palette colour exactly); the
  sun adds the lit−shadow difference where it reaches. Cast shadows count as shadow. No ambient, no specular.
- **Outlines are screen-space, not inverted hulls** (a deliberate departure from the spec). Box primitives have split
  normals, so pushed-out hulls crack at every corner, and hulls never draw creases (post meets wall). The ink pass
  finds depth steps and normal creases on everything; characters keep their own hull ink on top.
- **Inked detail lines** (planks, shingles, cobbles) are drawn by the surface shader in world space and fade out when
  they get smaller than a few pixels, so distant siding never turns solid black. Cobbles show dirt between stones.
- Tiny dense things (grass tufts) render in the transparent pass so the ink pass cannot swallow them.
- Night keeps the sun as a dim blue moon rather than switching it off — characters are lit only by lights and would
  go black otherwise.

## Departures from the spec, and why
- Fire hydrant red, lamp is a black iron lantern, window trim is wood not cream, no shutters on the house — to match
  the two target images (the spec said Metal Accent / sphere lamp / teal shutters).
- Sun is from the west-southwest (spec: west). Due west only grazes the south-facing porch and left it in shadow.
- Shop sign reads GENERAL GOODS, on the roof edge (target overview). Change `ShopName` in the generator.
- Garden: the existing FarmPlot sits inside the raised bed; its own soil is hidden under the bed's dirt, so only crops
  show. It starts empty (the target shows it planted).
- Curb stones, loose stepping stones, flower clumps, distant houses and a backdrop tree line were added from the
  targets; they are not in the spec's prop list.

## Not done yet
- Doors: `HouseDoor` / `ShopDoor` markers exist; no Teleporter until there are interiors on this street.
- No NavigationRegion bake yet, so NPCs cannot path here; `RoadWalkPath` is a Path3D ready for a walker.
- Gap to the target (see compare_player_view.png): painted texture inside each tone, the big tree actually over the
  path, more clutter. Strict two tones read flatter than the painting.

## Density pass (2026-09-18, user: "however you recommend")
- Lane narrowed to 4 m (`ROAD_HALF` 2.0; spec said 6 m — it read as a highway beside the target). Everything placed
  in `_street()` is pulled toward the road (`squeeze()`: house side 0.8 m, shop side 1.0 m). Added the LaneTree
  between house and shop, a second outer tree ring and low hills (`far_green`).

## In the game (main.tscn)
- `world/world_look.gd` (WorldLook): `apply_environment()` gives any scene the sky, lighting presets and ink pass;
  `toon_subtree()` swaps StandardMaterial3D for two-tone toon materials, skipping scripts that recolour their own
  meshes at runtime (`KEEP_SCRIPTS`: farm plots, guitar stand, mirror, enemies, character rig/equipment, rewards).
- `main.gd`: `_dress_buildings()` (before the nav bake) swaps graybox PlayerHome and Store for the kit house/shop via
  `KIT_BUILDINGS`, keeping node names, doors, `home_player` and `loc_store`; `_apply_world_look()` runs before any
  character spawns; town-growth buildings are toon-converted as they appear. Test: `tests/world_look_test.gd`.
- Still graybox: the four neighbour homes, gym, court, skate/social pads, garden plots, interiors, town-growth lots.
- Known: from far/high cameras characters read almost black (their hull ink plus the screen ink at a few pixels
  tall). Fine at play distance.
