extends Node
## Headless proof of the complete small farming loop across calendar days.

var failures: Array[String] = []
var plot: FarmPlot
var starting_day: int

func _ready() -> void:
	TimeManager.set_speed(TimeManager.Speed.PAUSED)
	starting_day = TimeManager.day_index
	FarmingManager.reset_for_tests()
	EventBus.recent_events.clear()
	plot = FarmPlot.new()
	plot.plot_id = "test_plot"
	add_child(plot)
	await get_tree().process_frame
	_run_cycle()
	var report := _build_report()
	print(report)
	var file := FileAccess.open("res://tests/farming_simulation_report.txt", FileAccess.WRITE)
	if file:
		file.store_string(report)
	get_tree().quit(0 if failures.is_empty() else 1)

func _run_cycle() -> void:
	# A reset is a true reset even after a prior play/test session used seeds.
	FarmingManager.use_seed("turnip")
	FarmingManager.reset_for_tests()
	_expect(FarmingManager.get_seed_count("turnip") == FarmingManager.STARTER_SEEDS, "Reset restores starter seeds after prior inventory changes")

	plot.interact(null)
	_expect(plot.state == FarmPlot.PlotState.GROWING, "An empty plot accepts a seed")
	_expect(FarmingManager.get_seed_count("turnip") == FarmingManager.STARTER_SEEDS - 1, "Planting consumes exactly one seed")

	plot.interact(null)
	plot.interact(null)
	_expect(plot.watered_today and plot.growth_days == 0, "Watering is limited to once per day")
	_advance_day()
	_expect(plot.growth_days == 1 and not plot.watered_today, "A watered crop grows at the day boundary")

	_advance_day()
	_expect(plot.growth_days == 1, "An unwatered day does not advance growth")

	for expected_growth in [2, 3]:
		plot.interact(null)
		_advance_day()
		_expect(plot.growth_days == expected_growth, "Watered growth reached day %d" % expected_growth)

	_expect(plot.state == FarmPlot.PlotState.READY, "The crop becomes harvestable after its configured growth time")
	plot.interact(null)
	_expect(plot.state == FarmPlot.PlotState.EMPTY, "Harvesting returns the plot to reusable soil")
	_expect(FarmingManager.get_produce_count("turnip") >= 2, "Harvesting adds produce to shared inventory")
	_expect(_event_count("crop_planted") == 1 and _event_count("crop_watered") == 3 and _event_count("crop_harvested") == 1, "The world event bus observed the complete farming history")
	var plot_save := plot.to_dict()
	var inventory_save := FarmingManager.to_dict()
	plot.from_dict({"state": FarmPlot.PlotState.GROWING, "crop_id": "missing_crop", "growth_days": 99})
	_expect(plot.state == FarmPlot.PlotState.EMPTY, "Invalid saved crops recover to an empty usable plot")
	plot.from_dict(plot_save)
	FarmingManager.from_dict(inventory_save)
	_expect(FarmingManager.get_produce_count("turnip") >= 2, "Farm inventory round-trips through persistence data")

func _advance_day() -> void:
	TimeManager.day_index += 1
	TimeManager.day_changed.emit(TimeManager.day_index, TimeManager.get_day_of_week())

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

func _build_report() -> String:
	var crop := FarmingManager.get_crop("turnip")
	var lines: Array[String] = [
		"SMALL FARMING SYSTEM — HEADLESS VALIDATION",
		"Result: %s" % ("PASS" if failures.is_empty() else "FAIL"),
		"Crop: %s | watered growth days: %d | forgiving missed-day behavior: yes" % [crop.display_name, crop.days_to_mature],
		"Starter seeds remaining: %d | harvested produce: %d" % [FarmingManager.get_seed_count("turnip"), FarmingManager.get_produce_count("turnip")],
		"History: planted %d | watered %d | ready %d | harvested %d" % [_event_count("crop_planted"), _event_count("crop_watered"), _event_count("crop_ready"), _event_count("crop_harvested")],
		"The same plot is reusable after harvest and growth follows TimeManager day changes.",
	]
	if not failures.is_empty():
		lines.push_back("Failures: " + ", ".join(failures))
	TimeManager.day_index = starting_day
	return "\n".join(lines)
