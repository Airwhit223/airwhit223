extends SceneTree
## The player actually in the sea, in the live world. Run WITHOUT --headless.
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
	var p = root.get_node("WorldState").player
	var cam := Camera3D.new(); world.add_child(cam)
	# wading in at the shore
	p.global_position = Vector3(0, 1.0, 279.0)
	for i in 60: await physics_frame
	await _frames(6)
	cam.position = p.global_position + Vector3(4.5, 2.2, -5.0); cam.look_at(p.global_position + Vector3(0, 0.6, 0))
	cam.current = true
	await _frames(6)
	root.get_texture().get_image().save_png(out + "swim_wade.png")
	print("WADE state=", p.water_state, " swimming=", p.is_swimming, " y=%.2f" % p.global_position.y)
	# out of their depth
	p.global_position = Vector3(0, 1.0, 300.0)
	for i in 120: await physics_frame
	await _frames(6)
	cam.position = p.global_position + Vector3(4.0, 1.9, -5.5); cam.look_at(p.global_position + Vector3(0, 0.5, 0))
	await _frames(6)
	root.get_texture().get_image().save_png(out + "swim_deep.png")
	print("SWIM state=", p.water_state, " swimming=", p.is_swimming, " y=%.2f  stamina=%.0f" % [p.global_position.y, p.stamina])
	quit()
