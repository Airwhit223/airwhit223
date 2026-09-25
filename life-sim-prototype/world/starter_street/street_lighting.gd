class_name StreetLighting
extends Node
## Starter Street's two lighting states (docs/STARTER_STREET.md): golden hour — the default and the first
## impression — and night. Follows TimeManager: night from NIGHT_START until DAY_START, golden hour otherwise.
##
## The toon surfaces take their shadow tone from the `world_shadow_*` shader globals (see toon_world.gdshader), so
## night is: the sun becomes a dim blue moon (not switched off — characters are lit only by lights, so with no light
## at all they go black), shadow tones dimmed and cooled, street lamps on, window glow cards brightened.

enum Preset { GOLDEN_HOUR, NIGHT }

const NIGHT_START := 20
const DAY_START := 6

const GOLDEN := {
	"sun_color": Color("#FFE0B0"), "sun_energy": 1.0,
	"shadow_tint": Color(1, 1, 1), "shadow_energy": 1.0,
	"horizon": Color("#FFD890"), "zenith": Color("#4A8CD8"), "stars": 0.0, "clouds": 0.42, "haze": 0.45,
	"sun_angle": Vector3(-30, -58, 0),
	"cloud": Color("#FFF6E8"), "cloud_shadow": Color("#E9C9B8"),
	"window_glow": 0.0, "lamp": false,
}
const NIGHT := {
	"sun_color": Color("#7F95D0"), "sun_energy": 0.35,
	"shadow_tint": Color("#7A88C0"), "shadow_energy": 0.42,
	"horizon": Color("#2A3458"), "zenith": Color("#0E1428"), "stars": 0.8, "clouds": 0.25, "haze": 0.0,
	"sun_angle": Vector3(-55, 30, 0),
	"cloud": Color("#3A4468"), "cloud_shadow": Color("#262E4C"),
	"window_glow": 1.25, "lamp": true,
}

@export var preset: Preset = Preset.GOLDEN_HOUR: set = set_preset
## Follow the game clock. Off in look tests that pin a preset.
@export var follow_time := true
@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"
## The shared glow-card material (house windows, shop window, lamp globe).
@export var window_material: ShaderMaterial
@export var lamp_material: ShaderMaterial

func _ready() -> void:
	if window_material == null:
		window_material = load("res://world/starter_street/materials/window_glow.tres")
	if lamp_material == null:
		lamp_material = load("res://world/starter_street/materials/lamp_glow.tres")
	if follow_time and has_node("/root/TimeManager"):
		var clock := get_node("/root/TimeManager")
		clock.hour_changed.connect(_on_hour)
		_on_hour(clock.hour)
	else:
		_apply()

func _on_hour(hour: int) -> void:
	var night := hour >= NIGHT_START or hour < DAY_START
	set_preset(Preset.NIGHT if night else Preset.GOLDEN_HOUR)

func set_preset(value: Preset) -> void:
	preset = value
	if is_inside_tree():
		_apply()

func _apply() -> void:
	var p: Dictionary = NIGHT if preset == Preset.NIGHT else GOLDEN
	var sun := get_node_or_null(sun_path) as DirectionalLight3D
	if sun:
		sun.light_color = p["sun_color"]
		sun.light_energy = p["sun_energy"]
		sun.rotation_degrees = p["sun_angle"]
	RenderingServer.global_shader_parameter_set("world_shadow_tint", p["shadow_tint"])
	RenderingServer.global_shader_parameter_set("world_shadow_energy", p["shadow_energy"])
	var env_node := get_node_or_null(environment_path) as WorldEnvironment
	if env_node and env_node.environment and env_node.environment.sky:
		var sky := env_node.environment.sky.sky_material as ShaderMaterial
		if sky:
			sky.set_shader_parameter("horizon_color", p["horizon"])
			sky.set_shader_parameter("zenith_color", p["zenith"])
			sky.set_shader_parameter("stars", p["stars"])
			sky.set_shader_parameter("haze", p["haze"])
			sky.set_shader_parameter("cloud_cover", p["clouds"])
			sky.set_shader_parameter("cloud_color", p["cloud"])
			sky.set_shader_parameter("cloud_shadow", p["cloud_shadow"])
	if window_material:
		window_material.set_shader_parameter("glow", p["window_glow"])
	if lamp_material:
		lamp_material.set_shader_parameter("glow", 1.4 if p["lamp"] else 0.0)
	for light in get_tree().get_nodes_in_group("street_lamp_light"):
		(light as Light3D).visible = p["lamp"]

func is_night() -> bool:
	return preset == Preset.NIGHT
