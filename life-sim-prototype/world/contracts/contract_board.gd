class_name ContractBoard
extends Interactable
## The adventurers' contract board by the Woodland Ruins. Opens the ContractPanel: postings you can take, contracts
## in progress, and turn-ins. It stands in for a client NPC - contracts are quests whose giver is "contract_board",
## so accepting and turning in go through QuestManager.handle_topic like any conversation.
## Optional extras (the Hollowed Moon ledger) are checked here when a contract completes.

func _ready() -> void:
	super._ready()
	collision_layer = 8
	collision_mask = 0
	var col := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(2.2, 2.4, 1.4); col.shape = sh
	col.position.y = 1.2
	add_child(col)
	var body := StaticBody3D.new()
	var bc := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.8, 2.0, 0.2); bc.shape = bs
	bc.position.y = 1.0
	body.add_child(bc)
	add_child(body)
	for x in [-0.8, 0.8]:
		var post := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(0.14, 2.2, 0.14); post.mesh = pm
		post.position = Vector3(x, 1.1, 0)
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.4, 0.28, 0.16); post.material_override = m
		add_child(post)
	var board := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.7, 1.1, 0.08); board.mesh = bm
	board.position = Vector3(0, 1.5, 0)
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(0.58, 0.42, 0.24); board.material_override = bmat
	add_child(board)
	for i in 3:
		var paper := MeshInstance3D.new(); var pp := BoxMesh.new(); pp.size = Vector3(0.36, 0.46, 0.01); paper.mesh = pp
		paper.position = Vector3(-0.5 + i * 0.5, 1.5 + (0.05 if i == 1 else -0.03), 0.05)
		var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.95, 0.92, 0.82); paper.material_override = pmat
		add_child(paper)
	var l := Label3D.new(); l.text = "CONTRACTS"; l.font_size = 48; l.pixel_size = 0.005; l.outline_size = 8
	l.position = Vector3(0, 2.35, 0.05)
	add_child(l)
	QuestManager.quest_completed.connect(_on_quest_completed)

func get_prompt() -> String:
	var turn_ins := QuestManager.topics_for("contract_board").filter(func(t): return String(t["id"]).contains(":deliver:"))
	return "Contract board — turn in a contract" if not turn_ins.is_empty() else "Contract board"

func interact(_player: Node) -> void:
	get_tree().root.add_child(ContractPanel.open())

## Accept a posting (panel button / tests).
static func accept(contract_id: String) -> Dictionary:
	return QuestManager.handle_topic("contract_board", "quest:%s:offer" % ContractCatalog.quest_id(contract_id))

## Turn in whatever contract is ready (panel button / tests). Returns the client's line, or "".
static func turn_in(contract_id: String) -> String:
	for t in QuestManager.topics_for("contract_board"):
		if String(t["id"]).begins_with("quest:%s:deliver" % ContractCatalog.quest_id(contract_id)):
			return String(QuestManager.handle_topic("contract_board", t["id"])["line"])
	return ""

func _on_quest_completed(quest_id: String) -> void:
	var q := QuestCatalog.by_id(quest_id)
	var c := ContractCatalog.by_id(String(q.get("contract", "")))
	if c.is_empty():
		return
	EventBus.fire("contract_completed", {"contract": c["id"], "type": c["type"], "client": c["client"]})
	var bonus: Array = c.get("bonus_item", [])
	if not bonus.is_empty() and InventoryManager.count(bonus[0]) > 0:
		InventoryManager.remove(bonus[0], 1)
		QuestManager.set_flag(bonus[1])
		Economy.earn(int(bonus[2]), "%s bonus" % c["title"])
		EventBus.fire("hud_message", {"text": "You handed over the %s too. +$%d - someone will want to read this." % [
			ContractCatalog.item_name(bonus[0]).to_lower(), bonus[2]]})
