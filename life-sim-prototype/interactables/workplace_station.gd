class_name WorkplaceStation
extends Interactable
## Where a job's shift starts and ends: the restaurant's time clock, Grandpa's task board, the skate shop bench.
## Walk up, press E: "Start Shift" (pick a length) - or, mid-shift, "Finish Shift" (results + pay).
## The shift also ends by itself when its hours run out on the game clock.

@export var job_id: String = "restaurant_cook"

func _ready() -> void:
	super._ready()
	JobManager.shift_started.connect(func(_j, _h) -> void: set_process(true))
	set_process(false)

func get_prompt() -> String:
	var job := JobCatalog.get_job(job_id)
	if JobManager.is_working():
		return "Finish Shift" if JobManager.shift["job"] == job_id else "(On another shift)"
	return "Start Shift — %s" % job.get("name", job_id)

func interact(_player: Node) -> void:
	if JobManager.is_working():
		if JobManager.shift["job"] == job_id:
			_finish()
		return
	get_tree().root.add_child(JobPanel.open_start(job_id))

func _process(_delta: float) -> void:
	if not JobManager.is_working() or JobManager.shift["job"] != job_id:
		set_process(false)
		return
	var elapsed := int(TimeManager.get_total_minutes()) - int(JobManager.shift["started_min"])
	if elapsed >= int(JobManager.shift["hours"]) * 60:
		_finish()

func _finish() -> void:
	var summary := JobManager.finish_shift()
	if not summary.is_empty():
		get_tree().root.add_child(JobPanel.open_results(summary))
