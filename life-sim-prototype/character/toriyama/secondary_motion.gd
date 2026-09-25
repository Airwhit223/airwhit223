class_name SecondaryMotion
extends RefCounted
## Makes hair and loose clothing lag behind a character and settle back, instead of being welded to the skeleton.
##
## Per character we track how the body actually moved this frame and run one damped spring per profile. The spring
## chases a target that trails the body's own velocity (so walking holds the hair back, not just accelerating):
##     target = -body_velocity * lag;  spring_vel += (stiffness * (target - offset) - damping * spring_vel) * dt
## The result is a small world-space displacement: hair trails while walking, overshoots and settles when you stop,
## bounces slightly with each step, and drifts gently when standing still. It is handed to the shaders in MODEL space, where each
## vertex takes a share of it by how far it is from the piece's anchor — roots stay put, tips move most.
##
## Shader-side (no bones, no physics bodies): cheap enough for a town full of NPCs.

class Profile:
	var stiffness := 90.0
	var damping := 14.0
	var lag := 0.016           # seconds of trail behind the body's velocity
	var bounce := 0.010        # extra bob per metre/second of speed
	var max_offset := 0.05     # metres, so hair never tears off the head
	var idle := 0.004          # gentle drift when standing still
	var idle_rate := 1.3
	var amount := 1.0          # per-piece multiplier the materials use
	var mode := 0              # 0 = distance from the anchor (hair), 1 = hangs below the anchor (hems, sleeves)
	var range_m := 0.22

	func _init(values := {}) -> void:
		for key in values:
			set(key, values[key])

## Tuned so hair reads as hair and a jacket as heavier cloth.
static func profiles() -> Dictionary:
	return {
		"hair": Profile.new({"stiffness": 95.0, "damping": 13.0, "lag": 0.017, "bounce": 0.0032, "max_offset": 0.055,
			"idle": 0.0045, "idle_rate": 1.25, "mode": 0, "range_m": 0.20}),
		"cloth": Profile.new({"stiffness": 62.0, "damping": 12.5, "lag": 0.011, "bounce": 0.0018, "max_offset": 0.038,
			"idle": 0.0022, "idle_rate": 0.9, "mode": 1, "range_m": 0.42}),
		# tails (Beastfolk): softer and swingier than hair, a longer reach, and more of a lag behind the body. The
		# range is the tail's own length, passed per piece from the part's tr_secondary_range.
		"tail": Profile.new({"stiffness": 52.0, "damping": 8.5, "lag": 0.024, "bounce": 0.0045, "max_offset": 0.10,
			"idle": 0.007, "idle_rate": 0.95, "mode": 0, "range_m": 0.50}),
	}

var enabled := true
var scale := 1.0                       # global strength, so it can be dialled down or off

var _profiles: Dictionary = profiles()
var _offset: Dictionary = {}           # profile -> Vector3 (world)
var _velocity: Dictionary = {}
var _materials: Dictionary = {}        # profile -> Array[Dictionary] {material, origin}
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _time := 0.0
var _started := false

func _init() -> void:
	for key in _profiles:
		_offset[key] = Vector3.ZERO
		_velocity[key] = Vector3.ZERO
		_materials[key] = []

## Called as each piece's material is built. `origin` is the anchor in model space (head centre for hair, the waist
## for clothing); vertices are weighted away from it.
## `range_m` (optional) overrides the profile's reach for this one piece — a tail passes its own length.
## An unknown profile name is reported instead of ignored silently.
## `mode` overrides the profile's weighting for this piece: 2 = strand (the mesh carries TR_Strand root->tip data),
## -1 = the profile's own mode.
func register(material: ShaderMaterial, profile: String, origin: Vector3, amount := 1.0, range_m := -1.0,
		mode := -1) -> void:
	if not _materials.has(profile):
		push_warning("SecondaryMotion: unknown profile '%s' (have %s)" % [profile, _materials.keys()])
		return
	var entry := {"material": material, "origin": origin, "amount": amount, "range": range_m, "mode": mode,
		"prev": Vector3.ZERO}
	_materials[profile].append(entry)
	_push(entry, profile, Vector3.ZERO)
	_started = false          # a freshly assembled character must not read its first frame as movement

func clear() -> void:
	for key in _materials:
		_materials[key].clear()

func has_pieces() -> bool:
	for key in _materials:
		if not (_materials[key] as Array).is_empty():
			return true
	return false

## Call once per frame with the character's world transform.
func update(delta: float, global_transform: Transform3D) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var position := global_transform.origin
	if not _started:
		_started = true
		_last_position = position
	var velocity := (position - _last_position) / delta
	# teleports, spawning and the frame a character is assembled on would fling everything
	if (position - _last_position).length() > 0.75 or velocity.length() > 14.0:
		velocity = Vector3.ZERO
	velocity = _last_velocity.lerp(velocity, clampf(delta * 12.0, 0.0, 1.0))   # smooth out frame noise
	_last_position = position
	_last_velocity = velocity
	var speed := velocity.length()
	var basis_inv := global_transform.basis.orthonormalized().inverse()
	for key in _profiles:
		var p: Profile = _profiles[key]
		var offset: Vector3 = _offset[key]
		var vel: Vector3 = _velocity[key]
		if enabled:
			var target := -velocity * p.lag
			vel += (p.stiffness * (target - offset) - p.damping * vel) * delta
			offset += vel * delta
			if offset.length() > p.max_offset:
				offset = offset.normalized() * p.max_offset
			# a light bob in step with movement, plus the standing-still drift
			var step := sin(_time * (2.2 + speed * 2.4)) * p.bounce * speed
			var idle := Vector3(sin(_time * p.idle_rate) * p.idle, sin(_time * p.idle_rate * 0.7 + 1.1) * p.idle * 0.5 + step,
				cos(_time * p.idle_rate * 0.85) * p.idle)
			_offset[key] = offset
			_velocity[key] = vel
			var total := (offset + idle) * scale          # the limit covers the drift too, not just the spring
			if total.length() > p.max_offset:
				total = total.normalized() * p.max_offset
			var model_offset := basis_inv * total
			for entry in _materials[key]:
				_push(entry, key, model_offset)
		else:
			_offset[key] = Vector3.ZERO
			_velocity[key] = Vector3.ZERO
			for entry in _materials[key]:
				_push(entry, key, Vector3.ZERO)

func _push(entry: Dictionary, profile: String, model_offset: Vector3) -> void:
	var p: Profile = _profiles[profile]
	var material: ShaderMaterial = entry["material"]
	if not is_instance_valid(material):
		return
	var mode: int = p.mode if int(entry.get("mode", -1)) < 0 else int(entry["mode"])
	var prev: Vector3 = entry.get("prev", model_offset)
	entry["prev"] = model_offset
	material.set_shader_parameter("sway_offset", model_offset)
	material.set_shader_parameter("sway_offset_prev", prev)
	material.set_shader_parameter("sway_origin", entry["origin"])
	var reach: float = float(entry.get("range", -1.0))
	if reach <= 0.0:
		reach = p.range_m
	material.set_shader_parameter("sway_range", reach)
	material.set_shader_parameter("sway_amount", float(entry["amount"]) * p.amount)
	material.set_shader_parameter("sway_mode", mode)
	var ink := material.next_pass as ShaderMaterial
	if ink:
		ink.set_shader_parameter("sway_offset", model_offset)
		ink.set_shader_parameter("sway_offset_prev", prev)
		ink.set_shader_parameter("sway_origin", entry["origin"])
		ink.set_shader_parameter("sway_range", reach)
		ink.set_shader_parameter("sway_amount", float(entry["amount"]) * p.amount)
		ink.set_shader_parameter("sway_mode", mode)
