extends Control
## HP and SP for active members, plus the bench.

var _party: Party
var _actor: Battler


func refresh(party: Party, actor: Battler) -> void:
	_party = party
	_actor = actor
	queue_redraw()


func _draw() -> void:
	if _party == null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.12, 0.9))
	for i in _party.active.size():
		var b := _party.active[i]
		var y := 2.0 + i * 11.0
		var name_col := Color.YELLOW if b == _actor else (Color(0.5, 0.5, 0.5) if b.is_ko() else Color.WHITE)
		draw_string(font, Vector2(3, y + 8), b.data.display_name, HORIZONTAL_ALIGNMENT_LEFT, 40, 8, name_col)
		_bar(Vector2(46, y + 2), 60, float(b.hp) / b.data.max_hp, Color("#4caf50"))
		draw_string(font, Vector2(110, y + 8), "%d" % b.hp, HORIZONTAL_ALIGNMENT_LEFT, 24, 8, Color.WHITE)
		for s in Tuning.SP_MAX:
			var c := Color("#4fc3f7") if s < b.sp else Color(0.25, 0.25, 0.3)
			draw_rect(Rect2(136 + s * 5, y + 3, 4, 4), c)
	var by := 2.0 + _party.active.size() * 11.0
	var bench_text := "Bench:"
	for b in _party.bench:
		bench_text += "  %s %d" % [b.data.display_name, b.hp]
	draw_string(font, Vector2(3, by + 8), bench_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, 8, Color(0.75, 0.75, 0.8))


func _bar(pos: Vector2, w: float, pct: float, col: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w, 5)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(pos, Vector2(w * clampf(pct, 0.0, 1.0), 5)), col)
