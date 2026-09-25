class_name Pet
extends CharacterBody3D
## A companion animal. The behaviour is ported from Rolling_Tides_2D/scripts_2d/pets/pet_ai.gd, which already
## had the shape this game needs: needs that drift, a bond held PER PLAYER rather than one global affection
## number, FOLLOW/STAY companion modes, and neglect that costs you.
##
## Per-player bonds matter more here than they did in 2D: with four-player co-op the dog has to be able to like
## the guest who keeps feeding it more than the owner who never does (docs/MULTIPLAYER_PLAN.md).
##
## Host-authoritative by design - decisions are made on one machine and the result replicated - but the network
## layer is not wired yet, so for now it simply runs locally.

signal petted(by_player_id: String, bond: float)
signal fed(by_player_id: String, bond: float)
signal mood_changed(mood: float)

## A rigged model (pets/*.glb) to use instead of the blockout spheres under `Art`. When this is set the blockout is
## thrown away at load and the model's own looping `idle` animation drives the pet, so the hand-written bob and tail
## wag below stand down. Breeds without a model yet keep the spheres and keep working exactly as before.
@export var model_scene: PackedScene = null
## The model's height to the ears, used to scale it onto this breed's `shoulder_height`. 0 leaves it at native size.
@export var model_native_height: float = 0.0

@export var breed_id: String = "husky"
@export var display_name: String = "Husky"
@export var species: String = "dog"          # dog | cat
@export var shoulder_height: float = 0.5
@export var pet_name: String = ""

@export_group("Companion")
@export var follow_speed: float = 3.4
@export var stop_distance: float = 1.6       # close enough; stop crowding them
@export var catch_up_distance: float = 9.0   # beyond this, hurry
@export var wander_radius: float = 4.5

var _anim: AnimationPlayer = null

const GRAVITY := 18.0
const DECISION_INTERVAL := 5.0
const NEGLECT_INTERVAL := 120.0              # real seconds before an ignored pet loses a little bond
const BOND_MAX := 100.0
## Cats keep their own counsel: they follow less eagerly and wander further.
const SPECIES_TEMPERAMENT := {
	"dog": {"follow_bias": 1.0, "wander_bias": 0.8, "pet_bond": 3.0},
	"cat": {"follow_bias": 0.55, "wander_bias": 1.35, "pet_bond": 2.0},
}

var energy: float = 100.0
var hunger: float = 100.0
var mood: float = 0.8
## player_id -> bond 0..100. A pet can prefer whichever player actually looks after it.
var bonds: Dictionary = {}
var preferred_player_id: String = ""
var companion_mode: String = "FOLLOW"        # FOLLOW | STAY
var stay_position: Vector3 = Vector3.ZERO
var state: String = "IDLE"                   # IDLE | FOLLOW | WANDER | SIT

var _owner_node: Node3D = null
var _decision_clock := 0.0
var _neglect_clock := 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO
var _bob := 0.0

func _ready() -> void:
	add_to_group("pet")
	add_to_group("interactable")
	_anchor = global_position
	stay_position = global_position
	if pet_name.is_empty():
		pet_name = display_name
	_wander_target = _pick_wander_target()
	_install_model()

func temperament() -> Dictionary:
	return SPECIES_TEMPERAMENT.get(species, SPECIES_TEMPERAMENT["dog"])

func set_owner_node(node: Node3D) -> void:
	_owner_node = node

## The player this pet currently trots after. With several players present it is whoever it likes most, which is
## what the per-player bond is for.
func _target_player() -> Node3D:
	var best: Node3D = null
	var best_bond := -1.0
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Node3D
		if p == null:
			continue
		var id := String(p.get("player_id")) if p.get("player_id") != null else "player"
		var bond: float = float(bonds.get(id, 25.0))
		if bond > best_bond:
			best_bond = bond
			best = p
	if best and best_bond >= 0.0:
		preferred_player_id = String(best.get("player_id")) if best.get("player_id") != null else "player"
	return best if best else _owner_node

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_tick_needs(delta)
	_decision_clock -= delta
	if _decision_clock <= 0.0:
		_decision_clock = DECISION_INTERVAL
		_decide()
	match state:
		"FOLLOW":
			_move_toward_target(delta)
		"WANDER":
			_wander(delta)
		_:
			velocity.x = move_toward(velocity.x, 0.0, follow_speed * 3.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, follow_speed * 3.0 * delta)
	move_and_slide()
	_animate(delta)

func _tick_needs(delta: float) -> void:
	hunger = maxf(0.0, hunger - delta * 0.35)
	energy = clampf(energy + (delta * 0.5 if state == "IDLE" or state == "SIT" else -delta * 0.6), 0.0, 100.0)
	var target_mood := clampf((hunger / 100.0) * 0.5 + (energy / 100.0) * 0.2 + _best_bond() / 100.0 * 0.3, 0.0, 1.0)
	if absf(target_mood - mood) > 0.01:
		mood = lerpf(mood, target_mood, delta * 0.5)
		mood_changed.emit(mood)
	# neglect: nobody has touched this animal in a long while
	_neglect_clock += delta
	if _neglect_clock >= NEGLECT_INTERVAL:
		_neglect_clock = 0.0
		for id in bonds:
			bonds[id] = maxf(0.0, float(bonds[id]) - 1.0)

func _decide() -> void:
	if companion_mode == "STAY":
		state = "SIT" if global_position.distance_to(stay_position) < stop_distance else "FOLLOW"
		return
	var target := _target_player()
	if target == null:
		state = "WANDER"
		return
	var distance := global_position.distance_to(target.global_position)
	var t := temperament()
	if distance > catch_up_distance:
		state = "FOLLOW"
	elif distance > stop_distance * 1.6:
		# a dog closes the gap; a cat often cannot be bothered
		state = "FOLLOW" if randf() < float(t["follow_bias"]) else "WANDER"
	else:
		state = "WANDER" if randf() < 0.35 * float(t["wander_bias"]) else "IDLE"
	if state == "WANDER":
		_wander_target = _pick_wander_target()

func _move_toward_target(delta: float) -> void:
	var target: Node3D = _owner_node if companion_mode == "STAY" else _target_player()
	var goal := stay_position if companion_mode == "STAY" else (target.global_position if target else _anchor)
	var to_goal := goal - global_position
	to_goal.y = 0.0
	if to_goal.length() < stop_distance:
		state = "IDLE"
		return
	var speed := follow_speed * (1.35 if to_goal.length() > catch_up_distance else 1.0)
	var dir := to_goal.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)

func _wander(delta: float) -> void:
	var to_goal := _wander_target - global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.5:
		state = "IDLE"
		return
	var dir := to_goal.normalized()
	velocity.x = dir.x * follow_speed * 0.45
	velocity.z = dir.z * follow_speed * 0.45
	_face(dir, delta)

func _pick_wander_target() -> Vector3:
	var base := stay_position if companion_mode == "STAY" else _anchor
	var target := _target_player()
	if target and companion_mode == "FOLLOW":
		base = target.global_position
	var a := randf() * TAU
	var r := randf_range(1.0, wander_radius * float(temperament()["wander_bias"]))
	return base + Vector3(sin(a) * r, 0.0, cos(a) * r)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-9.0 * delta))

## Swap the blockout for a rigged model. Called from _ready; does nothing when no model_scene is set.
func _install_model() -> void:
	if model_scene == null:
		return
	var old := get_node_or_null("Art")
	if old:
		old.name = "ArtBlockout"          # freeing is deferred, so rename first or the new node collides
		old.queue_free()
	var art := Node3D.new()
	art.name = "Art"
	add_child(art)
	var model: Node3D = model_scene.instantiate()
	art.add_child(model)
	if model_native_height > 0.0 and shoulder_height > 0.0:
		var k: float = shoulder_height / model_native_height
		art.scale = Vector3(k, k, k)
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		_anim = ap
		if ap.has_animation("idle"):
			ap.play("idle")
		break

## Blockout breeds have no skeleton: the body bobs with its own speed and the tail swings with mood, which is enough
## movement to read as alive at the distance a pet is usually seen from. A modelled breed plays its own idle instead,
## so all this does there is keep the body level.
func _animate(delta: float) -> void:
	if _anim != null:
		return
	var art := get_node_or_null("Art") as Node3D
	if art == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_bob += delta * (5.0 + speed * 2.2)
	art.position.y = sin(_bob) * 0.012 * (0.4 + speed * 0.5)
	art.rotation.z = sin(_bob * 0.5) * 0.02 * speed
	var tail := art.get_node_or_null("Tail") as Node3D
	if tail:
		var wag := 2.0 + mood * 6.0 + speed
		tail.rotation.y = sin(_bob * wag * 0.35) * (0.12 + mood * 0.35)

# ── interaction ───────────────────────────────────────────────────────────────
func get_prompt() -> String:
	return "Pet %s" % pet_name

func interact(user: Node) -> void:
	var id := "player"
	if user and user.get("player_id") != null:
		id = String(user.get("player_id"))
	pet_by(id)

func pet_by(player_id: String) -> float:
	var gain: float = float(temperament()["pet_bond"])
	var bond: float = minf(BOND_MAX, float(bonds.get(player_id, 25.0)) + gain)
	bonds[player_id] = bond
	_neglect_clock = 0.0
	mood = minf(1.0, mood + 0.08)
	petted.emit(player_id, bond)
	EventBus.fire("pet_petted", {"pet": pet_name, "breed": breed_id, "by": player_id, "bond": bond})
	return bond

func feed_by(player_id: String, nourishment: float = 35.0) -> float:
	hunger = minf(100.0, hunger + nourishment)
	var bond: float = minf(BOND_MAX, float(bonds.get(player_id, 25.0)) + 5.0)
	bonds[player_id] = bond
	_neglect_clock = 0.0
	fed.emit(player_id, bond)
	EventBus.fire("pet_fed", {"pet": pet_name, "breed": breed_id, "by": player_id, "bond": bond})
	return bond

func bond_with(player_id: String) -> float:
	return float(bonds.get(player_id, 25.0))

func _best_bond() -> float:
	var best := 0.0
	for id in bonds:
		best = maxf(best, float(bonds[id]))
	return best

func set_companion_mode(mode: String) -> void:
	companion_mode = mode
	if mode == "STAY":
		stay_position = global_position
	_decision_clock = 0.0

func to_dict() -> Dictionary:
	return {"breed": breed_id, "name": pet_name, "bonds": bonds.duplicate(), "hunger": hunger,
		"energy": energy, "mood": mood, "mode": companion_mode}

func from_dict(d: Dictionary) -> void:
	breed_id = String(d.get("breed", breed_id))
	pet_name = String(d.get("name", pet_name))
	bonds = (d.get("bonds", {}) as Dictionary).duplicate()
	hunger = float(d.get("hunger", hunger))
	energy = float(d.get("energy", energy))
	mood = float(d.get("mood", mood))
	companion_mode = String(d.get("mode", companion_mode))
