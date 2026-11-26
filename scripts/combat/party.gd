class_name Party
extends RefCounted
## Four active slots and two bench slots.

const ACTIVE_SIZE := 4
const BENCH_SIZE := 2

var active: Array[Battler] = []
var bench: Array[Battler] = []
var swap_used := false


func _init(members: Array[Battler]) -> void:
	assert(members.size() == ACTIVE_SIZE + BENCH_SIZE, "Party needs exactly 6 members")
	active = members.slice(0, ACTIVE_SIZE)
	bench = members.slice(ACTIVE_SIZE, ACTIVE_SIZE + BENCH_SIZE)


func all_members() -> Array[Battler]:
	return active + bench


func begin_turn() -> void:
	swap_used = false


func can_swap(active_idx: int, bench_idx: int) -> bool:
	if swap_used:
		return false
	if active_idx < 0 or active_idx >= active.size():
		return false
	if bench_idx < 0 or bench_idx >= bench.size():
		return false
	return not bench[bench_idx].is_ko()


func swap(active_idx: int, bench_idx: int) -> bool:
	if not can_swap(active_idx, bench_idx):
		return false
	_exchange(active_idx, bench_idx)
	swap_used = true
	return true


func living_active() -> Array[Battler]:
	return active.filter(func(b: Battler) -> bool: return not b.is_ko())


func bench_recover() -> void:
	for b in bench:
		b.heal(DamageCalc.ceil_pct(b.data.max_hp, Tuning.BENCH_RECOVER_PCT))


## When every active member is KO, living bench members move into KO slots.
## Returns [outgoing, incoming] pairs. Does not use the swap allowance.
func auto_fill() -> Array:
	var pairs: Array = []
	if not living_active().is_empty():
		return pairs
	for bi in bench.size():
		if bench[bi].is_ko():
			continue
		for ai in active.size():
			if active[ai].is_ko():
				pairs.append([active[ai], bench[bi]])
				_exchange(ai, bi)
				break
	return pairs


func is_wiped() -> bool:
	for b in all_members():
		if not b.is_ko():
			return false
	return true


func full_restore_all() -> void:
	for b in all_members():
		b.full_restore()


func _exchange(ai: int, bi: int) -> void:
	var tmp := active[ai]
	active[ai] = bench[bi]
	bench[bi] = tmp
