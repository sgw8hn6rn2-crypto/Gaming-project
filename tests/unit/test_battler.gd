extends TestCase


func _make(hp := 100) -> Battler:
	var d := BattlerData.new()
	d.id = &"t"
	d.max_hp = hp
	d.atk = 10
	d.def = 5
	d.speed = 10
	return Battler.new(d)


func test_starts_full() -> void:
	var b := _make()
	assert_eq(b.hp, 100)
	assert_eq(b.sp, 0)
	assert_almost(b.gauge, 0.0)
	assert_false(b.is_ko())


func test_damage_floors_at_zero() -> void:
	var b := _make()
	var taken := b.take_damage(150)
	assert_eq(b.hp, 0)
	assert_true(b.is_ko())
	assert_eq(taken, 100)


func test_heal_caps_at_max() -> void:
	var b := _make()
	b.take_damage(30)
	var healed := b.heal(50)
	assert_eq(b.hp, 100)
	assert_eq(healed, 30)


func test_heal_ignored_when_ko() -> void:
	var b := _make()
	b.take_damage(100)
	assert_eq(b.heal(50), 0)
	assert_eq(b.hp, 0)


func test_revive_only_from_ko() -> void:
	var b := _make()
	assert_false(b.revive(0.25))
	b.take_damage(100)
	assert_true(b.revive(0.25))
	assert_eq(b.hp, 25)


func test_sp_clamped() -> void:
	var b := _make()
	b.add_sp(9)
	assert_eq(b.sp, 5)
	b.add_sp(-20)
	assert_eq(b.sp, 0)


func test_full_restore() -> void:
	var b := _make()
	b.take_damage(100)
	b.add_sp(3)
	b.gauge = 40.0
	b.full_restore()
	assert_eq(b.hp, 100)
	assert_false(b.is_ko())
