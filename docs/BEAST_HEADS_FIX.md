# Beast heads: why they all come out as the same dog, and how to fix it

Covers the three animal families in `RACE_BIBLE.md` section 7b: Beastfolk (mammals), Aquatic folk and
Draconic folk. Target looks: `docs/reference_images/09_beastfolk_spectrum.jpg`, `10_dragonfolk_spectrum.jpg`,
`11_aquatic_folk.jpg`, plus the lizard sheet (eight lizardfolk in streetwear).

## Why every head looks like a dog

According to `docs/HANDOFF_CHARACTER_FIXES.md`, `tr_beastfolk.py` builds every lineage from the same four head
morphs: `TR_Muzzle`, `TR_Brow_Ridge`, `TR_Jaw_Animal` and `TR_Eye_Spread`, plus `TR_Muzzle_Full` at the far end.
The lineage only changes **how much** of each morph gets applied (`beast_values(lineage, b)`), never the **shape**.
There is one muzzle sculpt, so a cat is a short dog, a shark is a long dog and a dragon is a dog with horns.
Scaling one shape can't turn it into a different skull.

(I couldn't see `tr_beastfolk.py` itself because it isn't in the snapshot. This is based on the handoff notes.)

## The fix: keep the slider, give each skull its own target

Keep the design decision exactly as it is: one 0..1 person→beast slider, all blend shapes, and awakening
pushes further along the same slider. What changes is that **each skull type gets its own sculpted targets**,
and the lineage picks which set the slider drives.

### 1. Skull types (sculpt these, not one per animal)

Each type needs two shape keys on `Head_Base`: `TR_Skull_<Type>_Mid` (b = 0.5) and `TR_Skull_<Type>_Full`
(b = 1.0). Similar animals share a type and differ only through parts and colors.

| Skull type | Lineages | What the silhouette must show |
|---|---|---|
| `Canid` | wolf, dog, fox (fox: longer and thinner, set via a small `TR_Snout_Narrow` modifier) | long tapered snout, stop at the brow, black nose pad at the tip, mouth line runs back under the eye |
| `Feline` | cat, lion, tiger | **short** muzzle, flat round face, big forward eyes, small triangle nose, split upper lip |
| `Ursine` | bear | round skull, short **broad** blunt snout, small eyes, small round ears high up |
| `Lagomorph` | rabbit, hare | rounded head, small soft muzzle, Y-shaped mouth, eyes set wide |
| `Saurian` | lizard, crocodilian, horned dragon, crested dragon | flat top, long straight jaw with **no stop**, heavy brow ridge, nostrils on top of the snout, lipless mouth line almost to the ear |
| `Gecko` | gecko, chameleon, winglet dragon | wide rounded head, **very wide smile**, almost no snout, big eyes at the sides (the leopard gecko in the lizard sheet) |
| `Shark` | shark | pointed rostrum above an **underslung** wide mouth, eyes on the sides, gill slits (part) |
| `Manta` | manta, ray | flattened wide head, eyes at the outer edges, cephalic fins (part) |
| `Cephalo` | octopus, squid | tall bulb cranium, small face low on the head, no nose |
| `Aquatic` | fish, eel, coral | stays human-shaped: bald, smooth, slightly wider eyes, flatter nose. Fins, frills and antlers are parts |

Ten skull types instead of one muzzle. Most of the look still comes from parts (step 3), so this stays manageable.

### 2. Slider stages

| b | Name | Head | Body |
|---|---|---|---|
| 0.0 | Human with traits | human head, no skull morph | human skin |
| 0.25 | Hybrid | still human. Traits come from **parts only**: ears, horns, fin-ears, cheek scale patches, fangs | tail, scale/fur patches |
| 0.5 | Mid | `_Mid` skull key at 1: snout/face clearly animal, but human-sized eyes and expressions | fur/scale shell on arms and neck |
| 1.0 | Animal humanoid | `_Full` skull key at 1 | fully furred/scaled, clawed hands |
| awakening | past 1.0 | `_Full` plus lineage extras (bigger fangs, horns, spines, glowing marks) | |
| full beast | separate model | e.g. `character/transformations/wolf_beast_full.glb` | |

Mapping: `mid = clamp((b - 0.25) / 0.25, 0, 1)`, `full = clamp((b - 0.5) / 0.5, 0, 1)`.
Drive `TR_Skull_<Type>_Mid = mid * (1 - full)` and `TR_Skull_<Type>_Full = full`. Only the active type's keys are
ever nonzero. As before, the mapping ships in the kit manifest so GDScript doesn't copy the formula.

The references show this: the dragon-hybrid and cat-hybrid are **fully human faces** with horns/ears added,
while the fox "mid-spectrum" already has a real fox head.

### 3. Parts per lineage (swap by lineage, not morph)

Shape keys can't add geometry, so anything that sticks out is its own mesh on `DEF-head`:

- **Nose**: dog pad (canid, ursine), small pink triangle (feline, lagomorph), two slits (saurian, gecko,
  shark), none (aquatic, cephalo, manta). *One shared dog nose on every head alone makes everything read as a dog.*
- **Ears**: canid, fox (tall), feline, bear (round), rabbit (long), fin-ears (fish, eel), none (saurian, shark,
  cephalo), ear-frills (crested dragon).
- **Head extras**: horns (horned dragon, 2 styles), crest (crested dragon, chameleon casque), spine ridge
  (lizard), coral antlers, dorsal fin (shark), cephalic fins (manta), gills (shark, fish, eel).
- **Mouth**: fangs (canid, feline), rows of teeth (shark), lipless line (saurian, gecko).
- **Eyes**: pupil texture per lineage: round, slit (feline, saurian, dragon), horizontal (none yet), solid
  (shark, eel). This is cheap and makes a big difference.

### 4. Check: can you tell them apart in silhouette?

Render every lineage at b = 1.0 in **side profile, solid black on white**, all in one strip. Do the same at
b = 0.5. Someone who hasn't seen the labels should be able to name each one. If two can't be told apart (the
current wolf, cat and shark, for example), that skull type needs more sculpting before anything else ships.
Also render the b = 0.25 strip in color and check the faces are still clearly human.

## Status

Every skull type in the table above is in `characters/beast_skulls/`, with part sets for each lineage
(ears, noses, mouths, horns, crests, spines, casque, fin-ears, gills, antlers, cephalic fins).
There is one silhouette sheet and one color sheet per family.

## Build order

1. Sculpt `Canid`, `Feline` and `Saurian` `_Mid` and `_Full`, and add the per-lineage nose parts. Run the
   silhouette check on those three. If they read clearly, the method works.
2. `Shark`, `Aquatic`, `Gecko`, then the rest.
3. Horns, crests, fins and ears as parts.
4. Export to the kit and add the Character Creator **Family → Lineage → Expression** sliders.
