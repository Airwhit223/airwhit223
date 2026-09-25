extends SceneTree
## Builds THE UNDERWORLD beneath the Origin Nexus - the piece the sky island planet was missing.
##
## What it is (from the user's brief): the underside of the cosmic planet, where the ancient race actually lives.
## Not the ruined metropolis above, but a home village - and the draconics live there with them, in peace. Around
## the village the cavern opens into elemental biomes the two peoples train in. The lore tablets along the road
## carry the rest: the two races fought a long war up on the surface, lost it, and came down here together.
##
## Layout (a 360 m cavern, entered from the gravity lift at the village's edge):
##   centre      Hollowlight Village + the draconic roosts on the cavern walls above it
##   ring 120 m  five elemental training grounds - ember, tide, stone, storm, aether
##   between     four lore tablets on the roads out
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/build_sky_underworld.gd
## NOT headless - MultiMesh data and shader defaults are dropped in headless mode (see build_starter_street.gd).

const DIR := "res://world/sky_island_planet/underworld/"
const SKY := "res://world/sky_island_planet/"
const TOON := "res://world/shaders/toon_world.gdshader"

## base, shadow, line_mode, line_spacing, glow
const PALETTE := {
	# Hatching is for props, not for the ground: at 360 m a 0.6 m line spacing turns the whole cavern into moire.
	"underworld_bedrock": ["#40304F", "#241A31", 0, 0.0, 0.0],
	"cavern_ceiling": ["#1C1526", "#0E0A14", 0, 0.0, 0.0],
	"village_ground": ["#2F6A6B", "#17383C", 0, 0.0, 0.35],
	"hearth_ember": ["#FF8A3D", "#C24E10", 0, 0.0, 3.4],
	"village_timber": ["#6B4A7A", "#3D2947", 1, 0.55, 0.0],
	"village_thatch": ["#C9B8E8", "#7E6C9E", 1, 0.22, 0.0],
	"draconic_scale_jade": ["#3FBF7F", "#1B6B45", 0, 0.0, 0.8],
	"draconic_scale_dusk": ["#8F5BD6", "#4C2A78", 0, 0.0, 0.8],
	"tide_water": ["#2FA8E0", "#12557A", 0, 0.0, 1.6],
	"storm_cloud": ["#B9C9FF", "#5A6B99", 0, 0.0, 2.0],
	"stone_training": ["#6E6480", "#3A3347", 3, 1.10, 0.0],
	"aether_light": ["#C9A2FF", "#6B3FB0", 0, 0.0, 3.0],
	"lore_tablet": ["#D6CBEF", "#8478A8", 3, 0.90, 0.0],
}

## id, display, colour key, position, the element trained there
const BIOMES := [
	["ember", "Ember Hollow", "magma_vein", Vector3(0, 0, -120), "fire"],
	["tide", "The Tidepool Deep", "tide_water", Vector3(114, 0, -37), "water"],
	["stone", "Stoneheart Terrace", "stone_training", Vector3(70, 0, 97), "earth"],
	["storm", "The Stormvault", "storm_cloud", Vector3(-70, 0, 97), "air"],
	["aether", "The Aether Well", "aether_light", Vector3(-114, 0, -37), "aether"],
]

## The war, told in four stones on the way out of the village.
const LORE := [
	["LoreTablet1", Vector3(0, 0, -58), "THE FIRST SKY\nWe built the cities above on light we did not understand.\nThe draconics warned us. We called it envy."],
	["LoreTablet2", Vector3(58, 0, -20), "THE BURNING OF THE SPIRES\nNine hundred years of war for a sky that was already dying.\nBoth peoples counted their dead in the same numbers."],
	["LoreTablet3", Vector3(-58, 0, -20), "THE DESCENT\nWhen the light failed, the wings carried the wingless down.\nNo terms were written. There was no one left to write them to."],
	["LoreTablet4", Vector3(0, 0, 54), "HOLLOWLIGHT\nWe train in the deep so the deep does not take us.\nOur children cannot tell which of them is which. Let it stay that way."],
]

var M := {}

func _initialize() -> void:
	_build.call_deferred()

func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("could not save %s (%d)" % [path, err])

func _materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "materials"))
	for key in PALETTE:
		var p: Array = PALETTE[key]
		var m := ShaderMaterial.new()
		m.shader = load(TOON)
		m.set_shader_parameter("base_color", Color(p[0]))
		m.set_shader_parameter("shadow_color", Color(p[1]))
		m.set_shader_parameter("line_mode", p[2])
		if p[3] > 0.0:
			m.set_shader_parameter("line_spacing", p[3])
		if p[2] > 0:
			m.set_shader_parameter("line_color", Color(p[1]).darkened(0.5))
		if p[4] > 0.0:
			m.set_shader_parameter("glow", p[4])
		_save(m, DIR + "materials/%s.tres" % key)
		M[key] = load(DIR + "materials/%s.tres" % key)
	# the cavern borrows the planet's own rock and crystal so it reads as the same world, one floor down
	for shared in ["planet_bedrock_mauve", "quartz_crystal_cyan", "quartz_crystal_magenta", "quartz_crystal_violet",
			"magma_vein", "ancient_city_wall", "ancient_gold_trim", "bioluminescent_teal_turf", "power_grid_energy"]:
		M[shared] = load(SKY + "materials/%s.tres" % shared)

func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mi.add_child(body)
	return mi

func _shape(parent: Node3D, node_name: String, pos: Vector3, mesh: Mesh, mat: Material, scale := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _cone(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	return c

func _marker(parent: Node3D, node_name: String, pos: Vector3, meta: Dictionary = {}) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	for key in meta:
		n.set_meta(key, meta[key])
	return n

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_materials()
	var root := Node3D.new()
	root.name = "Underworld"

	# --- the cavern itself ------------------------------------------------------------------------------------
	var cavern := Node3D.new(); cavern.name = "Cavern"; root.add_child(cavern)
	_box(cavern, "BedrockFloor", Vector3(0, -1.0, 0), Vector3(360, 2, 360), M["underworld_bedrock"])
	_box(cavern, "CavernCeiling", Vector3(0, 52.0, 0), Vector3(360, 4, 360), M["cavern_ceiling"])
	for i in 4:                      # walls, so the cavern reads as enclosed from inside
		var a := i * TAU / 4.0
		var pos := Vector3(sin(a) * 180.0, 25.0, cos(a) * 180.0)
		var size := Vector3(360, 52, 6) if i % 2 == 0 else Vector3(6, 52, 360)
		_box(cavern, "CavernWall%d" % i, pos, size, M["underworld_bedrock"])
	# stalactites, lit from within, so the ceiling is not a flat lid
	var spikes := Node3D.new(); spikes.name = "Stalactites"; cavern.add_child(spikes)
	var rng := RandomNumberGenerator.new(); rng.seed = 20260923
	var crystal_keys := ["quartz_crystal_cyan", "quartz_crystal_magenta", "quartz_crystal_violet"]
	for i in 60:
		var x := rng.randf_range(-165.0, 165.0)
		var z := rng.randf_range(-165.0, 165.0)
		if Vector2(x, z).length() < 34.0:
			continue                 # leave the sky above the village clear
		var h := rng.randf_range(6.0, 20.0)
		_shape(spikes, "Stalactite%d" % i, Vector3(x, 50.0 - h * 0.5, z), _cone(rng.randf_range(1.2, 3.4), h),
			M[crystal_keys[i % 3]], Vector3.ONE, Vector3(PI, 0, 0))

	# --- Hollowlight Village ----------------------------------------------------------------------------------
	var village := Node3D.new(); village.name = "HollowlightVillage"; root.add_child(village)
	_box(village, "VillagePlaza", Vector3(0, 0.15, 0), Vector3(58, 0.3, 58), M["village_ground"])
	# the hearth at the centre: the fire both peoples keep
	_shape(village, "GreatHearth", Vector3(0, 1.4, 0), _cone(3.4, 2.8), M["hearth_ember"])
	_box(village, "HearthRing", Vector3(0, 0.35, 0), Vector3(9, 0.7, 9), M["stone_training"])
	# dwellings in a ring - ancient stonework with draconic-scale roofs, because they build them together
	for i in 7:
		var a := i * TAU / 7.0
		var pos := Vector3(sin(a) * 22.0, 0.0, cos(a) * 22.0)
		var hut := Node3D.new(); hut.name = "Dwelling%d" % (i + 1); hut.position = pos
		hut.rotation.y = -a
		village.add_child(hut)
		_box(hut, "Walls", Vector3(0, 2.2, 0), Vector3(7.5, 4.4, 7.5), M["ancient_city_wall"])
		_shape(hut, "Roof", Vector3(0, 6.0, 0), _cone(6.2, 3.4),
			M["draconic_scale_jade"] if i % 2 == 0 else M["draconic_scale_dusk"])
		_box(hut, "Door", Vector3(0, 1.3, 3.85), Vector3(1.8, 2.6, 0.2), M["village_timber"], false)
		_box(hut, "Lintel", Vector3(0, 2.8, 3.9), Vector3(2.6, 0.3, 0.3), M["ancient_gold_trim"], false)
	# the great hall, where the two peoples meet
	var hall := Node3D.new(); hall.name = "GreatHall"; hall.position = Vector3(0, 0, -30); village.add_child(hall)
	_box(hall, "Walls", Vector3(0, 4.0, 0), Vector3(22, 8, 13), M["ancient_city_wall"])
	_shape(hall, "Roof", Vector3(0, 10.0, 0), _cone(15.0, 5.0), M["draconic_scale_dusk"])
	_box(hall, "Doors", Vector3(0, 2.6, 6.6), Vector3(4.4, 5.2, 0.3), M["village_timber"], false)
	for side in [-1.0, 1.0]:
		_box(hall, "Brazier%s" % ("L" if side < 0 else "R"), Vector3(side * 7.0, 1.2, 7.4),
			Vector3(1.2, 2.4, 1.2), M["hearth_ember"], false)

	# --- draconic roosts, on ledges above the village -----------------------------------------------------------
	var roosts := Node3D.new(); roosts.name = "DraconicRoosts"; root.add_child(roosts)
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		var height := 14.0 + float(i % 3) * 5.0
		var pos := Vector3(sin(a) * 52.0, height, cos(a) * 52.0)
		var ledge := Node3D.new(); ledge.name = "Roost%d" % (i + 1); ledge.position = pos; roosts.add_child(ledge)
		_box(ledge, "Ledge", Vector3.ZERO, Vector3(16, 2.4, 14), M["underworld_bedrock"])
		_box(ledge, "Buttress", Vector3(0, -height * 0.5, 0), Vector3(5, height, 5), M["underworld_bedrock"])
		_shape(ledge, "NestRim", Vector3(0, 1.8, 0), TorusMesh.new(), M["draconic_scale_jade"], Vector3(3.2, 1.0, 3.2))
		_shape(ledge, "Egg", Vector3(0, 2.0, 0), SphereMesh.new(), M["quartz_crystal_violet"], Vector3(1.4, 1.8, 1.4))
		_marker(ledge, "DraconicPerch", Vector3(0, 1.4, 0), {"species": "draconic", "roost": i + 1})

	# --- elemental training grounds ------------------------------------------------------------------------------
	var grounds := Node3D.new(); grounds.name = "ElementalBiomes"; root.add_child(grounds)
	for entry in BIOMES:
		var id: String = entry[0]
		var display: String = entry[1]
		var colour: String = entry[2]
		var centre: Vector3 = entry[3]
		var element: String = entry[4]
		var biome := Node3D.new(); biome.name = "Biome_" + id.capitalize(); biome.position = centre
		grounds.add_child(biome)
		_box(biome, "Terrace", Vector3(0, 0.25, 0), Vector3(48, 0.5, 48), M[colour])
		# a ring of pillars marks every training ground, each keyed to its element's colour
		for i in 8:
			var a := i * TAU / 8.0
			_box(biome, "Pillar%d" % (i + 1), Vector3(sin(a) * 19.0, 3.0, cos(a) * 19.0),
				Vector3(1.6, 6.0, 1.6), M["stone_training"])
			_shape(biome, "PillarLight%d" % (i + 1), Vector3(sin(a) * 19.0, 6.6, cos(a) * 19.0),
				SphereMesh.new(), M[colour], Vector3(1.1, 1.1, 1.1))
		# the element itself, in the middle of the ring
		match element:
			"fire":
				_box(biome, "MagmaPool", Vector3(0, 0.45, 0), Vector3(16, 0.4, 16), M["magma_vein"], false)
				for i in 3:
					_shape(biome, "Obsidian%d" % (i + 1), Vector3(-5.0 + i * 5.0, 2.0, 2.0),
						_cone(1.8, 4.0), M["underworld_bedrock"])
			"water":
				_box(biome, "TidePool", Vector3(0, 0.4, 0), Vector3(18, 0.3, 18), M["tide_water"], false)
				for i in 4:
					var a2 := i * TAU / 4.0
					_shape(biome, "Geyser%d" % (i + 1), Vector3(sin(a2) * 6.0, 2.4, cos(a2) * 6.0),
						CylinderMesh.new(), M["tide_water"], Vector3(0.5, 2.4, 0.5))
			"earth":
				for i in 5:
					var a3 := i * TAU / 5.0
					_shape(biome, "Monolith%d" % (i + 1), Vector3(sin(a3) * 6.5, 4.0, cos(a3) * 6.5),
						_cone(2.2, 8.0), M["quartz_crystal_violet"])
			"air":
				for i in 4:
					_box(biome, "UpdraftPad%d" % (i + 1), Vector3(-9.0 + i * 6.0, 1.0 + i * 2.5, 0.0),
						Vector3(5, 0.4, 5), M["storm_cloud"])
				_shape(biome, "StormCore", Vector3(0, 12.0, 0), SphereMesh.new(), M["storm_cloud"],
					Vector3(3.0, 3.0, 3.0))
			"aether":
				_shape(biome, "AetherWell", Vector3(0, 1.0, 0), CylinderMesh.new(), M["aether_light"],
					Vector3(6.0, 1.0, 6.0))
				_shape(biome, "AetherColumn", Vector3(0, 14.0, 0), CylinderMesh.new(), M["aether_light"],
					Vector3(1.2, 13.0, 1.2))
		_marker(biome, "TrainingSpot", Vector3(0, 0.5, 14.0),
			{"biome_id": id, "display_name": display, "element": element, "skill": "adventure"})
		_marker(biome, "BiomeEntrance", Vector3(0, 0.5, 24.0), {"biome_id": id, "display_name": display})
		# a road back to the village, so the cavern reads as connected rather than as five islands
		var to_village := -centre.normalized()
		var road := Node3D.new(); road.name = "RoadToVillage"; biome.add_child(road)
		var span := centre.length() - 54.0
		road.position = to_village * (24.0 + span * 0.5)
		road.rotation.y = atan2(to_village.x, to_village.z)
		_box(road, "Roadbed", Vector3.ZERO, Vector3(7.0, 0.2, span), M["stone_training"], false)

	# --- the war, on four stones --------------------------------------------------------------------------------
	var lore := Node3D.new(); lore.name = "LoreTablets"; root.add_child(lore)
	for entry in LORE:
		var tablet := Node3D.new(); tablet.name = entry[0]; tablet.position = entry[1]; lore.add_child(tablet)
		tablet.rotation.y = atan2(-entry[1].x, -entry[1].z)
		_box(tablet, "Slab", Vector3(0, 2.2, 0), Vector3(4.0, 4.4, 0.5), M["lore_tablet"])
		_box(tablet, "Base", Vector3(0, 0.3, 0), Vector3(5.0, 0.6, 1.6), M["stone_training"])
		_shape(tablet, "Rune", Vector3(0, 4.6, 0), SphereMesh.new(), M["aether_light"], Vector3(0.6, 0.6, 0.6))
		tablet.set_meta("lore_text", entry[2])
		tablet.set_meta("lore_title", "The War Above")

	# --- arrival and links ---------------------------------------------------------------------------------------
	var links := Node3D.new(); links.name = "Links"; root.add_child(links)
	_box(links, "GravityLiftPad", Vector3(34, 0.3, 0), Vector3(12, 0.6, 12), M["power_grid_energy"])
	_marker(links, "ArrivalSpawn", Vector3(34, 0.8, 8), {"from": "sky_island_planet"})
	_marker(links, "ReturnToSurface", Vector3(34, 0.8, 0), {"target": "sky_island_planet"})
	# the fire cave that already exists is this cavern's fire trial, reached from Ember Hollow
	_marker(links, "FireCaveEntrance", Vector3(0, 0.8, -142),
		{"target": "res://world/sky_island_planet/dungeons/elemental_fire_cave.tscn", "biome_id": "ember"})

	root.set_script(load(DIR + "underworld.gd"))
	var packed := PackedScene.new()
	for child in root.get_children():
		_own(child, root)
	if packed.pack(root) != OK:
		push_error("pack failed")
		quit(1)
		return
	_save(packed, DIR + "underworld.tscn")
	print("UNDERWORLD built: ", _count(root), " nodes -> ", DIR + "underworld.tscn")
	quit()

func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)

func _count(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count(child)
	return c
