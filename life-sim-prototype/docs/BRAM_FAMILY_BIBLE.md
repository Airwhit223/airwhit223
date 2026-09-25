# Bram's Family — Character Bible

**Source of truth:** the user's four sheets in `docs/references/bram_family/` (`bram_sheet`, `family_sheet`,
`grandpa_sheet`, `sergio_sheet`). Bram himself: see `BRAM_CHARACTER_BIBLE.md` (party role, power curve).
**In game:** `data/bram_family.gd` (NPC definitions + first-pass kit looks), spawned by `scenes/main.gd`
`_spawn_bram_family()`. Tests: `tests/bram_family_lineup.gd` (renders), `tests/bram_family_ingame.gd`.

## The family — "Same blood. Bigger adventures."

Big, warm, strong, and always feeding somebody. They run **The Good Place** — *Food · Rest · Repairs · Brighter
Journeys* — an inn in Olde Town (placed at the Olde Town tavern, `loc_good_place`). Shared traits: kind, loyal,
protective, feeds everybody, way stronger than they look, adventures together, always a place for you here.
Recurring gag: *"Everyone thought he was exaggerating. He wasn't."* — the player meeting the family and realising Bram
undersold them.

| Who | Look (sheet) | Voice / motto | Notes |
|---|---|---|---|
| **Garrik** (Dad) | Tallest, broad and burly; grey-streaked messy hair, full grey beard, dark tee, green work apron with tool pockets, towel on shoulder, black work pants, boots | "Hard work. Good food. Happy people." | Lifts logs one-handed. Always a mug in hand. |
| **Bram** | Warm brown skin, short messy black hair, black "Heavy Steps / Bright Days" tee, olive cargos, hiking boots, wrist wraps, white towel, huge orange pack with bedroll + a little bear keychain | "Same guy. Just a different gear." | Early-game protector; see his own bible. |
| **Lysa** (Mom) | Curly dark hair in a pink headband, cream blouse, green apron over a long skirt, belt pouches, wrist wraps | "A full belly is a happy journey." | Carries the food. |
| **Kip** (little sibling) | Kid, spiky black hair, white tee with red sleeves, black vest, red bandana, grey cargo shorts, bandaged fists | "Shorter. Louder. Still hits harder." | Fighter stance, grinning. |
| **Nana Ella** (Grandma) | Grey bun, round glasses, purple floral shawl, white blouse, patterned apron + long skirt, a cat on her shoulder | "Looks sweet? Good. Keep underestimating me." | Arms-crossed confidence. |
| **Grandpa** (Bram's) | Very round, bald with a white fringe, huge white mustache, round glasses, mustard striped vest + trousers, white coat/lab coat with a gear patch, towel, tool belt, pocket watch, big boots, a cane-wrench | "Old parts. New stories. That's the way of life." / "If it can be fixed, it still has a future." | Fixes everything; **moves like a cannonball** — "He doesn't just walk... he ricochets." Kind, funny, brilliant, surprisingly fast, loves to tinker, feeds everybody, believes in people, still has adventures left. Tools: tool kits, spare parts, pocket watch, snacks, *mysterious springs*, a few secrets. |
| **Sergio** — *the other brother* | Grandpa's **twin**. Tall and lean, same bald head + fringe + mustache, but a scowl; mustard striped suit, long torn dark coat with a gear badge, heavy tool harness, gloves, gear-buckled boots, a long multi-tool wrench | "People break. Machines are more honest." / "If it can be taken apart, it can be made better. If people could be taken apart... never mind." | Brilliant, pessimistic, fast, keeps to himself, doesn't trust easily, bitter but not heartless. Lives alone in a cliff workshop "at the edge of everything" ("Sergio's Repairs. Modifications. No people. No problems."). Tools: custom multi-wrench, spring launchers, retractable cables, modified gears, smoke & distraction pods, field repair kit, unknown prototypes. *"Old parts. New ideas. Same genius. Darker intentions."* |

**The twins:** "Two brothers. Same roots. One saw problems. One saw people. Both fix the world in their own ways.
Different directions. Same sky." In game they share one face (`TWIN_FACE` in `bram_family.gd`) — only posture,
build, eyes (Grandpa soft, Sergio narrow) and life differ.

## Schedules (first pass)

Garrik and Lysa work the inn all day; Nana Ella and Kip are around the house; Grandpa works (repairs) at the inn;
Bram heads out adventuring 9–15 and is back for the evening; Sergio works at his workshop from dawn to late night
(placeholder spot on the coast past Old Shore, `home_sergio`, until his cliff is built).

## Looks — first pass vs. what needs modelling

The first pass uses the creator's existing parts plus two things added for this family: recipe `"shape"`
(`belly` / `posture` / `definition` — the Blender TR_Belly/TR_Posture/TR_Definition channels, now driven from
recipes) and recipe `"height"` (scales the NPC's Body). Silhouettes and sizes read right; these parts are stand-ins:

| Needed | Who | Stand-in now |
|---|---|---|
| Bald-with-white-fringe hair | Grandpa, Sergio | `Short_Crop` in white |
| Big white handlebar mustache | Grandpa, Sergio | — |
| Full beard | Garrik | — |
| Work apron (with pockets) | Garrik, Lysa, Nana Ella | pleated skirt / nothing |
| Long skirt | Lysa, Nana Ella | pleated skirt |
| Striped vest + trousers / striped suit | Grandpa, Sergio | plain mustard shirt + pants |
| White open coat (knee length) | Grandpa | blazer |
| Long torn coat | Sergio | utility jacket |
| Big orange expedition pack + bedroll | Bram | crossbody bag |
| Shawl | Nana Ella | utility jacket |
| Vest + bandana | Kip | scarf in red |
| Tool belts/harness, pocket watch, towel-over-shoulder | Grandpa, Sergio, Garrik | scarf as towel |
| Cane-wrench / multi-wrench props | Grandpa, Sergio | — |
| Older faces (brows, wrinkles) | Grandpa, Sergio, Nana Ella | — |

Known issue from the extra widths/belly: stand-in garments clip in places (dark patches on skirts/cargos, Ella's
shirt under the jacket). Proper garments built on the widened bodies fix that.

## Open questions for the user

- Grandpa's name, and the family's surname.
- Is Bram's Grandpa the Grandpa of **Grandpa's Ranch** (the Ranch Hand job), or a different grandpa?
- Sergio's role in the story — "darker intentions": rival inventor, reluctant helper, or tied to something bigger?
- Where Sergio's cliff workshop should be.
