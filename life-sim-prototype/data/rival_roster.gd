class_name RivalRoster
extends RefCounted
## The Rolling Tides rivals: six NPCs added on top of the resident cast (NPCRoster stays the five residents, so the
## social / event simulations and their tests are unchanged). Each wears their Toriyama model (see ToriyamaRoster)
## and lives on Rival Row, a line of home spots behind the houses (markers added by main.gd).

const HOUSEHOLDS := {
	"household_jace": ["jace"],
	"household_theo": ["theo"],
	"household_blair": ["blair"],
	"household_kira": ["kira"],
	"household_maya_reyes": ["maya_reyes"],
	"household_jones": ["jones"],
}

## home location id -> position (open ground behind the resident houses)
const HOMES := {
	"home_jace": Vector3(-28, 0, -30),
	"home_theo": Vector3(-17, 0, -30),
	"home_blair": Vector3(-6, 0, -30),
	"home_kira": Vector3(5, 0, -30),
	"home_maya_reyes": Vector3(16, 0, -30),
	"home_jones": Vector3(27, 0, -30),
}

## nametag outline colour per rival (debug marker, like main.gd's NPC_COLORS)
const COLORS := {
	"jace": Color(0.72, 0.12, 0.16),
	"theo": Color(0.13, 0.23, 0.37),
	"blair": Color(0.85, 0.70, 0.42),
	"kira": Color(0.88, 0.33, 0.56),
	"maya_reyes": Color(0.18, 0.55, 0.55),
	"jones": Color(0.66, 0.16, 0.17),
}

static func build() -> Array[NPCDefinition]:
	var roster: Array[NPCDefinition] = []
	roster.append(_make("jace", "Jace", "Moreno", 17, 12, Color(0.78, 0.58, 0.42),
		["skateboarding", "music"], {"creativity": 45.0},
		{"extroversion": 0.6, "kindness": 0.4, "ambition": 0.7, "humor": 0.6, "discipline": 0.3},
		[{"day": "ALL", "start": 10, "end": 16, "activity": "WORK", "location": "loc_skate"},
		 {"day": "ALL", "start": 19, "end": 22, "activity": "SOCIALIZE", "location": "loc_social"}]))
	roster.append(_make("theo", "Theo", "Bennett", 17, 30, Color(0.93, 0.80, 0.68),
		["reading", "games"], {"wisdom": 65.0},
		{"extroversion": 0.3, "kindness": 0.6, "ambition": 0.8, "humor": 0.5, "discipline": 0.8},
		[{"day": "WEEKEND", "start": 10, "end": 12, "activity": "SOCIALIZE", "location": "loc_tavern"},
		 {"day": "ALL", "start": 17, "end": 19, "activity": "SOCIALIZE", "location": "loc_tavern"}]))
	roster.append(_make("blair", "Blair", "Sinclair", 17, 48, Color(0.96, 0.86, 0.78),
		["fashion", "music"], {"charisma": 60.0},
		{"extroversion": 0.8, "kindness": 0.3, "ambition": 0.9, "humor": 0.4, "discipline": 0.7},
		[{"day": "ALL", "start": 12, "end": 15, "activity": "SOCIALIZE", "location": "loc_neon_plaza"},
		 {"day": "ALL", "start": 18, "end": 21, "activity": "SOCIALIZE", "location": "loc_neon_plaza"}]))
	roster.append(_make("kira", "Kira", "Brooks", 17, 63, Color(0.78, 0.58, 0.42),
		["skateboarding", "basketball"], {"basketball": 35.0},
		{"extroversion": 0.9, "kindness": 0.35, "ambition": 0.5, "humor": 0.8, "discipline": 0.2},
		[{"day": "ALL", "start": 15, "end": 19, "activity": "SOCIALIZE", "location": "loc_boardwalk"},
		 {"day": "ALL", "start": 19, "end": 23, "activity": "SOCIALIZE", "location": "loc_boardwalk"}]))
	roster.append(_make("maya_reyes", "Maya", "Reyes", 17, 5, Color(0.55, 0.38, 0.26),
		["fitness", "basketball"], {"fitness": 55.0, "basketball": 45.0},
		{"extroversion": 0.6, "kindness": 0.7, "ambition": 0.8, "humor": 0.5, "discipline": 0.8},
		[{"day": "ALL", "start": 7, "end": 9, "activity": "EXERCISE", "location": "loc_gym"},
		 {"day": "ALL", "start": 15, "end": 17, "activity": "BASKETBALL", "location": "loc_basketball"},
		 {"day": "ALL", "start": 19, "end": 21, "activity": "SOCIALIZE", "location": "loc_social"}]))
	roster.append(_make("jones", "Mr.", "Jones", 38, 77, Color(0.78, 0.58, 0.42),
		["music", "cooking"], {"wisdom": 55.0, "charisma": 45.0},
		{"extroversion": 0.5, "kindness": 0.5, "ambition": 0.6, "humor": 0.7, "discipline": 0.6},
		[{"day": "ALL", "start": 11, "end": 12, "activity": "SOCIALIZE", "location": "loc_store"},
		 {"day": "ALL", "start": 12, "end": 17, "activity": "ADVENTURE", "location": "loc_adventure"},
		 {"day": "ALL", "start": 18, "end": 20, "activity": "SOCIALIZE", "location": "loc_social"}]))
	return roster

static func _make(id: String, first: String, last: String, age: int, birthday: int, skin: Color, interests: Array,
		skills: Dictionary, personality: Dictionary, schedule: Array) -> NPCDefinition:
	var d := NPCDefinition.new()
	d.id = id
	d.first_name = first
	d.last_name = last
	d.age_years = age
	d.birthday_day_of_year = birthday
	d.household_id = "household_" + id
	d.home_location_id = "home_" + id
	d.skin_tone = skin
	d.starting_equipment = {}   # the Toriyama model carries the outfit
	d.interests.assign(interests)
	d.skills = skills
	d.personality = personality
	d.schedule.assign(schedule)
	d.recalculate_life_stage()
	return d
