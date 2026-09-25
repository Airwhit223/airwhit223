extends SceneTree
## Host side of the LAN smoke test. Run alongside tests/_net_join.gd in a second process.
func _initialize() -> void: _run.call_deferred()
func _frames(n := 1) -> void:
	for i in n: await process_frame
func _run() -> void:
	var NM := root.get_node_or_null("/root/NetworkManager")
	if NM == null:
		print("HOST no NetworkManager autoload"); quit(1); return
	var joined: Array = []
	NM.player_joined.connect(func(id, prof): joined.append("%d:%s" % [id, prof.get("name", "?")]))
	NM.player_left.connect(func(id): print("HOST peer_left ", id))
	var code: String = NM.start_hosting({"name": "Arin", "player_id": "host_arin", "recipe": {"base": "M"}})
	print("HOST code=", code, " decodes_to=", NM.decode_invite_code(code))
	if code.is_empty():
		print("HOST failed to bind"); quit(1); return
	# wait for the guest
	for i in 900:
		await _frames(1)
		if NM.peer_profiles.size() >= 4:
			break
	await _frames(300)
	print("HOST players=", NM.peer_profiles.size(), " roster=", joined)
	print("HOST scenes=", NM.peer_scenes)
	print("HOST is_host=", NM.is_host(), " my_peer=", NM.my_peer_id(), " remote=", NM.remote_peer_ids())
	print("HOST DONE")
	NM.stop_multiplayer()
	quit()
