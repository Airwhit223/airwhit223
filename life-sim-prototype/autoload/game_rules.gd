extends Node
## Which rules this save runs under. ONE source of truth for Adventure vs Sandbox.
##
## Adventure and Sandbox are not two games: they are the same world, NPCs, jobs, relationships, shops, powers and
## life-sim systems, differing only in how much authored story is switched on. So nothing in the codebase should ask
## "which mode is this?" — it asks for the one FLAG it cares about, and the flags can be recombined. That is what
## makes a later "enable the adventure story in my existing sandbox save" a data change instead of a rewrite.
##
##   main_story_enabled        the authored chapter chain advances at all
##   story_cutscenes_enabled   authored cutscenes play (a chapter can still advance without them)
##   story_world_events_enabled  story beats are allowed to change the world permanently
##   npc_personal_quests_enabled  Bram's family, Mei and Jian, hardship storylines - ON IN BOTH MODES by design
##   random_world_events_enabled  community events, seasonal happenings, wandering trouble
##
## The tuning values below are the Sandbox settings the design doc wants exposed later. They exist now so systems can
## already read them; there is deliberately no settings screen yet.

signal mode_changed(mode: int)
signal rules_changed()

enum Mode { ADVENTURE, SANDBOX }

const MODE_NAMES := {Mode.ADVENTURE: "Adventure", Mode.SANDBOX: "Sandbox"}

## The flag set each mode starts from. A save may diverge from these afterwards.
const PRESETS := {
	Mode.ADVENTURE: {
		"main_story_enabled": true, "story_cutscenes_enabled": true, "story_world_events_enabled": true,
		"npc_personal_quests_enabled": true, "random_world_events_enabled": true,
	},
	Mode.SANDBOX: {
		"main_story_enabled": false, "story_cutscenes_enabled": false, "story_world_events_enabled": false,
		"npc_personal_quests_enabled": true, "random_world_events_enabled": true,
	},
}

## Sandbox dials. Everything is a multiplier on the system's own rate, so 1.0 is "as designed" in both modes.
const DEFAULT_TUNING := {
	"starting_money": 250,
	"energy_drain_scale": 1.0,
	"aging_enabled": true,
	"relationship_speed": 1.0,
	"job_difficulty": 1.0,
	"combat_difficulty": 1.0,
	"power_progression_speed": 1.0,
	"danger_frequency": 1.0,
	"season_length_days": 21,
}

var mode: int = Mode.ADVENTURE
var flags: Dictionary = {}
var tuning: Dictionary = {}
## False until a mode has actually been chosen for this run, so a scene loaded straight from the editor can tell.
var started := false

func _ready() -> void:
	_apply_preset(Mode.ADVENTURE)

func _apply_preset(new_mode: int) -> void:
	mode = new_mode
	flags = (PRESETS[new_mode] as Dictionary).duplicate(true)
	tuning = DEFAULT_TUNING.duplicate(true)

## Begin a run. `overrides` may set any flag or tuning value (a Sandbox with the story switched on, say).
func start_new_game(new_mode: int, overrides: Dictionary = {}) -> void:
	_apply_preset(new_mode)
	for key in overrides:
		if flags.has(key):
			flags[key] = overrides[key]
		elif tuning.has(key):
			tuning[key] = overrides[key]
		else:
			push_warning("GameRules: unknown override '%s'" % key)
	started = true
	mode_changed.emit(mode)
	rules_changed.emit()
	EventBus.fire("game_mode_started", {"mode": mode, "name": mode_name(), "flags": flags.duplicate()})

func mode_name() -> String:
	return String(MODE_NAMES.get(mode, "Adventure"))

func is_adventure_mode() -> bool:
	return mode == Mode.ADVENTURE

## The question every system should ask, instead of asking which mode it is in.
func allows(flag: String) -> bool:
	return bool(flags.get(flag, false))

func value(key: String, fallback = null):
	return tuning.get(key, fallback)

## Turn one flag on or off mid-run. This is how "enable the adventure story in this sandbox save" will work.
func set_flag(flag: String, on: bool) -> void:
	if not flags.has(flag):
		push_warning("GameRules: unknown flag '%s'" % flag)
		return
	if bool(flags[flag]) == on:
		return
	flags[flag] = on
	rules_changed.emit()
	EventBus.fire("game_rule_changed", {"flag": flag, "on": on})

func set_value(key: String, v) -> void:
	if not tuning.has(key):
		push_warning("GameRules: unknown tuning key '%s'" % key)
		return
	tuning[key] = v
	rules_changed.emit()

## --- save/load ----------------------------------------------------------
func to_save() -> Dictionary:
	return {"mode": mode, "flags": flags.duplicate(true), "tuning": tuning.duplicate(true), "started": started}

func from_save(data: Dictionary) -> void:
	_apply_preset(int(data.get("mode", Mode.ADVENTURE)))
	for key in (data.get("flags", {}) as Dictionary):
		if flags.has(key):
			flags[key] = data["flags"][key]
	for key in (data.get("tuning", {}) as Dictionary):
		if tuning.has(key):
			tuning[key] = data["tuning"][key]
	started = bool(data.get("started", false))
	mode_changed.emit(mode)
	rules_changed.emit()

func reset_for_tests() -> void:
	_apply_preset(Mode.ADVENTURE)
	started = false
