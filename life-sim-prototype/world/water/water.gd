class_name Water
extends RefCounted
## Where the water is, and how deep. One place anything can ask "am I in water here, and can I stand up?".
##
## The ocean is not a collision volume — it is a shader on a plane over terrain whose height is a formula
## (`world/detail/regional_landscape.gd`). So the ocean is answered analytically: surface height is a constant, the
## seabed comes from the same function that built it, and the difference is the depth. That is exact, costs nothing
## per frame, and cannot drift out of sync with the terrain the way a hand-placed trigger volume would.
##
## Smaller bodies (ponds, wells, troughs) are not formulas, so they register an AABB and a surface height. Anything
## in the `water_volume` group with a `water_surface_y` property is picked up automatically.

const LANDSCAPE := preload("res://world/detail/landscape_shape.gd")
## Below this the water is ankle-deep: you walk, you just splash.
const SHALLOW_DEPTH := 0.45
## At or past this your feet have left the bottom and you swim. Between the two you are wading.
const SWIM_DEPTH := 1.30

static var _volumes: Array[Dictionary] = []

## Register a pond/pool so it can be swum in. `aabb` is in world space.
static func register_volume(id: String, aabb: AABB, surface_y: float) -> void:
	unregister_volume(id)
	_volumes.append({"id": id, "aabb": aabb, "surface_y": surface_y})

static func unregister_volume(id: String) -> void:
	for i in range(_volumes.size() - 1, -1, -1):
		if String(_volumes[i]["id"]) == id:
			_volumes.remove_at(i)

static func clear_volumes() -> void:
	_volumes.clear()

## Height of the water surface over this point, or -INF where there is none.
static func surface_y(pos: Vector3) -> float:
	for v in _volumes:
		var box: AABB = v["aabb"]
		if pos.x >= box.position.x and pos.x <= box.end.x and pos.z >= box.position.z and pos.z <= box.end.z:
			if pos.y <= float(v["surface_y"]) + 2.0:
				return float(v["surface_y"])
	if LANDSCAPE.land_edge(pos.x, pos.z) < 0.0:
		return LANDSCAPE.WATER_LEVEL
	return -INF

## Height of the ground under this point (the seabed out at sea).
static func bed_y(pos: Vector3) -> float:
	return LANDSCAPE.height_at(pos.x, pos.z)

## How deep the water is here, 0 where there is none. This is the water column, not how submerged a swimmer is.
static func depth_at(pos: Vector3) -> float:
	var s := surface_y(pos)
	if s == -INF:
		return 0.0
	return maxf(0.0, s - bed_y(pos))

static func is_water(pos: Vector3) -> bool:
	return surface_y(pos) != -INF

## What a body standing at `feet` should be doing: "" (dry), "shallow", "wade" or "swim".
static func state_at(feet: Vector3) -> String:
	var s := surface_y(feet)
	if s == -INF or feet.y > s + 0.25:
		return ""
	var d := maxf(0.0, s - bed_y(feet))
	if d >= SWIM_DEPTH:
		return "swim"
	if d >= SHALLOW_DEPTH:
		return "wade"
	if d > 0.02:
		return "shallow"
	return ""
