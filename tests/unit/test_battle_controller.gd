extends TestCase

const P := BattleController.Phase
const M := TimingJudge.Move


func _member(i: int, speed: int) -> Battler:
	var d := BattlerData.new()
	d.id = StringName("m%d" % i)
	d.display_name = "M%d" % i
	d.max_hp = 100
	d.atk = 20
	d.def = 10
	d.speed = speed
	var sk := SkillData.new()
	sk.id = &"big"
	sk.sp_cost = 2
	sk.power = 2.0
	sk.target = SkillData.Target.ENEMY
	sk.effect = SkillData.Effect.DAMAGE
	sk.timed = true
	d.skills = [sk]
	return Battler.new(d)


func _party(first_speed := 30) -> Party:
	var m: Array[Battler] = []
	for i in 6:
		m.append(_member(i, first_speed if i == 0 else 10))
	return Party.new(m)


func _boss(speed := 5, atk := 30, hp := 600) -> Battler:
	var d := BattlerData.new()
	d.id = &"boss"
	d.max_hp = hp
	d.atk = atk
	d.def = 10
	d.speed = speed
	return Battler.new(d)


func _attack(party_wide := false, hits := 1, power := 1.0) -> BossAttack:
	var a := BossAttack.new()
	a.id = &"wide" if party_wide else &"single"
	a.power = power
	var times := PackedFloat32Array()
	for i in hits:
		times.append(0.6 + 0.3 * i)
	a.hit_times = times
	a.party_wide = party_wide
	a.weight = 1
	return a


func _ctrl(party: Party, boss: Battler, attacks: Array[BossAttack], start_hp := -1) -> BattleController:
	var c := BattleController.new(party, boss, attacks, 1, start_hp)
	c.start()
	return c


func test_first_actor_is_fastest() -> void:
	var p := _party(30)
	var c := _ctrl(p, _boss(), [_attack()])
	assert_eq(c.actor, p.active[0])
	assert_eq(c.phase, P.PLAYER_CHOOSE)


func test_timed_attack_perfect_more_damage() -> void:
	var b1 := _boss()
	var c1 := _ctrl(_party(), b1, [_attack()])
	c1.choose_attack()
	assert_eq(c1.phase, P.PLAYER_TIMING)
	c1.resolve_player_timing(0.0)
	var b2 := _boss()
	var c2 := _ctrl(_party(), b2, [_attack()])
	c2.choose_attack()
	c2.resolve_player_timing(INF)
	assert_true(b1.hp < b2.hp, "perfect %d vs miss %d" % [b1.hp, b2.hp])


func test_miss_timing_still_hits() -> void:
	var b := _boss()
	var c := _ctrl(_party(), b, [_attack()])
	c.choose_attack()
	c.resolve_player_timing(INF)
	assert_eq(b.hp, 600 - DamageCalc.damage(20, 1.0, 1.0, 10))


func test_attack_gives_sp() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	c.choose_attack()
	c.resolve_player_timing(INF)
	assert_eq(p.active[0].sp, 1)


func test_skill_needs_sp() -> void:
	var p := _party()
	var b := _boss()
	var c := _ctrl(p, b, [_attack()])
	var sk: SkillData = p.active[0].data.skills[0]
	assert_false(c.choose_skill(sk, b))
	assert_eq(c.phase, P.PLAYER_CHOOSE)
	p.active[0].add_sp(2)
	assert_true(c.choose_skill(sk, b))
	assert_eq(p.active[0].sp, 0)
	assert_eq(c.phase, P.PLAYER_TIMING)


func test_skill_wrong_target_refused() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	p.active[0].add_sp(5)
	assert_false(c.choose_skill(p.active[0].data.skills[0], p.active[1]))
	assert_eq(p.active[0].sp, 5)


func test_swap_does_not_end_turn() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	var actor := c.actor
	assert_true(c.swap(1, 0))
	assert_eq(c.phase, P.PLAYER_CHOOSE)
	assert_eq(c.actor, actor)
	assert_false(c.swap(2, 1), "second swap refused")


func test_cannot_swap_out_current_actor() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	var actor := c.actor
	assert_false(c.swap(0, 0))
	assert_eq(c.actor, actor)
	assert_eq(p.active[0], actor)
	assert_true(c.swap(1, 0), "allowance not used by refused swap")


func test_block_carried_hold_through_controller() -> void:
	var p := _party(1)
	var c := _ctrl(p, _boss(50), [_attack(false, 2)])
	var target: Battler = c.pending_targets[0]
	c.resolve_enemy_hit(0, M.BLOCK, -0.15, true)
	var after_one := target.hp
	c.resolve_enemy_hit(1, M.BLOCK, INF, true, true)
	assert_eq(100 - after_one, DamageCalc.damage(30, 1.0, Tuning.BLOCK_MULT, 10))
	assert_eq(after_one - target.hp, DamageCalc.damage(30, 1.0, Tuning.BLOCK_MULT, 10))


func test_perfect_parry_no_damage_and_counter() -> void:
	var p := _party(1)
	var b := _boss(50)
	var c := _ctrl(p, b, [_attack()])
	assert_eq(c.phase, P.ENEMY_DEFENSE)
	var target: Battler = c.pending_targets[0]
	c.resolve_enemy_hit(0, M.PARRY, 0.0, false)
	assert_eq(target.hp, 100)
	assert_eq(b.hp, 600 - DamageCalc.counter_damage(20, 10))
	assert_eq(target.sp, 1)


func test_miss_defense_full_damage() -> void:
	var p := _party(1)
	var b := _boss(50)
	var c := _ctrl(p, b, [_attack()])
	var target: Battler = c.pending_targets[0]
	c.resolve_enemy_hit(0, M.PARRY, INF, false)
	assert_eq(target.hp, 100 - DamageCalc.damage(30, 1.0, 1.0, 10))


func test_party_wide_one_input_all_targets() -> void:
	var p := _party(1)
	var c := _ctrl(p, _boss(50), [_attack(true)])
	assert_eq(c.pending_targets.size(), 4)
	c.resolve_enemy_hit(0, M.DODGE, 0.0, false)
	for t in p.active:
		assert_eq(t.hp, 100)


func test_multi_hit_each_hit_judged_once() -> void:
	var p := _party(1)
	var c := _ctrl(p, _boss(50), [_attack(false, 3, 0.5)])
	var target: Battler = c.pending_targets[0]
	c.resolve_enemy_hit(0, M.PARRY, INF, false)
	var after_one := target.hp
	c.resolve_enemy_hit(0, M.PARRY, INF, false)
	assert_eq(target.hp, after_one)
	assert_eq(c.phase, P.ENEMY_DEFENSE, "still waiting for hits 1 and 2")
	assert_eq(after_one, 100 - DamageCalc.damage(30, 0.5, 1.0, 10))


func test_turn_ends_after_last_hit() -> void:
	var p := _party(1)
	var c := _ctrl(p, _boss(12), [_attack(false, 2)])
	assert_eq(c.phase, P.ENEMY_DEFENSE)
	c.resolve_enemy_hit(0, M.PARRY, INF, false)
	c.resolve_enemy_hit(1, M.PARRY, INF, false)
	assert_eq(c.phase, P.PLAYER_CHOOSE)


func test_revive_item() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	p.active[1].take_damage(100)
	assert_false(c.choose_item("revive", p.active[2]), "living target refused")
	assert_true(c.choose_item("revive", p.active[1]))
	assert_eq(p.active[1].hp, 25)
	assert_eq(c.items["revive"], 1)


func test_potion_item() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	p.active[1].take_damage(60)
	assert_true(c.choose_item("potion", p.active[1]))
	assert_eq(p.active[1].hp, 80)
	assert_eq(c.items["potion"], 2)


func test_victory_when_boss_zero() -> void:
	var b := _boss()
	var c := _ctrl(_party(), b, [_attack()], 1)
	var ended := []
	c.battle_ended.connect(func(v: bool) -> void: ended.append(v))
	c.choose_attack()
	c.resolve_player_timing(INF)
	assert_eq(c.phase, P.VICTORY)
	assert_eq(ended, [true])


func test_defeat_only_when_all_six_down() -> void:
	var p := _party(1)
	var c := _ctrl(p, _boss(50, 1000), [_attack(true)])
	c.resolve_enemy_hit(0, M.PARRY, INF, false)
	assert_true(c.phase != P.DEFEAT, "bench still alive")
	assert_eq(p.living_active().size(), 2)
	var guard := 0
	while c.phase != P.DEFEAT and c.phase != P.VICTORY and guard < 50:
		guard += 1
		if c.phase == P.ENEMY_DEFENSE:
			for i in c.pending_attack.hit_times.size():
				c.resolve_enemy_hit(i, M.PARRY, INF, false)
		elif c.phase == P.PLAYER_CHOOSE:
			c.choose_attack()
			c.resolve_player_timing(INF)
	assert_eq(c.phase, P.DEFEAT)
	assert_true(p.is_wiped())


func test_boss_start_hp_respected() -> void:
	var b := _boss()
	_ctrl(_party(), b, [_attack()], 1)
	assert_eq(b.hp, 1)


func test_bench_recovers_after_party_turn() -> void:
	var p := _party()
	var c := _ctrl(p, _boss(), [_attack()])
	p.bench[0].take_damage(50)
	c.choose_attack()
	c.resolve_player_timing(INF)
	assert_eq(p.bench[0].hp, 55)


func _party_wide_labels(move: int, delta: float) -> Dictionary:
	var p := _party(1)
	var c := _ctrl(p, _boss(50), [_attack(true)])
	var labels: Array = []
	var counters := [0]
	c.damage_dealt.connect(func(t: Battler, _amt: int, label: String) -> void:
		if t == c.boss:
			counters[0] += 1
		else:
			labels.append(label))
	c.resolve_enemy_hit(0, move, delta, false)
	return { "labels": labels, "counters": counters[0], "party": p }


func test_party_wide_same_result_for_mixed_styles() -> void:
	var r := _party_wide_labels(M.DODGE, 0.08)
	assert_eq(r["labels"], ["DODGE", "DODGE", "DODGE", "DODGE"])
	for t in r["party"].active:
		assert_eq(t.hp, 100)


func test_party_wide_perfect_is_parry_with_one_counter() -> void:
	var r := _party_wide_labels(M.PARRY, 0.0)
	assert_eq(r["labels"], ["PARRY!", "PARRY!", "PARRY!", "PARRY!"])
	assert_eq(r["counters"], 1)


func test_party_wide_graze_half_damage_for_all() -> void:
	var r := _party_wide_labels(M.PARRY, 0.12)
	assert_eq(r["labels"], ["GRAZE", "GRAZE", "GRAZE", "GRAZE"])
