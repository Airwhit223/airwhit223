class_name CharacterRig
extends Node3D
## Shared low-poly humanoid used by the player AND every NPC: rounded
## primitive body parts on a joint hierarchy, animated procedurally in code
## (no imported model or AnimationPlayer). Everything that attaches to a
## character — clothing, hats, held items, the skateboard, the basketball —
## goes through this rig's named parts and sockets, never raw coordinates on
## the character scene.
##
## Proportions are authored for a 1.8m player with feet at y=0; NPC scenes
## scale the whole Body node, so sockets and clothing stay correct for both.
## Facing is -Z. The character's LEFT is -X.
##
## Built in _init (not _ready) so parts/sockets exist immediately after
## instantiate() — NPCBrain.setup() applies skin tone before add_child().

## How a character carries themselves: the same procedural walk with different weights. Chosen in the character
## creator ("movement" in a recipe) and settable on any NPC.
##   stride      leg swing         arm         arm swing       sway   hips side-to-side
##   bob         vertical bounce   lean        torso pitch (+ forward)
##   twist       shoulder counter-rotation     elbow  resting elbow bend
##   arm_out     how far the arms hang from the body   idle_amp  breathing/shifting when still
const MOVEMENT_STYLES := {
	"neutral":   {"stride": 1.0, "arm": 1.0, "sway": 1.0, "bob": 1.0, "lean": 0.0, "twist": 1.0, "elbow": 1.0, "arm_out": 1.0, "idle_amp": 1.0, "speed": 1.0},
	"masculine": {"stride": 1.05, "arm": 1.15, "sway": 0.55, "bob": 1.0, "lean": 0.02, "twist": 1.2, "elbow": 1.15, "arm_out": 1.6, "idle_amp": 0.8, "speed": 0.98},
	"feminine":  {"stride": 0.92, "arm": 0.8, "sway": 1.9, "bob": 0.85, "lean": -0.02, "twist": 0.8, "elbow": 1.25, "arm_out": 0.45, "idle_amp": 1.15, "speed": 1.04},
	"eager":     {"stride": 1.1, "arm": 1.35, "sway": 1.1, "bob": 1.5, "lean": 0.06, "twist": 1.1, "elbow": 1.3, "arm_out": 1.0, "idle_amp": 1.8, "speed": 1.12},
	"athletic":  {"stride": 1.15, "arm": 1.1, "sway": 0.8, "bob": 0.8, "lean": 0.05, "twist": 1.15, "elbow": 1.5, "arm_out": 0.9, "idle_amp": 0.7, "speed": 1.08},
	"shy":       {"stride": 0.8, "arm": 0.55, "sway": 0.9, "bob": 0.7, "lean": 0.09, "twist": 0.7, "elbow": 1.7, "arm_out": 0.3, "idle_amp": 0.6, "speed": 0.92},
}

## Distinct ground-up locomotion profiles with true heel-to-toe foot roll,
## knee weight acceptance cushion, 3D pelvis dynamics, shoulder twist, and relaxed arm arcs.
const LOCOMOTION_PROFILES := {
	"hero_walk": {
		"stride_fwd": 0.48, "stride_back": -0.38,
		"knee_cushion": -0.16, "knee_extension": -0.05, "knee_swing": -0.92,
		"ankle_strike": 0.30, "ankle_push": -0.46, "ankle_clear": 0.06,
		"arm_fwd": 0.52, "arm_back": -0.36, "elbow_rest": 0.34, "elbow_swing": 0.52, "arm_out": 0.045,
		"pelvis_yaw": 0.07, "pelvis_roll": 0.035, "sway": 0.016,
		"shoulder_twist": 0.12, "torso_lean": 0.055, "head_stabilize": 0.8,
		"bob_amp": 0.024, "cadence": 1.0, "speed_ref": 4.5, "idle_amp": 0.9,
	},
	"neutral_walk": {
		"stride_fwd": 0.38, "stride_back": -0.30,
		"knee_cushion": -0.12, "knee_extension": -0.04, "knee_swing": -0.78,
		"ankle_strike": 0.22, "ankle_push": -0.34, "ankle_clear": 0.05,
		"arm_fwd": 0.38, "arm_back": -0.26, "elbow_rest": 0.30, "elbow_swing": 0.46, "arm_out": 0.040,
		"pelvis_yaw": 0.045, "pelvis_roll": 0.025, "sway": 0.014,
		"shoulder_twist": 0.08, "torso_lean": 0.02, "head_stabilize": 0.75,
		"bob_amp": 0.016, "cadence": 1.0, "speed_ref": 4.2, "idle_amp": 1.0,
	},
	"relaxed_walk": {
		"stride_fwd": 0.32, "stride_back": -0.25,
		"knee_cushion": -0.10, "knee_extension": -0.03, "knee_swing": -0.68,
		"ankle_strike": 0.18, "ankle_push": -0.25, "ankle_clear": 0.04,
		"arm_fwd": 0.28, "arm_back": -0.18, "elbow_rest": 0.26, "elbow_swing": 0.38, "arm_out": 0.035,
		"pelvis_yaw": 0.035, "pelvis_roll": 0.035, "sway": 0.020,
		"shoulder_twist": 0.05, "torso_lean": -0.005, "head_stabilize": 0.7,
		"bob_amp": 0.012, "cadence": 0.92, "speed_ref": 3.8, "idle_amp": 0.7,
	},
	"feminine_walk": {
		"stride_fwd": 0.34, "stride_back": -0.27,
		"knee_cushion": -0.11, "knee_extension": -0.03, "knee_swing": -0.74,
		"ankle_strike": 0.24, "ankle_push": -0.32, "ankle_clear": 0.05,
		"arm_fwd": 0.26, "arm_back": -0.17, "elbow_rest": 0.34, "elbow_swing": 0.48, "arm_out": 0.028,
		"pelvis_yaw": 0.075, "pelvis_roll": 0.055, "sway": 0.026,
		"shoulder_twist": 0.10, "torso_lean": 0.0, "head_stabilize": 0.85,
		"bob_amp": 0.016, "cadence": 1.06, "speed_ref": 4.0, "idle_amp": 1.15,
		"stance": -0.012,                 # feet track close to the centre line, one almost in front of the other
	},
	"jog": {
		"stride_fwd": 0.58, "stride_back": -0.44,
		"knee_cushion": -0.22, "knee_extension": -0.06, "knee_swing": -1.18,
		"ankle_strike": 0.20, "ankle_push": -0.52, "ankle_clear": 0.08,
		"arm_fwd": 0.65, "arm_back": -0.48, "elbow_rest": 1.00, "elbow_swing": 1.18, "arm_out": 0.055,
		"pelvis_yaw": 0.08, "pelvis_roll": 0.028, "sway": 0.012,
		"shoulder_twist": 0.15, "torso_lean": 0.09, "head_stabilize": 0.85,
		"bob_amp": 0.042, "cadence": 1.15, "speed_ref": 6.5, "idle_amp": 1.2,
	},
	"adventure_run": {
		"stride_fwd": 0.70, "stride_back": -0.55,
		"knee_cushion": -0.28, "knee_extension": -0.08, "knee_swing": -1.35,
		"ankle_strike": 0.16, "ankle_push": -0.62, "ankle_clear": 0.10,
		"arm_fwd": 0.92, "arm_back": -0.70, "elbow_rest": 1.38, "elbow_swing": 1.52, "arm_out": 0.11,
		"pelvis_yaw": 0.10, "pelvis_roll": 0.022, "sway": 0.010,
		"shoulder_twist": 0.18, "torso_lean": 0.20, "head_stabilize": 0.9,
		"bob_amp": 0.072, "cadence": 1.30, "speed_ref": 8.5, "idle_amp": 1.0,
	},
	"legacy_walk": {
		"is_legacy": true, "speed": 1.0, "stride": 1.0, "arm": 1.0, "sway": 1.0, "bob": 1.0, "lean": 0.0, "twist": 1.0, "elbow": 1.0, "arm_out": 1.0, "idle_amp": 1.0
	}
}

const WALK_REFERENCE_SPEED := 4.5
const STRIDE_RADIANS_PER_METER := 2.8
const POSE_EASE_RATE := 14.0
const TORSO_BASE_Y := 0.94
## Neutral forearm twist. The rig shipped with 1.25, which rotates the palm to face FORWARD - the "hands held
## out" look. A relaxed arm carries its palm toward the thigh.
const WRIST_NEUTRAL := 0.35
const LAND_CUSHION_TIME := 0.26      # how long the knees keep absorbing after touchdown
const JUMP_SPEED_REF := 6.0          # vertical speed that reads as a full launch or a full fall
const SIT_DROP := 0.40               # how far the torso sinks when sitting
const SWIM_PITCH := -1.45            # hip pitch that lays the whole body out prone
const SWIM_CHEST_LIFT := 0.42        # chest arched back up from the hips, so the head rides above the water

var _parts: Dictionary = {}   # part name -> MeshInstance3D (clothing coverage uses these names)
var _pivots: Dictionary = {}  # joint name -> Node3D
var _sockets: Dictionary = {} # equipment slot name -> Node3D

var _skin_material := StandardMaterial3D.new()
var _eye_material := StandardMaterial3D.new()
var _mouth_material := StandardMaterial3D.new()

## Opt-in Toriyama / DQ8 model (res://character/toriyama/<name>/). Empty keeps the primitive body. The primitive
## parts are kept (hidden) so part-based equipment coverage still resolves; sockets follow the model's bones.
@export var toriyama_character := ""
## Custom character built from kit parts (the character creator). Takes precedence over `toriyama_character`.
var toriyama_recipe: Dictionary = {}
var model: ToriyamaCharacter = null
var _sockets_oriented := false
var _growth_connected := false

## Movement style name (a key of MOVEMENT_STYLES or LOCOMOTION_PROFILES); set from player recipe or NPC definition.
var movement_style := "hero_walk":
	set(value):
		movement_style = value
		if MOVEMENT_STYLES.has(value):
			_style = MOVEMENT_STYLES[value]
		else:
			_style = MOVEMENT_STYLES["neutral"]
var _style: Dictionary = MOVEMENT_STYLES["neutral"]

var _phase := 0.0
var _move := 0.0
var _time := 0.0
var _air := 0.0            # seconds since leaving the floor; 0 while standing
var _land := 0.0           # landing cushion, 1 at touchdown and decaying
var _stroke := 0.0         # swim stroke phase, its own clock so it runs while treading water
## Sword states read this: 0 rests in guard, 0 -> 1 drives one cut. The player advances it over the swing time;
## `swing_side` picks which hand leads a dual-wield cut. Kept as state rather than an animate() argument so that
## every existing caller, and every NPC, is unaffected.
var swing: float = 0.0
var swing_side: int = 1

func _init() -> void:
	_skin_material.albedo_color = Color(0.85, 0.68, 0.55)
	_eye_material.albedo_color = Color(0.05, 0.05, 0.05)
	_mouth_material.albedo_color = Color(0.4, 0.18, 0.18)
	_build()

func _ready() -> void:
	if not toriyama_recipe.is_empty():
		_attach_kit(toriyama_recipe)
	elif toriyama_character != "":
		_attach_toriyama(toriyama_character)

## Build the character from kit parts instead of a baked export (custom player, creator preview).
func set_toriyama_recipe(new_recipe: Dictionary) -> void:
	var held := _detach_model()
	toriyama_recipe = new_recipe.duplicate(true)
	toriyama_character = ""
	movement_style = String(new_recipe.get("movement", movement_style))
	_attach_kit(toriyama_recipe)
	_reattach_held(held)

func _attach_kit(new_recipe: Dictionary) -> void:
	var kit := ToriyamaKitCharacter.new()
	model = kit
	model.name = "Toriyama"
	add_child(model)
	model.visible = false
	kit.apply_recipe(new_recipe)
	_finish_attach()

func _attach_toriyama(character: String) -> void:
	model = ToriyamaCharacter.new()
	model.name = "Toriyama"
	add_child(model)
	model.visible = false   # shown after its first pose sync, so a new model never flashes its bind pose
	model.setup(character)
	_finish_attach()

func _finish_attach() -> void:
	_hide_primitive_meshes()
	var sockets := model.make_sockets(self)
	for slot in sockets:
		_sockets[slot] = sockets[slot]
	model.sync_from_rig(self, _pivots, TORSO_BASE_Y)
	var clock := get_node_or_null("/root/TimeManager")
	if clock and clock.has_signal("day_changed"):
		if not _growth_connected:
			clock.day_changed.connect(_on_day_for_hair_growth)
			_growth_connected = true
		model.update_growth(float(clock.day_index))

func _on_day_for_hair_growth(day_index: int, _dow: int) -> void:
	if model:
		model.update_growth(float(day_index))

## Swap the Toriyama model at runtime (player look presets now, the character creator later). Anything held on a
## socket (skateboard on the back, ball, accessories) moves to the new model's matching socket.
func set_toriyama_character(character: String) -> void:
	if character == toriyama_character and model:
		return
	var held := _detach_model()
	toriyama_character = character
	toriyama_recipe = {}
	if character != "":
		_attach_toriyama(character)
	_reattach_held(held)

## Take the current model off, keeping whatever hangs on the sockets (skateboard, held items).
func _detach_model() -> Dictionary:
	var held := {}
	for slot in _sockets:
		var socket: Node3D = _sockets[slot]
		held[slot] = socket.get_children()
		for child in held[slot]:
			socket.remove_child(child)
	var old := model
	model = null
	if old:
		remove_child(old)
		old.queue_free()
	_sockets_oriented = false
	return held

func _reattach_held(held: Dictionary) -> void:
	for slot in held:
		var target: Node3D = _sockets.get(slot, null)
		for child in held[slot]:
			if target:
				target.add_child(child)
			else:
				child.queue_free()

var _transformation_model_instance: Node3D = null

## Swaps the character's body mesh with a dedicated full-body transformation model (e.g. Wolf Beast, Dragon Drake).
func swap_transformation_model(glb_path: String) -> Node3D:
	if is_instance_valid(_transformation_model_instance):
		restore_base_model()

	if model:
		model.visible = false
	_hide_primitive_meshes()

	if not glb_path.begins_with("res://"):
		if not glb_path.ends_with(".glb"):
			glb_path = "res://character/transformations/" + glb_path + "_full.glb"
		else:
			glb_path = "res://character/transformations/" + glb_path

	if ResourceLoader.exists(glb_path):
		var scene: PackedScene = load(glb_path)
		if scene:
			_transformation_model_instance = scene.instantiate()
			_transformation_model_instance.name = "TransformationModel"
			_transformation_model_instance.rotation_degrees.y = 180.0
			add_child(_transformation_model_instance)

	return _transformation_model_instance

## Restores the character's customized base model after a transformation ends.
func restore_base_model() -> void:
	if is_instance_valid(_transformation_model_instance):
		if _transformation_model_instance.get_parent():
			_transformation_model_instance.get_parent().remove_child(_transformation_model_instance)
		_transformation_model_instance.queue_free()
		_transformation_model_instance = null

	if model:
		model.visible = true

## Primitive body parts, face details and part-coverage clothing layers (added as pivot children by
## CharacterEquipment) are replaced by the model's own body and outfit.
func _hide_primitive_meshes() -> void:
	for pivot in _pivots.values():
		for child in (pivot as Node3D).get_children():
			if child is MeshInstance3D and child.visible:
				child.visible = false

## --- Public API -----------------------------------------------------------

func set_skin_tone(color: Color) -> void:
	_skin_material.albedo_color = color

func get_part(part_name: String) -> MeshInstance3D:
	return _parts.get(part_name, null)

## Re-make the bone sockets after the model rebuilt itself (switching body type swaps the base mesh).
func refresh_sockets() -> void:
	if model == null:
		return
	var held := {}
	for slot in _sockets:
		var socket: Node3D = _sockets[slot]
		if is_instance_valid(socket) and socket.get_parent() != null:
			held[slot] = socket.get_children()
			for child in held[slot]:
				socket.remove_child(child)
	var made := model.make_sockets(self)
	for slot in made:
		_sockets[slot] = made[slot]
	for slot in held:
		var target: Node3D = _sockets.get(slot, null)
		if target:
			for child in held[slot]:
				target.add_child(child)
	_sockets_oriented = false

func get_socket(slot: String) -> Node3D:
	return _sockets.get(slot, null)

## Two-handed hold: the ball sits between the hands (the "hold" pose brings
## both hands in front of the chest).
func ball_hold_position() -> Vector3:
	var l: Node3D = _sockets["hand_l"]
	var r: Node3D = _sockets["hand_r"]
	return (l.global_position + r.global_position) * 0.5

func _get_active_profile() -> Dictionary:
	if LOCOMOTION_PROFILES.has(movement_style):
		return LOCOMOTION_PROFILES[movement_style]
	match movement_style:
		"masculine", "hero":
			return LOCOMOTION_PROFILES["hero_walk"]
		"neutral":
			return LOCOMOTION_PROFILES["neutral_walk"]
		"feminine":
			return LOCOMOTION_PROFILES["feminine_walk"]
		"shy", "relaxed":
			return LOCOMOTION_PROFILES["relaxed_walk"]
		"eager":
			return LOCOMOTION_PROFILES["jog"]
		"athletic":
			return LOCOMOTION_PROFILES["adventure_run"]
		"legacy", "legacy_walk":
			return LOCOMOTION_PROFILES["legacy_walk"]
		_:
			return LOCOMOTION_PROFILES["hero_walk"]

## Walk -> jog -> run is one continuous gait, not three clips: at speed the profile is blended toward jog and then
## toward the run, so a sprint lengthens the stride, drives the knees higher and leans the torso in without ever
## snapping between poses. Keys the faster profile does not define (a walk's `stance`, say) are carried through.
static func _blend_profiles(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := a.duplicate()
	for key in b:
		var bv = b[key]
		if not (bv is float or bv is int):
			continue
		var av = a.get(key, bv)
		if not (av is float or av is int):
			continue
		out[key] = lerpf(float(av), float(bv), t)
	return out


func _gait_profile(base: Dictionary, speed: float) -> Dictionary:
	if base.get("is_legacy", false):
		return base
	var walk_ref := float(base.get("speed_ref", WALK_REFERENCE_SPEED))
	if speed <= walk_ref:
		return base
	var jog: Dictionary = LOCOMOTION_PROFILES["jog"]
	var run: Dictionary = LOCOMOTION_PROFILES["adventure_run"]
	var jog_ref := float(jog["speed_ref"])
	var run_ref := float(run["speed_ref"])
	if speed <= jog_ref:
		return _blend_profiles(base, jog, clampf((speed - walk_ref) / maxf(jog_ref - walk_ref, 0.01), 0.0, 1.0))
	return _blend_profiles(jog, run, clampf((speed - jog_ref) / maxf(run_ref - jog_ref, 0.01), 0.0, 1.0))


## Non-linear, biomechanically grounded gait cycle sample for a single leg.
## u: normalized cycle phase [0.0, 1.0)
## 0.0 -> 0.50: Stance (heel strike -> loading response -> mid-stance roll -> push-off)
## 0.50 -> 1.00: Swing (initial lift -> high knee clearance -> terminal reach)
static func _sample_leg_gait(u: float, prof: Dictionary) -> Dictionary:
	var hip: float = 0.0
	var knee: float = 0.0
	var ankle: float = 0.0
	var sf: float = float(prof["stride_fwd"])
	var sb: float = float(prof["stride_back"])
	var kc: float = float(prof["knee_cushion"])
	var ke: float = float(prof["knee_extension"])
	var ks: float = float(prof["knee_swing"])
	var as_strike: float = float(prof["ankle_strike"])
	var ap_push: float = float(prof["ankle_push"])
	var ac_clear: float = float(prof["ankle_clear"])

	if u < 0.50:
		# --- STANCE PHASE (0.00 -> 0.50) ---
		var t_stance := u / 0.50
		hip = lerpf(sf, sb, t_stance)

		if u < 0.15:
			# Loading response / shock absorption: heel-strike rolling down to flat foot
			var t_load := u / 0.15
			knee = lerpf(kc, kc * 1.15, t_load)
			ankle = lerpf(as_strike, 0.0, t_load)
		elif u < 0.38:
			# Mid-stance: foot firmly flat, body rolls over supporting leg, knee extends
			var t_mid := (u - 0.15) / 0.23
			knee = lerpf(kc * 1.15, ke, t_mid)
			ankle = 0.0
		else:
			# Push-off / toe-off: heel lifts, strong ankle drive through ball of foot
			var t_push := (u - 0.38) / 0.12
			knee = lerpf(ke, kc * 1.3, t_push)
			ankle = lerpf(0.0, ap_push, t_push)
	else:
		# --- SWING PHASE (0.50 -> 1.00) ---
		if u < 0.75:
			# Initial & mid swing: knee flexes deeply to clear floor, ankle recovers
			var t_lift := (u - 0.50) / 0.25
			var t_smooth := smoothstep(0.0, 1.0, t_lift)
			hip = lerpf(sb, sf * 0.4, t_smooth)
			knee = lerpf(kc * 1.3, ks, t_smooth)
			ankle = lerpf(ap_push, ac_clear, t_smooth)
		else:
			# Terminal swing: leg reaches forward, knee extends smoothly, ankle prepares heel-strike
			var t_reach := (u - 0.75) / 0.25
			var t_smooth := smoothstep(0.0, 1.0, t_reach)
			hip = lerpf(sf * 0.4, sf, t_smooth)
			knee = lerpf(ks, kc, t_smooth)
			ankle = lerpf(ac_clear, as_strike, t_smooth)

	return {"hip": hip, "knee": knee, "ankle": ankle}

## Call once per physics frame. `state` is one of:
## "normal", "hold" (carrying the basketball), "ride" (on the skateboard),
## "exercise" (NPC workout).
## `vertical_speed` shapes the jump: rising tucks the legs, falling reaches for the ground, and the landing is
## cushioned for a moment after touchdown. It defaults to 0, so callers that do not track it still animate.
func animate(delta: float, horizontal_speed: float, on_floor: bool, state: String = "normal",
		vertical_speed: float = 0.0) -> void:
	_time += delta
	if on_floor:
		if _air > 0.08:
			_land = 1.0          # only a real fall earns a cushion, not a step off a kerb
		_air = 0.0
	else:
		_air += delta
	_land = maxf(0.0, _land - delta / LAND_CUSHION_TIME)
	var prof := _get_active_profile()
	if prof.get("is_legacy", false):
		_animate_legacy(delta, horizontal_speed, on_floor, state)
		return
	prof = _gait_profile(prof, horizontal_speed)

	var speed_ref: float = float(prof.get("speed_ref", WALK_REFERENCE_SPEED))
	var target := clampf(horizontal_speed / speed_ref, 0.0, 1.5)
	_move = lerpf(_move, target, 1.0 - exp(-10.0 * delta))
	if state != "ride":
		var cadence: float = float(prof.get("cadence", 1.0))
		_phase = fmod(_phase + delta * horizontal_speed * STRIDE_RADIANS_PER_METER * cadence, TAU)
	# The swim stroke keeps its own clock: treading water is still a stroke, just a slower one.
	_stroke = fmod(_stroke + delta * (1.9 + clampf(horizontal_speed / 2.0, 0.0, 1.4)), TAU)
	var amt := minf(_move, 1.0)
	var k := 1.0 - exp(-POSE_EASE_RATE * delta)

	_animate_legs_new(state, on_floor, amt, k, prof, vertical_speed)
	_animate_arms_new(state, on_floor, amt, k, prof, vertical_speed)

	var torso: Node3D = _pivots["torso"]
	var hips: Node3D = _pivots["hips"]
	var idle := float(prof.get("idle_amp", 1.0))
	var idle_breath := sin(_time * 1.6) * 0.012 * idle * (1.0 - amt)

	# Standing still: a slow weight shift from one leg to the other, so idle never reads as a statue.
	var still := 1.0 - clampf(amt * 3.0, 0.0, 1.0)
	var shift := sin(_time * 0.42) * still * idle
	if state == "normal" or state == "hold":
		var bob: float = -cos(_phase * 2.0) * float(prof["bob_amp"]) * amt if on_floor else 0.0
		# the landing cushion drops the whole torso, not just the knees, so the weight reads
		torso.position.y = TORSO_BASE_Y + bob + sin(_time * 2.0) * 0.004 * idle - _land * _land * 0.10
		# Negated: on this rig a NEGATIVE torso x pitches the chest forward (the swim pose proves it), so the
		# profiles' positive `torso_lean` was leaning every character slightly BACKWARD - a runner sitting back on
		# their heels. The profile number reads as forward lean.
		torso.rotation.x = lerp_angle(torso.rotation.x, -float(prof["torso_lean"]) * (0.4 + 0.6 * amt) + idle_breath, k)
		torso.rotation.y = lerp_angle(torso.rotation.y, -sin(_phase) * float(prof["shoulder_twist"]) * amt, k)

		hips.position.x = lerpf(hips.position.x, sin(_phase) * float(prof["sway"]) * amt + shift * 0.012, k)
		hips.rotation.y = lerp_angle(hips.rotation.y, sin(_phase) * float(prof["pelvis_yaw"]) * amt, k)
		hips.rotation.z = lerp_angle(hips.rotation.z, -cos(_phase) * float(prof["pelvis_roll"]) * amt, k)
		# Spine counter-tilt: torso laterally flexes against pelvic roll to keep chest & head balanced
		torso.rotation.z = lerp_angle(torso.rotation.z, -hips.rotation.z * 0.65 - shift * 0.018, k)

		if _pivots.has("head"):
			var head: Node3D = _pivots["head"]
			head.rotation.y = lerp_angle(head.rotation.y, -torso.rotation.y * float(prof["head_stabilize"]), k)
			head.rotation.x = lerp_angle(head.rotation.x, -bob * 1.2, k)
			head.rotation.z = lerp_angle(head.rotation.z, -torso.rotation.z * 0.5, k)
	elif state == "sit":
		# Seated: the torso sinks onto the hips and carries a little forward lean, with the breath still running.
		torso.position.y = lerpf(torso.position.y, TORSO_BASE_Y - SIT_DROP + sin(_time * 1.8) * 0.004, k)
		torso.rotation.x = lerp_angle(torso.rotation.x, -0.10 + idle_breath, k)      # negative pitches forward
		torso.rotation.y = lerp_angle(torso.rotation.y, sin(_time * 0.35) * 0.03, k)
		torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, k)
		hips.position.x = lerpf(hips.position.x, 0.0, k)
		hips.rotation.y = lerp_angle(hips.rotation.y, 0.0, k)
		hips.rotation.z = lerp_angle(hips.rotation.z, 0.0, k)
		if _pivots.has("head"):
			var head: Node3D = _pivots["head"]
			head.rotation.y = lerp_angle(head.rotation.y, -sin(_time * 0.35) * 0.03, k)
			head.rotation.x = lerp_angle(head.rotation.x, 0.06, k)       # look level, against the torso's lean
			head.rotation.z = lerp_angle(head.rotation.z, 0.0, k)
	elif state == "katana" or state == "dual_katana":
		# Kenjutsu stance: weight back, shoulders turned off square so the blade has somewhere to travel from. The
		# cut is a TORSO move - the arms only carry the sword - so the twist unwinds through the swing and the
		# chest drops into it, which is what makes a swing read as weight rather than a flapping arm.
		var sw := clampf(swing, 0.0, 1.0)
		var wind := sin(sw * PI)                       # 0 at guard and at the end, 1 through the middle of the cut
		var through := smoothstep(0.15, 0.85, sw)      # 0 -> 1 across the cut
		var lead := float(swing_side)
		var turn: float = (0.30 - 0.85 * through) * lead
		torso.position.y = lerpf(torso.position.y, TORSO_BASE_Y - 0.05 - wind * 0.06, k)
		torso.rotation.x = lerp_angle(torso.rotation.x, -(0.10 + wind * 0.22), k)
		torso.rotation.y = lerp_angle(torso.rotation.y, turn, k)
		torso.rotation.z = lerp_angle(torso.rotation.z, -lead * wind * 0.10, k)
		hips.rotation.x = lerp_angle(hips.rotation.x, 0.0, k)
		hips.rotation.y = lerp_angle(hips.rotation.y, turn * 0.45, k)
		hips.rotation.z = lerp_angle(hips.rotation.z, 0.0, k)
		hips.position.x = lerpf(hips.position.x, 0.0, k)
		if _pivots.has("head"):
			var kh: Node3D = _pivots["head"]
			kh.rotation.y = lerp_angle(kh.rotation.y, -turn * 0.55, k)     # eyes stay on the target through the turn
			kh.rotation.x = lerp_angle(kh.rotation.x, 0.06 + wind * 0.10, k)
			kh.rotation.z = lerp_angle(kh.rotation.z, 0.0, k)
	elif state == "swim":
		# A swimmer is PRONE. The first pass pitched only the waist and left the pelvis standing, which folded the
		# character in half and read as a head-first dive (see the pose sheet). The pitch belongs on the hips, so
		# the whole body goes horizontal about the hip joint; the chest then arches back UP so the head clears the
		# water instead of ploughing into it. The body rolls to each stroke and breathes on one side.
		var roll := sin(_stroke) * 0.20
		torso.position.y = lerpf(torso.position.y, TORSO_BASE_Y - 0.10, k)
		hips.rotation.x = lerp_angle(hips.rotation.x, SWIM_PITCH, k)
		torso.rotation.x = lerp_angle(torso.rotation.x, SWIM_CHEST_LIFT, k)
		torso.rotation.y = lerp_angle(torso.rotation.y, roll * 0.5, k)
		torso.rotation.z = lerp_angle(torso.rotation.z, roll, k)
		hips.position.x = lerpf(hips.position.x, 0.0, k)
		hips.rotation.y = lerp_angle(hips.rotation.y, 0.0, k)
		hips.rotation.z = lerp_angle(hips.rotation.z, -roll * 0.4, k)
		if _pivots.has("head"):
			var head: Node3D = _pivots["head"]
			var breathe := maxf(0.0, sin(_stroke)) ** 2.0        # face turns out of the water on one side only
			head.rotation.y = lerp_angle(head.rotation.y, -0.85 * breathe, k)
			head.rotation.x = lerp_angle(head.rotation.x, 0.30 - 0.20 * breathe, k)
			head.rotation.z = lerp_angle(head.rotation.z, -roll * 0.5, k)
	else:
		torso.position.y = TORSO_BASE_Y + sin(_time * 2.0) * 0.004 * idle
		torso.rotation.x = lerp_angle(torso.rotation.x, idle_breath, k)
		torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, k)
		torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, k)
		hips.position.x = lerpf(hips.position.x, shift * 0.012, k)
		hips.rotation.y = lerp_angle(hips.rotation.y, 0.0, k)
		hips.rotation.z = lerp_angle(hips.rotation.z, 0.0, k)
		if _pivots.has("head"):
			var head: Node3D = _pivots["head"]
			head.rotation.y = lerp_angle(head.rotation.y, 0.0, k)
			head.rotation.x = lerp_angle(head.rotation.x, 0.0, k)
			head.rotation.z = lerp_angle(head.rotation.z, 0.0, k)

	if model:
		_hide_primitive_meshes()
		model.sync_from_rig(self, _pivots, TORSO_BASE_Y)
		model.visible = true
		if not _sockets_oriented:
			model.orient_sockets(self, _sockets)
			_sockets_oriented = true

func _animate_legs_new(state: String, on_floor: bool, amt: float, k: float, prof: Dictionary,
		vertical_speed: float = 0.0) -> void:
	var hip_l: Node3D = _pivots["hip_l"]
	var hip_r: Node3D = _pivots["hip_r"]
	var knee_l: Node3D = _pivots["knee_l"]
	var knee_r: Node3D = _pivots["knee_r"]
	var ankle_l: Node3D = _pivots["ankle_l"]
	var ankle_r: Node3D = _pivots["ankle_r"]

	if state == "ride":
		_ease_x(hip_l, 0.12, k); _ease_x(hip_r, -0.12, k)
		_ease_x(knee_l, -0.15, k); _ease_x(knee_r, -0.15, k)
		_ease_x(ankle_l, 0.0, k); _ease_x(ankle_r, 0.0, k)
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, 0.0, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, 0.0, k)
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, 0.0, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, 0.0, k)
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.0, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, 0.0, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, 0.0, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.0, k)
	elif state == "sit":
		# Thighs forward and level, shins down, feet flat. One knee sits a little wider than the other so the pose
		# does not read as a mannequin bolted to a chair.
		# Positive swings the thigh FORWARD (the same sign the gait uses for stride_fwd); the knee folds negative.
		_ease_x(hip_l, 1.42, k); _ease_x(knee_l, -1.46, k); _ease_x(ankle_l, 0.16, k)
		_ease_x(hip_r, 1.38, k); _ease_x(knee_r, -1.52, k); _ease_x(ankle_r, 0.12, k)
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, 0.10, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, -0.16, k)
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, -0.10, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, 0.15, k)
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.05, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, -0.08, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, 0.0, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.0, k)
	elif state == "katana" or state == "dual_katana":
		# Staggered stance, lead foot forward, weight sinking into the cut. Knees stay soft the whole time; a
		# straight-legged swordsman is the stiff read we are trying to get away from.
		var sw2 := clampf(swing, 0.0, 1.0)
		var drop := sin(sw2 * PI)
		var lead2 := float(swing_side)
		var front := 0.34 + drop * 0.16
		var back := -0.22 - drop * 0.10
		if lead2 > 0.0:
			_ease_x(hip_l, front, k); _ease_x(hip_r, back, k)
		else:
			_ease_x(hip_r, front, k); _ease_x(hip_l, back, k)
		_ease_x(knee_l, -0.34 - drop * 0.24, k)
		_ease_x(knee_r, -0.34 - drop * 0.24, k)
		_ease_x(ankle_l, 0.10, k); _ease_x(ankle_r, 0.10, k)
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, 0.12, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, -0.12, k)
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, -0.10, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, 0.10, k)
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.0, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, 0.0, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, 0.0, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.0, k)
	elif state == "swim":
		# Flutter kick: the legs trail behind the pitched torso and beat from the hip with a soft trailing knee.
		var beat := sin(_stroke * 2.0)
		var beat2 := sin(_stroke * 2.0 + PI)
		# The hips now carry the pitch, so the legs only need a small flutter around straight - the big negative
		# swing here was compensating for a pelvis that was still standing up.
		_ease_x(hip_l, 0.10 + beat * 0.24, k); _ease_x(hip_r, 0.10 + beat2 * 0.24, k)
		_ease_x(knee_l, -0.28 - maxf(0.0, beat) * 0.34, k)
		_ease_x(knee_r, -0.28 - maxf(0.0, beat2) * 0.34, k)
		_ease_x(ankle_l, -0.34, k); _ease_x(ankle_r, -0.34, k)      # toes pointed
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, 0.04, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, -0.04, k)
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, -0.035, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, 0.035, k)
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.0, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, 0.0, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, 0.0, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.0, k)
	elif not on_floor:
		# One jump, read off vertical speed: rise tucks the legs under the body, the apex opens them, and the fall
		# reaches for the ground with the lead leg. `v` runs +1 at full launch to -1 at full fall.
		var v := clampf(vertical_speed / JUMP_SPEED_REF, -1.0, 1.0)
		var rise := maxf(0.0, v)
		var fall := maxf(0.0, -v)
		var lead := 0.30 + rise * 0.55 - fall * 0.42          # front leg: tucked high, then reaching down
		var trail := -0.10 + rise * 0.22 - fall * 0.30
		_ease_x(hip_l, lead, k); _ease_x(hip_r, trail, k)
		_ease_x(knee_l, -0.55 - rise * 0.85 + fall * 0.22, k)
		_ease_x(knee_r, -0.40 - rise * 0.55 + fall * 0.14, k)
		_ease_x(ankle_l, 0.10 - rise * 0.30 + fall * 0.22, k)    # toes point on the way up, brace on the way down
		_ease_x(ankle_r, -0.05 - rise * 0.28 + fall * 0.26, k)
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, 0.05, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, -0.05, k)
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, -0.05 - rise * 0.03, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, 0.05 + rise * 0.03, k)
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.0, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, 0.0, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, 0.0, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.0, k)
	else:
		var u_l := fmod(_phase / TAU, 1.0)
		if u_l < 0.0: u_l += 1.0
		var u_r := fmod((_phase + PI) / TAU, 1.0)
		if u_r < 0.0: u_r += 1.0

		var s_l := _sample_leg_gait(u_l, prof)
		var s_r := _sample_leg_gait(u_r, prof)

		_ease_x(hip_l, s_l["hip"] * amt, 1.0)
		_ease_x(knee_l, s_l["knee"] * amt, 1.0)
		_ease_x(ankle_l, s_l["ankle"] * amt, 1.0)

		_ease_x(hip_r, s_r["hip"] * amt, 1.0)
		_ease_x(knee_r, s_r["knee"] * amt, 1.0)
		_ease_x(ankle_r, s_r["ankle"] * amt, 1.0)

		# Touchdown: the knees keep giving for a moment instead of the character arriving rigid.
		if _land > 0.0:
			var give := _land * _land * 0.62
			knee_l.rotation.x -= give
			knee_r.rotation.x -= give
			hip_l.rotation.x -= give * 0.35
			hip_r.rotation.x -= give * 0.35
			ankle_l.rotation.x += give * 0.30
			ankle_r.rotation.x += give * 0.30

		# Natural toe-out splay (outward angle of feet so legs do not look parallel/robotic)
		var toe_splay := 0.22
		var toe_dyn_l := toe_splay - sin(_phase) * 0.02 * amt
		var toe_dyn_r := -toe_splay - sin(_phase) * 0.02 * amt
		hip_l.rotation.y = lerp_angle(hip_l.rotation.y, toe_dyn_l, k)
		hip_r.rotation.y = lerp_angle(hip_r.rotation.y, toe_dyn_r, k)

		# Stance width at the hips. A feminine walk (the user's Mery reference) tracks the feet close to the centre
		# line, so its profile sets this negative; a broad walk keeps the feet apart.
		var abduct: float = float(prof.get("stance", 0.085))
		var abduct_l := -abduct - cos(_phase) * 0.02 * amt
		var abduct_r := abduct - cos(_phase) * 0.02 * amt
		hip_l.rotation.z = lerp_angle(hip_l.rotation.z, abduct_l, k)
		hip_r.rotation.z = lerp_angle(hip_r.rotation.z, abduct_r, k)

		# Ankle subtle ground adaptation & toe alignment
		ankle_l.rotation.y = lerp_angle(ankle_l.rotation.y, 0.04, k)
		ankle_r.rotation.y = lerp_angle(ankle_r.rotation.y, -0.04, k)
		ankle_l.rotation.z = lerp_angle(ankle_l.rotation.z, -0.02 * amt, k)
		ankle_r.rotation.z = lerp_angle(ankle_r.rotation.z, 0.02 * amt, k)

func _animate_arms_new(state: String, on_floor: bool, amt: float, k: float, prof: Dictionary,
		vertical_speed: float = 0.0) -> void:
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var shoulder: Node3D = _pivots["shoulder_" + side]
		var elbow: Node3D = _pivots["elbow_" + side]
		var hand: Node3D = _pivots.get("hand_" + side, null)
		var target := Vector3.ZERO
		var elbow_bend := float(prof["elbow_rest"])
		var wrist_pitch := 0.08
		var wrist_yaw := sx * WRIST_NEUTRAL
		var wrist_roll := sx * 0.08

		var still_arm := 1.0 - clampf(amt * 3.0, 0.0, 1.0)
		match state:
			"hold":
				target = Vector3(1.15, sx * -0.15, sx * 0.1)
				elbow_bend = 0.55
				wrist_pitch = 0.0
				wrist_yaw = sx * -0.35
				wrist_roll = sx * 0.15
			"exercise":
				var raise := sin(_time * 6.0) * 0.5 + 0.5
				target = Vector3(0.1, 0.0, sx * (0.15 + raise * 2.6))
				elbow_bend = 0.1
				wrist_pitch = 0.0
				wrist_yaw = sx * 0.5
				wrist_roll = 0.0
			"ride":
				target = Vector3(0.15, sx * 0.05, sx * 0.9)
				elbow_bend = 0.25
				wrist_pitch = 0.06
				wrist_yaw = sx * 1.15
				wrist_roll = sx * 0.08
			"sit":
				# Forearms resting on the thighs, hands loose, with a slow breath through the shoulders.
				target = Vector3(0.34 + sin(_time * 1.2 + sx) * 0.015, sx * 0.12, sx * 0.16)
				elbow_bend = 1.05
				wrist_pitch = 0.18
				wrist_yaw = sx * 0.95
				wrist_roll = sx * 0.12
			"katana":
				# Two hands on ONE hilt, so both must arrive at the same point on the centre line - that is what
				# sells a two-handed weapon, and it is why the hands are pulled toward the middle with -sx rather
				# than mirrored outward. Guard is chudan, hands at the belt; the cut lifts overhead and comes down
				# across the body (kesagiri), arms extending as it lands.
				var sw := clampf(swing, 0.0, 1.0)
				var lift := sin(clampf(sw / 0.35, 0.0, 1.0) * PI * 0.5)        # wind up over the shoulder
				var fall := smoothstep(0.35, 0.85, sw)                          # then drive it down and through
				var dom := 1.0 if sx * float(swing_side) > 0.0 else 0.0         # grip hand vs support hand
				var support := 1.0 - dom
				# The blade hangs off the GRIP hand, so the support hand has further to travel to reach the same
				# hilt - it starts from the other shoulder. It gets the extra cross-body reach and the extra elbow
				# to close that gap, both easing off as the cut extends and the hands end up in front anyway.
				var reach := support * (0.34 - fall * 0.26)
				# ...and the whole arc bows OUTWARD through the middle of the cut, or the blade travels straight
				# down the thigh. Peaks mid-fall, closed again by the finish.
				var clear := sin(fall * PI) * 0.40
				# the support arm also comes further FORWARD at guard: reaching across alone leaves it beside the
				# hip, not under the hilt, which sits in front of the sternum
				var pitch: float = 0.42 - lift * 1.85 + fall * 2.05 + support * (0.26 - fall * 0.26)
				# ...and the grip arm tucks IN at guard rather than standing off, so the two meet at the centre
				target = Vector3(pitch, -sx * (0.34 + reach - fall * 0.16),
						sx * (0.16 - 0.10 * dom * (1.0 - fall) + clear) + lift * 0.18)
				elbow_bend = 1.45 + dom * 0.18 + support * (0.50 - fall * 0.42) - lift * 0.25 - fall * 0.95
				wrist_pitch = -0.10 - lift * 0.35 + fall * 0.45
				wrist_yaw = sx * (0.12 + 0.20 * dom)
				wrist_roll = -sx * (0.30 + lift * 0.25 - fall * 0.45)
			"dual_katana":
				# One blade per hand, so the hands stay OUT on their own sides instead of meeting. They do not
				# mirror in time either: the lead arm cuts while the other holds its guard wide, then they trade.
				# Symmetry would read as a jumping jack rather than a swordsman.
				var sw2 := clampf(swing, 0.0, 1.0)
				var leading := sx * float(swing_side) > 0.0
				var t2 := smoothstep(0.05, 0.70, sw2) if leading else smoothstep(0.40, 1.0, sw2) * 0.5
				var lift2 := sin(clampf((sw2 if leading else sw2 * 0.6) / 0.35, 0.0, 1.0) * PI * 0.5)
				var breath := sin(_time * 1.6 + (0.0 if leading else PI)) * 0.03
				var clear2 := sin(t2 * PI) * 0.28              # bow the arc out past the thigh mid-cut
				target = Vector3(0.26 - lift2 * 1.30 + t2 * 1.55 + breath,
						sx * (0.22 - t2 * 0.50), sx * (0.62 + lift2 * 0.20 + t2 * 0.22 + clear2))
				elbow_bend = 1.30 - lift2 * 0.20 - t2 * 0.80
				wrist_pitch = -0.16 - lift2 * 0.25 + t2 * 0.40
				wrist_yaw = sx * 0.34
				wrist_roll = sx * (0.40 - t2 * 0.60)
			"swim":
				# Front crawl. One arm pulls under the body while the other recovers over the shoulder; the
				# stroke runs on its own clock so treading water still moves.
				var ph: float = _stroke + (0.0 if side == "l" else PI)
				var c := cos(ph)
				var pull := sin(ph)
				# shoulder sweeps from overhead (catch) down past the hip (finish) and back over the top
				target = Vector3(-1.25 * c, sx * 0.10 * pull, sx * (0.22 + 0.30 * maxf(0.0, c)))
				elbow_bend = 0.30 + maxf(0.0, -c) * 0.85        # bent on the recovery, straighter on the catch
				wrist_pitch = -0.12 * c
				wrist_yaw = sx * 0.85
				wrist_roll = sx * 0.10
			_:
				if not on_floor:
					# Arms answer the jump: swept back and up off the launch, opening out for balance on the fall.
					var v := clampf(vertical_speed / JUMP_SPEED_REF, -1.0, 1.0)
					var rise := maxf(0.0, v)
					var fall := maxf(0.0, -v)
					target = Vector3(0.25 - rise * 0.95 + fall * 0.35, sx * 0.05,
							sx * (0.45 + rise * 0.30 + fall * 0.45))
					elbow_bend = 0.42 + rise * 0.25 + fall * 0.10
					wrist_pitch = -0.15 - rise * 0.10
					wrist_yaw = sx * 0.9
					wrist_roll = sx * 0.06
				else:
					var arm_s := -sin(_phase) if side == "l" else sin(_phase)
					var arm_pitch: float = 0.0
					if arm_s >= 0.0:
						arm_pitch = arm_s * float(prof["arm_fwd"]) * amt
						elbow_bend = (float(prof["elbow_rest"]) + (float(prof["elbow_swing"]) - float(prof["elbow_rest"])) * 0.45 * arm_s) * amt + float(prof["elbow_rest"]) * (1.0 - amt)
					else:
						arm_pitch = arm_s * (-float(prof["arm_back"])) * amt
						elbow_bend = (float(prof["elbow_rest"]) + (float(prof["elbow_swing"]) - float(prof["elbow_rest"])) * (-arm_s) * 0.75) * amt + float(prof["elbow_rest"]) * (1.0 - amt)

					# 3D teardrop arm path: medial inward curve on forward swing, outward clearance on backswing
					var arm_yaw := sx * arm_pitch * 0.14
					var arm_roll := sx * (float(prof["arm_out"]) + maxf(0.0, -arm_pitch * 0.05) + cos(_phase) * 0.010 * sx * amt)
					target = Vector3(arm_pitch, arm_yaw, arm_roll)

					# Dynamic wrist follow-through (drag / inertia) and natural palm-to-body orientation
					if arm_pitch >= 0.0:
						# Forward swing: wrist drags back naturally
						wrist_pitch = -arm_pitch * 0.35 * amt + 0.08
						wrist_yaw = sx * (WRIST_NEUTRAL - arm_pitch * 0.18 * amt)
						wrist_roll = sx * (0.08 + arm_pitch * 0.05 * amt)
					else:
						# Back swing: wrist carries forward
						wrist_pitch = -arm_pitch * 0.25 * amt + 0.08
						wrist_yaw = sx * (WRIST_NEUTRAL + arm_pitch * 0.12 * amt)
						wrist_roll = sx * (0.08 - arm_pitch * 0.04 * amt)

		# standing: soften the elbow further and let the arm drift with the breath, so it never locks straight
		if state == "normal" and on_floor:
			elbow_bend += still_arm * 0.12
			target.x += still_arm * sin(_time * 1.3 + (0.0 if side == "l" else 0.6)) * 0.020
			target.z -= sx * still_arm * 0.010
		var rate := 1.0 if state == "normal" and on_floor else k
		shoulder.rotation.x = lerp_angle(shoulder.rotation.x, target.x, rate)
		shoulder.rotation.y = lerp_angle(shoulder.rotation.y, target.y, k)
		shoulder.rotation.z = lerp_angle(shoulder.rotation.z, target.z, k)

		# Elbow flexion is POSITIVE on this rig - the profiles' own sign. Both arm chains share one axis convention
		# (+x on either shoulder or elbow swings that hand the same way), so the bend is not mirrored per side;
		# the contralateral swing comes from arm_s alone.
		#
		# This was briefly negated after judging the sign from an arm raised straight ahead, where positive merely
		# continues the line and reads as "straight". That was the wrong pose to judge it in: at rest, which is how
		# the character is seen nearly all the time, positive hangs the forearm naturally FORWARD and negative
		# swings it behind the hip - visibly hyperextended, which is what shipped and what looked broken in game.
		# Judge arm signs at rest, not mid-reach.
		_ease_x(elbow, elbow_bend, k)
		var pronation := sx * 0.22 + sx * 0.10 * target.x * amt
		elbow.rotation.y = lerp_angle(elbow.rotation.y, pronation, k)
		elbow.rotation.z = lerp_angle(elbow.rotation.z, sx * 0.025, k)

		# Wrist / hand natural relaxation & articulation
		if hand:
			hand.rotation.x = lerp_angle(hand.rotation.x, wrist_pitch, rate)
			hand.rotation.y = lerp_angle(hand.rotation.y, wrist_yaw, k)
			hand.rotation.z = lerp_angle(hand.rotation.z, wrist_roll, k)

## Legacy procedural walk preserved for side-by-side comparison
func _animate_legacy(delta: float, horizontal_speed: float, on_floor: bool, state: String) -> void:
	var target := clampf(horizontal_speed / WALK_REFERENCE_SPEED, 0.0, 1.5)
	_move = lerpf(_move, target, 1.0 - exp(-10.0 * delta))
	if state != "ride":
		_phase = fmod(_phase + delta * horizontal_speed * STRIDE_RADIANS_PER_METER * float(_style.get("speed", 1.0)), TAU)
	var amt := minf(_move, 1.0)
	var s := sin(_phase)
	var swing := s * 0.55 * amt * float(_style.get("stride", 1.0))
	var k := 1.0 - exp(-POSE_EASE_RATE * delta)

	_animate_legs_legacy(state, on_floor, swing, s, amt, k)
	_animate_arms_legacy(state, on_floor, swing, amt, k)

	var torso: Node3D = _pivots["torso"]
	var idle := float(_style.get("idle_amp", 1.0))
	var bob := absf(s) * 0.025 * amt * float(_style.get("bob", 1.0)) if on_floor and state != "ride" else 0.0
	torso.position.y = TORSO_BASE_Y + bob + sin(_time * 2.0) * 0.004 * idle
	var twist := swing * 0.15 * float(_style.get("twist", 1.0)) if state == "normal" or state == "hold" else 0.0
	torso.rotation.y = lerp_angle(torso.rotation.y, twist, k)
	var hips: Node3D = _pivots["hips"]
	hips.position.x = lerpf(hips.position.x, s * 0.022 * amt * float(_style.get("sway", 1.0)), k)
	hips.rotation.y = lerp_angle(hips.rotation.y, 0.0, k)
	hips.rotation.z = lerp_angle(hips.rotation.z, -s * 0.05 * amt * float(_style.get("sway", 1.0)), k)
	var idle_breath := sin(_time * 1.6) * 0.012 * idle * (1.0 - amt)
	torso.rotation.x = lerp_angle(torso.rotation.x, float(_style.get("lean", 0.0)) * (0.4 + 0.6 * amt) + idle_breath, k)

	if _transformation_model_instance != null:
		return

	if model:
		_hide_primitive_meshes()
		model.sync_from_rig(self, _pivots, TORSO_BASE_Y)
		model.visible = true
		if not _sockets_oriented:
			model.orient_sockets(self, _sockets)
			_sockets_oriented = true

func _animate_legs_legacy(state: String, on_floor: bool, swing: float, s: float, amt: float, k: float) -> void:
	var hip_l: Node3D = _pivots["hip_l"]
	var hip_r: Node3D = _pivots["hip_r"]
	var knee_l: Node3D = _pivots["knee_l"]
	var knee_r: Node3D = _pivots["knee_r"]
	var ankle_l: Node3D = _pivots["ankle_l"]
	var ankle_r: Node3D = _pivots["ankle_r"]
	_ease_x(ankle_l, 0.0, k)
	_ease_x(ankle_r, 0.0, k)
	if state == "ride":
		_ease_x(hip_l, 0.12, k); _ease_x(hip_r, -0.12, k)
		_ease_x(knee_l, -0.15, k); _ease_x(knee_r, -0.15, k)
	elif not on_floor:
		_ease_x(hip_l, 0.55, k); _ease_x(knee_l, -0.9, k)
		_ease_x(hip_r, -0.15, k); _ease_x(knee_r, -0.35, k)
	else:
		_ease_x(hip_l, swing, 1.0); _ease_x(hip_r, -swing, 1.0)
		_ease_x(knee_l, -maxf(0.0, -s) * 0.9 * amt, 1.0)
		_ease_x(knee_r, -maxf(0.0, s) * 0.9 * amt, 1.0)

func _animate_arms_legacy(state: String, on_floor: bool, swing: float, amt: float, k: float) -> void:
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var shoulder: Node3D = _pivots["shoulder_" + side]
		var elbow: Node3D = _pivots["elbow_" + side]
		var target := Vector3.ZERO
		var elbow_bend := 0.15
		match state:
			"hold":
				target = Vector3(1.15, 0.0, 0.0)
				elbow_bend = 0.55
			"exercise":
				var raise := sin(_time * 6.0) * 0.5 + 0.5
				target = Vector3(0.1, 0.0, sx * (0.15 + raise * 2.6))
				elbow_bend = 0.1
			"ride":
				target = Vector3(0.15, 0.0, sx * 0.9)
				elbow_bend = 0.25
			_:
				if not on_floor:
					target = Vector3(0.3, 0.0, sx * 0.6)
					elbow_bend = 0.4
				else:
					var arm := -swing * 0.8 if side == "l" else swing * 0.8
					arm *= float(_style.get("arm", 1.0))
					target = Vector3(arm, 0.0, sx * 0.12 * float(_style.get("arm_out", 1.0)))
					elbow_bend = (0.15 + 0.3 * amt) * float(_style.get("elbow", 1.0))
		var rate := 1.0 if state == "normal" and on_floor else k
		shoulder.rotation.x = lerp_angle(shoulder.rotation.x, target.x, rate)
		shoulder.rotation.z = lerp_angle(shoulder.rotation.z, target.z, k)
		_ease_x(elbow, elbow_bend, k)
		var hand: Node3D = _pivots.get("hand_" + side, null)
		if hand:
			hand.rotation = Vector3.ZERO

func _ease_x(node: Node3D, value: float, rate: float) -> void:
	node.rotation.x = lerp_angle(node.rotation.x, value, rate)

## --- Construction -------------------------------------------------------------

func _build() -> void:
	var hips := _pivot("hips", self, Vector3(0, TORSO_BASE_Y, 0))
	_part("hips", hips, _capsule(0.12, 0.34), Vector3.ZERO, Vector3(0, 0, 90), Vector3(1, 1, 0.8))
	_socket("hip", hips, Vector3(0.19, -0.02, 0))

	var torso := _pivot("torso", self, Vector3(0, TORSO_BASE_Y, 0))
	_part("torso", torso, _capsule(0.18, 0.56), Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1, 1, 0.65))
	_socket("accessory", torso, Vector3(0, 0.38, -0.162))
	_socket("back", torso, Vector3(0, 0.3, 0.12))

	var neck := _pivot("neck", torso, Vector3(0, 0.56, 0))
	_part("neck", neck, _cylinder(0.055, 0.1), Vector3(0, 0.02, 0))
	var head := _pivot("head", neck, Vector3(0, 0.2, 0))
	_part("head", head, _sphere(0.17), Vector3.ZERO)
	_detail(head, _sphere(0.024), Vector3(-0.065, 0.02, -0.15), Vector3.ONE, _eye_material)
	_detail(head, _sphere(0.024), Vector3(0.065, 0.02, -0.15), Vector3.ONE, _eye_material)
	_detail(head, _sphere(0.02), Vector3(0, -0.07, -0.15), Vector3(1.8, 0.6, 0.6), _mouth_material)
	_socket("head", head, Vector3(0, 0.135, 0))
	_socket("hair", head, Vector3(0, 0.05, 0.04))

	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0

		var shoulder := _pivot("shoulder_" + side, torso, Vector3(0.22 * sx, 0.42, 0))
		_part("upper_arm_" + side, shoulder, _capsule(0.055, 0.32), Vector3(0, -0.15, 0))
		var elbow := _pivot("elbow_" + side, shoulder, Vector3(0, -0.3, 0))
		_part("lower_arm_" + side, elbow, _capsule(0.05, 0.3), Vector3(0, -0.14, 0))
		var hand := _pivot("hand_" + side, elbow, Vector3(0, -0.29, 0))
		_part("hand_" + side, hand, _sphere(0.055), Vector3(0, -0.04, 0))
		_socket("hand_" + side, hand, Vector3(0, -0.05, 0))

		var thigh := _pivot("hip_" + side, hips, Vector3(0.1 * sx, -0.02, 0))
		_part("upper_leg_" + side, thigh, _capsule(0.075, 0.44), Vector3(0, -0.21, 0))
		var knee := _pivot("knee_" + side, thigh, Vector3(0, -0.42, 0))
		_part("lower_leg_" + side, knee, _capsule(0.065, 0.42), Vector3(0, -0.2, 0))
		var ankle := _pivot("ankle_" + side, knee, Vector3(0, -0.4, 0))
		# Foot bottom sits 3cm above the ground so inflated shoes don't sink in.
		_part("foot_" + side, ankle, _box(Vector3(0.12, 0.08, 0.26)), Vector3(0, -0.03, -0.05))

	# Relaxed idle so a freshly spawned character isn't in a stiff T-ish pose.
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		(_pivots["shoulder_" + side] as Node3D).rotation.z = sx * 0.09
		(_pivots["elbow_" + side] as Node3D).rotation.x = 0.18
		(_pivots["elbow_" + side] as Node3D).rotation.y = sx * 0.22
		(_pivots["hand_" + side] as Node3D).rotation = Vector3(0.08, sx * 1.25, sx * 0.08)
		(_pivots["hip_" + side] as Node3D).rotation = Vector3(0.0, sx * -0.22, sx * -0.085)

func _pivot(joint: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Joint" + joint.to_pascal_case()
	n.position = pos
	parent.add_child(n)
	_pivots[joint] = n
	return n

func _part(part_name: String, parent: Node3D, mesh: Mesh, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := _detail(parent, mesh, pos, scl, _skin_material)
	m.name = part_name.to_pascal_case()
	m.rotation_degrees = rot_deg
	_parts[part_name] = m
	return m

func _detail(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.scale = scl
	m.material_override = material
	parent.add_child(m)
	return m

func _socket(slot: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Socket" + slot.to_pascal_case()
	n.position = pos
	parent.add_child(n)
	_sockets[slot] = n
	return n

static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 6
	return c

static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 16
	return c

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
