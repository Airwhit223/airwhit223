# Beast skulls (first three)

Separate head shapes for each skull type, replacing the one shared `TR_Muzzle`. The shapes are built
on the Toriyama kit base head (`toriyama_kit/base/M/M.glb`, the same head F uses). The plan is in
`docs/BEAST_HEADS_FIX.md`.

![silhouettes](silhouette_side.png)
![color](color_34.png)

## Files

| File | What it is |
|------|------------|
| `tr_beast_skulls.py` | Blender module: skull settings, `add_skull_keys()`, `make_parts()`, `beast_values()` |
| `render_skulls.py` | Loads a kit base, adds the keys and parts, and renders the two check sheets |
| `beast_skulls_M.glb` / `.blend` | Kit base M with the new keys and parts, ready to look at in Blender or Godot |

To rebuild: `pip install bpy pillow`, then
`python3 render_skulls.py <path>/toriyama_kit/base/M/M.glb <out dir>`.

## New shape keys

On `Head_Base` and every face decal (eyes, brows, mouth, nose, ear ink, AE_*):
`TR_Skull_Canid_Mid/Full`, `TR_Skull_Feline_Mid/Full` and `TR_Skull_Saurian_Mid/Full`.
All the existing keys (expressions, `TR_Chin`, `Pose_Rest`, body shapes) are left alone.

- **Canid** (wolf, dog, fox): long tapered snout, a clear stop under the eyes, the nose pad sits
  lower than the eyes and the lower jaw is shorter than the upper.
- **Feline** (cat, lion, tiger): short muzzle pad, human nose flattened, puffed cheeks, very little
  chin and bigger eyes.
- **Saurian** (lizard, croc, horned and crested dragon): no stop, the forehead slopes straight into
  a long flat snout, flattened crown, heavy brow, eyes pushed back and turned toward the sides.

Eyes and brows move as rigid pieces, so the painted eyes never smear, and they snap onto the
reshaped skin.

## Parts

Parts are skinned to `DEF-head`:

- `TR_Beast_Nose_<Type>`: dog nose pad, small pink cat triangle, or two lizard nostrils. Each one
  carries its type's skull keys, so it slides from the human nose out to the snout tip. The human
  nose decals shrink away in those keys.
- `TR_Beast_Ears_Canid`, `TR_Beast_Ears_Feline`: tall wolf ears or wide cat ears. Lizards have
  none. The human ears tuck into the skull as the slider goes up.

## Godot side

For each head mesh, set the values from `beast_values(lineage, b)`:
`mid = clamp((b - .25) / .25)`, `full = clamp((b - .5) / .5)`,
`TR_Skull_<Type>_Mid = mid * (1 - full)`, `TR_Skull_<Type>_Full = full`, and 0 for every other
type. Show the ear part from b ≥ 0.2 and the nose part from b ≥ 0.3.

## Not done yet

- Fox's narrower snout, the other seven skull types, horns, crests, fins.
- Fur and scale materials. The sheet colors are flat preview colors.
- An animal mouth line along the snout. The human mouth decal just rides to the snout tip for now.
- The ears are simple cupped cards and could use a proper sculpt.
