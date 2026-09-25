class_name EquipmentItem
extends Resource
## A piece of equipment/clothing as pure DATA — no mesh node lives here.
## CharacterEquipment reads this to build (or discard) the actual visual
## when something is equipped/unequipped; the item itself never changes.
## Stored/looked-up by stable string `id`, never by mesh reference, so this
## is already save-friendly: persisting a character's outfit later is just
## persisting a handful of id strings per slot.

enum Slot { HEAD, HAIR, TOP, BOTTOM, SHOES, ACCESSORY, BACK, HAND_L, HAND_R, HIP }
enum Shape { BOX, SPHERE, CYLINDER }

const SLOT_NAMES := {
	Slot.HEAD: "head", Slot.HAIR: "hair", Slot.TOP: "top", Slot.BOTTOM: "bottom",
	Slot.SHOES: "shoes", Slot.ACCESSORY: "accessory", Slot.BACK: "back",
	Slot.HAND_L: "hand_l", Slot.HAND_R: "hand_r", Slot.HIP: "hip",
}

@export var id: String = ""
@export var display_name: String = ""
@export var slot: Slot = Slot.TOP
@export var color: Color = Color.WHITE

## CLOTHING: names of CharacterRig body parts this item wraps ("torso",
## "upper_arm_l", "foot_r"...). When non-empty the item is built as a slightly
## inflated copy of each covered part, riding that part's joint so it animates
## with the limb. When empty, the item is one mesh attached at its slot socket.
@export var coverage: Array[String] = []
@export var inflate: float = 0.02
## "" = solid color, "stripes" = alternating `color` / `accent_color` bands.
@export var pattern: String = ""
@export var accent_color: Color = Color.WHITE

## SOCKET ITEMS (hats, necklace, backpack, held tools...): placeholder geometry
## plus fine-tuning relative to the slot socket.
@export var shape: Shape = Shape.BOX
@export var size: Vector3 = Vector3(1, 1, 1)
@export var local_offset: Vector3 = Vector3.ZERO
@export var local_rotation_degrees: Vector3 = Vector3.ZERO

## Not used by anything yet — reserved so a future armor/buff pass has
## somewhere to put "warmth", "defense", etc. without changing this schema.
@export var stats: Dictionary = {}

func slot_name() -> String:
	return SLOT_NAMES[slot]

func build_mesh() -> Mesh:
	match shape:
		Shape.SPHERE:
			var m := SphereMesh.new()
			m.radius = size.x * 0.5
			m.height = size.y
			return m
		Shape.CYLINDER:
			var c := CylinderMesh.new()
			c.top_radius = size.x * 0.5
			c.bottom_radius = size.x * 0.5
			c.height = size.y
			return c
		_:
			var b := BoxMesh.new()
			b.size = size
			return b
