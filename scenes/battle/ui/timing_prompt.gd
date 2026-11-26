extends Control
## Draws the shrinking ring for attacks and the closing square for defense.

var ring_center := Vector2.ZERO
var ring_progress := -1.0  # 0..1 while visible, -1 hidden
var square_centers: Array[Vector2] = []
var square_progresses := PackedFloat32Array()  # one 0..1 entry per upcoming hit


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ring_progress >= 0.0:
		var r := lerpf(28.0, 6.0, clampf(ring_progress, 0.0, 1.0))
		draw_arc(ring_center, 6.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
		draw_arc(ring_center, r, 0, TAU, 32, Color.YELLOW, 1.5)
	if square_progresses.is_empty():
		return
	for c in square_centers:
		draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(1, 1, 1, 0.5), false, 1.0)
		for p in square_progresses:
			var k := clampf(p, 0.0, 1.0)
			var half := lerpf(26.0, 9.0, k)
			var col := Color.YELLOW if k < 0.85 else Color.WHITE
			draw_rect(Rect2(c - Vector2(half, half), Vector2(half * 2, half * 2)), col, false, 1.5)
