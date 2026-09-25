# Adventure & Sandbox — implementation plan (2026-09-24)

Two supported modes, one game. Same world simulation, towns, NPCs, jobs, relationships, traits, schedules,
exploration, followers, combat, powers, shops, homes. The only difference is how much authored story is switched on.

## 1. What already exists and gets reused

| Need from the brief | Already in the project |
|---|---|
| Living NPCs with homes, jobs, schedules, travel | `npc/npc_brain.gd` — schedules, navmesh travel, work/sleep/exercise/basketball/socialize/event states, follow requests, day log |
| Towns, districts, workplaces | `TownsfolkGenerator` (25 jobs across 10 districts), `WorldState` (locations, households, job holders), `scenes/main.gd` bootstrap |
| Relationships incl. dating | `RelationshipManager` — friendship / trust / tension / familiarity / **romance** + memories |
| Traits shaping lifestyle | `TraitSystem` + `TraitCatalog` + `TraitPairing`; NPC registers derive from trait pairs |
| Dialogue with options | `data/social_topics.gd`, `npc/npc_conversation.gd`, `data/npc_outlook.gd`, `ui/dialogue_box.gd` (built this session) |
| NPC personal quests | `Hardships` — clue-driven personal storylines that end in a recruitable companion. This IS the "personal quests stay on in both modes" system |
| Levelling, unlock quests | `Progression` (1–60, unlock quests at 15 / 25) |
| Body/lifestyle drift | `PlayerStats` — mass / muscle / book smarts from what you actually did that week |
| Seasonal & town events | `CommunityEventManager`, `TownGrowth`, `FarmingManager` |
| Powers | `PowerSystem`, `power_system/power_controller.gd`, `primal_form.gd` |
| Characters | `ToriyamaKitCharacter` + the kit (bases, 39 garments, hair, katana props) |
| The opening in-world | `scenes/intro_sequence.gd` — already starts the player in their bedroom at a mirror, no menu screen |
| Interaction verbs | `interactables/` — bed, gym, register, skateboard pickup, teleporter, danger zone, location zone |

## 2. What is missing and has to be new

| New | Why |
|---|---|
| **`GameRules`** autoload | mode + flags + sandbox tuning. DONE (milestone 1) |
| **`StoryManager`** autoload | the chapter/beat chain, data-driven, only advances when `main_story_enabled` |
| ~~**`Vitals`** (Health / Energy / Stamina)~~ | **done.** `player/vitals.gd`; the player's `health`/`energy`/`stamina` are now pass-throughs so existing readers are unchanged |
| **`MoodSystem`** | temporary moods are a separate axis from permanent traits; nothing models them today |
| ~~**Money**~~ | **done.** `Economy` holds money, a single price book and the shops; `CreatorData.is_unlocked` reads real ownership |
| `data/trait_lifestyle.gd` | which activities restore Energy for which trait — the heart of "traits shape lifestyle, not stats" |
| `data/quest_definition.gd` + `QuestManager` | authored personal quests (Bram's family, Mei & Jian) alongside the generated Hardship ones |
| `data/shop_definition.gd`, restaurant + skate shop interactables and their part-time jobs | town life locations |
| Follower availability | NPCs need to be able to say "I already have plans" and return to their own lives |
| Mode select at boot | one screen before the world loads |
| Roster entries for Mr. Jones, Grandpa, Bram, Sergio, Mei & Jian | the in-game authored cast is still Maya / Jordan / Alex / Riley / Sam placeholders; Bram's approved companion power curve is recorded in `docs/BRAM_CHARACTER_BIBLE.md` |

## 3. How the modes branch

`GameRules` holds the flags; **no system asks which mode it is in**, it asks for the flag it cares about:

```
GameRules.allows("main_story_enabled")        # StoryManager advances the chapter chain
GameRules.allows("story_cutscenes_enabled")   # a beat plays its cutscene, or skips straight to its outcome
GameRules.allows("story_world_events_enabled")# a beat may permanently change the world
GameRules.allows("npc_personal_quests_enabled")  # ON IN BOTH MODES
GameRules.allows("random_world_events_enabled")  # ON IN BOTH MODES
```

Because they are flags and not a mode check, "enable the adventure story inside an existing sandbox save" is
`GameRules.set_flag("main_story_enabled", true)` and nothing else. Sandbox tuning (starting money, energy drain,
aging, relationship speed, difficulty, power speed, danger frequency, season length) lives in the same object with
defaults, ready for a settings screen that does not exist yet.

## 4. Chapter One with placeholders

One `ChapterOne` resource: an ordered list of beats, each `{id, trigger, on_enter, objective, on_complete}`.
StoryManager owns the cursor; beats fire through EventBus so nothing is hard-wired to a scene.

| Beat | Placeholder implementation |
|---|---|
| Wake in your house, "first day" | extend `IntroSequence` (already the bedroom + mirror opening) |
| First-day freedom, town objectives | objective markers only; no gates |
| Mr. Jones invites you | a roster NPC with a schedule + a dialogue topic; if the player misses the day, the beat reschedules |
| Travel tutorial | trigger volumes along the road teaching sprint / stamina / gather / climb |
| Beastfolk encounter | a kit NPC with `race = "beastfolk"` (the field arrived in the merge), a short scripted exchange |
| Ruin, Dwarf + Elf rivals | boxed-out room set under `world/dungeons/`, two kit NPCs, a race timer |
| Draconic boss | `rpg/enemy.gd` with phases; transformation reuses the Primal Form aura shader |
| Mr. Jones power event | a scripted PowerSystem burst + the same aura, no bespoke cinematic |
| Walk home, family dinner | a gathering at a location marker, dialogue-driven |
| Dream ending | a small separate scene, then `CHAPTER ONE COMPLETE` |

Nothing above needs final art, and every beat is skippable in Sandbox because the whole chain sits behind one flag.

## 5. Safest order (each milestone ends testable)

1. **GameRules** + mode select. *(done — `tests/game_rules_test.gd`, 13/13)*
2. **Vitals**: Health / Energy / Stamina with the slow-energy, fast-stamina, low-energy-penalty and mastery-discount
   rules; HUD bars. Touches the player only. *(done — `player/vitals.gd`, `tests/vitals_test.gd` 19/19)*
3. **Money** + `ShopDefinition`, and make `creator_data.gd`'s existing prices real. *(done — `autoload/economy.gd`,
   `data/shop_definition.gd`, `tests/economy_test.gd` 25/25)*
4. **Traits → lifestyle** + **Moods**. Data first, then hook Energy recovery to them.
5. **Follower availability** and "I have plans" — small change inside `npc_brain`, big change in how the world feels.
6. **Restaurant** and **skate shop** with their part-time jobs (board assembly).
7. **StoryManager** + the Chapter One beat list, still with placeholder content.
8. Authored roster: Mr. Jones, Grandpa, Bram, Sergio, Mei & Jian.
9. Chapter One beats in order, 4 or 5 at a time.
10. Sandbox free-start flow and the tuning screen.

Order matters: 2–6 are pure life-sim and improve Sandbox immediately, so the game is playable and better after every
milestone even if the story chain is never touched. Nothing before step 7 can break existing systems.
