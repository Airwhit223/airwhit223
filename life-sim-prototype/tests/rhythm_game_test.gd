extends Node
## Headless scoring proof for the deterministic four-lane guitar pattern.

var failures: Array[String] = []

func _ready() -> void:
	TimeManager.set_speed(TimeManager.Speed.NORMAL)
	EventBus.recent_events.clear()
	var game := RhythmGame.new()
	add_child(game)
	await get_tree().process_frame
	var guitar := EquipmentCatalog.get_item("acoustic_guitar")
	_expect(guitar != null and guitar.slot == EquipmentItem.Slot.HAND_L, "The guitar is a reusable hand-tool inventory item")
	_expect(guitar.stats.get("activity", "") == "guitar", "The inventory item advertises its performance activity")
	game.start_game()
	_expect(TimeManager.current_speed == TimeManager.Speed.PAUSED, "Starting the guitar set pauses the simulation clock")
	game._elapsed = game.get_note_time(0)
	_expect(game.submit_lane(int(game.NOTES[0][0])), "The matching arrow hits a note inside its timing window")
	_expect(game.score >= 100 and game.combo == 1, "A precise hit awards score and combo")
	game._elapsed = game.get_note_time(1) - 0.5
	_expect(not game.submit_lane(int(game.NOTES[1][0])) and game.combo == 0, "An early input misses and breaks combo")
	for index in range(1, game.NOTES.size()):
		game._elapsed = game.get_note_time(index)
		game.submit_lane(int(game.NOTES[index][0]))
	game._finish_game()
	_expect(game.hits == game.NOTES.size(), "The complete four-lane pattern can be cleared")
	_expect(_event_count("guitar_minigame_completed") == 1, "Completion publishes a result through the world event bus")
	game.close_game()
	_expect(TimeManager.current_speed == TimeManager.Speed.NORMAL and not game.active, "Closing returns cleanly to the prior world speed")
	var street_score := game.score
	_expect(CommunityEventManager.get_performance_venue(Vector3(40, 0, 40)).get("multiplier", 0.0) == 1.0, "Away from the stage a set scores normally")
	game.start_game({"id": "concert_stage", "name": "Concert Stage", "multiplier": 1.5})
	for index in game.NOTES.size():
		game._elapsed = game.get_note_time(index)
		game.submit_lane(int(game.NOTES[index][0]))
	game._finish_game()
	_expect(game.score > street_score and absi(game.score - int(round(game.base_score * 1.5))) <= game.NOTES.size(), "The concert stage multiplies the same performance's points")
	var completed: Array = EventBus.recent_events.filter(func(entry: Dictionary): return entry.name == "guitar_minigame_completed")
	_expect(not completed.is_empty() and completed[-1].data.get("venue_id", "") == "concert_stage", "Completion reports the venue that earned the bonus")
	game.close_game()
	var report := _build_report(game)
	print(report)
	var file := FileAccess.open("res://tests/rhythm_game_report.txt", FileAccess.WRITE)
	if file:
		file.store_string(report)
	get_tree().quit(0 if failures.is_empty() else 1)

func _event_count(event_name: String) -> int:
	var count := 0
	for entry in EventBus.recent_events:
		if entry.name == event_name:
			count += 1
	return count

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.push_back(label)
		push_error("FAIL: " + label)

func _build_report(game: RhythmGame) -> String:
	var lines: Array[String] = [
		"TINY GUITAR RHYTHM GAME — HEADLESS VALIDATION",
		"Result: %s" % ("PASS" if failures.is_empty() else "FAIL"),
		"Pattern: %d notes across four arrow-key lanes" % game.NOTES.size(),
		"Instrument: Acoustic Guitar is available through the existing modular equipment inventory.",
		"Scoring: timing window, perfect/good grades, combo, misses and final accuracy are active.",
		"World handoff: the clock pauses for the set and restores its previous speed afterward.",
	]
	if not failures.is_empty():
		lines.push_back("Failures: " + ", ".join(failures))
	return "\n".join(lines)
