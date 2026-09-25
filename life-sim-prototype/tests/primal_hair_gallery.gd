extends SceneTree
## Gallery: several hairstyles, each normal / Controlled / Uncontrolled Primal (user://primal_gallery/).
const CUTS := ["RT_M_Straight_Medium", "RT_M_Spiky_Medium", "F_Base_Long", "F_Base_High_Ponytail", "Box_Braids", "Locs",
	"Twists_To_TwistOut", "RT_F_Curly_Long"]
func _initialize() -> void: _run.call_deferred()
func _f(n: int) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://primal_gallery/")
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.18, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var cam := Camera3D.new(); world.add_child(cam)
	var missing := 0
	for cut in CUTS:
		var rig := CharacterRig.new()
		var r := CreatorData.default_recipe()
		r["hair"]["cut"] = cut
		r["base"] = "F" if cut.begins_with("F_") or cut.begins_with("RT_F") else "M"
		r["garments"] = []
		rig.toriyama_recipe = r
		world.add_child(rig)
		await _f(6)
		for k in 10: rig.animate(1.0 / 60.0, 0.0, true, "normal")
		var ch: ToriyamaCharacter = rig.model
		for state in ["normal", "controlled", "dark"]:
			var pf: PrimalForm = null
			if state != "normal":
				pf = PrimalForm.begin(ch, state == "dark")
				for k in 45:
					await process_frame
				if not String(ch.recipe["hair"]["cut"]).ends_with("__Bolt" if state == "dark" else "__Loose"):
					missing += 1
					print("MISSING primal cut for ", cut, " ", state)
			var eye := ch.eye_world_position()
			cam.global_position = eye + Vector3(0.35, 0.05, -0.9)
			cam.look_at(eye + Vector3(0, 0.06, 0))
			cam.current = true
			await _f(3)
			root.get_texture().get_image().save_png("%s%s_%s.png" % [out, cut, state])
			if pf:
				pf.end(true)
				await _f(2)
		rig.queue_free()
		await _f(2)
	print("GALLERY_DONE missing=", missing)
	quit()
