class_name ToriyamaCharacter
extends Node3D
## Toriyama / DQ8 character model for CharacterRig. Loads an exported character (GLB + baked textures + manifest),
## applies the painted-toon and ink shaders, drives the skeleton from CharacterRig's procedural joint pivots (so the
## existing idle / walk / hold / ride / exercise animation carries over), and runs face (eye style, expressions,
## blink) and hair growth states.

const PAINT := preload("res://character/toriyama/toriyama_paint.gdshader")
const INK := preload("res://character/toriyama/toriyama_ink.gdshader")
const ROOT_DIR := "res://character/toriyama/"

## CharacterRig joint -> skeleton bone. Arm chains share one "hang" alignment (the model's T-pose -> arms down).
const BONE_PIVOTS := {
	"DEF-spine": "torso", "DEF-chest": "torso", "DEF-clavicle.L": "torso", "DEF-clavicle.R": "torso",
	"DEF-neck": "neck", "DEF-head": "head",
	"DEF-upper_arm.L": "shoulder_l", "DEF-forearm.L": "elbow_l", "DEF-hand.L": "hand_l",
	"DEF-upper_arm.R": "shoulder_r", "DEF-forearm.R": "elbow_r", "DEF-hand.R": "hand_r",
	"DEF-thigh.L": "hip_l", "DEF-shin.L": "knee_l", "DEF-foot.L": "ankle_l", "DEF-toe.L": "ankle_l",
	"DEF-thigh.R": "hip_r", "DEF-shin.R": "knee_r", "DEF-foot.R": "ankle_r", "DEF-toe.R": "ankle_r",
}
const ALIGN_CHAINS := {
	"L": ["DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L"], "R": ["DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"],
	"LL": ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L"], "LR": ["DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R"],
}
const SOCKET_BONES := {"head": "SOCKET-head", "hair": "DEF-head", "hand_l": "SOCKET-hand.L", "hand_r": "SOCKET-hand.R",
	"back": "SOCKET-back", "hip": "SOCKET-hip", "accessory": "DEF-chest"}
const EXPRESSIONS := ["Happy", "Laughing", "Angry", "Sad", "Surprised", "Determined", "Worried", "Embarrassed", "Smug"]

signal hair_state_changed(state: StringName)

var character_name := ""
var manifest: Dictionary = {}
var model: Node3D
var skeleton: Skeleton3D
var hair_meshes: Dictionary = {}          # state -> MeshInstance3D
var hair_state: StringName = &"fresh"
var last_service_day := 0.0
var growth_rate := 1.0

var _blend_meshes: Array[MeshInstance3D] = []
var _rest_global: Array[Basis] = []
var _align: Dictionary = {}               # bone index -> Quaternion
var _pivot_bone: Dictionary = {}          # bone index -> pivot name
var _root_bone := -1
## Hair and loose clothing lag behind the body and settle (see secondary_motion.gd).
var motion := SecondaryMotion.new()

var _blink_timer := 3.0
var _blink := 0.0
var _eye_style := 0.0
var _expr: Dictionary = {}


func setup(name_: String) -> void:
	character_name = name_
	var dir := ROOT_DIR + name_ + "/"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
	var packed: PackedScene = load(dir + name_ + ".glb")
	model = packed.instantiate()
	model.name = "Model"
	model.rotation.y = PI            # glTF faces +Z; CharacterRig faces -Z
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_apply_materials(dir)
	_collect_hair()
	set_proportions(float(manifest.get("head_scale", HEAD_SCALE)), float(manifest.get("leg_length", 0.0)))
	_register_motion()
	_prepare_skeleton()
	set_eye_style(float(manifest.get("eye_style", 0.0)))
	# the meshes are skinned in a T-pose but the game stands with its arms down; this corrective shape restores the
	# volume plain skinning loses at that angle (body and every garment)
	_set_shape("Pose_Rest", 1.0)
	_set_shape("TR_Chin", 1.0)            # the chin fix (tr_fit_fixes.py); a no-op until a model carries the key
	_set_shape("TR_Neck", 1.0)            # the neck fix (tr_fit_fixes.py): throat knob and nape step smoothed
	_set_shape("TR_Head_Shape", 1.0)      # head pass: narrower, shallower skull + nose/mouth height (the sheets' ratios)
	_set_shape("TR_Jaw", JAW_DEFAULT)
	_set_shape("TR_Eye_DQ", EYE_DQ_DEFAULT)
	_set_shape("TR_Ear_Detail", 1.0)      # helix/concha/lobe relief (tr_fit_fixes.ear_detail)
	set_hair_state(&"fresh")
	voice = ToriyamaVoice.for_character(name_)
	_hide_floating_ear_ink()


## The ear outline (Ear_Ink) was exported 1.6 m above the head on the pre-built characters (an object offset baked
## into its vertices; fixed at the source for the kit on 2026-09-23). Until they are re-exported, hide it wherever it
## sits above the head - they lose only the thin ear line, not the ears.
func _hide_floating_ear_ink() -> void:
	var ear := model.find_child("Ear_Ink", true, false) as MeshInstance3D
	var head := model.find_child("Head_Base", true, false) as MeshInstance3D
	if ear and head and ear.mesh and head.mesh and ear.mesh.get_aabb().position.y > head.mesh.get_aabb().end.y:
		ear.visible = false


# ------------------------------------------------------------------ materials
func _paint(source: int, tex: Texture2D = null, color := Color.WHITE, unlit := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("source", source)
	if tex:
		m.set_shader_parameter("paint_texture", tex)
	m.set_shader_parameter("flat_color", color)
	m.set_shader_parameter("unlit", unlit)
	return m


func _ink(width := 2.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = INK
	m.set_shader_parameter("width_px", width)
	return m


static func _srgb(a: Array) -> Color:
	return Color8(int(a[0]), int(a[1]), int(a[2]))


func _apply_materials(dir: String) -> void:
	var textures: Dictionary = manifest["textures"]
	var face_mats: Dictionary = manifest["face_materials"]
	var vc_meshes: Array = manifest["vertex_color_meshes"]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := String(mi.name)
		if mi.mesh.get_blend_shape_count() > 0:
			_blend_meshes.append(mi)
		if textures.has(mesh_name):
			var mat := _paint(0, load(dir + textures[mesh_name]))
			mat.next_pass = _ink(2.4)
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)
		elif mesh_name in vc_meshes:
			var mat := _paint(1)
			mat.next_pass = _ink(2.0)
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)
		else:   # face features: flat painted colours per surface, iris texture tinted by eye colour
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var mname := src.resource_name if src else ""
				var info: Dictionary = face_mats.get(mname, {"srgb": [128, 128, 128]})
				var unlit := mname in ["MAT_Eye_White", "M9_Eye_Shine", "M9_Pupil", "M9_Face_Ink", "CA_Sclera_Shade"]
				var mat: ShaderMaterial
				if mname == "MAT_Skin" and mesh_name in manifest.get("skin_vertex_color_meshes", []):
					mat = _paint(1)     # lid caps: baked head colour sampled into vertex colours
				elif mname == "CA_Iris":
					mat = _paint(0, load(dir + "textures/iris.png"), Color.WHITE, true)
					mat.set_shader_parameter("tint", _srgb(manifest["eye_srgb"]))
					mat.set_shader_parameter("retro_detail", 4.0)   # big anime eyes stay readable in PS2 mode
				else:
					mat = _paint(2, null, _srgb(info["srgb"]), unlit)
					mat.set_shader_parameter("retro_detail", 3.0)
				mi.set_surface_override_material(s, mat)


func _collect_hair() -> void:
	var names: Dictionary = manifest["hair"]["meshes"]
	for state in names:
		var found := model.find_child(names[state], true, false)
		if found is MeshInstance3D:
			hair_meshes[StringName(state)] = found


# ------------------------------------------------------------------ hair growth
func growth_for_day(day: float) -> float:
	var days: float = manifest["hair"]["days_to_overgrown"]
	return clampf((day - last_service_day) * growth_rate / maxf(days, 0.001), 0.0, 1.0)


func state_for_growth(g: float) -> StringName:
	var t: Dictionary = manifest["hair"]["thresholds"]
	if g >= float(t["overgrown"]):
		return &"overgrown"
	if g >= float(t["needs_maintenance"]):
		return &"needs_maintenance"
	return &"fresh"


func set_hair_state(state: StringName) -> void:
	for s in hair_meshes:
		hair_meshes[s].visible = (s == state)
	if state != hair_state:
		hair_state = state
		hair_state_changed.emit(state)
	hair_state = state


func update_growth(day: float) -> void:
	set_hair_state(state_for_growth(growth_for_day(day)))


## Barber / stylist / braider / loctician. cost_hook: Callable(character_name, cost: Dictionary) -> bool.
func perform_service(provider: String, service: String, day: float, cost_hook := Callable()) -> Dictionary:
	var spec: Dictionary = manifest["services"][provider]
	var structure: String = manifest["hair"]["structure"]
	if not (spec["structures"] as Array).has(structure):
		return {"ok": false, "reason": "%s does not handle %s styles" % [spec["label"], structure]}
	var item: Dictionary = spec["services"][service]
	if cost_hook.is_valid() and not cost_hook.call(character_name, item["cost"]):
		return {"ok": false, "reason": "cost not paid", "cost": item["cost"]}
	last_service_day = day
	update_growth(day)
	return {"ok": true, "provider": provider, "service": service, "cost": item["cost"]}


# ------------------------------------------------------------------ face
func _set_shape(shape: String, value: float) -> void:
	for mi in _blend_meshes:
		var i := mi.find_blend_shape_by_name(shape)
		if i >= 0:
			mi.set_blend_shape_value(i, value)


## Fitness drift body: blends the Body_Lean / Body_Stocky / Body_Athletic / Body_Bulk archetype shapes (body, garments
## and neck together). mass, muscle in 0..1; 0.5 / 0.5 is the character's authored build.
func set_body(mass: float, muscle: float) -> void:
	var a := 2.0 * clampf(mass, 0.0, 1.0) - 1.0
	var b := 2.0 * clampf(muscle, 0.0, 1.0) - 1.0
	var pa := maxf(0.0, a)
	var pb := maxf(0.0, b)
	_set_shape("Body_Lean", maxf(0.0, -a) * (1.0 - pb))
	_set_shape("Body_Stocky", pa * (1.0 - pb))
	_set_shape("Body_Athletic", b * (1.0 - pa))
	_set_shape("Body_Bulk", pa * pb)


## Jaw strength (TR_Jaw): 0 = the base jaw, 1 = square and strong. Every character holds JAW_DEFAULT unless the
## creator's Jaw slider moves it.
const JAW_DEFAULT := 0.6

func set_jaw(amount: float) -> void:
	_set_shape("TR_Jaw", clampf(amount, 0.0, 1.5))

## The Dragon Quest eye read (TR_Eye_DQ): flattens the opening toward DQ8's almond and sets the eyes further apart.
## 0 keeps the old rounder eye, 1 is the full DQ read.
const EYE_DQ_DEFAULT := 0.0   # the DQ eye shape is baked into the mesh now; the key only exists on older exports

## Body-type width channels (tr_fit_fixes.WIDTH_KEYS). 0 = the base body.
const WIDTHS := {"hips": "TR_Hip_Width", "waist": "TR_Waist_Width", "chest": "TR_Chest_Width"}

func set_widths(values: Dictionary) -> void:
	for key in WIDTHS:
		if values.has(key):
			_set_shape(WIDTHS[key], clampf(float(values[key]), -0.5, 1.5))

## Ear shapes (TR_Ear_*): size, elf point and how far they stick out. All 0 by default.
const EARS := {"size": "TR_Ear_Big", "point": "TR_Ear_Point", "out": "TR_Ear_Out"}

func set_ears(values: Dictionary) -> void:
	for key in EARS:
		if values.has(key):
			_set_shape(EARS[key], clampf(float(values[key]), -1.0, 1.5))

func set_eye_dq(amount: float) -> void:
	_set_shape("TR_Eye_DQ", clampf(amount, 0.0, 1.0))

## 0 = Dragon Quest VIII eyes, 1 = Dragon Ball-influenced (sharper lid, heavier brows). Any value in between blends.
func set_eye_style(value: float) -> void:
	_eye_style = clampf(value, 0.0, 1.0)
	_set_shape("Eye_Style_DB", _eye_style)
	_set_shape("Brow_Style_DB", _eye_style)


func set_expression(expr: String, weight := 1.0, clear_others := true) -> void:
	if clear_others:
		for e in EXPRESSIONS:
			_expr[e] = 0.0
	_expr[expr] = weight
	for e in _expr:
		_set_shape("Expr_" + e, _expr[e])
	_update_anime_eye()


# ------------------------------------------------------------------ drawn anime eye
## The drawn eye (character/toriyama_kit/anime_eye) cannot blend shapes - each expression is its own drawing - so the
## blink and the strongest expression pick a frame. Materials are registered by whoever builds the eye cards.
const ANIME_EYE_FRAMES := ["open", "half", "closed", "happy", "angry", "surprised", "sad"]
const ANIME_EYE_EXPRESSION_FRAME := {"Happy": "happy", "Laughing": "happy", "Angry": "angry", "Determined": "angry",
	"Surprised": "surprised", "Sad": "sad", "Worried": "sad", "Embarrassed": "half", "Smug": "half"}
var anime_eye_materials: Array[ShaderMaterial] = []
var _look := Vector2.ZERO

func _anime_eye_frame(blink: float) -> String:
	if blink > 0.6:
		return "closed"
	var best := ""
	var best_w := 0.3
	for e in _expr:
		if float(_expr[e]) > best_w:
			best = e
			best_w = float(_expr[e])
	if blink > 0.25:
		return "happy" if ANIME_EYE_EXPRESSION_FRAME.get(best, "") == "happy" else "half"
	return ANIME_EYE_EXPRESSION_FRAME.get(best, "open")

## A change of expression cross-fades over ANIME_EYE_FADE seconds; a blink cuts (a fading blink reads as a ghost).
const ANIME_EYE_FADE := 0.08
var _ae_frame := 0
var _ae_prev := 0
var _ae_fade := 1.0

## The drawn mouth (anime_mouth.gdshader) follows the strongest expression; blinks don't touch it.
const ANIME_MOUTH_FRAMES := ["neutral", "smile", "grin", "laugh", "o", "shout", "frown", "tight", "smirk", "small",
	"talk_a", "talk_e", "talk_o"]
const ANIME_MOUTH_EXPRESSION_FRAME := {"Happy": "grin", "Laughing": "laugh", "Angry": "shout", "Determined": "tight",
	"Surprised": "o", "Sad": "frown", "Worried": "frown", "Embarrassed": "small", "Smug": "smirk"}
var anime_mouth_materials: Array[ShaderMaterial] = []
var _am_frame := 0
var _am_prev := 0
var _am_fade := 1.0

func _anime_mouth_frame() -> String:
	if _syllable != "":
		return _syllable
	var best := ""
	var best_w := 0.3
	for e in _expr:
		if float(_expr[e]) > best_w:
			best = e
			best_w = float(_expr[e])
	return ANIME_MOUTH_EXPRESSION_FRAME.get(best, "neutral")

func _update_anime_mouth() -> void:
	if anime_mouth_materials.is_empty():
		return
	var frame := ANIME_MOUTH_FRAMES.find(_anime_mouth_frame())
	if frame != _am_frame:
		_am_prev = _am_frame
		_am_frame = frame
		_am_fade = 1.0 if _talk_left > 0.0 else 0.0     # speech cuts between shapes; expressions blend
	for m in anime_mouth_materials:
		m.set_shader_parameter("frame_index", _am_frame)
		m.set_shader_parameter("frame_prev", _am_prev)
		m.set_shader_parameter("fade", _am_fade)

func _update_anime_eye(blink := 0.0) -> void:
	_update_anime_mouth()
	if anime_eye_materials.is_empty():
		return
	var frame := ANIME_EYE_FRAMES.find(_anime_eye_frame(blink))
	if frame != _ae_frame:
		_ae_prev = _ae_frame
		_ae_frame = frame
		_ae_fade = 1.0 if blink > 0.0 else 0.0
	for m in anime_eye_materials:
		m.set_shader_parameter("frame_index", _ae_frame)
		m.set_shader_parameter("frame_prev", _ae_prev)
		m.set_shader_parameter("fade", _ae_fade)
		m.set_shader_parameter("look", _look)

func _step_anime_eye_fade(delta: float) -> void:
	if _am_fade < 1.0:
		_am_fade = minf(1.0, _am_fade + delta / ANIME_EYE_FADE)
		for m in anime_mouth_materials:
			m.set_shader_parameter("fade", _am_fade)
	if _ae_fade >= 1.0 or anime_eye_materials.is_empty():
		return
	_ae_fade = minf(1.0, _ae_fade + delta / ANIME_EYE_FADE)
	for m in anime_eye_materials:
		m.set_shader_parameter("fade", _ae_fade)

# ------------------------------------------------------------------ talking
## Talking = the babble voice (voice.gd: a made-up language, one syllable sample per syllable, this character's own
## pitch) with the mouth following each syllable's vowel: open for most of the syllable, a closed beat at its end and
## in the gaps between words. Drawn mouth: the talk_* frames. Modelled mouth (no speaking shapes of its own): its
## round (Expr_Surprised) and open (Expr_Laughing) shapes pulsed on the Mouth mesh only, eyes untouched.
## A character with no voice (none assigned) still moves its mouth, with random syllables and no sound.
const TALK_SYLLABLE := Vector2(0.07, 0.15)
const TALK_SHAPES := {"talk_a": 0.34, "talk_e": 0.22, "talk_o": 0.14, "small": 0.16, "neutral": 0.14}
const MOUTH_OPEN_PART := 0.7            # of each syllable; the rest closes toward the next
var voice: ToriyamaVoice = null
var _talk_left := 0.0
var _syllable_left := 0.0
var _syllable := ""
var _speech: Array = []                  # planned syllables (voice.plan)
var _speech_i := -1
var _speech_phase := ""                  # "open" | "close" | "gap"
var _voice_player: AudioStreamPlayer3D = null

## Talk for `seconds` (extends a talk already running): wordless chatter.
func talk(seconds: float) -> void:
	if voice:
		if _speech.is_empty():
			_start_speech(voice.plan_babble(seconds))
		return
	_talk_left = maxf(_talk_left, seconds)

## How long a line of dialogue takes to say without a voice: ~18 characters a second, 0.8-5 s.
static func talk_seconds(line: String) -> float:
	return clampf(line.length() * 0.055, 0.8, 5.0)

## Say a line: the voice speaks it syllable by syllable; the mouth follows.
func talk_line(line: String) -> void:
	if voice:
		_start_speech(voice.plan(line))
	else:
		talk(talk_seconds(line))

func is_talking() -> bool:
	return _talk_left > 0.0

func stop_talking() -> void:
	_talk_left = 0.0
	_speech.clear()
	_speech_i = -1
	if _voice_player:
		_voice_player.stop()

func _start_speech(plan: Array) -> void:
	_speech = plan
	_speech_i = -1
	_speech_phase = "gap"
	_syllable_left = 0.0
	_talk_left = 0.0
	for syl in plan:
		_talk_left += voice.duration(syl) + float(syl["gap"])
	_talk_left = maxf(_talk_left, 0.05)

func _next_syllable() -> void:
	_speech_i += 1
	if _speech_i >= _speech.size():
		_speech.clear()
		_talk_left = 0.0
		_syllable = ""
		return
	var syl: Dictionary = _speech[_speech_i]
	_speech_phase = "open"
	_syllable = String(syl["mouth"])
	_syllable_left = voice.duration(syl) * MOUTH_OPEN_PART
	_play_syllable(syl)

func _play_syllable(syl: Dictionary) -> void:
	var stream := ToriyamaVoice.sample(String(syl["name"]))
	if stream == null:
		return
	if _voice_player == null:
		_voice_player = AudioStreamPlayer3D.new()
		_voice_player.name = "Voice"
		_voice_player.unit_size = 3.0
		_voice_player.max_distance = 30.0
		add_child(_voice_player)
	if skeleton:
		_voice_player.global_position = eye_world_position()
	_voice_player.stream = stream
	_voice_player.pitch_scale = voice.pitch * float(syl["pitch"]) * voice.speed * randf_range(0.98, 1.02)
	_voice_player.volume_db = linear_to_db(float(syl["loud"]))
	_voice_player.play()

func _update_talk(delta: float) -> void:
	if not _speech.is_empty():
		_talk_left = maxf(0.0, _talk_left - delta)
		_syllable_left -= delta
		while _syllable_left <= 0.0 and not _speech.is_empty():
			if _speech_phase == "open":
				var syl: Dictionary = _speech[_speech_i]
				_speech_phase = "close"
				_syllable = "small"
				_syllable_left += voice.duration(syl) * (1.0 - MOUTH_OPEN_PART)
			elif _speech_phase == "close" and float(_speech[_speech_i]["gap"]) > 0.0:
				_speech_phase = "gap"
				_syllable = "neutral"
				_syllable_left += float(_speech[_speech_i]["gap"])
			else:
				_next_syllable()
				if _speech.is_empty():
					break
		if _speech.is_empty():
			_talk_left = 0.0
			_syllable = ""
		_apply_talk()
		return
	if _talk_left <= 0.0 and _syllable == "":
		return
	_talk_left -= delta
	_syllable_left -= delta
	if _talk_left <= 0.0:
		_talk_left = 0.0
		_syllable = ""
	elif _syllable_left <= 0.0:
		_syllable_left = randf_range(TALK_SYLLABLE.x, TALK_SYLLABLE.y)
		var closed := _syllable in ["small", "neutral"]
		var pick := _syllable
		while pick == _syllable:           # never hold the same shape twice; after a closed beat, open up
			var r := randf()
			for s in TALK_SHAPES:
				r -= TALK_SHAPES[s]
				if r <= 0.0:
					pick = s
					break
			if closed and pick in ["small", "neutral"]:
				pick = _syllable
		_syllable = pick
	_apply_talk()

func _apply_talk() -> void:
	_update_anime_mouth()
	var o := 0.55 if _syllable == "talk_o" else 0.0
	var a := 0.45 if _syllable == "talk_a" else (0.25 if _syllable == "talk_e" else 0.0)
	for mi in _blend_meshes:
		if String(mi.name) != "Mouth":
			continue
		for pair in [["Expr_Surprised", o, "Surprised"], ["Expr_Laughing", a, "Laughing"]]:
			var i := mi.find_blend_shape_by_name(pair[0])
			if i >= 0:
				mi.set_blend_shape_value(i, minf(1.0, float(_expr.get(pair[2], 0.0)) + float(pair[1])))


## Where the eyes look, fixed: x toward the character's left, y up, each -1..1. Overrides look_target and the idle
## glances until clear_look(). (Tests and cutscenes; gameplay sets look_target instead.)
func set_look(v: Vector2) -> void:
	_look_override = v.clamp(Vector2(-1, -1), Vector2(1, 1))
	_gaze = _look_override
	_apply_gaze()

func clear_look() -> void:
	_look_override = null


# ------------------------------------------------------------------ gaze
## What the eyes follow: another character, the player, an object. null = idle glances. The eyes turn toward it
## within the head's range (LOOK_YAW / LOOK_PITCH map to full deflection) and give up when it is behind the head.
## Works for both eyes: the drawn anime eye slides its iris, the modelled eye blends its Look_* shapes.
var look_target: Node3D = null
const LOOK_YAW := deg_to_rad(38.0)
const LOOK_PITCH := deg_to_rad(26.0)
const LOOK_GIVE_UP := deg_to_rad(105.0)
const EYE_HEIGHT_ON_HEAD := 0.10          # eyes above the head joint, along the head bone (metres, before head scale)
var _look_override = null
var _gaze := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_timer := 2.0

## The point between the eyes, in world space (follows the animated head).
func eye_world_position() -> Vector3:
	var h := skeleton.find_bone("DEF-head") if skeleton else -1
	if h < 0:
		return global_position + Vector3(0, 1.5, 0)
	return skeleton.global_transform * (skeleton.get_bone_global_pose(h) * Vector3(0, EYE_HEIGHT_ON_HEAD, 0))

## Where to look on a node: a character's eyes (so gazes meet), else a point at head height above it.
static func gaze_point(node: Node3D) -> Vector3:
	if node is ToriyamaCharacter:
		return (node as ToriyamaCharacter).eye_world_position()
	var rig = node.get("body")
	if rig is Node and rig.get("model") is ToriyamaCharacter:
		return (rig.get("model") as ToriyamaCharacter).eye_world_position()
	if node.get("model") is ToriyamaCharacter:
		return (node.get("model") as ToriyamaCharacter).eye_world_position()
	return node.global_position + Vector3(0, 0.25 if node.is_in_group("basketballs") else 1.45, 0)

## The head's world frame: -Z forward, +Y up, -X the character's left. The body's frame turned by the head bone.
func _head_basis() -> Basis:
	var body_basis := global_transform.basis.orthonormalized()
	var h := skeleton.find_bone("DEF-head") if skeleton else -1
	if h < 0 or h >= _rest_global.size():
		return body_basis
	var s := skeleton.global_transform.basis.orthonormalized()
	var turn := skeleton.get_bone_global_pose(h).basis.orthonormalized() * _rest_global[h].inverse()
	return (s * turn * s.inverse()) * body_basis

## Target direction -> eye deflection (-1..1 each), or null when the target is behind the head.
func _gaze_toward(point: Vector3) -> Variant:
	var local := _head_basis().inverse() * (point - eye_world_position())
	var yaw := atan2(-local.x, -local.z)
	if absf(yaw) > LOOK_GIVE_UP:
		return null
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	return Vector2(clampf(yaw / LOOK_YAW, -1.0, 1.0), clampf(pitch / LOOK_PITCH, -1.0, 1.0))

func _update_gaze(delta: float) -> void:
	var goal = _look_override
	if goal == null and is_instance_valid(look_target):
		goal = _gaze_toward(gaze_point(look_target))
	if goal == null:
		# nobody to look at: small glances around, often back to centre
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = randf_range(1.2, 3.5)
			_glance = Vector2.ZERO if randf() < 0.45 else Vector2(randf_range(-0.45, 0.45), randf_range(-0.2, 0.15))
		goal = _glance
	# eyes jump rather than drift: close most of the gap within a few frames
	_gaze = _gaze.lerp(goal, 1.0 - exp(-delta * 22.0))
	_apply_gaze()

func _apply_gaze() -> void:
	_look = _gaze
	for m in anime_eye_materials:
		m.set_shader_parameter("look", _look)
	_set_shape("Look_Left", maxf(0.0, _gaze.x))
	_set_shape("Look_Right", maxf(0.0, -_gaze.x))
	_set_shape("Look_Up", maxf(0.0, _gaze.y))
	_set_shape("Look_Down", maxf(0.0, -_gaze.y))


## Anchors: hair swings off the head, clothing off the waist. Model space, so the skeleton pose does not matter.
func head_anchor() -> Vector3:
	var bone := skeleton.find_bone("DEF-head") if skeleton else -1
	return skeleton.get_bone_global_rest(bone).origin if bone >= 0 else Vector3(0, 1.62, 0)

func waist_anchor() -> Vector3:
	var bone := skeleton.find_bone("DEF-spine") if skeleton else -1
	return skeleton.get_bone_global_rest(bone).origin if bone >= 0 else Vector3(0, 1.05, 0)

## Hair sway is off for now (the user did not like the look); clothing still sways. Flip this back on to restore it.
const HAIR_MOTION := false

## Which meshes sway: the hair states, and clothing (anything that is not body, head or a face feature).
func _register_motion() -> void:
	motion.clear()
	var body_meshes := ["Body_Base", "Head_Base", "DQ8_Neck_Shadow", "Nose_Bridge", "Nose_Tip", "Mouth", "Blush",
		"Eye_L", "Eye_R", "Brow_L", "Brow_R", "AE_Eye_L", "AE_Eye_R", "AE_Brow_L", "AE_Brow_R", "AE_Mouth"]
	var head := head_anchor()
	var waist := waist_anchor()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var is_hair := false
		for state in hair_meshes:
			var value = hair_meshes[state]
			# one mesh per state on a baked character, a list of pieces on a kit character
			if value is Array:
				if (value as Array).has(mi):
					is_hair = true
			elif value == mi:
				is_hair = true
		if not is_hair and String(mi.name) in body_meshes:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			if mat == null:
				continue
			if is_hair:
				if not HAIR_MOTION:
					continue          # hair sway is off (user, 2026-09-22: "doesn't look how I wanted")
				# hair carrying TR_Strand (root->tip in its UVs; older hair exports have no UVs at all) sways by strand
				var strands: bool = (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV) != 0
				motion.register(mat, "hair", head, 1.0, -1.0, 2 if strands else -1)
			else:
				motion.register(mat, "cloth", waist, 0.85)

func _process(delta: float) -> void:
	motion.update(delta, global_transform)
	_step_anime_eye_fade(delta)
	_update_gaze(delta)
	_update_talk(delta)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 6.0)
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta * 7.0)
		_set_shape("Expr_Blink", sin(_blink * PI))
		_update_anime_eye(sin(_blink * PI))


# ------------------------------------------------------------------ skeleton
func _prepare_skeleton() -> void:
	var count := skeleton.get_bone_count()
	_rest_global.resize(count)
	for b in count:
		_rest_global[b] = skeleton.get_bone_global_rest(b).basis.orthonormalized()
		var bname := skeleton.get_bone_name(b)
		if BONE_PIVOTS.has(bname):
			_pivot_bone[b] = BONE_PIVOTS[bname]
	_root_bone = skeleton.find_bone("DEF-pelvis")
	# Hanging alignment per chain: rotate the chain's first bone direction (T-pose) to straight down in skeleton space.
	for chain in ALIGN_CHAINS.values():
		var a := skeleton.find_bone(chain[0])
		var c := skeleton.find_bone(chain[1])
		if a < 0 or c < 0:
			continue
		var d := (skeleton.get_bone_global_rest(c).origin - skeleton.get_bone_global_rest(a).origin).normalized()
		var q := Quaternion(d, Vector3.DOWN)
		for bn in chain:
			var bi := skeleton.find_bone(bn)
			if bi >= 0:
				_align[bi] = q


## Proportions live on the bones, set once (sync_from_rig only writes rotations and the pelvis bob, so they persist).
## Same numbers as work/toriyama_system/tr_character.py:
##   head: a uniform pose scale on DEF-head, pivoting at the neck joint, so the face, hair, beard and hats follow.
##     0.80 is every character's size (user decision 2026-09-18: ~6.5-7 heads tall, like the reference sheets).
##   legs: DEF-thigh.L/.R stretched along their length by k = 1 + 0.085 * leg_length (the shin hangs off the thigh
##     and inherits it), and the root raised by (k - 1) * 0.91 m (hip height) so the feet stay on the floor.
##     This replaces the TR_Leg_Length shape key, which left hair and hats behind; that key is held at 0.
const HEAD_SCALE := 0.80
const LEG_RANGE := 0.085
const LEG_REST := 0.91
var head_scale := HEAD_SCALE
var leg_length := 0.0

func set_proportions(head: float, legs: float) -> void:
	head_scale = clampf(head, 0.5, 1.5)
	leg_length = clampf(legs, -1.0, 1.0)
	_set_shape("TR_Leg_Length", 0.0)
	if skeleton == null:
		return
	var h := skeleton.find_bone("DEF-head")
	if h >= 0:
		skeleton.set_bone_pose_scale(h, Vector3.ONE * head_scale)
	var k := 1.0 + LEG_RANGE * leg_length
	for bone_name in ["DEF-thigh.L", "DEF-thigh.R"]:
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			skeleton.set_bone_pose_scale(b, Vector3(1.0, k, 1.0))
	var root := skeleton.find_bone("root")
	if root >= 0:
		skeleton.set_bone_pose_position(root, skeleton.get_bone_rest(root).origin + Vector3(0.0, (k - 1.0) * LEG_REST, 0.0))


## Called by CharacterRig.animate() after it has posed its pivots.
func sync_from_rig(rig: Node3D, pivots: Dictionary, torso_rest_y: float) -> void:
	if skeleton == null:
		return
	var to_skel := (skeleton.global_basis.orthonormalized().inverse() * rig.global_basis.orthonormalized()).get_rotation_quaternion()
	var rig_inv := rig.global_basis.orthonormalized().inverse()
	var global_rot: Array[Quaternion] = []
	global_rot.resize(skeleton.get_bone_count())
	for b in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(b)
		var rest_local := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
		var parent_rot := global_rot[parent] if parent >= 0 else Quaternion.IDENTITY
		var g := parent_rot * rest_local
		if _pivot_bone.has(b) and pivots.has(_pivot_bone[b]):
			var pivot: Node3D = pivots[_pivot_bone[b]]
			var q_rig := (rig_inv * pivot.global_basis.orthonormalized()).get_rotation_quaternion()
			var q_skel := to_skel * q_rig * to_skel.inverse()
			g = q_skel * _align.get(b, Quaternion.IDENTITY) * _rest_global[b].get_rotation_quaternion()
		global_rot[b] = g
		skeleton.set_bone_pose_rotation(b, (parent_rot.inverse() * g).normalized())
	if _root_bone >= 0 and pivots.has("torso"):
		var bob: float = (pivots["torso"] as Node3D).position.y - torso_rest_y
		var rest_pos := skeleton.get_bone_rest(_root_bone).origin
		skeleton.set_bone_pose_position(_root_bone, rest_pos + to_skel * Vector3(0, bob, 0))


## Sockets that follow skeleton bones, oriented like the rig at rest so existing item offsets still fit.
func make_sockets(rig: Node3D) -> Dictionary:
	var out := {}
	for slot in SOCKET_BONES:
		var bone := skeleton.find_bone(SOCKET_BONES[slot])
		if bone < 0:
			continue
		var att := BoneAttachment3D.new()
		att.name = "Attach_" + slot
		att.bone_name = SOCKET_BONES[slot]
		skeleton.add_child(att)
		var socket := Node3D.new()
		socket.name = "Socket" + String(slot).to_pascal_case()
		att.add_child(socket)
		out[slot] = socket
	return out


## After the first pose: orient each socket like the rig (the frame item offsets were authored in).
func orient_sockets(rig: Node3D, sockets: Dictionary) -> void:
	for slot in sockets:
		var s: Node3D = sockets[slot]
		if not is_instance_valid(s) or s.get_parent() == null:
			continue          # a rebuilt body (e.g. switching body type) freed the old sockets
		var parent_basis := (s.get_parent() as Node3D).global_basis.orthonormalized()
		s.basis = parent_basis.inverse() * rig.global_basis.orthonormalized()
		if slot == "accessory":
			s.global_position = (s.get_parent() as Node3D).global_position + rig.global_basis * Vector3(0, 0.05, -0.16)
