class_name RollingTidesWorld
extends Node3D
## Master blended overworld combining:
## - The Neighborhood Hub
## - The Gothic Olde Town / Haunted Village
## - Neon Tokyo Sector
## - The Old Shore & Coastal Boardwalk

const HUDScene := preload("res://ui/hud.tscn")
const NPCScene := preload("res://scenes/npc.tscn")

const DISTRICT_NPCS := {
	"jones": {
		"spot": "NPCSpawns/BenchSitSpot",
		"display_name": "Mr. Jones",
		"offset": Vector3(0.0, 0.0, -0.25),
		"yaw": 172.0,
	},
	"jace": {
		"spot": "NPCSpawns/ShopWorkSpot",
		"display_name": "Jace",
		"offset": Vector3(0.0, 0.0, 0.0),
		"yaw": 0.0,
	},
	"maya_reyes": {
		"spot": "NPCSpawns/CourtSpot",
		"display_name": "Maya",
		"offset": Vector3(0.0, 0.0, 0.0),
		"yaw": -15.0,
	},
}

@export var camera_distance := 3.6
@export var camera_height := 1.6
@export var camera_fov := 58.0

var current_zone: String = "The Neighborhood"

func _ready() -> void:
	preload("res://world/detail/regional_landscape.gd").install(self)
	_register_locations()
	var player := get_node_or_null("Player")
	if player:
		var spawn := get_node_or_null("NPCSpawns/PlayerSpawn") as Node3D
		if spawn:
			player.global_transform = spawn.global_transform
		frame_camera(player)
	_spawn_npcs()
	_setup_zone_triggers()
	_setup_space_capsule()

func _setup_space_capsule() -> void:
	var capsule := get_node_or_null("Landmarks/LaunchpadSpaceCapsule")
	if capsule and capsule.has_signal("space_reached"):
		capsule.space_reached.connect(_on_space_capsule_reached)

func _on_space_capsule_reached() -> void:
	var ow_mgr := get_node_or_null("OpenWorldManager")
	var player := get_node_or_null("Player")
	if ow_mgr and ow_mgr.has_method("launch_to_sky_islands"):
		ow_mgr.launch_to_sky_islands(player)
	elif ow_mgr and ow_mgr.has_method("launch_to_orbit"):
		ow_mgr.launch_to_orbit(player)
	else:
		var sky_scene := load("res://world/sky_island_planet/sky_island_planet.tscn")
		if sky_scene:
			get_tree().change_scene_to_packed(sky_scene)
		else:
			var space_scene := load("res://world/space/outer_space_realm.tscn")
			if space_scene:
				get_tree().change_scene_to_packed(space_scene)

func frame_camera(player: Node) -> void:
	var rig := player.get_node_or_null("CameraRig") as Node3D
	var arm := player.get_node_or_null("CameraRig/SpringArm3D") as SpringArm3D
	var cam := player.get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
	if rig:
		rig.position.y = camera_height
	if arm:
		arm.spring_length = camera_distance
	if cam:
		cam.fov = camera_fov

func _register_locations() -> void:
	var world := get_node_or_null("/root/WorldState")
	if world == null:
		return
	var spawns := get_node_or_null("NPCSpawns")
	if spawns:
		for marker in spawns.get_children():
			if marker is Marker3D:
				world.register_location("world_" + String(marker.name).to_snake_case(), marker)
	
	var bench_spot := get_node_or_null("NPCSpawns/BenchSitSpot")
	var shop_spot := get_node_or_null("NPCSpawns/ShopWorkSpot")
	var porch_spot := get_node_or_null("NPCSpawns/PorchSitSpot")
	var court_spot := get_node_or_null("NPCSpawns/CourtSpot")
	var tavern_spot := get_node_or_null("NPCSpawns/TavernSpot")
	var pier_spot := get_node_or_null("NPCSpawns/PierSpot")
	
	if bench_spot:
		world.register_location("loc_social", bench_spot)
		world.register_location("home_jones", bench_spot)
	if shop_spot:
		world.register_location("loc_skate", shop_spot)
		world.register_location("loc_store", shop_spot)
		world.register_location("home_jace", shop_spot)
	if court_spot:
		world.register_location("home_maya_reyes", court_spot)
		world.register_location("loc_gym", court_spot)
		world.register_location("loc_basketball", court_spot)
	elif porch_spot:
		world.register_location("home_maya_reyes", porch_spot)
	if tavern_spot:
		world.register_location("loc_tavern", tavern_spot)
	if pier_spot:
		world.register_location("loc_pier", pier_spot)
		world.register_location("loc_fishing", pier_spot)
	var khem_spot := get_node_or_null("NPCSpawns/KhemOasisSpot")
	var queen_spot := get_node_or_null("NPCSpawns/QueenPavilionSpot")
	if khem_spot:
		world.register_location("loc_khem", khem_spot)
		world.register_location("loc_oasis", khem_spot)
	if queen_spot:
		world.register_location("loc_nefertari", queen_spot)
		world.register_location("home_nefertari", queen_spot)

	var house_door := get_node_or_null("NPCSpawns/HouseDoorTeleporter")
	if house_door:
		world.register_location("home_player", house_door)
	var bed := find_child("Bed", true, false)
	if bed:
		world.register_location("home_bed", bed)
	var mirror := find_child("HomeMirror", true, false)
	if mirror:
		world.register_location("home_mirror", mirror)
	for household_id in RivalRoster.HOUSEHOLDS:
		world.register_household(household_id, RivalRoster.HOUSEHOLDS[household_id])

func _spawn_npcs() -> void:
	if not get_tree().get_nodes_in_group("rival").is_empty():
		return
	var npcs_root := get_node_or_null("NPCs")
	if npcs_root == null:
		npcs_root = Node3D.new()
		npcs_root.name = "NPCs"
		add_child(npcs_root)

	var defs_by_id: Dictionary = {}
	for d in RivalRoster.build():
		defs_by_id[d.id] = d

	for npc_id in DISTRICT_NPCS:
		if not defs_by_id.has(npc_id):
			continue
		var def: NPCDefinition = defs_by_id[npc_id]
		var info: Dictionary = DISTRICT_NPCS[npc_id]
		if info.has("display_name"):
			def.first_name = info["display_name"]

		var npc = NPCScene.instantiate()
		npc.name = "NPC_" + npc_id.capitalize().replace(" ", "")
		npc.setup(def, RivalRoster.COLORS.get(npc_id, Color.WHITE))
		npc.add_to_group("rival")
		npcs_root.add_child(npc)

		var spot := get_node_or_null(info["spot"]) as Node3D
		if spot:
			var offset: Vector3 = info.get("offset", Vector3.ZERO)
			var yaw: float = float(info.get("yaw", spot.rotation_degrees.y))
			npc.global_position = spot.global_position + offset
			npc.rotation_degrees.y = yaw
			npc.current_target_location = "world_" + String(spot.name).to_snake_case()
		npc.arrived = true
		npc.current_activity = NPCBrain.Activity.SOCIALIZE

func _setup_zone_triggers() -> void:
	var triggers := get_node_or_null("ZoneTriggers")
	if triggers == null:
		return
	for child in triggers.get_children():
		if child is Area3D:
			child.body_entered.connect(_on_zone_entered.bind(child))

func _on_zone_entered(body: Node, zone_area: Area3D) -> void:
	if not body.is_in_group("player") and body.name != "Player":
		return
	var title: String = zone_area.get_meta("zone_title", "Unknown District")
	var time_of_day: String = zone_area.get_meta("time_of_day", "")
	current_zone = title
	var hud := get_node_or_null("ZoneHUD")
	if hud and hud.has_method("show_zone_banner"):
		hud.show_zone_banner(title, time_of_day)
