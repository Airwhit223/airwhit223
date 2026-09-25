# Handoff: recent character-system fixes other threads must not overwrite

Several threads edit the same character files (creator/kit, body channels, beastfolk). These fixes landed on
2026-09-17/18 and are easy to lose if a file is rebuilt from an older copy. **Before editing any file below, read its
current version from disk and merge into it — do not paste in an older copy.** Run the listed tests afterwards.

## Godot — life-sim-prototype

### `character/toriyama_kit/kit_character.gd`
- **Part removal (hair/clothing stacking bug).** When a part is attached, `_adopt()` moves its meshes off the GLB root
  onto the shared skeleton, so the root is empty afterwards. `_part_roots[key]` is now a Dictionary
  `{root, meshes, attachments}`, filled by `_dress()`, and `_remove_part(key)` frees the meshes and the
  `Kit_*` BoneAttachment3D nodes — not just the root. `set_hair_style()` and `set_garment()` go through it. Before
  this, switching hairstyles left every previous style on the head. Any new part type (beast ears, nose, tail) must be
  attached through `_dress(..., part_key)` and removed through `_remove_part()`.
- `_set_shape("Pose_Rest", 1.0)` after assembly and after every garment add — the arms-down corrective (below).
- `set_definition()` (Def_* sliders), `set_eye_preset()` (7 eye shapes), `_register_motion()` after assembly, hair
  swaps and garment adds.

### `character/toriyama/toriyama_character.gd`
- `motion := SecondaryMotion.new()`, updated in `_process`; `_register_motion()` classifies hair vs clothing;
  `head_anchor()` / `waist_anchor()` give model-space anchors. Also holds `Pose_Rest` at 1 in `setup()`.

### `character/toriyama/secondary_motion.gd` — **beastfolk tails use this**
- API: `register(material, profile, origin, amount, range_m)`. Profiles: `"hair"`, `"cloth"`, and `"tail"`
  (added 2026-09-18 for Beastfolk — softer, swingier, longer reach). `range_m` overrides the profile's reach for one
  piece, so a tail passes its own length (`tr_secondary_range`). An unknown profile name now logs a warning instead
  of being ignored silently.
- The spring trails body VELOCITY (not acceleration — a steady walk produced nothing under the old model). Total
  offset is clamped, and position jumps over 0.75 m or speeds over 14 m/s are ignored (spawn/teleport spikes), and
  `register()` resets the start frame.

### Shaders `toriyama_paint.gdshader` + `toriyama_ink.gdshader`
- Both carry the same `sway_*` uniforms and `sway_vertex()`, applied to VERTEX before anything else in `vertex()`.
  **The ink pass must match the paint pass** or outlines peel off moving hair/tails.
- `vertex()` writes `POSITION` unconditionally. Writing it only inside a branch leaves it undefined and the paint pass
  vanishes, leaving characters as black ink silhouettes.
- Retro PS2 uniforms (`retro_*` globals) — leave in place.

### Creator + opening
- `ui/character_creator.gd` has an in-world mode (`in_world`, `target_rig`) used by `scenes/intro_sequence.gd` and
  the bedroom mirror; a new game starts at the mirror, not the old full-screen creator.
- `player/player.gd`: `input_locked`, `open_creator(allow_cancel, mirror)`, `apply_recipe()` also pushes
  `recipe["traits"]` into TraitSystem.

### Changes from the beard/beastfolk thread (Blender side only, no .gd/.gdshader touched)
- `tr_beard.py` (new): Mr. Jones' beard is a shell grown off Head_Base with `Beard_Grow`/`Beard_Shag` on the hair clock;
  the clump beard left `cut_jones_curls_beard`. Opt in with `beard='full'` in tr_factions. It copies every head key,
  `Pose_Rest` included.
- `tr_body_shapes.py` (new): `TR_Leg_Length`/`TR_Belly`/`TR_Definition`/`TR_Posture` at tr_build step 3a2, propagated to
  older garments after 3b2; `propagate_to_garments` takes `key_names`/`prefix`/`drive`.
- Exporters: `KEEP` includes `TR_` (tr_export also `Beard_`); the manifest has a `beard` entry and `TR_Beard` is a
  vertex-colour mesh.
- `tr_beastfolk.py` (new, WIP, not yet in the kit export): head morphs `TR_Muzzle`/`TR_Brow_Ridge`/`TR_Jaw_Animal`/
  `TR_Eye_Spread` and parts `TR_Beast_*` (ears, inner ear, nose, mouth line, fangs on DEF-head; face fur shell; tail on
  DEF-pelvis with `tr_secondary_anchor`/`_profile`/`_range` props; the tail's profile is now `"tail"`).
- **Beastfolk are one person↔beast axis, 0..1, all blend shapes** — Godot slides a character along it live, and
  awakening means pushing further along the same axis, not swapping models. Character_CTRL keys: `TR_Muzzle`,
  `TR_Brow_Ridge`, `TR_Jaw_Animal`, `TR_Eye_Spread` (the base four) and `TR_Muzzle_Full`, `TR_Fur_Full`, `TR_Ear_Big`,
  `TR_Tail_Big` (the full four). Mapping lives in `tr_beastfolk.beast_values(lineage, b)`: `base = min(1, b/.5)` scales
  the first four to their lineage values; `full = max(0, (b-.5)/.5)` drives the last four directly. The mapping will
  ship in the kit manifest, so GDScript reads it rather than copying the formula.
- Pending, Godot side: once the export carries `tr_secondary_anchor`/`_profile`/`_range` as kit.json fields,
  `kit_character.gd` `_register_motion()` needs a branch that registers those parts with their own profile and range
  (the beastfolk thread will ping when the fields exist).

## 2026-09-18 (later): nose patch, chin, pant hems
- **`equipment/character_equipment.gd`**: on a Toriyama model, socket items that are not hand tools (the old primitive
  `black_beanie` / `baseball_cap` from STARTING_EQUIPMENT and npc_roster) get no mesh. They were flat cylinders on
  the head socket that sat inside the hair and poked through the face: the black arch on the nose bridge in the mirror,
  flickering as it depth-fought the face. Items stay equipped; headwear on these models comes from the kit.
- **`TR_Chin`** (`work/toriyama_system/tr_fit_fixes.py`, tr_build step 3b3, before Pose_Rest): additive head key,
  ~1.4 cm forward / 0.6 cm down on the chin — the base head sloped straight back from the lip to the neck. Held at 1 in
  `ToriyamaCharacter.setup` and `kit_character.set_chin()` (recipe `"chin"`, creator Face tab slider 0..1.5).
  Base M/F kit parts re-exported with it. Baked preset characters (rivals, hero looks) pick it up on their next
  `tr_export` (no re-export done yet).
- **Longer hems** on `Pants_Casual_01` and `TR_Baggy_Jeans` (hem z .13 -> .09, 25% flare) so the ankle no longer shows
  above the sneakers on every stride. Applied to every shape key, tagged `tr_hem_lengthened` so it runs once.
  Both garments re-exported. Pre-fix blend: `outputs/toriyama_system/toriyama_character_system_pre_fit_fixes.blend`.
- Run tr_kit_export with separate arguments (`-- base M`). Passing one quoted string ("base M") writes into a folder
  named `kit/base M/` and exports nothing — that is where the stray empty folders came from (removed).

## 2026-09-18 (evening): head scale, leg bones, strand sway (request from the beard/beastfolk thread)
- **Head 0.80 for everyone** — `ToriyamaCharacter.set_proportions(head, legs)` sets a uniform pose scale on
  `DEF-head` (pivot = neck joint). Default `HEAD_SCALE` 0.80; per character: manifest `head_scale` (baked) or
  recipe `head_scale` (kit). `sync_from_rig` writes only bone rotations + the DEF-pelvis bob, so pose scales persist.
- **Leg length on bones** — `k = 1 + 0.085 * leg_length`; `DEF-thigh.L/.R` pose scale `(1, k, 1)`, `root` raised
  `(k - 1) * 0.91` m. `TR_Leg_Length` is held at 0 (deprecated). Per character: manifest `leg_length` or recipe
  `leg_length`. Checked: legs 0.85 raises the head 6.6 cm, feet stay on the floor within 5 mm.
  **Blender side still to do:** `tr_export.py`'s manifest must write `head_scale` and `leg_length` from the spec
  (Jones = 0.85), and the kit manifest `head_scale` if it ever differs from 0.80 — until then the game uses 0.80 / 0.
- **Strand sway (mode 2)** — both `toriyama_paint.gdshader` and `toriyama_ink.gdshader`: `sway_vertex(VERTEX, UV)`,
  `sway_len_ref` (0.25 m), `sway_offset_prev` (tips trail a beat). `w = t² * clamp(len / sway_len_ref)`, with
  t = UV.x (root 0 -> tip 1) and len = 1 - UV.y metres. `_register_motion` picks mode 2 for any hair surface that has
  UVs (only TR_Strand exports do; older hair has none) and falls back to mode 0 otherwise.
  `SecondaryMotion.register(..., mode := -1)` takes the override; it also tracks each entry's previous offset.
  Tails can pass `mode 2` when their export carries TR_Strand.
- Tests on macOS: pass `--always-on-top` when running the tests while working in other windows; a covered
  Godot window is throttled and a run can take 15+ minutes.

## 2026-09-22: neck reshape, head pass, DQ eyes, ears (Blender + Godot)
All of this is in `work/toriyama_system/tr_fit_fixes.py` (tr_build step 3b3) unless noted, and every change is an
ADDITIVE shape key or a weight change — the M8 body lock still passes.
- **TR_Neck** — the body's neck is now the visible neck (narrow under the jaw, flaring into the trapezius, nape
  leaning back, trap lifted, top edge hidden inside the jaw); the head's own neck section is tucked 7 mm inside it.
  Judged on silhouettes from 5 angles, then in Godot at 4 cameras.
- **TR_Head_Shape / TR_Jaw** — skull narrowed x0.92 and its BACK flattened to the sheets' 0.80 H depth, nose/mouth
  band lifted 16 mm. `head_warp()` is a world-space field: BOTH exporters (`tr_kit_export`, `tr_export`) now put
  TR_Head_Shape on hair, hats and beards, or they float off the narrower skull.
- **DQ eyes** — the shape is built into the eye generator now: `tr_face.EYE_SCALE_DQ` / `EYE_C_DQ` (bolder lid,
  peak over the inner third, outward flick, almond opening, wider spacing). `ca_face.build()` CANNOT be re-run on a
  built blend (it reshapes the head and the neck sleeve assert fails); rebuild just the four eye/brow objects the way
  the scratch script `eye_rebuild.py` does. The old TR_Eye_DQ key is removed.
- **TR_Ear_Big / TR_Ear_Point / TR_Ear_Out** — ear customisation (Point is the Race Bible's elf ear). They move only
  what is proud of the skull, between brow level and the nose tip; a taller zone grows points out of the skull.
- Godot: `ToriyamaCharacter` holds TR_Head_Shape 1 and TR_Jaw 0.6 (`JAW_DEFAULT`), `set_jaw()`, `set_ears()`,
  `set_eye_dq()` (legacy, 0); `kit_character` reads recipe `jaw`, `ears`, `eye_dq`; creator Face tab has Ears, Jaw
  and Chin sliders; `CreatorData.random_recipe()` varies jaw and ears.
- Judge faces in Godot, not in a flat single-colour Blender render: the eyes, nose and mouth are separate flat
  meshes and smear together, which cost this session two false "creases".

## Blender — work/toriyama_system

- **`tr_pose_fix.py` → `Pose_Rest` key on every deforming mesh.** Bakes Blender's volume-preserving skinning minus
  linear skinning for the game's arms-down rest pose. Gotchas, all needed: evaluate with ONLY the armature modifier
  enabled; force the armature modifier's `show_viewport` on (it is off in the M11 source); unhide the object
  (garments are built hidden and hidden objects are never evaluated); mute rig drivers while posing; call
  `obj.update_tag()` + `dg.update()` after changing `use_deform_preserve_volume`. New deforming meshes (beast parts on
  DEF-head/DEF-pelvis) get it automatically if they exist before step 3c in `tr_build.py`.
- `KEEP` in `tr_export.py` / `tr_kit_export.py` must keep `Pose_`, `Def_`, `Eye_Style_`, `Brow_Style_` (and `TR_`
  from the body-channels thread). Dropping one silently collapses that shape at export.
- `signature_core()` in `tr_body_def.py` ignores `Def_`, `Pose_` and `TR_` keys — the lock covers vertices, topology,
  weights and the original keys only.
- Build order in `tr_build.py`: body definition (3a) → body channels (3a2) → wardrobe + headwear (3b) → propagate
  channels to legacy garments (3b2) → pose correctives (3c) → inklines (4).

## Tests to run after touching any of this
`tests/kit_character_test.gd` (includes the hair and jacket swap regression), `character_creator_test`,
`intro_sequence_test`, `secondary_motion_test`, `rivals_hero_ingame_test` — each prints a single `*_TEST PASS` line.
