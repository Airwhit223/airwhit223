class_name NPCRoster
extends RefCounted
## Builds the milestone-1 cast: 5 simulated residents across 4 households and
## most life stages. Adding a 6th resident later is just another entry here —
## nothing else needs to change.

const FAMILY_PAIRS := [
	["alex", "riley"],
]

const HOUSEHOLDS := {
	"household_maya": ["maya"],
	"household_jordan": ["jordan"],
	"household_rivera": ["alex", "riley"],
	"household_sam": ["sam"],
}

static func build() -> Array[NPCDefinition]:
	var roster: Array[NPCDefinition] = []
	roster.append(_maya())
	roster.append(_jordan())
	roster.append(_alex())
	roster.append(_riley())
	roster.append(_sam())
	return roster

static func _maya() -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "maya"
	d.first_name = "Maya"
	d.last_name = "Chen"
	d.age_years = 26
	d.birthday_day_of_year = 10
	d.household_id = "household_maya"
	d.home_location_id = "home_maya"
	d.skin_tone = Color(0.87, 0.68, 0.52)
	d.starting_equipment = {"top": "red_hoodie", "bottom": "black_pants", "shoes": "white_sneakers", "accessory": "simple_necklace"}
	d.occupation = "general_store_clerk"
	d.workplace_location_id = "loc_store"
	d.work_start_hour = 9
	d.work_end_hour = 17
	d.interests = ["cooking", "music"]
	d.skills = {"charisma": 40.0}
	d.personality = {"extroversion": 0.7, "kindness": 0.8, "ambition": 0.6, "humor": 0.5, "discipline": 0.7}
	d.schedule = [
		{"day": "WEEKDAY", "start": 9, "end": 17, "activity": "WORK", "location": "loc_store"},
		{"day": "WEEKEND", "start": 8, "end": 10, "activity": "EXERCISE", "location": "loc_gym"},
		{"day": "ALL", "start": 18, "end": 20, "activity": "SOCIALIZE", "location": "loc_social"},
	]
	d.recalculate_life_stage()
	return d

static func _jordan() -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "jordan"
	d.first_name = "Jordan"
	d.last_name = "Reyes"
	d.age_years = 34
	d.birthday_day_of_year = 25
	d.household_id = "household_jordan"
	d.home_location_id = "home_jordan"
	d.skin_tone = Color(0.45, 0.32, 0.23)
	d.starting_equipment = {"top": "blue_hoodie", "bottom": "gray_sweatpants", "shoes": "black_sneakers", "head": "baseball_cap"}
	d.interests = ["painting", "music"]
	d.skills = {"creativity": 55.0}
	d.personality = {"extroversion": 0.4, "kindness": 0.6, "ambition": 0.5, "humor": 0.7, "discipline": 0.4}
	d.schedule = [
		{"day": "ALL", "start": 15, "end": 17, "activity": "EXERCISE", "location": "loc_gym"},
		{"day": "ALL", "start": 19, "end": 21, "activity": "SOCIALIZE", "location": "loc_social"},
	]
	d.recalculate_life_stage()
	return d

static func _alex() -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "alex"
	d.first_name = "Alex"
	d.last_name = "Rivera"
	d.age_years = 22
	d.birthday_day_of_year = 40
	d.household_id = "household_rivera"
	d.home_location_id = "home_rivera"
	d.skin_tone = Color(0.72, 0.53, 0.38)
	d.starting_equipment = {"top": "black_tshirt", "bottom": "blue_jeans", "shoes": "red_sneakers"}
	d.interests = ["basketball", "fitness"]
	d.skills = {"basketball": 50.0, "fitness": 40.0}
	d.personality = {"extroversion": 0.8, "kindness": 0.5, "ambition": 0.7, "humor": 0.6, "discipline": 0.6}
	d.schedule = [
		{"day": "ALL", "start": 8, "end": 10, "activity": "EXERCISE", "location": "loc_gym"},
		{"day": "ALL", "start": 14, "end": 17, "activity": "BASKETBALL", "location": "loc_basketball"},
		{"day": "ALL", "start": 19, "end": 21, "activity": "SOCIALIZE", "location": "loc_social"},
	]
	d.recalculate_life_stage()
	return d

static func _riley() -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "riley"
	d.first_name = "Riley"
	d.last_name = "Rivera"
	d.age_years = 15
	d.birthday_day_of_year = 55
	d.household_id = "household_rivera"
	d.home_location_id = "home_rivera"
	d.skin_tone = Color(0.75, 0.56, 0.41) # family resemblance to sibling Alex
	d.starting_equipment = {"top": "striped_shirt", "bottom": "blue_jeans", "shoes": "white_sneakers", "head": "black_beanie"}
	d.interests = ["basketball", "skateboarding"]
	d.skills = {"basketball": 20.0}
	d.personality = {"extroversion": 0.6, "kindness": 0.7, "ambition": 0.4, "humor": 0.8, "discipline": 0.3}
	d.schedule = [
		{"day": "WEEKEND", "start": 10, "end": 12, "activity": "EXERCISE", "location": "loc_gym"},
		{"day": "ALL", "start": 16, "end": 18, "activity": "BASKETBALL", "location": "loc_basketball"},
		{"day": "ALL", "start": 19, "end": 20, "activity": "SOCIALIZE", "location": "loc_social"},
	]
	d.recalculate_life_stage()
	return d

static func _sam() -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = "sam"
	d.first_name = "Sam"
	d.last_name = "Okafor"
	d.age_years = 68
	d.birthday_day_of_year = 70
	d.household_id = "household_sam"
	d.home_location_id = "home_sam"
	d.skin_tone = Color(0.58, 0.4, 0.28)
	d.starting_equipment = {"top": "white_tshirt", "bottom": "gray_sweatpants", "shoes": "black_sneakers", "head": "baseball_cap"}
	d.interests = ["gardening", "music"]
	d.skills = {"wisdom": 80.0}
	d.personality = {"extroversion": 0.5, "kindness": 0.9, "ambition": 0.2, "humor": 0.6, "discipline": 0.6}
	d.schedule = [
		{"day": "ALL", "start": 8, "end": 9, "activity": "EXERCISE", "location": "loc_gym"},
		{"day": "ALL", "start": 10, "end": 12, "activity": "SOCIALIZE", "location": "loc_social"},
		{"day": "ALL", "start": 16, "end": 17, "activity": "SOCIALIZE", "location": "loc_social"},
	]
	d.recalculate_life_stage()
	return d
