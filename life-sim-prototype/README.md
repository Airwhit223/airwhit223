# Life Sim Prototype — Milestone 1

A small Godot 4 3D life-sim/RPG vertical slice: one continuous neighborhood,
five persistent simulated NPCs, and a player who can move freely between
their work, workouts, basketball games, and evening hangouts — no minigame
scenes, no loading screens.

## Social simulation foundation

Residents now build lightweight persistent histories with one another as well
as with the player. Each pair tracks familiarity, friendship, trust, and
tension; actual conversations and shared activities create timestamped social
memories. During free time, NPCs can choose another real resident using
proximity, existing history, recent contact, shared interests, personality,
and schedule availability. Work and sleep remain authoritative.

Press **J** to open the prototype Social Inspector for the nearest resident.
It shows their closest relationships, current values, recent memories, and
their current social intention or small data-derived personal moment.

The deterministic multi-day validation is available at
`tests/social_simulation_test.tscn`; its latest concise output is saved to
`tests/social_simulation_report.txt`.

## Living community events

Two recurring events now happen inside the same open world:

- Saturday, 6:00 PM — Neighborhood Concert
- Sunday, 2:00 PM — Community Cookout

The concert creates a temporary stage and speakers; the cookout creates a
grill, food table, and seating. Every performer, cook, and guest is one of the
five persistent residents. Attendance is selected from live resident data and
considers obligations, personality, interests, relationships, invitations,
importance, and life stage. Residents travel through the normal navigation
system, perform role-specific actions, can arrive late or leave early, and
return to their ordinary schedules when the event ends.

The always-visible prototype calendar lists the next occurrences. HUD notices
announce setup/start/end, nearby dialogue mentions upcoming or active events,
and the player remains freely controllable throughout. The three-week
integration report is saved at `tests/community_event_simulation_report.txt`.

## Small farming loop

Four reusable garden plots sit beside the player's home. Walk up and press
**E** to plant a starter turnip seed, water the crop once per day, and harvest
it after three watered day changes. Missing a day only delays growth; crops do
not die in this forgiving first pass. Growth stages are visible in the world,
and the HUD shows shared seed and harvested-turnip counts. The latest complete
cycle report is saved at `tests/farming_simulation_report.txt`.

## Guitar activity

The Acoustic Guitar is a held tool. Pick it from the **Tab** tool wheel (or
take it at the guitar stand near the social area), then press **R** to play a
set anywhere. The purple **Concert Stage** marker at the social area pays
**x1.5** points, and **x2** while the Saturday concert is running — residents
attending that concert also remember seeing you perform. The compact 16-note
activity uses the four arrow keys, timing grades, score, combo, misses, and
final accuracy. It pauses the simulation clock only while playing, then
restores the previous speed.

## Tool wheel

Hands start empty. **Tab** opens a radial wheel with Empty Hands / Sword /
Guitar: tap Tab and click a slice (or press 1-3), or hold Tab, point, and
release. Held tools are exclusive — choosing one puts the other away — and
picking up a basketball tucks your tool away until you shoot or drop the ball.
Its validation report is saved at `tests/rhythm_game_report.txt`.

## RPG adventure foundation

The same neighborhood now opens into a small dangerous woodland ruin at the
far east edge of town. Entering the marked area enables danger behavior while
the normal clock and NPC schedules continue. Pick the Test Sword from the
**Tab** tool wheel: **K** or **Left Click** performs a short directional
melee attack and **Shift** dodges with a brief invulnerability window. Two
leash-bound ruin enemies detect, chase, telegraph, attack, take damage, and
recover through a simple knockout flow.

Defeat an enemy, collect the guarded Ruin Relic, and return to town. The relic
is tracked in persistent adventure state, so the player can immediately go
back to talking, shopping, sports, sleep, farming, or other normal activities.
The companion option is intentionally deferred; the existing Follow system is
left unchanged until it can be extended without schedule edge cases. The
headless proof is saved at `tests/adventure_simulation_report.txt`.

## Running it

Open the project folder in Godot 4.7+ and press Play (F5). It boots straight
into the neighborhood.

## Controls

| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse |
| Jump | Space |
| Interact (talk / pick up / use / close dialogue / dismount) | E |
| Shoot (while holding the basketball) | Left Click |
| Invite nearby NPC — they'll come when free | F |
| Follow Me — immediate, only if they're free right now / Stop Following | G |
| Mount/dismount skateboard (after picking one up) | Q |
| Pause / Resume simulation time | P |
| Normal / Fast / Very Fast simulation time | 1 / 2 / 3 |
| Toggle controls help panel | H |
| Toggle wardrobe (test equipping clothes/items) | I |
| Tool wheel (Empty Hands / Sword / Guitar) | Tab |
| Play guitar anywhere (bonus at the Concert Stage) | R |
| Guitar notes (during a set) | Arrow keys |
| Sword attack (sword in hand) | K or Left Click |
| Dodge / brief invulnerability | Shift |
| Release/capture mouse (also needed to click HUD buttons) | Esc |

A contextual `[E] ...` prompt appears whenever you're near something usable,
and `[F] Invite ...` when near an NPC — you're never expected to guess.

## What's here

- **Simulation clock** (`autoload/time_manager.gd`) — minutes → hours → days →
  weeks → seasons, with a debug time-scale toggle.
- **Event framework** (`autoload/event_bus.gd`) — a single `fire()`/`schedule()`
  API used for everything from "shift started" to "basketball scored" to
  "birthday." Future spontaneous life-sim events (arguments, crushes,
  festivals...) are more calls into this same bus, not new plumbing.
- **Relationships** (`autoload/relationship_manager.gd`) — affinity/familiarity
  per pair, changed only by actual shared activities (talking, hanging out,
  playing basketball, exercising together). Family ties are declared at
  world setup.
- **World registry** (`autoload/world_state.gd`) — named locations, households,
  and job assignments (e.g. `general_store_clerk` → `maya`), so replacing the
  shop employee later is a data change, not a rewrite.
- **NPCs** (`npc/npc_brain.gd`, `data/npc_definition.gd`, `data/npc_roster.gd`) —
  five persistent residents (Maya, Jordan, Alex, Riley, Sam) across four
  households and four life stages (teen, young adult ×2, adult, older adult;
  Alex and Riley are siblings). Each has identity, personality, schedule,
  needs, skills, interests, and an occupation. They path to real world
  locations, perform their scheduled activity there, and can be pulled off
  schedule by a player invite before resuming normal life.
- **Player** (`player/player.gd`) — third-person controller with the
  interaction foundations: talk, invite, contextual activities (inviting
  someone while standing on the court proposes basketball, not a generic
  hangout).
- **Invite vs. Follow Me** — Invite is a scheduled request: if the NPC is
  working or asleep it's queued (`npc_invite_queued`) and honored the moment
  their schedule frees up, rather than force-interrupting them. Follow Me is
  immediate companion mode — only works if they're free *right now*, has them
  continuously track the player instead of a fixed destination
  (`NPCBrain._process_follow`), and only work/sleep can interrupt it.
- **Open-world activities, not minigames** (`interactables/`) — a physical
  basketball + hoop + scoring Area3D used by both the player and NPCs; real
  gym equipment anyone can use; a shop register tied to whichever NPC is
  actually clocked in; a skateboard pickup that's a foundation for
  skating-as-traversal.
- **Aging foundation** — each NPC has a life stage and a birthday; turning a
  year older recalculates life stage and fires an `npc_birthday` event.
  Children-as-future-residents and the rest of the age ladder build on this
  same field, not a parallel system.
- **Basketball possession loop** (`interactables/basketball.gd`) — one shared
  ball with real reserve → carry → shoot → settle states. A miss stays where
  it lands and can be picked back up; a make delays briefly then returns the
  same ball to the court instead of spawning a replacement.
- **Minimal dialogue** — talking to an NPC opens a small panel with their name
  and one contextual line (different while they're working/exercising/
  playing/hanging out). Not branching yet, just proof that talking did
  something.
- **House & store interiors** (`interactables/teleporter.gd`) — the player's
  home and the general store both have small real interiors reached through
  a door (same `Teleporter` script for both, and for the exits back out).
  Maya actually walks to the store's exterior door, then teleports to a
  `StoreWorkSpot` inside for her shift and back out to the door when it ends
  (`WorldState.register_workplace_interior` — any future job just registers
  another spot, no new mechanism needed) — she's never left standing at an
  abstract outdoor point.
- **Sleep** (`interactables/bed.gd`) — jumps the shared clock straight to
  morning via `TimeManager.advance_to_morning()` rather than ticking through
  the night. Restricted to nighttime (21:00–07:00); interacting with the bed
  outside that window always answers with a clear "It's too early to sleep,"
  never a silent no-op. NPCs react to the time jump the same way they react
  to any hour change.
- **Simulation speed** (`autoload/time_manager.gd`) — Paused / Normal / Fast /
  Very Fast, keys P and 1/2/3 or the HUD buttons. Only the clock's pace
  changes; player and NPC physical movement always run at real-world speed.
- **Audio architecture** (`autoload/audio_manager.gd`) — every sound-worthy
  moment (basketball bounce/shot/score, register, gym equipment, skateboard,
  dialogue, doors, sleep) already calls `AudioManager.play_sfx(...)`. All
  paths are currently empty, so it's silent — drop a file in and point its
  name at the path to make it play, nothing else to wire up.

## Faces & skin tone

Every character now has a distinct head (a sphere sitting on the body
capsule) with two eyes and a mouth, colored by a `skin_tone` separate from
their body/outfit color. NPCs each get a hand-picked tone in
`data/npc_roster.gd` (siblings Alex and Riley share a family resemblance);
the player's is `@export var skin_tone` on `player/player.gd`, editable in
the Inspector. This is the first step toward the full clothing/equipment
slot system — the head is already a separate mesh precisely so a hat/hair
slot can attach to it later without touching the body.

While wiring this up I found the actual `setup(definition, color)` call on
each NPC happens *before* `add_child()`, so the `@onready var mesh`/`head`
references used inside it were still null — meaning NPC outfit colors had
silently never been applied since Milestone 1 (they were all rendering with
the default capsule material). Fixed by using `get_node(...)` directly
inside `setup()` instead of the `@onready` vars, which works immediately
since the whole scene subtree already exists locally at that point even
before the node joins the live tree. Confirmed via a headless check that
every NPC's body and head materials now actually match their assigned
colors.

## Equipment & clothing

A generic slot-based equipment system (`equipment/`) shared by the player and
every NPC — nothing character-specific is hard-coded twice:

- **`EquipmentItem`** (`equipment/equipment_item.gd`) is pure data: id, display
  name, slot, color, a primitive placeholder shape (box/sphere/cylinder) +
  size, and an unused `stats` dict reserved for later. No mesh node lives on
  the item itself.
- **`EquipmentCatalog`** (`equipment/equipment_catalog.gd`) is the tiny test
  inventory — 5 tops, 3 bottoms, 3 shoes, 2 hats, a necklace, a backpack, a
  sword, a tool, a pouch, and one hair placeholder. Add an item by adding one
  line here.
- **`CharacterEquipment`** (`equipment/character_equipment.gd`) is the one
  reusable visual controller, added as a child node to both `player.tscn` and
  `npc.tscn`. `equip(item)`/`unequip(slot)` are the whole API: equipping
  updates the `equipped` data dict, finds that slot's socket, and builds (or
  frees) a `MeshInstance3D` there — the character's simulation/schedule logic
  never knows equipment exists.
- **Slots & sockets**: head, hair (reserved), top, bottom, shoes, accessory,
  back, hand_l, hand_r, hip (reserved) — each a named `Node3D` child of the
  body mesh (head-slots nest under the head mesh so they turn with it). Item
  meshes attach to these sockets exclusively; nothing is positioned with
  arbitrary world coordinates.
- **Outfits are data, not code**: `NPCDefinition.starting_equipment` is a
  slot→item-id dictionary read once at spawn
  (`NPCBrain._equip_starting_outfit`) — a future "change into work clothes"
  feature is just another `equipment.equip()` call with a different id, not a
  new system. All five NPCs currently have visibly different outfits; the
  player's is `Player.STARTING_EQUIPMENT`. Because everything is looked up by
  a stable string id (never a mesh reference), this is already save-friendly.
- **World items now use the same sockets**: the basketball snaps to the
  `hand_r` socket while held (both player and NPC), and the skateboard's
  carried pose matches the `back` socket's position — same attachment points
  clothing uses, one shared basketball/skateboard node each, never duplicated.
- **Test wardrobe** (`ui/wardrobe_panel.gd`, press **I**): a deliberately
  plain per-slot `< name >` cycler, not real UI — it's there to prove
  equip/unequip actually changes the character immediately, nothing more.
- Skin tone stays independent of clothing: the body capsule itself is now
  skin-colored (matching the head) for both the player and every NPC, and the
  visible "outfit" comes entirely from equipped items layered on top. The old
  flat per-NPC identity color survives only as the nametag's outline color,
  for telling silhouettes apart at a glance before you're close enough to
  equip/read anything.

**Needs your own visual check** (I can't render the game to verify these
myself): clothing clipping through the body at the shoulder/hip seams, hat
sitting correctly on the head rather than floating/sinking, shoe placement at
the feet, whether the basketball-in-hand and carried-skateboard positions
still look right now that they're socket-driven instead of hand-tuned, item
scale relative to the bean body, and — separate from correctness — whether
the outfits actually look good together. Headless testing confirmed the data
layer and the meshes attach/detach at the right sockets with the right
colors; it can't tell you if it looks right.

## Humanoid characters (replaced the bean bodies)

- **`CharacterRig`** (`character/character_rig.gd`) is one shared humanoid used
  by the player and every NPC: rounded primitive parts (torso, hips, neck,
  head with eyes/mouth, upper/lower arms, hands, upper/lower legs, feet) on a
  joint hierarchy, built in code — no imported model. Proportions are
  authored for a 1.8m player; `npc.tscn` scales its `Body` node to 0.89, so
  sockets and clothing stay proportional with no NPC-specific tweaks. Facing
  is -Z and the character's left is -X (the old bean had its hand sockets
  swapped left/right — fixed).
- **Procedural animation** (`CharacterRig.animate()`, called every physics
  frame): a walk cycle driven by actual speed (leg swing, knee bend, arm
  counter-swing, torso bob and twist), idle breathing, a jump pose, a riding
  pose with arms out for balance, a two-handed basketball hold, and a
  jumping-jack workout pose NPCs use at the gym.
- **Clothing wraps body parts now.** Each clothing item lists the rig parts it
  covers (`EquipmentItem.coverage`), and `CharacterEquipment` builds a
  slightly inflated copy of each covered part on the same joint — so sleeves
  and pant legs move with the limbs. T-shirts cover torso + upper arms,
  hoodies add forearms, pants cover hips + legs, shoes cover feet. The
  striped shirt has real stripes (a tiny generated texture). Hats, hair,
  necklace, backpack, sword/tool and pouch still attach at named sockets,
  now on the rig.
- **World items:** the basketball is held between both hands
  (`CharacterRig.ball_hold_position()`) for the player and NPCs. The
  skateboard is parented to the rig's Back socket when carried and to the
  Body when riding.
- Collision capsules are unchanged (0.4m radius), so the collision shape is a
  little wider than the new, slimmer body.
- The rig is built at runtime, so opening `player.tscn`/`npc.tscn` in the
  editor shows an empty `Body` node — the character only appears when you
  press Play.

## Deliberately not built yet

Per the brief: this is one playable milestone, not fifteen simultaneous
systems. Not implemented: romance/marriage/pregnancy, arguments/confessions,
community events (cookouts, festivals, concerts...), skating-as-real-
traversal (mounting is a speed/visual swap, not real board physics), job
quitting/replacement UI (the data model supports it via
`WorldState.assign_job`/`vacate_job`, just no UI hook yet), branching
dialogue, and children as playable residents. NPC homes reuse the same
Teleporter pattern as the player's and the store's but don't have explorable
interiors yet (NPCs still just go stand at their home marker outside for
SLEEP). Equipment-wise: no character creator, no shop/economy to buy items,
no clothing physics or body-fitted meshes, no armor stats, no full hair
system, no clothes-changing behavior (work outfits, gym outfits) — the
architecture supports all of that (it's just more items and more
`equip()` calls) but none of it is wired up yet. All of these have a clear
landing spot in the systems above rather than needing new ones.

## A real bug worth knowing about

A resting (frozen) `RigidBody3D` is invisible to `Area3D` overlap detection
in Godot 4 unless its `freeze_mode` is `FREEZE_MODE_KINEMATIC` (the default
is `FREEZE_MODE_STATIC`, which is *not* detected). The basketball sits frozen
at rest, so without this the player's interaction area never saw it and solo
play was silently broken — confirmed by simulating real input events
headlessly and watching `Area3D.get_overlapping_bodies()` stay empty right
up until unfreezing it. Fixed in `scenes/basketball.tscn` (`freeze_mode = 1`).
Worth remembering for any other object that needs to sit still *and* be
interactable.

A related one: anything a character *carries* by teleporting it to a socket
every frame must not collide with that character. The held ball overlapped
the player's capsule, and `move_and_slide` shoved the player out of it every
frame — about 3x normal travel distance while walking with the ball, which
read as movement "going crazy". `Basketball` now adds a collision exception
with whoever holds it (and keeps it ~0.35s after release so a shot launched
from against the body doesn't knock the thrower), and holds the ball out in
front of the hand socket (`HOLD_OFFSET`) so it isn't visually buried either.

Also: the player root sits exactly at ground level, so any visual placed
below it is hidden inside the ground. That's why the skateboard kept
vanishing while riding. Riding now lifts the visible body by `MOUNT_LIFT`
(visual only, collision unchanged) so the character stands on the board.
