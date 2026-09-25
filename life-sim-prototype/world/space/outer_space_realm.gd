class_name OuterSpaceRealm
extends Node3D
## Outer Space Realm: Low-orbit & celestial ruins above the homeworld.
## Features:
## - Low gravity physics (0.15x)
## - Deep cosmic skybox with nebulas and planetary curve
## - Floating platforms, celestial monolith, and orbital research outpost
## - Zero-G thruster movement support

signal entered_orbit()
signal returned_to_surface()

@export var space_gravity_multiplier: float = 0.15
@export var space_drag: float = 0.98

var player: CharacterBody3D
var space_hud: CanvasLayer

func _ready() -> void:
	add_to_group("space_realm")
	player = get_node_or_null("Player")
	if player:
		_setup_player_in_space(player)
	_setup_space_hud()

func _setup_player_in_space(p: CharacterBody3D) -> void:
	# Enable low gravity and zero-g thrusters
	var powers = p.get_node_or_null("SuperpowerController")
	if powers:
		powers.gravity_scale = space_gravity_multiplier
	entered_orbit.emit()

func _setup_space_hud() -> void:
	var hud := get_node_or_null("ZoneHUD")
	if hud and hud.has_method("show_zone_banner"):
		hud.show_zone_banner("Outer Space — Low Orbit", "Zero Gravity")
