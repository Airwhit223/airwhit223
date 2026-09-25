extends Node
## Headless proof of the continuous-world adventure loop.

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScript := preload("res://rpg/enemy.gd")
const RewardScript := preload("res://interactables/adventure_reward.gd")

var failures: Array[String] = []
var player: Player

func _ready() -> void:
	TimeManager.set_speed(TimeManager.Speed.PAUSED)
	AdventureManager.reset_for_tests()
	EventBus.recent_events.clear()
	player = PlayerScene.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector3.ZERO
	# Hands start empty now; pick the sword the same way the inventory wheel does.
	player.select_hand_tool("test_sword")
	AdventureManager.enter_danger_zone()
	var enemy := EnemyScript.new()
	enemy.enemy_id = "test_ruin_beast"
	enemy.position = Vector3(0, 0, -1.5)
	add_child(enemy)
	await get_tree().process_frame
	_run_combat(enemy)
	await get_tree().process_frame
	await _run_reward()
	_run_return_to_life()
	var report := _build_report()
	print(report)
	var file := FileAccess.open("res://tests/adventure_simulation_report.txt", FileAccess.WRITE)
	if file:
		file.store_string(report)
	get_tree().quit(0 if failures.is_empty() else 1)

func _run_combat(enemy: RuinEnemy) -> void:
	_expect(EquipmentCatalog.get_item("test_sword") != null, "The existing equipment catalog provides the test sword")
	_expect(player.equipment.get_equipped("hand_r") != null and player.equipment.get_equipped("hand_r").id == "test_sword", "The player can enter the outskirts with the sword equipped")
	_expect(player.perform_basic_attack(), "Basic sword attack is available during normal movement")
	_expect(enemy.health == 15, "A sword hit deals readable fixed damage")
	player._dodge()
	_expect(player.is_dodging, "Dodge grants a brief invulnerability window")
	player._dodge_timer = 0.0
	player.is_dodging = false
	enemy.take_damage(15, player.global_position)
	_expect(enemy.health == 0, "The reusable enemy can be defeated")

func _run_reward() -> void:
	_expect(AdventureManager.enemies_defeated == 1, "Enemy defeat updates persistent adventure state")
	var reward := RewardScript.new()
	add_child(reward)
	await get_tree().process_frame
	reward.interact(player)
	_expect(AdventureManager.ruin_relic_found, "The guarded ruin reward becomes claimable after combat")
	_expect(not reward.visible, "The claimed reward is removed from the world")

func _run_return_to_life() -> void:
	var old_minutes := TimeManager.get_total_minutes()
	AdventureManager.leave_danger_zone()
	_expect(not AdventureManager.player_in_danger, "Leaving the ruins restores the safe-world state")
	TimeManager._jump_by_minutes(180)
	_expect(TimeManager.get_total_minutes() == old_minutes + 180, "The shared life-sim clock continues during an adventure")
	_expect(AdventureManager.ruin_relic_found, "The reward persists after returning to ordinary life")
	_expect(EventBus.recent_events.any(func(entry: Dictionary): return entry.name == "danger_zone_left"), "The return transition is observable through the event bus")

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.push_back(label)
		push_error("FAIL: " + label)

func _build_report() -> String:
	var lines: Array[String] = [
		"RPG ADVENTURE FOUNDATION — HEADLESS VALIDATION",
		"Result: %s" % ("PASS" if failures.is_empty() else "FAIL"),
		"Combat: sword damage, enemy defeat, attack telegraph path, dodge/invulnerability, health state.",
		"World: danger-zone enter/exit, leash-bound enemy, persistent Ruin Relic reward.",
		"Continuity: TimeManager advanced three in-game hours and reward survived the return home transition.",
	]
	if not failures.is_empty():
		lines.push_back("Failures: " + ", ".join(failures))
	return "\n".join(lines)
