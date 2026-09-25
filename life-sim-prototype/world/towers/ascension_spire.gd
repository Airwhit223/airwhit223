class_name AscensionSpire
extends Node3D
## Monumental Ascension Tower.
## Features:
## - Regional map synchronization beacon
## - Thermal updraft at the summit launching gliders high into the sky
## - Grapple anchor rings along the exterior shaft
## - Fast travel point

signal tower_activated(tower_name: String)

@export var tower_name: String = "Ascension Spire"
@export var tower_height: float = 48.0
@export var is_activated: bool = false

var beacon_light: OmniLight3D
var thermal_area: Area3D

func _ready() -> void:
	add_to_group("tower")
	beacon_light = get_node_or_null("SummitBeacon/BeaconLight")
	thermal_area = get_node_or_null("SummitThermalUpdraft")
	_update_visuals()

func activate_tower() -> void:
	if is_activated:
		return
	is_activated = true
	_update_visuals()
	tower_activated.emit(tower_name)
	var eb := get_node_or_null("/root/EventBus")
	if eb:
		eb.fire("hud_message", {"text": "Tower Synchronized: " + tower_name + "!"})

func _update_visuals() -> void:
	if beacon_light:
		beacon_light.light_energy = 5.0 if is_activated else 1.0
		beacon_light.light_color = Color(0.2, 0.9, 1.0) if is_activated else Color(0.9, 0.4, 0.2)
