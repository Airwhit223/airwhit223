extends SceneTree
## The three bars in the running game, at three different states. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 6) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out: String = ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await _frames(60)
	var p = root.get_node("WorldState").player
	var cam := Camera3D.new(); world.add_child(cam)
	cam.global_position = p.global_position + Vector3(2.6, 1.7, -3.4)
	cam.look_at(p.global_position + Vector3(0, 0.9, 0))
	cam.current = true
	for shot in [["fresh", 100.0, 100.0, 100.0], ["worn", 68.0, 44.0, 52.0], ["spent", 31.0, 9.0, 6.0]]:
		p.vitals.health = float(shot[1]); p.vitals.energy = float(shot[2]); p.vitals.stamina = float(shot[3])
		p.vitals._regen_block = 999.0        # hold it still for the photo
		await _frames(8)
		root.get_texture().get_image().save_png("%svitals_%s.png" % [out, shot[0]])
	print("OUT ok")
	quit()
