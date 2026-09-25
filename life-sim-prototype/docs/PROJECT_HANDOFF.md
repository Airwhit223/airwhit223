# PROJECT HANDOFF — COMPLETE TECHNICAL + VISUAL SUMMARY FOR ANOTHER AI AGENT

**Document Path:** `res://docs/PROJECT_HANDOFF.md`  
**Target Audience:** Codex / Secondary AI Agents / Human Developers  
**Authoring Agent:** AntiGravity (Gemini 3.7 Flash)  
**Date:** September 18, 2026  
**Status:** Canonical Reference & Knowledge Transfer Document  

---

## 1. PROJECT IDENTITY

### Core Concept & Player Experience
This project is an **open-world life simulation / RPG adventure** built in Godot 4.7+ (Forward+ renderer). It is set several years after the events of **Rolling Tides**, in the aftermath of the weakening/opening of the Dream Realm barrier. In this world:
- The modern everyday world (suburban streets, corner minimarts, basketball courts, skate culture, apartments) now coexists with ancient mystical and cultural layers returning to the physical surface.
- The player is a young adult moving out into an independent life (a distant family relative connected to the Rolling Tides hero's lineage through grandparents/Uncle Jones, but **not** the Rolling Tides protagonist themselves).
- **Two Parallel Gameplay Loops:**
  1. **Ordinary Life-Sim:** Daily routine, living schedules, farming, community calendar events, basketball, hanging out with rivals/neighbors, decorating, cooking, buying clothes, listening to local gossip, relationship building.
  2. **Adventure & Discovery:** Investigating Dream bleed cracks in the neighborhood, venturing into the Overgrowth, exploring resurfaced ruins, plumbing ancient Egyptian-style underground cities, confronting ancient sealed entities (e.g., the *Loss / Remorse* spirit), and reaching cosmic origins.
- The player is **never forced** to abandon the life-sim to engage in RPG content. Both spheres feed into one another: crops and neighborhood connections supply gear, potions, and faction favor; adventure rewards provide rare decorative relics, ancient textiles, and story progression.

---

## 2. VISUAL DIRECTION

### Target Aesthetic: Stylized 3D Cel-Shaded JRPG
The visual target is an **illustrated 3D JRPG aesthetic inspired by late-PS2 / early-HD adventure games (specifically Dragon Quest VIII, Dragon Quest XI, and Akira Toriyama's character design language)**, executed with modern real-time rendering techniques.

### Mandatory Visual DNA:
1. **Ink Outlines:** Inverted-hull mesh duplication (`cull_front`) with consistent, deliberate line weight. Outlines must scale with depth or maintain silhouette readability without turning into noisy black wireframes.
2. **Two-Tone Cel Shading:** Clean, hard-edged shading (a lit tone and a single shadow tone per surface). Avoid soft gradients, micro-surface PBR glossiness, or muddy ambient occlusion maps.
3. **Chunky Sculptural Masses:** Hair, fur, foliage, and cloth folds are modeled as volumetric locks and solid geometric shapes, never millions of fine strands or alpha hair cards.
4. **Toriyama Facial Construction:** Expressive, clean eyes with distinct pupils/highlights; clear, grounded nose bridges and mouth lines; readable silhouettes; warm, appealing, approachable personalities even on tough or monstrous characters.
5. **Grounded Everyday Coexistence:** Contemporary casual streetwear (hoodies, baggy jeans, sneakers, skateboards, snapbacks) naturally coexisting with returning ancient stone, mystical flora, and regional traditional attire.

### What Must Be Strictly Avoided:
- ❌ **Photorealism / PBR textures:** No realistic photogrammetry, high-frequency normal maps, or metallic roughness maps that clash with toon shading.
- ❌ **Generic Asset-Store Quality:** No stock low-poly asset-pack look with mismatched flat shading and uncurated palettes.
- ❌ **Generic Western Fantasy / MMO Look:** No oversized pauldron armor, glowing high-fantasy neon swords, or generic World of Warcraft geometry.
- ❌ **Pixar / Disney / Mobile Look:** No round, rubbery, plastic-smooth featureless faces. Proportions are moderately stylized anime/JRPG (~6.5 to 7 heads tall), not chibi and not doll-like.
- ❌ **Giant Saucer Eyes:** Eyes are expressive and anime-influenced, but grounded in structural anatomy.

### Visual Target References
Approved concept target images generated during design sessions (located in the agent's brain artifact storage at `/Users/whitlow/.gemini/antigravity/brain/50ec1919-0128-4632-aca9-4434cce7777f/`):
- `four_zones_dq_style_1789686188351.jpg`: Master 4-zone concept showing Neighborhood, Old Shore, Overgrowth, and Undercity in cohesive DQ style.
- `gameplay_neighborhood_1789686338260.jpg`: Third-person gameplay camera view of the neighborhood street at golden hour with UI minimap and stamina bars.
- `gameplay_undercity_1789686363823.jpg`: Streetwear protagonist standing before ancient Egyptian columns and a sealed door (the gold standard of visual contrast).
- `human_toriyama_v2_1789725932398.jpg`: Master Toriyama human race reference sheet with body diversity.
- `beastfolk_spectrum_1789725950944.jpg`: Master Beastfolk spectrum from human-hybrid to full-beast head.
- `dragonfolk_v2_hybrid_1789726213391.jpg`: Master Dragonfolk spectrum featuring devil-horn/wing human hybrids to full dragon heads.
- `aquatic_toriyama_v2_1789725961710.jpg`: Master Aquatic folk reference sheet.
- `starter_street_design.md`: Environment design specification for the first playable street.

---

## 3. CHARACTER SYSTEM

### Architecture & Pipeline Overview
The character system lives under `character/` and `character/toriyama_kit/`:
- **Core Scripts:**
  - `character/toriyama/toriyama_character.gd`: Main controller for assembled Toriyama models. Handles animations, bone anchors (`head_anchor()`, `waist_anchor()`), and secondary physics.
  - `character/toriyama_kit/kit_character.gd`: Modular character assembler. Adopts meshes from separate GLBs onto a shared skeleton, configures shape keys, attaches clothing/hair, and enforces restorative rest poses.
  - `character/toriyama/secondary_motion.gd`: Real-time spring physics for hair, clothing, and tails trailing body velocity.
  - `character/toriyama/retro_ps2.gd` & `retro_ps2_screen.gdshader`: Full-screen optional post-processing emulation for PS2 CRT/color depth.
  - Shaders: `character/toriyama/toriyama_paint.gdshader` (cel/toon lit pass) and `character/toriyama/toriyama_ink.gdshader` (outline pass).

### Crucial Implementation Fixes (Do NOT Overwrite):
1. **Part Removal & Swapping (`kit_character.gd`):** When parts are attached, `_adopt()` moves meshes off the GLB root onto the shared skeleton. `_part_roots[key]` is stored as `{root, meshes, attachments}` and removed cleanly via `_remove_part(key)` and `_dress(..., part_key)`. Never replace this with simple root-freeing, or swapped hair/garments will stack infinitely.
2. **`Pose_Rest` Blend Shape:** Must be held at `1.0` after assembly and after every garment addition to enforce correct arm rest posture.
3. **Secondary Motion Tails Profile:** `secondary_motion.gd` contains `"hair"`, `"cloth"`, and `"tail"` profiles. The `"tail"` profile features a softer spring, longer dampening, and custom `range_m` overrides.
4. **Shader Symmetry:** Both `toriyama_paint.gdshader` and `toriyama_ink.gdshader` **must** execute identical `sway_*` vertex displacement math in `vertex()`. If the ink shader is not updated identically to paint, outlines detach and float off swaying hair and tails.
5. **Unconditional `POSITION` Write:** `vertex()` in both shaders must write `POSITION` outside of any conditional branch, or the mesh will fail to render on some platforms, leaving only floating black ink silhouettes.

---

## 4. PLAYABLE RACES & ANCESTRAL SPECTRUM

### Universal DNA Established by Humans
All races inherit the base Toriyama linework weight, two-tone shadow response, eye construction language, and socket rigging. They are not disconnected creature designs; they are co-inhabitants of this world.

### The Race Order:
1. **01 Human:** Baseline DNA. Broad range of skin tones, curly/coily/wavy/straight hair masses, athletic/curvy/muscular/slim builds.
2. **02 Dwarf:** Grounded, compact, broad-shouldered master crafters. Modern attire + heavy work aprons, durable boots, mechanical goggles.
3. **03 Elf:** Tall, elegant, refined features, pointed ears, flowing silhouettes. Modern chic + traditional woven accents.
4. **04 Wolf Beastfolk:** Canine lineage.
5. **05 Feline Beastfolk:** Feline lineage.
6. **06 Aquatic Folk:** Shark, fish, manta, octopus, eel lineages. Smooth skin, webbed digits, fin-ears, bioluminescent patterns.
7. **07 Scaled / Horned Race:** Desert lizards, chameleons, geckos.
8. **08 Dragonfolk:** Regal horns, crests, slit pupils, vestigial wings, tails, fine scales.

### The Ancestral Expression Spectrum
Beastfolk, Dragonfolk, and Aquatic races utilize an ancestral physical-expression slider:
```
MOST HUMANOID (Low) <------------------------> FULL BEAST/CREATURE (High)
Human face + animal ears/tail/small horns     Full animal/reptilian/aquatic head
Street-passing hybrid                        Beast snout, heavy fur/scales, claws
```
*Crucial Rule:* This spectrum represents **only physical lineage expression**, NOT intelligence, social standing, faction alignment, or moral character. A full-head wolf beastfolk can be an accountant at the town bank; a human-passing cat-hybrid can be a brawler.

**Full Beast Transformation:** All Beastfolk also retain an innate full-beast transformation power tied to their stamina/adventure progression.

---

## 5. WORLD & ENVIRONMENT: REALITY VS. PLACEHOLDERS

### Current Repository Reality:
The existing primary scene at `res://scenes/main.tscn` contains:
- **Terrain:** Flat green ground plane (`MeshInstance3D`) with standard default lighting. **(PLACEHOLDER - GREYBOX)**
- **Structures:** Simple box/mesh buildings representing houses, basketball court pad, concert stage pad. **(PLACEHOLDER - GREYBOX)**
- **NPCs:** Primitive humanoid test rigs with colored capsules/cylinders and floating 3D text status labels. **(TEMPORARY TEST RIGS - being superseded by Toriyama models in `character/toriyama/`)**

### Approved Target Environment Design:
See `res://docs/starter_street_design.md` for the approved spec of the first real playable environment:
- **Footprint:** A 35m × 25m gentle curving dirt-to-cobblestone street.
- **Key Buildings:**
  1. **Player/Neighbor House:** Two-story wood-plank siding, asymmetrical shingled roof, front porch with steps, garden plot.
  2. **General Store:** Wooden storefront, 3-stripe canvas awning, propped door, sidewalk crates and barrels.
- **Props:** Vintage street lamp, notice board, wooden bench, bike rack with bicycle, fire hydrant, mailbox.
- **Vegetation:** One large shade tree (green canopy disc), one blossoming cherry tree (pink accents), scattered grass tufts along curb edges.
- **Materials:** Strict 7-color palette (`#C4956A` warm wood, `#7A6B5D` roof shingle, `#D4B896` road dirt, `#B8A88C` cobblestone, `#7DB84A` grass green, awning accents, `#6B7B8D` metal).

---

## 6. GAMEPLAY SYSTEMS STATUS

| System | Script / Path | Status | Notes |
|---|---|---|---|
| **Time & Seasons** | `autoload/time_manager.gd` | **Working** | Day/hour ticks, time multiplier (1x, 4x, 15x), seasonal tracking. |
| **World State** | `autoload/world_state.gd` | **Working** | Tracks open/closed status, stores, player ownership. |
| **Relationships** | `autoload/relationship_manager.gd` | **Working** | Friendship/rivalry meters, interaction history. |
| **Community Events**| `autoload/community_event_manager.gd`| **Working** | Scheduled weekend concerts, cookouts, calendars. |
| **Farming** | `autoload/farming_manager.gd`, `farming/` | **Working** | Tilling, planting, watering, growth stages. |
| **Player Movement**| `player/player.gd` | **Working** | 3D locomotion, sprint, jump, interaction raycasts. |
| **NPC AI / Brain** | `npc/npc_brain.gd` | **Working** | Routine scheduler, travel states, sleep/work/hangout behaviors. |
| **Basketball** | `scenes/basketball.tscn` | **Prototype** | Shoot, score, ball physics on court pad. |
| **Skateboarding** | `player/` | **Prototype** | Board mount/dismount and cruising physics. |
| **Modular Outfits** | `character/toriyama_kit/kit_character.gd` | **Working** | Dynamic part attachment and rest pose enforcement. |
| **RPG / Combat** | `rpg/`, `autoload/adventure_manager.gd` | **Partially Working** | Free-play combat prototype, stats in `PlayerStats`. |
| **Audio** | `autoload/audio_manager.gd` | **Working** | Sound effect triggers and BGM bus control. |
| **Environment Art**| `scenes/main.tscn` | **Greybox / Temporary** | Geometry needs replacement with stylized modular assets. |

---

## 7. GODOT ENGINE ARCHITECTURE

- **Godot Version:** 4.7+ (Forward+ Desktop Renderer)
- **Resolution Base:** 1280 × 720 (configured in `project.godot`), scaling to window viewport.
- **Autoload Dependencies:**
  - `TimeManager` drives `CommunityEventManager`, `FarmingManager`, and `npc_brain.gd` schedule ticks.
  - `EventBus` broadcasts global player actions (`player_interacted`, `item_equipped`, `time_tick`).
  - `RetroPS2` toggles screen-space retro emulation on the camera viewport.
  - `TraitSystem` holds player identity traits passed into character creator recipes.
- **Character Attachment Tree:**
  ```
  KitCharacter (Node3D)
  └── Armature / GeneralSkeleton (Skeleton3D)
      ├── Base_Body (MeshInstance3D)
      ├── Head_Base (MeshInstance3D)
      ├── Hair_* (MeshInstance3D)
      ├── Garment_* (MeshInstance3D)
      └── BoneAttachment3D (Skins, Sockets, Accessories)
  ```

---

## 8. ASSET PIPELINE & SOURCING

1. **Toriyama Blender Kit:** Sourced from internal Blender pipelines (Milestones 10–13, `tr_build.py`, `tr_body_shapes.py`, `tr_beard.py`). Meshes export to `.glb` with standardized bone hierarchies and blend shapes (`Pose_Rest`, `Def_*`, facial shapes).
2. **Procedural Rigs:** `character/character_rig.gd` is an older procedural capsule rig used for early physics and NPC testing. It is being phased out in favor of `character/toriyama_kit/kit_character.gd`.
3. **Prop Assets:** Must be built or imported as modular `.tscn` instances using the 7-color palette and `toriyama_paint.gdshader` / `toriyama_ink.gdshader`. Never import textured PBR photorealistic assets directly without passing them through the toon material pipeline.

---

## 9. LORE THAT AFFECTS DEVELOPMENT

1. **Post-Rolling Tides Era:** Rolling Tides was a coastal farm/life RPG. In this sequel, several years have elapsed. The "Hallowed Moon" and Dream Realm barriers have fragmented.
2. **Mystical Resurfacing:** Forgotten ancient history is literally pushing up through the earth. A modern skater kid might walk past a storm drain that opens into an ancient Egyptian subterranean palace.
3. **Grandpa Jones' Heritage:** Grandpa's tall tales from the original game were literal truth. The player possesses ancient non-human/mystical lineage that explains their ability to adapt to Dream magic.
4. **The Four Villains & The Loss:** Four local orphan rivals embody different corrupted motivations (Power, Fear, Greed, Envy/Deceit), while an ancient entity known as *Loss / Remorse* resides in the deepest undercity chambers.
5. **Cosmic Convergence:** The deep cosmology connects through ancient portals to cosmic origin worlds (two suns, crystalline formations, floating landmasses).

---

## 10. CRITICAL "DO NOT BREAK" LIST

1. **DO NOT overwrite `kit_character.gd`'s `_part_roots` dictionary architecture.** Simple root-freeing reintroduces the hair/clothing infinite stacking bug.
2. **DO NOT delete or bypass `_set_shape("Pose_Rest", 1.0)`.** Disabling this will cause characters' arms to pop into a T-pose or break garment fitting.
3. **DO NOT modify `toriyama_paint.gdshader` without making the identical vertex sway updates to `toriyama_ink.gdshader`.** Outline detachment will ruin the visual aesthetic.
4. **DO NOT replace the modular socket system with baked monolithic single-mesh characters.** Player customization, fashion purchasing, and race hybridization rely on interchangeable pieces.
5. **DO NOT remove working autoloads** (`TimeManager`, `EventBus`, `FarmingManager`, `CommunityEventManager`) when refactoring scenes.

---

## 11. CURRENT PROBLEMS & CANDID ASSESSMENT

### Visual Deficiencies:
- **Main Scene is a Greybox:** `scenes/main.tscn` uses a flat green plane, grey box buildings, and primitive capsule NPCs. It looks nothing like the approved concept art.
- **Lighting is Flat:** Default DirectionalLight3D lacks the warm golden-hour tones, ambient blue shadow fill, and painted skybox defined in the design spec.
- **NPC Representation:** NPCs still spawn on older primitive rigs rather than the new Toriyama kit meshes.

### Technical & Fragile Areas:
- **Garment Clipping:** Loose clothing models can clip on extreme body type blend slider settings (`TR_Belly`, high `TR_Definition`).
- **Input Management:** Interaction raycasts occasionally target collision shapes of background props instead of foreground NPCs if collision layers are not strictly separated.

---

## 12. RECOMMENDED NEXT MILESTONES

1. **Milestone 1: Starter Street Scene Assembly**
   - Build a clean `res://scenes/starter_street.tscn` adhering strictly to `res://docs/starter_street_design.md`.
   - Place modular house, general store, dirt/cobble road, trees, fence, and street props.
   - Configure golden-hour DirectionalLight3D and toon environment.
2. **Milestone 2: NPC Toriyama Rig Integration**
   - Transition the 5 neighborhood NPCs (Maya, Jordan, Alex, Riley, Sam) from test rigs to `kit_character.gd` instances with unique hair/clothing presets.
3. **Milestone 3: In-Game Clothing Shop Prototype**
   - Connect the General Store interaction to a clothing buy/equip menu that swaps garments using `kit_character.gd`'s `set_garment()`.
4. **Milestone 4: Beastfolk & Dragonfolk Mesh Integration**
   - Import the first hybrid and full-head beastfolk meshes into `character/toriyama_kit/` and register them with the creator data.

---

## 13. AGENT HANDOFF INSTRUCTIONS (FOR CODEX)

> **To Codex / Succeeding AI:**
>
> 1. **Do not assume existing code or placeholder art is final.** The grey boxes in `main.tscn` are temporary scaffolding. The true visual targets are the approved concepts and specs documented in `docs/starter_street_design.md`, `docs/new_regions_design.md`, and `docs/clothing_system_design.md`.
> 2. **Read before writing.** Before touching `kit_character.gd`, `secondary_motion.gd`, or the shaders, read the code currently on disk. Many subtle bugfixes are live that must not be reverted.
> 3. **Preserve the visual language.** If you build environment meshes or character parts, enforce cel shading, two-tone colors, and ink outlines. Do not add generic PBR materials.
> 4. **Respect the dual-nature design.** This is a cozy life-sim with adventure layers. Never rip out farming, schedules, or basketball in favor of a pure dungeon crawler, and never lock the player out of life-sim activities.
