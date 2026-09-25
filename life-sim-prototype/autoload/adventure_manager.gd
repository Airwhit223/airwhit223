extends Node
## Lightweight state for the RPG side of the same life simulation.

signal adventure_state_changed

var player_in_danger: bool = false
var enemies_defeated: int = 0
var ruin_relic_found: bool = false
var last_adventure_day: int = -1
## Adventurer reputation from contracts (the contract board) -> rank.
var reputation: float = 0.0
const RANKS := [[0.0, "Unranked"], [10.0, "Bronze"], [40.0, "Silver"], [100.0, "Gold"]]

func reset_for_tests() -> void:
	player_in_danger = false
	enemies_defeated = 0
	ruin_relic_found = false
	last_adventure_day = -1
	reputation = 0.0

func enter_danger_zone(zone_id: String = "wooded_ruins") -> void:
	player_in_danger = true
	EventBus.fire("danger_zone_entered", {"zone_id": zone_id})
	adventure_state_changed.emit()

func leave_danger_zone(zone_id: String = "wooded_ruins") -> void:
	player_in_danger = false
	EventBus.fire("danger_zone_left", {"zone_id": zone_id})
	adventure_state_changed.emit()

## `kind` / `faction` let contract objectives count the right enemies ("defeat 2 Hollowed Moon thugs").
func register_enemy_defeat(enemy_id: String, kind := "", faction := "", zone := "") -> void:
	enemies_defeated += 1
	last_adventure_day = TimeManager.day_index
	EventBus.fire("enemy_defeated", {"enemy_id": enemy_id, "defeated_count": enemies_defeated, "kind": kind,
		"faction": faction, "zone": zone})
	adventure_state_changed.emit()

func claim_relic() -> bool:
	if ruin_relic_found or enemies_defeated < 1:
		return false
	ruin_relic_found = true
	last_adventure_day = TimeManager.day_index
	EventBus.fire("adventure_reward_found", {"item_id": "ruin_relic", "name": "Ruin Relic"})
	adventure_state_changed.emit()
	return true

func add_reputation(amount: float) -> void:
	var before := rank()
	reputation = maxf(0.0, reputation + amount)
	if rank() != before:
		EventBus.fire("hud_message", {"text": "Adventurer rank: %s" % rank()})
	adventure_state_changed.emit()

func rank() -> String:
	var out := "Unranked"
	for r in RANKS:
		if reputation >= float(r[0]):
			out = r[1]
	return out

func to_dict() -> Dictionary:
	return {"enemies_defeated": enemies_defeated, "ruin_relic_found": ruin_relic_found, "reputation": reputation,
		"last_adventure_day": last_adventure_day}

func from_dict(d: Dictionary) -> void:
	enemies_defeated = int(d.get("enemies_defeated", 0))
	ruin_relic_found = bool(d.get("ruin_relic_found", false))
	reputation = float(d.get("reputation", 0.0))
	last_adventure_day = int(d.get("last_adventure_day", -1))
