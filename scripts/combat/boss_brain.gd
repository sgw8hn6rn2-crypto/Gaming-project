class_name BossBrain
extends RefCounted
## Picks the boss's next attack (weighted random) and its targets.
## Never the same attack 3 times in a row, never party-wide twice in a row.

var attacks: Array[BossAttack] = []
var rng := RandomNumberGenerator.new()
var _history: Array[BossAttack] = []


func _init(list: Array[BossAttack], seed_value: int) -> void:
	attacks = list
	rng.seed = seed_value


func choose(targets: Array[Battler]) -> Dictionary:
	var living := targets.filter(func(b: Battler) -> bool: return not b.is_ko())
	var attack := _pick_attack()
	_history.append(attack)
	if _history.size() > 2:
		_history.pop_front()
	var chosen: Array[Battler] = []
	if attack.party_wide:
		chosen.assign(living)
	elif not living.is_empty():
		chosen.append(living[rng.randi_range(0, living.size() - 1)])
	return { "attack": attack, "targets": chosen }


func _allowed(a: BossAttack) -> bool:
	if _history.is_empty():
		return true
	var last: BossAttack = _history[-1]
	if a.party_wide and last.party_wide:
		return false
	if _history.size() >= 2 and _history[0] == a and last == a:
		return false
	return true


func _pick_attack() -> BossAttack:
	var pool := attacks.filter(_allowed)
	if pool.is_empty():
		pool = attacks
	var total := 0
	for a in pool:
		total += maxi(a.weight, 1)
	var roll := rng.randi_range(1, total)
	for a in pool:
		roll -= maxi(a.weight, 1)
		if roll <= 0:
			return a
	return pool[-1]
