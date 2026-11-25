class_name LossAssist
extends RefCounted
## Tracks losses per boss and which retry options are offered.
## 1-3 losses: save point. 4-10: + instant retry. 11-20: + boss keeps its HP.
## 21+: + boss at 1 HP. The save point is always offered.

enum Option { SAVE_POINT, RETRY_FULL, RETRY_KEEP_HP, RETRY_ONE_HP }

const RETRY_FULL_AFTER := 3
const KEEP_HP_AFTER := 10
const ONE_HP_AFTER := 20

var _losses: Dictionary = {}
var _hp_at_loss: Dictionary = {}


func record_loss(boss_id: StringName, boss_hp: int, boss_max_hp: int) -> void:
	_losses[boss_id] = losses(boss_id) + 1
	_hp_at_loss[boss_id] = clampi(boss_hp, 1, boss_max_hp)


func losses(boss_id: StringName) -> int:
	return _losses.get(boss_id, 0)


func options(boss_id: StringName) -> Array[Option]:
	var n := losses(boss_id)
	var out: Array[Option] = [Option.SAVE_POINT]
	if n > RETRY_FULL_AFTER:
		out.append(Option.RETRY_FULL)
	if n > KEEP_HP_AFTER:
		out.append(Option.RETRY_KEEP_HP)
	if n > ONE_HP_AFTER:
		out.append(Option.RETRY_ONE_HP)
	return out


func start_hp(boss_id: StringName, option: Option, boss_max_hp: int) -> int:
	match option:
		Option.RETRY_KEEP_HP:
			return clampi(_hp_at_loss.get(boss_id, boss_max_hp), 1, boss_max_hp)
		Option.RETRY_ONE_HP:
			return 1
	return boss_max_hp


func record_victory(boss_id: StringName) -> void:
	_losses.erase(boss_id)
	_hp_at_loss.erase(boss_id)


func debug_set_losses(boss_id: StringName, n: int) -> void:
	_losses[boss_id] = maxi(n, 0)
