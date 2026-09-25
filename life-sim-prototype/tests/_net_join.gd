extends SceneTree
## Guest side of the LAN smoke test.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
func _run() -> void:
	var NM := root.get_node_or_null("/root/NetworkManager")
	await _frames(30)     # let the host bind first
	var reasons: Array = []
	NM.connection_failed.connect(func(r): reasons.append(r))
	var connected := [false]
	NM.server_connected.connect(func(): connected[0] = true)
	var err = NM.join_with_code("RT-L", {"name": OS.get_environment("GUEST_NAME"), "player_id": "guest_" + OS.get_environment("GUEST_NAME").to_lower(), "recipe": {"base": "M"}})
	print("GUEST[", OS.get_environment("GUEST_NAME"), "] join err=", err)
	for i in 600:
		await _frames(1)
		if connected[0] and NM.peer_profiles.size() >= 4:
			break
	NM.report_my_scene("res://scenes/main.tscn")
	await _frames(60)
	print("GUEST[", OS.get_environment("GUEST_NAME"), "] connected=", connected[0], " players=", NM.peer_profiles.size(),
		" my_peer=", NM.my_peer_id(), " is_host=", NM.is_host())
	print("GUEST[", OS.get_environment("GUEST_NAME"), "] roster=", NM.peer_profiles.keys(), " failures=", reasons)
	print("GUEST DONE")
	NM.stop_multiplayer()
	quit()
