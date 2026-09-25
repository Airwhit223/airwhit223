class_name SkyIslandPlanet
extends Node3D
## Celestial Origin Nexus: A floating sky-island planet under twin suns.
## Features:
## - Low gravity physics (0.35x) allowing float jumps and prolonged gliding
## - Dual sun lighting (Golden-Orange and Cyan-Blue suns casting double shadows)
## - Colossal ringed gas giant visible in the cosmos
## - Archipelago of 4 floating sky islands connected by rainbow energy bridges and stone arches
## - Alien flora (bioluminescent spiral trees, glowing giant mushrooms, teal turf)
## - Interactive Attunable Resonance Crystal pillars
## - Round-trip Space Capsule connection back to the homeworld surface

signal crystal_attuned(crystal_name: String)
signal returned_to_surface()

@export var space_gravity_multiplier: float = 0.35

var player: CharacterBody3D
var zone_hud: CanvasLayer

func _ready() -> void:
	add_to_group("sky_island_realm")
	player = get_node_or_null("Player")
	if player:
		_setup_player(player)
	_setup_zone_hud()
	_setup_return_capsule()
	_setup_resonance_crystals()
	_setup_underworld_descent()      # LOCAL PATCH - re-apply after syncing this file from the Antigravity copy

func _setup_player(p: CharacterBody3D) -> void:
	var spawn := get_node_or_null("NPCSpawns/PlayerSpawn") as Node3D
	if spawn:
		p.global_transform = spawn.global_transform
	
	# Apply low gravity to superpower controller
	var powers = p.get_node_or_null("SuperpowerController")
	if powers:
		powers.gravity_scale = space_gravity_multiplier
	
	# Frame camera for expansive celestial view
	var rig := p.get_node_or_null("CameraRig") as Node3D
	var arm := p.get_node_or_null("CameraRig/SpringArm3D") as SpringArm3D
	var cam := p.get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
	if rig:
		rig.position.y = 1.8
	if arm:
		arm.spring_length = 4.2
	if cam:
		cam.fov = 62.0

func _setup_zone_hud() -> void:
	zone_hud = get_node_or_null("ZoneHUD")
	if zone_hud and zone_hud.has_method("show_zone_banner"):
		zone_hud.show_zone_banner("The Origin Nexus", "The Twin Sun Horizon (Low-Gravity Zone: Active)")

func _setup_return_capsule() -> void:
	var capsule := get_node_or_null("Landmarks/DockedSpaceCapsule")
	if capsule:
		if capsule.has_signal("space_reached"):
			capsule.space_reached.connect(return_to_surface)
		var trigger := capsule.get_node_or_null("InteractionTrigger") as Area3D
		if trigger:
			trigger.body_entered.connect(func(body):
				if body == player or (body and body.is_in_group("player")):
					return_to_surface()
			)

func _setup_resonance_crystals() -> void:
	var crystal := get_node_or_null("Landmarks/AttunableResonanceCrystal")
	if crystal:
		var trigger := crystal.get_node_or_null("AttuneArea") as Area3D
		if trigger:
			trigger.body_entered.connect(func(body):
				if body == player or (body and body.is_in_group("player")):
					attune_crystal("Crystal_Prime")
			)

func attune_crystal(crystal_name: String) -> void:
	crystal_attuned.emit(crystal_name)
	if player:
		var powers = player.get_node_or_null("SuperpowerController")
		if powers and powers.has_method("restore_stamina"):
			powers.restore_stamina(100.0)
	if zone_hud and zone_hud.has_method("show_zone_banner"):
		zone_hud.show_zone_banner("Cosmic Resonance Attuned", "Energy Restored & Super Jump Amplified")

## LOCAL PATCH. The gravity lift only went up. The cavern below - Hollowlight Village and the elemental training
## grounds - is reached by riding it down, so the lift gets a trigger that changes scene to the underworld.
const UNDERWORLD := "res://world/sky_island_planet/underworld/underworld.tscn"

func _setup_underworld_descent() -> void:
	var lift := find_child("GravityLiftElevator", true, false) as Node3D
	if lift == null:
		return
	var area := Area3D.new()
	area.name = "DescendToUnderworld"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.0
	cyl.height = 4.0
	shape.shape = cyl
	shape.position = Vector3(0, -2.5, 0)      # under the pad: step off the lift's underside to go down
	area.add_child(shape)
	lift.add_child(area)
	area.body_entered.connect(func(body):
		if body.is_in_group("player") or body.name == "Player":
			descend_to_underworld())

func descend_to_underworld() -> void:
	var deep := load(UNDERWORLD)
	if deep:
		get_tree().change_scene_to_packed(deep)


func return_to_surface() -> void:
	returned_to_surface.emit()
	var surface_scene := load("res://world/rolling_tides_world/rolling_tides_world.tscn")
	if surface_scene:
		get_tree().change_scene_to_packed(surface_scene)
