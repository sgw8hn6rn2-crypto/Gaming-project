extends Control
## Placeholder save point outside the boss room.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var _t := 0.0


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


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		GameState.pending_boss_start_hp = -1
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, 320, 180), Color("#14141f"))
	draw_rect(Rect2(0, 120, 320, 60), Color("#1f1f2e"))
	# Boss door
	draw_rect(Rect2(230, 50, 50, 70), Color("#3a2a2a"))
	draw_rect(Rect2(236, 56, 38, 64), Color("#0c0808"))
	draw_string(font, Vector2(214, 44), "Boss room ahead", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.6, 0.6))
	# Save crystal
	var glow := 0.5 + 0.5 * sin(_t * 3.0)
	var c := Vector2(90, 100)
	draw_circle(c, 14 + glow * 3, Color(0.3, 0.7, 1.0, 0.15 + glow * 0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(8, 0), c + Vector2(0, 16), c + Vector2(-8, 0)]), Color("#4fc3f7"))
	draw_string(font, Vector2(56, 130), "Save point", HORIZONTAL_ALIGNMENT_CENTER, 68, 8, Color("#b3e5fc"))
	var n := GameState.loss_assist.losses(&"warden")
	if n > 0:
		draw_string(font, Vector2(0, 150), "Losses to the Warden: %d" % n, HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color(0.6, 0.6, 0.65))
	draw_string(font, Vector2(0, 166), "Press Z / Space / A to enter the boss room", HORIZONTAL_ALIGNMENT_CENTER, 320, 8, Color.WHITE)
