# Multiplayer — architecture report and plan

**Target: 4-player co-op** (the existing stack is capped at 2; see the audit).

**Status:** not started. Recorded 2026-09-23 so the architecture stops drifting away from it.

## You already built this once

`Rolling_Tides_2D` contains a working 2-player co-op stack, 1,327 lines, worth porting rather than reinventing:

| File | Lines | What it gives us |
|---|---|---|
| `scripts_2d/multiplayer/network_manager.gd` | 668 | Host/join over LAN with a short code (`RT-xxxx`), port 7777, `MAX_CLIENTS = 1` (host + 1 = "small multiplayer"), peer profiles, **per-peer scene tracking** (`peer_scenes`), join/leave signals |
| `scripts_2d/multiplayer/permission_manager.gd` | 133 | `VISITOR / MEMBER / OWNER` roles with per-flag checks and denial notifications |
| `scripts_2d/multiplayer/network_player.gd` | 409 | The remote-player representation |
| `scripts_2d/multiplayer/player_spawner.gd` | 117 | Spawning peers into a scene |

The old README is honest that host/client authority and RPC paths exist but a live two-machine LAN join was
never verified. Treat that as "port the design, re-test the socket".

The permission roles matter more in this game than they did in the 2D one: a visiting friend who can fly now has
the ability to break your roof (see `autoload/building_damage.gd`).

## What in the current build fights multiplayer

Found by auditing what was written this session. None of it is hard to fix now; all of it is expensive later.

1. **`FlightController` reads `Input` directly.** Every peer's flight would answer the local keyboard. The input
   source has to be per-player: only the locally-owned player polls `Input`, remote players consume replicated
   state.
2. **Travel uses `get_tree().change_scene_to_packed`** (underworld descent, sky island, return to surface). In
   co-op that drags or desyncs everyone. The 2D `network_manager.peer_scenes` already models per-peer scenes —
   that is the pattern to reuse.
3. **`BuildingDamage` is a local autoload.** Damage must be host-authoritative and replicated, and gated by
   `PermissionManager` (can a VISITOR put a hole in the owner's roof?).
4. **NPC brains and schedules run locally.** Two clients would each simulate their own Jones. Host-authoritative
   with position/state replication.
5. **`PowerSystem.profile` is one global profile.** It needs to be per-peer; the power bible's profile is already
   a self-contained object, which helps.
6. **Vehicle mounting reparents the player node.** Reparenting is replication-hostile; it needs an explicit
   authority/ownership handoff instead.

## Cheap guardrails to apply BEFORE the port

- Route player input through a small indirection (an `input_source` object per player) rather than calling
  `Input` inside ability controllers.
- Keep world mutations (building damage, growth, NPC state) behind autoload APIs — they already are — so the
  host-authority layer can wrap them in one place instead of being sprayed through call sites.
- Keep scene travel behind a single function per destination, so per-peer scene handling has one place to live.


---

# Architecture report (requested before implementation) — 2026-09-23

## Q: high-level multiplayer API, or something custom/lower-level?

**It is Godot's high-level API, and it is idiomatic.** This is the good answer: the work is porting and
extending, not rework.

- **Transport:** `ENetMultiplayerPeer` with `create_server(PORT, MAX_CLIENTS)` / `create_client(ip, PORT)`
  assigned to `multiplayer.multiplayer_peer`. Standard.
- **Signals:** the engine's own `multiplayer.peer_connected / peer_disconnected / connected_to_server /
  connection_failed / server_disconnected`.
- **RPC:** 74 annotated functions across `scripts_2d`, with correct, varied modes rather than one blunt default —
  `@rpc("authority", "reliable")` ×25, `@rpc("any_peer", "reliable")` ×23, `call_remote` variants ×20, and
  `unreliable` reserved for high-frequency state ×5. Targeted sends use `rpc_id`.
- **Replication:** `MultiplayerSynchronizer` / `MultiplayerSpawner` are in use (`player_spawner.gd`,
  `NetworkPlayer.tscn`, `Pet2D.tscn`, `AngieFull.tscn`), with explicit synchronised properties on the remote
  player (`sync_position`, `sync_animation`, `sync_flip_h`, `sync_walk_frame`, `sync_tool`).
- **Authority:** host-authoritative already (`multiplayer.is_server()` gates state changes), matching the
  spec's core structural rule.

**Consequence:** Godot's high-level API is dimension-agnostic, so the networking layer ports to the 3D project
essentially as-is. What does *not* port is the 2D-specific payload — `NetworkPlayer` syncs `Vector2` position,
flip and walk-frame.

**A cheap win for the 3D port:** our `CharacterRig` poses every bone procedurally from four inputs
(`horizontal_speed`, `on_floor`, `state`, `vertical_speed`). So a remote 3D character needs position, rotation
and those four values — no bone or animation-track replication at all. That is a smaller payload than the 2D
game sends.

## Q: how much rework does the NPC data model need for per-player memory?

**Much less than the spec fears — the data shape is already right.**

- `autoload/relationship_manager.gd` is **pair-keyed**, not host-keyed: `_pair_key(id_a, id_b)` with
  `get_relationship(a, b)`, `record_shared_activity(a, b, …)`, `record_social_event(actor, target, …)`,
  `get_recent_memories(a, b)` and per-pair memory lists. An NPC↔Player-2 relationship is the same kind of
  record as an NPC↔NPC one. Nothing needs restructuring.
- `player/player.gd` already carries `@export var player_id: String = "player"` — a per-character identity field
  exists; it is merely defaulted to a single literal.

So the work is identity plumbing, not a data-model rewrite:
1. Give each joined player a unique, persistent `player_id` (from their peer profile) instead of `"player"`.
2. Replace hardcoded `"player"` literals at call sites (e.g. `autoload/community_event_manager.gd`, and the
   `"You"` label in `relationship_manager.gd:157`).
3. **The real structural change:** `WorldState.player` is a single global reference, and `npc_brain.gd` follows,
   reacts to and paths toward that one player (`is_following_player`, `WorldState.player.global_position`).
   This becomes a collection plus a "which player is this NPC dealing with" resolution (usually nearest).

Item 3 is the milestone-sized piece; items 1–2 are mechanical. This supports the spec's instruction that
per-player NPC memory may deserve its own milestone — but the reason is the NPC *targeting* model, not the
relationship store.

## Stress test before building on top
The spec is right that networking faults do not scale linearly. Before any RPG systems are layered on, the
4-player case needs a deliberate soak: four peers, simultaneous world mutation (building damage, placement),
scene travel while others remain, and a mid-session join/leave.

## Decisions still open (flagged, not defaulted)
1. **Mixed-path combat** — unify into one real-time system for multiplayer / keep path-based switching
   single-player-only / restrict to same-path groups. Not decided; has the largest downstream effect.
2. **Scope** — hub/life-sim content only, or full adventure and combat? Does visiting expose guests to the
   host's story and heritage-reveal progress?

## Guardrail already applied (2026-09-23)
`player/input_source.gd` + `LocalInputSource` + `RemoteInputSource`. Ability controllers no longer poll `Input`
directly; each character reads its own intent source, so a remote character can be fed replicated intent without
the controller knowing. `FlightController` and the player's movement are converted. **Still to convert:** the
vehicle scripts (`player/vehicles/*.gd`) poll `Input` directly — they are Antigravity files that get re-synced,
so convert them at port time with a marked patch rather than now.
