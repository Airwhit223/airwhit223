extends SceneTree
## Hair and clothing secondary motion: the spring should stay still when the character does, swing while they move,
## and settle after they stop — and never fling a piece further than its limit. Screenshots in user://motion_test/.

var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _frames(n := 10) -> void:
	for i in n: await process_frame
	await RenderingServer.frame_post_draw

func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok: failures.append(what)

## Biggest sway any clothing material is currently showing.
func _cloth_offset(character) -> float:
	var worst := 0.0
	for entry in character.motion._materials["cloth"]:
		var value = (entry["material"] as ShaderMaterial).get_shader_parameter("sway_offset")
		if value is Vector3:
			worst = maxf(worst, (value as Vector3).length())
	return worst

## Biggest sway any hair material is currently showing.
func _hair_offset(character) -> float:
	var worst := 0.0
	for entry in character.motion._materials["hair"]:
		var mat: ShaderMaterial = entry["material"]
		var value = mat.get_shader_parameter("sway_offset")
		if value is Vector3:
			worst = maxf(worst, (value as Vector3).length())
	return worst

func _run() -> void:
	ToriyamaRoster.save_recipe(CreatorData.default_recipe())
	var out := ProjectSettings.globalize_path("user://motion_test/")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(150)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: Node3D = root.get_tree().get_first_node_in_group("player")
	var rig = player.get_node("Body")
	var character = rig.model
	_expect(character != null and character.motion.has_pieces(), "clothing registered for motion")
	_expect(not ToriyamaCharacter.HAIR_MOTION, "hair sway is off (user asked for it off 2026-09-22)")

	# hair sway is off, so the hair checks below are skipped; clothing sway keeps its own coverage
	# clothing: it picks up movement and settles again (hair sway is off, so hair is not checked)
	player.input_locked = false
	Input.action_press("move_forward")
	await _frames(25)
	var moving := _cloth_offset(character)
	root.get_texture().get_image().save_png(out + "walking.png")
	_expect(moving > 0.0005, "clothing swings while walking (%.4f m)" % moving)
	Input.action_release("move_forward")
	await _frames(70)
	var settled := _cloth_offset(character)
	root.get_texture().get_image().save_png(out + "settled.png")
	_expect(settled < maxf(moving, 0.001), "clothing settles after stopping (%.4f m)" % settled)

	# and it can be switched off
	character.motion.enabled = false
	await _frames(6)
	_expect(is_equal_approx(_hair_offset(character), 0.0), "motion can be turned off")
	character.motion.enabled = true
	# a tail profile exists (Beastfolk) and takes its own reach, so a tail registers instead of being ignored
	var tail_mat := ShaderMaterial.new()
	tail_mat.shader = load("res://character/toriyama/toriyama_paint.gdshader")
	character.motion.register(tail_mat, "tail", Vector3(0, 0.905, 0.085), 1.0, 0.5)
	await _frames(4)
	_expect(character.motion._materials.has("tail") and (character.motion._materials["tail"] as Array).size() == 1,
		"a tail registers under its own profile")
	_expect(is_equal_approx(float(tail_mat.get_shader_parameter("sway_range")), 0.5), "a tail uses its own length as reach")

	# strand hair (TR_Strand root->tip UVs) registers with mode 2; old exports keep the profile's mode 0
	var strand_mat := ShaderMaterial.new()
	strand_mat.shader = load("res://character/toriyama/toriyama_paint.gdshader")
	var probe := SecondaryMotion.new()
	probe.register(strand_mat, "hair", Vector3.ZERO, 1.0, -1.0, 2)
	probe.update(1.0 / 60.0, Transform3D.IDENTITY)
	_expect(int(strand_mat.get_shader_parameter("sway_mode")) == 2, "strand hair uses sway mode 2")
	var plain_mat := ShaderMaterial.new()
	plain_mat.shader = strand_mat.shader
	probe.register(plain_mat, "hair", Vector3.ZERO)
	probe.update(1.0 / 60.0, Transform3D.IDENTITY)
	_expect(int(plain_mat.get_shader_parameter("sway_mode")) == 0, "hair without strand data falls back to mode 0")

	ToriyamaRoster.clear_recipe()
	print("MOTION_TEST ", "PASS" if failures.is_empty() else "FAIL %s" % str(failures), " out=", out)
	quit(0 if failures.is_empty() else 1)
