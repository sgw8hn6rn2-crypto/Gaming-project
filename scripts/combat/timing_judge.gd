class_name TimingJudge
extends RefCounted
## Turns a button press time into a timing result.
## press_delta = press time minus impact time, in seconds. INF means no press.

enum AttackResult { PERFECT, GOOD, NORMAL }
enum DefenseResult { PERFECT_PARRY, DODGE, BLOCK, GRAZE, MISS }
## The defense the player chose by which button they pressed.
enum Move { PARRY, DODGE, BLOCK }

const EPS := 0.000001


static func _within(d: float, window: float) -> bool:
	return absf(d) <= window + EPS


static func judge_attack(press_delta: float) -> AttackResult:
	if is_inf(press_delta):
		return AttackResult.NORMAL
	if _within(press_delta, Tuning.ATTACK_PERFECT_WINDOW):
		return AttackResult.PERFECT
	if _within(press_delta, Tuning.ATTACK_GOOD_WINDOW):
		return AttackResult.GOOD
	return AttackResult.NORMAL


static func attack_mult(r: AttackResult) -> float:
	match r:
		AttackResult.PERFECT:
			return Tuning.ATTACK_PERFECT_MULT
		AttackResult.GOOD:
			return Tuning.ATTACK_GOOD_MULT
	return Tuning.ATTACK_NORMAL_MULT


## carried_hold: a BLOCK hold that began validly for an earlier hit of the same
## attack and is still held. Only BLOCK uses it.
static func judge_defense(move: Move, press_delta: float, held_at_hit: bool, carried_hold := false) -> DefenseResult:
	if move == Move.BLOCK and carried_hold and held_at_hit:
		return DefenseResult.BLOCK
	if is_inf(press_delta) or press_delta < -Tuning.LOCKOUT - EPS:
		return DefenseResult.MISS
	match move:
		Move.PARRY:
			if _within(press_delta, Tuning.PARRY_PERFECT_WINDOW):
				return DefenseResult.PERFECT_PARRY
			if _within(press_delta, Tuning.PARRY_GRAZE_WINDOW):
				return DefenseResult.GRAZE
		Move.DODGE:
			if _within(press_delta, Tuning.DODGE_WINDOW):
				return DefenseResult.DODGE
			if _within(press_delta, Tuning.DODGE_GRAZE_WINDOW):
				return DefenseResult.GRAZE
		Move.BLOCK:
			if press_delta <= EPS and press_delta >= -Tuning.BLOCK_EARLY_WINDOW - EPS:
				return DefenseResult.BLOCK if held_at_hit else DefenseResult.MISS
			if press_delta > 0.0 and press_delta <= Tuning.BLOCK_LATE_GRAZE_WINDOW + EPS:
				return DefenseResult.GRAZE
	return DefenseResult.MISS


static func defense_mult(r: DefenseResult) -> float:
	match r:
		DefenseResult.PERFECT_PARRY, DefenseResult.DODGE:
			return 0.0
		DefenseResult.BLOCK:
			return Tuning.BLOCK_MULT
		DefenseResult.GRAZE:
			return Tuning.GRAZE_MULT
	return Tuning.MISS_MULT


static func grants_counter(r: DefenseResult) -> bool:
	return r == DefenseResult.PERFECT_PARRY
