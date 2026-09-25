class_name ToriyamaRoster
## Which exported Toriyama character a resident wears (folders in res://character/toriyama/).
## Residents currently keep the primitive body; the Rolling Tides rivals (RivalRoster) wear their own models.
const NPC_CHARACTERS := {
	"jace": "Jace",
	"theo": "Theo",
	"blair": "Blair",
	"kira": "Kira",
	"maya_reyes": "Maya",
	"jones": "Jones",
}

## The player is custom: until the character creator exists, these presets stand in for it (F9 cycles them and the
## choice is remembered). Hero_* are the Rolling Tides hero looks; June is the original test character.
const PLAYER_LOOKS: Array[String] = ["Hero_RT", "Hero_Real", "Hero_Red", "Hero_Grunge", "Hero_Stripes", "June"]
const DEFAULT_PLAYER_LOOK := "Hero_RT"
const PLAYER_LOOK_SAVE := "user://player_look.cfg"

static func exists(name: String) -> bool:
	return name != "" and FileAccess.file_exists("res://character/toriyama/%s/manifest.json" % name)

static func for_npc(npc_id: String) -> String:
	var name: String = NPC_CHARACTERS.get(npc_id, "")
	return name if exists(name) else ""

static func available_player_looks() -> Array[String]:
	var out: Array[String] = []
	for look in PLAYER_LOOKS:
		if exists(look):
			out.append(look)
	return out

static func saved_player_look() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_LOOK_SAVE) == OK:
		var look: String = cfg.get_value("player", "look", "")
		if exists(look):
			return look
	for look in [DEFAULT_PLAYER_LOOK, "June"]:
		if exists(look):
			return look
	return ""

## The custom player built in the character creator. An empty Dictionary means "not created yet".
static func saved_recipe() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_LOOK_SAVE) != OK:
		return {}
	var text: String = cfg.get_value("player", "recipe", "")
	if text == "":
		return {}
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}

## The traits chosen at creation are part of the character, so they are saved and restored with it.
static func saved_traits() -> Array:
	return saved_recipe().get("traits", [])

static func save_recipe(recipe: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_LOOK_SAVE)
	cfg.set_value("player", "recipe", JSON.stringify(recipe))
	cfg.save(PLAYER_LOOK_SAVE)

static func clear_recipe() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_LOOK_SAVE) != OK:
		return
	cfg.set_value("player", "recipe", "")
	cfg.save(PLAYER_LOOK_SAVE)

static func save_player_look(look: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "look", look)
	cfg.save(PLAYER_LOOK_SAVE)
