extends SceneTree
## Did the import settings actually take?
func _initialize() -> void:
	var toon := load("res://pets/pet_toon.tres")
	for f in ["husky", "maine_coon_ginger"]:
		var n: Node = load("res://pets/%s.glb" % f).instantiate()
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		var a := ap.get_animation("idle")
		print("%-20s surface_mat=%s  loops=%s" % [f, mi.mesh.surface_get_material(0) == toon,
			a.loop_mode == Animation.LOOP_LINEAR])
		n.queue_free()
	for f in ["hoodie_guy", "casual_girl"]:
		var n: Node = load("res://characters/%s.glb" % f).instantiate()
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		print("%-20s surface_mat=%s  bones=%d  hips=%s" % [f, mi.mesh.surface_get_material(0) == toon,
			sk.get_bone_count(), sk.find_bone("Hips") >= 0])
		n.queue_free()
	var bm := load("res://characters/bone_maps/hoodie_guy_bonemap.tres") as BoneMap
	print("bonemap profile=", bm.profile.get_class(), " Hips->", bm.get_skeleton_bone_name("Hips"),
		" LeftUpperArm->", bm.get_skeleton_bone_name("LeftUpperArm"))
	quit()
