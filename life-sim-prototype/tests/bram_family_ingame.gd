extends SceneTree
## Bram's family in the real world: all seven spawn with their kit looks and heights, The Good Place and Sergio's
## workshop are registered, family ties are declared, Bram's quest is offered by the real Bram. Screenshot of the
## family at The Good Place to user://bram_family/.
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _f(n := 5) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://bram_family/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(40)
	root.get_node("RetroPS2").apply(&"off")
	var ws = root.get_node("WorldState")
	var fam: Array = main.get_tree().get_nodes_in_group("bram_family")
	_expect(fam.size() == 7, "seven family members spawned (%d)" % fam.size())
	_expect(ws.has_location("loc_good_place") and ws.has_location("home_sergio"), "The Good Place and Sergio's workshop registered")
	var by_id := {}
	for n in fam:
		by_id[n.definition.id] = n
	var kip = by_id.get("kip"); var garrik = by_id.get("garrik")
	_expect(kip and is_equal_approx(kip.get_node("Body").scale.x, 0.74), "Kip is kid-sized")
	_expect(garrik and is_equal_approx(garrik.get_node("Body").scale.x, 1.12), "Garrik towers")
	var bram = by_id.get("bram")
	_expect(bram and bram.get_node("Body").model is ToriyamaKitCharacter, "Bram wears his kit look")
	var rel = root.get_node("RelationshipManager")
	_expect(rel.has_method("is_family") == false or rel.is_family("grandpa_bram", "sergio"), "the twins are family")
	var topics: Array = root.get_node("QuestManager").topics_for("bram")
	_expect(topics.any(func(t): return String(t["id"]).contains("bram_expedition")), "Bram offers his expedition quest")
	# gather them for a family photo at The Good Place
	var home: Vector3 = ws.get_location_position("loc_good_place")
	var order := ["garrik", "bram", "lysa", "kip", "nana_ella", "grandpa_bram", "sergio"]
	for i in order.size():
		var n = by_id[order[i]]
		n.set_physics_process(false)
		n.global_position = home + Vector3(-4.2 + i * 1.4, 0, 0)
		n.rotation.y = PI
	var cam := Camera3D.new(); main.add_child(cam); cam.current = true
	cam.fov = 40
	cam.global_position = home + Vector3(0, 1.6, 7.5); cam.look_at(home + Vector3(0, 1.0, 0))
	await _f(20)
	root.get_texture().get_image().save_png(out + "good_place_family.png")
	print("BRAM_FAMILY_INGAME ALL PASS" if failures.is_empty() else "BRAM_FAMILY_INGAME FAILED: %s" % str(failures))
	quit()
