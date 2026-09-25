# World Map & Town Layout Specification

**Document Path:** `res://docs/WORLD_MAP_AND_TOWN_LAYOUT.md`  
**Status:** Approved Master Layout Architecture  
**Context:** Expands the original *Rolling Tides* world map several years later, incorporating the player's new independent neighborhood, the Local Skateshop, and the new external regions.

---

## 1. THE MACRO REGIONAL WORLD MAP

The world connects outward from the player's new home base in the modern neighborhood:

```
                          [ COSMIC ORIGIN NEXUS ]
                                     ▲
                           (Deepest Rift Portal)
                                     │
                         [ SUBTERRANEAN UNDERCITY ]
                                     ▲
                            (Pyramid Catacombs)
                                     │
                     [ RESURFACED KINGDOM OF KHEM ]
                     (Pyramids, Sand Villages, Dunes)
                                     ▲
                           (The Geological Scar)
                                     │
  [ THE OVERGROWTH ] ◄───────────────┴───────────────► [ THE OLD SHORE ]
 (Dream-Infused Forest &                              (Rolling Tides Docks,
   Highland Ruins)                                    Boardwalk, Grandpa's Farm)
          ▲                                                    ▲
          │                                                    │
          └──────────────────┬─────────────────────────────────┘
                             │
                  [ THE NEIGHBORHOOD ]
            (Player House, Skateshop, Court,
              Community Stage, Suburb Loop)
```

### Regional Connections & Exits:
1. **South Exit $\rightarrow$ The Old Shore:** A winding coastal road leading down to the original *Rolling Tides* seaside village and boardwalk. Grandpa's heritage, old friends, ocean fishing, and coastal shops.
2. **North Exit $\rightarrow$ The Overgrowth:** The road ascends into Carpenter Forest and the ancient highlands, now mutated by Dream energy into colossal glowing trees, wild vines, and hidden gothic ruins.
3. **East Exit $\rightarrow$ The Geological Scar & Resurfaced Desert:** Cracked modern asphalt and broken guardrails where millions of tons of golden desert sand have ruptured to the surface, leading directly into the *Kingdom of Khem* (Pyramids, Dune-Surfing, Nefertari's Court).
4. **Deep Subterranean / Portals:** Descending through the central pyramid leads to the *Underground City* and ultimately the cosmic portal to the *Twin-Sun Origin World*.

---

## 2. THE STARTER NEIGHBORHOOD BLOCK (DETAILED LAYOUT)

The player's neighborhood is not an abstract endless grid. It is an authored, cozy residential street designed for both **life-sim routine** and **skateboarding flow**.

```
                        NORTH: Trail to Overgrowth
                                   ↑
   ┌──────────────────────────────────────────────────────────────┐
   │                                                              │
   │   ┌──────────────────┐               ┌──────────────────┐    │
   │   │  PLAYER'S HOUSE  │               │ LOCAL SKATESHOP  │    │
   │   │ (Porch + Steps)  │               │ (Decks, Awning,  │    │
   │   └────────┬─────────┘               │  Grind Bench)    │    │
   │            │                         └────────┬─────────┘    │
   │      [Home Garden]                            │              │
   │      (Turnip Plots)                   [Display Decks]        │
   │      ══════╧══════════════════════════════════╧════════      │
   │           ░░░░░░ CURVING STREET / ASPHALT ░░░░░░             │
   │      ══════╤══════════════════════════════════╤════════      │
   │            │                                  │              │
   │   ┌────────┴─────────┐               ┌────────┴─────────┐    │
   │   │ BASKETBALL COURT │               │ COMMUNITY STAGE  │    │
   │   │ & SKATE SPOT     │               │ & COOKOUT LAWN   │    │
   │   │ (Hoop, Rail,     │               │ (Weekend Concert,│    │
   │   │  Quarter-Pipe)   │               │  Picnic Tables)  │    │
   │   └──────────────────┘               └──────────────────┘    │
   │                                                              │
   └──────────────────────────────────────────────────────────────┘
         ↓                                              ↓
   WEST: Resurfaced Desert Rift               SOUTH: To Old Shore
```

---

## 3. KEY NEIGHBORHOOD LANDMARKS

### 1. The Player’s House
* **Exterior:** Two-story clapboard wooden home with front porch steps, mailbox, and an attached fenced yard.
* **The Home Garden:** Directly beside the porch steps. 4–8 tilled garden plots (`[E] Plant Turnip / Water / Harvest`). Reuses the core farming autoloads.
* **Interior:** Teleport door into a cozy living room, bedroom with mirror (triggers in-world character customization and clothing swaps), and kitchen.

### 2. The Local Skateshop ("Grindline" / "Deck & Gear")
* **Exterior:** The wooden building with the striped canvas awning seen in the prototypes. 
* **Skate Props Outside:** 
  - Wall-mounted display deck racks showing rotating graphic decks.
  - A heavy steel-edged wooden bench that doubles as an NPC sit-spot and a skate grind-ledge.
  - A chalkboard sign announcing weekly skate deals and contest scores.
* **Interior / Shop Function:**
  - Buy custom **Decks** (street boards, longboards, and later desert dune-boards!).
  - Customize **Grip Tape, Wheels, Trucks**, and unlock skate tricks.
  - Buy **Streetwear:** Hoodies, snapbacks, skate sneakers, baggy denim, and track jackets.

### 3. The Basketball Court & Skate Spot
* **Surface:** Concrete pad with painted court lines and a chain-link fence.
* **Dual Function:**
  - **Basketball Mode:** Basketball hoop, interactive ball physics, score counter (`[E] Shoot`).
  - **Skate Park Mode:** Low grind rail along the court boundary, a wooden kick-ramp / quarter-pipe against the back fence, and smooth pavement for practicing kickflips and manual wheelies.

### 4. The Community Stage & Cookout Lawn
* **Surface:** Wooden stage platform surrounded by grass, string lights strung between wooden posts, and picnic tables.
* **Event Integration:** Automatically populates during weekend events managed by `CommunityEventManager`:
  - **Saturday 6:00 PM:** Live neighborhood indie band concert (guitar solo mini-game).
  - **Sunday 2:00 PM:** Community cookout (NPC social gathering, food buffs, relationship gossip).

---

## 4. SKATE-FLOW & TRAVERSAL PHILOSOPHY

To lean into the **toony skater-RPG identity**, the town layout is built with flow in mind:
1. **Continuous Curbs:** Curbs along the road have continuous low collision bevels so the player can grind curbs all the way from their house to the skateshop.
2. **Smooth Street Transitions:** Asphalt roads curve gently rather than turning at 90-degree robotic angles.
3. **Shortcuts & Gaps:** Small grassy alleys between fences allow the player to ollie over garden gates or slide under rail barriers to reach the basketball court faster.
4. **Cartoon Feedback:** Board contact kicks up cartoon ink-line dust puffs; big tricks trigger stylized popup score notifications (`Dune Drift x2`, `Ollie Clean!`).

---

## 5. STEP-BY-STEP REPLACEMENT PLAN FOR THE CURRENT PLACEHOLDER SCENE

To upgrade `res://scenes/main.tscn` from its current greybox/prototype state without breaking existing gameplay logic:

| Step | Task | What It Replaces |
|---|---|---|
| **Phase 1** | **Road & Curb Mesh:** Create a curved asphalt/cobblestone road mesh with curbs using the 7-color toon shader. | Flat green plane collision lines. |
| **Phase 2** | **Skateshop Dressing:** Add deck racks, skate rails, and signage to the wooden shop building. | Generic colored blocks. |
| **Phase 3** | **Court Integration:** Place the basketball court beside the road with an integrated skate grind-rail. | Free-floating basketball pad. |
| **Phase 4** | **Prop Clustering:** Place street lamps, fire hydrants, trash cans, and fence segments along the road. | Empty grass voids. |
| **Phase 5** | **Directional Lighting & Sky:** Lock in the warm golden-hour DirectionalLight and toon outlined clouds. | Default flat engine sky. |
