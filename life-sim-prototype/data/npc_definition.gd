class_name NPCDefinition
extends Resource
## The persistent identity of one simulated resident. This is deliberately a
## plain data Resource — the NPCBrain script (npc/npc_brain.gd) is what makes
## a definition "alive" in the world.

enum LifeStage { BABY, CHILD, TEEN, YOUNG_ADULT, ADULT, OLDER_ADULT }

const LIFE_STAGE_NAMES := ["Baby", "Child", "Teen", "Young Adult", "Adult", "Older Adult"]

## Age thresholds (in years) at which life_stage advances. Aging itself is
## driven by NPCBrain checking birthdays against TimeManager — this table is
## the only thing that needs to change to retune the life span later.
const LIFE_STAGE_AGE_THRESHOLDS := [0, 3, 13, 18, 30, 60]

@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var age_years: int = 25
@export var life_stage: LifeStage = LifeStage.YOUNG_ADULT
@export var birthday_day_of_year: int = 0 # 0-83, since a season is 21 days here

@export var household_id: String = ""
@export var home_location_id: String = ""

## Skin tone is independent of clothing — the body and head mesh both read
## this directly; visible outfit color comes entirely from equipped items.
@export var skin_tone: Color = Color(0.85, 0.68, 0.55)
@export var race: String = "human"
@export var transformation_model: String = ""
@export var movement_style: String = ""

## Procedural Character Creator / Toriyama Kit recipe
@export var recipe: Dictionary = {}

## Adventurer status and combat capabilities (low leveled for standard townsfolk)
@export var is_adventurer: bool = true
@export var adventurer_level: int = 1
@export var adventurer_rank: String = "Novice (Rank F)"
@export var combat_stats: Dictionary = {"hp": 60, "attack": 12, "defense": 8, "speed": 10}

## Superpower manifestation (rare ~10-15% among novices)
@export var has_superpower: bool = false
@export var superpower_id: String = ""
@export var superpower_name: String = ""
@export var superpower_description: String = ""

## Relationship flags
@export var is_romanceable: bool = true

## slot name (see EquipmentItem.Slot) -> EquipmentCatalog item id, applied
## once at spawn (see NPCBrain._equip_starting_outfit). Future work-clothes/
## gym-clothes changes are just more equip() calls with a different item —
## this dictionary only needs to hold whatever they're wearing right now.
@export var starting_equipment: Dictionary = {}

@export var occupation: String = "" # "" means unemployed, else a job_id in WorldState.jobs
@export var workplace_location_id: String = ""
@export var work_start_hour: int = 9
@export var work_end_hour: int = 17
@export var works_weekends: bool = false

## Two traits from the same framework the player uses (autoload/trait_system.gd). Named residents can leave this
## empty; generated townsfolk always have two.
@export var traits: Array[StringName] = []
## How this person talks about the Merging Era: grounded, genre_aware or lost. Derived from the trait pair by
## TownsfolkGenerator — never rolled separately, so outlook always matches who they are.
@export var register: StringName = &"grounded"
## True for procedurally generated townsfolk, false for the authored cast.
@export var generated: bool = false

@export var interests: Array[String] = []
@export var skills: Dictionary = {} # skill_name -> float 0..100

## extroversion, kindness, ambition, humor, discipline, each 0..1
@export var personality: Dictionary = {}

## Ordered list of {day: "ALL"/"WEEKDAY"/"WEEKEND", start: int, end: int, activity: String, location: String}
## Checked top to bottom; first matching block for the current hour wins.
## "activity" is one of NPCBrain.Activity's enum names as a String.
@export var schedule: Array[Dictionary] = []

func full_name() -> String:
	return "%s %s" % [first_name, last_name]

func get_life_stage_name() -> String:
	return LIFE_STAGE_NAMES[life_stage]

func recalculate_life_stage() -> LifeStage:
	var stage: int = LifeStage.BABY
	for i in range(LIFE_STAGE_AGE_THRESHOLDS.size()):
		if age_years >= LIFE_STAGE_AGE_THRESHOLDS[i]:
			stage = i
	life_stage = stage
	return life_stage
