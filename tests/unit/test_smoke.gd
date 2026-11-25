extends TestCase


func test_truth() -> void:
	assert_true(true)


func test_tuning_loaded() -> void:
	assert_almost(Tuning.ATTACK_PERFECT_MULT, 1.5)
