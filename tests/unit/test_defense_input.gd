extends TestCase

const S := TimingJudge.Move
const D := TimingJudge.DefenseResult
const FLURRY := [0.6, 0.9, 1.2]


func _run(presses: Array, releases: Array, style: int, moves: Array = []) -> Array:
	# Feeds press/release events and hit samples in time order, returns results per hit.
	var di := DefenseInput.new(PackedFloat32Array(FLURRY))
	var events: Array = []
	for k in presses.size():
		events.append([presses[k], "press", moves[k] if k < moves.size() else style])
	for t in releases:
		events.append([t, "release"])
	for i in FLURRY.size():
		events.append([FLURRY[i], "sample", i])
	events.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] == "sample" and b[1] != "sample"))
	for e in events:
		match e[1]:
			"press":
				di.press(e[0], e[2])
			"release":
				di.release()
			"sample":
				di.sample(e[2])
	var out: Array = []
	for i in FLURRY.size():
		var r: Dictionary = di.result(i)
		out.append(TimingJudge.judge_defense(r["move"], r["delta"], r["held"], r["carried"]))
	return out


func test_clean_presses_parry_each_hit() -> void:
	assert_eq(_run([0.6, 0.9, 1.2], [0.65, 0.95, 1.25], S.PARRY), [D.PERFECT_PARRY, D.PERFECT_PARRY, D.PERFECT_PARRY])


func test_mash_locks_out_every_hit() -> void:
	var presses: Array = []
	var releases: Array = []
	for k in 14:
		presses.append(0.1 + k * 0.1)
		releases.append(0.15 + k * 0.1)
	for style in [S.PARRY, S.DODGE]:
		assert_eq(_run(presses, releases, style), [D.MISS, D.MISS, D.MISS], "style %d" % style)


func test_block_hold_through_flurry() -> void:
	assert_eq(_run([0.45], [1.3], S.BLOCK), [D.BLOCK, D.BLOCK, D.BLOCK])


func test_hold_from_start_does_not_carry() -> void:
	assert_eq(_run([0.05], [1.3], S.BLOCK), [D.MISS, D.MISS, D.MISS])


func test_release_breaks_carry() -> void:
	assert_eq(_run([0.45], [0.7], S.BLOCK), [D.BLOCK, D.MISS, D.MISS])


func test_no_input_all_miss() -> void:
	assert_eq(_run([], [], S.PARRY), [D.MISS, D.MISS, D.MISS])


func test_different_move_per_hit() -> void:
	assert_eq(_run([0.6, 0.9, 1.1], [0.65, 0.95, 1.3], S.PARRY, [S.PARRY, S.DODGE, S.BLOCK]), [D.PERFECT_PARRY, D.DODGE, D.BLOCK])
