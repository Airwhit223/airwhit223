extends SceneTree
## What the conversation panel actually looks like, with a real resident. Run WITHOUT --headless.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 6) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var out := ProjectSettings.globalize_path("user://gear/")
	DirAccess.make_dir_recursive_absolute(out)
	var rm = root.get_node("RelationshipManager")
	var ConvoScript: GDScript = load("res://npc/npc_conversation.gd")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var def := TownsfolkGenerator.generate(rng, 3)
	var world := Node3D.new(); root.add_child(world)
	var brain = load("res://scenes/npc.tscn").instantiate()
	brain.definition = def
	world.add_child(brain)
	brain.set_physics_process(false)
	await _frames(4)
	brain.day_log.clear()
	brain.day_log.append({"hour": 7, "kind": "activity", "detail": "WORK", "with": ""})
	brain.day_log.append({"hour": 12, "kind": "social", "detail": "have lunch", "with": "Bram"})
	brain.day_log.append({"hour": 18, "kind": "activity", "detail": "BASKETBALL", "with": ""})
	# a friendship worth showing off, so the romance and favour groups are on screen
	rm.modify_affinity("player", def.id, 55.0)
	rm.modify_romance("player", def.id, 38.0)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color(0.10, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var box = load("res://ui/dialogue_box.gd").new()
	layer.add_child(box)
	box.open_with(brain)
	await _frames(8)
	root.get_texture().get_image().save_png(out + "dialogue_box.png")
	box._pick("your_day")
	await _frames(8)
	root.get_texture().get_image().save_png(out + "dialogue_box_day.png")
	print("OUT ", out, " ", def.first_name, " ", box.conversation.outlook)
	quit()
