extends SceneTree
## Levelling and how the two power trait slots open.
##   * levels 1-60 are the designed range; past that, levelling continues but only grants a shrinking buff
##   * reaching level 15 or 25 makes an unlock QUEST available — it never grants the slot by itself
##   * finishing that quest is what opens the slot in TraitSystem

var failures: Array[String] = []
var prog
var traits

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _level_to(target: int) -> void:
	var guard := 0
	while prog.level < target and guard < 100000:
		prog.add_xp(prog.xp_to_next() + 1.0)
		guard += 1

func _run() -> void:
	prog = root.get_node("Progression")
	traits = root.get_node("TraitSystem")
	prog.reset()
	traits.reset()

	# --- the curve
	_expect(prog.level == 1 and is_equal_approx(prog.xp, 0.0), "a new character starts at level 1")
	_expect(prog.xp_for_next(10) > prog.xp_for_next(1), "each level costs more than the last")
	prog.add_xp(prog.xp_for_next(1) + 1.0)
	_expect(prog.level == 2, "enough xp levels you up")
	var carried: float = prog.xp
	_expect(carried > 0.0, "leftover xp carries into the next level")

	# --- events feed xp without anything else being wired up
	var before: float = prog.total_xp
	root.get_node("EventBus").fire("enemy_defeated", {})
	_expect(prog.total_xp > before, "things the game already does award xp")

	# --- power unlocks: reaching the level only offers the quest
	prog.reset(); traits.reset()
	_level_to(14)
	_expect(prog.available_unlock_quests().is_empty(), "nothing is offered before level 15")
	_level_to(15)
	_expect(prog.is_unlock_quest_available(&"quest_first_power"), "level 15 offers the first unlock quest")
	_expect(not traits.is_power_slot_unlocked(0), "reaching the level does NOT open the slot")
	_expect(not traits.set_power_trait(0, &"unshaken"), "and the slot still refuses a trait")
	_expect(prog.complete_unlock_quest(&"quest_first_power"), "finishing the quest works")
	_expect(traits.is_power_slot_unlocked(0), "finishing the quest opens the slot")
	_expect(traits.set_power_trait(0, &"unshaken"), "now the power trait fits")
	_expect(not prog.complete_unlock_quest(&"quest_first_power"), "a quest cannot be completed twice")
	_expect(not prog.is_unlock_quest_available(&"quest_second_power"), "the second quest is not offered yet")
	_level_to(25)
	_expect(prog.is_unlock_quest_available(&"quest_second_power"), "level 25 offers the second unlock quest")
	_expect(not traits.is_power_slot_unlocked(1), "again, the level alone opens nothing")
	prog.complete_unlock_quest(&"quest_second_power")
	_expect(traits.is_power_slot_unlocked(1), "the second slot opens on completion")

	# --- the content cap
	_level_to(60)
	_expect(not prog.is_beyond_content(), "level 60 is still inside the designed range")
	_expect(is_equal_approx(prog.beyond_bonus(), 0.0), "no tail bonus before the cap")
	var offered_at_cap: int = prog.available_unlock_quests().size()
	_level_to(75)
	_expect(prog.is_beyond_content(), "levelling continues past 60")
	_expect(prog.available_unlock_quests().size() == offered_at_cap, "no new unlocks past the cap")
	var at_75: float = prog.beyond_bonus()
	_expect(at_75 > 0.0, "past the cap each level grants a small buff (%.3f at 75)" % at_75)
	_level_to(120)
	var at_120: float = prog.beyond_bonus()
	_expect(at_120 > at_75, "the tail keeps growing")
	var first_15: float = at_75
	var next_45: float = at_120 - at_75
	_expect(next_45 < first_15, "but with diminishing returns (%.3f over 45 levels vs %.3f over the first 15)" % [next_45, first_15])
	_expect(at_120 < 0.15, "the tail stays small (%.3f)" % at_120)

	# --- save / load
	var saved: Dictionary = prog.to_dict()
	var level_before: int = prog.level
	prog.reset()
	_expect(prog.level == 1, "reset clears progression")
	prog.from_dict(saved)
	_expect(prog.level == level_before and prog.completed_unlock_quests().size() == 2,
		"level and finished unlock quests survive a save and load")

	prog.reset(); traits.reset()
	print("PROGRESSION_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
