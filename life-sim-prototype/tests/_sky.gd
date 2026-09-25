extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://mainworld/")
	for path in ["res://world/sky_island_planet/sky_island_planet.tscn",
			"res://world/sky_island_planet/dungeons/elemental_fire_cave.tscn"]:
		var packed: PackedScene = load(path)
		if packed == null:
			print("FAILED to load ", path); continue
		var node: Node = packed.instantiate()
		root.add_child(node)
		await _frames(25)
		var tag: String = path.get_file().get_basename()
		print("LOADED ", tag, " nodes=", node.get_child_count())
		var cam := Camera3D.new(); (node as Node3D).add_child(cam); cam.current = true; cam.fov = 62
		cam.global_position = Vector3(0, 60, 130) if tag.begins_with("sky") else Vector3(0, 14, 34)
		cam.look_at(Vector3(0, 6, 0))
		await _frames(4)
		root.get_texture().get_image().save_png(out + tag + ".png")
		node.queue_free()
		await _frames(3)
	print("SKY done")
	quit()
