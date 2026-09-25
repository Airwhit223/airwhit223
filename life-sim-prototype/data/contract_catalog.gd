class_name ContractCatalog
extends RefCounted
## Adventure Contracts - data only. A contract is a job posted on the contract board: a client, a dungeon, what's
## waiting inside, and a list of reusable objective STEPS. to_quest() turns it into an ordinary QuestManager quest
## (giver "contract_board"), so contracts get the tracker, saving and rewards for free, and the board turns them in
## through the same deliver/talk topics an NPC would.
##
## Steps (the reusable contract / dungeon objective hooks - each becomes one quest stage):
##   ["reach", dungeon]                 enter the dungeon (its danger zone fires danger_zone_entered)
##   ["defeat", faction, n, label]      defeat n enemies of a faction (counted enemy_defeated events)
##   ["recover", item, n]               have n of an item from the dungeon's loot (inventory)
##   ["clear+recover", faction, n, item, m, label]  both at once, in any order
##   ["return", item, n]                hand the items in at the contract board
## Dungeons say which enemies and loot to place when the contract is accepted (Dungeon.populate).

## Contract items - quest items (kept out of gifts, never lost to a full bag).
const ITEMS := {
	"silver_locket": "Alvarez family locket",
	"shipment_crate": "Stolen shipment crate",
	"moon_ledger": "Hollowed Moon ledger",
}

const CONTRACTS := [
	{
		"id": "lost_keepsake", "type": "retrieval", "title": "The Lost Keepsake", "client": "Mrs. Alvarez",
		"dungeon": "old_crypt",
		"posting": "My grandmother's silver locket was buried with her in the old crypt under the ruins. Something down there has been dragging things out of the tombs. Please bring it back.",
		"steps": [["reach", "old_crypt"], ["recover", "silver_locket", 1], ["return", "silver_locket", 1]],
		"spawn": {"enemies": [["skeleton", 3]], "loot": [["silver_locket", 1]]},
		"reward": {"money": 120, "adventure_rep": 12, "xp": 60, "skills": {"exploration": 8, "tracking": 6, "combat": 4}},
		"return_line": "The locket's warm from being carried. Mrs. Alvarez will be in tears - the good kind.",
	},
	{
		"id": "stolen_shipment", "type": "stolen_goods", "title": "The Stolen Shipment", "client": "Harbor Master Okafor",
		"dungeon": "smuggler_cellar", "requires_quests": ["contract_lost_keepsake"],
		"posting": "Three crates vanished off the pier overnight. Goblin tracks, and men in moon-sigil coats paying them. They're holed up in the old smugglers' cellar - it runs into the catacombs. Get the crates back.",
		"steps": [["reach", "smuggler_cellar"],
			["clear+recover", "hollowed_moon", 2, "shipment_crate", 3, "Defeat the Hollowed Moon thugs"],
			["return", "shipment_crate", 3]],
		"spawn": {"enemies": [["goblin", 3], ["moon_thug", 2], ["skeleton", 2]],
			"loot": [["shipment_crate", 1], ["shipment_crate", 1], ["shipment_crate", 1], ["moon_ledger", 1]]},
		"reward": {"money": 260, "adventure_rep": 25, "xp": 140, "skills": {"combat": 10, "tracking": 6, "exploration": 4}},
		"return_line": "All three crates, seals intact. The harbor master owes you one - and someone should look at that moon sigil.",
		# the ledger is optional - carrying it back sets a story flag (Hollowed Moon supply lines)
		"bonus_item": ["moon_ledger", "found_moon_ledger", 80],
	},
]

static func all() -> Array:
	return CONTRACTS

static func by_id(id: String) -> Dictionary:
	for c in CONTRACTS:
		if c["id"] == id:
			return c
	return {}

## Quest id for a contract (quests and contracts share QuestManager's namespace).
static func quest_id(contract_id: String) -> String:
	return "contract_" + contract_id

## The contract as a QuestManager quest.
static func to_quest(c: Dictionary) -> Dictionary:
	var stages: Array = []
	for step in c["steps"]:
		match String(step[0]):
			"reach":
				stages.append({"journal": "Find the way into %s." % dungeon_name(step[1]),
					"objectives": [{"type": "event", "event": "danger_zone_entered", "match": {"zone_id": step[1]}}]})
			"defeat":
				stages.append({"journal": step[3] if step.size() > 3 else "Defeat %d %s." % [step[2], faction_name(step[1])],
					"objectives": [_defeat(step[1], int(step[2]))]})
			"recover":
				stages.append({"journal": "Recover the %s." % item_name(step[1]).to_lower(),
					"objectives": [{"type": "item", "item": step[1], "count": int(step[2])}]})
			"clear+recover":
				stages.append({"journal": "%s and recover the %s." % [step[5], item_name(step[3]).to_lower() + ("s" if int(step[4]) > 1 else "")],
					"objectives": [_defeat(step[1], int(step[2])), {"type": "item", "item": step[3], "count": int(step[4])}]})
			"return":
				stages.append({"journal": "Return to the contract board.",
					"objectives": [{"type": "deliver", "npc": "contract_board", "item": step[1], "count": int(step[2]),
						"label": "Turn in: %s" % c["title"], "line": c.get("return_line", "Contract complete.")}]})
	return {"id": quest_id(c["id"]), "title": c["title"], "giver": "contract_board", "contract": c["id"],
		"ask_label": "Take the contract: %s" % c["title"], "offer_line": c["posting"],
		"requires_quests": c.get("requires_quests", []), "stages": stages, "reward": c["reward"]}

static func _defeat(faction: String, n: int) -> Dictionary:
	return {"type": "event", "event": "enemy_defeated", "match": {"faction": faction}, "count": n}

const DUNGEON_NAMES := {"old_crypt": "the Old Crypt", "smuggler_cellar": "the Smugglers' Cellar"}
const FACTION_NAMES := {"goblins": "goblins", "undead": "skeletons", "hollowed_moon": "Hollowed Moon thugs"}

static func dungeon_name(id: String) -> String:
	return String(DUNGEON_NAMES.get(id, id.capitalize()))

static func faction_name(id: String) -> String:
	return String(FACTION_NAMES.get(id, id))

static func item_name(id: String) -> String:
	return String(ITEMS.get(id, id.capitalize()))
