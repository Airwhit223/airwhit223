class_name FarmPlot
extends Interactable
## One reusable garden plot: plant, water once per day, grow on the next day,
## and harvest. The crop never dies in this first forgiving prototype.

enum PlotState { EMPTY, GROWING, READY }

@export var plot_id: String = "plot_1"
@export var default_crop_id: String = "turnip"

var state: int = PlotState.EMPTY
var crop_id: String = ""
var growth_days: int = 0
var watered_today: bool = false
var last_watered_day: int = -1

var _plant_visual: Node3D
var _soil_material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true
	_build_visuals()
	TimeManager.day_changed.connect(_on_day_changed)
	_refresh_visual()

func get_prompt() -> String:
	var crop := FarmingManager.get_crop(default_crop_id if crop_id == "" else crop_id)
	if crop == null:
		return "Garden plot unavailable"
	if state == PlotState.EMPTY:
		return "Plant %s (%d seeds)" % [crop.display_name, FarmingManager.get_seed_count(crop.id)]
	if state == PlotState.READY:
		return "Harvest %s" % crop.display_name
	if not watered_today:
		return "Water %s" % crop.display_name
	return "%s growing — %d/%d days" % [crop.display_name, growth_days, crop.days_to_mature]

func interact(_player: Node) -> void:
	if state == PlotState.EMPTY:
		_plant(default_crop_id)
	elif state == PlotState.READY:
		_harvest()
	elif not watered_today:
		_water()
	else:
		_message("This plot is watered for today.")

func _plant(new_crop_id: String) -> void:
	var crop := FarmingManager.get_crop(new_crop_id)
	if crop == null:
		return
	if not FarmingManager.use_seed(new_crop_id):
		_message("You are out of %s seeds." % crop.display_name)
		return
	crop_id = new_crop_id
	state = PlotState.GROWING
	growth_days = 0
	watered_today = false
	last_watered_day = -1
	_refresh_visual()
	EventBus.fire("crop_planted", {"plot_id": plot_id, "crop_id": crop_id})
	_message("Planted a %s. Water it to help it grow." % crop.display_name)

func _water() -> void:
	watered_today = true
	last_watered_day = TimeManager.day_index
	_refresh_visual()
	EventBus.fire("crop_watered", {"plot_id": plot_id, "crop_id": crop_id})
	_message("Watered the %s." % _crop_name())

func _on_day_changed(new_day: int, _day_of_week: int) -> void:
	if state != PlotState.GROWING:
		return
	# Watering during the previous calendar day earns one growth step. Time
	# jumps use this same signal, so sleeping and normal clock passage agree.
	if watered_today and last_watered_day < new_day:
		growth_days += 1
		var crop := FarmingManager.get_crop(crop_id)
		if crop and growth_days >= crop.days_to_mature:
			state = PlotState.READY
			EventBus.fire("crop_ready", {"plot_id": plot_id, "crop_id": crop_id})
		else:
			EventBus.fire("crop_grew", {"plot_id": plot_id, "crop_id": crop_id, "growth_days": growth_days})
	watered_today = false
	_refresh_visual()

func _harvest() -> void:
	var crop := FarmingManager.get_crop(crop_id)
	if crop == null:
		return
	# Deterministic per plot/day so tests and saved replays remain predictable.
	var span: int = maxi(1, crop.harvest_max - crop.harvest_min + 1)
	var amount: int = crop.harvest_min + (abs(hash("%s:%d" % [plot_id, TimeManager.day_index])) % span)
	FarmingManager.add_harvest(crop_id, amount)
	EventBus.fire("crop_harvested", {"plot_id": plot_id, "crop_id": crop_id, "amount": amount})
	_message("Harvested %d %s%s." % [amount, crop.display_name, "s" if amount != 1 else ""])
	state = PlotState.EMPTY
	crop_id = ""
	growth_days = 0
	watered_today = false
	last_watered_day = -1
	_refresh_visual()

func _crop_name() -> String:
	var crop := FarmingManager.get_crop(crop_id)
	return crop.display_name if crop else "crop"

func _message(text: String) -> void:
	EventBus.fire("hud_message", {"text": text})

func _build_visuals() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65, 0.3, 1.65)
	collision.shape = shape
	collision.position.y = 0.12
	add_child(collision)

	var soil := MeshInstance3D.new()
	soil.name = "Soil"
	var soil_mesh := BoxMesh.new()
	soil_mesh.size = Vector3(1.65, 0.18, 1.65)
	soil.mesh = soil_mesh
	soil.position.y = 0.05
	_soil_material = StandardMaterial3D.new()
	_soil_material.albedo_color = Color(0.26, 0.13, 0.06)
	soil.material_override = _soil_material
	add_child(soil)

	_plant_visual = Node3D.new()
	_plant_visual.name = "CropVisual"
	add_child(_plant_visual)
	for x in [-0.42, 0.0, 0.42]:
		for z in [-0.38, 0.38]:
			_plant_visual.add_child(_make_plant(Vector3(float(x), 0.14, float(z))))

func _make_plant(at: Vector3) -> Node3D:
	var plant := Node3D.new()
	plant.position = at
	var root := MeshInstance3D.new()
	var root_mesh := SphereMesh.new()
	root_mesh.radius = 0.12
	root_mesh.height = 0.2
	root.mesh = root_mesh
	root.position.y = 0.06
	var root_mat := StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.92, 0.86, 0.75)
	root.material_override = root_mat
	plant.add_child(root)
	for angle in [-0.8, 0.0, 0.8]:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.12
		leaf_mesh.height = 0.32
		leaf.mesh = leaf_mesh
		leaf.scale = Vector3(0.55, 1.0, 0.28)
		leaf.position = Vector3(sin(angle) * 0.09, 0.22, cos(angle) * 0.04)
		leaf.rotation.z = angle
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.albedo_color = Color(0.25, 0.68, 0.25)
		leaf.material_override = leaf_mat
		plant.add_child(leaf)
	return plant

func _refresh_visual() -> void:
	if _plant_visual == null:
		return
	_plant_visual.visible = state != PlotState.EMPTY
	if state == PlotState.EMPTY:
		_soil_material.albedo_color = Color(0.26, 0.13, 0.06)
		return
	var crop := FarmingManager.get_crop(crop_id)
	var maturity: float = clampf(float(growth_days + 1) / float(crop.days_to_mature + 1), 0.22, 1.0) if crop else 0.3
	if state == PlotState.READY:
		maturity = 1.0
	_plant_visual.scale = Vector3.ONE * maturity
	_apply_crop_palette(crop)
	_soil_material.albedo_color = Color(0.17, 0.10, 0.05) if watered_today else Color(0.26, 0.13, 0.06)

## Crop definitions already carry foliage and produce colors. Applying them
## here keeps new crops visually distinct without creating a new plot script.
func _apply_crop_palette(crop: CropDefinition) -> void:
	if crop == null or _plant_visual == null:
		return
	for plant in _plant_visual.get_children():
		var parts := plant.get_children()
		if parts.is_empty():
			continue
		var root := parts[0] as MeshInstance3D
		if root:
			var root_material := root.material_override as StandardMaterial3D
			if root_material:
				root_material.albedo_color = crop.crop_color
		for child_index in range(1, parts.size()):
			var leaf := parts[child_index] as MeshInstance3D
			if leaf:
				var leaf_material := leaf.material_override as StandardMaterial3D
				if leaf_material:
					leaf_material.albedo_color = crop.foliage_color

## Plot state stays local because different garden beds can be at different
## growth stages. This round-trip is ready for the future save coordinator.
func to_dict() -> Dictionary:
	return {
		"plot_id": plot_id,
		"state": state,
		"crop_id": crop_id,
		"growth_days": growth_days,
		"watered_today": watered_today,
		"last_watered_day": last_watered_day,
	}

func from_dict(data: Dictionary) -> void:
	plot_id = String(data.get("plot_id", plot_id))
	state = clampi(int(data.get("state", PlotState.EMPTY)), PlotState.EMPTY, PlotState.READY)
	crop_id = String(data.get("crop_id", ""))
	growth_days = maxi(0, int(data.get("growth_days", 0)))
	watered_today = bool(data.get("watered_today", false))
	last_watered_day = int(data.get("last_watered_day", -1))
	# Invalid or removed crop ids should never leave behind an unharvestable bed.
	if state != PlotState.EMPTY and FarmingManager.get_crop(crop_id) == null:
		state = PlotState.EMPTY
		crop_id = ""
		growth_days = 0
		watered_today = false
		last_watered_day = -1
	_refresh_visual()
