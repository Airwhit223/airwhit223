extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	for s in ["husky", "husky_copper", "husky_silver", "husky_white",
			"maine_coon", "maine_coon_cream", "maine_coon_ginger", "maine_coon_smoke",
			"corgi", "siamese"]:
		var p: Node3D = load("res://pets/%s.tscn" % s).instantiate()
		world.add_child(p)
		await process_frame
		var art := p.get_node_or_null("Art")
		var mi := art.find_children("*", "MeshInstance3D", true, false) if art else []
		var ap := art.find_children("*", "AnimationPlayer", true, false) if art else []
		var playing := (ap[0] as AnimationPlayer).is_playing() if ap.size() > 0 else false
		print("%-20s model=%s  meshes=%d  idle_playing=%s" % [s, p.model_scene != null, mi.size(), playing])
		p.queue_free()
	quit()
