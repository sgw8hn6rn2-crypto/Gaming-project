class_name DefenseInput
extends RefCounted
## Turns raw press/release events during an enemy attack into per-hit inputs.
## Times are seconds since the telegraph started.
## - Each press goes to the earliest hit that is still open and has no press
##   yet, so mashing burns through hits early and gets locked out.
## - A block hold that started inside the block window carries through later
##   hits of the same attack while it is held.

const RESOLVE_AFTER := 0.2  # a hit stops taking presses this long after it lands

var hit_times: PackedFloat32Array
var _press := PackedFloat64Array()
var _held: Array[bool] = []
var _carried: Array[bool] = []
var _holding := false
var _hold_start := 0.0
var _hold_valid := false


func _init(times: PackedFloat32Array) -> void:
	hit_times = times
	_press.resize(times.size())
	_press.fill(INF)
	for i in times.size():
		_held.append(false)
		_carried.append(false)


func press(t: float) -> void:
	_holding = true
	_hold_start = t
	_hold_valid = false
	for i in hit_times.size():
		if t > hit_times[i] + RESOLVE_AFTER or not is_inf(_press[i]):
			continue
		_press[i] = t
		var d := t - hit_times[i]
		_hold_valid = d >= -Tuning.BLOCK_EARLY_WINDOW - TimingJudge.EPS and d <= TimingJudge.EPS
		return


func release() -> void:
	_holding = false
	_hold_valid = false


## Call at the moment hit i lands.
func sample(i: int) -> void:
	_held[i] = _holding
	_carried[i] = i > 0 and _holding and _hold_valid and is_inf(_press[i]) and _hold_start < hit_times[i - 1]


## { "delta": float (INF if no press), "held": bool, "carried": bool }
func result(i: int) -> Dictionary:
	var d := INF if is_inf(_press[i]) else _press[i] - hit_times[i]
	return { "delta": d, "held": _held[i], "carried": _carried[i] }
