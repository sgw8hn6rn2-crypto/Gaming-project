extends TestCase


func _party() -> Party:
	var members: Array[Battler] = []
	for i in 6:
		var d := BattlerData.new()
		d.id = StringName("m%d" % i)
		d.max_hp = 100
		d.speed = 10
		members.append(Battler.new(d))
	return Party.new(members)


func test_initial_slots() -> void:
	var p := _party()
	assert_eq(p.active.size(), 4)
	assert_eq(p.bench.size(), 2)
	assert_eq(p.active[0].data.id, &"m0")
	assert_eq(p.bench[0].data.id, &"m4")


func test_one_swap_per_turn() -> void:
	var p := _party()
	p.begin_turn()
	assert_true(p.swap(0, 0))
	assert_eq(p.active[0].data.id, &"m4")
	assert_eq(p.bench[0].data.id, &"m0")
	assert_false(p.can_swap(1, 1))
	assert_false(p.swap(1, 1))
	p.begin_turn()
	assert_true(p.swap(1, 1))


func test_cannot_swap_in_ko() -> void:
	var p := _party()
	p.begin_turn()
	p.bench[0].take_damage(100)
	assert_false(p.swap(0, 0))
	assert_eq(p.active[0].data.id, &"m0")
	assert_true(p.swap(0, 1), "allowance not used by refused swap")


func test_swap_out_ko_active_allowed() -> void:
	var p := _party()
	p.begin_turn()
	p.active[2].take_damage(100)
	assert_true(p.swap(2, 0))
	assert_false(p.active[2].is_ko())


func test_bad_indices_refused() -> void:
	var p := _party()
	p.begin_turn()
	assert_false(p.swap(4, 0))
	assert_false(p.swap(0, 2))
	assert_false(p.swap(-1, 0))


func test_bench_recover_5pct() -> void:
	var p := _party()
	p.bench[0].take_damage(50)
	p.bench[1].take_damage(100)
	p.bench_recover()
	assert_eq(p.bench[0].hp, 55)
	assert_eq(p.bench[1].hp, 0)


func test_auto_fill_when_all_active_down() -> void:
	var p := _party()
	for b in p.active:
		b.take_damage(100)
	var pairs := p.auto_fill()
	assert_eq(pairs.size(), 2)
	assert_eq(p.living_active().size(), 2)
	assert_false(p.is_wiped())


func test_auto_fill_noop_when_someone_alive() -> void:
	var p := _party()
	for i in 3:
		p.active[i].take_damage(100)
	assert_eq(p.auto_fill().size(), 0)


func test_auto_fill_does_not_use_swap() -> void:
	var p := _party()
	p.begin_turn()
	for b in p.active:
		b.take_damage(100)
	p.auto_fill()
	assert_false(p.swap_used)


func test_wipe_requires_all_six() -> void:
	var p := _party()
	for b in p.active:
		b.take_damage(100)
	p.bench[0].take_damage(100)
	assert_false(p.is_wiped())
	p.bench[1].take_damage(100)
	assert_true(p.is_wiped())


func test_full_restore_all() -> void:
	var p := _party()
	for b in p.active:
		b.take_damage(100)
	p.full_restore_all()
	assert_eq(p.living_active().size(), 4)
