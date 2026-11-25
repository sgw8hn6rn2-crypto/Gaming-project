class_name Battler
extends RefCounted
## Runtime state for one combatant.

var data: BattlerData
var hp: int
var sp: int = 0
var gauge: float = 0.0


func _init(d: BattlerData) -> void:
	data = d
	hp = d.max_hp


func is_ko() -> bool:
	return hp <= 0


## Returns the damage actually taken.
func take_damage(n: int) -> int:
	var taken := mini(maxi(n, 0), hp)
	hp -= taken
	return taken


## Returns the HP actually restored. Does nothing while KO.
func heal(n: int) -> int:
	if is_ko():
		return 0
	var healed := mini(maxi(n, 0), data.max_hp - hp)
	hp += healed
	return healed


## Revives from KO with a fraction of max HP. Returns false if not KO.
func revive(pct: float) -> bool:
	if not is_ko():
		return false
	hp = clampi(DamageCalc.ceil_pct(data.max_hp, pct), 1, data.max_hp)
	return true


func add_sp(n: int) -> void:
	sp = clampi(sp + n, 0, Tuning.SP_MAX)


func full_restore() -> void:
	hp = data.max_hp
	sp = 0
	gauge = 0.0
