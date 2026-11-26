extends TestCase


func test_basic_damage() -> void:
	assert_eq(DamageCalc.damage(20, 1.0, 1.0, 10), 15)


func test_perfect_mult_damage() -> void:
	assert_eq(DamageCalc.damage(20, 1.0, 1.5, 10), 25)


func test_minimum_one() -> void:
	assert_eq(DamageCalc.damage(1, 1.0, 1.0, 50), 1)


func test_zero_mult_is_zero() -> void:
	assert_eq(DamageCalc.damage(20, 1.0, 0.0, 10), 0)


func test_heal_amount() -> void:
	assert_eq(DamageCalc.heal_amount(130, 0.4), 52)


func test_counter_damage() -> void:
	assert_eq(DamageCalc.counter_damage(20, 10), 5)
