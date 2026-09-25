# Starter Street — Environment Design Spec

The first playable street for the life-sim prototype. One house, one shop, a road, and enough life to make it feel like a place someone actually lives.

## Visual Target

````carousel
![Overhead layout — house, shop, road curve, prop placement](/Users/whitlow/.gemini/antigravity/brain/50ec1919-0128-4632-aca9-4434cce7777f/street_overview.jpg)
<!-- slide -->
![Player-view gameplay angle — walking the street at golden hour](/Users/whitlow/.gemini/antigravity/brain/50ec1919-0128-4632-aca9-4434cce7777f/street_player.jpg)
````

---

## Layout — Top Down

```
                    N
                    ↑
     ┌──────────────────────────────┐
     │          grass / edge        │
     │   ┌─────────┐               │
     │   │  HOUSE   │    🌳 shade  │
     │   │ (porch →)│     tree     │
     │   └────┬─────┘              │
     │   yard │fence    mailbox    │
     │  garden│         ┌─┐        │
     │   ═════╧═══╤═════╧═╧═══    │
     │        dirt │  cobble        │
     │    ════════╤╧═══════════    │
     │            │  bench         │
     │   bike ──┐ │  ┌──────────┐  │
     │   rack   │ │  │   SHOP   │  │
     │   notice─┤ │  │(awning →)│  │
     │   board  │ │  │ crates   │  │
     │          │ │  └──────────┘  │
     │     🌸  lamp  hydrant      │
     │  blossom  │                 │
     │   tree    │    grass        │
     └──────────────────────────────┘

     Road: ~20m long, ~6m wide
     Total playable area: ~35m × 25m
```

The road **curves gently** — not a straight grid. It enters from the west as packed dirt and transitions to worn cobblestone as it passes the shop. This isn't a highway; it's a neighborhood street where people walk in the road.

---

## Material Palette — 7 Colors

Every surface in this scene draws from this limited palette. Materials use **flat base color + one cel-shadow tone** (no PBR roughness/metallic). Bold dark outlines on all geometry edges.

| Material | Base Color | Shadow Tone | Where Used |
|---|---|---|---|
| **Warm Wood** | `#C4956A` | `#8B6842` | House siding, porch, fence posts, shop frame, crates, bench, notice board |
| **Roof Shingle** | `#7A6B5D` | `#5A4E43` | House roof, shop roof edge |
| **Road Dirt** | `#D4B896` | `#A8906E` | Packed dirt road surface, yard paths |
| **Cobblestone** | `#B8A88C` | `#8C7E68` | Road near shop, curb stones |
| **Living Green** | `#7DB84A` | `#5A8A32` | Grass, bushes, garden plants, tree leaves |
| **Awning Stripe** | `#E85D3A` / `#F4E04D` / `#4AA87D` | darkened 30% | Shop awning (3-stripe pattern) |
| **Metal Accent** | `#6B7B8D` | `#4A5663` | Lamp post, hydrant, mailbox, bike rack, trash can |

> [!TIP]
> The key to the DQ look: **each material gets exactly TWO tones** — a lit side and a shadow side, hard-cut, no gradient. The outline does the rest. Resist adding specular, normal maps, or texture detail. The style's readability comes from simplicity.

---

## Buildings

### The House

A **two-story wooden house** with character. Not a mansion, not a shack — a comfortable home someone actually lives in.

| Element | Detail |
|---|---|
| **Footprint** | ~6m × 5m |
| **Height** | ~6m to roof peak |
| **Walls** | Horizontal wood plank siding, Warm Wood palette. Slightly rounded corners (this is stylized, not architectural) |
| **Roof** | Asymmetric gable, Roof Shingle palette. Slight overhang with visible rafter ends. One chimney (decorative for now) |
| **Porch** | 1.5m deep, runs full front width. 3 wooden steps down to yard. Railing with simple vertical posts |
| **Windows** | 2 downstairs (flanking the door), 2 upstairs. Painted shutters in a muted teal `#5D8A7A`. Warm yellow interior glow cards behind glass |
| **Front Door** | Slightly oversized (JRPG proportions). Darker wood `#6B4E36`. This is the interact/teleport point |
| **Porch Props** | One chair, one small side table, a pair of shoes by the door, a potted plant on the railing |

### The Shop

A **small general store** — friendly, cluttered, clearly open for business.

| Element | Detail |
|---|---|
| **Footprint** | ~5m × 4m |
| **Height** | ~4.5m (single story with high ceiling) |
| **Walls** | Same Warm Wood, but with a painted front face in a warmer cream `#F0E6D0` |
| **Awning** | Extends 1.5m from the storefront. Striped canvas (red/yellow/green), slightly sagging in the middle for personality |
| **Sign** | Hand-painted wood sign mounted above the awning. Text reads the shop name. Slightly crooked on purpose |
| **Door** | Wide, propped open during business hours (a wedge-shaped door stop visible). Warm light spilling out |
| **Shop-front props** | 2 wooden crates (stacked), 1 barrel, a small chalkboard sandwich sign, potted flowers flanking the entrance |
| **Bench** | Wooden, beside the shop entrance. NPC sit-spot |

---

## Props — Full List

Every prop should be a **separate reusable scene** (`.tscn`). Build once, place many.

### Road & Infrastructure
| Prop | Mesh Shape | Size | Notes |
|---|---|---|---|
| **Street lamp** | Cylinder post + sphere lamp top | 3m tall | Warm point light at night. Place at the road curve |
| **Fire hydrant** | Rounded cylinder + nubs | 0.6m tall | Metal Accent palette. Near the shop side |
| **Trash can** | Cylinder with lid | 0.8m tall | Metal Accent. Near the house fence corner |
| **Mailbox** | Box on a post | 1.2m tall | At the fence gate, facing the road |

### Community
| Prop | Mesh Shape | Size | Notes |
|---|---|---|---|
| **Notice board** | Flat rectangle on two posts | 1.5m tall | Warm Wood. Pinned paper cards on the face (flat colored rectangles). Place between house and shop |
| **Bench** | Plank seat + backrest on legs | 1.5m wide | Beside the shop door. NPC sit-action target |
| **Bike rack** | Low metal frame | 0.8m wide | Metal Accent. One bicycle leaning in it (bicycle is its own scene) |
| **Bicycle** | Simple frame + wheels | 1m long | Parked in the rack. Future rideable |

### Yard & Garden
| Prop | Mesh Shape | Size | Notes |
|---|---|---|---|
| **Fence section** | Vertical posts + horizontal rails | 1m tall, 2m wide | Warm Wood. Repeatable. ~10 sections to enclose the yard |
| **Fence gate** | Same as fence but with hinges | 1m wide | Marks the yard entrance from the road |
| **Garden plot** | Flat raised dirt rectangle | 2m × 1.5m | Farmable area. Reuses existing `farming/` system |
| **Potted plant** | Small pot + bush shape | 0.4m | Terracotta pot `#C4704A` with Living Green foliage |
| **Porch chair** | Simple wooden seat | 0.5m wide | Sit-action target. "Sit and think" location |

### Vegetation
| Prop | Mesh Shape | Size | Notes |
|---|---|---|---|
| **Shade tree** | Thick trunk + large rounded canopy | 5m tall | The bigger tree. Near the house. Casts a noticeable shadow disc |
| **Blossom tree** | Thinner trunk + smaller canopy with pink accent | 3.5m tall | Near the shop. Pink blossom color `#F0A0B0` mixed into the green |
| **Bush (small)** | Rounded blob | 0.6m | Living Green. Scatter 3–4 along fence and building foundations |
| **Grass tufts** | Flat billboard quads | 0.15m | Clusters along road edges, fence bases, cobble cracks. MultiMesh these |

---

## Placement Rules

These aren't arbitrary — they're what makes the scene read as *inhabited* rather than *decorated*.

1. **Props cluster near doors.** The shop entrance has crates + flowers + bench + chalkboard sign. The house porch has chair + table + shoes + plant. Life gathers at thresholds.

2. **The road has weight.** It's not a flat plane — it's slightly crowned (2–3cm higher in the center) so it reads as a surface that gets walked on. Grass tufts grow at the edges where feet don't reach.

3. **Nothing is perfectly aligned.** The fence posts aren't exactly evenly spaced. The bench is slightly angled. The shop sign is a degree off-level. The bike leans. This is the difference between a game environment and a diorama.

4. **Shadow anchors everything.** Every object gets a small dark disc or blob shadow underneath it (even if dynamic shadows are off). Without this, props float.

5. **NPC space is planned.** Leave a 2m radius clear in front of the shop door, a 2m radius around the bench, and a 1.5m clear path along the entire road. NPCs need room to walk, stop, and perform actions without clipping into things.

6. **The garden faces the road.** The player should see it while walking past. It's an invitation, not a hidden feature.

---

## Godot 4 Implementation Notes

### Toon Shader (the DQ look)

The core visual identity comes from **one reusable toon shader** applied to every mesh:

```
shader_type spatial;
render_mode unshaded;

uniform vec4 base_color : source_color;
uniform vec4 shadow_color : source_color;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float NdotL = dot(NORMAL, normalize(vec3(0.4, 0.8, 0.3)));
    float cel = step(shadow_threshold, NdotL * 0.5 + 0.5);
    ALBEDO = mix(shadow_color.rgb, base_color.rgb, cel).rgb;
}
```

Apply this as a `ShaderMaterial` on every mesh. Set `base_color` and `shadow_color` from the palette table. The `shadow_threshold` at 0.5 gives a clean hard cut.

### Outlines

Use the inverted-hull method (which you already built in milestone 10):
- Duplicate the mesh
- Flip normals
- Push vertices out along normals by 0.02–0.03
- Flat black material, `render_mode cull_front`

### Scene Structure

```
StreetScene (Node3D)
├── Environment
│   ├── Ground (MeshInstance3D — road + grass as one mesh or GridMap)
│   ├── House (PackedScene)
│   ├── Shop (PackedScene)
│   ├── ShadeTree (PackedScene)
│   ├── BlossomTree (PackedScene)
│   └── FenceSections (Node3D — repeated fence scenes)
├── Props (Node3D)
│   ├── StreetLamp
│   ├── NoticeBoard
│   ├── Bench
│   ├── BikeRack
│   ├── Bicycle
│   ├── Mailbox
│   ├── FireHydrant
│   ├── TrashCan
│   ├── GardenPlot
│   └── PottedPlants...
├── NPCSpawns (Node3D — markers for NPC positions)
│   ├── ShopWorkSpot (Marker3D)
│   ├── BenchSitSpot (Marker3D)
│   ├── PorchSitSpot (Marker3D)
│   └── RoadWalkPath (Path3D)
├── Lighting
│   ├── Sun (DirectionalLight3D)
│   └── StreetLampLight (OmniLight3D — warm, shadowless)
└── GrassTufts (MultiMeshInstance3D)
```

### What Plugs Into Existing Systems

| Existing System | How This Street Uses It |
|---|---|
| `interactables/teleporter.gd` | House door + Shop door → interiors |
| `npc/npc_brain.gd` | ShopWorkSpot = work location, BenchSitSpot = hangout, PorchSitSpot = rest |
| `farming/` | GardenPlot reuses the crop plot system directly |
| `autoload/world_state.gd` | Register shop as a workplace, house as player home |
| `equipment/character_equipment.gd` | No changes — characters already render clothing via sockets |
| `autoload/time_manager.gd` | Street lamp toggles on at dusk, shop door closes at night |

---

## Lighting & Atmosphere

### Golden Hour (Default / First Impression)

- **Sun direction:** 30° above horizon, coming from the west (warm side-light)
- **Sun color:** `#FFE0B0` — warm amber
- **Ambient:** `#8090B0` — cool blue-grey at 0.3 intensity (fills shadows without flattening)
- **Sky:** Gradient from `#FFD080` at horizon to `#6090C0` overhead
- **Street lamp:** Off during day. `#FFD070` warm omni at night, 4m range, no shadow

### Night

- **Sun off.** Ambient drops to `#202840` at 0.15.
- **Street lamp on.** Creates one warm pool of light on the road curve.
- **House windows:** Interior glow cards brighten. Someone's home.
- **Shop:** Awning lamp (small omni) on if shop is open. Dark if closed.

> [!IMPORTANT]
> The scene should feel **noticeably different** between day and night with just these two states. Don't over-engineer the lighting — two presets (golden hour + night) are enough to prove the mood works. Morning, overcast, rain, etc. come later.
