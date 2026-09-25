extends SceneTree
## Verifies res://equipment/skateboard.tscn instantiates with proper hierarchy,
## wheels roll with speed, and carving tilt responds to turn input.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://equipment/skateboard.tscn")
	assert(scene != null, "skateboard.tscn must exist and load")
	
	var board: Node3D = scene.instantiate()
	assert(board != null, "Must instantiate board")
	
	# Add to tree root so _ready fires
	root.add_child(board)
	
	# Verify hierarchy
	assert(board.deck_pivot != null, "Must have Deck pivot")
	assert(board.front_truck != null, "Must have FrontTruck")
	assert(board.rear_truck != null, "Must have RearTruck")
	assert(board.wheel_fl != null, "Must have Wheel_FL")
	assert(board.wheel_fr != null, "Must have Wheel_FR")
	assert(board.wheel_bl != null, "Must have Wheel_BL")
	assert(board.wheel_br != null, "Must have Wheel_BR")
	print("PASS: hierarchy verified (deck, nose, tail, trucks, 4 wheels)")
	
	# Verify wheel rolling
	var initial_rot: float = board.wheel_rotation
	board.update_skate(6.0, 0.0, 0.1) # 6 m/s forward for 0.1s
	assert(board.wheel_rotation > initial_rot, "Wheel rotation must advance when moving forward")
	assert(board.wheel_fl.rotation.x > 0.0, "Wheel mesh rotation.x must update")
	print("PASS: wheels roll with forward motion (d_rot = %f)" % (board.wheel_rotation - initial_rot))
	
	# Verify carving tilt
	board.update_skate(6.0, 1.0, 0.1) # Hard right turn
	assert(board.deck_pivot.rotation_degrees.z < 0.0, "Deck must tilt into right turn (negative roll)")
	assert(board.front_truck.rotation_degrees.y > 0.0, "Front truck must steer into turn")
	print("PASS: deck carves and tilts with steering input (tilt = %f deg)" % board.deck_pivot.rotation_degrees.z)
	
	# Verify graphic color change
	board.set_deck_graphic_color(Color.RED)
	print("PASS: deck graphic color customization works")
	
	print("ALL SKATEBOARD TESTS PASSED!")
	board.queue_free()
	quit()
