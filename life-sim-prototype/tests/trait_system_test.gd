extends SceneTree
## The trait framework: slots, unlocks, and how a combination resolves. No content is asserted here — the real trait
## list lands later; what matters is that any combination produces one deterministic answer.

var failures: Array[String] = []
var traits

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _initialize() -> void:
	_run.call_deferred()        # autoloads are not on the tree yet inside _initialize

func _run() -> void:
	traits = root.get_node("TraitSystem")
	traits.reset()

	# --- slots
	_expect(traits.slots_open()["start"] == 3, "three starting slots")
	_expect(traits.slots_open()["power"] == 0, "power slots start locked")
	traits.choose_starting([&"warm", &"restless", &"careful", &"scrappy"])
	_expect(traits.active().size() == 3, "only three starting traits are taken")
	_expect(not traits.set_power_trait(0, &"unshaken"), "a locked power slot cannot be filled")
	_expect(traits.unlock_power_slot(0), "a power slot unlocks (through its quest)")
	_expect(not traits.unlock_power_slot(0), "unlocking twice does nothing")
	_expect(traits.set_power_trait(0, &"unshaken"), "an unlocked power slot takes a trait")
	_expect(traits.active().has(&"unshaken"), "the power trait is active")
	traits.grant_achievement_slot(&"first_friend", &"known_face")
	_expect(traits.slots_open()["achievement"] == 1 and traits.active().has(&"known_face"),
		"an achievement grants a slot and can fill it")

	# --- additive fallback: traits with no pairing just add up
	traits.reset()
	traits.choose_starting([&"careful", &"scrappy"])
	var careful: float = traits.definition(&"careful").effects["move.speed"]
	var expected := careful + 0.0
	_expect(is_equal_approx(traits.effect("move.speed"), expected), "unpaired traits add together")
	_expect(is_equal_approx(traits.effect("combat.damage"), traits.definition(&"scrappy").effects["combat.damage"]),
		"a key only one trait touches comes through unchanged")
	_expect(is_equal_approx(traits.effect("nothing.here", 1.0), 1.0), "an unknown key returns the default")

	# --- bespoke pairing replaces both traits' own numbers for the keys it defines
	traits.reset()
	traits.choose_starting([&"warm", &"restless"])
	var solo_sum: float = traits.definition(&"warm").effects["relationship.gain_rate"] \
		+ traits.definition(&"restless").effects.get("relationship.gain_rate", 0.0)
	_expect(is_equal_approx(traits.effect("relationship.gain_rate"), 0.35),
		"the pairing's number wins over the sum (%.2f, not %.2f)" % [traits.effect("relationship.gain_rate"), solo_sum])
	_expect(is_equal_approx(traits.effect("focus.study"), 0.0), "a pairing can cancel a trait's downside")
	_expect(is_equal_approx(traits.effect("event.invite_success"), 0.2), "a pairing can add a key neither trait had")
	_expect(is_equal_approx(traits.effect("trade.price"), traits.definition(&"warm").effects["trade.price"]),
		"keys the pairing does not mention still add normally")
	_expect(traits.has_tag(&"ringleader"), "a pairing can add its own tag")

	# --- a third trait keeps contributing alongside a pairing
	traits.reset()
	traits.choose_starting([&"warm", &"restless", &"careful"])
	_expect(is_equal_approx(traits.effect("focus.study"), traits.definition(&"careful").effects["focus.study"]),
		"an unpaired third trait still adds")

	# --- order must not matter
	traits.reset()
	traits.choose_starting([&"restless", &"warm", &"careful"])
	var a: Dictionary = traits.effects()
	traits.reset()
	traits.choose_starting([&"careful", &"warm", &"restless"])
	var b: Dictionary = traits.effects()
	var same: bool = a.size() == b.size()
	for key in a:
		if not b.has(key) or not is_equal_approx(float(a[key]), float(b[key])):
			same = false
	_expect(same, "the result does not depend on the order traits were chosen")

	# --- tags for dialogue, never a UI list
	_expect(traits.has_tag(&"kind") and traits.has_tag(&"cautious"), "tags come through for dialogue to read")
	_expect(traits.multiplier("relationship.gain_rate") > 1.0, "multiplier() wraps a bonus for callers")

	# --- save / load
	traits.reset()
	traits.choose_starting([&"tinkerer", &"careful"])
	traits.unlock_power_slot(1)
	traits.set_power_trait(1, &"quick_study")
	var saved: Dictionary = traits.to_dict()
	var before: float = traits.effect("repair.quality")
	traits.reset()
	_expect(is_equal_approx(traits.effect("repair.quality"), 0.0), "reset clears everything")
	traits.from_dict(saved)
	_expect(is_equal_approx(traits.effect("repair.quality"), before), "traits survive a save and load")
	_expect(traits.is_power_slot_unlocked(1) and traits.active().has(&"quick_study"), "unlocked slots survive too")
	_expect(is_equal_approx(before, 0.45), "careful + tinkerer uses its bespoke pairing")

	# --- the effects are live in play: movement speed reads the trait total
	traits.reset()
	traits.choose_starting([&"restless"])
	var fast: float = traits.multiplier("move.speed")
	traits.reset()
	traits.choose_starting([&"careful"])
	var slow: float = traits.multiplier("move.speed")
	_expect(fast > 1.0 and slow < 1.0 and fast > slow, "movement speed differs by trait (%.2f vs %.2f)" % [fast, slow])

	traits.reset()
	print("TRAIT_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
