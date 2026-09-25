extends SceneTree
## The opening: a new game starts at the bedroom mirror with the creator beside the character, the character is the
## real one in the room, and confirming walks the player out of the house and returns control.
## Screenshots in user://intro_test/.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	ToriyamaRoster.clear_recipe()
	var out := ProjectSettings.globalize_path("user://intro_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(150)

	var intro = main.find_child("IntroSequence", true, false)
	var creator = root.find_child("CharacterCreator", true, false)
	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var mirror = main.find_child("HomeMirror", true, false)
	_expect(intro != null, "a new game starts the intro")
	_expect(creator != null and creator.in_world, "the creator opens in the world, not on a menu screen")
	_expect(mirror != null and mirror.global_position.distance_to(player.global_position) < 2.5,
		"the player is standing at the bedroom mirror")
	_expect(player.input_locked, "movement is locked while choosing")
	if creator == null:
		print("INTRO_TEST FAIL ", failures)
		quit(1)
		return
	_expect(creator._character == player.get_node("Body").model, "the creator edits the character in the room")
	await _frames(10)
	root.get_texture().get_image().save_png(out + "mirror.png")

	# make a couple of choices, exactly as the buttons do
	creator._show_category("Hair")
	await _frames(6)
	root.get_texture().get_image().save_png(out + "hair.png")
	creator._character.set_hair_colors({"color": CreatorData.HAIR_COLORS["Blonde"], "accent": CreatorData.HAIR_COLORS["Blonde"]})
	creator.recipe["hair"] = creator._character.recipe["hair"]
	creator.recipe["name"] = "Opening Test"
	await _frames(8)
	root.get_texture().get_image().save_png(out + "changed.png")

	# confirm: camera pulls back, the player walks out, control returns
	creator._finish()
	await _frames(30)
	root.get_texture().get_image().save_png(out + "pull_back.png")
	var waited := 0
	while main.find_child("IntroSequence", true, false) != null and waited < 600:
		await _frames(5)
		waited += 5
	await _frames(20)
	root.get_texture().get_image().save_png(out + "outside.png")

	var outside: Vector3 = root.get_node("WorldState").get_location_position("home_player")
	_expect(player.global_position.distance_to(outside) < 6.0, "the player ends up outside their house")
	_expect(not player.input_locked, "control is handed back")
	_expect(player.camera.current, "the player's own camera is back")
	_expect(not ToriyamaRoster.saved_recipe().is_empty(), "the character is saved")
	_expect(String(ToriyamaRoster.saved_recipe().get("name", "")) == "Opening Test", "the saved character is the one made")
	ToriyamaRoster.clear_recipe()
	print("INTRO_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures), " out=", out)
	quit(0 if failures.is_empty() else 1)
