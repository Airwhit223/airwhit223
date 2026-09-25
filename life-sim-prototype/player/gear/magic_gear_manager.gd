class_name MagicGearManager
extends Node
## Magic Gear and Arcane Traversal Manager.
## Provides:
## - Aether Glider: Low-drag descent wings, riding thermal updrafts.
## - Astral Grapple: Hook tether pulling player to anchor points.
## - Elemental Spells: Fire (burns/lights braziers), Ice (freezes water), Lightning (activates switches).

signal gear_activated(gear_type: String, details: Dictionary)
signal grapple_hit(point: Vector3)
signal spell_cast(spell_type: String, origin: Vector3, dir: Vector3)

enum Element { FIRE, ICE, LIGHTNING }

@export var glide_fall_speed: float = -1.2
@export var glide_forward_speed: float = 8.5
@export var grapple_range: float = 28.0
@export var grapple_pull_speed: float = 16.0

var player: CharacterBody3D

var has_glider: bool = true
var has_grapple: bool = true
var has_elemental_staff: bool = true

var is_gliding: bool = false
var is_grappling: bool = false
var grapple_target: Vector3 = Vector3.ZERO
var glider_mesh: Node3D = null

var current_element: Element = Element.FIRE
var spell_cooldown: float = 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	_create_glider_mesh()

func _create_glider_mesh() -> void:
	if player == null:
		return
	glider_mesh = Node3D.new()
	glider_mesh.name = "AetherGliderWings"
	glider_mesh.position = Vector3(0, 1.4, 0.2)
	glider_mesh.visible = false
	
	# Left energy wing
	var left_wing := MeshInstance3D.new()
	var prism_left := PrismMesh.new()
	prism_left.size = Vector3(2.4, 0.08, 1.2)
	prism_left.left_to_right = 0.8
	left_wing.mesh = prism_left
	left_wing.position = Vector3(-1.3, 0, 0)
	left_wing.rotation_degrees = Vector3(0, 15, 10)
	
	# Right energy wing
	var right_wing := MeshInstance3D.new()
	var prism_right := PrismMesh.new()
	prism_right.size = Vector3(2.4, 0.08, 1.2)
	prism_right.left_to_right = 0.2
	right_wing.mesh = prism_right
	right_wing.position = Vector3(1.3, 0, 0)
	right_wing.rotation_degrees = Vector3(0, -15, -10)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.85, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	left_wing.material_override = mat
	right_wing.material_override = mat
	
	glider_mesh.add_child(left_wing)
	glider_mesh.add_child(right_wing)
	player.add_child(glider_mesh)

func _process(delta: float) -> void:
	if spell_cooldown > 0.0:
		spell_cooldown = maxf(0.0, spell_cooldown - delta)

func update_gear(delta: float, input_dir: Vector2, cam_basis: Basis) -> bool:
	if player == null:
		return false

	# Grapple pull
	if is_grappling:
		var to_target := grapple_target - player.global_position
		var dist := to_target.length()
		if dist < 1.2:
			is_grappling = false
			player.velocity = to_target.normalized() * 4.0 # Release fling
		else:
			var pull_dir := to_target.normalized()
			player.velocity = pull_dir * grapple_pull_speed
		return true

	# Glider mechanics
	if is_gliding:
		if player.is_on_floor():
			stop_gliding()
			return false

		# Glide down slowly
		player.velocity.y = glide_fall_speed

		# Thermal updraft check (under towers or volcanic vents)
		if _check_thermal_updraft():
			player.velocity.y = 4.5 # Lift upward!

		# Forward propulsion
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()

		var move_dir := forward * -input_dir.y + right * input_dir.x
		if move_dir.length() < 0.1:
			move_dir = forward
		else:
			move_dir = move_dir.normalized()

		player.velocity.x = move_dir.x * glide_forward_speed
		player.velocity.z = move_dir.z * glide_forward_speed
		return true

	return false

func try_deploy_glider() -> bool:
	if not has_glider or player.is_on_floor() or is_gliding or is_grappling:
		return false
	is_gliding = true
	if glider_mesh:
		glider_mesh.visible = true
	gear_activated.emit("aether_glider", {})
	return true

func stop_gliding() -> void:
	if is_gliding:
		is_gliding = false
		if glider_mesh:
			glider_mesh.visible = false

func try_grapple(cam_origin: Vector3, cam_forward: Vector3) -> bool:
	if not has_grapple or is_grappling:
		return false

	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam_origin, cam_origin + cam_forward * grapple_range)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider = hit.get("collider")
	var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
	
	# Can grapple to grapple points, towers, rings, and cliff geometry
	var can_attach := false
	if collider.is_in_group("grapple_point") or collider.has_meta("grapple_target"):
		can_attach = true
	elif hit_pos.y > player.global_position.y + 0.5: # Above player
		can_attach = true

	if can_attach:
		grapple_target = hit_pos
		is_grappling = true
		stop_gliding()
		grapple_hit.emit(hit_pos)
		gear_activated.emit("astral_grapple", {"target": hit_pos})
		return true

	return false

func cast_spell(cam_origin: Vector3, cam_forward: Vector3) -> bool:
	if not has_elemental_staff or spell_cooldown > 0.0:
		return false

	spell_cooldown = 0.4
	var elem_name := "fire"
	if current_element == Element.ICE:
		elem_name = "ice"
	elif current_element == Element.LIGHTNING:
		elem_name = "lightning"

	spell_cast.emit(elem_name, cam_origin, cam_forward)
	gear_activated.emit("spell_" + elem_name, {"direction": cam_forward})

	# Hitscan / spell projectile raycast
	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam_origin, cam_origin + cam_forward * 30.0)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider:
			if collider.has_method("on_elemental_hit"):
				collider.on_elemental_hit(elem_name, hit.get("position"))
			elif collider.has_method("take_damage"):
				collider.take_damage(25, player.global_position)

	return true

func cycle_element() -> Element:
	current_element = ((current_element + 1) % 3) as Element
	return current_element

func _check_thermal_updraft() -> bool:
	var space_state := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3.DOWN * 8.0)
	query.collide_with_areas = true
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var col = hit.get("collider")
		if col and (col.is_in_group("thermal_updraft") or col.has_meta("thermal")):
			return true
	return false
