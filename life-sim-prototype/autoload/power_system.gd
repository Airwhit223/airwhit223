extends Node

const PlayerPowerProfileScript := preload("res://power_system/player_power_profile.gd")

var profile: RefCounted = null

func _init() -> void:
	profile = PlayerPowerProfileScript.new()

func _ready() -> void:
	EventBus.event_fired.connect(_on_event_fired)
	TimeManager.day_changed.connect(_on_day_changed)

func _process(delta: float) -> void:
	if profile:
		profile.update_runtime(delta)

func _on_event_fired(event_name: String, data: Dictionary) -> void:
	if profile == null:
		return

	match event_name:
		"workout":
			# Gym equipment: Builds raw physical strength and resistance
			profile.add_universal_mastery("strength", 0.08)
			profile.add_universal_mastery("resistance", 0.06)
			EventBus.fire("hud_message", {"text": "Strength & Durability increased!"})

		"walk":
			# Walking & distance travel: Builds locomotive speed and stamina
			profile.add_universal_mastery("speed", 0.03)
			profile.add_universal_mastery("stamina", 0.04)

		"study":
			# Library and book reading: Deepens soul understanding and magic mastery
			if profile.magic_affinity != "":
				profile.add_magic_mastery(0.8)
				EventBus.fire("hud_message", {"text": "Soul Magic understanding deepened (+0.8)!"})
			else:
				profile.add_universal_mastery("senses", 0.05)

		"combat":
			# Combat dodges & strikes: Sharpens reflexes and mutation output
			profile.add_universal_mastery("reflex", 0.05)
			if profile.mutation_affinity != "":
				profile.add_mutation_mastery(0.6)

		"basketball_scored":
			# Athletics: Agility and mobility
			profile.add_universal_mastery("agility", 0.06)
			profile.add_universal_mastery("mobility", 0.05)

		"dream_realm_entered":
			# Dream realm exposure: Accelerates mutation and soul mastery
			if profile.mutation_affinity != "":
				profile.add_mutation_mastery(1.5)
			if profile.magic_affinity != "":
				profile.add_magic_mastery(1.5)

func _on_day_changed(_day_index: int, _day_of_week: int) -> void:
	if profile:
		# Full rest restores energy
		profile.energy = profile.max_energy
		# Ancestral natural growth over weeks
		profile.add_race_mastery(0.5)

# ----------------- Save / Load Interface -----------------
func to_dict() -> Dictionary:
	return profile.to_dict() if profile else {}

func from_dict(data: Dictionary) -> void:
	if profile:
		profile.from_dict(data)

func reset() -> void:
	if profile:
		profile.reset_to_defaults()
