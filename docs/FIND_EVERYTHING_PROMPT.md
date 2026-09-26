# Prompt: where to find everything

Paste everything below the line into any Claude (Claude Code, Antigravity,
or a chat) that needs to find the art we made.

---

All the art for my Godot 4.7 life-sim game is in the GitHub repo
**Airwhit223/airwhit223**, branch **`claude/cloud-credits-explanation-hhe8y7`**
(not `main`, and not `local-project-snapshot`, which is an old unrelated snapshot).

Get it with:

```
git clone -b claude/cloud-credits-explanation-hhe8y7 https://github.com/Airwhit223/airwhit223.git
```

Read these first:
- `README.md`: catalog of every asset group with preview pictures
- `CLAUDE.md`: how the pipeline works, the conventions and how to change or add assets
- `docs/GODOT_IMPORT.md`: how to bring the models into Godot
- `docs/LOCAL_CLAUDE_PROMPT.md`: step-by-step prompt for importing into my game project

Where each thing is (every folder has its own `README.md` and preview images):

| What | Folder |
|------|--------|
| Toon water shader | `water/` |
| Husky and Maine Coon pets (8 coats) | `pets/` |
| Cows, sheep, chickens, horses (5 coats) | `farm/` |
| Hoodie guy, black hoodie guy, casual girl, Egyptian queens | `characters/` |
| Beastfolk customizable kit (12 species) + shark and wolf NPCs | `characters/` (`beastfolk_*.glb`, `npc_*.glb`) and `characters/beastfolk/` (Godot script and shader) |
| Egyptian warriors: Anubis, axe warrior, archer | `characters/` (`npc_anubis.glb`, ...) and `characters/egypt/` (notes) |
| Spear, axe, bow, quiver | `characters/weapons/` |
| Goblins, skeletons, nightmare bat, shadow entity | `monsters/` |
| Barn, hay, stalls, fences, chicken coop, farm tools, saddle | `props/farm/` |
| Appliances, furniture, bathroom, laundry, consoles, art supplies, cameras, sports and gym gear, decor | `props/house/` |
| Modular house kit: walls, doors, windows, floors, roof, stairs | `props/house_kit/` |
| Restaurant food, grill, fryer, booths, fun house | `props/restaurant/` |
| Meshy base bodies (inputs for the characters) | `bases/` |
| Rebuild everything / render previews | `tools/build_all.sh`, `tools/preview/render.sh` |

Key facts:
- Game models are the `.glb` files; the `.py` next to them is the Blender
  (`bpy`) script that generates them, and `.blend` files are working copies.
- Every model faces **+Z** in Godot, is in real meters, and has its origin
  at the bottom center (doors: hinge; wall items: back).
- Colors are vertex colors; use the toon `.tres` material in each folder as
  the material override for the cartoon outline look.
- Animated models: pets and farm animals have `idle`; monsters have `idle`,
  `walk`, `attack`; humanoid characters use Godot humanoid bone names for
  retargeting Mixamo animations.

Tell me what you found, and ask before changing or deleting anything.
