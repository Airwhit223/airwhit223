extends SceneTree
## Sheet build (ToriyamaKitCharacter.set_sheet_build): the stocky character-sheet body. Checks the SB_Sheet_* shapes
## ship on the body and garments, that only the base's own key is driven, and saves 0-vs-1 renders to
## user://sheet_build_test/ for a visual check.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

func _value(ch: Node, mesh_name: String, shape: String) -> float:
	for mi in ch.find_children("*", "MeshInstance3D", true, false):
		if mesh_name in String(mi.name):
			var i: int = mi.find_blend_shape_by_name(shape)
			if i >= 0:
				return mi.get_blend_shape_value(i)
	return -1.0

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
	var out := ProjectSettings.globalize_path("user://sheet_build_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new(); world.add_child(cam)
	var dressed := [{"part": "TR_Hooded_Jacket", "colors": {}}, {"part": "TR_Baggy_Jeans", "colors": {}},
		{"part": "Shoes_Sneaker_01", "colors": {}}]
	for base in ["M", "F"]:
		for outfit in ["bare", "dressed"]:
			for sb in [0.0, 1.0]:
				var ch := ToriyamaKitCharacter.new()
				world.add_child(ch)
				ch.apply_recipe({"base": base, "hair": {"cut": ""}, "sheet_build": sb,
					"garments": dressed if outfit == "dressed" else []})
				var own: String = "SB_Sheet_" + base
				var other: String = "SB_Sheet_" + ("F" if base == "M" else "M")
				_expect(is_equal_approx(_value(ch, "Body", own), sb), "%s %s: body %s = %.1f" % [base, outfit, own, sb])
				_expect(_value(ch, "Body", other) <= 0.0, "%s %s: other base's key held at 0" % [base, outfit])
				if outfit == "dressed":
					_expect(is_equal_approx(_value(ch, "TR_Baggy_Jeans", own), sb), "%s: jeans follow (%s = %.1f)" % [base, own, sb])
				await _frames(20)
				for view in [["front", Vector3(0, 0.9, -3.4)], ["side", Vector3(3.4, 0.9, 0)]]:
					cam.global_position = view[1]
					cam.look_at(Vector3(0, 0.85, 0))
					cam.current = true
					await _frames(4)
					root.get_texture().get_image().save_png("%s%s_%s_sb%d_%s.png" % [out, base, outfit, int(sb), view[0]])
				ch.queue_free()
				await _frames(2)
	print("OUT ", out)
	print("SHEET_BUILD_TEST ", "FAILED: %s" % failures if failures else "ALL PASS")
	quit(1 if failures else 0)
