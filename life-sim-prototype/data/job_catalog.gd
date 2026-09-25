class_name JobCatalog
extends RefCounted
## Job definitions (data). JobManager runs shifts; each job's gameplay lives in its own controller (restaurant kitchen,
## ranch task board, skate bench) and reports what happened through JobManager.record().
##
##   id / name / workplace (location id) / employer (npc id, may not exist yet)
##   hours: [open, close] the player may start a shift in; shift_lengths: hours on offer
##   pay_per_hour: base wage; tip_per_point: tips per performance point above "Okay"
##   energy_per_hour: long-term drain (physical jobs more)
##   skills: skill -> share of the shift's skill XP
##   enjoy_tags: trait tags that make this job pleasant (small mood + less energy drain) - an extension point
##   levels: job level -> {"title", "reputation" needed, "unlocks": [...]} ; promotions are offered, not automatic
##   dimensions: which performance dimensions this job scores (see JobManager.GRADE_*)

const SKILLS := {
	"cooking": "Cooking", "coordination": "Speed & Coordination", "social": "Social",
	"ranching": "Ranching", "animal_handling": "Animal Handling", "strength": "Strength & Tools",
	"crafting": "Crafting", "skate_knowledge": "Skate Knowledge", "mechanical": "Mechanical",
	"exploration": "Exploration", "combat": "Combat", "tracking": "Tracking",
}

const JOBS := {
	"restaurant_cook": {
		"name": "Line Cook", "workplace": "loc_restaurant", "employer": "restaurant_owner",
		"hours": [10, 22], "shift_lengths": [2, 4], "pay_per_hour": 14, "tip_per_point": 3,
		"energy_per_hour": 7.0, "skills": {"cooking": 0.6, "coordination": 0.3, "social": 0.1},
		"enjoy_tags": [&"creative", &"social"],
		"dimensions": ["orders", "mistakes", "satisfaction", "speed"],
		"levels": {1: {"title": "Prep Cook", "reputation": 0, "unlocks": ["burger", "fries", "salad"]},
			2: {"title": "Line Cook", "reputation": 30, "unlocks": ["soup", "grilled_meat"]},
			3: {"title": "Head Cook", "reputation": 80, "unlocks": ["special_orders"]}},
	},
	"ranch_hand": {
		"name": "Ranch Hand", "workplace": "loc_ranch", "employer": "grandpa",
		"hours": [6, 18], "shift_lengths": [2, 4], "pay_per_hour": 12, "tip_per_point": 2,
		"energy_per_hour": 10.0, "skills": {"ranching": 0.5, "animal_handling": 0.3, "strength": 0.2},
		"enjoy_tags": [&"active", &"outdoorsy"],
		"dimensions": ["tasks", "mistakes", "speed"],
		"levels": {1: {"title": "Helping Grandpa", "reputation": 0, "unlocks": ["feed", "water", "eggs"]},
			2: {"title": "Ranch Hand", "reputation": 30, "unlocks": ["fence", "harvest"]},
			3: {"title": "Foreman", "reputation": 80, "unlocks": ["herding"]}},
	},
	"skate_builder": {
		"name": "Board Builder", "workplace": "loc_skate", "employer": "skate_owner",
		"hours": [11, 20], "shift_lengths": [2, 4], "pay_per_hour": 13, "tip_per_point": 4,
		"energy_per_hour": 6.0, "skills": {"crafting": 0.4, "skate_knowledge": 0.4, "mechanical": 0.2},
		"enjoy_tags": [&"creative", &"sporty"],
		"dimensions": ["orders", "satisfaction", "mistakes"],
		"levels": {1: {"title": "Shop Help", "reputation": 0, "unlocks": ["street", "cruiser"]},
			2: {"title": "Board Builder", "reputation": 30, "unlocks": ["longboard", "budget_orders"]},
			3: {"title": "Custom Builder", "reputation": 80, "unlocks": ["hoverboard", "sponsored"]}},
	},
}

static func get_job(job_id: String) -> Dictionary:
	return JOBS.get(job_id, {})

static func skill_name(skill: String) -> String:
	return String(SKILLS.get(skill, skill.capitalize()))
