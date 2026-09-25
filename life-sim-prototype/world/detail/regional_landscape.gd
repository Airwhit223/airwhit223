extends Node3D
## Deterministic landscape shared by the composed main scene and standalone overworld.
## Town footprints and existing roads remain level; the terrain between them carries the views.
const STEP := 10.0
const EXTENT := 750.0
const WATER_LEVEL := LandscapeShape.WATER_LEVEL
const TOON := preload("res://world/shaders/toon_world.gdshader")
const GROVES := LandscapeShape.GROVES
var _last_dry_positions: Dictionary = {}

static func land_edge(x: float, z: float) -> float:
	return LandscapeShape.land_edge(x, z)

static func install(world: Node3D) -> void:
	if world.has_node("RegionalLandscape"):
		return
	var landscape := Node3D.new()
	landscape.set_script(load("res://world/detail/regional_landscape.gd"))
	landscape.name = "RegionalLandscape"
	world.add_child(landscape)
	landscape.build(world)

static func coast_z(x: float) -> float:
	return LandscapeShape.coast_z(x)

static func height_at(x: float, z: float) -> float:
	return LandscapeShape.height_at(x, z)

func build(world: Node3D) -> void:
	var surfaces := world.get_node("Terrain/GroundSurfaces")
	var canvas := surfaces.get_node_or_null("OverworldGrassCanvas")
	if canvas:
		canvas.visible = false
	# The original canvas collider is a sibling of the mesh, not its child.
	for child in surfaces.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			if child.shape.size.x >= 740.0 and child.shape.size.z >= 740.0:
				child.disabled = true
	var old_water := world.get_node_or_null("Terrain/OceanWater")
	if old_water:
		old_water.visible = false
	for mesh_name in ["CoastalBeachSand", "OceanSeabed"]:
		var old_mesh := surfaces.get_node_or_null(mesh_name) as MeshInstance3D
		if old_mesh:
			old_mesh.visible = false
			for child in surfaces.get_children():
				if child is CollisionShape3D and child.position.is_equal_approx(old_mesh.position):
					child.disabled = true
	_build_ground()
	_build_ocean()
	_build_vegetation()
	_build_islands()
	_build_coastal_trail()

func _physics_process(_delta: float) -> void:
	# No swimming system exists yet. The new ocean must not trap walkers or ridden vehicles.
	for body in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("vehicle"):
		if not body is CharacterBody3D or not body.is_inside_tree():
			continue
		if body.get_parent() is VehicleBase:
			continue
		var p: Vector3 = to_local(body.global_position)
		var id: int = body.get_instance_id()
		if body.is_on_floor() and p.y > WATER_LEVEL + 0.4:
			_last_dry_positions[id] = body.global_position
		elif p.y < WATER_LEVEL - 1.6 and land_edge(p.x, p.z) < 0.0:
			if _last_dry_positions.has(id):
				body.global_position = _last_dry_positions[id] + Vector3.UP * 0.4
				body.velocity = Vector3.ZERO
				if body is VehicleBase:
					body.current_speed = 0.0
				EventBus.fire("hud_message", {"text": "The sea is too deep here. Back to dry ground."})

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(150):
		for ix in range(150):
			var x := -EXTENT + ix * STEP
			var z := -EXTENT + iz * STEP
			for offset in [Vector2(0, 0), Vector2(STEP, 0), Vector2(0, STEP), Vector2(STEP, 0), Vector2(STEP, STEP), Vector2(0, STEP)]:
				var px: float = x + offset.x
				var pz: float = z + offset.y
				var h := height_at(px, pz)
				var coast_distance := land_edge(px, pz)
				var sand := 1.0 - smoothstep(10.0, 65.0, coast_distance)
				var desert := (1.0 - smoothstep(110.0, 205.0, Vector2(px - 255.0, pz + 185.0).length()))
				var grass := Color("779b50").lerp(Color("526e4b"), clampf(h / 65.0, 0, 1))
				st.set_color(grass.lerp(Color("d7b77a"), maxf(sand, desert)))
				st.set_uv(Vector2(px, pz) * 0.03)
				st.add_vertex(Vector3(px, h - 0.025, pz))
	st.generate_normals()
	var mesh := st.commit()
	var ground := MeshInstance3D.new()
	ground.name = "SculptedMainland"
	ground.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/detail/landscape_surface.gdshader")
	ground.material_override = mat
	add_child(ground)
	ground.create_trimesh_collision()

func _build_ocean() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "OpenOcean"
	# Two planes, because one cannot do both jobs: the outer plane is flat and huge and only has to fill the horizon,
	# while the waves in water/toon_water.gdshader are VERTEX displacement and need geometry to move. Subdividing a
	# 14 km plane finely enough for 10 m waves would cost millions of vertices, so the toon water is a smaller,
	# dense plane over the part of the sea the player can actually reach.
	var plane := PlaneMesh.new()
	plane.size = Vector2(14000, 14000)
	sea.mesh = plane
	# well BELOW the coastal sheet, not just under it: the toon water's shore foam comes from the depth buffer, and a
	# solid plane 5 cm down reads as "shallow everywhere" and floods the whole sea with foam
	sea.position.y = WATER_LEVEL - 40.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/detail/open_ocean.gdshader")
	sea.material_override = mat
	add_child(sea)
	_build_coastal_water()

## The swimmable stretch: toon water on a plane dense enough for its waves, covering the bay and both coasts.
const COASTAL_SIZE := 1800.0
const COASTAL_SUBDIV := 300                    # 6 m quads - one wave (wave_length 26) spans about four of them
const COASTAL_CENTRE := Vector3(0.0, 0.0, 420.0)

func _build_coastal_water() -> void:
	var surf := MeshInstance3D.new()
	surf.name = "CoastalWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(COASTAL_SIZE, COASTAL_SIZE)
	plane.subdivide_width = COASTAL_SUBDIV
	plane.subdivide_depth = COASTAL_SUBDIV
	surf.mesh = plane
	surf.position = Vector3(COASTAL_CENTRE.x, WATER_LEVEL, COASTAL_CENTRE.z)
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the ocean preset from water/README.md, with the wave length opened up to suit 6 m quads
	var mat: ShaderMaterial = load("res://water/toon_water.tres").duplicate(true)
	mat.set_shader_parameter("depth_distance", 6.0)
	# the foam noise is sampled in WORLD space, and this world is hundreds of metres across - the default 0.04 makes
	# one noise cell span the whole bay, which reads as giant stripes rather than drifting foam
	mat.set_shader_parameter("surface_noise_scale", 0.35)
	mat.set_shader_parameter("color_bands", 3)
	mat.set_shader_parameter("wave_height", 0.25)
	mat.set_shader_parameter("wave_length", 26.0)
	mat.set_shader_parameter("wave_speed", 1.0)
	mat.set_shader_parameter("flow_speed", 0.02)
	mat.set_shader_parameter("surface_foam_cutoff", 0.72)
	mat.set_shader_parameter("foam_width", 0.45)
	surf.material_override = mat
	add_child(surf)

func _material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("shadow_color", color.darkened(0.28))
	return mat

func _batch(mesh: Mesh, transforms: Array[Transform3D], color: Color, label: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = mm
	instance.material_override = _material(color)
	add_child(instance)

func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23092026
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for i in 1300:
		var x := rng.randf_range(-620, 610)
		var z := rng.randf_range(-650, 260)
		# Keep existing inhabited land free of new obstacles and foliage.
		var in_grove := false
		for center in GROVES:
			if Vector2(x, z).distance_to(center) < 34.0:
				in_grove = true
		if x > -305 and x < 385 and z > -300 and z < 270 and not in_grove:
			continue
		var h := height_at(x, z)
		if coast_z(x) - z < 35 or h < 0:
			continue
		var scale_factor := rng.randf_range(0.8, 1.8)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale_factor)
		if x > 150 and z < -260:
			stones.append(Transform3D(basis.scaled(Vector3(4, 2.5, 3)), Vector3(x, h, z)))
		else:
			trunks.append(Transform3D(basis, Vector3(x, h + 2.5 * scale_factor, z)))
			crowns.append(Transform3D(basis, Vector3(x, h + 7.0 * scale_factor, z)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.65
	trunk.height = 5.0
	trunk.radial_segments = 7
	var crown := SphereMesh.new()
	crown.radius = 4.0
	crown.height = 10.0
	crown.radial_segments = 9
	crown.rings = 5
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	_batch(trunk, trunks, Color("78604a"), "WoodlandTrunks")
	_batch(crown, crowns, Color("467653"), "WoodlandCanopy")
	_batch(rock, stones, Color("b9996b"), "DesertOutcrops")
	var forest_body := StaticBody3D.new()
	forest_body.name = "TreeTrunkCollision"
	add_child(forest_body)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.55
	trunk_shape.height = 5.0
	for placement in trunks:
		var collider := CollisionShape3D.new()
		collider.shape = trunk_shape
		collider.transform = placement
		forest_body.add_child(collider)

func _build_coastal_trail() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-290, 110, 5):
		for offset in [Vector2(0, -2), Vector2(5, -2), Vector2(0, 2), Vector2(5, -2), Vector2(5, 2), Vector2(0, 2)]:
			var px: float = float(x) + offset.x
			var pz: float = coast_z(px) - 24.0 + offset.y
			st.add_vertex(Vector3(px, height_at(px, pz) + 0.025, pz))
	st.generate_normals()
	var trail := MeshInstance3D.new()
	trail.name = "CoastalWalkingTrail"
	trail.mesh = st.commit()
	trail.material_override = _material(Color("b99b6f"))
	add_child(trail)

func _build_islands() -> void:
	for data in [Vector3(-260, 32, 590), Vector3(430, 48, 640), Vector3(20, 23, 810), Vector3(-490, 65, 890)]:
		var island := MeshInstance3D.new()
		island.name = "OffshoreIsland"
		var rock := SphereMesh.new()
		rock.radius = 1.0
		rock.height = 2.0
		rock.radial_segments = 15
		rock.rings = 7
		island.mesh = rock
		island.position = Vector3(data.x, -12, data.z)
		island.scale = Vector3(data.y * 2.4, data.y, data.y * 1.6)
		island.material_override = _material(Color("728d79"))
		add_child(island)
		island.create_trimesh_collision()
