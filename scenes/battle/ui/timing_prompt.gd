extends Control
## Draws the shrinking timing ring for attacks and the "!" cue for defense.

var ring_center := Vector2.ZERO
var ring_progress := -1.0  # 0..1 while visible, -1 hidden
var cue_positions: Array[Vector2] = []
var cue_visible := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ring_progress >= 0.0:
		var r := lerpf(28.0, 6.0, clampf(ring_progress, 0.0, 1.0))
		draw_arc(ring_center, 6.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
		draw_arc(ring_center, r, 0, TAU, 32, Color.YELLOW, 1.5)
	if cue_visible:
		var font := get_theme_default_font()
		for p in cue_positions:
			draw_string(font, p + Vector2(-3, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
