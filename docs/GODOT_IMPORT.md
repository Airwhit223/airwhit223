# Using these assets in Godot 4.7

## 1. Copy the folders

Copy the asset folders into the game project, keeping the folder names so
the `.tres` materials next to each group still resolve, for example:

```
life-sim-prototype/assets/art/pets/          <- pets/*.glb, pet_toon.tres
life-sim-prototype/assets/art/farm/          <- farm/*.glb, dq_toon.tres
life-sim-prototype/assets/art/characters/    <- characters/*.glb, beastfolk/, weapons/
life-sim-prototype/assets/art/monsters/      <- monsters/*.glb, monster_toon.tres
life-sim-prototype/assets/art/props/...      <- props/<group>/*.glb + toon_*.tres
life-sim-prototype/assets/art/water/         <- water/*
```

You only need the `.glb`, `.tres`, `.gd` and `.gdshader` files. The `.blend`
and `.py` files stay in this repo.

## 2. Facing and scale

- Everything faces **+Z** (Godot's `Vector3.MODEL_FRONT`). A character
  walking along its basis `+Z` walks face-first; `look_at()` users should
  pass `use_model_front = true`.
- Scale is real meters: the hoodie guy is 1.78 m, doors are 2.16 m, the
  house kit is on a 2 m grid.
- Origins are at the bottom center (on the floor), except doors and gates
  (hinge) and wall items (back).

## 3. Materials (the cartoon look)

Colors are vertex colors. Set the toon material as the **material override**
so you get flat shading and the black outline:

- In the `.glb` import dialog: *Meshes → your mesh → Material Override*, or
- in code: `mesh_instance.material_override = preload("res://.../dq_toon.tres")`.

Use the folder's thick-outline material (`dq_toon.tres`, `toon_large.tres`,
`pet_toon.tres`, `monster_toon.tres`) for characters, animals and furniture,
and `toon_small.tres` for tiny things (eggs, toast, controllers, balls) so
the outline does not swallow them.

Meshes named `glow` (monster eyes) want an unshaded or emissive material;
meshes named `screen` (TV, monitor, handheld, treadmill) can take a
`ViewportTexture` to show a live picture.

## 4. Animations

- Pets and farm animals: `idle` (set it to loop in the import settings).
- Monsters: `idle`, `walk`, `attack` (bat and shadow: `idle`, `attack`).
  Loop `idle` and `walk`. They move the `root` bone for bobbing and lunges.
- Humanoid characters ship without animations. Their skeleton uses Godot's
  humanoid bone names; in the import dialog set *Skeleton → Bone Map* to
  `SkeletonProfileHumanoid` and retarget Mixamo or other humanoid
  animations onto them.

## 5. Collision

- Props: *Mesh → Create Collision Shape* (convex for small props, trimesh
  for the barn and house-kit walls you walk around).
- Characters and monsters: a `CapsuleShape3D` on the `CharacterBody3D`.

## 6. Beastfolk

`characters/beastfolk/beastfolk.gd` (`class_name Beastfolk`) sits on a
`Node3D` with `beastfolk_male.glb` or `beastfolk_female.glb` as a child; set
species, form, outfit and colors in the inspector or from code. For
multiplayer, keep those properties in the player's synced profile and set
them on every peer; see `characters/beastfolk/README.md`.
