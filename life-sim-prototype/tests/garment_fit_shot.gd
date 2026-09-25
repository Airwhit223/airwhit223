extends SceneTree
## Garment fit check (user screenshots 2026-09-23): a CharacterRig with the kit character in a tee or a tank top +
## denim jeans + grey sneakers, neutral light, driven by the game's own walk cycle. Standing front / back / side,
## then several mid-stride frames from the side and back. Saves user://garment_fit/<outfit>_<view>.png.

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	var out := ProjectSettings.globalize_path("user://garment_fit/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var cam := Camera3D.new(); world.add_child(cam)
	var outfits := {
		"tee": {"Shirt_Casual_01": {"top": "#EFE9DC"}, "TR_Baggy_Jeans": {"bottom": "#4F6A8C"}, "Shoes_Sneaker_01": {"shoe": "#6E7078"}},
		"tank": {"Mechanic_Work_Tank": {"top": "#EFE9DC"}, "TR_Baggy_Jeans": {"bottom": "#4F6A8C"}, "Shoes_Sneaker_01": {"shoe": "#6E7078"}},
	}
	for outfit in outfits:
		var rig := CharacterRig.new()
		var r := CreatorData.default_recipe()
		r["garments"] = []
		for part in outfits[outfit]:
			r["garments"].append({"part": part, "colors": outfits[outfit][part]})
		r["hair"]["cut"] = ""
		rig.toriyama_recipe = r
		world.add_child(rig)
		await _frames(10)
		for k in 20:
			rig.animate(1.0 / 60.0, 0.0, true, "normal")
		for view in [["front", 0.0, 1.2, 1.6], ["back", 180.0, 1.0, 2.4], ["side", 90.0, 0.9, 2.4]]:
			var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(float(view[1])))
			var aim := Vector3(0, float(view[2]), 0)
			cam.global_position = aim + dir * float(view[3])
			cam.look_at(aim)
			cam.current = true
			await _frames(6)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, outfit, view[0]])
		# walk cycle: advance the rig's own gait at walking speed and shoot at a few phases
		for k in 4:
			for s in 11:
				rig.animate(1.0 / 60.0, 3.5, true, "normal")
			var dir2 := Vector3(1, 0, 0) if k % 2 == 0 else Vector3(0, 0, 1)
			cam.global_position = Vector3(0, 0.75, 0) + dir2 * 2.3
			cam.look_at(Vector3(0, 0.75, 0))
			await _frames(3)
			root.get_texture().get_image().save_png("%s%s_walk%d.png" % [out, outfit, k])
		rig.queue_free()
		await _frames(3)
	print("OUT ", out)
	print("GARMENT_FIT_SHOT done")
	quit(0)
