extends Control
## Shows the next few actors as small colored chips.

var _order: Array[Battler] = []
var _current: Battler


func show_order(order: Array[Battler], current: Battler) -> void:
	_order = order
	_current = current
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var x := 2.0
	draw_string(font, Vector2(x, 9), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.75))
	x += 24.0
	var list: Array[Battler] = []
	if _current:
		list.append(_current)
	list.append_array(_order)
	for i in list.size():
		var b := list[i]
		var w := 34.0
		var r := Rect2(x, 1, w, 11)
		draw_rect(r, b.data.color.darkened(0.3 if i > 0 else 0.0))
		if i == 0:
			draw_rect(r, Color.WHITE, false, 1.0)
		draw_string(font, Vector2(x + 2, 9), b.data.display_name.substr(0, 6), HORIZONTAL_ALIGNMENT_LEFT, w - 3, 8, Color.WHITE)
		x += w + 2
		if x > size.x - 30:
			break
