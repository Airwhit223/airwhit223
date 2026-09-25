class_name RuinEnemy
extends CharacterBody3D
## One readable enemy prototype: detect, chase, telegraph, strike, flinch, die.
## `kind` picks a variant from KINDS (set it before adding to the tree) - the contract factions: Goblins (small, fast,
## weak), Skeletons (slow, tough), Hollowed Moon thugs (hit hard). Defeats report kind + faction + zone so contract
## objectives can count them.

const DETECT_RADIUS := 10.0
const LEASH_RADIUS := 18.0
const ATTACK_RANGE := 1.65
const KINDS := {
	"ruin_beast": {"label": "Ruin Enemy", "faction": "ruin", "health": 30, "speed": 2.7, "damage": 8, "cooldown": 1.5,
		"windup": 0.45, "radius": 0.35, "height": 1.2, "color": Color(0.35, 0.16, 0.32), "eye": Color(1.0, 0.55, 0.1)},
	"goblin": {"label": "Goblin", "faction": "goblins", "health": 20, "speed": 3.6, "damage": 5, "cooldown": 1.1,
		"windup": 0.35, "radius": 0.28, "height": 0.95, "color": Color(0.35, 0.6, 0.25), "eye": Color(1.0, 0.9, 0.2)},
	"skeleton": {"label": "Skeleton", "faction": "undead", "health": 40, "speed": 2.1, "damage": 8, "cooldown": 1.7,
		"windup": 0.55, "radius": 0.3, "height": 1.6, "color": Color(0.88, 0.85, 0.76), "eye": Color(0.4, 0.9, 1.0)},
	"moon_thug": {"label": "Hollowed Moon Thug", "faction": "hollowed_moon", "health": 45, "speed": 2.8, "damage": 12,
		"cooldown": 1.6, "windup": 0.5, "radius": 0.38, "height": 1.5, "color": Color(0.22, 0.2, 0.32), "eye": Color(0.75, 0.6, 1.0)},
}

var kind := "ruin_beast"
## the dungeon / area this enemy belongs to (reported on defeat)
var zone := ""
var MOVE_SPEED := 2.7
var ATTACK_COOLDOWN := 1.5
var ATTACK_WINDUP := 0.45
var MAX_HEALTH := 30
var damage := 8
var health: int = MAX_HEALTH
var home_position: Vector3
var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _telegraph: MeshInstance3D
var _body_mesh: MeshInstance3D
var _body_material: StandardMaterial3D
var _dead: bool = false
var enemy_id: String = "ruin_beast"

func _ready() -> void:
	var k: Dictionary = KINDS.get(kind, KINDS["ruin_beast"])
	MOVE_SPEED = float(k["speed"]); ATTACK_COOLDOWN = float(k["cooldown"]); ATTACK_WINDUP = float(k["windup"])
	MAX_HEALTH = int(k["health"]); health = MAX_HEALTH; damage = int(k["damage"])
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	home_position = global_position
	_build_visual()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var player := WorldState.player
	if player == null or not AdventureManager.player_in_danger:
		velocity = Vector3.ZERO
		return
	var distance_home := global_position.distance_to(home_position)
	var distance_player := global_position.distance_to(player.global_position)
	if distance_home > LEASH_RADIUS or distance_player > DETECT_RADIUS:
		velocity = Vector3.ZERO
		return
	if _windup_timer > 0.0:
		_windup_timer -= delta
		velocity = Vector3.ZERO
		_telegraph.visible = true
		if _windup_timer <= 0.0:
			_telegraph.visible = false
			if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 0.25 and not player.is_dodging:
				player.take_damage(damage, global_position)
			_attack_timer = ATTACK_COOLDOWN
		return
	if distance_player <= ATTACK_RANGE:
		velocity = Vector3.ZERO
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		if _attack_timer <= 0.0:
			_windup_timer = ATTACK_WINDUP
		return
	var direction := player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		look_at(global_position + direction, Vector3.UP)
	move_and_slide()

func take_damage(amount: int, hit_origin: Vector3 = Vector3.ZERO) -> void:
	if _dead:
		return
	health = maxi(0, health - amount)
	if hit_origin != Vector3.ZERO:
		var knockback := global_position - hit_origin
		knockback.y = 0.0
		if knockback.length_squared() > 0.01:
			global_position += knockback.normalized() * 0.22
	EventBus.fire("enemy_hit", {"enemy_id": enemy_id, "health": health})
	if _body_material:
		_body_material.albedo_color = Color(1.0, 0.35, 0.25)
		get_tree().create_timer(0.1).timeout.connect(_clear_hit_flash)
	if health <= 0:
		_dead = true
		var k: Dictionary = KINDS.get(kind, KINDS["ruin_beast"])
		AdventureManager.register_enemy_defeat(enemy_id, kind, String(k["faction"]), zone)
		EventBus.fire("hud_message", {"text": "%s defeated." % k["label"]})
		queue_free()

func _clear_hit_flash() -> void:
	if is_instance_valid(_body_material):
		_body_material.albedo_color = KINDS.get(kind, KINDS["ruin_beast"])["color"]

func _build_visual() -> void:
	var k: Dictionary = KINDS.get(kind, KINDS["ruin_beast"])
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = k["radius"]
	capsule.height = k["height"]
	shape.shape = capsule
	shape.position.y = k["height"] / 2.0
	add_child(shape)
	_body_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = k["radius"]
	mesh.height = k["height"]
	_body_mesh.mesh = mesh
	_body_mesh.position.y = k["height"] / 2.0
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = k["color"]
	_body_mesh.material_override = _body_material
	add_child(_body_mesh)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.09
	eye_mesh.height = 0.18
	eye.mesh = eye_mesh
	eye.position = Vector3(0, float(k["height"]) * 0.73, -float(k["radius"]) + 0.04)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = k["eye"]
	eye_mat.emission_enabled = kind != "ruin_beast"
	eye_mat.emission = k["eye"]
	eye.material_override = eye_mat
	add_child(eye)
	_telegraph = MeshInstance3D.new()
	var telegraph_mesh := SphereMesh.new()
	telegraph_mesh.radius = 0.52
	telegraph_mesh.height = 0.06
	_telegraph.mesh = telegraph_mesh
	_telegraph.position.y = 0.04
	var telegraph_mat := StandardMaterial3D.new()
	telegraph_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.58)
	telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph.material_override = telegraph_mat
	_telegraph.visible = false
	add_child(_telegraph)
	var label := Label3D.new()
	label.text = k["label"]
	label.font_size = 24
	label.outline_size = 5
	label.position.y = float(k["height"]) + 0.15
	add_child(label)
