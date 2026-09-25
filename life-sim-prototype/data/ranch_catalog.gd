class_name RanchCatalog
extends RefCounted
## Grandpa's ranch (JobManager "ranch_hand") - data only; world/ranch/ranch.gd runs it.
## Each shift Grandpa writes a task board from the TASKS the player has unlocked (job levels in job_catalog.gd):
## "Feed the chickens", "Fill the cow trough", "Collect 4 eggs", "Repair 2 fence sections"...
## A task is a loop between stations: fetch from a SOURCE (holding it), bring it to a TARGET. Stations: see ranch.gd.
##   unlock    the job-level feature that puts it on the board
##   source    station kind you fetch from ("" = the targets themselves are the source, e.g. nests)
##   carry     what you hold after the source; `carry_max` how many at once
##   target    station kind that takes it; `count` [min, max] how many times it must be done
##   stamina   base stamina per action (JobManager.stamina_cost - free at mastery)
##   skill     the skill that cheapens / speeds it
##   risk      chance per action of a mistake at skill 0 (shrinks with skill) and what it's called

const TASKS := {
	"feed_chickens": {"name": "Feed the chickens", "unlock": "feed", "source": "feed_bin", "carry": "chicken_feed",
		"carry_max": 1, "target": "chicken_trough", "count": [1, 1], "stamina": 2.0, "skill": "animal_handling"},
	"feed_cows": {"name": "Fill the cow trough with hay", "unlock": "feed", "source": "hay_bale", "carry": "hay",
		"carry_max": 1, "target": "cow_trough", "count": [2, 2], "stamina": 4.0, "skill": "strength"},
	"water": {"name": "Refill the water trough", "unlock": "water", "source": "pump", "carry": "water_bucket",
		"carry_max": 1, "target": "water_trough", "count": [2, 3], "stamina": 4.0, "skill": "strength"},
	"eggs": {"name": "Collect eggs", "unlock": "eggs", "source": "nest", "carry": "egg", "carry_max": 6,
		"target": "egg_crate", "count": [3, 5], "stamina": 1.0, "skill": "animal_handling",
		"risk": [0.18, "cracked an egg"]},
	"fence": {"name": "Repair fence sections", "unlock": "fence", "source": "lumber", "carry": "fence_board",
		"carry_max": 1, "target": "broken_fence", "count": [2, 3], "stamina": 6.0, "skill": "strength"},
	"harvest": {"name": "Harvest tomatoes", "unlock": "harvest", "source": "tomato_plant", "carry": "tomato",
		"carry_max": 8, "target": "produce_bin", "count": [6, 8], "stamina": 1.5, "skill": "ranching",
		"risk": [0.12, "bruised a tomato"]},
}

## What you're holding, for prompts and the board.
const CARRY_NAMES := {"chicken_feed": "chicken feed", "hay": "hay", "water_bucket": "a full bucket", "egg": "eggs",
	"fence_board": "a fence board", "tomato": "tomatoes"}

## Things Grandpa might bring up at the start of a shift - hooks for ranch events. Each adds a bonus task.
const EVENTS := {
	"loose_chicken": {"chance": 0.25, "line": "One of the hens got out again. Catch her if you see her!",
		"task": {"name": "Catch the loose hen", "target": "loose_hen", "count": [1, 1], "stamina": 3.0,
			"skill": "animal_handling"}},
}

## How many tasks go on the board for a shift of this length.
static func board_size(hours: int) -> int:
	return 3 if hours <= 2 else 5

## Build today's board: [{"id", "name", "need", "done", "mistakes"}], most important chores first.
static func make_board(unlocked: Array, hours: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[String] = []
	for id in ["feed_chickens", "water", "eggs", "feed_cows", "fence", "harvest"]:
		if TASKS[id]["unlock"] in unlocked:
			pool.append(id)
	var board: Array[Dictionary] = []
	for id in pool.slice(0, board_size(hours)):
		var t: Dictionary = TASKS[id]
		var need := rng.randi_range(int(t["count"][0]), int(t["count"][1]))
		var title := String(t["name"])
		if id in ["eggs", "fence", "harvest"]:
			title = "%s (%d)" % [title, need]
		board.append({"id": id, "name": title, "need": need, "done": 0, "mistakes": 0})
	return board

## The task definition for a board id (events included).
static func task(id: String) -> Dictionary:
	if TASKS.has(id):
		return TASKS[id]
	for e in EVENTS:
		if id == e:
			return EVENTS[e]["task"]
	return {}
