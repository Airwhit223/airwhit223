class_name LandscapeShape
extends RefCounted
## The pure shape of the land: where the coast runs and how high the ground is at any point.
##
## Split out of regional_landscape.gd so that things which only need to ASK about the terrain — the water layer, a
## spawn placer, a test — do not have to pull in the whole builder, which touches autoloads and cannot even be
## compiled by a headless script. Both the builder and the water read these, so there is one coastline, not two.

const WATER_LEVEL := -0.65
const GROVES := [Vector2(-175, 45), Vector2(-130, 130), Vector2(-20, 150), Vector2(335, 105), Vector2(60, -185)]

## A sheltered bay at the boardwalk and a promontory beneath the lighthouse.
static func coast_z(x: float) -> float:
	return 275.0 + 38.0 * sin(x * 0.008) - 47.0 * exp(-pow((x - 170.0) / 64.0, 2.0)) + 40.0 * exp(-pow((x - 225.0) / 24.0, 2.0))

## Distance to the nearest land edge; negative out at sea.
static func land_edge(x: float, z: float) -> float:
	return minf(coast_z(x) - z, minf(660.0 - absf(x), z + 685.0))

static func height_at(x: float, z: float) -> float:
	var edge := land_edge(x, z)
	if edge < 0.0:
		return maxf(-12.0, edge * 0.16)
	var waves := 10.0 + 8.0 * sin(x * 0.014) * cos(z * 0.011) + 5.0 * sin(z * 0.027 + x * 0.009)
	var northern_ridge := 65.0 * exp(-pow((z + 480.0) / 105.0, 2.0)) * (0.65 + 0.35 * sin(x * 0.018))
	var h := maxf(0.0, waves + northern_ridge)
	# Preserve the inhabited and already decorated central footprint, including all road links.
	var outside := maxf(absf(x - 35.0) - 335.0, absf(z + 15.0) - 275.0)
	h *= smoothstep(0.0, 100.0, outside)
	# Low knolls in deliberately empty gaps frame the routes without moving towns.
	for center in GROVES:
		var r := Vector2(x, z).distance_to(center) / 42.0
		h += 9.0 * pow(maxf(0.0, 1.0 - r * r), 3.0)
	h *= smoothstep(12.0, 65.0, edge)
	return h
