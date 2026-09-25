extends SceneTree
## What the water in the live world actually looks like right now, before any change. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 6) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await _frames(60)
	# what is the water made of?
	var found: Array[String] = []
	for n: Node in world.find_children("*", "MeshInstance3D", true, false):
		var lower := String(n.name).to_lower()
		if "water" in lower or "ocean" in lower or "sea" in lower or "pond" in lower or "river" in lower:
			var mi := n as MeshInstance3D
			var mat = mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh and mi.mesh.get_surface_count() > 0 else null)
			found.append("%s  mesh=%s  visible=%s  mat=%s  verts~%d" % [n.name, mi.mesh.get_class() if mi.mesh else "-",
				mi.visible, mat.get_class() if mat else "none",
				(mi.mesh.get_faces().size() if mi.mesh and mi.mesh is ArrayMesh else -1)])
	print("WATERNODES")
	for f in found: print("   ", f)
	var cam := Camera3D.new(); world.add_child(cam)
	cam.position = Vector3(0, 14, 238); cam.look_at(Vector3(0, -2, 320)); cam.fov = 60; cam.current = true
	await _frames(12)
	root.get_texture().get_image().save_png(out + "water_now_coast.png")
	cam.position = Vector3(0, 2.0, 268); cam.look_at(Vector3(0, -0.6, 300))
	await _frames(8)
	root.get_texture().get_image().save_png(out + "water_now_shore.png")
	print("OUT ok")
	quit()
