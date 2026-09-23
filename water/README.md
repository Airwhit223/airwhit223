# Toon water (Godot 4.7)

Cartoon / anime-style water shader: stepped shallow-to-deep colors, crisp
white foam around shores and objects, drifting foam patches, glittering sun
specks, and gentle waves.

![preview](preview.png)

## Setup

1. Copy this `water/` folder into your project root (so the path is
   `res://water/`). If you put it elsewhere, fix the shader path inside
   `toon_water.tres`.
2. Add a `MeshInstance3D` with a `PlaneMesh`. Give it plenty of subdivisions
   (e.g. 100 x 100 on a 50 m plane) so the waves have vertices to move.
3. Drag `toon_water.tres` onto the mesh's material slot. For each body of
   water, right-click the material, choose **Make Unique**, and tune it.

Uses the Forward+ or Mobile renderer. It won't look right in Compatibility.

## Presets

| Setting              | Ocean          | River           | Pond           |
|----------------------|----------------|-----------------|----------------|
| `depth_distance`     | 6.0            | 1.5             | 1.0            |
| `color_bands`        | 3              | 2               | 2              |
| `wave_height`        | 0.25           | 0.04            | 0.02           |
| `wave_length`        | 10.0           | 3.0             | 4.0            |
| `flow_speed`         | 0.02           | 0.25            | 0.005          |
| `flow_direction`     | any            | down the river  | any            |
| `surface_foam_cutoff`| 0.72           | 0.62 (streaky)  | 0.85 (calm)    |
| `foam_width`         | 0.45           | 0.25            | 0.2            |

For rivers, rotate `flow_direction` to match each stretch of river, or split
the river into a few meshes with their own material.

## Multiplayer

The waves are purely visual, so by default each player uses their own clock.
Waves won't line up exactly between players, which nobody will notice. If you
later add boats or anything that bobs on the waves, feed the same clock to
everyone by setting the `synced_time` shader parameter each frame from a
server-synced time value, and use the same `wave()` math in GDScript for the
bobbing.
