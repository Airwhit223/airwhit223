class_name OpenWorldManager
extends Node3D
## Coordinates open world systems:
## - Regional exploration across Wilderness, Towers, Caves, and Settlements
## - Vehicle spawning & retrieval
## - Dungeon entrance & exit transitions
## - Outer Space rocket launches and orbital ascent

const VehicleBase = preload("res://player/vehicles/vehicle_base.gd")

signal district_changed(new_district: String)
signal launch_to_space_requested()

@export var current_region: String = "The Valley"
var active_vehicles: Dictionary = {}

func register_vehicle(id: String, vehicle: Node3D) -> void:
	active_vehicles[id] = vehicle

func get_vehicle(id: String) -> Node3D:
	return active_vehicles.get(id, null)

func launch_to_sky_islands(player: CharacterBody3D) -> void:
	launch_to_space_requested.emit()
	var sky_scene := load("res://world/sky_island_planet/sky_island_planet.tscn")
	if sky_scene:
		get_tree().change_scene_to_packed(sky_scene)

func launch_to_orbit(player: CharacterBody3D) -> void:
	launch_to_space_requested.emit()
	var space_scene := load("res://world/space/outer_space_realm.tscn")
	if space_scene:
		get_tree().change_scene_to_packed(space_scene)
