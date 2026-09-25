# House-building kit

Snap-together pieces for cartoony houses: lap-siding walls in three color
schemes, doors, windows with shutters, floors, a 30-degree shingle roof,
gables and stairs. Everything is on a **2 m grid with 3 m storeys**. Built
by `../build_house_kit.py`.

![houses](preview_houses.png)
![interior](preview_interior.png)

## Pieces

| File | Notes |
|------|-------|
| `wall_<scheme>` | 2 x 3 m wall, 0.2 m thick |
| `wall_half_<scheme>` | 1 m wide wall for odd lengths |
| `wall_door_<scheme>` | wall with a 1.1 x 2.2 m doorway and white trim |
| `wall_window_<scheme>` | wall with a 1.1 x 1.2 m window (sill at 0.9 m), glass, shutters |
| `gable_<scheme>_l`, `gable_<scheme>_r` | triangular infill under one roof cell, tall edge at local -X (`_l`) or +X (`_r`) |
| `corner_post` | white 0.3 m trim post for outside corners |
| `door_front` | red front door with a window; `door_interior` white panel door |
| `floor_wood`, `floor_tile`, `floor_carpet` | 2 x 2 m floor, top at 0.022 m |
| `roof_slope` | one 2 x 2 m cell of roof, rising 1.155 m |
| `roof_eave` | 0.5 m overhang with fascia and soffit |
| `roof_ridge` | cap for the peak |
| `stairs` | 1 m wide, climbs 3 m over 4 m, with a railing |

Schemes: `cream` (green shutters), `pink` (blue shutters), `blue` (white
shutters). Outside faces have siding and a stone footing; inside faces have
striped wallpaper, a chair rail and baseboards.

## How the pieces fit (Godot coordinates, y up)

Each wall runs along its local X from -1 to +1 with its outside toward local
-Z and its bottom at y = 0. Put wall centers on the grid lines between
cells:

- Front wall (outside toward -Z): rotation 0, e.g. at (x, 0, -2).
- Back wall: rotation 180 at (x, 0, +2).
- Left wall (outside toward -X): rotation 90 at (-2, 0, z).
- Right wall: rotation -90 at (+2, 0, z).
- `corner_post` at each outside corner, e.g. (-2, 0, -2).
- Floors at the cell centers, e.g. (-1, 0, -1).
- Doors: origin is the hinge. In a `wall_door` at (x, 0, z) with rotation r,
  put the door at the wall's local x = -0.53 with the same rotation, and
  rotate it negative (toward the inside) to open it.
- Upper storey: stack walls at y = 3.

Roof for a house 4 m deep with the ridge running along X at z = 0:

- `roof_slope` rotation 0 at (x, 3, -1) and rotation 180 at (x, 3, +1)
  (the low edge sits on the wall line, the high edge meets at the ridge).
- `roof_eave` rotation 0 at (x, 3, -2) and rotation 180 at (x, 3, +2).
- `roof_ridge` at (x, 4.155, 0).
- Gables on the side walls at y = 3: left wall (rotation 90) gets
  `gable_*_l` at z = -1 and `gable_*_r` at z = +1; right wall (rotation -90)
  gets `gable_*_r` at z = -1 and `gable_*_l` at z = +1.

For deeper houses chain more `roof_slope` cells up the slope: each cell
starts 1.155 m higher and 2 m further in.

Rugs and furniture go on top of the floor at y = 0.022.

## Materials

Use `toon_large.tres` as the material override. Colors are vertex colors.
Walls are thin boxes, so collision works well with **Create Trimesh Static
Body** or a box per wall.

## Rebuilding

```
python props/build_house_kit.py [name ...]
```

New color schemes are one line each in `SCHEMES`.
