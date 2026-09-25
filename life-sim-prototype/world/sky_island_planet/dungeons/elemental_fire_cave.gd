class_name ElementalFireCave
extends Node3D
## The Infernal Training Caverns of Ignis: Deep subterranean elemental fire trial.
## Contains extreme heat hazard zones, magma braziers, and the Ignis Primal Colossus boss.
## Beating the boss grants the permanent Heat Resistance passive perk.

signal trial_completed()

@export var heat_hazard_dps: float = 15.0

var _player: Node = null
var _in_lava_zone: bool = false
var _hazard_tick: float = 0.0

const BossIgnisColossusClass = preload("res://world/sky_island_planet/dungeons/boss_ignis_colossus.gd")

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_setup_boss()
	_setup_hazard_areas()

func _setup_boss() -> void:
	var boss: Node = get_node_or_null("BossIgnisColossus")
	if boss:
		boss.connect("boss_defeated", _on_boss_defeated)

func _setup_hazard_areas() -> void:
	var lava_zone := get_node_or_null("HazardLavaZone") as Area3D
	if lava_zone:
		lava_zone.body_entered.connect(_on_lava_entered)
		lava_zone.body_exited.connect(_on_lava_exited)

func _on_lava_entered(body: Node) -> void:
	if body == _player or (body and body.is_in_group("player")):
		_in_lava_zone = true

func _on_lava_exited(body: Node) -> void:
	if body == _player or (body and body.is_in_group("player")):
		_in_lava_zone = false

func _physics_process(delta: float) -> void:
	if not _in_lava_zone or _player == null:
		return

	_hazard_tick += delta
	if _hazard_tick >= 0.5:
		_hazard_tick = 0.0
		# Apply heat hazard damage unless player possesses Heat Resistance
		var pc = _player.get("power_controller")
		if pc and pc.profile and pc.profile.has_resistance("heat"):
			return # Immune to heat!

		if _player.has_method("take_damage"):
			_player.take_damage(heat_hazard_dps * 0.5)

func _on_boss_defeated() -> void:
	trial_completed.emit()
	var chest := get_node_or_null("BossRewardChest")
	if chest and chest.has_method("set_unlocked"):
		chest.set_unlocked(true)
