extends Node
## Clean, silent-safe audio hooks. Every call site in the game (basketball,
## interactions, dialogue, skateboard...) already routes through here — there
## are just no sound files yet. Drop a file in and point its name at the path
## below; everything that plays it is already wired up. With an empty path
## (or a missing file) every call is a safe no-op, so the game runs silently.

const SFX_PATHS := {
	"footstep": "",
	"interact_click": "",
	"basketball_bounce": "",
	"basketball_shot": "",
	"basketball_score": "",
	"skateboard_mount": "",
	"skateboard_roll": "",
	"gym_equipment": "",
	"register_use": "",
	"dialogue_open": "",
	"dialogue_close": "",
	"ui_toast": "",
	"door": "",
	"sleep": "",
}

const MUSIC_PATHS := {
	"ambient_neighborhood": "",
}

var _music_player: AudioStreamPlayer

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

## Positional one-shot sound (basketball bounce, register beep...). Safe to
## call with no file registered or present — it just does nothing.
func play_sfx(sound_name: String, at_position: Vector3 = Vector3.ZERO) -> void:
	var path: String = SFX_PATHS.get(sound_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	get_tree().root.add_child(player)
	player.global_position = at_position
	player.finished.connect(player.queue_free)
	player.play()

## Non-positional one-shot sound (UI clicks, dialogue open/close...).
func play_ui_sfx(sound_name: String) -> void:
	var path: String = SFX_PATHS.get(sound_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_music(music_name: String) -> void:
	var path: String = MUSIC_PATHS.get(music_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	_music_player.stream = load(path)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
