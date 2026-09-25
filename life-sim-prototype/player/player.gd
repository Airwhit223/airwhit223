class_name Player
extends CharacterBody3D
## The player. Free-roaming third-person controller plus the interaction
## foundations: talk, invite, and context-sensitive activity participation
## (basketball, gym equipment, the shop register). No separate minigame
## scenes — everything here happens in the one persistent world.

const SPEED := 4.5
const FlightControllerScript := preload("res://player/powers/flight_controller.gd")
const RUN_SPEED := 8.5          # holding sprint; the rig blends walk -> jog -> run across this range, and 8.5
                                # is where the run profile is fully in (LOCOMOTION_PROFILES.adventure_run)
const SKATE_SPEED := 7.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
## Swimming. Slower than walking on purpose: crossing water should be a decision, not a shortcut.
const SWIM_SPEED := 2.6
const SWIM_SPRINT_SPEED := 4.2
## How far the body rides under the surface while floating - about chest deep on a 1.78 m character.
const FLOAT_DEPTH := 1.15
const BUOYANCY := 9.0            # spring pulling the body back to the surface
const BUOYANCY_DAMP := 4.5       # ...and the damping that stops it bobbing forever
const SWIM_DRAIN := 3.2          # stamina per second while swimming
const SPRINT_DRAIN := 6.0
const STAMINA_REGEN := 12.0
const WADE_SLOWDOWN := 0.55
## One sword cut, start to finish. The rig's swing phase is derived from what is left of the cooldown, so the
## animation and the hitbox window are the same number and cannot drift apart.
const ATTACK_TIME := 0.55
## The katana variant the test sword shows in hand (a prop kit under character/toriyama_kit/prop/).
const SWORD_PROP := "Classic"
const MOUSE_SENSITIVITY := 0.0025
const PITCH_MIN := deg_to_rad(-60)
const PITCH_MAX := deg_to_rad(20)
const FADE_DURATION := 0.3
const SLEEP_WAKE_HOUR := 7

## Carried: parented to the rig's Back socket (same one a backpack uses),
## pushed out behind it, standing upright flat against the back.
const SKATEBOARD_CARRIED_OFFSET := Vector3(0.0, 0.0, 0.24)
const SKATEBOARD_CARRIED_ROT := Vector3(0.0, 90.0, 90.0)
## The player root sits at ground height and the rig's feet rest just above
## it, so riding lifts the whole visible body by MOUNT_LIFT to stand ON the
## board. Purely visual — the collision capsule doesn't move.
const MOUNT_LIFT := 0.095
## Relative to the (lifted) Body: board top just under the shoes, board
## bottom just above the ground and court pads.
const SKATEBOARD_MOUNTED_POS := Vector3(0.0, -0.025, 0.0)
const SKATEBOARD_MOUNTED_ROT := Vector3(0.0, 90.0, 0.0) # board length along travel direction

## Hands start empty; the sword and guitar live in the inventory wheel (Tab).
const STARTING_EQUIPMENT := ["striped_shirt", "black_pants", "white_sneakers", "black_beanie"]
const HAND_TOOL_IDS := ["test_sword", "acoustic_guitar"]

@export var player_id: String = "player"
@export var skin_tone: Color = Color(0.85, 0.68, 0.55)

var current_zone: String = ""
var has_skateboard: bool = false
var is_mounted_skateboard: bool = false
var held_ball = null
## Read-only view of the weekly-drift fitness system (PlayerStats); kept for code that reads player.fitness.
var fitness: float:
	get:
		return PlayerStats.get_fitness_level()
## Minimal placeholder rest stat — sleeping restores it. No decay system yet;
## this exists so the sleep loop has something real to restore.
## Health, Energy and Stamina all live in player/vitals.gd now. These stay as pass-throughs so the HUD, enemies
## and anything else that grew up reading `player.health` keep working unchanged.
var vitals: Vitals = null
var energy: float:
	get: return vitals.energy if vitals else 100.0
	set(v):
		if vitals: vitals.energy = clampf(v, 0.0, vitals.max_energy)
var stamina: float:
	get: return vitals.stamina if vitals else 100.0
	set(v):
		if vitals: vitals.stamina = clampf(v, 0.0, vitals.max_stamina)
var max_stamina: float:
	get: return vitals.max_stamina if vitals else 100.0
## "", "shallow", "wade" or "swim" - see world/water/water.gd.
var water_state: String = ""
var is_swimming: bool = false
var dialogue_open: bool = false
## Who the open dialogue is with (NPCs look at the player while it is them; the player's eyes hold on them).
var dialogue_partner: Node3D = null
var max_health: int:
	get: return int(vitals.max_health) if vitals else 100
var health: int:
	get: return int(vitals.health) if vitals else 100
	set(v):
		if vitals: vitals.health = clampf(float(v), 0.0, vitals.max_health)
var is_dodging: bool = false
var _dodge_timer: float = 0.0
var _attack_cooldown: float = 0.0
## Tool tucked away while both hands hold the basketball; comes back after.
var _stowed_tool_id: String = ""

## Where this character's intent comes from. The locally driven player reads the device; a peer's character is
## fed replicated intent instead (player/input_source.gd). Abilities read THIS, never Input directly.
var input: InputSource = LocalInputSource.new()
var flight: Node = null
var _flight_ground_y := 0.0
var _nearby_npcs: Array = []
var _nearby_interactables: Array = []
var _nearby_balls: Array = []
var _body_base_y: float = 0.0

@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var ball_hold_point: Node3D = $CameraRig/SpringArm3D/Camera3D/BallHoldPoint
@onready var interaction_area: Area3D = $InteractionArea
@onready var body: CharacterRig = $Body
@onready var skateboard_mesh: Node3D = $Body/SkateboardMesh
@onready var equipment: CharacterEquipment = $CharacterEquipment

## The player is custom: a character made in the creator wins; otherwise fall back to a preset look. Set before the
## rig attaches its model (children are ready first).
func _enter_tree() -> void:
	var rig := get_node_or_null("Body")
	if rig == null or rig.is_node_ready():
		return
	var saved := ToriyamaRoster.saved_recipe()
	if not saved.is_empty():
		rig.toriyama_recipe = saved
		rig.movement_style = String(saved.get("movement", "neutral"))
		return
	var look := ToriyamaRoster.saved_player_look()
	if look != "":
		rig.toriyama_character = look

## Rebuild the player from a character-creator recipe and remember it. Traits travel with the character: they are
## chosen at creation and never shown in a list again, only felt in play and heard in dialogue.
func apply_recipe(recipe: Dictionary) -> void:
	body.set_toriyama_recipe(recipe)
	ToriyamaRoster.save_recipe(recipe)
	if recipe.has("traits"):
		TraitSystem.choose_starting(recipe["traits"])
	if String(recipe.get("name", "")) != "":
		player_name = String(recipe["name"])
	EventBus.fire("hud_message", {"text": "Looking good."})

## Open the character creator (new game, or the mirror at home).
func open_creator(allow_cancel := true, mirror: Node3D = null) -> void:
	if get_tree().root.find_child("CharacterCreator", true, false) != null:
		return
	var creator := CharacterCreator.new()
	creator.name = "CharacterCreator"
	creator.allow_cancel = allow_cancel
	if mirror:                     # standing at a mirror: edit the real character, camera in the glass
		creator.in_world = true
		creator.target_rig = body
		creator.title_text = "Change your look"
	var saved := ToriyamaRoster.saved_recipe()
	if not saved.is_empty():
		creator.recipe = saved.duplicate(true)
	var previous_mouse := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input_locked = true
	# at a mirror the camera moves into the glass, so you edit the character you are looking at
	var mirror_camera: Camera3D = null
	if mirror:
		mirror_camera = Camera3D.new()
		add_child(mirror_camera)
		mirror_camera.global_position = mirror.global_position + Vector3(0, 1.48, 0) - mirror.global_transform.basis.z * 0.28
		mirror_camera.look_at(global_position + Vector3(0, 1.35, 0))
		mirror_camera.fov = 48.0
		mirror_camera.current = true
	var restore := func() -> void:
		input_locked = false
		Input.mouse_mode = previous_mouse
		if is_instance_valid(mirror_camera):
			mirror_camera.queue_free()
		camera.current = true
	creator.finished.connect(func(recipe: Dictionary) -> void:
		restore.call()
		apply_recipe(recipe))
	creator.cancelled.connect(func() -> void: restore.call())
	get_tree().root.add_child(creator)

## F9: next look preset (stand-in for the character creator). Held items move over to the new model.
func cycle_look() -> void:
	var looks := ToriyamaRoster.available_player_looks()
	if looks.is_empty():
		return
	var next: String = looks[(looks.find(body.toriyama_character) + 1) % looks.size()]
	body.set_toriyama_character(next)
	ToriyamaRoster.save_player_look(next)
	EventBus.fire("hud_message", {"text": "Look: %s" % next.replace("_", " ")})

var player_name := "Player"
## Set while the character creator or a scripted moment has control; movement input is ignored but the character
## still animates and physics still runs.
var input_locked := false

func _ready() -> void:
	vitals = Vitals.new()
	vitals.name = "Vitals"
	add_child(vitals)
	add_to_group("player")
	WorldState.player = self
	flight = FlightControllerScript.new()
	flight.name = "FlightController"
	add_child(flight)
	flight.setup(self)
	interaction_area.body_entered.connect(_on_interaction_body_entered)
	interaction_area.body_exited.connect(_on_interaction_body_exited)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skateboard_mesh.visible = false
	_body_base_y = body.position.y
	body.set_skin_tone(skin_tone)
	for item_id in STARTING_EQUIPMENT:
		var item := EquipmentCatalog.get_item(item_id)
		if item:
			equipment.equip(item)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_player_look"):
		cycle_look()
	if event.is_action_pressed("attack"):
		perform_basic_attack()
	if event.is_action_pressed("dodge"):
		_dodge()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact"):
		_do_interact()
	if event.is_action_pressed("shoot"):
		_do_shoot()
	if event.is_action_pressed("invite"):
		_do_invite()
	if event.is_action_pressed("follow_me"):
		_do_follow()
	if event.is_action_pressed("toggle_mount"):
		_toggle_skateboard()
	if event.is_action_pressed("time_pause"):
		TimeManager.toggle_pause()
	if event.is_action_pressed("time_speed_normal"):
		TimeManager.set_speed(TimeManager.Speed.NORMAL)
	if event.is_action_pressed("time_speed_fast"):
		TimeManager.set_speed(TimeManager.Speed.FAST)
	if event.is_action_pressed("time_speed_very_fast"):
		TimeManager.set_speed(TimeManager.Speed.VERY_FAST)
	if event.is_action_pressed("play_guitar"):
		try_play_guitar()

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		is_dodging = true
	else:
		is_dodging = false
	# Flight takes the whole movement step when it is active, so gravity and ground speed are skipped. It only
	# engages on a second jump in mid-air and only once the ability has awakened (universal_mastery.flight).
	var flying := false
	_update_water(delta)
	if is_swimming:
		# float instead of fall: a spring holds the body at the surface, so stepping off a shelf into deep water
		# turns into swimming rather than sinking, and swimming back to the shallows sets you down on the bottom
		var target_y: float = Water.surface_y(global_position) - FLOAT_DEPTH
		velocity.y += ((target_y - global_position.y) * BUOYANCY - velocity.y * BUOYANCY_DAMP) * delta
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif input.just_pressed(&"jump"):
		velocity.y = JUMP_VELOCITY

	if input is LocalInputSource:
		(input as LocalInputSource).locked = input_locked
	var input_dir := input.move_vector()
	var cam_basis := camera_rig.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	var move_dir := forward * -input_dir.y + right * input_dir.x

	var sprinting := not is_mounted_skateboard and input.pressed(&"sprint") and stamina > 1.0
	var base_speed := SKATE_SPEED if is_mounted_skateboard else (RUN_SPEED if sprinting else SPEED)
	if is_swimming:
		base_speed = SWIM_SPRINT_SPEED if sprinting else SWIM_SPEED
	elif water_state == "wade":
		base_speed *= WADE_SLOWDOWN
	var speed := base_speed * TraitSystem.multiplier("move.speed")
	_spend_stamina(delta, sprinting)
	if move_dir.length() > 0.01:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		body.look_at(body.global_position + move_dir, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 6.0 * delta)

	if flight:
		flying = flight.update(delta, move_dir, _ground_reference_y())
	move_and_slide()

	if is_mounted_skateboard and skateboard_mesh and skateboard_mesh.has_method("update_skate"):
		var horiz_speed := Vector2(velocity.x, velocity.z).length()
		skateboard_mesh.update_skate(horiz_speed, input_dir.x, delta)

	var sword := _sword_stance()
	body.swing = 0.0 if _attack_cooldown <= 0.0 else clampf(1.0 - _attack_cooldown / ATTACK_TIME, 0.0, 1.0)
	var pose := "normal"
	if is_swimming:
		pose = "swim"
	elif is_mounted_skateboard:
		pose = "ride"
	elif held_ball:
		pose = "hold"
	elif sword != "" and (_attack_cooldown > 0.0 or Vector2(velocity.x, velocity.z).length() < 0.6):
		# stance only while cutting or standing ready - walking with a drawn sword keeps the walk cycle, or the
		# character slides around the town frozen in a guard
		pose = sword
	# in the air under power the body reads as airborne, which is what the jump pose already handles
	# swimming counts as grounded for the rig so it never accumulates air time and cuts to a falling pose - the
	# "swim" state above is what actually drives the body
	body.animate(delta, Vector2(velocity.x, velocity.z).length(), (is_on_floor() or is_swimming) and not flying, pose, velocity.y)

	if held_ball:
		held_ball.global_position = body.ball_hold_position()
	if body.model:
		body.model.look_target = _gaze_target()

## The player's eyes: the dialogue partner, else whatever is in focus (the person or thing [E] would act on).
func _gaze_target() -> Node3D:
	if dialogue_open and is_instance_valid(dialogue_partner):
		return dialogue_partner
	var focus = _get_focus_target()
	return focus if focus is Node3D else null

## --- Zones (set by LocationZone triggers placed around the neighborhood) --

func enter_zone(zone_id: String) -> void:
	current_zone = zone_id
	EventBus.fire("player_entered_zone", {"zone": zone_id})

func exit_zone(zone_id: String) -> void:
	if current_zone == zone_id:
		current_zone = ""

## --- Sword -----------------------------------------------------------------
## "" with no blade drawn, "katana" for one, "dual_katana" for one in each hand.
func _sword_stance() -> String:
	# any held weapon, not one hard-coded id, so the real katana variants slot straight in later
	var right := _is_blade(equipment.get_equipped("hand_r"))
	var left := _is_blade(equipment.get_equipped("hand_l"))
	if right and left:
		return "dual_katana"
	if right or left:
		body.swing_side = 1 if right else -1
		return "katana"
	return ""

static func _is_blade(item) -> bool:
	return item != null and String(item.stats.get("tool_type", "")) == "weapon"

## Show or hide the katana model itself. The blade is a prop on a hand socket (ToriyamaKitCharacter.set_weapon),
## not part of the body mesh, so drawing it is a scene change rather than an animation state.
func _refresh_sword_prop() -> void:
	if body == null or body.model == null or not body.model.has_method("set_weapon"):
		return
	var stance := _sword_stance()
	if stance == "":
		body.model.set_weapon("")
	else:
		body.model.set_weapon(SWORD_PROP, "hip", {}, stance == "dual_katana")
		body.model.set_weapon_drawn(true)

## --- Water -----------------------------------------------------------------
## Which of dry / splashing / wading / swimming the player is in, from the water layer rather than trigger volumes,
## so it is correct anywhere on the coast without anyone placing a box.
func _update_water(delta: float) -> void:
	var was := water_state
	water_state = Water.state_at(global_position)
	var swimming_now := water_state == "swim"
	if swimming_now != is_swimming:
		is_swimming = swimming_now
		if is_swimming:
			velocity.y = maxf(velocity.y, -1.5)          # a dive should not carry you to the seabed
			EventBus.fire("player_started_swimming", {})
		else:
			EventBus.fire("player_stopped_swimming", {})
	if was != water_state:
		EventBus.fire("player_water_state", {"state": water_state})
		if was == "" and water_state != "":
			AudioManager.play_sfx("footstep", global_position)

func _spend_stamina(delta: float, sprinting: bool) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var spent := false
	if is_swimming:
		vitals.spend_stamina("swim", delta)
		spent = true
	if sprinting and (moving or is_swimming):
		vitals.spend_stamina("sprint", delta)
		spent = true
	elif is_mounted_skateboard and moving:
		vitals.spend_stamina("skate", delta)
		spent = true
	if not spent:
		vitals.tick(delta)

## True while the player is out of their depth - for the HUD, for animation, and for anything that should be
## refused in the water (skating, the tool wheel, attacking).
func swimming() -> bool:
	return is_swimming

## --- Interaction foundations ----------------------------------------------

func get_player_id() -> String:
	return player_id

func get_focus_prompt() -> String:
	if dialogue_open:
		return "[E] Close"
	if is_mounted_skateboard:
		return "[E] Dismount Skateboard"
	if held_ball:
		return "[E] Drop Ball    [Click] Shoot"
	var target = _get_focus_target()
	if target == null:
		return ""
	if target.has_method("get_prompt"):
		var p: String = target.get_prompt()
		if p == "":
			return ""
		return "[E] %s" % p
	return ""

func get_invite_prompt() -> String:
	if dialogue_open or is_mounted_skateboard or held_ball:
		return ""
	var target = _get_focus_target()
	if target and target.is_in_group("npc"):
		if target.is_following(self):
			return "[G] Stop Following"
		var label: String = {
			"BASKETBALL": "Invite to Basketball", "EXERCISE": "Invite to Workout",
		}.get(_activity_for_zone(current_zone), "Invite to Hang Out")
		return "[F] %s    [G] Follow Me" % label
	return ""

func _get_focus_target() -> Variant:
	var best: Variant = null
	var best_dist := INF
	for n in _nearby_npcs + _nearby_interactables + _nearby_balls:
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best = n
	return best

func get_social_inspection_target():
	var focused = _get_focus_target()
	if focused and focused.is_in_group("npc"):
		return focused
	var nearest = null
	var nearest_distance := INF
	for npc in WorldState.get_all_npcs():
		var distance := global_position.distance_to(npc.global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	return nearest

func _do_interact() -> void:
	if dialogue_open:
		_close_dialogue()
		return
	if is_mounted_skateboard:
		_toggle_skateboard()
		return
	if held_ball:
		_drop_ball()
		return
	var target = _get_focus_target()
	if target == null:
		return
	if target.is_in_group("basketballs"):
		_pick_up_ball(target)
	elif target.is_in_group("npc"):
		_talk_to(target)
	elif target.is_in_group("interactable"):
		target.interact(self)

## --- Held tools (inventory wheel) ----------------------------------------

## The one tool currently in hand, or null for empty hands.
func get_hand_tool() -> EquipmentItem:
	for slot in CharacterEquipment.HAND_SLOTS:
		var item := equipment.get_equipped(slot)
		if CharacterEquipment.is_hand_tool(item):
			return item
	return null

## "" puts every tool away. Equipping a tool swaps out the other one
## (CharacterEquipment keeps tools exclusive), and drops a held basketball.
func select_hand_tool(item_id: String, announce: bool = true) -> void:
	_stowed_tool_id = ""
	if item_id == "":
		var had := get_hand_tool()
		for slot in CharacterEquipment.HAND_SLOTS:
			if CharacterEquipment.is_hand_tool(equipment.get_equipped(slot)):
				equipment.unequip(slot)
		if announce:
			EventBus.fire("hud_message", {"text": "Put away the %s." % had.display_name if had else "Your hands are already empty."})
		_refresh_sword_prop()
		EventBus.fire("player_tool_selected", {"item_id": ""})
		return
	var item := EquipmentCatalog.get_item(item_id)
	if item == null:
		return
	if held_ball:
		_drop_ball()
	var current := get_hand_tool()
	if current == null or current.id != item_id:
		equipment.equip(item)
	if announce:
		EventBus.fire("hud_message", {"text": "%s in hand." % item.display_name})
	_refresh_sword_prop()
	EventBus.fire("player_tool_selected", {"item_id": item_id})

func try_play_guitar() -> void:
	var held_item := get_hand_tool()
	if held_item == null or held_item.stats.get("activity", "") != "guitar":
		EventBus.fire("hud_message", {"text": "Pick the guitar from the tool wheel (Tab) first."})
		return
	if dialogue_open or is_mounted_skateboard or is_swimming:
		EventBus.fire("hud_message", {"text": "Hop off and finish talking before playing."})
		return
	var venue := CommunityEventManager.get_performance_venue(global_position)
	EventBus.fire("guitar_minigame_requested", {"source": "inventory_tool", "item_id": held_item.id, "venue": venue})

func perform_basic_attack() -> bool:
	if _attack_cooldown > 0.0 or dialogue_open or is_mounted_skateboard or is_swimming:
		return false
	var weapon := equipment.get_equipped("hand_r")
	if weapon == null or weapon.id != "test_sword":
		EventBus.fire("hud_message", {"text": "Pick the sword from the tool wheel (Tab) first."})
		return false
	if not vitals.spend_stamina("attack", 1.0, false):
		EventBus.fire("hud_message", {"text": "Too winded to swing."})
		return false
	_attack_cooldown = ATTACK_TIME
	EventBus.fire("player_attack_started", {"weapon_id": weapon.id})
	var forward := -body.global_transform.basis.z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(global_position) > 2.15:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01 and forward.dot(to_enemy.normalized()) >= -0.15:
			enemy.take_damage(15, global_position)
	EventBus.fire("player_attack_landed", {"weapon_id": weapon.id})
	return true

func _dodge() -> void:
	if is_dodging:
		return
	if not vitals.spend_stamina("dodge", 1.0, false):
		return
	is_dodging = true
	_dodge_timer = 0.42
	var direction := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() <= 0.01:
		direction = -body.global_transform.basis.z
	direction = direction.normalized()
	velocity.x = direction.x * 8.0
	velocity.z = direction.z * 8.0
	EventBus.fire("player_dodged", {})

func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if is_dodging or health <= 0:
		return
	vitals.damage(float(amount))
	EventBus.fire("player_damaged", {"amount": amount, "health": health})
	if source_position != Vector3.ZERO:
		var push := global_position - source_position
		push.y = 0.0
		if push.length_squared() > 0.01:
			velocity += push.normalized() * 2.5
	if health <= 0:
		vitals.health = vitals.max_health
		velocity = Vector3.ZERO
		EventBus.fire("player_knocked_out", {})
		EventBus.fire("hud_message", {"text": "You were knocked out and wake up at home."})
		if WorldState.has_location("home_player"):
			global_position = WorldState.get_location_position("home_player")

func _do_shoot() -> void:
	if held_ball == null:
		var weapon := equipment.get_equipped("hand_r")
		if weapon and weapon.id == "test_sword": perform_basic_attack()
		return
	var throw_dir := -camera.global_transform.basis.z
	held_ball.shoot(throw_dir + Vector3.UP * 0.3)
	held_ball = null
	_restore_stowed_tool()

func _do_invite() -> void:
	var target = _get_focus_target()
	if target == null or not target.is_in_group("npc"):
		return
	var context := _activity_for_zone(current_zone)
	var location_id: String = current_zone if current_zone != "" else target.definition.home_location_id
	var accepted: bool = target.receive_invite(self, player_id, location_id, context)
	EventBus.fire("player_invited_npc", {"npc_id": target.definition.id, "accepted": accepted, "activity": context})

## Immediate companion mode, distinct from the (possibly delayed) invite:
## only works right now, on an NPC who is actually free.
func _do_follow() -> void:
	var target = _get_focus_target()
	if target == null or not target.is_in_group("npc"):
		return
	if target.is_following(self):
		target.stop_following()
		return
	target.receive_follow_request(self, player_id)

func _activity_for_zone(zone_id: String) -> String:
	match zone_id:
		"loc_basketball": return "BASKETBALL"
		"loc_gym": return "EXERCISE"
		_: return "SOCIALIZE"

## --- Dialogue ------------------------------------------------------------
## The conversation itself lives in ui/dialogue_box.gd (the topic list) and npc/npc_conversation.gd (the answers).
## The player only opens it, holds eye contact with whoever it is with, and closes when the box says so.

func _talk_to(npc) -> void:
	RelationshipManager.record_shared_activity(player_id, npc.definition.id, "talk")
	dialogue_open = true
	dialogue_partner = npc
	AudioManager.play_ui_sfx("dialogue_open")
	EventBus.fire("dialogue_opened", {"name": npc.definition.first_name, "npc": npc})

func _close_dialogue() -> void:
	dialogue_open = false
	if is_instance_valid(dialogue_partner) and dialogue_partner.body.model:
		dialogue_partner.body.model.stop_talking()
	dialogue_partner = null
	AudioManager.play_ui_sfx("dialogue_close")
	EventBus.fire("dialogue_closed", {})

## --- Basketball --------------------------------------------------------

func _pick_up_ball(ball) -> void:
	if not ball.is_available():
		return
	held_ball = ball
	ball.pick_up(self)
	# The ball takes both hands: tuck the current tool away until it's released.
	var tool := get_hand_tool()
	if tool:
		equipment.unequip(tool.slot_name())
		_stowed_tool_id = tool.id

func _drop_ball() -> void:
	if held_ball == null:
		return
	held_ball.shoot(Vector3.DOWN + -camera.global_transform.basis.z * 0.2, 0.5)
	held_ball = null
	_restore_stowed_tool()

func _restore_stowed_tool() -> void:
	if _stowed_tool_id == "":
		return
	var item := EquipmentCatalog.get_item(_stowed_tool_id)
	_stowed_tool_id = ""
	if item and get_hand_tool() == null:
		equipment.equip(item)

## --- Skateboard (foundation for skating-as-traversal) ---------------------

func grant_skateboard() -> void:
	has_skateboard = true
	skateboard_mesh.visible = true
	_pose_skateboard_carried()

func _pose_skateboard_carried() -> void:
	body.position.y = _body_base_y
	var back := body.get_socket("back")
	skateboard_mesh.reparent(back if back else body, false)
	skateboard_mesh.position = SKATEBOARD_CARRIED_OFFSET
	skateboard_mesh.rotation_degrees = SKATEBOARD_CARRIED_ROT

func _toggle_skateboard() -> void:
	if not has_skateboard:
		return
	is_mounted_skateboard = not is_mounted_skateboard
	if is_mounted_skateboard:
		body.position.y = _body_base_y + MOUNT_LIFT
		skateboard_mesh.reparent(body, false)
		skateboard_mesh.position = SKATEBOARD_MOUNTED_POS
		skateboard_mesh.rotation_degrees = SKATEBOARD_MOUNTED_ROT
	else:
		_pose_skateboard_carried()
	AudioManager.play_sfx("skateboard_mount", global_position)
	EventBus.fire("player_toggled_skateboard", {"mounted": is_mounted_skateboard})
	EventBus.fire("hud_message", {"text": "Hopped on the skateboard." if is_mounted_skateboard else "Hopped off the skateboard."})

## --- House entry / sleep (fade helpers shared by both) --------------------

func teleport_to(destination: Vector3) -> void:
	EventBus.fire("screen_fade_out", {"duration": FADE_DURATION})
	await get_tree().create_timer(FADE_DURATION).timeout
	global_position = destination
	velocity = Vector3.ZERO
	AudioManager.play_sfx("door", global_position)
	EventBus.fire("screen_fade_in", {"duration": FADE_DURATION})

func sleep_until_morning() -> void:
	EventBus.fire("screen_fade_out", {"duration": FADE_DURATION})
	await get_tree().create_timer(FADE_DURATION).timeout
	AudioManager.play_sfx("sleep", global_position)
	var slept: float = float(SLEEP_WAKE_HOUR - TimeManager.hour)
	if slept <= 0.0:
		slept += 24.0
	TimeManager.advance_to_morning(SLEEP_WAKE_HOUR)
	vitals.sleep_restore(slept)
	velocity = Vector3.ZERO
	await get_tree().create_timer(FADE_DURATION).timeout
	EventBus.fire("screen_fade_in", {"duration": FADE_DURATION})
	EventBus.fire("hud_message", {"text": "You wake up feeling rested."})

## --- Interaction area signal handlers --------------------------------

func _on_interaction_body_entered(body_node: Node) -> void:
	if body_node.is_in_group("npc"):
		_nearby_npcs.append(body_node)
	elif body_node.is_in_group("basketballs"):
		_nearby_balls.append(body_node)

func _on_interaction_body_exited(body_node: Node) -> void:
	_nearby_npcs.erase(body_node)
	_nearby_balls.erase(body_node)

func _on_interaction_area_entered(area: Area3D) -> void:
	if area.is_in_group("interactable"):
		_nearby_interactables.append(area)

func _on_interaction_area_exited(area: Area3D) -> void:
	_nearby_interactables.erase(area)


## The last ground height the player stood on - flight measures its ceiling from there rather than from sea level,
## so the ceiling means the same thing on a dune, a boardwalk or a cliff.
func _ground_reference_y() -> float:
	if is_on_floor():
		_flight_ground_y = global_position.y
	return _flight_ground_y
