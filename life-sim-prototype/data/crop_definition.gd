class_name CropDefinition
extends Resource
## Small, data-driven crop description. New crops can be added without
## changing farm-plot behavior.

@export var id: String = "turnip"
@export var display_name: String = "Turnip"
@export var seed_item_id: String = "turnip_seed"
@export var days_to_mature: int = 3
@export var harvest_min: int = 2
@export var harvest_max: int = 3
@export var foliage_color: Color = Color(0.25, 0.68, 0.25)
@export var crop_color: Color = Color(0.92, 0.86, 0.75)

