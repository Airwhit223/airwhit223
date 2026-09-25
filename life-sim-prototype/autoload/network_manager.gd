extends Node
## LAN co-op for up to four players. Ported from Rolling_Tides_2D/scripts_2d/multiplayer/network_manager.gd,
## which is idiomatic Godot high-level multiplayer (ENet + @rpc), so this is the same design rather than a new one.
##
## Changes from the 2D original:
##  - four players instead of two (MAX_CLIENTS 1 -> 3). The old stack was confirmed at 2 and reported stable at
##    3 by outside testers; 4 has never been tested, so treat the fourth seat as unproven until soaked.
##  - invite codes encode which private range the host is on. The 2D version assumed 192.168.x.x and silently
##    produced an unreachable address on a 10.x or 172.x network.
##  - profiles carry the player's character recipe and a stable player_id, because NPC relationship memory is
##    keyed per person (see docs/MULTIPLAYER_PLAN.md).
##
## Host-authoritative: the host's world is the real one. Guests keep their own character and save.

signal player_joined(peer_id: int, profile: Dictionary)
signal player_left(peer_id: int)
signal server_connected()
signal server_disconnected()
signal connection_failed(reason: String)
signal multiplayer_toggled(enabled: bool)
signal peer_scene_changed(peer_id: int, scene_path: String)
signal profile_updated(peer_id: int, profile: Dictionary)

const PORT: int = 7777
const MAX_CLIENTS: int = 3          # 3 guests + host = 4 players
const CODE_PREFIX: String = "RT-"
const HOST_PEER_ID: int = 1

## peer_id -> profile dictionary
var peer_profiles: Dictionary = {}
## peer_id -> scene path. Peers may stand in different scenes (the underworld, a house interior), so travel
## does not drag everybody along.
var peer_scenes: Dictionary = {}
var is_multiplayer_active: bool = false
var my_profile: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ── Public API ────────────────────────────────────────────────────────────────

## Starts accepting guests and returns the invite code to read out. Call once the host is already in the world.
func start_hosting(profile: Dictionary) -> String:
	if is_multiplayer_active:
		push_warning("[NET] Already active - stop first.")
		return ""
	my_profile = profile.duplicate(true)
	my_profile["peer_id"] = HOST_PEER_ID
	my_profile["role"] = "OWNER"
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[NET] Failed to host on port %d: %s" % [PORT, error_string(err)])
		return ""
	multiplayer.multiplayer_peer = enet
	is_multiplayer_active = true
	peer_profiles[HOST_PEER_ID] = my_profile
	var code := _generate_invite_code()
	print("[NET] Hosting on port %d, room for %d guests. Invite code: %s" % [PORT, MAX_CLIENTS, code])
	multiplayer_toggled.emit(true)
	player_joined.emit(HOST_PEER_ID, my_profile)
	return code

func join_with_code(code: String, profile: Dictionary) -> Error:
	if is_multiplayer_active:
		push_warning("[NET] Already active - stop first.")
		return ERR_ALREADY_IN_USE
	my_profile = profile.duplicate(true)
	var ip := decode_invite_code(code)
	if ip.is_empty():
		connection_failed.emit("That invite code is not readable.")
		return ERR_INVALID_PARAMETER
	print("[NET] Joining %s:%d with code %s" % [ip, PORT, code])
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(ip, PORT)
	if err != OK:
		push_error("[NET] Could not reach %s: %s" % [ip, error_string(err)])
		connection_failed.emit("Could not reach the host.")
		return err
	multiplayer.multiplayer_peer = enet
	is_multiplayer_active = true
	return OK

func stop_multiplayer() -> void:
	if not is_multiplayer_active:
		return
	print("[NET] Stopping multiplayer.")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer_profiles.clear()
	peer_scenes.clear()
	is_multiplayer_active = false
	multiplayer_toggled.emit(false)

func is_host() -> bool:
	return not is_multiplayer_active or multiplayer.is_server()

func my_peer_id() -> int:
	return multiplayer.get_unique_id() if is_multiplayer_active else HOST_PEER_ID

func player_count() -> int:
	return maxi(1, peer_profiles.size())

## The guest's progression belongs to their own save, never the host's world.
## This compact profile is exchanged when they enter a visit; it deliberately
## carries portable character data and home storage/customisation, not quests,
## money, or world-state which remain owned by the host save.
func build_visitor_profile() -> Dictionary:
	var player_name := "Traveller"
	if WorldState.player and WorldState.player.get("player_name"):
		player_name = String(WorldState.player.player_name)
	return {
		"name": player_name,
		"player_id": SaveManager.player_identity,
		"character_recipe": ToriyamaRoster.saved_recipe().duplicate(true),
		"level": Progression.level,
		"stats": PlayerStats.to_dict(),
		"powers": PowerSystem.to_dict(),
		"home_setup": {"storage": InventoryManager.storages.duplicate(true)},
	}

func has_room() -> bool:
	return peer_profiles.size() <= MAX_CLIENTS

func remote_peer_ids() -> Array:
	var out: Array = []
	for id in peer_profiles:
		if int(id) != my_peer_id():
			out.append(int(id))
	return out

## Tell everyone which scene this peer is standing in, so travel does not drag the group along.
func report_my_scene(scene_path: String) -> void:
	if not is_multiplayer_active:
		return
	_rpc_set_peer_scene.rpc(my_peer_id(), scene_path)
	_set_peer_scene_local(my_peer_id(), scene_path)

func scene_of(peer_id: int) -> String:
	return String(peer_scenes.get(peer_id, ""))

# ── Invite codes ──────────────────────────────────────────────────────────────
## A code a person can read down the phone. One letter for the private range, then the octets that vary within
## it, so 10.x and 172.x hosts decode correctly instead of being assumed onto 192.168.
##   L        -> loopback, same machine
##   Cxxxx    -> 192.168.A.B
##   Byyyyyy  -> 172.A.B.C   (A within 16..31)
##   Ayyyyyy  -> 10.A.B.C
func _generate_invite_code() -> String:
	for addr in IP.get_local_addresses():
		var parts := addr.split(".")
		if parts.size() != 4:
			continue
		var o := [int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])]
		if o[0] == 192 and o[1] == 168:
			return CODE_PREFIX + "C%02X%02X" % [o[2], o[3]]
		if o[0] == 172 and o[1] >= 16 and o[1] <= 31:
			return CODE_PREFIX + "B%02X%02X%02X" % [o[1], o[2], o[3]]
		if o[0] == 10:
			return CODE_PREFIX + "A%02X%02X%02X" % [o[1], o[2], o[3]]
	return CODE_PREFIX + "L"

func decode_invite_code(code: String) -> String:
	var body := code.strip_edges().to_upper()
	if body.begins_with(CODE_PREFIX):
		body = body.substr(CODE_PREFIX.length())
	if body.is_empty():
		return ""
	var family := body.substr(0, 1)
	var digits := body.substr(1)
	if family == "L":
		return "127.0.0.1"
	if family == "C" and digits.length() == 4:
		return "192.168.%d.%d" % [_hex(digits, 0), _hex(digits, 2)]
	if family == "B" and digits.length() == 6:
		return "172.%d.%d.%d" % [_hex(digits, 0), _hex(digits, 2), _hex(digits, 4)]
	if family == "A" and digits.length() == 6:
		return "10.%d.%d.%d" % [_hex(digits, 0), _hex(digits, 2), _hex(digits, 4)]
	return ""

func _hex(s: String, at: int) -> int:
	return String("0x" + s.substr(at, 2)).hex_to_int()

# ── Connection handling ───────────────────────────────────────────────────────
func _on_peer_connected(peer_id: int) -> void:
	print("[NET] Peer %d connected." % peer_id)
	if multiplayer.is_server():
		# hand the newcomer the roster, then ask for theirs
		for known_id in peer_profiles:
			_rpc_receive_profile.rpc_id(peer_id, int(known_id), peer_profiles[known_id])
		for known_id in peer_scenes:
			_rpc_set_peer_scene.rpc_id(peer_id, int(known_id), String(peer_scenes[known_id]))
		_rpc_request_profile.rpc_id(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[NET] Peer %d left." % peer_id)
	peer_profiles.erase(peer_id)
	peer_scenes.erase(peer_id)
	player_left.emit(peer_id)
	if multiplayer.is_server():
		_rpc_peer_left.rpc(peer_id)

func _on_connected_to_server() -> void:
	print("[NET] Connected to host as peer %d." % multiplayer.get_unique_id())
	my_profile["peer_id"] = multiplayer.get_unique_id()
	my_profile["role"] = my_profile.get("role", "MEMBER")
	server_connected.emit()
	_rpc_submit_profile.rpc_id(HOST_PEER_ID, my_profile)

func _on_connection_failed() -> void:
	is_multiplayer_active = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit("The host refused the connection.")

func _on_server_disconnected() -> void:
	print("[NET] Host closed the session.")
	peer_profiles.clear()
	peer_scenes.clear()
	is_multiplayer_active = false
	server_disconnected.emit()
	multiplayer_toggled.emit(false)

# ── RPCs ──────────────────────────────────────────────────────────────────────
@rpc("authority", "call_remote", "reliable")
func _rpc_request_profile() -> void:
	_rpc_submit_profile.rpc_id(HOST_PEER_ID, my_profile)

## Guest -> host. The host is the only one that adds to the roster, then republishes it.
@rpc("any_peer", "reliable")
func _rpc_submit_profile(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var stored := profile.duplicate(true)
	stored["peer_id"] = sender
	stored["role"] = stored.get("role", "MEMBER")
	peer_profiles[sender] = stored
	_rpc_receive_profile.rpc(sender, stored)
	_register_profile(sender, stored)

@rpc("authority", "reliable")
func _rpc_receive_profile(peer_id: int, profile: Dictionary) -> void:
	_register_profile(peer_id, profile)

@rpc("authority", "reliable")
func _rpc_peer_left(peer_id: int) -> void:
	if peer_profiles.erase(peer_id):
		peer_scenes.erase(peer_id)
		player_left.emit(peer_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_peer_scene(peer_id: int, scene_path: String) -> void:
	_set_peer_scene_local(peer_id, scene_path)
	if multiplayer.is_server():
		_rpc_set_peer_scene.rpc(peer_id, scene_path)

func _set_peer_scene_local(peer_id: int, scene_path: String) -> void:
	peer_scenes[peer_id] = scene_path
	peer_scene_changed.emit(peer_id, scene_path)

func _register_profile(peer_id: int, profile: Dictionary) -> void:
	var known := peer_profiles.has(peer_id)
	peer_profiles[peer_id] = profile
	if known:
		profile_updated.emit(peer_id, profile)
	else:
		print("[NET] %s joined as peer %d (%d/%d players)." % [
			profile.get("name", "A traveller"), peer_id, peer_profiles.size(), MAX_CLIENTS + 1])
		player_joined.emit(peer_id, profile)
