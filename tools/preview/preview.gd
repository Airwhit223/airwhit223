extends Node3D
## Renders one frame of some assets and saves it as a PNG, then quits.
## Driven by environment variables (see render.sh):
##   ITEMS  "path.glb:x:z[:y[:yaw[:anim[:t]]]];..."  paths relative to the repo root
##   CAM    "x,y,z"   camera position      LOOK "x,y,z"  point to look at
##   FOV    degrees (default 45)           OUT  output png path
##   BG     "sky" (default) or "room"      THIN "1" to use the thin outline everywhere

func _env(name: String, fallback: String) -> String:
	var v := OS.get_environment(name)
	return v if v != "" else fallback

func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _ready() -> void:
	var room := _env("BG", "sky") == "room"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.88, 0.8) if room else Color(0.62, 0.8, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.78, 0.62, 0.45) if room else Color(0.45, 0.68, 0.3)
	ground.material_override = gm
	add_child(ground)

	var thick: Material = load("res://materials/toon_outline_thick.tres")
	var thin: Material = load("res://materials/toon_outline_thin.tres")
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for item in _env("ITEMS", "").split(";", false):
		var f := item.split(":")
		var scene: PackedScene = load("res://assets/" + f[0])
		var node: Node3D = scene.instantiate()
		node.position = Vector3(float(f[1]), float(f[3]) if f.size() > 3 and f[3] != "" else 0.0, float(f[2]))
		node.rotation_degrees.y = float(f[4]) if f.size() > 4 and f[4] != "" else 0.0
		add_child(node)
		var aabb := AABB()
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(mi.get_aabb())
		var small := aabb.get_longest_axis_size() < 0.6 or _env("THIN", "") == "1"
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			if mi.name.begins_with("glow"):
				mi.material_override = glow
			else:
				mi.material_override = thin if small else thick
		if f.size() > 5 and f[5] != "":
			var players := node.find_children("*", "AnimationPlayer", true, false)
			if players.size() > 0:
				var ap: AnimationPlayer = players[0]
				ap.play(f[5])
				ap.seek((float(f[6]) if f.size() > 6 else 0.0) * ap.current_animation_length, true)
				ap.pause()
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "45"))
	cam.position = _vec(_env("CAM", "0,2,6"))
	add_child(cam)
	cam.look_at(_vec(_env("LOOK", "0,0.8,0")))
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_env("OUT", "/tmp/preview.png"))
	get_tree().quit()
