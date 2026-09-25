extends SceneTree
## Character-creator kit: assembles recipes from parts and checks recolouring works, saving renders to
## user://kit_test/. Proves one baked part can be any colour (skin, hair, clothes) without re-exporting.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42, 35, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.27, 0.29, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.66)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var out := ProjectSettings.globalize_path("user://kit_test/")
	DirAccess.make_dir_recursive_absolute(out)

	_expect(ToriyamaKitCharacter.list_parts("base").size() >= 2, "both base bodies in the kit")
	_expect(ToriyamaKitCharacter.list_parts("garment").size() >= 2, "garments in the kit")

	var recipes := {
		"a_default": {"base": "M", "skin": "#CE9872", "eye": "#784624", "eye_style": 0.35,
			"hair": {"cut": "F_Base_Long", "bangs": "Curtain", "color": "#3A2419", "accent": "#3A2419"},
			"garments": [{"part": "TR_Hooded_Jacket", "colors": {}}, {"part": "TR_Baggy_Jeans", "colors": {}}]},
		"b_recolored": {"base": "M", "skin": "#704836", "eye": "#2E66BA", "eye_style": 0.9,
			"hair": {"cut": "F_Base_High_Ponytail", "bangs": "Blunt", "color": "#D8B36A", "accent": "#D8B36A", "tie": "#B8326E"},
			"garments": [{"part": "TR_Hooded_Jacket", "colors": {"outer": "#2E8C8C", "top_trim": "#EFE3D2", "metal": "#C9CED8"}},
				{"part": "TR_Baggy_Jeans", "colors": {"bottom": "#B8326E", "bottom_trim": "#3A2A2E"}}]},
		"c_female": {"base": "F", "skin": "#F6D6C0", "eye": "#8C48B4", "eye_style": 0.1,
			"hair": {"cut": "F_Base_Bob", "bangs": "Wispy", "color": "#1E1A1A"},
			"build": {"Body_Athletic": 0.6},
			"garments": [{"part": "TR_Hooded_Jacket", "colors": {"outer": "#1A1618"}}]},
		"d_no_clothes": {"base": "F", "skin": "#9E6C52", "eye": "#3E8446", "hair": {"cut": ""}, "garments": []},
	}
	var cam := Camera3D.new(); world.add_child(cam)
	for key in recipes:
		var ch := ToriyamaKitCharacter.new()
		world.add_child(ch)
		ch.apply_recipe(recipes[key])
		_expect(ch.skeleton != null, "%s assembled on a skeleton" % key)
		var wanted: int = int(recipes[key].get("garments", []).size())
		var garment_roots: Array = ch.find_children("Garment_*", "Node3D", false, false)
		_expect(garment_roots.size() == wanted, "%s has %d garment part(s)" % [key, wanted])
		await _frames(30)
		for view in [["face", Vector3(0, 1.55, -0.85), Vector3(0, 1.5, 0)], ["body", Vector3(0, 1.1, -2.6), Vector3(0, 1.0, 0)]]:
			cam.global_position = view[1]
			cam.look_at(view[2])
			cam.current = true
			await _frames(10)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, key, view[0]])
		ch.queue_free()
		await _frames(4)
	# swapping parts must REPLACE them: a part's meshes move onto the shared skeleton, so freeing only the part's
	# original root used to leave the old hairstyle in place under the new one
	var swap := ToriyamaKitCharacter.new()
	world.add_child(swap)
	swap.apply_recipe({"base": "F", "hair": {"cut": "F_Base_Long", "bangs": "Curtain", "color": "#3A2419"},
		"garments": [{"part": "Shirt_Casual_01", "colors": {}}]})
	await _frames(10)
	for cut in ["F_Base_Bob", "F_Base_High_Ponytail", "F_Base_Twin_Tails", "RT_M_Curly_Short"]:
		swap.set_hair_style(cut, "Blunt" if cut.begins_with("F_Base_") else "", "")
		await _frames(4)
	var hair_left := 0
	for mi in swap.skeleton.find_children("Hair_*", "MeshInstance3D", true, false):
		if not mi.is_queued_for_deletion():
			hair_left += 1
	_expect(hair_left == 3, "after four hair swaps only the current style's three growth meshes remain (%d)" % hair_left)
	for part in ["TR_Hooded_Jacket", "TR_Varsity_Jacket", "TR_Blazer"]:
		swap.set_garment("outerwear", part, {})
		await _frames(4)
	var jackets := 0
	for name in ["TR_Hooded_Jacket", "TR_Varsity_Jacket", "TR_Blazer"]:
		var found = swap.skeleton.find_child(name, true, false)
		if found and not found.is_queued_for_deletion():
			jackets += 1
	_expect(jackets == 1, "after three jacket swaps only one jacket is worn (%d)" % jackets)
	swap.queue_free()
	await _frames(4)

	# eye shape presets: each one is its own face shape, shown in a face close-up
	var eyes := ToriyamaKitCharacter.new()
	world.add_child(eyes)
	eyes.apply_recipe({"base": "M", "skin": CreatorData.SKIN_TONES["Tan"], "eye": CreatorData.EYE_COLORS["Brown"],
		"hair": {"cut": "RT_M_Curly_Short", "color": CreatorData.HAIR_COLORS["Chestnut"]}, "garments": []})
	await _frames(30)
	for preset in ToriyamaKitCharacter.EYE_PRESETS:
		eyes.set_eye_preset(preset)
		_expect(eyes.recipe["eye_preset"] == preset, "eye preset %s applied" % preset)
		cam.global_position = Vector3(0, 1.54, -0.8)
		cam.look_at(Vector3(0, 1.5, 0))
		cam.current = true
		await _frames(8)
		root.get_texture().get_image().save_png("%seyes_%s.png" % [out, preset])
	eyes.queue_free()
	print("KIT_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures), " out=", out)
	quit(0 if failures.is_empty() else 1)
