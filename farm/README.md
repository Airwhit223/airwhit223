# Farm animals

Stylized, rigged farm animals in a Dragon Quest-inspired style (chunky
bodies, big heads, stubby legs, round Toriyama-style eyes, bold outlines),
shown next to the hoodie guy for scale.

![farm animals](preview.png)
![close-up](preview_chickens.png)

| File | Animal |
|------|--------|
| `cow.glb` | Black-and-white cow (back at ~1.2 m) |
| `cow_brown.glb` | Brown-and-white cow |
| `sheep.glb` | White sheep with a dark face (~0.85 m) |
| `sheep_black.glb` | Black sheep |
| `chicken.glb` | White hen (~0.5 m) |
| `chicken_brown.glb` | Brown hen |

About 16–17k triangles each. Every animal has a skeleton (head, neck,
spine, legs, tail) and a looping `idle` animation (tail swish, breathing,
head bob), like the pets.

## Using them in Godot

Copy the `farm/` folder into your project, set `farm/dq_toon.tres` (thicker
outline for the Dragon Quest look) as the material override, and
set the `idle` animation to loop in the import settings. They face -Z.

## Rebuilding

Coats are palettes in `build_farm.py` (`COW_COATS`, `SHEEP_COATS`,
`CHICKEN_COATS`). Add an entry and run:

```
python farm/build_farm.py <name>
```
