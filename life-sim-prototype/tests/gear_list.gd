extends SceneTree
## Does the creator see the new gear? Data only, no rendering.
func _initialize() -> void:
	var by_slot := CreatorData.garments_by_slot()
	print("SHOES ", by_slot.get("shoes", []))
	print("PROPS ", ToriyamaKitCharacter.list_parts("prop"))
	for v in ToriyamaKitCharacter.list_parts("prop"):
		var kit := ToriyamaKitCharacter.kit_json("prop", v)
		print("  ", v, " slot=", kit.get("slot", "?"), " sword=", kit.get("sword", "?"),
			" sockets=", (kit.get("meshes", {}).get(String(kit.get("saya", "")), {}) as Dictionary).get("sockets", {}).keys())
	for s in ["TR_Skate_Hi", "TR_Chunky_Hi"]:
		var kit := ToriyamaKitCharacter.kit_json("garment", s)
		print("  ", s, " slot=", kit.get("slot", "?"), " roles=", kit.get("roles", []))
	quit()
