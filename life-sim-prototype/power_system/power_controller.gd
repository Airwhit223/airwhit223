class_name PowerController
extends Node
## In-game runtime controller managing the active Power System state on the player.
## Handles dynamic transformation auras, cosmetic racial attachments (wolf ears/tail),
## stat multiplier application, and power loadout triggers.

const PlayerPowerProfileScript := preload("res://power_system/player_power_profile.gd")
const PowerCatalogScript := preload("res://power_system/power_catalog.gd")

signal transformation_visual_changed(is_active: bool, form_id: String)
signal ability_executed(ability_id: String)

var player: CharacterBody3D
var profile: RefCounted = null

var _aura_node: Node3D = null
var _socket_accessories: Array[Node3D] = []
## Transformation display mode: "full" (dedicated 3D model swap, default) or "hybrid" (socket accessories)
var transform_mode: String = "full"

func setup(p: CharacterBody3D) -> void:
	player = p
	var ps = get_node_or_null("/root/PowerSystem") if is_inside_tree() else null
	if ps and ps.profile:
		profile = ps.profile
	elif profile == null:
		profile = PlayerPowerProfileScript.new()

	profile.transformation_started.connect(_on_transformation_started)
	profile.transformation_ended.connect(_on_transformation_ended)
	profile.power_state_changed.connect(_on_power_state_changed)

func _on_power_state_changed() -> void:
	# Keep player stats synchronized
	_apply_stat_effects()

func _apply_stat_effects() -> void:
	if player == null or profile == null:
		return
	# Stat effects are read by player in _physics_process via get_speed_multiplier(), etc.

func get_speed_multiplier() -> float:
	if profile == null:
		return 1.0
	return profile.get_effective_stat("speed")

func get_jump_multiplier() -> float:
	if profile == null:
		return 1.0
	var mob: float = profile.get_effective_stat("mobility")
	var str_stat: float = profile.get_effective_stat("strength")
	return (mob + str_stat) * 0.5

func get_strength_multiplier() -> float:
	if profile == null:
		return 1.0
	return profile.get_effective_stat("strength")

func get_resistance_multiplier() -> float:
	if profile == null:
		return 1.0
	var res: float = profile.get_effective_stat("resistance")
	if profile.current_adaptation == "physical":
		res *= 1.35
	return res

func get_reflex_multiplier() -> float:
	if profile == null:
		return 1.0
	return profile.get_effective_stat("reflex")

# ----------------- Visual Transformation Rigging -----------------
func _on_transformation_started(trans_id: String, _axis: String) -> void:
	_cleanup_visuals()
	var all_trans: Dictionary = PowerCatalogScript.get_transformations()
	if not all_trans.has(trans_id):
		return
	var t_data: Dictionary = all_trans[trans_id]
	var rig = player.get_node_or_null("Body") if player else null
	# Ancient Cousin Primal Form on the real character (character/toriyama/primal_form.gd): the hair, eyes, markings,
	# body and aura are driven on the model itself instead of the placeholder primitives below.
	if trans_id in ["ancient_primal", "ancient_primal_dark"] and rig and rig.get("model") is ToriyamaCharacter:
		PrimalForm.begin(rig.model, trans_id == "ancient_primal_dark")
		transformation_visual_changed.emit(true, trans_id)
		var ebp = get_node_or_null("/root/EventBus") if is_inside_tree() else null
		if ebp:
			ebp.fire("hud_message", {"text": "TRANSFORMATION: " + String(t_data.get("display_name", trans_id))})
		return
	_build_transformation_aura(t_data)

	var full_model: String = String(t_data.get("full_model_path", ""))
	var keep_body: bool = bool(t_data.get("keep_base_body", false))

	if not keep_body and transform_mode == "full" and full_model != "" and rig and rig.has_method("swap_transformation_model"):
		rig.swap_transformation_model(full_model)
	else:
		# Base body preserved or Hybrid mode: attach socket cosmetics & markings
		var attachment: String = String(t_data.get("cosmetic_socket_attachment", ""))
		if attachment != "":
			_attach_cosmetics(attachment)

	transformation_visual_changed.emit(true, trans_id)
	var eb = get_node_or_null("/root/EventBus") if is_inside_tree() else null
	if eb:
		var mode_label := " (Primal Form)" if keep_body else (" (Full Form)" if transform_mode == "full" else " (Hybrid)")
		eb.fire("hud_message", {"text": "TRANSFORMATION: " + String(t_data.get("display_name", trans_id)) + mode_label})

func _on_transformation_ended(trans_id: String) -> void:
	_cleanup_visuals()
	transformation_visual_changed.emit(false, trans_id)
	var eb = get_node_or_null("/root/EventBus") if is_inside_tree() else null
	if eb:
		eb.fire("hud_message", {"text": "Transformation subsided."})

func _build_transformation_aura(t_data: Dictionary) -> void:
	if player == null:
		return
	_aura_node = Node3D.new()
	_aura_node.name = "TransformationAura"
	_aura_node.position = Vector3(0, 0.9, 0) # Centered on torso

	# Layer 1: Outer glowing energy shell (Dominant Blue / Theme Color)
	var shell := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.55
	cap.height = 1.95
	shell.mesh = cap

	var mat := StandardMaterial3D.new()
	var col: Color = t_data.get("aura_color", Color.CYAN)
	mat.albedo_color = Color(col.r, col.g, col.b, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b)
	mat.emission_energy_multiplier = float(t_data.get("aura_emission_energy", 2.0)) * 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = mat
	_aura_node.add_child(shell)

	# Layer 2: Inner Core Heat Shell (e.g. Fiery Orange biological heat underneath the blue)
	if t_data.has("aura_inner_color"):
		var inner_shell := MeshInstance3D.new()
		var inner_cap := CapsuleMesh.new()
		inner_cap.radius = 0.42
		inner_cap.height = 1.70
		inner_shell.mesh = inner_cap

		var inner_mat := StandardMaterial3D.new()
		var in_col: Color = t_data.get("aura_inner_color", Color.ORANGE)
		inner_mat.albedo_color = Color(in_col.r, in_col.g, in_col.b, 0.28)
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.emission_enabled = true
		inner_mat.emission = Color(in_col.r, in_col.g, in_col.b)
		inner_mat.emission_energy_multiplier = float(t_data.get("aura_emission_energy", 2.0)) * 0.65
		inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inner_shell.material_override = inner_mat
		_aura_node.add_child(inner_shell)

	# Layer 3: Gold Lightning Arcs & Crackles
	if t_data.has("lightning_color"):
		var light_col: Color = t_data.get("lightning_color", Color.GOLD)
		var light_mat := StandardMaterial3D.new()
		light_mat.albedo_color = light_col
		light_mat.emission_enabled = true
		light_mat.emission = light_col
		light_mat.emission_energy_multiplier = 3.2
		for j in range(6):
			var arc := MeshInstance3D.new()
			var arc_mesh := CylinderMesh.new()
			arc_mesh.top_radius = 0.015
			arc_mesh.bottom_radius = 0.025
			arc_mesh.height = 0.35 + (j % 3) * 0.12
			arc.mesh = arc_mesh
			arc.material_override = light_mat
			var a := j * (PI / 3.0)
			arc.position = Vector3(cos(a) * 0.52, -0.4 + (j * 0.22), sin(a) * 0.52)
			arc.rotation_degrees = Vector3(sin(j) * 35.0, a * 57.3, cos(j) * 40.0)
			_aura_node.add_child(arc)

	# Orbiting Energy Orbs
	var style := String(t_data.get("particle_effect_style", "flame"))
	for i in range(4):
		var orb := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 0.08
		s_mesh.height = 0.16
		orb.mesh = s_mesh
		orb.material_override = mat
		var angle := i * (PI / 2.0)
		orb.position = Vector3(cos(angle) * 0.65, sin(angle * 2.0) * 0.3, sin(angle) * 0.65)
		_aura_node.add_child(orb)

	player.add_child(_aura_node)

func _attach_cosmetics(attachment_type: String) -> void:
	if player == null:
		return
	var rig = player.get_node_or_null("Body")
	if rig == null:
		return

	if attachment_type == "wolf_features":
		# Left & Right Wolf Ears
		var fur_mat := StandardMaterial3D.new()
		fur_mat.albedo_color = Color(0.28, 0.22, 0.18)
		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var p := PrismMesh.new()
			p.size = Vector3(0.12, 0.22, 0.08)
			ear.mesh = p
			ear.position = Vector3(side * 0.16, 1.82, -0.05)
			ear.rotation_degrees = Vector3(10, 0, side * 20)
			ear.material_override = fur_mat
			player.add_child(ear)
			_socket_accessories.append(ear)

		# Wolf Tail
		var tail := MeshInstance3D.new()
		var c_tail := CylinderMesh.new()
		c_tail.top_radius = 0.04
		c_tail.bottom_radius = 0.09
		c_tail.height = 0.65
		tail.mesh = c_tail
		tail.position = Vector3(0, 0.75, 0.35)
		tail.rotation_degrees = Vector3(35, 0, 0)
		tail.material_override = fur_mat
		player.add_child(tail)
		_socket_accessories.append(tail)

		# Feral Claw Bracers
		for side in [-1.0, 1.0]:
			var claw := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.08, 0.14, 0.16)
			claw.mesh = b
			claw.position = Vector3(side * 0.38, 0.88, 0.05)
			claw.material_override = fur_mat
			player.add_child(claw)
			_socket_accessories.append(claw)

	elif attachment_type == "dragon_features":
		# Swept Draconic Horns
		var horn_mat := StandardMaterial3D.new()
		horn_mat.albedo_color = Color(0.15, 0.12, 0.14)
		horn_mat.emission_enabled = true
		horn_mat.emission = Color(0.95, 0.25, 0.05)
		horn_mat.emission_energy_multiplier = 1.2
		for side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.06
			c.height = 0.42
			horn.mesh = c
			horn.position = Vector3(side * 0.14, 1.88, -0.10)
			horn.rotation_degrees = Vector3(-35, side * 15, side * 22)
			horn.material_override = horn_mat
			player.add_child(horn)
			_socket_accessories.append(horn)

		# Dragon Dorsal Wings / Spine Ridges
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = Color(0.35, 0.12, 0.10)
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var p := PrismMesh.new()
			p.size = Vector3(0.55, 0.42, 0.04)
			wing.mesh = p
			wing.position = Vector3(side * 0.26, 1.28, 0.22)
			wing.rotation_degrees = Vector3(20, side * 45, side * -25)
			wing.material_override = wing_mat
			player.add_child(wing)
			_socket_accessories.append(wing)

		# Long Dragon Tail
		var d_tail := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.03
		tc.bottom_radius = 0.10
		tc.height = 0.85
		d_tail.mesh = tc
		d_tail.position = Vector3(0, 0.68, 0.42)
		d_tail.rotation_degrees = Vector3(45, 0, 0)
		d_tail.material_override = horn_mat
		player.add_child(d_tail)
		_socket_accessories.append(d_tail)

	elif attachment_type == "elf_features":
		# High Elf Long Pointed Ears
		var ear_mat := StandardMaterial3D.new()
		ear_mat.albedo_color = Color(0.88, 0.72, 0.60)
		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var p := PrismMesh.new()
			p.size = Vector3(0.06, 0.26, 0.06)
			ear.mesh = p
			ear.position = Vector3(side * 0.21, 1.68, -0.06)
			ear.rotation_degrees = Vector3(15, 0, side * -42)
			ear.material_override = ear_mat
			player.add_child(ear)
			_socket_accessories.append(ear)

		# Floating Emerald Astral Halo
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.34
		halo.mesh = torus
		halo.position = Vector3(0, 2.05, 0)
		var halo_mat := StandardMaterial3D.new()
		halo_mat.albedo_color = Color(0.2, 0.95, 0.5)
		halo_mat.emission_enabled = true
		halo_mat.emission = Color(0.3, 1.0, 0.6)
		halo_mat.emission_energy_multiplier = 2.4
		halo.material_override = halo_mat
		player.add_child(halo)
		_socket_accessories.append(halo)

	elif attachment_type == "dwarf_features":
		# Heavy Stone Runic Pauldrons
		var stone_mat := StandardMaterial3D.new()
		stone_mat.albedo_color = Color(0.42, 0.44, 0.48)
		stone_mat.emission_enabled = true
		stone_mat.emission = Color(0.85, 0.65, 0.25)
		stone_mat.emission_energy_multiplier = 1.0
		for side in [-1.0, 1.0]:
			var p_mesh := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.24, 0.18, 0.24)
			p_mesh.mesh = b
			p_mesh.position = Vector3(side * 0.32, 1.34, 0.0)
			p_mesh.rotation_degrees = Vector3(0, 0, side * 15)
			p_mesh.material_override = stone_mat
			player.add_child(p_mesh)
			_socket_accessories.append(p_mesh)

		# Earthen Arm Guard Shield
		var shield := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.12, 0.38, 0.26)
		shield.mesh = sb
		shield.position = Vector3(-0.38, 0.95, 0.10)
		shield.material_override = stone_mat
		player.add_child(shield)
		_socket_accessories.append(shield)

	elif attachment_type == "human_features":
		# Transcendent Golden Halo Ring
		var h_ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.25
		t.outer_radius = 0.30
		h_ring.mesh = t
		h_ring.position = Vector3(0, 2.02, 0)
		var gold_mat := StandardMaterial3D.new()
		gold_mat.albedo_color = Color(1.0, 0.9, 0.3)
		gold_mat.emission_enabled = true
		gold_mat.emission = Color(1.0, 0.85, 0.2)
		gold_mat.emission_energy_multiplier = 2.2
		h_ring.material_override = gold_mat
		player.add_child(h_ring)
		_socket_accessories.append(h_ring)

	elif attachment_type == "ancient_primal_features" or attachment_type == "ancient_dark_features":
		var is_dark := (attachment_type == "ancient_dark_features")
		# 1. Evolved Hair with Gold Lightning Highlights (or White for Dark Primal)
		var hair_highlight_mat := StandardMaterial3D.new()
		if not is_dark:
			hair_highlight_mat.albedo_color = Color(1.0, 0.88, 0.25) # Gold Lightning
			hair_highlight_mat.emission_enabled = true
			hair_highlight_mat.emission = Color(1.0, 0.82, 0.2)
			hair_highlight_mat.emission_energy_multiplier = 2.8
		else:
			hair_highlight_mat.albedo_color = Color(0.96, 0.96, 0.98) # Pure White
			hair_highlight_mat.emission_enabled = true
			hair_highlight_mat.emission = Color(0.9, 0.9, 1.0)
			hair_highlight_mat.emission_energy_multiplier = 1.8

		# Central Crest Lightning Spikes
		var crest := MeshInstance3D.new()
		var p_crest := PrismMesh.new()
		p_crest.size = Vector3(0.24, 0.42, 0.18)
		crest.mesh = p_crest
		crest.position = Vector3(0, 1.95, -0.02)
		crest.rotation_degrees = Vector3(-12, 0, 0)
		crest.material_override = hair_highlight_mat
		player.add_child(crest)
		_socket_accessories.append(crest)

		# Swept Lateral Lightning Highlight Locks (Left & Right)
		for side in [-1.0, 1.0]:
			var lock := MeshInstance3D.new()
			var p_lock := PrismMesh.new()
			p_lock.size = Vector3(0.14, 0.36, 0.12)
			lock.mesh = p_lock
			lock.position = Vector3(side * 0.18, 1.86, -0.06)
			lock.rotation_degrees = Vector3(-8, side * 22, side * 35)
			lock.material_override = hair_highlight_mat
			player.add_child(lock)
			_socket_accessories.append(lock)

			# Rear sweeping dynamic lock
			var r_lock := MeshInstance3D.new()
			var p_rlock := PrismMesh.new()
			p_rlock.size = Vector3(0.12, 0.32, 0.10)
			r_lock.mesh = p_rlock
			r_lock.position = Vector3(side * 0.14, 1.82, 0.12)
			r_lock.rotation_degrees = Vector3(25, side * 15, side * 20)
			r_lock.material_override = hair_highlight_mat
			player.add_child(r_lock)
			_socket_accessories.append(r_lock)

		# 2. Glowing Ancestral Markings (Biological Tattoos)
		var mark_mat := StandardMaterial3D.new()
		if not is_dark:
			mark_mat.albedo_color = Color(0.15, 0.85, 1.0) # Electric Cyan-Blue
			mark_mat.emission_enabled = true
			mark_mat.emission = Color(0.18, 0.88, 1.0)
			mark_mat.emission_energy_multiplier = 2.6
		else:
			mark_mat.albedo_color = Color(0.95, 0.1, 0.15) # Crimson
			mark_mat.emission_enabled = true
			mark_mat.emission = Color(1.0, 0.15, 0.15)
			mark_mat.emission_energy_multiplier = 3.0

		# Forearm Circuit Bands & Spirals
		for side in [-1.0, 1.0]:
			var arm_mark := MeshInstance3D.new()
			var cyl_arm := CylinderMesh.new()
			cyl_arm.top_radius = 0.065
			cyl_arm.bottom_radius = 0.075
			cyl_arm.height = 0.18
			arm_mark.mesh = cyl_arm
			arm_mark.position = Vector3(side * 0.38, 0.88, 0.05)
			arm_mark.material_override = mark_mat
			player.add_child(arm_mark)
			_socket_accessories.append(arm_mark)

			# Deltoid / Shoulder Markings
			var sh_mark := MeshInstance3D.new()
			var box_sh := BoxMesh.new()
			box_sh.size = Vector3(0.08, 0.12, 0.08)
			sh_mark.mesh = box_sh
			sh_mark.position = Vector3(side * 0.28, 1.28, 0.0)
			sh_mark.rotation_degrees = Vector3(0, 0, side * 15)
			sh_mark.material_override = mark_mat
			player.add_child(sh_mark)
			_socket_accessories.append(sh_mark)

			# Subtle cheek/face markings
			var cheek := MeshInstance3D.new()
			var c_mesh := BoxMesh.new()
			c_mesh.size = Vector3(0.02, 0.06, 0.02)
			cheek.mesh = c_mesh
			cheek.position = Vector3(side * 0.11, 1.62, -0.16)
			cheek.rotation_degrees = Vector3(0, 0, side * -20)
			cheek.material_override = mark_mat
			player.add_child(cheek)
			_socket_accessories.append(cheek)

		# Collarbone / Sternum Branching Energy Core
		var chest_mark := MeshInstance3D.new()
		var p_chest := PrismMesh.new()
		p_chest.size = Vector3(0.16, 0.14, 0.03)
		chest_mark.mesh = p_chest
		chest_mark.position = Vector3(0, 1.34, -0.155)
		chest_mark.rotation_degrees = Vector3(180, 0, 0)
		chest_mark.material_override = mark_mat
		player.add_child(chest_mark)
		_socket_accessories.append(chest_mark)

		# 3. Vivid Electric Eyes (Blue-Gold for Controlled, Red for Dark)
		var eye_mat := StandardMaterial3D.new()
		if not is_dark:
			eye_mat.albedo_color = Color(0.2, 0.85, 1.0)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(0.25, 0.9, 1.0)
			eye_mat.emission_energy_multiplier = 3.5
		else:
			eye_mat.albedo_color = Color(1.0, 0.05, 0.05)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.05, 0.05)
			eye_mat.emission_energy_multiplier = 3.5

		for side in [-1.0, 1.0]:
			var eye_glow := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.022
			sph.height = 0.044
			eye_glow.mesh = sph
			eye_glow.position = Vector3(side * 0.058, 1.66, -0.165)
			eye_glow.material_override = eye_mat
			player.add_child(eye_glow)
			_socket_accessories.append(eye_glow)

# ----------------- Active Racial Abilities -----------------
func cast_race_ability() -> bool:
	if player == null or profile == null:
		return false

	var r_id: String = profile.race_id
	var ability_name: String = ""

	match r_id:
		"dragon_kin":
			ability_name = "Inferno Breath"
			_execute_dragon_breath()
		"elf":
			ability_name = "Nature Surge"
			_execute_nature_surge()
		"dwarf":
			ability_name = "Earth Tremor"
			_execute_earth_tremor()
		"wolf_beastfolk":
			ability_name = "Feral Slash"
			_execute_feral_slash()
		"human":
			ability_name = "Adrenaline Surge"
			_execute_adrenaline_surge()
		"ancient_cousin":
			ability_name = "Ancestral Shockwave"
			_execute_ancestral_shockwave()

	ability_executed.emit(ability_name)
	var eb = get_node_or_null("/root/EventBus") if is_inside_tree() else null
	if eb:
		eb.fire("hud_message", {"text": "RACIAL POWER: " + ability_name})
	return true

func _execute_dragon_breath() -> void:
	if player == null: return
	# Spawn a forward-projecting flame cone
	var cone := MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 1.4
	cyl_mesh.bottom_radius = 0.1
	cyl_mesh.height = 3.5
	cone.mesh = cyl_mesh
	cone.position = Vector3(0, 1.1, -2.0)
	cone.rotation_degrees = Vector3(-90, 0, 0)
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(1.0, 0.3, 0.05, 0.75)
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.25, 0.0)
	f_mat.emission_energy_multiplier = 3.5
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone.material_override = f_mat
	player.add_child(cone)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.1)
	light.light_energy = 4.0
	light.omni_range = 6.0
	cone.add_child(light)

	var tween := player.create_tween()
	tween.tween_property(cone, "scale", Vector3(1.3, 1.3, 1.3), 0.35)
	tween.parallel().tween_property(cone, "transparency", 1.0, 0.4)
	tween.tween_callback(cone.queue_free)

func _execute_nature_surge() -> void:
	if player == null: return
	# Radial healing/mana wave
	var wave := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.7
	wave.mesh = t
	wave.position = Vector3(0, 0.15, 0)
	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.2, 0.95, 0.5, 0.8)
	w_mat.emission_enabled = true
	w_mat.emission = Color(0.3, 1.0, 0.6)
	w_mat.emission_energy_multiplier = 3.0
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = w_mat
	player.add_child(wave)

	profile.energy = minf(profile.max_energy, profile.energy + 25.0)

	var tween := player.create_tween()
	tween.tween_property(wave, "scale", Vector3(5.0, 1.0, 5.0), 0.45)
	tween.parallel().tween_property(wave, "transparency", 1.0, 0.45)
	tween.tween_callback(wave.queue_free)

func _execute_earth_tremor() -> void:
	if player == null: return
	# Radial ground fracture ring
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.5
	cyl.bottom_radius = 2.8
	cyl.height = 0.08
	ring.mesh = cyl
	ring.position = Vector3(0, 0.04, 0)
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.55, 0.45, 0.35)
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.85, 0.6, 0.2)
	s_mat.emission_energy_multiplier = 2.5
	ring.material_override = s_mat
	player.add_child(ring)

	var tween := player.create_tween()
	tween.tween_property(ring, "scale", Vector3(2.5, 1.0, 2.5), 0.35)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.4)
	tween.tween_callback(ring.queue_free)

func _execute_feral_slash() -> void:
	if player == null: return
	# Forward claw impulse + claw arc visual
	var fwd: Vector3 = -player.global_transform.basis.z if player.is_inside_tree() else -player.transform.basis.z
	player.velocity += fwd * 9.0

	var slash := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.2, 0.04, 0.6)
	slash.mesh = b
	slash.position = Vector3(0, 1.0, -1.0)
	slash.rotation_degrees = Vector3(25, 30, -35)
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	c_mat.emission_enabled = true
	c_mat.emission = Color(1.0, 0.7, 0.1)
	c_mat.emission_energy_multiplier = 3.0
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material_override = c_mat
	player.add_child(slash)

	var tween := player.create_tween()
	tween.tween_property(slash, "scale", Vector3(1.6, 1.6, 1.6), 0.25)
	tween.parallel().tween_property(slash, "transparency", 1.0, 0.25)
	tween.tween_callback(slash.queue_free)

func _execute_adrenaline_surge() -> void:
	if player == null: return
	profile.energy = profile.max_energy
	var surge_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	surge_ring.mesh = torus
	surge_ring.position = Vector3(0, 0.9, 0)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.9)
	g_mat.emission_enabled = true
	g_mat.emission = Color(1.0, 0.8, 0.1)
	g_mat.emission_energy_multiplier = 3.5
	surge_ring.material_override = g_mat
	player.add_child(surge_ring)

	var tween := player.create_tween()
	tween.tween_property(surge_ring, "scale", Vector3(3.0, 3.0, 3.0), 0.35)
	tween.parallel().tween_property(surge_ring, "transparency", 1.0, 0.35)
	tween.tween_callback(surge_ring.queue_free)

func _execute_ancestral_shockwave() -> void:
	if player == null: return
	# Expanding dual shockwave ring of blue and fiery orange energy
	var wave_blue := MeshInstance3D.new()
	var t_blue := TorusMesh.new()
	t_blue.inner_radius = 0.6
	t_blue.outer_radius = 0.85
	wave_blue.mesh = t_blue
	wave_blue.position = Vector3(0, 0.2, 0)
	var mat_blue := StandardMaterial3D.new()
	mat_blue.albedo_color = Color(0.15, 0.8, 1.0, 0.85)
	mat_blue.emission_enabled = true
	mat_blue.emission = Color(0.2, 0.85, 1.0)
	mat_blue.emission_energy_multiplier = 3.2
	mat_blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_blue.material_override = mat_blue
	player.add_child(wave_blue)

	var wave_orange := MeshInstance3D.new()
	var t_orange := TorusMesh.new()
	t_orange.inner_radius = 0.4
	t_orange.outer_radius = 0.6
	wave_orange.mesh = t_orange
	wave_orange.position = Vector3(0, 0.2, 0)
	var mat_orange := StandardMaterial3D.new()
	mat_orange.albedo_color = Color(1.0, 0.45, 0.05, 0.85)
	mat_orange.emission_enabled = true
	mat_orange.emission = Color(1.0, 0.42, 0.05)
	mat_orange.emission_energy_multiplier = 3.0
	mat_orange.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_orange.material_override = mat_orange
	player.add_child(wave_orange)

	if profile:
		profile.energy = minf(profile.max_energy, profile.energy + 15.0)
	var fwd: Vector3 = -player.global_transform.basis.z if player.is_inside_tree() else -player.transform.basis.z
	player.velocity += fwd * 7.5

	var tween := player.create_tween()
	tween.tween_property(wave_blue, "scale", Vector3(4.5, 1.0, 4.5), 0.45)
	tween.parallel().tween_property(wave_orange, "scale", Vector3(3.8, 1.0, 3.8), 0.45)
	tween.parallel().tween_property(wave_blue, "transparency", 1.0, 0.45)
	tween.parallel().tween_property(wave_orange, "transparency", 1.0, 0.45)
	tween.tween_callback(wave_blue.queue_free)
	tween.tween_callback(wave_orange.queue_free)

func _cleanup_visuals() -> void:
	var rig_c = player.get_node_or_null("Body") if player else null
	if rig_c and rig_c.get("model") is ToriyamaCharacter:
		var pf := (rig_c.model as Node).get_node_or_null("PrimalForm") as PrimalForm
		if pf:
			pf.end()
	if player:
		var rig = player.get_node_or_null("Body")
		if rig and rig.has_method("restore_base_model"):
			rig.restore_base_model()

	if is_instance_valid(_aura_node):
		if _aura_node.get_parent():
			_aura_node.get_parent().remove_child(_aura_node)
		_aura_node.queue_free()
		_aura_node = null
	for acc in _socket_accessories:
		if is_instance_valid(acc):
			if acc.get_parent():
				acc.get_parent().remove_child(acc)
			acc.queue_free()
	_socket_accessories.clear()

# ----------------- Transformation Triggers -----------------
func trigger_best_transformation() -> bool:
	if profile == null:
		return false
	if profile.is_transformed():
		profile.deactivate_transformation()
		return true

	# Priority order: Fusion -> Power Mastery (Mutation/Magic) -> Race Form
	if profile.can_fuse():
		return profile.activate_transformation("fusion")
	if profile.is_mutation_transformation_unlocked():
		return profile.activate_transformation("mutation")
	if profile.is_magic_transformation_unlocked():
		return profile.activate_transformation("magic")
	if profile.is_race_transformation_unlocked():
		return profile.activate_transformation("race")

	var eb = get_node_or_null("/root/EventBus") if is_inside_tree() else null
	if eb:
		eb.fire("hud_message", {"text": "Transformation not yet unlocked (Train Mastery!)"})
	return false
