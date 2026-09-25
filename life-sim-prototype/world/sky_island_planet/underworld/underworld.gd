class_name Underworld
extends Node3D
## The cavern beneath the Origin Nexus. Hollowlight Village, the draconic roosts, five elemental training grounds
## and the four stones that carry the war. Built by tools/build_sky_underworld.gd - edit the builder, not the scene.

signal lore_read(title: String, text: String)
signal training_entered(biome_id: String, element: String)
signal returning_to_surface()

const SURFACE := "res://world/sky_island_planet/sky_island_planet.tscn"

var visited_biomes: Dictionary = {}
var read_tablets: Dictionary = {}

func _ready() -> void:
	add_to_group("underworld_realm")
	var player := get_node_or_null("Player")
	var spawn := get_node_or_null("Links/ArrivalSpawn") as Node3D
	if player and spawn:
		player.global_transform = spawn.global_transform
	_arm_triggers()

## Each tablet and training ground gets a proximity area. They are added here rather than baked into the scene so
## the builder stays a pure geometry pass and the radii can be tuned without a rebuild.
func _arm_triggers() -> void:
	for tablet in get_node_or_null("LoreTablets").get_children() if has_node("LoreTablets") else []:
		_add_area(tablet, 4.5, _on_tablet_entered.bind(tablet))
	var biomes := get_node_or_null("ElementalBiomes")
	if biomes:
		for biome in biomes.get_children():
			var spot := biome.get_node_or_null("TrainingSpot")
			if spot:
				_add_area(spot, 7.0, _on_training_entered.bind(spot))
	var ret := get_node_or_null("Links/ReturnToSurface")
	if ret:
		_add_area(ret, 5.0, _on_return_entered)

func _add_area(host: Node3D, radius: float, handler: Callable) -> void:
	var area := Area3D.new()
	area.name = "Trigger"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	host.add_child(area)
	area.body_entered.connect(func(body): if body.is_in_group("player") or body.name == "Player": handler.call())

func _on_tablet_entered(tablet: Node3D) -> void:
	var title: String = String(tablet.get_meta("lore_title", "The War Above"))
	var text: String = String(tablet.get_meta("lore_text", ""))
	if read_tablets.has(tablet.name):
		return
	read_tablets[tablet.name] = true
	lore_read.emit(title, text)

func _on_training_entered(spot: Node3D) -> void:
	var biome_id: String = String(spot.get_meta("biome_id", ""))
	var element: String = String(spot.get_meta("element", ""))
	visited_biomes[biome_id] = true
	training_entered.emit(biome_id, element)

func _on_return_entered() -> void:
	returning_to_surface.emit()
	var surface := load(SURFACE)
	if surface:
		get_tree().change_scene_to_packed(surface)

## How far through the deep the player has got - five biomes and four stones.
func exploration_progress() -> float:
	return (float(visited_biomes.size()) / 5.0) * 0.6 + (float(read_tablets.size()) / 4.0) * 0.4
