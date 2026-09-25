extends SceneTree
## Rolling Tides - the docks town on the Old Shore. The world shipped the pier, two carts, two skiffs and the
## lighthouse; the town itself was missing. Built from the user's original world map (SURF SHACK, ICE CREAM,
## FISH N' CHIPS, the carousel and ferris wheel on the boardwalk) and old_shore_docks_sunset.jpg.
##
## Additive layer in world/detail/ - rolling_tides_world.tscn is re-synced from the Antigravity copy, so nothing
## is written into it.
##
## Ground it sits on: beach sand spans x 105..255, z 192..237. The pier runs out from z 244 to 265.
## The town takes the strip between them, facing the water.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/build_old_shore_detail.gd

const OUT := "res://world/detail/"
const MATS := "res://world/rolling_tides_world/materials/"

const DECK_Z := 240.0
const SHOP_Z := 231.0

## name, x, width, awning material, sign text
const SHOPS := [
	["SurfShack", 138.0, 11.0, "awning_blue", "SURF SHACK"],
	["IceCream", 152.0, 9.0, "awning_red", "ICE CREAM"],
	["FishAndChips", 165.0, 10.0, "awning_yellow", "FISH N' CHIPS"],
	["BaitAndTackle", 179.0, 9.5, "awning_blue", "BAIT & TACKLE"],
	["Harbormaster", 193.0, 12.0, "awning_red", "HARBORMASTER"],
]

var M := {}

func _initialize() -> void:
	_build.call_deferred()

func _m(n: String) -> Material:
	if not M.has(n):
		M[n] = load(MATS + n + ".tres")
	return M[n]

func _box(parent: Node3D, n: String, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0, collide := true) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	var mi := MeshInstance3D.new(); mi.name = n; mi.mesh = mesh; mi.position = pos
	mi.rotation.y = yaw; mi.material_override = mat
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new(); var shape := CollisionShape3D.new()
		var box := BoxShape3D.new(); box.size = size; shape.shape = box
		body.add_child(shape); mi.add_child(body)
	return mi

func _shape(parent: Node3D, n: String, pos: Vector3, mesh: Mesh, mat: Material, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = n; mi.mesh = mesh; mi.position = pos
	mi.scale = scale; mi.rotation = rot; mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sign(parent: Node3D, n: String, pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.name = n
	label.text = text
	label.position = pos
	label.font_size = 96
	label.pixel_size = 0.010
	label.outline_size = 18
	label.modulate = Color(0.16, 0.10, 0.07)
	label.outline_modulate = Color(0.98, 0.94, 0.86)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = true        # the boardwalk is walked from both ends
	# The shopfronts face the water at +Z, which is the way an unrotated Label3D already reads. Turning it put
	# every sign face-down into its own wall.
	parent.add_child(label)

func _lamp(parent: Node3D, n: String, pos: Vector3) -> void:
	var l := Node3D.new(); l.name = n; l.position = pos; parent.add_child(l)
	_shape(l, "Post", Vector3(0, 2.1, 0), CylinderMesh.new(), _m("iron"), Vector3(0.09, 2.1, 0.09))
	_box(l, "Head", Vector3(0, 4.4, 0), Vector3(0.55, 0.7, 0.55), _m("lamp_glow"), 0.0, false)
	_box(l, "Cap", Vector3(0, 4.85, 0), Vector3(0.75, 0.2, 0.75), _m("iron"), 0.0, false)

func _barrel(parent: Node3D, n: String, pos: Vector3) -> void:
	_shape(parent, n, pos + Vector3(0, 0.6, 0), CylinderMesh.new(), _m("wood_barrel"), Vector3(0.48, 0.6, 0.48))

func _crate(parent: Node3D, n: String, pos: Vector3, yaw := 0.0) -> void:
	_box(parent, n, pos + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), _m("wood_crate"), yaw)

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var rng := RandomNumberGenerator.new(); rng.seed = 20260924
	var root := Node3D.new(); root.name = "OldShoreDetail"

	# --- the boardwalk deck the whole town stands on --------------------------------------------------------------
	var deck := Node3D.new(); deck.name = "Boardwalk"; root.add_child(deck)
	_box(deck, "Deck", Vector3(172, 0.25, DECK_Z), Vector3(96, 0.5, 11), _m("pier_wood"))
	_box(deck, "DeckEdge", Vector3(172, 0.55, DECK_Z + 5.4), Vector3(96, 0.3, 0.4), _m("dark_timber"), 0.0, false)
	for i in 17:                     # pilings under the seaward edge
		_shape(deck, "Piling%d" % (i + 1), Vector3(126.0 + i * 5.8, -0.6, DECK_Z + 5.0), CylinderMesh.new(),
			_m("dark_timber"), Vector3(0.28, 1.1, 0.28))
	# ramp down to the sand, so the boardwalk connects to the beach instead of floating
	_box(deck, "BeachRamp", Vector3(150, 0.2, DECK_Z - 7.5), Vector3(8, 0.4, 6), _m("pier_wood"), 0.0, false)
	# link to the pier that already exists out at z 244
	_box(deck, "PierApron", Vector3(167, 0.3, DECK_Z + 4.0), Vector3(22, 0.4, 5), _m("pier_wood"), 0.0, false)

	# --- the shopfronts -------------------------------------------------------------------------------------------
	var shops := Node3D.new(); shops.name = "Shopfronts"; root.add_child(shops)
	for entry in SHOPS:
		var n: String = entry[0]
		var x: float = entry[1]
		var w: float = entry[2]
		var awning: String = entry[3]
		var text: String = entry[4]
		var shop := Node3D.new(); shop.name = n; shop.position = Vector3(x, 0, SHOP_Z); shops.add_child(shop)
		var h := 5.6 if n == "Harbormaster" else 4.6
		_box(shop, "Walls", Vector3(0, h * 0.5, 0), Vector3(w, h, 8.0), _m("warm_wood"))
		_box(shop, "Roof", Vector3(0, h + 0.35, 0), Vector3(w + 1.2, 0.7, 9.0),
			_m("roof_slate") if n in ["SurfShack", "FishAndChips", "Harbormaster"] else _m("dark_timber"), 0.0, false)
		_box(shop, "Door", Vector3(-w * 0.26, 1.35, 4.1), Vector3(1.6, 2.7, 0.2), _m("door_wood"), 0.0, false)
		_box(shop, "Window", Vector3(w * 0.22, 2.1, 4.1), Vector3(w * 0.4, 1.7, 0.18), _m("window_glow"), 0.0, false)
		_box(shop, "Awning", Vector3(0, 3.5, 5.3), Vector3(w + 0.6, 0.18, 2.6), _m(awning), 0.0, false)
		for side in [-1.0, 1.0]:
			_shape(shop, "AwningPost%s" % ("L" if side < 0 else "R"),
				Vector3(side * (w * 0.5 - 0.3), 1.7, 6.4), CylinderMesh.new(), _m("dark_timber"),
				Vector3(0.09, 1.7, 0.09))
		_box(shop, "SignBoard", Vector3(0, h - 0.5, 4.15), Vector3(w * 0.78, 1.1, 0.14), _m("cream"), 0.0, false)
		_sign(shop, "SignText", Vector3(0, h - 0.5, 4.3), text)
		# a crate or two by every door, the way a working shop looks
		_crate(shop, "Crate", Vector3(w * 0.5 - 0.8, 0, 5.0), rng.randf_range(-0.4, 0.4))
		if rng.randf() > 0.4:
			_barrel(shop, "Barrel", Vector3(-w * 0.5 + 0.9, 0, 5.2))

	# --- market stalls, lamps and benches along the deck ----------------------------------------------------------
	var market := Node3D.new(); market.name = "MarketRow"; root.add_child(market)
	var awnings := ["awning_red", "awning_yellow", "awning_blue"]
	for i in 6:
		var x := 132.0 + i * 13.0
		var stall := Node3D.new(); stall.name = "Stall%d" % (i + 1); stall.position = Vector3(x, 0.5, DECK_Z + 2.6)
		market.add_child(stall)
		_box(stall, "Counter", Vector3(0, 0.55, 0), Vector3(3.6, 1.1, 1.9), _m("warm_wood"))
		_box(stall, "Canopy", Vector3(0, 2.5, 0), Vector3(4.6, 0.16, 3.0), _m(awnings[i % 3]), 0.0, false)
		for c in [Vector3(-2.0, 1.25, -1.2), Vector3(2.0, 1.25, -1.2), Vector3(-2.0, 1.25, 1.2), Vector3(2.0, 1.25, 1.2)]:
			_shape(stall, "Post%d_%d" % [int(c.x), int(c.z)], c, CylinderMesh.new(), _m("dark_timber"),
				Vector3(0.07, 1.25, 0.07))
		_crate(stall, "StallCrate", Vector3(2.4, -0.5, 0.9))
	for i in 7:
		_lamp(market, "DeckLamp%d" % (i + 1), Vector3(128.0 + i * 15.0, 0.5, DECK_Z + 4.4))
	for i in 4:
		var bench := Node3D.new(); bench.name = "Bench%d" % (i + 1)
		bench.position = Vector3(140.0 + i * 18.0, 0.5, DECK_Z + 3.8)
		market.add_child(bench)
		_box(bench, "Seat", Vector3(0, 0.55, 0), Vector3(3.0, 0.16, 0.8), _m("warm_wood"))
		_box(bench, "Back", Vector3(0, 1.0, -0.36), Vector3(3.0, 0.7, 0.14), _m("warm_wood"), 0.0, false)
		for side in [-1.0, 1.0]:
			_box(bench, "Leg%s" % ("L" if side < 0 else "R"), Vector3(side * 1.3, 0.25, 0), Vector3(0.16, 0.5, 0.7),
				_m("dark_timber"), 0.0, false)

	# --- working dock clutter -------------------------------------------------------------------------------------
	var dock := Node3D.new(); dock.name = "DockClutter"; root.add_child(dock)
	for i in 10:
		_barrel(dock, "Barrel%d" % (i + 1), Vector3(rng.randf_range(130.0, 212.0), 0.5,
			DECK_Z + rng.randf_range(-3.6, 4.2)))
	for i in 12:
		_crate(dock, "Crate%d" % (i + 1), Vector3(rng.randf_range(130.0, 212.0), 0.5,
			DECK_Z + rng.randf_range(-3.8, 4.4)), rng.randf_range(-0.6, 0.6))
	for i in 8:                      # lobster pots: a cage with a rope loop
		var pot := Node3D.new(); pot.name = "LobsterPot%d" % (i + 1)
		pot.position = Vector3(134.0 + i * 9.5, 0.5, DECK_Z - 4.2)
		dock.add_child(pot)
		_box(pot, "Cage", Vector3(0, 0.34, 0), Vector3(1.1, 0.68, 0.9), _m("rust_metal"))
		_shape(pot, "Rope", Vector3(0.4, 0.75, 0.2), TorusMesh.new(), _m("wood_barrel"), Vector3(0.3, 0.3, 0.3))
	for i in 9:                      # mooring bollards along the seaward edge
		_shape(dock, "Bollard%d" % (i + 1), Vector3(130.0 + i * 10.0, 0.85, DECK_Z + 5.0), CylinderMesh.new(),
			_m("iron"), Vector3(0.24, 0.45, 0.24))

	# --- the fairground at the east end, from the original map ----------------------------------------------------
	var fair := Node3D.new(); fair.name = "Fairground"; fair.position = Vector3(214, 0, 236); root.add_child(fair)
	# carousel
	var carousel := Node3D.new(); carousel.name = "Carousel"; fair.add_child(carousel)
	_shape(carousel, "Platform", Vector3(0, 0.4, 0), CylinderMesh.new(), _m("pier_wood"), Vector3(6.0, 0.4, 6.0))
	_shape(carousel, "CentrePole", Vector3(0, 3.0, 0), CylinderMesh.new(), _m("iron"), Vector3(0.3, 3.0, 0.3))
	for i in 8:
		var a := i * TAU / 8.0
		_shape(carousel, "Pole%d" % (i + 1), Vector3(sin(a) * 4.6, 2.4, cos(a) * 4.6), CylinderMesh.new(),
			_m("awning_yellow"), Vector3(0.09, 2.0, 0.09))
		_shape(carousel, "Horse%d" % (i + 1), Vector3(sin(a) * 4.6, 1.6, cos(a) * 4.6), BoxMesh.new(),
			_m("cream"), Vector3(1.4, 0.8, 0.5), Vector3(0, -a, 0))
	var canopy := CylinderMesh.new(); canopy.top_radius = 0.4; canopy.bottom_radius = 6.2; canopy.height = 2.2
	_shape(carousel, "Canopy", Vector3(0, 5.4, 0), canopy, _m("awning_red"))
	# ferris wheel, side-on to the water
	var wheel := Node3D.new(); wheel.name = "FerrisWheel"; wheel.position = Vector3(16, 0, -4); fair.add_child(wheel)
	for side in [-1.0, 1.0]:
		_box(wheel, "Leg%s" % ("L" if side < 0 else "R"), Vector3(side * 4.0, 5.0, 0), Vector3(0.7, 10.0, 0.7),
			_m("steel"), 0.0, false)
	_shape(wheel, "Hub", Vector3(0, 10.0, 0), CylinderMesh.new(), _m("steel"), Vector3(0.7, 0.5, 0.7),
		Vector3(0, 0, PI * 0.5))
	for i in 10:
		var a2 := i * TAU / 10.0
		var rim := Vector3(sin(a2) * 8.4, 10.0 + cos(a2) * 8.4, 0)
		_box(wheel, "Spoke%d" % (i + 1), rim * 0.5 + Vector3(0, 5.0, 0), Vector3(0.22, 8.6, 0.22), _m("steel"),
			0.0, false).rotation.z = -a2
		_box(wheel, "Car%d" % (i + 1), rim + Vector3(0, -0.9, 0), Vector3(1.7, 1.4, 1.5),
			_m(awnings[i % 3]), 0.0, false)

	# --- gulls, because the reference is full of them ------------------------------------------------------------
	var gulls := Node3D.new(); gulls.name = "Gulls"; root.add_child(gulls)
	for i in 7:
		var g := Node3D.new(); g.name = "Gull%d" % (i + 1)
		g.position = Vector3(rng.randf_range(132.0, 210.0), rng.randf_range(6.0, 16.0), rng.randf_range(238.0, 262.0))
		g.rotation.y = rng.randf_range(0.0, TAU)
		gulls.add_child(g)
		for side in [-1.0, 1.0]:
			_box(g, "Wing%s" % ("L" if side < 0 else "R"), Vector3(side * 0.5, 0, 0), Vector3(1.0, 0.07, 0.3),
				_m("cream"), 0.0, false).rotation.z = side * -0.35
		_box(g, "Body", Vector3.ZERO, Vector3(0.28, 0.2, 0.7), _m("cream"), 0.0, false)

	_marker(root, "ShoreTownCentre", Vector3(172, 1.0, DECK_Z), {"district": "The Old Shore"})
	_marker(root, "loc_shore_market", Vector3(165, 1.0, DECK_Z + 1.0), {"district": "The Old Shore"})

	for child in root.get_children():
		_own(child, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed"); quit(1); return
	var err := ResourceSaver.save(packed, OUT + "old_shore_detail.tscn", ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("save failed %d" % err); quit(1); return
	print("OLD SHORE built: ", _count(root), " nodes -> ", OUT + "old_shore_detail.tscn")
	quit()

func _marker(parent: Node3D, n: String, pos: Vector3, meta: Dictionary) -> void:
	var m := Node3D.new(); m.name = n; m.position = pos; parent.add_child(m)
	for k in meta:
		m.set_meta(k, meta[k])

func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)

func _count(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count(child)
	return c
