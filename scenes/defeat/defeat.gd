extends Control
## Shown after losing. Lists the loss-assist options for this boss.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SAVE_POINT_SCENE := "res://scenes/save_point/save_point.tscn"

var options: Array = []
var labels: Array[String] = []
var cursor := 0
var _boss_id: StringName
var _max_hp := 600


## Ignore input briefly so a player still mashing from the fight does not pick
## an option by accident.
const INPUT_GRACE := 0.5

var _opened_at := 0


func accepts_input() -> bool:
	return Time.get_ticks_msec() - _opened_at >= INPUT_GRACE * 1000.0


func _ready() -> void:
	_opened_at = Time.get_ticks_msec()
	var t := Theme.new()
	t.default_font_size = 8
	theme = t
	_boss_id = GameState.last_boss_id if GameState.last_boss_id != &"" else &"warden"
	_max_hp = Content.warden().max_hp
	var la: LossAssist = GameState.loss_assist
	options = la.options(_boss_id)
	for o in options:
		labels.append(_label_for(o, la))


func _label_for(o: LossAssist.Option, la: LossAssist) -> String:
	match o:
		LossAssist.Option.RETRY_FULL:
			return "Retry now"
		LossAssist.Option.RETRY_KEEP_HP:
			return "Retry now, boss keeps its damage (%d HP)" % la.start_hp(_boss_id, o, _max_hp)
		LossAssist.Option.RETRY_ONE_HP:
			return "Retry now, boss at 1 HP"
	return "Return to save point"


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if event.is_action_pressed("ui_up"):
		cursor = wrapi(cursor - 1, 0, options.size())
	elif event.is_action_pressed("ui_down"):
		cursor = wrapi(cursor + 1, 0, options.size())
	elif event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_choose(options[cursor])
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _choose(o: LossAssist.Option) -> void:
	if o == LossAssist.Option.SAVE_POINT:
		GameState.pending_boss_start_hp = -1
		get_tree().change_scene_to_file(SAVE_POINT_SCENE)
		return
	GameState.pending_boss_start_hp = GameState.loss_assist.start_hp(_boss_id, o, _max_hp)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, 320, 180), Color("#120c14"))
	var n := GameState.loss_assist.losses(_boss_id)
	draw_string(font, Vector2(0, 40), "DEFEATED", HORIZONTAL_ALIGNMENT_CENTER, 320, 16, Color("#ef5350"))
	draw_string(font, Vector2(0, 56), "Losses to this boss: %d" % n, HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color(0.7, 0.7, 0.75))
	for i in labels.size():
		var y := 84.0 + i * 14.0
		var col := Color.YELLOW if i == cursor else Color.WHITE
		if i == cursor:
			draw_string(font, Vector2(44, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		draw_string(font, Vector2(54, y), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 240, 8, col)
	draw_string(font, Vector2(0, 170), "Your party returns fully healed.", HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color(0.55, 0.55, 0.6))
