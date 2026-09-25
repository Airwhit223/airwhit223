class_name Vitals
extends Node
## Health, Energy and Stamina — three bars that mean three different things, per
## docs/MODES_AND_CHAPTER_ONE.md.
##
##   HEALTH   physical condition. Damage, illness, environmental danger. Does not come back on its own.
##   ENERGY   the long daily reserve. It drains across the day and is restored by SLEEPING, EATING, resting and
##            the activities a character's traits actually enjoy — never by standing still. That is the whole point:
##            a day has a budget, and how you spend and refill it is the life sim.
##   STAMINA  immediate exertion. Sprinting, swimming, climbing, fighting, powers. This one DOES come back on its
##            own, quickly, because it is about the last ten seconds rather than the last ten hours.
##
## The two are coupled one way only: low Energy makes Stamina both cheaper to exhaust and slower to recover, so a
## tired character can still sprint — just not for long, and not repeatedly. Stamina never feeds back into Energy.
##
## Mastery cuts the cost of what you are good at. At full mastery an ordinary action in that discipline is FREE, so
## late-game Stamina stops being a tax on walking around and becomes the budget for pushing past normal ability.

signal health_changed(value: float, maximum: float)
signal energy_changed(value: float, maximum: float)
signal stamina_changed(value: float, maximum: float)
signal collapsed()                ## health reached zero
signal exhausted()                ## energy reached zero
signal winded()                   ## stamina reached zero

const MAX := 100.0
## Energy lost per in-game hour awake, before traits and the sandbox dial. About two thirds of the bar over a
## sixteen-hour day, so an ordinary day ends tired but standing.
const ENERGY_PER_HOUR := 4.2
## Below this share of Energy, Stamina starts to suffer.
const LOW_ENERGY := 0.35
## How bad it gets at zero Energy: costs rise by this much, recovery falls to this share.
const TIRED_COST_PENALTY := 0.65
const TIRED_REGEN_FLOOR := 0.30

const STAMINA_REGEN := 16.0
## Recovery pauses for a moment after spending, so mashing an action cannot be papered over by regen.
const STAMINA_REGEN_DELAY := 0.7

## Sustained costs are per second; one-shot costs are the whole action. `discipline` names the mastery that
## discounts it — an empty discipline can never be discounted.
const COSTS := {
	"sprint":  {"rate": 6.0, "discipline": "speed"},
	"swim":    {"rate": 3.2, "discipline": "stamina"},
	"climb":   {"rate": 8.0, "discipline": "mobility"},
	"skate":   {"rate": 1.2, "discipline": "agility"},
	"attack":  {"shot": 8.0, "discipline": "strength"},
	"dodge":   {"shot": 12.0, "discipline": "reflex"},
	"block":   {"rate": 4.0, "discipline": "resistance"},
	"power":   {"shot": 18.0, "discipline": ""},
}
## Mastery runs 1..10 in PlayerPowerProfile. This is where an ordinary action in that discipline becomes free.
const MASTERY_FREE_AT := 10.0

var max_health := MAX
var max_energy := MAX
var max_stamina := MAX
var health := MAX
var energy := MAX
var stamina := MAX

var _regen_block := 0.0
var _last_hour := -1

func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		_last_hour = int(tm.hour)
		tm.hour_changed.connect(_on_hour_changed)

# ------------------------------------------------------------------ energy
## Energy goes down with the clock, not with the frame, so it cannot be outrun by standing still or by a fast
## machine. Sleeping through hours does not drain them - sleep_restore() is what a night costs and pays.
func _on_hour_changed(hour: int) -> void:
	_last_hour = hour
	var scale := 1.0
	var rules := get_node_or_null("/root/GameRules")
	if rules:
		scale = float(rules.value("energy_drain_scale", 1.0))
	var traits := get_node_or_null("/root/TraitSystem")
	if traits:
		scale *= traits.multiplier("vitals.energy_drain")
	spend_energy(ENERGY_PER_HOUR * scale)

func spend_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var was := energy
	energy = clampf(energy - amount, 0.0, max_energy)
	if energy != was:
		energy_changed.emit(energy, max_energy)
	if energy <= 0.0 and was > 0.0:
		exhausted.emit()

## The only way Energy comes back: sleep, food, rest, or an activity this character actually enjoys. `source` is
## recorded so trait-driven recovery (milestone 4) can weight it without changing any caller.
func restore_energy(amount: float, source := "rest") -> void:
	if amount <= 0.0:
		return
	var traits := get_node_or_null("/root/TraitSystem")
	if traits:
		amount *= traits.multiplier("vitals.energy_from_" + source)
	var was := energy
	energy = clampf(energy + amount, 0.0, max_energy)
	if energy != was:
		energy_changed.emit(energy, max_energy)

## A full night. Not a straight refill: how much a night gives depends on how long it was.
func sleep_restore(hours: float) -> void:
	restore_energy(max_energy * clampf(hours / 8.0, 0.0, 1.0), "sleep")
	heal(clampf(hours / 8.0, 0.0, 1.0) * 12.0)

func energy_ratio() -> float:
	return energy / maxf(max_energy, 0.001)

func is_tired() -> bool:
	return energy_ratio() < LOW_ENERGY

# ----------------------------------------------------------------- stamina
## How far into "tired" we are: 0 while Energy is healthy, 1 at empty.
func _tired_amount() -> float:
	return clampf((LOW_ENERGY - energy_ratio()) / LOW_ENERGY, 0.0, 1.0)

## What one unit of `action` costs right now, after mastery and after tiredness.
func cost_of(action: String, amount := 1.0) -> float:
	var entry: Dictionary = COSTS.get(action, {})
	if entry.is_empty():
		return 0.0
	var base: float = float(entry.get("rate", entry.get("shot", 0.0))) * amount
	var discipline := String(entry.get("discipline", ""))
	if discipline != "":
		base *= 1.0 - clampf(_mastery(discipline) / MASTERY_FREE_AT, 0.0, 1.0)
	return base * (1.0 + TIRED_COST_PENALTY * _tired_amount())

func _mastery(discipline: String) -> float:
	var ps := get_node_or_null("/root/PowerSystem")
	if ps == null or ps.profile == null:
		return 1.0
	var table = ps.profile.get("universal_mastery")
	if table is Dictionary:
		return float((table as Dictionary).get(discipline, 1.0))
	return 1.0

## Spend on a sustained action (pass delta) or a one-shot (pass 1.0). Returns false if there was not enough, and in
## that case nothing is spent - so a dodge either happens properly or does not happen.
func spend_stamina(action: String, amount := 1.0, partial := true) -> bool:
	var cost := cost_of(action, amount)
	if cost <= 0.0:
		return true
	if cost > stamina and not partial:
		return false
	var was := stamina
	stamina = clampf(stamina - cost, 0.0, max_stamina)
	_regen_block = STAMINA_REGEN_DELAY
	if stamina != was:
		stamina_changed.emit(stamina, max_stamina)
	if stamina <= 0.0 and was > 0.0:
		winded.emit()
	return true

func can_afford(action: String, amount := 1.0) -> bool:
	return cost_of(action, amount) <= stamina

## Call every frame. Stamina is the only bar that recovers by itself.
func tick(delta: float) -> void:
	if _regen_block > 0.0:
		_regen_block = maxf(0.0, _regen_block - delta)
		return
	if stamina >= max_stamina:
		return
	var rate := STAMINA_REGEN * lerpf(1.0, TIRED_REGEN_FLOOR, _tired_amount())
	rate *= 1.0 + 0.10 * (_mastery("recovery") - 1.0)
	var was := stamina
	stamina = clampf(stamina + rate * delta, 0.0, max_stamina)
	if stamina != was:
		stamina_changed.emit(stamina, max_stamina)

# ------------------------------------------------------------------ health
func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var was := health
	health = clampf(health - amount, 0.0, max_health)
	if health != was:
		health_changed.emit(health, max_health)
	if health <= 0.0 and was > 0.0:
		collapsed.emit()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	var was := health
	health = clampf(health + amount, 0.0, max_health)
	if health != was:
		health_changed.emit(health, max_health)

func is_alive() -> bool:
	return health > 0.0

# ------------------------------------------------------------------ save
func to_save() -> Dictionary:
	return {"health": health, "energy": energy, "stamina": stamina,
		"max_health": max_health, "max_energy": max_energy, "max_stamina": max_stamina}

func from_save(d: Dictionary) -> void:
	max_health = float(d.get("max_health", MAX))
	max_energy = float(d.get("max_energy", MAX))
	max_stamina = float(d.get("max_stamina", MAX))
	health = clampf(float(d.get("health", max_health)), 0.0, max_health)
	energy = clampf(float(d.get("energy", max_energy)), 0.0, max_energy)
	stamina = clampf(float(d.get("stamina", max_stamina)), 0.0, max_stamina)
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)
	stamina_changed.emit(stamina, max_stamina)
