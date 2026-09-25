extends SceneTree
## Character creator, end to end: a new game opens it, choices rebuild the preview live, confirming rebuilds the
## player from kit parts, and the look is remembered for the next session. Screenshots in user://creator_test/.

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ToriyamaRoster.PLAYER_LOOK_SAVE))
	var out := ProjectSettings.globalize_path("user://creator_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(150)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# a brand new game plays the opening at the mirror (see intro_sequence_test); this test covers the creator
	# itself, opened the way the mirror opens it
	var player_node: Node3D = root.get_tree().get_first_node_in_group("player")
	var intro = main.find_child("IntroSequence", true, false)
	if intro:
		intro.queue_free()
	var existing = root.find_child("CharacterCreator", true, false)
	if existing:
		existing.queue_free()
		await _frames(4)
	var mirror_node = main.find_child("HomeMirror", true, false)
	player_node.global_position = mirror_node.global_position + Vector3(0, 0.1, 1.9)
	player_node.open_creator(true, mirror_node)
	await _frames(10)
	var creator = root.find_child("CharacterCreator", true, false)
	_expect(creator != null, "the mirror opens the character creator")
	if creator == null:
		print("CREATOR_TEST FAIL ", failures)
		quit(1)
		return
	_expect(creator.in_world and creator.target_rig != null, "it edits the character standing at the mirror")
	_expect(player_node.input_locked, "movement is locked while creating")
	await _frames(10)
	root.get_texture().get_image().save_png(out + "creator_body.png")

	# walk the categories, and make some choices through the same calls the buttons use
	for category in ["Face", "Hair", "Clothes", "Movement"]:
		creator._show_category(category)
		await _frames(6)
		root.get_texture().get_image().save_png(out + "creator_%s.png" % category.to_lower())
	var character = creator._character
	creator.recipe["base"] = "F"
	creator._rebuild_character()
	await _frames(20)
	character = creator._character
	_expect(character.recipe["base"] == "F", "switching base rebuilds the preview")
	character.set_skin(CreatorData.SKIN_TONES["Deep"])
	creator.recipe["skin"] = CreatorData.SKIN_TONES["Deep"]
	character.set_hair_style("F_Base_High_Ponytail", "Curtain", "")
	character.set_hair_colors({"color": CreatorData.HAIR_COLORS["Magenta"], "accent": CreatorData.HAIR_COLORS["Magenta"]})
	creator.recipe["hair"] = character.recipe["hair"]
	character.set_garment("outerwear", "TR_Varsity_Jacket", {"outer": CreatorData.GARMENT_COLORS["Teal"]})
	creator.recipe["garments"] = character.recipe["garments"]
	creator.recipe["movement"] = "athletic"
	creator.recipe["name"] = "Test Hero"
	await _frames(20)
	root.get_texture().get_image().save_png(out + "creator_edited.png")
	_expect(character.recipe["hair"]["cut"] == "F_Base_High_Ponytail" and character.recipe["hair"]["bangs"] == "Curtain",
		"hair style + bangs applied live")
	_expect(character.hair_meshes.size() > 0, "hair meshes present after the style change")

	# confirm: the player is rebuilt from the recipe
	creator._finish()
	await _frames(60)
	var player: Node3D = player_node
	_expect(not player.input_locked, "control returns after confirming")
	var rig = player.get_node("Body")
	_expect(rig.model is ToriyamaKitCharacter, "player wears the created character")
	_expect(rig.toriyama_recipe.get("name", "") == "Test Hero", "the player's recipe is the one created")
	_expect(rig.movement_style == "athletic", "movement style applied to the rig")
	_expect(not ToriyamaRoster.saved_recipe().is_empty(), "the look is saved for next time")

	# walk a few frames so the created body animates, then look at it
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	var cam := Camera3D.new()
	player.add_child(cam)
	var fwd: Vector3 = -rig.global_transform.basis.z
	cam.global_position = rig.global_position + fwd * 2.2 + Vector3(0, 1.3, 0)
	cam.look_at(rig.global_position + Vector3(0, 1.0, 0))
	cam.current = true
	await _frames(12)
	root.get_texture().get_image().save_png(out + "player_created.png")

	# the mirror reopens it, and this time cancelling is allowed
	var mirror = main.find_child("HomeMirror", true, false)
	_expect(mirror != null, "mirror stands at the player's home")
	if mirror:
		mirror.interact(player)
		await _frames(20)
		var again = root.find_child("CharacterCreator", true, false)
		_expect(again != null and again.allow_cancel, "the mirror reopens the creator (cancel allowed)")
		if again:
			again.cancelled.emit()
			again.queue_free()
	ToriyamaRoster.clear_recipe()
	print("CREATOR_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures), " out=", out)
	quit(0 if failures.is_empty() else 1)
