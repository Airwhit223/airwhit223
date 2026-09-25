extends SceneTree
## Lineup render of every breed, plus a behaviour check on the two canonical pets.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-42, -132, 0); world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.83, 0.86, 0.88)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	root.get_node("RetroPS2").apply(&"off")
	var ground := StaticBody3D.new(); world.add_child(ground)
	var gm := MeshInstance3D.new(); var plane := BoxMesh.new(); plane.size = Vector3(40, 0.4, 20)
	gm.mesh = plane; gm.position = Vector3(0, -0.2, 0); ground.add_child(gm)
	var gs := CollisionShape3D.new(); var gb := BoxShape3D.new(); gb.size = Vector3(40, 0.4, 20)
	gs.shape = gb; gs.position = Vector3(0, -0.2, 0); ground.add_child(gs)
	var out := ProjectSettings.globalize_path("user://pets/")
	DirAccess.make_dir_recursive_absolute(out)
	var breeds := ["husky", "maine_coon"]
	var pets: Array = []
	for i in breeds.size():
		var packed: PackedScene = load("res://pets/%s.tscn" % breeds[i])
		if packed == null:
			print("MISSING ", breeds[i]); continue
		var pet = packed.instantiate()
		world.add_child(pet)
		pet.global_position = Vector3(-0.9 + i * 1.8, 0.05, 0.0)
		pet.rotation.y = PI * 0.5
		pets.append(pet)
	await _frames(20)
	print("PETS spawned=", pets.size(), " names=", pets.map(func(p): return p.display_name))
	# a character beside them, because the sheet's whole point is scale
	var rig := CharacterRig.new(); world.add_child(rig)
	rig.set_toriyama_recipe(CreatorData.default_recipe())
	await _frames(12)
	rig.global_position = Vector3(-2.7, 0, 0)
	for i in 30:
		rig.animate(1.0 / 60.0, 0.0, true)
		await _frames(1)
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.fov = 34
	cam.global_position = Vector3(-0.4, 0.95, 5.6); cam.look_at(Vector3(-0.4, 0.62, 0))
	await _frames(4)
	root.get_texture().get_image().save_png(out + "scale.png")
	# close on the two canon pets
	for v in [["side", Vector3(-0.9, 0.55, 2.4), Vector3(-0.9, 0.38, 0.0)],
			["front", Vector3(-0.9 - 2.2, 0.55, 0.0), Vector3(-0.9, 0.38, 0.0)]]:
		cam.global_position = v[1]; cam.look_at(v[2])
		await _frames(3)
		root.get_texture().get_image().save_png(out + "husky_%s.png" % v[0])
	cam.global_position = Vector3(0.9, 0.45, 1.9); cam.look_at(Vector3(0.9, 0.28, 0.0))
	await _frames(3)
	root.get_texture().get_image().save_png(out + "coon_side.png")
	# behaviour: bonds are per player, and the dog prefers whoever pets it
	var husky = pets[0]
	for pet in pets:
		var box := AABB()
		var first := true
		for mi in pet.find_children("*", "MeshInstance3D", true, false):
			var w = mi.global_transform * mi.mesh.get_aabb()
			box = w if first else box.merge(w)
			first = false
		print("SIZE %s  back_height=%.2f m  length=%.2f m  origin_y=%.2f" % [
			pet.display_name, box.position.y + box.size.y, box.size.z, pet.global_position.y])
	var rig_box := AABB(); var rf := true
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null: continue
		var w2 = mi.global_transform * mi.mesh.get_aabb()
		rig_box = w2 if rf else rig_box.merge(w2)
		rf = false
	print("SIZE Character height=%.2f m" % (rig_box.position.y + rig_box.size.y))
	print("BOND default=", husky.bond_with("arin"))
	husky.pet_by("arin"); husky.pet_by("arin"); husky.pet_by("arin")
	husky.pet_by("jace")
	print("BOND arin=%.0f jace=%.0f mood=%.2f" % [husky.bond_with("arin"), husky.bond_with("jace"), husky.mood])
	var coon = pets[1]
	coon.pet_by("jace")
	print("CAT bond per pet=%.0f (dog gains %.0f)" % [coon.bond_with("jace") - 25.0, husky.bond_with("jace") - 25.0])
	husky.feed_by("theo")
	print("FED hunger=%.0f theo bond=%.0f" % [husky.hunger, husky.bond_with("theo")])
	print("PETS done -> ", out)
	quit()
