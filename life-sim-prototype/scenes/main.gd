extends Node3D
## Boots the neighborhood: bakes the navmesh, registers every named location,
## spawns the five persistent NPCs from NPCRoster onto their households, and
## drops the player and HUD into the one continuous world.

const NPCScene := preload("res://scenes/npc.tscn")
const PlayerScene := preload("res://scenes/player.tscn")
const HUDScene := preload("res://ui/hud.tscn")
const FarmPlotScript := preload("res://farming/farm_plot.gd")
const GuitarStandScript := preload("res://interactables/guitar_stand.gd")
const DangerZoneScript := preload("res://interactables/danger_zone.gd")
const MirrorScript := preload("res://interactables/mirror.gd")
const IntroScript := preload("res://scenes/intro_sequence.gd")
const RewardScript := preload("res://interactables/adventure_reward.gd")
const EnemyScript := preload("res://rpg/enemy.gd")
const HomeStorageChestScript := preload("res://interactables/home_storage_chest.gd")

const NPC_COLORS := {
	"maya": Color(0.85, 0.35, 0.55),
	"jordan": Color(0.35, 0.65, 0.85),
	"alex": Color(0.85, 0.65, 0.15),
	"riley": Color(0.55, 0.85, 0.35),
	"sam": Color(0.65, 0.65, 0.85),
}

@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var locations_root: Node3D = $Locations

func _ready() -> void:
	_fold_in_world()
	_dress_buildings()
	nav_region.bake_navigation_mesh(false)
	_add_rival_homes()
	_register_locations()
	_register_households()
	_spawn_garden()
	_spawn_guitar_stand()
	_spawn_adventure_area()
	_apply_world_look()
	for pair in NPCRoster.FAMILY_PAIRS:
		RelationshipManager.declare_family(pair[0], pair[1])
	_spawn_npcs()
	_spawn_rivals()
	_spawn_bram_family()
	_spawn_townsfolk()
	_connect_town_growth()
	_assign_hardships()
	WorldState.register_workplace_interior("loc_store", get_node("%StoreWorkSpot"))
	WorldState.assign_job("general_store_clerk", "maya")
	_spawn_player()
	_spawn_mirror()
	_spawn_home_storage_chest()
	_spawn_restaurant()
	_spawn_ranch()
	_spawn_skate_shop()
	_spawn_contracts()
	add_child(HUDScene.instantiate())
	call_deferred("_apply_loaded_game")

func _apply_loaded_game() -> void:
	SaveManager.apply_pending_load()

## The Rolling Tides world (built in the Antigravity copy) is the land AROUND this neighborhood: the coast, the
## Olde Town, the neon strip, the forest and the far landmarks. Starter Street stays the home district, so the
## world's own copy of a neighborhood at the origin is dropped on the way in - it would sit inside ours.
## Its districts are already placed around us: Olde Town (-200, -220), Neon Tokyo (260, -30), Old Shore (180, 250).
const WORLD_SCENE := "res://world/rolling_tides_world/rolling_tides_world.tscn"
## The world's neighborhood is the DESIGNED one - the house, the skateshop, the sidewalk and its props are the
## street the player is meant to spawn into, so it is kept whole and this scene's graybox copies stand down
## instead (see _defer_to_world_neighborhood). Only what this scene genuinely owns is dropped.
const WORLD_STRIP := [
	"Player",                                # this scene spawns the player at home_player
	"WorldEnvironment", "Sun",               # our own sky and sun, tuned in world_look.gd
	"Landmarks/NeighborhoodBasketballCourt", # this scene's court and hoop already stand where it would
]

func _fold_in_world() -> void:
	var packed: PackedScene = load(WORLD_SCENE)
	if packed == null:
		push_warning("Rolling Tides world missing; running on Starter Street alone")
		return
	var world: Node3D = packed.instantiate()
	world.name = "RollingTidesWorld"
	for path in WORLD_STRIP:
		var node := world.get_node_or_null(path)
		if node:
			node.get_parent().remove_child(node)
			node.queue_free()
	preload("res://world/detail/regional_landscape.gd").install(world)   # our procedural terrain, newer than _widen_overworld
	_link_neighborhood_to_shore(world)
	# The world places the three who live on this street (Mr. Jones, Jace, Maya) on their own spots - the bench,
	# the shop counter, the court. This scene spawns the whole rival roster, so without this it would put a second
	# copy of each of them on top.
	for npc_id in world.get("DISTRICT_NPCS") if world.get("DISTRICT_NPCS") != null else {}:
		_world_owned_npcs[npc_id] = true
	add_child(world)
	move_child(world, 0)
	# The world's grass canvas tops out at y = 0, exactly where this neighborhood's ground sits. Lift ours by a
	# centimetre so it wins the depth test across the whole street instead of z-fighting with the overworld.
	var ground := nav_region.get_node_or_null("Ground") as Node3D
	if ground:
		ground.position.y += 0.01
	_defer_to_world_neighborhood(world)


## The designed street lives in the world scene: the player's house at (-7.5, -10.2), the skateshop at (7.5, 8.3),
## the turnip garden, the sidewalk and thirty-odd props between them. This scene grew its own graybox versions of
## the same things in the same place, so they are stood down and its anchors moved onto the real buildings:
## the player now spawns on the porch of the house they were always meant to live in.
const WORLD_PORCH := Vector3(-7.5, 0, -5.8)       # PlayerHouse's porch exit, from the world's NPCSpawns
const MOVED_ANCHORS := {
	"home_player": WORLD_PORCH,
	"loc_social": Vector3(0, 0, 30),              # the street centre belongs to the world's road now
}

func _defer_to_world_neighborhood(_world: Node3D) -> void:
	var duplicate_home := nav_region.get_node_or_null("PlayerHome")
	if duplicate_home:
		duplicate_home.queue_free()               # _dress_buildings skips what it cannot find
	for pad_name in ["SocialPad", "Firepit"]:     # the fire lawn sat in the middle of the world's street
		var pad := get_node_or_null("Decor/" + pad_name) as Node3D
		if pad:
			pad.position.z += 30.0
	for marker_name in MOVED_ANCHORS:
		var marker := locations_root.get_node_or_null(marker_name) as Node3D
		if marker:
			marker.position = MOVED_ANCHORS[marker_name]
	_home_rivals_across_the_world(_world)
	_add_detail_layers(_world)


## Our own landscape detail, kept in world/detail/ rather than written into the world scene - that file comes from
## the Antigravity copy and is re-synced, which would wipe anything added to it.
const DETAIL_LAYERS := [
	"res://world/detail/khem_detail.tscn",
	"res://world/detail/old_shore_detail.tscn",
	"res://world/detail/farm_valleys_detail.tscn",
	"res://world/detail/lagoon_detail.tscn",
	"res://world/detail/crystal_mine_detail.tscn",
	"res://world/detail/tree_village_detail.tscn",
	"res://world/detail/bigger_cities_detail.tscn",
	"res://world/detail/sand_villages_detail.tscn",
]

func _add_detail_layers(world: Node3D) -> void:
	for path in DETAIL_LAYERS:
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		world.add_child(packed.instantiate())
	_bake_district_navigation(world)
	# Vehicles are NOT spawned here. The world scene already instantiates the real hoverboard, speed bike,
	# sandboard and space capsule at its parked landmarks - they were rideable all along. Adding our own put a
	# second copy of each on top of the originals.


## The land itself. The world shipped on a 750 m canvas; the regions are meant to sit far enough apart that a
## hoverboard, a bike or flight is the sensible way to cross, so the ground is opened out to 1500 m. Only the
## canvas grows - the districts keep their own coordinates.
const OVERWORLD_SPAN := 1500.0

func _widen_overworld(world: Node3D) -> void:
	var canvas := world.get_node_or_null("Terrain/GroundSurfaces/OverworldGrassCanvas") as MeshInstance3D
	if canvas == null:
		return
	var mesh := canvas.mesh as BoxMesh
	if mesh:
		mesh = mesh.duplicate()
		mesh.size = Vector3(OVERWORLD_SPAN, mesh.size.y, OVERWORLD_SPAN)
		canvas.mesh = mesh
	for child in canvas.get_children():        # the floor you actually stand on has to grow with it
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		var box := shape.shape as BoxShape3D
		if box:
			box = box.duplicate()
			box.size = Vector3(OVERWORLD_SPAN, box.size.y, OVERWORLD_SPAN)
			shape.shape = box


## The road to the coast existed but nothing met it: it ran south from (85, 25) while the boulevard stopped short
## of this street, so the neighborhood and the shore town were two islands with grass between them. These slabs
## close both gaps, giving one continuous route - street, east along the boulevard, south to the boardwalk.
func _link_neighborhood_to_shore(world: Node3D) -> void:
	var roads := world.get_node_or_null("RoadsAndCurbs") as Node3D
	var existing := world.get_node_or_null("RoadsAndCurbs/BoulevardEastWest") as MeshInstance3D
	if roads == null or existing == null:
		return
	var surface: Material = existing.get_active_material(0)
	_add_road(roads, "BoulevardWestApproach", Vector3(-16.0, 0.03, -15.0), Vector3(58.0, 0.06, 7.2), surface)
	_add_road(roads, "CoastRoadNorthApproach", Vector3(85.0, 0.03, 5.0), Vector3(7.2, 0.06, 50.0), surface)
	_add_road(roads, "CoastRoadJunction", Vector3(85.0, 0.031, -15.0), Vector3(12.0, 0.06, 12.0), surface)


func _add_road(parent: Node3D, road_name: String, position: Vector3, size: Vector3, surface: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var slab := MeshInstance3D.new()
	slab.name = road_name
	slab.mesh = mesh
	slab.position = position
	if surface:
		slab.material_override = surface
	parent.add_child(slab)


## Only three characters live on this street. The rest belong further out in Rolling Tides - without a home
## location of their own they all defaulted to the world origin and stood in a heap in the middle of the new
## neighborhood. Each one is given a home out in the district that suits them, taken from the world's own spots.
const RIVAL_DISTRICT_HOMES := {
	"home_theo": "NPCSpawns/TavernSpot",                   # the Olde Town, reading and quiet
	"home_blair": "Landmarks/PlazaGrindRail1",             # the neon plaza, fashion and music
	"home_kira": "NPCSpawns/PierSpot",                     # the boardwalk, skating and the coast
	# Somewhere for them to GO in their own district. Their schedules used to name loc_skate and loc_social back
	# here, which meant a 250 m walk across districts with no navmesh between - so they never moved at all.
	"loc_tavern": "NPCSpawns/TavernSpot",
	"loc_neon_plaza": "Landmarks/PlazaGrindRail2",
	"loc_boardwalk": "NPCSpawns/PierSpot",
}

func _home_rivals_across_the_world(world: Node3D) -> void:
	for location_id in RIVAL_DISTRICT_HOMES:
		var spot := world.get_node_or_null(RIVAL_DISTRICT_HOMES[location_id]) as Node3D
		if spot == null:
			continue
		var marker := Node3D.new()
		marker.name = location_id
		locations_root.add_child(marker)
		marker.global_position = spot.global_position


## Anyone living outside this neighborhood had nothing to walk on: the scene's NavRegion only covers the home
## street, so the rivals out in the districts stood on their spawn all day. Each district gets its own region,
## baked from the world geometry inside its own box - one big navmesh over 1500 m would take far longer to bake
## and most of it is empty dune anyway.
const DISTRICT_NAV := {
	"NavShore": {"centre": Vector3(172, 4, 244), "size": Vector3(130, 24, 60)},
	"NavKhem": {"centre": Vector3(240, 8, -165), "size": Vector3(180, 40, 150)},
	"NavOldeTown": {"centre": Vector3(-200, 8, -222), "size": Vector3(110, 30, 110)},
	"NavTokyo": {"centre": Vector3(255, 6, -30), "size": Vector3(110, 30, 90)},
	"NavFarms": {"centre": Vector3(-110, 4, -110), "size": Vector3(100, 20, 100)},
	"NavLagoon": {"centre": Vector3(0, 4, -220), "size": Vector3(90, 20, 90)},
	"NavMines": {"centre": Vector3(150, 6, -220), "size": Vector3(80, 25, 80)},
	"NavTreeVillage": {"centre": Vector3(-80, 8, -260), "size": Vector3(90, 30, 90)},
	"NavMetropolis": {"centre": Vector3(-200, 6, 40), "size": Vector3(110, 25, 110)},
	"NavSandVillage": {"centre": Vector3(310, 6, -130), "size": Vector3(90, 25, 90)},
}

func _bake_district_navigation(world: Node3D) -> void:
	world.add_to_group("navmesh_source")
	for region_name in DISTRICT_NAV:
		var spec: Dictionary = DISTRICT_NAV[region_name]
		var region := NavigationRegion3D.new()
		region.name = region_name
		var nav := NavigationMesh.new()
		nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		nav.geometry_source_group_name = "navmesh_source"
		nav.filter_baking_aabb = AABB(spec["centre"] - spec["size"] * 0.5, spec["size"])
		nav.cell_size = 0.3
		nav.agent_radius = 0.45
		nav.agent_max_slope = 45.0
		region.navigation_mesh = nav
		add_child(region)
		region.bake_navigation_mesh(false)


## Graybox buildings swapped for Starter Street kit pieces, one at a time. The graybox body keeps its node (other
## code finds it by name) but loses its box mesh and collider; the kit scene brings its own. PlayerHome is gone -
## the world's designed house replaced it - and the loop skips what it cannot find.
const KIT_BUILDINGS := {
	"PlayerHome": {"scene": "res://world/starter_street/props/house.tscn", "position": Vector3(-24, 0, -23.3), "yaw": 0.0},
	"Store": {"scene": "res://world/starter_street/shop.tscn", "position": Vector3(-18, 0, 19.6), "yaw": 180.0},
}


func _dress_buildings() -> void:
	for body_name in KIT_BUILDINGS:
		var body := nav_region.get_node_or_null(body_name) as Node3D
		if body == null:
			continue
		var spec: Dictionary = KIT_BUILDINGS[body_name]
		for child in body.get_children():
			if child is MeshInstance3D:
				child.visible = false
			elif child is CollisionShape3D:
				child.disabled = true
		var kit: Node3D = load(spec["scene"]).instantiate()
		kit.name = body_name + "Kit"
		kit.position = spec["position"]
		kit.rotation_degrees.y = spec["yaw"]
		nav_region.add_child(kit)
	# the graybox door slabs would stand in front of the kit doors; keep the interactables, hide their meshes
	for door_path in ["Interactables/PlayerHomeDoor", "Interactables/StoreDoor"]:
		var door := get_node_or_null(door_path)
		if door:
			for child in door.get_children():
				if child is MeshInstance3D:
					child.visible = false

## The Starter Street look for the whole town (docs/STARTER_STREET.md): painted sky, golden hour / night, ink
## outlines and two-tone materials. Runs before anyone is spawned, so characters keep their own shaders.
func _apply_world_look() -> void:
	WorldLook.apply_environment(self, $WorldEnvironment, $Sun)
	$Sun.rotation_degrees = Vector3(-30, -58, 0)
	for child in get_children():
		WorldLook.toon_subtree(child)

func _register_locations() -> void:
	for child in locations_root.get_children():
		WorldState.register_location(child.name, child)

func _register_households() -> void:
	for household_id in NPCRoster.HOUSEHOLDS:
		WorldState.register_household(household_id, NPCRoster.HOUSEHOLDS[household_id])

func _spawn_npcs() -> void:
	for definition in NPCRoster.build():
		var npc = NPCScene.instantiate()
		npc.setup(definition, NPC_COLORS.get(definition.id, Color.WHITE))
		add_child(npc)
		if WorldState.has_location(definition.home_location_id):
			npc.global_position = WorldState.get_location_position(definition.home_location_id)

## Ordinary townsfolk, generated rather than authored: name, job, two traits and the tonal register those traits
## imply (see TownsfolkGenerator). They use the same NPC scene and brain as everyone else. Seeded, so a given town
## always has the same people.
const TOWNSFOLK_COUNT := 24
const TOWNSFOLK_SEED := 20260917

const DISTRICT_CENTERS := {
	"Starter Street": Vector3(-20, 0, -35),
	"Olde Town": Vector3(-200, 0, -222),
	"Neon Tokyo": Vector3(255, 0, -30),
	"Old Shore": Vector3(172, 0, 244),
	"The Farm Valleys": Vector3(-110, 0, -110),
	"The Quiet Lagoon": Vector3(0, 0, -220),
	"The Crystal Mines": Vector3(150, 0, -220),
	"The Ancient Tree Village": Vector3(-80, 0, -260),
	"Metro City Center": Vector3(-200, 0, 40),
	"Sand Villages of Khem": Vector3(310, 0, -130),
}

const DISTRICT_WORKPLACES := {
	"loc_store": Vector3(-15, 0, -10),
	"loc_gym": Vector3(-5, 0, -15),
	"loc_social": Vector3(-25, 0, -20),
	"loc_tavern": Vector3(-200, 0, -222),
	"loc_neon_plaza": Vector3(255, 0, -30),
	"loc_pier": Vector3(172, 0, 244),
	"loc_fishing": Vector3(160, 0, 250),
	"loc_farm_valley": Vector3(-110, 0, -110),
	"loc_lagoon": Vector3(0, 0, -220),
	"loc_crystal_mines": Vector3(150, 0, -220),
	"loc_tree_village": Vector3(-80, 0, -260),
	"loc_metro_city": Vector3(-200, 0, 40),
	"loc_sand_villages": Vector3(310, 0, -130),
}

func _spawn_townsfolk() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TOWNSFOLK_SEED
	var locations: Node3D = locations_root

	# Ensure all district workplace locations exist in WorldState
	for place_id in DISTRICT_WORKPLACES:
		if not WorldState.has_location(place_id):
			var place_marker := Node3D.new()
			place_marker.name = place_id
			place_marker.position = DISTRICT_WORKPLACES[place_id]
			locations.add_child(place_marker)
			WorldState.register_location(place_id, place_marker)

	for i in TOWNSFOLK_COUNT:
		var definition := TownsfolkGenerator.generate(rng, i)
		if not WorldState.has_location(definition.home_location_id):
			var marker := Node3D.new()
			marker.name = definition.home_location_id
			var district_name: String = String(TownsfolkGenerator.JOBS.get(definition.occupation, {}).get("district", "Starter Street"))
			var center: Vector3 = DISTRICT_CENTERS.get(district_name, Vector3(-20, 0, -35))
			var offset := Vector3(
				((i % 3) - 1.0) * 8.0,
				0.0,
				((int(i / 3) % 3) - 1.0) * 8.0
			)
			marker.position = center + offset
			locations.add_child(marker)
			WorldState.register_location(marker.name, marker)
		WorldState.register_household(definition.household_id, [definition.id])
		var npc = NPCScene.instantiate()
		npc.setup(definition, Color(0.6, 0.66, 0.72))
		npc.add_to_group("townsfolk")
		add_child(npc)
		npc.global_position = WorldState.get_location_position(definition.home_location_id)

## Some townsfolk are struggling; a few of those struggles have a Dream Realm cause (see Hardships). Only generated
## people and newcomers are eligible — the authored cast have their own written stories.
func _assign_hardships() -> void:
	var ids: Array = []
	for npc in get_tree().get_nodes_in_group("townsfolk"):
		ids.append(npc.definition.id)
	Hardships.assign(ids, TOWNSFOLK_SEED)

## Town growth: buildings go up when their level or story milestone lands, and the people who move in are spawned
## into them. Anything already unlocked in a loaded save is built immediately.
func _connect_town_growth() -> void:
	TownGrowth.building_unlocked.connect(_on_building_unlocked)
	TownGrowth.resident_arrived.connect(_on_resident_arrived)
	for building_id in TownGrowth.unlocked_buildings():
		_on_building_unlocked(building_id, TownGrowth.BUILDINGS[building_id])
	TownGrowth.evaluate()

func _on_building_unlocked(building_id: StringName, data: Dictionary) -> void:
	var root_node := get_node_or_null("NavRegion")
	if root_node == null or root_node.has_node(String(building_id)):
		return
	var homes := int(data.get("homes", 1))
	var size := Vector3(4.0 + homes * 1.5, 3.0, 4.0)
	var position: Vector3 = data.get("position", Vector3.ZERO)
	var building := StaticBody3D.new()
	building.name = String(building_id)
	building.position = position + Vector3(0, size.y * 0.5, 0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	building.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.55, 0.48)
	mesh.material_override = material
	building.add_child(mesh)
	root_node.add_child(building)
	WorldLook.toon_subtree(building)
	var sign_label := Label3D.new()
	sign_label.text = String(data.get("name", building_id))
	sign_label.font_size = 40
	sign_label.outline_size = 8
	sign_label.position = position + Vector3(0, size.y + 0.6, 0)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_label)
	# a home marker per residence, so arrivals have somewhere to live and sleep
	for i in homes:
		var home_id := "home_%s_%d" % [building_id, i]
		if locations_root.has_node(home_id):
			continue
		var marker := Node3D.new()
		marker.name = home_id
		marker.position = position + Vector3(-1.5 + i * 3.0, 0, 3.0)
		locations_root.add_child(marker)
		WorldState.register_location(home_id, marker)
	EventBus.fire("hud_message", {"text": "%s went up on the south lane." % data.get("name", "A new building")})

func _on_resident_arrived(definition: NPCDefinition, home_id: String) -> void:
	if not WorldState.has_location(home_id):
		return
	WorldState.register_household(definition.household_id, [definition.id])
	var npc = NPCScene.instantiate()
	npc.setup(definition, Color(0.7, 0.62, 0.55))
	npc.add_to_group("townsfolk")
	npc.add_to_group("newcomer")
	add_child(npc)
	npc.global_position = WorldState.get_location_position(home_id)
	EventBus.fire("hud_message", {"text": "%s moved in." % definition.full_name()})

## Rival Row: home spots for the Rolling Tides rivals, registered like any other location.
func _add_rival_homes() -> void:
	for home_id in RivalRoster.HOMES:
		if locations_root.has_node(home_id):
			continue
		var marker := Node3D.new()
		marker.name = home_id
		marker.position = RivalRoster.HOMES[home_id]
		locations_root.add_child(marker)
	for household_id in RivalRoster.HOUSEHOLDS:
		WorldState.register_household(household_id, RivalRoster.HOUSEHOLDS[household_id])

## NPC ids the folded-in world already placed on the street; this scene skips them.
var _world_owned_npcs: Dictionary = {}

func _spawn_rivals() -> void:
	for definition in RivalRoster.build():
		if _world_owned_npcs.has(definition.id):
			continue
		var npc = NPCScene.instantiate()
		npc.setup(definition, RivalRoster.COLORS.get(definition.id, Color.WHITE))
		npc.add_to_group("rival")
		add_child(npc)
		if WorldState.has_location(definition.home_location_id):
			npc.global_position = WorldState.get_location_position(definition.home_location_id)

## Bram's family (data/bram_family.gd) live and work at The Good Place - the inn at the Olde Town tavern. Sergio,
## Grandpa's twin, keeps to his workshop out on the coast past Old Shore, far from everyone.
const SERGIO_WORKSHOP_OFFSET := Vector3(18, 0, 10)      # from the pier - placeholder until his cliff is built

func _spawn_bram_family() -> void:
	var tavern := WorldState.get_location_position("loc_tavern")
	var pier := WorldState.get_location_position("loc_pier")
	for loc in [[BramFamily.HOME, tavern + Vector3(-3, 0, 2)], [BramFamily.SERGIO_HOME, pier + SERGIO_WORKSHOP_OFFSET]]:
		if not WorldState.has_location(loc[0]):
			var marker := Node3D.new()
			marker.name = loc[0]
			locations_root.add_child(marker)
			marker.global_position = loc[1]
			WorldState.register_location(loc[0], marker)
	var households := BramFamily.households()
	for h in households:
		WorldState.register_household(h, households[h])
	for pair in BramFamily.FAMILY_PAIRS:
		RelationshipManager.declare_family(pair[0], pair[1])
	var sign := Label3D.new()
	sign.name = "GoodPlaceSign"
	sign.text = "THE GOOD PLACE\nFood · Rest · Repairs"
	sign.font_size = 72; sign.pixel_size = 0.0045; sign.outline_size = 12
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)
	sign.global_position = tavern + Vector3(-3, 3.6, 2)
	var i := 0
	for definition in BramFamily.build():
		var npc = NPCScene.instantiate()
		npc.setup(definition, Color(0.62, 0.42, 0.3))
		npc.add_to_group("bram_family")
		add_child(npc)
		npc.global_position = WorldState.get_location_position(definition.home_location_id) + Vector3((i % 3) * 1.4, 0, (i / 3) * 1.4)
		i += 1

func _spawn_player() -> void:
	var player = PlayerScene.instantiate()
	add_child(player)
	if WorldState.has_location("home_player"):
		player.global_position = WorldState.get_location_position("home_player") + Vector3(0, 0.1, 0)

## The restaurant (Line Cook job): a placeholder diner front on the street and its kitchen down in the interiors layer,
## joined by doors like every other interior. Everything inside is built by world/restaurant/kitchen.gd.
const RESTAURANT_STREET := Vector3(22, 0, 8)
func _spawn_restaurant() -> void:
	var interiors := get_node_or_null("Interiors")
	var kitchen := Kitchen.new()
	kitchen.name = "RestaurantKitchen"
	if interiors:
		interiors.add_child(kitchen)
		kitchen.position = Vector3(100, 0, 0)
	else:
		add_child(kitchen)
		kitchen.position = Vector3(100, -500, 0)
	# street front
	var front := StaticBody3D.new()
	front.name = "DinerFront"
	add_child(front)
	front.position = RESTAURANT_STREET
	var size := Vector3(6, 3.4, 5)
	var col := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; col.shape = sh; col.position.y = size.y / 2
	front.add_child(col)
	var mesh := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mesh.mesh = bm; mesh.position.y = size.y / 2
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.85, 0.35, 0.3); mesh.material_override = mat
	front.add_child(mesh)
	var sign := Label3D.new(); sign.text = "DINER"; sign.font_size = 96; sign.pixel_size = 0.01; sign.outline_size = 12
	sign.position = Vector3(-size.x / 2 - 0.05, 2.8, 0); sign.rotation.y = -PI / 2
	front.add_child(sign)
	var marker := Marker3D.new(); marker.name = "loc_restaurant"
	add_child(marker)
	marker.global_position = RESTAURANT_STREET + Vector3(-size.x / 2 - 1.2, 0, 0)
	WorldState.register_location("loc_restaurant", marker)
	var door := Teleporter.new()
	door.name = "DinerDoor"
	door.prompt_text = "Enter Diner"
	door.collision_layer = 8
	door.collision_mask = 0
	var dc := CollisionShape3D.new(); var ds := BoxShape3D.new(); ds.size = Vector3(1.2, 2.2, 1.6); dc.shape = ds; dc.position.y = 1.1
	door.add_child(dc)
	add_child(door)
	door.global_position = RESTAURANT_STREET + Vector3(-size.x / 2 - 0.4, 0, 0)
	door.destination = door.get_path_to(kitchen.get_node("KitchenEntry"))
	var exit := Teleporter.new()
	exit.name = "DinerExit"
	exit.prompt_text = "Leave Diner"
	exit.collision_layer = 8
	exit.collision_mask = 0
	var ec := CollisionShape3D.new(); var es := BoxShape3D.new(); es.size = Vector3(1.2, 2.2, 1.2); ec.shape = es; ec.position.y = 1.1
	exit.add_child(ec)
	var el := Label3D.new(); el.text = "Exit"; el.font_size = 36; el.pixel_size = 0.004; el.position.y = 2.2
	el.billboard = BaseMaterial3D.BILLBOARD_ENABLED; el.outline_size = 8
	exit.add_child(el)
	kitchen.add_child(exit)
	exit.position = Vector3(5.8, 0, 4.6)
	exit.destination = exit.get_path_to(marker)

## Grandpa's ranch (Ranch Hand job) out in the Farm Valleys, on open flat ground west of the valley (clear of its trees). Everything
## is built by world/ranch/ranch.gd; the task board is the job's time clock.
const RANCH_POS := Vector3(-157, 0, -110)

func _spawn_ranch() -> void:
	var ranch := Ranch.new()
	ranch.name = "GrandpasRanch"
	add_child(ranch)
	ranch.global_position = RANCH_POS
	var marker := Marker3D.new(); marker.name = "loc_ranch"
	ranch.add_child(marker)
	marker.position = Vector3(3.5, 0, -4.5)
	WorldState.register_location("loc_ranch", marker)

## The skate shop workshop (Board Builder job) behind the existing skateshop on Starter Street: the building in the
## world scene is a shell, so its front door leads to the workshop in the interiors layer, like the diner.
const SKATE_SHOP_DOOR := Vector3(7.5, 0, 5.6)        # the shop at (7.5, 8.3) faces -z; its doorway is at z 6.2

func _spawn_skate_shop() -> void:
	var interiors := get_node_or_null("Interiors")
	var shop := SkateShop.new()
	shop.name = "SkateShopWorkshop"
	if interiors:
		interiors.add_child(shop)
		shop.position = Vector3(130, 0, 0)
	else:
		add_child(shop)
		shop.position = Vector3(130, -500, 0)
	var outside := Marker3D.new(); outside.name = "SkateShopFront"
	add_child(outside)
	outside.global_position = SKATE_SHOP_DOOR + Vector3(0, 0, -1.4)
	var door := Teleporter.new()
	door.name = "SkateShopDoor"
	door.prompt_text = "Enter Skate Shop"
	door.collision_layer = 8
	door.collision_mask = 0
	var dc := CollisionShape3D.new(); var ds := BoxShape3D.new(); ds.size = Vector3(1.6, 2.2, 1.2); dc.shape = ds; dc.position.y = 1.1
	door.add_child(dc)
	add_child(door)
	door.global_position = SKATE_SHOP_DOOR
	door.destination = door.get_path_to(shop.get_node("ShopEntry"))
	var exit := Teleporter.new()
	exit.name = "SkateShopExit"
	exit.prompt_text = "Leave Skate Shop"
	exit.collision_layer = 8
	exit.collision_mask = 0
	var ec := CollisionShape3D.new(); var es := BoxShape3D.new(); es.size = Vector3(1.2, 2.2, 1.2); ec.shape = es; ec.position.y = 1.1
	exit.add_child(ec)
	var el := Label3D.new(); el.text = "Exit"; el.font_size = 36; el.pixel_size = 0.004; el.position.y = 2.2
	el.billboard = BaseMaterial3D.BILLBOARD_ENABLED; el.outline_size = 8
	exit.add_child(el)
	shop.add_child(exit)
	exit.position = Vector3(0, 0, 4.5)
	exit.destination = exit.get_path_to(outside)

## Adventure Contracts: the contract board beside the Woodland Ruins sign, and the two handcrafted dungeons in the
## interiors layer - the Old Crypt (stairs down inside the ruins) and the Smugglers' Cellar (a hatch in Olde Town by
## the tavern, where the catacombs run). Dungeons stay empty until a contract that names them is accepted.
const CONTRACT_BOARD_POS := Vector3(28.5, 0, 1.5)
const CRYPT_STAIRS_POS := Vector3(35.5, 0, -11.0)       # inside the ruin walls, Woodland Ruins origin (32, 0, -7)
const CELLAR_HATCH_OFFSET := Vector3(7, 0, 5)           # from the Olde Town tavern spot

func _spawn_contracts() -> void:
	var board := ContractBoard.new()
	board.name = "ContractBoard"
	add_child(board)
	board.global_position = CONTRACT_BOARD_POS
	board.rotation.y = PI * 0.15
	_settle_on_ground.call_deferred([board])
	var interiors := get_node_or_null("Interiors")
	var tavern := WorldState.get_location_position("loc_tavern")
	var entrances := {"old_crypt": [CRYPT_STAIRS_POS, "Crypt stairs", Vector3(200, 0, 0)],
		"smuggler_cellar": [tavern + CELLAR_HATCH_OFFSET, "Cellar hatch", Vector3(260, 0, 0)]}
	for id in entrances:
		var d := Dungeon.new(id)
		if interiors:
			interiors.add_child(d)
			d.position = entrances[id][2]
		else:
			add_child(d)
			d.position = entrances[id][2] + Vector3(0, -500, 0)
		var at: Vector3 = entrances[id][0]
		var outside := Marker3D.new(); outside.name = "%s_outside" % id
		add_child(outside)
		outside.global_position = at + Vector3(0, 0.1, 1.6)
		d.add_exit(outside)
		var door := Teleporter.new()
		door.name = "%s_entrance" % id
		door.prompt_text = "Go down the %s" % String(entrances[id][1]).to_lower()
		door.collision_layer = 8
		door.collision_mask = 0
		var dc := CollisionShape3D.new(); var ds := BoxShape3D.new(); ds.size = Vector3(1.8, 2.0, 1.8); dc.shape = ds; dc.position.y = 1.0
		door.add_child(dc)
		# a raised stone frame with a wooden hatch - reads on any ground (cobbles, grass, ruin floor)
		var rim := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size = Vector3(1.9, 0.4, 1.9); rim.mesh = rb
		var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color(0.42, 0.4, 0.36); rim.material_override = rmat
		rim.position.y = 0.2
		door.add_child(rim)
		var hatch := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(1.4, 0.08, 1.4); hatch.mesh = hb
		var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.36, 0.22, 0.12); hatch.material_override = hm
		hatch.position.y = 0.44
		door.add_child(hatch)
		for bx in [-0.35, 0.35]:
			var band := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.1, 0.1, 1.45); band.mesh = bb
			var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.15, 0.15, 0.16); band.material_override = bm
			band.position = Vector3(bx, 0.47, 0)
			door.add_child(band)
		var l := Label3D.new(); l.text = entrances[id][1]; l.font_size = 40; l.pixel_size = 0.005; l.position.y = 1.5
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.outline_size = 8
		door.add_child(l)
		add_child(door)
		door.global_position = at
		door.destination = door.get_path_to(d.get_node("DungeonEntry"))
		_settle_on_ground.call_deferred([door, outside])

## Drop nodes placed in the wider world onto the ground once physics is running.
func _settle_on_ground(nodes: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for n in nodes:
		var at: Vector3 = n.global_position
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -60, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			n.global_position.y = hit["position"].y + (0.1 if n is Marker3D else 0.0)

## The mirror lives in the player's bedroom, on the far wall. It reopens the character creator later, and a brand new
## game opens there: the player starts in front of it (see IntroSequence).
func _spawn_mirror() -> void:
	var interior := get_node_or_null("Interiors/PlayerHomeInterior")
	var mirror := MirrorScript.new()
	mirror.name = "HomeMirror"
	if interior:
		interior.add_child(mirror)
		mirror.position = Vector3(0, 0, -2.75)
		mirror.rotation.y = PI          # the glass faces into the room
	else:
		add_child(mirror)
		mirror.position = WorldState.get_location_position("home_player") + Vector3(2.4, 0.0, 1.2)
	var exit_door := get_node_or_null("Interiors/PlayerHomeInterior/ExitDoor")
	if exit_door:
		exit_door.add_to_group("player_home_exit")
	if ToriyamaRoster.saved_recipe().is_empty():
		_start_intro(mirror)

func _spawn_home_storage_chest() -> void:
	var interior := get_node_or_null("Interiors/PlayerHomeInterior")
	if interior == null:
		return
	var chest := HomeStorageChestScript.new()
	chest.name = "HomeStorageChest"
	chest.storage_id = "home_chest_1"
	interior.add_child(chest)
	chest.position = Vector3(2.0, 0.0, 1.35)

## New game: the player is already at the mirror deciding who they are, then walks out into the world.
func _start_intro(mirror: Node3D) -> void:
	var player = WorldState.player
	if player == null or not player.has_method("apply_recipe"):
		return
	var intro := IntroScript.new()
	intro.name = "IntroSequence"
	add_child(intro)
	intro.call_deferred("start", player, mirror)

func _spawn_garden() -> void:
	var garden := Node3D.new()
	garden.name = "PlayerGarden"
	add_child(garden)
	var home_position := WorldState.get_location_position("home_player")
	# Four plots beside the player's home, outside the building footprint.
	var garden_origin := home_position + Vector3(-5.5, 0.0, 1.0)
	var offsets := [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 2), Vector3(2, 0, 2)]
	for index in offsets.size():
		var plot := FarmPlotScript.new()
		plot.name = "FarmPlot%d" % (index + 1)
		plot.plot_id = "home_plot_%d" % (index + 1)
		plot.position = garden_origin + offsets[index]
		garden.add_child(plot)
	var sign := Label3D.new()
	sign.text = "HOME GARDEN\nPlant  •  Water  •  Harvest"
	sign.font_size = 40
	sign.outline_size = 8
	sign.position = garden_origin + Vector3(1.0, 1.2, -1.0)
	garden.add_child(sign)

func _spawn_guitar_stand() -> void:
	var guitar := GuitarStandScript.new()
	guitar.name = "GuitarStand"
	guitar.position = WorldState.get_location_position("loc_social") + Vector3(-6.0, 0.0, 4.0)
	add_child(guitar)
	# Permanent marker for the concert stage spot, so the guitar bonus area is
	# findable on any day (the Saturday concert builds its Stage right on it).
	var stage_pos := CommunityEventManager.get_concert_stage_position()
	var pad := MeshInstance3D.new()
	pad.name = "ConcertStageMarker"
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(5.0, 0.03, 2.5)
	pad.mesh = pad_mesh
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.36, 0.22, 0.48)
	pad.material_override = pad_mat
	pad.position = stage_pos + Vector3(0, 0.035, 0)
	add_child(pad)
	var sign := Label3D.new()
	sign.text = "♪ CONCERT STAGE ♪\nGuitar sets: x1.5 points  •  x2 during the Saturday concert"
	sign.font_size = 72
	sign.outline_size = 14
	sign.modulate = Color(1.0, 0.85, 0.45)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = stage_pos + Vector3(0, 2.4, -1.4)
	add_child(sign)

func _spawn_adventure_area() -> void:
	var root := Node3D.new()
	root.name = "DangerousOutskirts"
	add_child(root)
	var origin := Vector3(32, 0.0, -7.0)
	var zone := DangerZoneScript.new()
	zone.name = "WoodedRuinsDangerZone"
	zone.zone_id = "wooded_ruins"
	root.add_child(zone)
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(16, 2.0, 16)
	zone_shape.shape = zone_box
	zone_shape.position = origin + Vector3(0, 1.0, 0)
	zone.add_child(zone_shape)
	var adventure_marker := Node3D.new()      # so a schedule can name it (Mr. Jones heads out here after lunch)
	adventure_marker.name = "loc_adventure"
	locations_root.add_child(adventure_marker)
	adventure_marker.position = origin
	WorldState.register_location("loc_adventure", adventure_marker)   # locations were registered before this ran
	_make_adventure_ground(root, origin)
	_make_ruin_walls(root, origin)
	for index in 2:
		var enemy := EnemyScript.new()
		enemy.name = "RuinEnemy%d" % (index + 1)
		enemy.enemy_id = "ruin_beast_%d" % (index + 1)
		enemy.position = origin + Vector3(-2.5 + index * 5.0, 0.0, 1.0)
		root.add_child(enemy)
	var reward := RewardScript.new()
	reward.name = "RuinRelic"
	reward.position = origin + Vector3(0, 0.25, -3.6)
	root.add_child(reward)
	var reward_mesh := MeshInstance3D.new()
	var reward_shape := SphereMesh.new()
	reward_shape.radius = 0.28
	reward_shape.height = 0.5
	reward_mesh.mesh = reward_shape
	var reward_mat := StandardMaterial3D.new()
	reward_mat.albedo_color = Color(0.85, 0.55, 0.12)
	reward_mesh.material_override = reward_mat
	reward_mesh.position.y = 0.35
	reward.add_child(reward_mesh)
	var entrance := Label3D.new()
	entrance.text = "WOODLAND RUINS\nDanger beyond this sign"
	entrance.font_size = 38
	entrance.outline_size = 8
	entrance.position = origin + Vector3(0, 1.8, 7.2)
	root.add_child(entrance)

func _make_adventure_ground(root: Node3D, origin: Vector3) -> void:
	var ground := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(15.0, 0.08, 15.0)
	ground.mesh = mesh
	ground.position = origin + Vector3(0, 0.02, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.26, 0.12)
	ground.material_override = mat
	root.add_child(ground)

func _make_ruin_walls(root: Node3D, origin: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.33, 0.30)
	for data in [[Vector3(-6, 1.0, -2), Vector3(0.5, 2.0, 8.0)], [Vector3(6, 1.0, -2), Vector3(0.5, 2.0, 8.0)], [Vector3(0, 1.0, -6), Vector3(12.0, 2.0, 0.5)]]:
		var wall := MeshInstance3D.new()
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = data[1]
		wall.mesh = wall_mesh
		wall.position = origin + data[0]
		wall.material_override = mat
		root.add_child(wall)
