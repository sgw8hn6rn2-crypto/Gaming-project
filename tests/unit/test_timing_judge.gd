extends TestCase

const S := BattlerData.DefenseStyle
const A := TimingJudge.AttackResult
const D := TimingJudge.DefenseResult


func test_attack_windows() -> void:
	assert_eq(TimingJudge.judge_attack(0.0), A.PERFECT)
	assert_eq(TimingJudge.judge_attack(0.06), A.PERFECT)
	assert_eq(TimingJudge.judge_attack(-0.1), A.GOOD)
	assert_eq(TimingJudge.judge_attack(0.3), A.NORMAL)
	assert_eq(TimingJudge.judge_attack(INF), A.NORMAL)


func test_attack_mults() -> void:
	assert_almost(TimingJudge.attack_mult(A.PERFECT), 1.5)
	assert_almost(TimingJudge.attack_mult(A.GOOD), 1.2)
	assert_almost(TimingJudge.attack_mult(A.NORMAL), 1.0)


func test_parry_windows() -> void:
	assert_eq(TimingJudge.judge_defense(S.PARRY, 0.04, false), D.PERFECT_PARRY)
	assert_eq(TimingJudge.judge_defense(S.PARRY, 0.12, false), D.GRAZE)
	assert_eq(TimingJudge.judge_defense(S.PARRY, 0.3, false), D.MISS)


func test_dodge_windows() -> void:
	assert_eq(TimingJudge.judge_defense(S.DODGE, -0.09, false), D.DODGE)
	assert_eq(TimingJudge.judge_defense(S.DODGE, 0.18, false), D.GRAZE)


func test_block_windows() -> void:
	assert_eq(TimingJudge.judge_defense(S.BLOCK, -0.25, true), D.BLOCK)
	assert_eq(TimingJudge.judge_defense(S.BLOCK, -0.25, false), D.MISS)
	assert_eq(TimingJudge.judge_defense(S.BLOCK, 0.1, true), D.GRAZE)


func test_no_press_is_miss() -> void:
	for style in [S.PARRY, S.DODGE, S.BLOCK]:
		assert_eq(TimingJudge.judge_defense(style, INF, false), D.MISS)


func test_mash_before_window_locks_out() -> void:
	for style in [S.PARRY, S.DODGE, S.BLOCK]:
		assert_eq(TimingJudge.judge_defense(style, -0.5, true), D.MISS, "style %d" % style)


func test_defense_mults() -> void:
	assert_almost(TimingJudge.defense_mult(D.PERFECT_PARRY), 0.0)
	assert_almost(TimingJudge.defense_mult(D.DODGE), 0.0)
	assert_almost(TimingJudge.defense_mult(D.BLOCK), 0.25)
	assert_almost(TimingJudge.defense_mult(D.GRAZE), 0.5)
	assert_almost(TimingJudge.defense_mult(D.MISS), 1.0)


func test_counter_only_on_perfect_parry() -> void:
	assert_true(TimingJudge.grants_counter(D.PERFECT_PARRY))
	for r in [D.DODGE, D.BLOCK, D.GRAZE, D.MISS]:
		assert_false(TimingJudge.grants_counter(r))


func test_block_carried_hold_blocks() -> void:
	assert_eq(TimingJudge.judge_defense(S.BLOCK, INF, true, true), D.BLOCK)


func test_carried_hold_ignored_for_tap_styles() -> void:
	assert_eq(TimingJudge.judge_defense(S.PARRY, INF, true, true), D.MISS)
	assert_eq(TimingJudge.judge_defense(S.DODGE, INF, true, true), D.MISS)
