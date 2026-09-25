extends SceneTree
## Boots the real main scene with the world folded in, and photographs the home district and its surroundings.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://mainworld/")
	DirAccess.make_dir_recursive_absolute(out)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await _frames(45)
	var names: Array = []
	for n in root.get_tree().get_nodes_in_group("rival"):
		var who: String = String(n.name)
		if n.get("definition") != null and n.definition != null:
			who = "%s %s" % [n.definition.first_name, n.definition.id]
		names.append("%s @ (%d, %d)" % [who, int(n.global_position.x), int(n.global_position.z)])
	print("RIVALS (", names.size(), "):")
	for entry in names: print("   ", entry)
	for r in main.find_children("Nav*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = r.navigation_mesh
		print("NAV ", r.name, " polys=", nm.get_polygon_count() if nm else -1)
	print("MAIN children=", main.get_child_count(), " has world=", main.get_node_or_null("RollingTidesWorld") != null)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.queue_free()          # intro mirror + HUD cover the view
	await _frames(3)
	var cam := Camera3D.new(); (main as Node3D).add_child(cam); cam.current = true; cam.fov = 60
	var shots := {
		"shore_town": [Vector3(172, 16, 268), Vector3(172, 3, 235)],
		"shore_market": [Vector3(150, 5, 250), Vector3(172, 3, 236)],
		"shore_fair": [Vector3(200, 14, 258), Vector3(222, 4, 234)],
		"shore_wide": [Vector3(120, 55, 320), Vector3(185, 0, 235)],
	}
	for key in shots:
		cam.global_position = shots[key][0]
		cam.look_at(shots[key][1])
		await _frames(4)
		for layer in root.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		await _frames(2)
		root.get_texture().get_image().save_png(out + "%s.png" % key)
	print("MAINWORLD done -> ", out)
	quit()
