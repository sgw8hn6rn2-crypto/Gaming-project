extends TestCase


func _b(name: String, speed: int) -> Battler:
	var d := BattlerData.new()
	d.id = StringName(name)
	d.display_name = name
	d.max_hp = 100
	d.speed = speed
	return Battler.new(d)


func test_faster_acts_first() -> void:
	var slow := _b("slow", 10)
	var fast := _b("fast", 20)
	var t := TurnTimeline.new([slow, fast])
	assert_eq(t.next_actor(), fast)


func test_double_speed_acts_twice() -> void:
	var slow := _b("slow", 10)
	var fast := _b("fast", 20)
	var t := TurnTimeline.new([slow, fast])
	var count := 0
	for b in t.preview(6):
		if b == fast:
			count += 1
	assert_eq(count, 4)


func test_preview_does_not_mutate() -> void:
	var a := _b("a", 10)
	var b := _b("b", 17)
	var t := TurnTimeline.new([a, b])
	t.next_actor()
	var ga := a.gauge
	var gb := b.gauge
	t.preview(8)
	assert_almost(a.gauge, ga)
	assert_almost(b.gauge, gb)


func test_preview_matches_real_order() -> void:
	var a := _b("a", 9)
	var b := _b("b", 14)
	var c := _b("c", 11)
	var t := TurnTimeline.new([a, b, c])
	var predicted := t.preview(10)
	for i in 10:
		assert_eq(t.next_actor(), predicted[i], "turn %d" % i)


func test_ko_skipped() -> void:
	var a := _b("a", 30)
	var b := _b("b", 10)
	a.take_damage(100)
	var t := TurnTimeline.new([a, b])
	for i in 3:
		assert_eq(t.next_actor(), b)
	assert_almost(a.gauge, 0.0)


func test_tie_breaks_by_order() -> void:
	var a := _b("a", 10)
	var b := _b("b", 10)
	var t := TurnTimeline.new([a, b])
	assert_eq(t.next_actor(), a)
	assert_eq(t.next_actor(), b)


func test_swap_inherits_gauge() -> void:
	var a := _b("a", 10)
	var other := _b("other", 50)
	var fresh := _b("fresh", 10)
	var t := TurnTimeline.new([a, other])
	t.next_actor()
	var g := a.gauge
	assert_true(g > 0.0)
	t.replace(a, fresh)
	assert_almost(fresh.gauge, g)
	assert_eq(t.battlers[0], fresh)
