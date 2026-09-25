extends SceneTree
## One BoneMap per character, auto-filled from SkeletonProfileHumanoid. The characters already use the profile's own
## bone names, so every bone maps itself; generating the resource here rather than hand-writing the .tres means the
## mapping is checked against the real skeleton instead of assumed.
func _initialize() -> void:
	for name in ["hoodie_guy", "hoodie_guy_black", "egyptian_queen", "egyptian_queen_meshy", "casual_girl"]:
		var scene: PackedScene = load("res://characters/%s.glb" % name)
		var n: Node = scene.instantiate()
		var sk: Skeleton3D = null
		for x: Skeleton3D in n.find_children("*", "Skeleton3D", true, false):
			sk = x
		if sk == null:
			print(name, " -> no Skeleton3D"); continue
		var have := {}
		for i in sk.get_bone_count():
			have[sk.get_bone_name(i)] = true
		var profile := SkeletonProfileHumanoid.new()
		var map := BoneMap.new()
		map.profile = profile
		var mapped := 0
		var missing: Array[String] = []
		for i in profile.bone_size:
			var pname := profile.get_bone_name(i)
			if have.has(pname):
				map.set_skeleton_bone_name(pname, pname)
				mapped += 1
			else:
				missing.append(pname)
		var path := "res://characters/bone_maps/%s_bonemap.tres" % name
		var err := ResourceSaver.save(map, path)
		print("%-22s skeleton=%s bones=%d mapped=%d/%d saved=%s unmapped=%s" % [name, sk.name, sk.get_bone_count(),
			mapped, profile.bone_size, "ok" if err == OK else str(err), str(missing.slice(0, 6))])
		n.queue_free()
	quit()
