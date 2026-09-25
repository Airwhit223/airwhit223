class_name PrimalForm
extends Node3D
## Ancient Cousin Primal Form on the real character model (Race Bible sections 4-6). ONE transformation, two states:
##   Controlled - blue aura over fiery-orange heat, gold lightning highlights THROUGH the character's own hairstyle,
##                vivid electric blue-gold eyes, a more defined body.
##   Dark       - the same awakening without control: white hair (same style, wilder), glowing red eyes, crimson /
##                black-red unstable energy with white-hot flickers.
## The character stays recognisable: hair keeps its cut (grown to its overgrown state - bigger, longer), clothes stay.
## Attach with PrimalForm.begin(character, dark); end() restores everything it changed.

const AURA_SHADER := preload("res://character/toriyama/primal_aura.gdshader")
const RAMP_TIME := 0.6
const STYLE := {
	false: {"hair": Color(1.0, 0.84, 0.28), "eye": Color(0.30, 0.82, 1.0), "outer": Color(0.22, 0.70, 1.0),
		"core": Color(0.70, 0.95, 1.0), "inner_outer": Color(1.0, 0.40, 0.06), "inner_core": Color(1.0, 0.85, 0.35),
		"bolt": Color(1.0, 0.86, 0.3), "ember": Color(1.0, 0.55, 0.15), "jitter": 0.0, "white_hair": false,
		"marks": Color(0.25, 0.85, 1.0)},
	true: {"hair": Color(1.0, 0.97, 0.95), "eye": Color(1.0, 0.08, 0.05), "outer": Color(0.75, 0.04, 0.08),
		"core": Color(1.0, 0.25, 0.20), "inner_outer": Color(0.35, 0.0, 0.02), "inner_core": Color(1.0, 0.9, 0.85),
		"bolt": Color(1.0, 0.25, 0.18), "ember": Color(0.9, 0.08, 0.06), "jitter": 1.0, "white_hair": true,
		"marks": Color(0.95, 0.06, 0.08)},
}
const WHITE_HAIR := Color(0.92, 0.93, 0.96)
const LIFT_CONTROLLED := 0.0      # live lift field left the head looking bald; windswept cuts instead    # hair blown upward by a smooth spatial field (paint/ink primal_hair_vertex)
const LIFT_DARK := 0.0
const SPIKE_CONTROLLED := 0.35
const SPIKE_DARK := 1.0

var character: ToriyamaCharacter
var dark := false
var amount := 0.0
var _target := 0.0
var _saved := {}
var _hair_mats: Array[ShaderMaterial] = []
var _lift_mats: Array[ShaderMaterial] = []
var _scalp_r := 0.085   # hair paint + ink passes (the outline must rise with the hair)
var _skin_mats: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []
var _bolts: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _bolt_timer := 0.0
var _embers: GPUParticles3D

static func begin(ch: ToriyamaCharacter, is_dark: bool) -> PrimalForm:
	var old := ch.get_node_or_null("PrimalForm") as PrimalForm
	if old:
		old.end(true)
	var pf := PrimalForm.new()
	pf.name = "PrimalForm"
	pf.character = ch
	pf.dark = is_dark
	ch.add_child(pf)
	pf._apply()
	return pf

## Ramp out and restore the character (immediate = no ramp, e.g. when swapping states).
func end(immediate := false) -> void:
	_target = 0.0
	if immediate:
		amount = 0.0
		_restore()
		queue_free()

## The primal cut for this character's hair type ("" = none: keep their cut, grown out).
func _primal_cut_for(ch: ToriyamaCharacter) -> String:
	if not ch is ToriyamaKitCharacter:
		return ""
	# the character's own cut, blown upward (primal_hair.windswept, exported as <cut>__Wind) - every hairstyle
	var cut := String(((ch.get("recipe") as Dictionary).get("hair", {}) as Dictionary).get("cut", ""))
	# Controlled: the curls loosen and lift (primal_hair.loosened); Uncontrolled: windswept (being redesigned)
	var want := cut + ("__Bolt" if dark else "__Loose")    # Dark: lightning-bolt curls (primal_hair.bolted)
	if cut != "" and not ToriyamaKitCharacter.kit_json("hair", want).is_empty():
		return want
	return ""

func _style() -> Dictionary:
	return STYLE[dark]

# ------------------------------------------------------------------ apply / restore
func _apply() -> void:
	var st := _style()
	var ch := character
	# hair: the SAME hair type, evolved (Race Bible hair rule). Curly hair swaps to its primal cut - the curls
	# pushed up (Controlled) or swept into big curly spikes (Dark), primal_hair.py; other types grow to overgrown.
	_saved["hair_state"] = ch.hair_state
	var primal_cut := _primal_cut_for(ch)   # the character's own cut, windswept (primal_hair.windswept)
	if primal_cut != "":
		var hair: Dictionary = (ch.get("recipe") as Dictionary).get("hair", {})
		_saved["hair_style"] = [String(hair.get("cut", "")), String(hair.get("bangs", "")), String(hair.get("accessory", ""))]
		ch.set_hair_style(primal_cut)
		ch.set_hair_state(&"fresh")

	var center := _head_center()
	# scalp radius follows the head scale (the head bone is scaled in game)
	var hb := ch.skeleton.find_bone("DEF-head") if ch.skeleton else -1
	if hb >= 0:
		_scalp_r = 0.085 * ch.skeleton.get_bone_global_pose(hb).basis.get_scale().y
	for state in ch.hair_meshes:
		var v = ch.hair_meshes[state]
		for mi in (v if v is Array else [v]):
			for m in _materials(mi as MeshInstance3D):
				_hair_mats.append(m)
				_saved[m] = m.get_shader_parameter("tint")
				m.set_shader_parameter("primal_hair", 1)
				m.set_shader_parameter("primal_color", st["hair"])
				m.set_shader_parameter("primal_center", center)
				_lift_mats.append(m)
				if m.next_pass is ShaderMaterial:
					_lift_mats.append(m.next_pass as ShaderMaterial)
				if st["white_hair"]:
					m.set_shader_parameter("tint", WHITE_HAIR)
					m.set_shader_parameter("primal_floor", 0.62)
					# the bolt blades intersect; the backface outline hull pokes through them as dark shards - keep
					# only the silhouette line on the white hair
					# the bolt blades cross each other and the backface outline hull shows through as black shards at any
					# width - detach it from the white hair for the form, restore after
					if m.next_pass is ShaderMaterial:
						_saved["ink:" + str(m.get_instance_id())] = m.next_pass
						m.next_pass = null
				else:
					# Controlled: inner fire warms the hair (the sheet's warm brown; the blue aura cools it otherwise)
					var t0: Color = _saved[m] if _saved[m] is Color else Color.WHITE
					m.set_shader_parameter("tint", Color(t0.r * 1.45, t0.g * 1.28, t0.b * 1.05, t0.a))
	# ancestral markings: skin materials that carry a marking mask (base kit bake); none yet = no-op
	for n in ["Body_Base", "Head_Base"]:
		var mi := ch.find_child(n, true, false) as MeshInstance3D
		if mi:
			for m in _materials(mi):
				if m.get_shader_parameter("primal_mask") != null:
					_skin_mats.append(m)
					m.set_shader_parameter("primal_hair", 0)
					m.set_shader_parameter("primal_color", st["marks"])
	# eyes
	_saved["anime_eye"] = []
	for m in ch.anime_eye_materials:
		if m.get_shader_parameter("eye_color") != null:
			_saved["anime_eye"].append([m, m.get_shader_parameter("eye_color")])
			m.set_shader_parameter("eye_color", st["eye"])
	_saved["iris"] = []
	for n in ["Eye_L", "Eye_R"]:
		var eye := ch.find_child(n, true, false) as MeshInstance3D
		if eye:
			for m in _materials(eye):
				if m.get_shader_parameter("paint_texture") != null and int(m.get_shader_parameter("source")) == 0:
					_saved["iris"].append([m, m.get_shader_parameter("tint")])
					m.set_shader_parameter("tint", st["eye"])
	# body: visibly more defined, not inflated
	_saved["shapes"] = {}
	for shape in ["TR_Definition", "Def_Shoulders", "Def_Back"]:
		_saved["shapes"][shape] = _shape_value(shape)
	_build_aura()
	# Dark: rage on the face - scowl, brows pulled down, snarl (drawn and modelled faces both follow set_expression)
	if dark:
		_saved["expr"] = ch._expr.duplicate()
		ch.set_expression("Angry")
	_target = 1.0

func _restore() -> void:
	var ch := character
	if not is_instance_valid(ch):
		return
	if _saved.has("expr"):
		ch._expr = (_saved["expr"] as Dictionary).duplicate()
		ch.set_expression("Angry", float(ch._expr.get("Angry", 0.0)), false)
	if _saved.has("hair_style"):
		var hs: Array = _saved["hair_style"]
		ch.set_hair_style(hs[0], hs[1], hs[2])
		_hair_mats.clear()             # those materials went with the primal cut
		_lift_mats.clear()
	ch.set_hair_state(_saved.get("hair_state", &"fresh"))
	for m in _lift_mats:
		m.set_shader_parameter("primal_lift", 0.0)
	for m in _hair_mats:
		m.set_shader_parameter("primal_floor", 0.0)
		var ink_key := "ink:" + str(m.get_instance_id())
		if _saved.has(ink_key):
			m.next_pass = _saved[ink_key]
		m.set_shader_parameter("primal_amount", 0.0)
		m.set_shader_parameter("primal_hair", 0)
		if _saved.has(m):
			m.set_shader_parameter("tint", _saved[m])
	for m in _skin_mats:
		m.set_shader_parameter("primal_amount", 0.0)
	for pair in _saved.get("anime_eye", []):
		pair[0].set_shader_parameter("eye_color", pair[1])
	for pair in _saved.get("iris", []):
		pair[0].set_shader_parameter("tint", pair[1])
	var shapes: Dictionary = _saved.get("shapes", {})
	for shape in shapes:
		ch._set_shape(shape, float(shapes[shape]))

func _materials(mi: MeshInstance3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if mi == null or mi.mesh == null:
		return out
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as ShaderMaterial
		if m and not out.has(m):
			out.append(m)
	return out

func _shape_value(shape: String) -> float:
	var body := character.find_child("Body_Base", true, false) as MeshInstance3D
	if body:
		var i := body.find_blend_shape_by_name(shape)
		if i >= 0:
			return body.get_blend_shape_value(i)
	return 0.0

## Head centre in the skeleton's space (where the hair meshes live), for choosing the streak bands.
func _head_center() -> Vector3:
	var sk := character.skeleton
	var h := sk.find_bone("DEF-head") if sk else -1
	if h < 0:
		return Vector3(0, 1.6, 0)
	return sk.get_bone_global_pose(h) * Vector3(0, 0.10, 0)

# ------------------------------------------------------------------ aura, lightning, embers
func _build_aura() -> void:
	var st := _style()
	# flame-silhouette cards (primal_aura.gdshader): one behind the figure at full strength, a faint one in front, and a
	# smaller inner-fire card behind (Controlled: orange heat under the blue)
	var top := clampf(character.eye_world_position().y - character.global_position.y, 1.0, 2.2) + 0.15
	var cards := [
		{"size": Vector2(1.7, top + 0.9), "radius": 0.36, "depth": -0.35, "alpha": 1.0, "outer": st["outer"], "core": st["core"], "seed": 0.0},
		{"size": Vector2(1.5, top + 0.6), "radius": 0.30, "depth": -0.30, "alpha": 0.75, "outer": st["inner_outer"], "core": st["inner_core"], "seed": 7.3},
		{"size": Vector2(1.7, top + 0.9), "radius": 0.36, "depth": 0.35, "alpha": 0.10, "outer": st["outer"], "core": st["core"], "seed": 2.1},
	]
	for c in cards:
		var card := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = c["size"]
		quad.center_offset = Vector3(0, c["size"].y * 0.5, 0)
		card.mesh = quad
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.extra_cull_margin = 2.0
		var m := ShaderMaterial.new()
		m.shader = AURA_SHADER
		m.set_shader_parameter("outer_color", c["outer"])
		m.set_shader_parameter("core_color", c["core"])
		m.set_shader_parameter("card_size", c["size"])
		m.set_shader_parameter("figure_top", top)
		m.set_shader_parameter("body_radius", c["radius"])
		m.set_shader_parameter("depth_offset", c["depth"])
		m.set_shader_parameter("layer_alpha", c["alpha"])
		m.set_shader_parameter("jitter", st["jitter"])
		m.set_shader_parameter("seed", c["seed"] + (11.0 if dark else 0.0))
		m.set_shader_parameter("intensity", 0.0)
		card.material_override = m
		add_child(card)
		_shells.append(card)
	_bolts = MeshInstance3D.new()
	_bolts.mesh = ImmediateMesh.new()
	_bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.albedo_color = st["bolt"]
	_bolts.material_override = _bolt_mat
	add_child(_bolts)
	_embers = GPUParticles3D.new()
	_embers.amount = 36
	_embers.lifetime = 1.3
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	_embers.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var dot := GradientTexture2D.new()          # round, soft embers rather than square specks
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	var em := StandardMaterial3D.new()
	em.albedo_texture = dot
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	em.albedo_color = st["ember"]
	quad.material = em
	_embers.draw_pass_1 = quad
	_embers.position = Vector3(0, 0.1, 0)
	add_child(_embers)

## Jagged lightning ribbons around the body, re-struck a dozen times a second, facing the camera.
func _strike() -> void:
	var im := _bolts.mesh as ImmediateMesh
	im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var height := character.eye_world_position().y - character.global_position.y
	var count := randi_range(1, 3) if not dark else randi_range(2, 4)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in count:
		var a := randf() * TAU
		var r := randf_range(0.28, 0.5)
		var p := Vector3(cos(a) * r, randf_range(0.35, height + 0.1), sin(a) * r)
		var dir := Vector3(randf_range(-0.4, 0.4), randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)).normalized()
		var pts: Array[Vector3] = [p]
		for s in randi_range(4, 7):
			p += dir * randf_range(0.05, 0.1) + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
			pts.append(p)
		for k in pts.size() - 1:
			var a0: Vector3 = pts[k]
			var a1: Vector3 = pts[k + 1]
			var view := (cam.global_position - global_transform * a0).normalized() if cam else Vector3.FORWARD
			var side := (a1 - a0).cross(global_transform.basis.inverse() * view).normalized() * 0.012 * (1.0 - float(k) / pts.size())
			im.surface_add_vertex(a0 - side); im.surface_add_vertex(a0 + side); im.surface_add_vertex(a1 + side)
			im.surface_add_vertex(a0 - side); im.surface_add_vertex(a1 + side); im.surface_add_vertex(a1 - side)
	im.surface_end()

func _process(delta: float) -> void:
	amount = move_toward(amount, _target, delta / RAMP_TIME)
	var pulse := amount * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.012))
	if dark:
		pulse *= 0.8 + 0.4 * randf()          # unstable
	for m in _hair_mats:
		m.set_shader_parameter("primal_amount", 0.0 if dark else amount)   # Dark: plain white, no veins
	# hair rises with the power: Controlled lifts and flares, Dark sweeps up into spikes
	var center := _head_center()
	for m in _lift_mats:
		m.set_shader_parameter("primal_lift", amount * (LIFT_DARK if dark else LIFT_CONTROLLED))
		m.set_shader_parameter("primal_spike", SPIKE_DARK if dark else SPIKE_CONTROLLED)
		m.set_shader_parameter("primal_lift_center", center)
		m.set_shader_parameter("primal_scalp_r", _scalp_r)
	for m in _skin_mats:
		m.set_shader_parameter("primal_amount", pulse)
	for shell in _shells:
		(shell.material_override as ShaderMaterial).set_shader_parameter("intensity", pulse)
	if is_instance_valid(character):
		character._set_shape("TR_Definition", lerpf(float(_saved["shapes"].get("TR_Definition", 0.0)), 0.7, amount))
		character._set_shape("Def_Shoulders", lerpf(float(_saved["shapes"].get("Def_Shoulders", 0.0)), 0.8, amount))
		character._set_shape("Def_Back", lerpf(float(_saved["shapes"].get("Def_Back", 0.0)), 0.7, amount))
	_embers.emitting = amount > 0.3
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = randf_range(0.05, 0.12)
		if amount > 0.5 and randf() < (0.8 if dark else 0.55):
			_strike()
		else:
			(_bolts.mesh as ImmediateMesh).clear_surfaces()
	if _target == 0.0 and amount == 0.0:
		_restore()
		queue_free()
