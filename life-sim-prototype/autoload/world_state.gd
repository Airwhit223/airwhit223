extends Node
## Central registry so any system can look up "where is location X" or
## "who is NPC Y" without scenes needing hard references to each other.
## Also holds the (currently tiny) roster of jobs, so replacing a shop
## employee later is a data change here, not a rewrite of the NPC or the shop.

var player: Player = null

var _npcs: Dictionary = {}          # npc_id -> NPCBrain
var _locations: Dictionary = {}     # location_id -> Node3D (marker)
var _households: Dictionary = {}    # household_id -> Array[String] npc_ids
## location_id (the OUTDOOR spot, e.g. "loc_store") -> Node3D marker inside
## that building's interior pocket. An NPC whose workplace has an entry here
## teleports in on arrival and back out when their shift ends, instead of
## needing full pathfinding into a space that isn't part of the navmesh.
var _workplace_interiors: Dictionary = {}

## job_id -> npc_id currently holding that job (or "" if vacant)
var jobs: Dictionary = {
	"general_store_clerk": "",
}

func register_npc(npc: NPCBrain) -> void:
	_npcs[npc.definition.id] = npc

func get_npc(npc_id: String) -> NPCBrain:
	return _npcs.get(npc_id, null)

func get_all_npcs() -> Array:
	return _npcs.values()

func register_location(location_id: String, marker) -> void:
	_locations[location_id] = marker

func get_location_position(location_id: String) -> Vector3:
	if _locations.has(location_id):
		return _locations[location_id].global_position
	push_warning("Unknown location id: %s" % location_id)
	return Vector3.ZERO

func has_location(location_id: String) -> bool:
	return _locations.has(location_id)

func register_workplace_interior(location_id: String, spot) -> void:
	_workplace_interiors[location_id] = spot

func get_workplace_interior(location_id: String):
	return _workplace_interiors.get(location_id, null)

func register_household(household_id: String, member_ids: Array) -> void:
	_households[household_id] = member_ids

func get_household_members(household_id: String) -> Array:
	return _households.get(household_id, [])

func assign_job(job_id: String, npc_id: String) -> void:
	var previous: String = jobs.get(job_id, "")
	jobs[job_id] = npc_id
	EventBus.fire("job_assigned", {"job_id": job_id, "npc_id": npc_id, "previous_npc_id": previous})

func vacate_job(job_id: String) -> void:
	var previous: String = jobs.get(job_id, "")
	jobs[job_id] = ""
	EventBus.fire("job_vacated", {"job_id": job_id, "previous_npc_id": previous})

func get_job_holder(job_id: String) -> String:
	return jobs.get(job_id, "")
