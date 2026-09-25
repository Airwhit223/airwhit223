extends SceneTree
## Does the second blade actually exist on the left hand, and does it go away again?
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var score := {"pass": 0, "fail": 0}
	var check := func(label: String, ok: bool, extra := ""):
		score["pass" if ok else "fail"] += 1
		print(("  ok   " if ok else "  FAIL ") + label + ("  " + extra if extra != "" else ""))
	var world := Node3D.new(); root.add_child(world)
	var rig := CharacterRig.new()
	rig.toriyama_recipe = CreatorData.default_recipe()
	world.add_child(rig)
	for i in 12: await process_frame
	var kit = null
	for c in rig.find_children("*", "ToriyamaKitCharacter", true, false): kit = c
	check.call("the kit character exists", kit != null)

	var blades := func() -> Dictionary:
		var out := {"r": 0, "l": 0}
		for att: BoneAttachment3D in kit.skeleton.find_children("*", "BoneAttachment3D", false, false):
			for mi: MeshInstance3D in att.find_children("*", "MeshInstance3D", true, false):
				if not String(mi.name).begins_with("TR_Katana"): continue
				if att.bone_name == "SOCKET-hand.R": out["r"] += 1
				elif att.bone_name == "SOCKET-hand.L": out["l"] += 1
		return out

	kit.set_weapon("Classic", "hip", {}, false)
	kit.set_weapon_drawn(true)
	for i in 4: await process_frame
	var single: Dictionary = blades.call()
	print("   single: ", single)
	check.call("one blade, main hand only", single["r"] == 1 and single["l"] == 0)

	kit.set_weapon("Classic", "hip", {}, true)
	kit.set_weapon_drawn(true)
	for i in 4: await process_frame
	var pair: Dictionary = blades.call()
	print("   dual:   ", pair)
	check.call("a blade in each hand", pair["r"] == 1 and pair["l"] == 1)

	kit.set_weapon("Classic", "hip", {}, false)
	kit.set_weapon_drawn(true)
	for i in 4: await process_frame
	var back: Dictionary = blades.call()
	print("   back:   ", back)
	check.call("dropping the pair removes the off-hand blade", back["r"] == 1 and back["l"] == 0)

	kit.set_weapon("")
	for i in 4: await process_frame
	var none: Dictionary = blades.call()
	check.call("sheathing removes both", none["r"] == 0 and none["l"] == 0, str(none))

	print("\n%d passed, %d failed" % [score["pass"], score["fail"]])
	quit(1 if int(score["fail"]) > 0 else 0)
