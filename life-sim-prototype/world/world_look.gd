class_name WorldLook
extends RefCounted
## Gives an existing scene the Starter Street look (docs/STARTER_STREET.md): the painted sky and colour handling,
## golden hour / night lighting, the screen-space ink pass, and two-tone toon materials in place of plain
## StandardMaterial3D surfaces.
##
## Used by main.tscn so the whole town reads in the new style while its graybox buildings are replaced with kit
## pieces one at a time.

const STREET := "res://world/starter_street/"
const TOON := preload("res://world/shaders/toon_world.gdshader")
## How much darker the shadow tone is than the lit tone for converted materials (the spec's awning rule, ~30%).
const SHADOW_DARKEN := 0.3
## Scripts that change their own mesh colours at runtime (watered soil, event lighting, enemy hits...). Their
## subtrees keep their StandardMaterial3D so those changes still show.
const KEEP_SCRIPTS := ["res://farming/farm_plot.gd", "res://interactables/guitar_stand.gd",
	"res://interactables/mirror.gd", "res://rpg/enemy.gd", "res://character/character_rig.gd",
	"res://equipment/character_equipment.gd", "res://interactables/adventure_reward.gd"]

static var _cache := {}

## Sky, environment, sun, lighting presets and the ink pass. `sun` may be null (one is created).
static func apply_environment(root: Node3D, world_env: WorldEnvironment, sun: DirectionalLight3D) -> StreetLighting:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = load(STREET + "materials/sky.tres")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.5
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		root.add_child(world_env)
	world_env.environment = env
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		root.add_child(sun)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	var lighting := StreetLighting.new()
	lighting.name = "StreetLighting"
	# paths are relative to the lighting node, which becomes a child of root
	lighting.sun_path = NodePath("../" + String(root.get_path_to(sun)))
	lighting.environment_path = NodePath("../" + String(root.get_path_to(world_env)))
	root.add_child(lighting)
	var ink := MeshInstance3D.new()
	ink.name = "InkPass"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	ink.mesh = quad
	ink.material_override = load(STREET + "materials/ink_screen.tres")
	ink.extra_cull_margin = 16384.0
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ink)
	return lighting

## Swap plain StandardMaterial3D surfaces under `node` for two-tone toon materials of the same colour.
static func toon_subtree(node: Node) -> void:
	var script: Script = node.get_script()
	if script and KEEP_SCRIPTS.has(script.resource_path):
		return
	if node is MeshInstance3D:
		_toon_mesh(node)
	for child in node.get_children():
		toon_subtree(child)

static func _toon_mesh(mi: MeshInstance3D) -> void:
	if mi.material_override is StandardMaterial3D:
		mi.material_override = toon_for(mi.material_override)
		return
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		if m is StandardMaterial3D:
			mi.set_surface_override_material(i, toon_for(m))

## One shared toon material per colour.
static func toon_for(std: StandardMaterial3D) -> Material:
	if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or std.emission_enabled:
		return std                           # glass, glows and effects stay as they are
	var c := std.albedo_color
	var key := c.to_html()
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("base_color", c)
		m.set_shader_parameter("shadow_color", c.darkened(SHADOW_DARKEN))
		_cache[key] = m
	return _cache[key]
