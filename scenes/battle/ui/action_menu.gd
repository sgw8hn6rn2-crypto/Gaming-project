extends Control
## Action menu: Attack, Skill, Item, Swap, with sub-menus for targets.
## Up/down to move, action or accept to confirm, cancel to go back.

signal attack_chosen
signal skill_chosen(skill: SkillData, target: Battler)
signal item_chosen(item_id: String, target: Battler)
signal swap_chosen(active_idx: int, bench_idx: int)

enum Mode { MAIN, SKILL, ITEM, TARGET, SWAP_OUT, SWAP_IN }

const ITEM_NAMES := { "potion": "Potion", "revive": "Revive Tonic" }

var ctrl: BattleController
var mode: Mode = Mode.MAIN
var cursor := 0
var _entries: Array = []  # [{ "label": String, "enabled": bool, "value": Variant }]
var _pending_skill: SkillData
var _pending_item := ""
var _swap_out_idx := -1
var _active := false


func open(controller: BattleController) -> void:
	ctrl = controller
	_active = true
	_set_mode(Mode.MAIN)
	show()


func close() -> void:
	_active = false
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _entries.is_empty():
		return
	cursor = wrapi(cursor + d, 0, _entries.size())
	queue_redraw()


func _back() -> void:
	match mode:
		Mode.SKILL, Mode.ITEM, Mode.SWAP_OUT:
			_set_mode(Mode.MAIN)
		Mode.TARGET:
			_set_mode(Mode.SKILL if _pending_skill else Mode.ITEM)
		Mode.SWAP_IN:
			_set_mode(Mode.SWAP_OUT)


func _confirm() -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries[cursor]
	if not e["enabled"]:
		return
	match mode:
		Mode.MAIN:
			match e["value"]:
				"attack":
					close()
					attack_chosen.emit()
				"skill":
					_set_mode(Mode.SKILL)
				"item":
					_set_mode(Mode.ITEM)
				"swap":
					_set_mode(Mode.SWAP_OUT)
		Mode.SKILL:
			_pending_skill = e["value"]
			_pending_item = ""
			match _pending_skill.target:
				SkillData.Target.ENEMY:
					close()
					skill_chosen.emit(_pending_skill, ctrl.boss)
				SkillData.Target.ALL_ALLIES:
					close()
					skill_chosen.emit(_pending_skill, ctrl.actor)
				_:
					_set_mode(Mode.TARGET)
		Mode.ITEM:
			_pending_item = e["value"]
			_pending_skill = null
			_set_mode(Mode.TARGET)
		Mode.TARGET:
			close()
			if _pending_skill:
				skill_chosen.emit(_pending_skill, e["value"])
			else:
				item_chosen.emit(_pending_item, e["value"])
		Mode.SWAP_OUT:
			_swap_out_idx = e["value"]
			_set_mode(Mode.SWAP_IN)
		Mode.SWAP_IN:
			swap_chosen.emit(_swap_out_idx, e["value"])
			_set_mode(Mode.MAIN)


func _set_mode(m: Mode) -> void:
	mode = m
	cursor = 0
	_entries = []
	var actor := ctrl.actor
	match m:
		Mode.MAIN:
			_entries = [
				{ "label": "Attack", "enabled": true, "value": "attack" },
				{ "label": "Skill", "enabled": not actor.data.skills.is_empty(), "value": "skill" },
				{ "label": "Item", "enabled": true, "value": "item" },
				{ "label": "Swap", "enabled": not ctrl.party.swap_used, "value": "swap" },
			]
		Mode.SKILL:
			for s in actor.data.skills:
				_entries.append({ "label": "%s (%d SP)" % [s.display_name, s.sp_cost], "enabled": actor.sp >= s.sp_cost, "value": s })
		Mode.ITEM:
			for id in ctrl.items:
				_entries.append({ "label": "%s x%d" % [ITEM_NAMES.get(id, id), ctrl.items[id]], "enabled": ctrl.items[id] > 0, "value": id })
		Mode.TARGET:
			var want_ko := (_pending_skill and _pending_skill.target == SkillData.Target.ALLY_KO) or _pending_item == "revive"
			for b in ctrl.party.active:
				_entries.append({ "label": "%s %d/%d" % [b.data.display_name, b.hp, b.data.max_hp], "enabled": b.is_ko() == want_ko, "value": b })
		Mode.SWAP_OUT:
			for i in ctrl.party.active.size():
				var b := ctrl.party.active[i]
				_entries.append({ "label": "Out: %s" % b.data.display_name, "enabled": true, "value": i })
		Mode.SWAP_IN:
			for i in ctrl.party.bench.size():
				var b := ctrl.party.bench[i]
				_entries.append({ "label": "In: %s %d" % [b.data.display_name, b.hp], "enabled": not b.is_ko(), "value": i })
	queue_redraw()


func _draw() -> void:
	if ctrl == null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.12, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.6, 0.7), false, 1.0)
	var first := maxi(0, cursor - 4)
	for i in range(first, mini(_entries.size(), first + 5)):
		var e: Dictionary = _entries[i]
		var y := 3.0 + (i - first) * 10.0
		var col := Color.WHITE if e["enabled"] else Color(0.45, 0.45, 0.5)
		if i == cursor:
			draw_string(font, Vector2(3, y + 8), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.YELLOW)
		draw_string(font, Vector2(11, y + 8), e["label"], HORIZONTAL_ALIGNMENT_LEFT, size.x - 13, 8, col)
