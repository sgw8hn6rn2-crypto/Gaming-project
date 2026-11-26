class_name BattleController
extends RefCounted
## The fight's state machine. Has no nodes: the view measures button timing
## and passes press deltas in seconds (INF = no press).

enum Phase { PLAYER_CHOOSE, PLAYER_TIMING, ENEMY_DEFENSE, VICTORY, DEFEAT }

signal phase_changed(phase: Phase)
signal actor_changed(actor: Battler)
signal damage_dealt(target: Battler, amount: int, result_label: String)
signal healed(target: Battler, amount: int)
signal enemy_attack_started(attack: BossAttack, targets: Array)
signal swapped(outgoing: Battler, incoming: Battler)
signal battle_ended(victory: bool)

const ATTACK_LABELS := {
	TimingJudge.AttackResult.PERFECT: "PERFECT!",
	TimingJudge.AttackResult.GOOD: "GOOD",
	TimingJudge.AttackResult.NORMAL: "",
}
const DEFENSE_LABELS := {
	TimingJudge.DefenseResult.PERFECT_PARRY: "PARRY!",
	TimingJudge.DefenseResult.DODGE: "DODGE",
	TimingJudge.DefenseResult.BLOCK: "BLOCK",
	TimingJudge.DefenseResult.GRAZE: "GRAZE",
	TimingJudge.DefenseResult.MISS: "",
}

var party: Party
var boss: Battler
var brain: BossBrain
var timeline: TurnTimeline
var phase: Phase = Phase.PLAYER_CHOOSE
var actor: Battler
var pending_attack: BossAttack
var pending_targets: Array = []
var items: Dictionary = { "potion": 3, "revive": 2 }

var _pending_power := 1.0
var _pending_is_basic := false
var _resolved_hits: Dictionary = {}


func _init(p: Party, b: Battler, attacks: Array[BossAttack], seed_value: int, boss_start_hp: int = -1) -> void:
	party = p
	boss = b
	brain = BossBrain.new(attacks, seed_value)
	if boss_start_hp > 0:
		boss.hp = clampi(boss_start_hp, 1, boss.data.max_hp)
	var order: Array[Battler] = party.active.duplicate()
	order.append(boss)
	timeline = TurnTimeline.new(order)


func start() -> void:
	_next_turn()


func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


# --- Player side -----------------------------------------------------------

func choose_attack() -> void:
	if phase != Phase.PLAYER_CHOOSE:
		return
	_pending_power = 1.0
	_pending_is_basic = true
	_set_phase(Phase.PLAYER_TIMING)


func choose_skill(skill: SkillData, target: Battler) -> bool:
	if phase != Phase.PLAYER_CHOOSE or skill == null:
		return false
	if actor.sp < skill.sp_cost or not _valid_skill_target(skill, target):
		return false
	actor.add_sp(-skill.sp_cost)
	match skill.effect:
		SkillData.Effect.DAMAGE:
			_pending_power = skill.power
			_pending_is_basic = false
			if skill.timed:
				_set_phase(Phase.PLAYER_TIMING)
			else:
				_hit_boss(TimingJudge.AttackResult.NORMAL)
				_end_party_turn()
		SkillData.Effect.HEAL:
			var targets: Array = party.living_active() if skill.target == SkillData.Target.ALL_ALLIES else [target]
			for t in targets:
				_heal(t, DamageCalc.heal_amount(t.data.max_hp, skill.power))
			_end_party_turn()
		SkillData.Effect.REVIVE:
			if target.revive(skill.power):
				healed.emit(target, target.hp)
			_end_party_turn()
	return true


func choose_item(item_id: String, target: Battler) -> bool:
	if phase != Phase.PLAYER_CHOOSE or items.get(item_id, 0) <= 0:
		return false
	if target == null or not party.active.has(target):
		return false
	match item_id:
		"potion":
			if target.is_ko():
				return false
			_heal(target, DamageCalc.heal_amount(target.data.max_hp, Tuning.POTION_HEAL_PCT))
		"revive":
			if not target.revive(Tuning.REVIVE_PCT):
				return false
			healed.emit(target, target.hp)
		_:
			return false
	items[item_id] -= 1
	_end_party_turn()
	return true


## Free swap. Stays in PLAYER_CHOOSE. The current actor cannot be swapped out,
## so a fresh bench character never acts the moment they come in.
func swap(active_idx: int, bench_idx: int) -> bool:
	if phase != Phase.PLAYER_CHOOSE:
		return false
	if active_idx >= 0 and active_idx < party.active.size() and party.active[active_idx] == actor:
		return false
	if not party.can_swap(active_idx, bench_idx):
		return false
	var outgoing := party.active[active_idx]
	var incoming := party.bench[bench_idx]
	party.swap(active_idx, bench_idx)
	timeline.replace(outgoing, incoming)
	swapped.emit(outgoing, incoming)
	return true


func resolve_player_timing(press_delta: float) -> void:
	if phase != Phase.PLAYER_TIMING:
		return
	_hit_boss(TimingJudge.judge_attack(press_delta))
	_end_party_turn()


# --- Enemy side ------------------------------------------------------------

## One judgment from the player's move and timing applies to every target.
func resolve_enemy_hit(hit_index: int, move: TimingJudge.Move, press_delta: float, held_at_hit: bool, carried_hold := false) -> void:
	if phase != Phase.ENEMY_DEFENSE or pending_attack == null:
		return
	if hit_index < 0 or hit_index >= pending_attack.hit_times.size():
		return
	if _resolved_hits.has(hit_index):
		return
	_resolved_hits[hit_index] = true
	var r := TimingJudge.judge_defense(move, press_delta, held_at_hit, carried_hold)
	var countered := false  # at most one counter, even on party-wide attacks
	for t in pending_targets:
		var target: Battler = t
		if target.is_ko():
			continue
		var dmg := DamageCalc.damage(boss.data.atk, pending_attack.power, TimingJudge.defense_mult(r), target.data.def)
		target.take_damage(dmg)
		damage_dealt.emit(target, dmg, DEFENSE_LABELS[r])
		if TimingJudge.grants_counter(r):
			target.add_sp(Tuning.SP_PER_PERFECT_PARRY)
			if not countered:
				countered = true
				var c := DamageCalc.counter_damage(target.data.atk, boss.data.def)
				boss.take_damage(c)
				damage_dealt.emit(boss, c, "COUNTER")
	_after_damage()
	if is_over():
		return
	if _resolved_hits.size() >= pending_attack.hit_times.size():
		pending_attack = null
		pending_targets = []
		_next_turn()


# --- Internals -------------------------------------------------------------

func _next_turn() -> void:
	if is_over():
		return
	actor = timeline.next_actor()
	if actor == null:
		return
	actor_changed.emit(actor)
	if actor == boss:
		_begin_enemy_turn()
	else:
		party.begin_turn()
		_set_phase(Phase.PLAYER_CHOOSE)


func _begin_enemy_turn() -> void:
	var choice := brain.choose(party.active)
	pending_attack = choice["attack"]
	pending_targets = choice["targets"]
	_resolved_hits = {}
	if pending_targets.is_empty():
		pending_attack = null
		_next_turn()
		return
	_set_phase(Phase.ENEMY_DEFENSE)
	enemy_attack_started.emit(pending_attack, pending_targets)


func _hit_boss(r: TimingJudge.AttackResult) -> void:
	var dmg := DamageCalc.damage(actor.data.atk, _pending_power, TimingJudge.attack_mult(r), boss.data.def)
	boss.take_damage(dmg)
	damage_dealt.emit(boss, dmg, ATTACK_LABELS[r])
	if _pending_is_basic:
		actor.add_sp(Tuning.SP_PER_ATTACK)


func _heal(target: Battler, amount: int) -> void:
	var done := target.heal(amount)
	healed.emit(target, done)


func _end_party_turn() -> void:
	party.bench_recover()
	_after_damage()
	if not is_over():
		_next_turn()


func _after_damage() -> void:
	if boss.is_ko():
		_set_phase(Phase.VICTORY)
		battle_ended.emit(true)
		return
	for pair in party.auto_fill():
		timeline.replace(pair[0], pair[1])
		swapped.emit(pair[0], pair[1])
	if party.is_wiped():
		_set_phase(Phase.DEFEAT)
		battle_ended.emit(false)


func _valid_skill_target(skill: SkillData, target: Battler) -> bool:
	match skill.target:
		SkillData.Target.ENEMY:
			return target == boss
		SkillData.Target.ALLY:
			return target != null and party.active.has(target) and not target.is_ko()
		SkillData.Target.ALL_ALLIES:
			return true
		SkillData.Target.ALLY_KO:
			return target != null and party.active.has(target) and target.is_ko()
	return false


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)
