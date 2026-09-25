extends Node
## Player bonds are private to each player's journal and never share the NPC
## relationship graph. A visit awards both participants equally via RPC.

signal bond_changed(player_id: String, bond: Dictionary)

const ACTIVITY_POINTS := {"explore": 4, "farm": 3, "meal": 3, "arcade": 3, "hangout": 2}
const RANKS := ["Acquaintance", "Friend", "Close Friend", "Kindred Spirit"]
var bonds: Dictionary = {} # persistent player_id -> {name, points, activities, last_day}

func record_shared_activity(peer_id: int, kind: String) -> bool:
	if not NetworkManager.is_multiplayer_active or not NetworkManager.peer_profiles.has(peer_id):
		return false
	if not ACTIVITY_POINTS.has(kind):
		return false
	var peer: Dictionary = NetworkManager.peer_profiles[peer_id]
	if not _record_local(String(peer.get("player_id", peer_id)), String(peer.get("name", "Traveller")), kind):
		return false
	if NetworkManager.is_host():
		_receive_bond_activity.rpc_id(peer_id, NetworkManager.my_profile.get("player_id", "host"), NetworkManager.my_profile.get("name", "Host"), kind)
	else:
		_request_bond_activity.rpc_id(NetworkManager.HOST_PEER_ID, kind)
	return true

@rpc("any_peer", "reliable")
func _request_bond_activity(kind: String) -> void:
	if not NetworkManager.is_host() or not ACTIVITY_POINTS.has(kind):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var peer: Dictionary = NetworkManager.peer_profiles.get(peer_id, {})
	if _record_local(String(peer.get("player_id", peer_id)), String(peer.get("name", "Traveller")), kind):
		_receive_bond_activity.rpc_id(peer_id, NetworkManager.my_profile.get("player_id", "host"), NetworkManager.my_profile.get("name", "Host"), kind)

@rpc("authority", "reliable")
func _receive_bond_activity(player_id: String, player_name: String, kind: String) -> void:
	_record_local(player_id, player_name, kind)

func _record_local(player_id: String, player_name: String, kind: String) -> bool:
	var bond: Dictionary = bonds.get(player_id, {"name": player_name, "points": 0, "activities": {}, "last_day": {}})
	var last: Dictionary = bond.get("last_day", {})
	# One meaningful activity of each type per player per day; no gift-spam grind.
	if int(last.get(kind, -1)) == TimeManager.day_index:
		return false
	last[kind] = TimeManager.day_index
	bond["name"] = player_name
	bond["last_day"] = last
	bond["points"] = int(bond.get("points", 0)) + int(ACTIVITY_POINTS[kind])
	var activities: Dictionary = bond.get("activities", {})
	activities[kind] = int(activities.get(kind, 0)) + 1
	bond["activities"] = activities
	bonds[player_id] = bond
	bond_changed.emit(player_id, bond.duplicate(true))
	return true

func rank_of(player_id: String) -> String:
	var points := int((bonds.get(player_id, {}) as Dictionary).get("points", 0))
	return RANKS[clampi(points / 15, 0, RANKS.size() - 1)]

func to_dict() -> Dictionary:
	return {"bonds": bonds.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	bonds = data.get("bonds", {}).duplicate(true)
