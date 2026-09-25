extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var rig := CharacterRig.new()
	rig.toriyama_recipe = CreatorData.default_recipe()
	world.add_child(rig)
	for i in 8: await process_frame
	var prof: Dictionary = rig._get_active_profile()
	print("recipe movement = ", CreatorData.default_recipe().get("movement"))
	print("active profile is_legacy = ", prof.get("is_legacy", false))
	print("profile keys = ", prof.keys())
	print("LOCOMOTION_PROFILES = ", CharacterRig.LOCOMOTION_PROFILES.keys())
	quit()
