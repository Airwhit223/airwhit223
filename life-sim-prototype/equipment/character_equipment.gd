class_name CharacterEquipment
extends Node
## Attach as a child of any character (Player or NPCBrain) that also has a
## CharacterRig child named "Body". Keeps equipment DATA (`equipped`) and the
## VISUAL meshes it builds completely separate: equipping an item never touches
## simulation/NPC logic, only this node's bookkeeping and the rig it dresses.
##
## Two kinds of visuals:
## - Clothing (item.coverage non-empty): one inflated copy of each covered
##   body part, added next to that part on its joint, so it animates with the
##   limb (a hoodie's sleeves swing with the arms).
## - Socket items (hats, backpack, held tools...): one mesh on the slot socket.

var equipped: Dictionary = {} # slot name -> EquipmentItem
var _visuals: Dictionary = {} # slot name -> Array of MeshInstance3D currently shown

static var _stripe_textures: Dictionary = {}

const HAND_SLOTS := ["hand_l", "hand_r"]

## A held tool (sword, guitar...) is a hand item whose stats name a tool_type.
static func is_hand_tool(item: EquipmentItem) -> bool:
	return item != null and item.stats.has("tool_type") and item.slot_name() in HAND_SLOTS

func equip(item: EquipmentItem) -> void:
	if item == null:
		return
	var rig := get_rig()
	if rig == null:
		push_warning("CharacterEquipment: no CharacterRig named 'Body' on %s" % get_parent().name)
		return
	var slot: String = item.slot_name()
	unequip(slot)
	# Held tools are one-at-a-time: a sword and a guitar can't both be in hand. The exception is a matched pair —
	# an item naming the other in `pairs_with` — which is what makes dual-wielding possible without opening the
	# hands up to every combination.
	if is_hand_tool(item):
		var pairs := String(item.stats.get("pairs_with", ""))
		for other in HAND_SLOTS:
			if other == slot:
				continue
			var held := get_equipped(other)
			if is_hand_tool(held) and held.id != pairs:
				unequip(other)
	var material := _material_for(item)
	var shown: Array = []
	if not item.coverage.is_empty():
		for part_name in item.coverage:
			var part := rig.get_part(part_name)
			if part == null:
				push_warning("CharacterEquipment: rig has no part '%s' (item %s)" % [part_name, item.id])
				continue
			var layer := MeshInstance3D.new()
			layer.mesh = _inflated(part.mesh, item.inflate)
			layer.transform = part.transform
			layer.material_override = material
			part.get_parent().add_child(layer)
			shown.append(layer)
	else:
		var socket := rig.get_socket(slot)
		if socket == null:
			push_warning("CharacterEquipment: rig has no socket for slot '%s'" % slot)
			return
		if item.stats.get("visual", "") == "guitar":
			shown.append_array(_build_guitar_visual(socket, item, material))
		elif rig.model != null and not is_hand_tool(item):
			# A Toriyama model wears its own kit headwear; the old primitive hat/beanie is a flat cylinder that sits
			# inside the hair and pokes out through the face (the black patch on the nose bridge). The item stays
			# equipped (stats, saves); it just has no primitive mesh on these models.
			pass
		else:
			var attached := MeshInstance3D.new()
			attached.mesh = item.build_mesh()
			attached.material_override = material
			attached.position = item.local_offset
			attached.rotation_degrees = item.local_rotation_degrees
			socket.add_child(attached)
			shown.append(attached)
	equipped[slot] = item
	_visuals[slot] = shown

func unequip(slot: String) -> void:
	for node in _visuals.get(slot, []):
		if is_instance_valid(node):
			node.queue_free()
	_visuals.erase(slot)
	equipped.erase(slot)

func is_equipped(slot: String) -> bool:
	return equipped.has(slot)

func get_equipped(slot: String) -> EquipmentItem:
	return equipped.get(slot, null)

## Public lookup so world systems (basketball, skateboard) attach to the SAME
## sockets clothing uses instead of inventing their own offsets.
func get_socket(slot: String) -> Node3D:
	var rig := get_rig()
	return rig.get_socket(slot) if rig else null

func get_rig() -> CharacterRig:
	return get_parent().get_node_or_null("Body") as CharacterRig

func _build_guitar_visual(socket: Node3D, item: EquipmentItem, wood: StandardMaterial3D) -> Array:
	var root := Node3D.new()
	root.name = "AcousticGuitarVisual"
	root.position = item.local_offset
	root.rotation_degrees = item.local_rotation_degrees
	socket.add_child(root)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.055, 0.035)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.92, 0.7, 0.32)

	var lower := MeshInstance3D.new()
	var lower_mesh := SphereMesh.new()
	lower_mesh.radius = 0.21
	lower_mesh.height = 0.36
	lower.mesh = lower_mesh
	lower.scale = Vector3(0.9, 1.0, 0.24)
	lower.material_override = wood
	root.add_child(lower)
	var upper := MeshInstance3D.new()
	var upper_mesh := SphereMesh.new()
	upper_mesh.radius = 0.155
	upper_mesh.height = 0.28
	upper.mesh = upper_mesh
	upper.position.y = 0.21
	upper.scale = Vector3(0.86, 1.0, 0.24)
	upper.material_override = wood
	root.add_child(upper)

	var neck := MeshInstance3D.new()
	var neck_mesh := BoxMesh.new()
	neck_mesh.size = Vector3(0.075, 0.55, 0.045)
	neck.mesh = neck_mesh
	neck.position.y = 0.55
	neck.material_override = dark
	root.add_child(neck)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.115, 0.13, 0.055)
	head.mesh = head_mesh
	head.position.y = 0.88
	head.material_override = wood
	root.add_child(head)

	var sound_hole := MeshInstance3D.new()
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.055
	hole_mesh.bottom_radius = 0.055
	hole_mesh.height = 0.012
	sound_hole.mesh = hole_mesh
	sound_hole.position = Vector3(0, 0.08, -0.052)
	sound_hole.rotation_degrees.x = 90
	sound_hole.material_override = dark
	root.add_child(sound_hole)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.13, 0.025, 0.025)
	bridge.mesh = bridge_mesh
	bridge.position = Vector3(0, -0.1, -0.06)
	bridge.material_override = trim
	root.add_child(bridge)
	return [root]

static func _inflated(source: Mesh, amount: float) -> Mesh:
	if source is CapsuleMesh:
		var cap := source as CapsuleMesh
		var c := CapsuleMesh.new()
		c.radius = cap.radius + amount
		c.height = cap.height + amount * 2.0
		c.radial_segments = cap.radial_segments
		c.rings = cap.rings
		return c
	if source is SphereMesh:
		var sph := source as SphereMesh
		var s := SphereMesh.new()
		s.radius = sph.radius + amount
		s.height = sph.height + amount * 2.0
		s.radial_segments = sph.radial_segments
		s.rings = sph.rings
		return s
	if source is CylinderMesh:
		var cyl := source as CylinderMesh
		var y := CylinderMesh.new()
		y.top_radius = cyl.top_radius + amount
		y.bottom_radius = cyl.bottom_radius + amount
		y.height = cyl.height + amount * 2.0
		y.radial_segments = cyl.radial_segments
		return y
	if source is BoxMesh:
		var box := source as BoxMesh
		var b := BoxMesh.new()
		b.size = box.size + Vector3.ONE * amount * 2.0
		return b
	return source

static func _material_for(item: EquipmentItem) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if item.pattern == "stripes":
		mat.albedo_texture = _stripe_texture(item.color, item.accent_color)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = Vector3(1.0, 4.0, 1.0)
	else:
		mat.albedo_color = item.color
	return mat

static func _stripe_texture(a: Color, b: Color) -> Texture2D:
	var key := "%s|%s" % [a.to_html(), b.to_html()]
	if _stripe_textures.has(key):
		return _stripe_textures[key]
	var img := Image.create_empty(1, 4, false, Image.FORMAT_RGB8)
	for y in range(4):
		img.set_pixel(0, y, a if y < 2 else b)
	var tex := ImageTexture.create_from_image(img)
	_stripe_textures[key] = tex
	return tex
