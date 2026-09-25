class_name Dungeon
extends Node3D
## A handcrafted dungeon for Adventure Contracts, built from a LAYOUT (floor, inner walls, torches, spawn spots) and
## sitting in the interiors layer behind an overworld entrance. It stays empty and quiet until a contract that names
## it is accepted, then populate() places that contract's enemies (RuinEnemy kinds) and loot chests on its spots.
## The whole footprint is a DangerZone with the dungeon's id, so entering it is the contract's "reach" objective and
## enemies only fight inside. Placeholder visuals: stone blocks and torch lights.

const LAYOUTS := {
	"old_crypt": {
		"name": "The Old Crypt", "size": Vector2(20, 16), "floor": Color(0.3, 0.29, 0.27), "wall": Color(0.36, 0.34, 0.31),
		"entry": Vector3(0, 0, 6.2),
		"walls": [[Vector3(-6, 0, 1), Vector3(8, 3, 0.6)], [Vector3(6, 0, 1), Vector3(8, 3, 0.6)]],
		"decor": [[Vector3(-6, 0, -4), Vector3(1.2, 0.8, 2.4)], [Vector3(-2, 0, -4), Vector3(1.2, 0.8, 2.4)],
			[Vector3(2, 0, -4), Vector3(1.2, 0.8, 2.4)], [Vector3(-8, 0, 4.5), Vector3(1.5, 1.4, 1.5)]],
		"torches": [Vector3(-8, 2, 6), Vector3(8, 2, 6), Vector3(-8, 2, -6), Vector3(8, 2, -6), Vector3(0, 2, -2)],
		"enemy_spots": [Vector3(-5, 0, -1.5), Vector3(4, 0, -2.5), Vector3(0, 0, -6.2), Vector3(6, 0, 4)],
		"loot_spots": [Vector3(7.8, 0, -6.4), Vector3(-8.2, 0, -6.4)],
	},
	"smuggler_cellar": {
		"name": "The Smugglers' Cellar", "size": Vector2(28, 20), "floor": Color(0.33, 0.27, 0.22), "wall": Color(0.3, 0.28, 0.27),
		"entry": Vector3(0, 0, 8.2),
		# cellar (south) -> gap on the west -> catacombs (north-west) -> gap -> the thugs' back room (north-east)
		"walls": [[Vector3(-12, 0, 1), Vector3(4, 3, 0.6)], [Vector3(4, 0, 1), Vector3(20, 3, 0.6)],
			[Vector3(4, 0, -0.5), Vector3(0.6, 3, 3)], [Vector3(4, 0, -7.5), Vector3(0.6, 3, 5)]],
		"decor": [[Vector3(-11, 0, 7.5), Vector3(2, 1.2, 1.4)], [Vector3(-8.5, 0, 8), Vector3(1.2, 0.9, 1.2)],
			[Vector3(11, 0, 8), Vector3(2.4, 1.4, 1.4)], [Vector3(-6, 0, -8), Vector3(1.2, 0.8, 2.4)],
			[Vector3(-1, 0, -8), Vector3(1.2, 0.8, 2.4)], [Vector3(9, 0, -4), Vector3(2.2, 0.8, 1.2)]],
		"torches": [Vector3(-10, 2, 8), Vector3(10, 2, 8), Vector3(-10, 2, -4), Vector3(-2, 2, -8), Vector3(9, 2, -2),
			Vector3(9, 2, -8)],
		"enemy_spots": [Vector3(-8, 0, 4.5), Vector3(7, 0, 4.5), Vector3(2, 0, 3.8),    # goblins in the cellar
			Vector3(8, 0, -6), Vector3(11, 0, -3),                                        # thugs in the back room
			Vector3(-8, 0, -4), Vector3(-3, 0, -6)],                                      # skeletons in the catacombs
		"loot_spots": [Vector3(11.5, 0, 5.5), Vector3(-12, 0, -8), Vector3(12, 0, -8.5), Vector3(9, 0, -2.4)],
	},
}

var dungeon_id := "old_crypt"
var contract_id := ""                    # the contract it's populated for, "" = empty
var _spawned: Array[Node] = []

func _init(id := "old_crypt") -> void:
	dungeon_id = id

func _ready() -> void:
	name = "Dungeon_" + dungeon_id
	_build()
	QuestManager.quest_started.connect(_on_quest_started)

func layout() -> Dictionary:
	return LAYOUTS[dungeon_id]

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var n := StaticBody3D.new()
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; m.mesh = b; m.position.y = size.y / 2
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; m.material_override = mat
	n.add_child(m)
	var c := CollisionShape3D.new(); var s := BoxShape3D.new(); s.size = size; c.shape = s; c.position.y = size.y / 2
	n.add_child(c)
	n.position = pos
	add_child(n)

func _build() -> void:
	var L := layout()
	var sz: Vector2 = L["size"]
	_box(Vector3(0, -0.2, 0), Vector3(sz.x, 0.2, sz.y), L["floor"])
	var h := 3.0
	for w in [[Vector3(0, 0, -sz.y / 2), Vector3(sz.x, h, 0.6)], [Vector3(0, 0, sz.y / 2), Vector3(sz.x, h, 0.6)],
			[Vector3(-sz.x / 2, 0, 0), Vector3(0.6, h, sz.y)], [Vector3(sz.x / 2, 0, 0), Vector3(0.6, h, sz.y)]]:
		_box(w[0], w[1], L["wall"])
	for w in L["walls"]:
		_box(w[0], w[1], L["wall"])
	for d in L["decor"]:
		_box(d[0], d[1], L["wall"].darkened(0.2))
	for t in L["torches"]:
		var light := OmniLight3D.new(); light.position = t; light.omni_range = 9.0; light.light_energy = 1.4
		light.light_color = Color(1.0, 0.72, 0.42)
		add_child(light)
		var flame := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; flame.mesh = sm
		var fm := StandardMaterial3D.new(); fm.albedo_color = Color(1, 0.6, 0.2); fm.emission_enabled = true
		fm.emission = Color(1, 0.55, 0.15); fm.emission_energy_multiplier = 3.0; flame.material_override = fm
		flame.position = t
		add_child(flame)
	# the whole footprint is dangerous; entering it is the "reach" objective
	var zone := DangerZone.new()
	zone.name = "DungeonZone"
	zone.zone_id = dungeon_id
	var zc := CollisionShape3D.new(); var zb := BoxShape3D.new(); zb.size = Vector3(sz.x - 1.0, 3.0, sz.y - 1.0)
	zc.shape = zb; zc.position.y = 1.5
	zone.add_child(zc)
	add_child(zone)
	var entry := Marker3D.new(); entry.name = "DungeonEntry"; entry.position = L["entry"] + Vector3(0, 0.1, -1.2)
	add_child(entry)
	var sign := Label3D.new(); sign.text = String(L["name"]).to_upper(); sign.font_size = 64; sign.pixel_size = 0.006
	sign.outline_size = 10; sign.position = L["entry"] + Vector3(0, 2.6, 0.2); sign.rotation.y = PI
	add_child(sign)

## Exit door back to the overworld (main.gd passes the marker outside the entrance).
func add_exit(outside: Node3D) -> void:
	var exit := Teleporter.new()
	exit.name = "DungeonExit"
	exit.prompt_text = "Leave %s" % layout()["name"]
	exit.collision_layer = 8
	exit.collision_mask = 0
	var ec := CollisionShape3D.new(); var es := BoxShape3D.new(); es.size = Vector3(1.6, 2.2, 1.2); ec.shape = es; ec.position.y = 1.1
	exit.add_child(ec)
	var el := Label3D.new(); el.text = "Exit"; el.font_size = 36; el.pixel_size = 0.004; el.position.y = 2.2
	el.billboard = BaseMaterial3D.BILLBOARD_ENABLED; el.outline_size = 8
	exit.add_child(el)
	add_child(exit)
	exit.position = layout()["entry"] + Vector3(0, 0, 0.6)
	exit.destination = exit.get_path_to(outside)

func _on_quest_started(quest_id: String) -> void:
	for c in ContractCatalog.all():
		if ContractCatalog.quest_id(c["id"]) == quest_id and c["dungeon"] == dungeon_id:
			populate(c)

## Place a contract's enemies and loot on this dungeon's spots (clears whatever was there).
func populate(c: Dictionary) -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	contract_id = c["id"]
	var L := layout()
	var spots: Array = L["enemy_spots"]
	var i := 0
	for group in c["spawn"].get("enemies", []):
		for k in int(group[1]):
			if i >= spots.size():
				break
			var e := RuinEnemy.new()
			e.kind = group[0]
			e.zone = dungeon_id
			e.enemy_id = "%s_%s_%d" % [dungeon_id, group[0], i]
			e.position = spots[i]
			add_child(e)
			_spawned.append(e)
			i += 1
	var loot_spots: Array = L["loot_spots"]
	var j := 0
	for loot in c["spawn"].get("loot", []):
		if j >= loot_spots.size():
			break
		var chest := LootChest.new()
		chest.item_id = loot[0]
		chest.count = int(loot[1])
		chest.position = loot_spots[j]
		add_child(chest)
		_spawned.append(chest)
		j += 1

func enemies() -> Array:
	return _spawned.filter(func(n): return is_instance_valid(n) and n is RuinEnemy and not n.is_queued_for_deletion())

func chests() -> Array:
	return _spawned.filter(func(n): return is_instance_valid(n) and n is LootChest)
