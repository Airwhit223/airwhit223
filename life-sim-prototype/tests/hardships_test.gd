extends SceneTree
## Dream-remnant storylines: struggling townsfolk, a minority with a supernatural cause that is not flagged in
## advance, discovered through clues, and a remnant storyline resolved earns a companion.

var failures: Array[String] = []
var h

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	h = root.get_node("Hardships")
	h.reset()
	var ids: Array = []
	for i in 40:
		ids.append("town_%02d" % i)
	h.assign(ids, 7, 0.6)
	var struggling: Array = h.struggling()
	var remnants: int = h.remnant_count()
	_expect(struggling.size() > 10, "some townsfolk are struggling (%d of 40)" % struggling.size())
	_expect(remnants >= 1, "at least one struggle has a Dream Realm cause (%d)" % remnants)
	_expect(float(remnants) <= float(struggling.size()) * h.REMNANT_SHARE + 1.0,
		"remnant causes stay a minority (%d of %d)" % [remnants, struggling.size()])

	# --- nothing is flagged in advance: remnant and ordinary look the same on the surface
	var remnant_id := ""
	var mundane_id := ""
	for id in struggling:
		var entry: Dictionary = h._hardships[id]
		if entry["remnant"] and remnant_id == "":
			remnant_id = id
		elif not entry["remnant"] and mundane_id == "":
			mundane_id = id
	var same_symptom := ""
	for id in struggling:
		if not h._hardships[id]["remnant"] and h._hardships[id]["symptom"] == h._hardships[remnant_id]["symptom"]:
			same_symptom = id
	if same_symptom != "":
		_expect(h.surface(remnant_id) == h.surface(same_symptom), "the same symptom reads identically whatever the cause")
	_expect(h.is_remnant(remnant_id) == null, "before investigating, the cause cannot be read at all")

	# --- clues: the early ones read the same; the last one tells them apart
	var first_r: String = h.investigate(remnant_id)
	_expect(first_r != "" and not h.is_revealed(remnant_id), "one clue is not enough")
	h.investigate(remnant_id)
	var last_r: String = h.investigate(remnant_id)
	_expect(h.is_revealed(remnant_id), "three clues reveal the cause")
	_expect(h.is_remnant(remnant_id) == true, "and it was a remnant")
	_expect(h.investigate(remnant_id) == "", "no clues after the cause is known")
	for i in 3:
		h.investigate(mundane_id)
	_expect(h.is_remnant(mundane_id) == false, "an ordinary hardship reveals as ordinary")

	# --- resolving: only after the reveal; only remnant storylines earn a companion
	var fresh := ""
	for id in struggling:
		if not h.is_revealed(id) and id != remnant_id and id != mundane_id:
			fresh = id
			break
	_expect(not h.resolve(fresh), "a hardship cannot be resolved before its cause is known")
	_expect(h.resolve(mundane_id), "an ordinary hardship can be helped")
	_expect(not h.recruitable_companions().has(mundane_id), "helping with an ordinary hardship does not make a companion")
	_expect(h.resolve(remnant_id), "a remnant storyline can be resolved")
	_expect(h.recruitable_companions().has(remnant_id), "resolving it makes them recruitable")
	_expect(not h.has_hardship(remnant_id), "and their struggle is over")

	# --- stable and saveable
	var saved: Dictionary = h.to_dict()
	h.reset()
	h.from_dict(saved)
	_expect(h.recruitable_companions().has(remnant_id), "companions survive a save and load")
	h.reset()
	h.assign(ids, 7, 0.6)
	var again: Array = h.struggling()
	_expect(again.size() == struggling.size(), "the same seed gives the town the same struggles")

	h.reset()
	print("HARDSHIPS_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures))
	quit(0 if failures.is_empty() else 1)
