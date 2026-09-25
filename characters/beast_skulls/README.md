# Beast skulls

Separate head shapes for each skull type, replacing the one shared `TR_Muzzle`. The shapes are built
on the Toriyama kit base head (`toriyama_kit/base/M/M.glb`, the same head F uses). The plan is in
`docs/BEAST_HEADS_FIX.md`.

One sheet per family: black side silhouettes (the "can you tell them apart" check) and a 3/4 view
in color, at b = 0, 0.25, 0.5 and 1.

| Family | Silhouettes | Color |
|---|---|---|
| Beastfolk: wolf, cat, bear, rabbit | [silhouette_beastfolk.png](silhouette_beastfolk.png) | [color_beastfolk.png](color_beastfolk.png) |
| Draconic: lizard, horned, crested, gecko, chameleon, winglet | [silhouette_draconic.png](silhouette_draconic.png) | [color_draconic.png](color_draconic.png) |
| Aquatic: shark, fish, eel, coral, octopus, manta | [silhouette_aquatic.png](silhouette_aquatic.png) | [color_aquatic.png](color_aquatic.png) |

## Files

| File | What it is |
|------|------------|
| `tr_beast_skulls.py` | Blender module: skull settings, `add_skull_keys()`, `make_parts()`, `beast_values()` |
| `render_skulls.py` | Loads a kit base, adds the keys and parts, and renders the two check sheets |
| `beast_skulls_M.glb` / `.blend` | Kit base M with the new keys and parts, ready to look at in Blender or Godot |

To rebuild: `pip install bpy pillow`, then
`python3 render_skulls.py <path>/toriyama_kit/base/M/M.glb <out dir>`.
Add `ROWS=shark,bear` in front of the command to render only some lineages.

## New shape keys

On `Head_Base` and every face decal (eyes, brows, mouth, nose, ear ink, AE_*):
`TR_Skull_<Type>_Mid/Full` for Canid, Feline, Ursine, Lagomorph, Saurian, Gecko, Shark, Aquatic, Cephalo and
Manta.
All the existing keys (expressions, `TR_Chin`, `Pose_Rest`, body shapes) are left alone.

- **Canid** (wolf, dog, fox): long tapered snout, a clear stop under the eyes, the nose pad sits
  lower than the eyes and the lower jaw is shorter than the upper.
- **Feline** (cat, lion, tiger): short muzzle pad, human nose flattened, puffed cheeks, very little
  chin and bigger eyes.
- **Saurian** (lizard, croc, horned and crested dragon): no stop, the forehead slopes straight into
  a long flat snout, flattened crown, heavy brow, eyes pushed back and turned toward the sides.
- **Shark**: the forehead runs into a pointed rostrum over an underslung mouth, the chin tucks back,
  the throat fills in so the head runs into the neck, and the eyes sit on the sides.
- **Ursine** (bear): round, wider skull, a short broad blunt snout, puffed cheeks and small eyes.
- **Lagomorph** (rabbit, hare): round head, and a soft blunt muzzle that the forehead slopes into
  with no stop (unlike the cat's flat face). Puffy cheeks, a small receding chin, and eyes set
  wide and turned a little to the sides.
- **Gecko** (gecko, chameleon, winglet dragon): wide round head with a flat face and almost no
  snout, receding chin, flattened crown, and big eyes that look out to the sides.

- **Aquatic** (fish, eel, coral): stays human-shaped by design, as in the aquatic reference sheet.
  It is smooth and bald, with a flatter nose, wider eyes and a small chin. Fins, gills and antlers
  do the rest.
- **Cephalo** (octopus, squid): the back and top of the skull swell into a big round bulb, with a
  small face set low and no nose.
- **Manta** (manta, ray): a flat, wide head with the crown pressed down, eyes out at the edges and
  turned sideways, plus cephalic fins.

Reptiles, sharks and sea folk get slimmer brow decals, so their faces don't read as human.

Eyes and brows move as rigid pieces, so the painted eyes never smear, and they snap onto the
reshaped skin.

## Parts

Parts are skinned to `DEF-head`:

- `TR_Beast_Nose_<Type>`: dog nose pad, small pink cat triangle, or two lizard nostrils. Each one
  carries its type's skull keys, so it slides from the human nose out to the snout tip. The human
  nose decals shrink away in those keys.
  The bear gets a bigger pad and the gecko smaller nostrils.
- `TR_Beast_Ears_<Type>`: tall wolf ears, wide cat ears, small round bear ears, or long rabbit ears. Lizards, sharks
  and geckos have none. The human ears tuck into the skull as the slider goes up.
- `TR_Beast_Mouth_Shark` + `TR_Beast_Teeth_Shark`: a grin with a row of teeth under the rostrum.
- `TR_Beast_Nose_Lagomorph`, `TR_Beast_MouthStem_Lagomorph`, `TR_Beast_Mouth_Lagomorph`: a small
  pink nose over a Y-shaped mouth.
- `TR_Beast_Mouth_Gecko`: the big smile that wraps round to the cheeks.
- `TR_Beast_Gills_Shark`: three slits on each side of the jaw. They show from the hybrid stage,
  like the fish girl in the aquatic sheet.
- `TR_Beast_Casque_Gecko`: the chameleon crest along the top of the head.
- `TR_Beast_Horns_Saurian`: big horns rising and sweeping back (horned dragon). They show from the
  hybrid stage, like the dragon-hybrids in the reference, and grow with the slider.
- `TR_Beast_HornsSmall_Saurian`: short horns (smooth-scale dragon).
- `TR_Beast_Crest_Saurian`: a fan of scale spikes over the back of the skull (crested dragon).
- `TR_Beast_Spines_Saurian`: a low row of spines down the centre of the head (lizard).
- `TR_Beast_Nubs_Gecko`: two short horn nubs (winglet dragon).
- `TR_Beast_Fin_Aquatic_L/R`, `TR_Beast_FinSmall_Aquatic_L/R`: webbed fin-ears with a scalloped
  edge where the human ears were (fish gets the big pair; eel and coral get the small pair).
- `TR_Beast_Gills_Aquatic`: gill slits for fish and eel.
- `TR_Beast_Antlers_Aquatic`: branching coral antlers.
- `TR_Beast_Mouth_Manta`, `TR_Beast_Cephalic_Manta`: a wide flat mouth, with the two fin lobes
  curling down at its corners.

Which lineage wears which part lives in `LINEAGE_PARTS`. The slider value each part appears at
lives in `PART_FROM`: hybrid traits (ears, horns, crest, fins, gills, antlers) at 0.2, and face
parts (nose, mouth, spines, casque, cephalic fins) at 0.3. Horns, spikes, antlers and cephalic
fins stay rigid and ride the reshaped skull, so they never bend with it.

The mouth, teeth and casque are laid on the head surface and carry the skull keys, so they stay on
the skin as it reshapes.

## Godot side

For each head mesh, set the values from `beast_values(lineage, b)`:
`mid = clamp((b - .25) / .25)`, `full = clamp((b - .5) / .5)`,
`TR_Skull_<Type>_Mid = mid * (1 - full)`, `TR_Skull_<Type>_Full = full`, and 0 for every other
type. `parts_visible(lineage, b)` returns which part sets to show for that lineage.

## Not done yet

- Fox's narrower snout.
- Fish and eel look almost the same as a human in black silhouette. That's intended (the sea folk
  stay human-shaped), so they are told apart by fins and color.
- The manta's cephalic fins are round tubes; flat, leaf-shaped lobes would read better.
- The dragons' wings, tails and fins on the body.
- Fur and scale materials. The sheet colors are flat preview colors.
- A mouth line for the wolf, cat, lizard and bear. The shark and gecko have one; the others
  still carry the human mouth decal out to the snout tip.
- The ears are simple cupped cards and could use a proper sculpt.
