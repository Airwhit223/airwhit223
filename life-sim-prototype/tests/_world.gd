extends SceneTree
## Loads the migrated Rolling Tides world and photographs it from a few vantage points.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://world/")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("RetroPS2").apply(&"off")
	var packed: PackedScene = load("res://world/rolling_tides_world/rolling_tides_world.tscn")
	if packed == null:
		print("WORLD load failed"); quit(); return
	var world: Node = packed.instantiate()
	root.add_child(world)
	await _frames(30)
	print("WORLD nodes=", world.get_child_count(), " total=", _count(world))
	var cam := Camera3D.new(); (world as Node3D).add_child(cam); cam.current = true; cam.fov = 60
	var shots := {
		"overview": [Vector3(0, 55, 70), Vector3(0, 0, 0)],
		"street": [Vector3(0, 6, 24), Vector3(0, 1.5, 0)],
		"far_north": [Vector3(0, 18, -70), Vector3(0, 2, -110)],
		"far_east": [Vector3(80, 18, 10), Vector3(120, 2, 10)],
	}
	for key in shots:
		cam.global_position = shots[key][0]
		cam.look_at(shots[key][1])
		await _frames(4)
		root.get_texture().get_image().save_png(out + "%s.png" % key)
	print("WORLD done -> ", out)
	quit()
func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children(): c += _count(ch)
	return c
