class_name FlightController
extends Node
## TIER I — AWAKENED BODY: Flight / Supernatural Mobility (power bible §2, §15, §16).
##
## Flight is a UNIVERSAL physical ability, so it costs neither affinity slot and does not care which element the
## character carries. It reads and writes PowerSystem.profile.universal_mastery["flight"]: everything about how it
## flies - top speed, climb rate, ceiling, energy drain - is interpolated from that one number, so a character who
## has barely awakened wallows a few metres up and burns energy fast, while a mastered flier crosses a district.
##
## Mastery comes from USE, not from spending points (§16). Time in the air accrues practice; every PRACTICE_STEP
## seconds of flying grants a little mastery and fires an event the life-sim can hook (§24: flying practice).
##
## Controls: jump while already airborne to take off, hold jump to climb, release to descend, sprint to boost,
## interact to cut the power and drop. Descent is deliberately NOT bound to "dodge" - that action already drives
## the player's dodge roll, and sharing it made the character roll in mid-air instead of coming down.

signal flight_started()
signal flight_ended(reason: String)
signal mastery_gained(amount: float, total: float)
signal roof_warning(building_name: String, seconds_left: float)
signal roof_broken(building_name: String, damage: float)

const UNLOCK_MASTERY := 1.0        # below this the ability has not awakened at all
const ENTRY_COST := 5.0            # energy to get off the ground
const PRACTICE_STEP := 4.0         # seconds of flight per mastery tick
const PRACTICE_GAIN := 0.05
const MASTERY_CAP := 10.0
const DESCENT_RATE := 3.2          # metres a second when not climbing
## Climbing inside a building warns continuously while there is still roof above you. Nothing breaks until you
## actually pass through the roof plane, so a warned player who stops climbing pays nothing.
const STRUCTURE_HINTS := ["house", "home", "shop", "shack", "store", "dwelling", "hall", "tavern", "building",
	"cabin", "hut", "forge", "lighthouse", "pavilion", "temple"]

var active := false
var _practice := 0.0
var _player: CharacterBody3D = null
var _roof_target: Dictionary = {}
var _warned_for := ""

func setup(player: CharacterBody3D) -> void:
	_player = player

## Intent for the character this controller belongs to. Never `Input` - in co-op every peer runs this script, and
## polling the device here would launch every character on the machine at once (docs/MULTIPLAYER_PLAN.md).
func _input_source() -> InputSource:
	if _player and _player.get("input") != null:
		return _player.input
	return _FALLBACK

static var _FALLBACK := InputSource.new()

## Named _intent, not _input: Node._input(event) is a reserved virtual and overriding it with a different
## signature is a parse error.
func _intent() -> InputSource:
	return _input_source()

## Looked up through the tree rather than by the singleton name: a script compiled before the SceneTree exists
## (a -s tool or test script) cannot resolve autoload identifiers at compile time.
func _profile():
	var tree := get_tree()
	if tree == null:
		return null
	var system := tree.root.get_node_or_null("/root/PowerSystem")
	return system.profile if system else null

func mastery() -> float:
	var p = _profile()
	if p == null:
		return 0.0
	return float(p.universal_mastery.get("flight", 0.0))

func unlocked() -> bool:
	return mastery() >= UNLOCK_MASTERY

## 0 at the moment of awakening, 1 at full mastery. Every flight characteristic hangs off this.
func _t() -> float:
	return clampf((mastery() - UNLOCK_MASTERY) / (MASTERY_CAP - UNLOCK_MASTERY), 0.0, 1.0)

func top_speed() -> float:
	return lerpf(7.0, 26.0, _t())

func climb_rate() -> float:
	return lerpf(3.5, 9.0, _t())

func ceiling() -> float:
	return lerpf(14.0, 90.0, _t())

func drain_rate() -> float:
	return lerpf(9.0, 2.5, _t())      # control gets cheaper as the body learns it

func can_start() -> bool:
	var p = _profile()
	return unlocked() and p != null and p.energy > ENTRY_COST

## Called from the player's physics step. Returns true when flight is driving the character this frame, in which
## case the caller must not apply gravity or its own ground movement.
func update(delta: float, move_dir: Vector3, ground_y: float) -> bool:
	if _player == null:
		return false
	var p = _profile()
	if active and (p == null or p.energy <= 0.0):
		_stop("out of energy")
		return false
	if not active:
		# take off: a second jump while already off the ground
		if _intent().just_pressed(&"jump") and not _player.is_on_floor() and can_start():
			_start()
		else:
			return false
	# Touching down ends flight unless the pilot is still climbing - otherwise a descent that clips a rooftop
	# leaves the character hovering with the ability still burning energy.
	if _player.is_on_floor() and not _intent().pressed(&"jump"):
		_stop("landed")
		return false
	if _intent().just_pressed(&"interact"):
		_stop("cancelled")
		return false

	var speed := top_speed()
	if _intent().pressed(&"sprint"):
		speed *= 1.35
	_player.velocity.x = move_dir.x * speed
	_player.velocity.z = move_dir.z * speed

	var vertical := 0.0
	if _intent().pressed(&"jump"):
		vertical = climb_rate()
	else:
		vertical = -DESCENT_RATE   # letting go brings you down at a landable rate, not a hover
	# the ceiling is a soft one: climbing past it just stops working
	if _player.global_position.y - ground_y > ceiling() and vertical > 0.0:
		vertical = 0.0
	_player.velocity.y = vertical

	p.energy = maxf(0.0, p.energy - drain_rate() * delta)
	# Holding yourself in the air is exertion: it suppresses the passive recovery trickle, so flight actually
	# costs something. A fully mastered flier is the exception - by then staying up is second nature.
	p.exerting = mastery() < MASTERY_CAP
	_accrue_practice(delta)
	_check_roof(delta, vertical)

	return true

func _start() -> void:
	var p = _profile()
	if p:
		p.energy = maxf(0.0, p.energy - ENTRY_COST)
	active = true
	flight_started.emit()
	EventBus.fire("flight_started", {"mastery": mastery()})

func _stop(reason: String) -> void:
	if not active:
		return
	active = false
	var p = _profile()
	if p:
		p.exerting = false
	_roof_target = {}
	_warned_for = ""
	flight_ended.emit(reason)
	EventBus.fire("flight_ended", {"reason": reason, "mastery": mastery()})

## Mastery through use (§16). Flying is its own training, which is also what §24 means by "flying practice".
func _accrue_practice(delta: float) -> void:
	var p = _profile()
	if p == null:
		return
	_practice += delta
	if _practice < PRACTICE_STEP:
		return
	_practice -= PRACTICE_STEP
	var current := mastery()
	if current >= MASTERY_CAP:
		return
	var gained := minf(PRACTICE_GAIN, MASTERY_CAP - current)
	p.universal_mastery["flight"] = current + gained
	p.power_state_changed.emit()
	mastery_gained.emit(gained, current + gained)
	EventBus.fire("power_mastery_gained", {"ability": "flight", "amount": gained, "total": current + gained})


## --- roofs ---------------------------------------------------------------------------------------------------
## Flying up through somebody's roof breaks it, and the player is warned first.
##
## This works off building FOOTPRINTS, not collision. The buildings in this world have no roof colliders at all -
## the player house carries nine collision shapes and every one of them sits at ankle height - so a ray cast
## upward hits nothing and you sail through the roof with no contact to detect. Instead each structure's bounding
## box is measured from its meshes, and a flier climbing out through the top of a box they are standing inside is
## what counts as going through the roof.
const ROOF_SCAN_RADIUS := 60.0     # only structures near the player are worth testing each frame

var _structures: Array = []        # [{node, name, aabb}]
var _scanned := false

func _scan_structures() -> void:
	_scanned = true
	_structures.clear()
	# Scanned from the player's own scene root rather than get_tree().current_scene: a scene added to the tree
	# by hand (as a -s test harness does) never becomes current_scene, and the scan would silently find nothing.
	var top: Node = _player
	while top != null and top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	if top == null:
		return
	_collect_structures(top)
	EventBus.fire("flight_structures_scanned", {"count": _structures.size()})

func _collect_structures(node: Node) -> void:
	var lower := String(node.name).to_lower()
	for hint in STRUCTURE_HINTS:
		if lower.contains(hint):
			var box := _global_aabb(node)
			if box.size.y > 1.5 and box.size.x > 1.5:
				_structures.append({"node": node, "name": String(node.name), "aabb": box})
			return                 # do not descend into a structure we already recorded
	for child in node.get_children():
		_collect_structures(child)

func _global_aabb(node: Node) -> AABB:
	var box := AABB()
	var started := false
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var world := m.global_transform * m.mesh.get_aabb()
		if not started:
			box = world
			started = true
		else:
			box = box.merge(world)
	if not started and node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).mesh.get_aabb()
	return box

func _structure_under_climb() -> Dictionary:
	var pos := _player.global_position
	for entry in _structures:
		var box: AABB = entry["aabb"]
		if pos.x < box.position.x or pos.x > box.position.x + box.size.x:
			continue
		if pos.z < box.position.z or pos.z > box.position.z + box.size.z:
			continue
		var roof := box.position.y + box.size.y
		# inside the footprint and approaching the roof plane from below
		if pos.y > box.position.y - 0.5 and pos.y < roof + 0.4:
			return entry
	return {}

func _check_roof(_delta: float, vertical: float) -> void:
	if vertical <= 0.0:
		_roof_target = {}
		_warned_for = ""
		return
	if not _scanned:
		_scan_structures()
	var entry := _structure_under_climb()
	if not entry.is_empty():
		# Under a roof and climbing: warn, every frame, with the headroom left. This is the "before you do it"
		# part - the player can stop climbing and nothing is damaged.
		_roof_target = entry
		var label: String = entry["name"]
		var box: AABB = entry["aabb"]
		var headroom: float = (box.position.y + box.size.y) - _player.global_position.y
		if _warned_for != label:
			_warned_for = label
			EventBus.fire("roof_warning", {"building": label, "headroom": headroom})
		roof_warning.emit(label, headroom)
		return
	# Left the footprint band. If we were warned about a roof and we are now ABOVE it, we went through it -
	# that is the moment the roof breaks. Leaving sideways or dropping back down costs nothing.
	if _roof_target.is_empty():
		_warned_for = ""
		return
	var target: Dictionary = _roof_target
	var t_box: AABB = target["aabb"]
	var roof_y: float = t_box.position.y + t_box.size.y
	var pos := _player.global_position
	var inside_xz := pos.x >= t_box.position.x and pos.x <= t_box.position.x + t_box.size.x \
		and pos.z >= t_box.position.z and pos.z <= t_box.position.z + t_box.size.z
	if inside_xz and pos.y > roof_y:
		_break_roof(target["node"], String(target["name"]))
	_roof_target = {}
	_warned_for = ""


func _break_roof(structure: Node, label: String) -> void:
	_roof_target = {}
	_warned_for = ""
	var id := String(structure.get_path()) if structure is Node else label
	var damage: float = BuildingDamage.ROOF_STRIKE_DAMAGE
	BuildingDamage.report_damage(id, damage, label)
	roof_broken.emit(label, damage)
