class_name DamageCalc
extends RefCounted
## Damage and healing numbers.


## max(1, round(atk * power * mult - def * DEF_FACTOR)). Returns 0 when mult is 0.
static func damage(atk: int, power: float, mult: float, def: int) -> int:
	if mult <= 0.0:
		return 0
	return maxi(1, roundi(atk * power * mult - def * Tuning.DEF_FACTOR))


## Fraction of max HP, rounded up. Tolerates float noise (130 * 0.4 is 52, not 53).
static func heal_amount(max_hp: int, power: float) -> int:
	return ceil_pct(max_hp, power)


static func counter_damage(attacker_atk: int, target_def: int) -> int:
	return damage(attacker_atk, 1.0, Tuning.COUNTER_MULT, target_def)


static func ceil_pct(value: int, pct: float) -> int:
	return ceili(value * pct - 0.000001)
