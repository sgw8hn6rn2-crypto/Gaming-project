extends TestCase

const O := LossAssist.Option


func _opts_for(n: int) -> Array:
	var la := LossAssist.new()
	la.debug_set_losses(&"boss", n)
	return la.options(&"boss")


func test_tiers() -> void:
	var S := O.SAVE_POINT
	var F := O.RETRY_FULL
	var K := O.RETRY_KEEP_HP
	var X := O.RETRY_ONE_HP
	var cases := {
		0: [S], 1: [S], 3: [S],
		4: [S, F], 10: [S, F],
		11: [S, F, K], 20: [S, F, K],
		21: [S, F, K, X], 50: [S, F, K, X],
	}
	for n in cases:
		var got: Array = _opts_for(n)
		assert_eq(got, cases[n], "losses=%d" % n)


func test_record_loss_counts() -> void:
	var la := LossAssist.new()
	for i in 4:
		la.record_loss(&"boss", 300, 600)
	assert_eq(la.losses(&"boss"), 4)
	assert_true(la.options(&"boss").has(O.RETRY_FULL))


func test_per_boss() -> void:
	var la := LossAssist.new()
	for i in 5:
		la.record_loss(&"a", 100, 600)
	assert_eq(la.losses(&"b"), 0)
	assert_eq(la.options(&"b"), [O.SAVE_POINT])


func test_victory_resets() -> void:
	var la := LossAssist.new()
	for i in 12:
		la.record_loss(&"a", 100, 600)
	la.record_victory(&"a")
	assert_eq(la.losses(&"a"), 0)
	assert_eq(la.start_hp(&"a", O.RETRY_KEEP_HP, 600), 600)


func test_keep_hp_uses_last_loss() -> void:
	var la := LossAssist.new()
	la.record_loss(&"a", 400, 600)
	la.record_loss(&"a", 250, 600)
	assert_eq(la.start_hp(&"a", O.RETRY_KEEP_HP, 600), 250)


func test_keep_hp_clamped() -> void:
	var la := LossAssist.new()
	la.record_loss(&"a", 0, 600)
	assert_eq(la.start_hp(&"a", O.RETRY_KEEP_HP, 600), 1)
	la.record_loss(&"a", 9999, 600)
	assert_eq(la.start_hp(&"a", O.RETRY_KEEP_HP, 600), 600)


func test_full_and_save_point_hp() -> void:
	var la := LossAssist.new()
	la.record_loss(&"a", 100, 600)
	assert_eq(la.start_hp(&"a", O.SAVE_POINT, 600), 600)
	assert_eq(la.start_hp(&"a", O.RETRY_FULL, 600), 600)


func test_one_hp() -> void:
	var la := LossAssist.new()
	assert_eq(la.start_hp(&"a", O.RETRY_ONE_HP, 600), 1)
