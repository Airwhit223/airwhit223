extends Node3D
## Developer-only review; captures views in user://landscape-review.
func _ready() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 15:
		await get_tree().process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	TimeManager.set_process(false)
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 12000
	camera.fov = 65
	var out := "user://landscape-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var views := {
		"coastal-bay": [Vector3(70, 55, 195), Vector3(220, 5, 350)],
		"landscape-overview": [Vector3(-450, 440, 650), Vector3(0, 0, -80)],
		"northern-hills": [Vector3(-280, 55, -255), Vector3(-180, 35, -470)],
		"shore-level": [Vector3(174, 4, 249), Vector3(175, 1, 650)],
	}
	for key in views:
		camera.position = views[key][0]
		camera.look_at(views[key][1])
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))
	print("Landscape review images: ", ProjectSettings.globalize_path(out))
