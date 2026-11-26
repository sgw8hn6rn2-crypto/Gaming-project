extends TestCase


func _atk(id: String, party_wide: bool, weight: int) -> BossAttack:
	var a := BossAttack.new()
	a.id = StringName(id)
	a.power = 1.0
	a.hit_times = PackedFloat32Array([1.0])
	a.party_wide = party_wide
	a.weight = weight
	return a


func _attacks() -> Array[BossAttack]:
	return [_atk("swing", false, 3), _atk("flurry", false, 3), _atk("wave", true, 2)]


func _targets(n := 4) -> Array[Battler]:
	var out: Array[Battler] = []
	for i in n:
		var d := BattlerData.new()
		d.id = StringName("t%d" % i)
		d.max_hp = 100
		out.append(Battler.new(d))
	return out


func test_deterministic_with_seed() -> void:
	var t := _targets()
	var b1 := BossBrain.new(_attacks(), 42)
	var b2 := BossBrain.new(_attacks(), 42)
	for i in 20:
		var c1: Dictionary = b1.choose(t)
		var c2: Dictionary = b2.choose(t)
		assert_eq(c1["attack"].id, c2["attack"].id, "choice %d" % i)
		assert_eq(c1["targets"], c2["targets"])


func test_no_triple_repeat() -> void:
	var t := _targets()
	var b := BossBrain.new(_attacks(), 7)
	var hist: Array = []
	for i in 500:
		hist.append(b.choose(t)["attack"].id)
	for i in range(2, hist.size()):
		assert_false(hist[i] == hist[i - 1] and hist[i] == hist[i - 2], "triple at %d" % i)


func test_party_wide_not_twice() -> void:
	var t := _targets()
	var b := BossBrain.new(_attacks(), 3)
	var prev_wide := false
	for i in 500:
		var wide: bool = b.choose(t)["attack"].party_wide
		assert_false(wide and prev_wide, "twice at %d" % i)
		prev_wide = wide


func test_party_wide_targets_all_living() -> void:
	var t := _targets()
	t[1].take_damage(100)
	var only_wave: Array[BossAttack] = [_atk("wave", true, 1), _atk("swing", false, 1)]
	var b := BossBrain.new(only_wave, 1)
	for i in 20:
		var c: Dictionary = b.choose(t)
		if c["attack"].party_wide:
			assert_eq(c["targets"].size(), 3)
			assert_false(c["targets"].has(t[1]))


func test_single_target_is_living() -> void:
	var t := _targets()
	t[0].take_damage(100)
	t[2].take_damage(100)
	var b := BossBrain.new(_attacks(), 11)
	for i in 100:
		var c: Dictionary = b.choose(t)
		for x in c["targets"]:
			assert_false(x.is_ko())
		if not c["attack"].party_wide:
			assert_eq(c["targets"].size(), 1)
