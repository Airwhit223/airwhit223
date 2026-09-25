class_name BasketballHoop
extends Area3D
## Scoring detector positioned at the net, just below the rim. Any physical
## basketball body that passes through counts as a made shot.

const SCORE_COOLDOWN := 0.6

var score: int = 0
var _cooldown: float = 0.0

func _ready() -> void:
	add_to_group("basketball_hoops")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func get_scoring_position() -> Vector3:
	return global_position

func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("basketballs"):
		_cooldown = SCORE_COOLDOWN
		score += 1
		AudioManager.play_sfx("basketball_score", global_position)
		EventBus.fire("basketball_scored", {"score": score})
		body.schedule_reset_after_score()
