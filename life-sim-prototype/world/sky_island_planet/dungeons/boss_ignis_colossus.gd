class_name BossIgnisColossus
extends CharacterBody3D
## Ignis Primal Colossus: Elemental Fire Cave Boss of the Cosmic Origin Planet.
## An ancient sentient magma guardian constructed of obsidian stone and primordial stellar fire.
## Defeating this boss unlocks the permanent 'Heat Resistance' passive trait.

signal boss_damaged(current_hp: float, max_hp: float)
signal boss_defeated()
signal attack_executed(attack_name: String)

@export var max_health: float = 300.0
var current_health: float = 300.0
var is_defeated: bool = false
var is_enraged: bool = false

@export var attack_cooldown: float = 2.4
var _cooldown_timer: float = 0.0

var _target: Node3D = null

func _ready() -> void:
	add_to_group("boss")
	current_health = max_health
	_find_target()

func _find_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if is_defeated:
		return

	if _target == null:
		_find_target()

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0 and _target != null:
		_perform_combat_cycle()
		_cooldown_timer = attack_cooldown * (0.65 if is_enraged else 1.0)

	# Face towards target
	if _target != null:
		var dir := (_target.global_position - global_position)
		dir.y = 0
		if dir.length() > 0.5:
			look_at(global_position + dir.normalized(), Vector3.UP)

func _perform_combat_cycle() -> void:
	var dist := global_position.distance_to(_target.global_position)
	if dist < 6.0:
		execute_magma_stomp()
	else:
		execute_flame_burst()

func execute_magma_stomp() -> void:
	attack_executed.emit("Magma Stomp")
	# Stomp AoE impact around boss
	var hit_area := get_node_or_null("StompArea") as Area3D
	if hit_area:
		for body in hit_area.get_overlapping_bodies():
			_apply_fire_damage_to(body, 25.0)

func execute_flame_burst() -> void:
	attack_executed.emit("Flame Burst")
	# Forward cone of fire
	var hit_cone := get_node_or_null("FlameCone") as Area3D
	if hit_cone:
		for body in hit_cone.get_overlapping_bodies():
			_apply_fire_damage_to(body, 20.0)

func _apply_fire_damage_to(body: Node, base_damage: float) -> void:
	if body == self:
		return
	if body.has_method("take_elemental_damage"):
		body.take_elemental_damage(base_damage, "fire")
	elif body.has_method("take_damage"):
		# Check if target player has heat resistance
		var pc = body.get("power_controller")
		if pc and pc.profile and pc.profile.has_resistance("heat"):
			return # Fully immune!
		body.take_damage(base_damage)

func take_damage(amount: float) -> void:
	if is_defeated:
		return
	current_health = maxf(0.0, current_health - amount)
	boss_damaged.emit(current_health, max_health)

	if current_health <= max_health * 0.5 and not is_enraged:
		is_enraged = true
		_enter_enrage_mode()

	if current_health <= 0.0:
		_die()

func _enter_enrage_mode() -> void:
	var core_light := get_node_or_null("MagmaFurnaceCore/CoreLight") as OmniLight3D
	if core_light:
		core_light.light_energy = 5.5
		core_light.light_color = Color(1.0, 0.3, 0.05)

func _die() -> void:
	is_defeated = true
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_reward_player(player)
	boss_defeated.emit()

	# Death tween: sink and fade
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 3.0, 2.0)
	tw.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 2.0)
	tw.tween_callback(func():
		var chest = get_parent().get_node_or_null("BossRewardChest")
		if chest and chest.has_method("reveal"):
			chest.reveal()
		queue_free()
	)

func _reward_player(p: Node) -> void:
	var pc = p.get("power_controller")
	if pc == null:
		pc = p.find_child("PowerController", true, false)
	if pc and pc.get("profile"):
		pc.profile.unlock_resistance("heat")
		pc.profile.add_mutation_mastery(25.0)
		pc.profile.add_magic_mastery(25.0)
