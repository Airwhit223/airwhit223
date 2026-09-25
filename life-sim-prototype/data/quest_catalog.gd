class_name QuestCatalog
extends RefCounted
## Authored personal quests, run by the QuestManager autoload. Pure data - see quest_manager.gd for the objective types.
##
## The three quest lines below are DRAFT SKELETONS from the user's premises (2026-09-24). Their giver NPCs are not in
## the roster yet, so they sit unoffered until those characters exist; steps and lines get rewritten once the user's
## full designs come in.

const ITEMS := {
	"medicine_herb": "Moonroot herb",
	"father_medicine": "Father's medicine",
	"explorer_map": "Bram's old survey map",
	"relic_shard": "Ancient relic shard",
}

const QUESTS := [
	{
		"id": "chen_medicine", "title": "Medicine for Father", "giver": "mei_chen",
		"ask_label": "You look worried. Is everything okay?",
		"offer_line": "Our father is sick, and the clinic's medicine isn't working. There's an old remedy... but the herb only grows far outside town. Would you help us?",
		"stages": [
			{"journal": "Ask Jian what the remedy needs.",
				"objectives": [{"type": "talk", "npc": "jian_chen", "label": "Mei told me about your father.",
					"line": "The remedy needs moonroot. Grandmother wrote down where it grew - out past the old quarry."}]},
			{"journal": "Find moonroot outside town.",
				"objectives": [{"type": "item", "item": "medicine_herb", "count": 1}]},
			{"journal": "Bring the moonroot to Mei.",
				"objectives": [{"type": "deliver", "npc": "mei_chen", "item": "medicine_herb", "count": 1,
					"label": "I found the moonroot.", "line": "You found it! I'll start brewing right away. Thank you - really."}]},
		],
		"reward": {"friendship": 3}, "set_flags": ["chen_father_saved"],
	},
	{
		"id": "bram_expedition", "title": "The Bram Expedition", "giver": "bram",
		"ask_label": "Planning another trip?",
		"offer_line": "Always! My family's been mapping the old ruins for three generations. We lost Grandpa's survey map - without it we can't find the lower chambers.",
		"stages": [
			{"journal": "Recover the Bram family's survey map.",
				"objectives": [{"type": "item", "item": "explorer_map", "count": 1}]},
			{"journal": "Return the map to Bram.",
				"objectives": [{"type": "deliver", "npc": "bram", "item": "explorer_map", "count": 1,
					"label": "Is this your map?", "line": "That's it! Grandpa's handwriting and everything. You're coming with us next time."}]},
		],
		"reward": {"friendship": 3}, "set_flags": ["bram_expedition_ready"],
	},
	{
		"id": "princess_cosmic_travel", "title": "The Princess Among the Stars", "giver": "egypt_princess",
		"ask_label": "You keep watching the sky.",
		"offer_line": "My father was one of the Ancients. Mother says I'm too young to see where he came from. I don't agree. Take me with you when you travel - please.",
		"requires_flags": [],
		"stages": [
			{"journal": "Get the queen's blessing.",
				"objectives": [{"type": "talk", "npc": "egypt_queen", "label": "Your daughter wants to travel with me.",
					"line": "...She is her father's daughter. Very well. Bring her back to me."}]},
			{"journal": "Travel to the stars with the princess.", "follower": "egypt_princess",
				"objectives": [{"type": "event", "event": "cosmic_travel_arrived"}]},
			{"journal": "Bring the princess home.", "follower": "egypt_princess",
				"objectives": [{"type": "talk", "npc": "egypt_queen", "label": "She's home safe.",
					"line": "You kept your word. The Ancients chose well when they trusted your kind."}]},
		],
		"reward": {"friendship": 4}, "set_flags": ["princess_travelled"],
	},
]

## Quests added at runtime (tests, and later generated ones such as adventure contracts).
static var extra: Array = []
static var _contracts: Array = []

## Authored quests + adventure contracts (data/contract_catalog.gd, as quests) + ones added at runtime.
static func all() -> Array:
	if _contracts.is_empty():
		for c in ContractCatalog.all():
			_contracts.append(ContractCatalog.to_quest(c))
	return QUESTS + _contracts + extra

static func by_id(quest_id: String) -> Dictionary:
	for q in all():
		if q["id"] == quest_id:
			return q
	return {}

static func item_name(item_id: String) -> String:
	if ContractCatalog.ITEMS.has(item_id):
		return String(ContractCatalog.ITEMS[item_id])
	return String(ITEMS.get(item_id, item_id.replace("_", " ").capitalize()))
