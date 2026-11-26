# Combat Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One complete, replayable boss fight in Godot that proves the combat feels right: timed attacks, dodge, parry and block, a turn timeline, 4 active and 2 bench characters with swapping, and the tiered loss assist.

**Architecture:** All combat rules live in plain GDScript classes (`RefCounted`/`Resource`) under `scripts/combat/`. They have no nodes, so they are unit-tested headless. One `BattleController` drives the fight as a state machine and takes input timings as numbers. The battle scene (`scenes/battle/`) is a thin view: it draws placeholder art, measures button timing against its own clock, calls the controller and reacts to its signals. Loss history lives in an autoload (`GameState`) so it survives scene changes.

**Tech Stack:** Godot 4.6.1 stable, GDScript, a project-local test runner (no add-ons). The GUT add-on cannot be downloaded from this build environment, and the runner is about 60 lines.

**Spec:** `docs/superpowers/specs/2026-11-25-core-game-design.md`

## Global Constraints

- Engine: Godot 4.6.1 stable. GDScript only. No add-ons.
- Base resolution 320x180. Window 1280x720. Stretch mode `viewport`, scale mode `integer`. Default texture filter `Nearest`.
- Platform: PC (Windows) first. Keyboard and gamepad both work for every action.
- Party: 6 playable characters, 4 active and 2 bench.
- One free swap per player turn. A swap never consumes the turn.
- A party-wide enemy attack is judged on **one** input that applies to every active character.
- Battle is lost only when all 6 characters are at 0 HP.
- Missing an attack timing still lands a normal (x1.0) hit.
- Loss assist tiers: 1 to 3 losses `[SAVE_POINT]`. 4 to 10 adds `RETRY_FULL`. 11 to 20 adds `RETRY_KEEP_HP`. 21+ adds `RETRY_ONE_HP`. `SAVE_POINT` is always offered. Counter is per boss and resets on that boss's defeat. Party is fully healed on any retry.
- All placeholder names and art are temporary. No final story content.
- Tests run headless with `./tools/run_tests.sh` and exit non-zero on any failure.

### Tuning values (builder's calls, all in `scripts/combat/tuning.gd` so playtesting can change them in one place)

| Name | Value |
|---|---|
| Attack timing: PERFECT window | ±0.06 s, x1.5 damage |
| Attack timing: GOOD window | ±0.15 s, x1.2 damage |
| PARRY style: perfect | ±0.05 s, 0 damage, counter for 50% of a basic attack |
| PARRY style: graze | ±0.15 s, x0.5 damage |
| DODGE style: dodge | ±0.10 s, 0 damage |
| DODGE style: graze | ±0.20 s, x0.5 damage |
| BLOCK style: block | press between 0.30 s before and the hit, still held at the hit, x0.25 damage |
| BLOCK style: graze | press up to 0.15 s after the hit, x0.5 damage |
| Lockout | a press more than 0.40 s before a hit locks that hit out (judged MISS) |
| No input | x1.0 damage |
| Bench recovery | 5% of max HP (rounded up) per party turn, only for living bench members |
| SP | max 5. Basic attack +1. Perfect parry +1 |
| Timeline gauge | acts at 100. Gauge gain per tick = speed |
| Damage | `max(1, round(atk * power * mult - def * 0.5))` |

## Review Focus

1. **Button mashing during defense.** A player who hammers the button should not get perfect parries. Expected: only the first press in a hit's window counts, and an early press locks that hit out. Pinned in Task 3 (`test_mash_before_window_locks_out`) and Task 9 (`test_multi_hit_each_hit_judged_once`).
2. **All four active characters knocked out while the bench is alive.** Expected: the battle continues, and living bench members move into the knocked-out slots automatically. Pinned in Task 6 (`test_auto_fill_when_all_active_down`).
3. **Swapping in a knocked-out bench member, or swapping twice in one turn.** Expected: refused, and the turn is not consumed. Pinned in Task 6 (`test_cannot_swap_in_ko`, `test_one_swap_per_turn`).
4. **Retrying with "boss keeps HP" when the boss was healthy at the loss, or at 1 HP.** Expected: boss starts at exactly the recorded HP, which is never 0 and never above max. Pinned in Task 8 (`test_keep_hp_clamped`).
5. **Swapping to steal turns.** A fresh bench character should not act immediately just because they came in. Expected: the incoming character inherits the outgoing character's timeline gauge. Pinned in Task 5 (`test_swap_inherits_gauge`).

---

## File Structure

```
project.godot                       Display, input map, autoload
tools/get_godot.sh                  Downloads Godot 4.6.1 headless to .godot-bin/ (gitignored)
tools/run_tests.sh                  Imports project, runs tests headless
tests/test_case.gd                  Base class with asserts
tests/run_tests.gd                  Discovers and runs tests/unit/test_*.gd
tests/unit/test_*.gd                One file per combat class
scripts/combat/tuning.gd            All tuning constants (table above)
scripts/combat/battler_data.gd      Resource: static stats for a character or boss
scripts/combat/skill_data.gd        Resource: one skill
scripts/combat/battler.gd           Runtime HP/SP/KO for one combatant
scripts/combat/timing_judge.gd      Turns a press time into a timing result
scripts/combat/damage_calc.gd       Damage and healing numbers
scripts/combat/turn_timeline.gd     Who acts next, plus preview
scripts/combat/party.gd             Active/bench slots, swaps, recovery, wipe check
scripts/combat/boss_attack.gd       Resource: one boss attack pattern
scripts/combat/boss_brain.gd        Picks the boss's next attack and target
scripts/combat/loss_assist.gd       Per-boss loss counts and retry options
scripts/combat/battle_controller.gd The fight's state machine
scripts/autoload/game_state.gd      Holds LossAssist and pending retry info
data/characters/*.tres              6 placeholder characters
data/skills/*.tres                  Placeholder skills
data/bosses/warden.tres             Placeholder boss and its 3 attacks
scenes/battle/battle.tscn + .gd     Battle view
scenes/battle/ui/*.tscn + .gd       Timeline bar, party panel, action menu, prompt
scenes/defeat/defeat.tscn + .gd     Loss screen with assist options
scenes/save_point/save_point.tscn + .gd  Placeholder save point, enter the boss room
```

---

### Task 1: Project scaffold and test runner

**Files:**
- Create: `project.godot`, `.gitignore`, `tools/get_godot.sh`, `tools/run_tests.sh`, `tests/test_case.gd`, `tests/run_tests.gd`, `tests/unit/test_smoke.gd`, `scripts/combat/tuning.gd`

**Interfaces:**
- Produces: `class_name TestCase extends RefCounted` with `assert_eq(a, b, msg := "")`, `assert_true(c, msg := "")`, `assert_false(c, msg := "")`, `assert_almost(a: float, b: float, eps := 0.001, msg := "")`. Failures are collected in `var failures: Array[String]`, not thrown.
- Produces: `class_name Tuning` with the constants from the tuning table, named in SCREAMING_CASE (for example `ATTACK_PERFECT_WINDOW := 0.06`, `ATTACK_PERFECT_MULT := 1.5`).
- Produces: the run command `./tools/run_tests.sh`.

- [ ] **Step 1:** Write `tools/get_godot.sh`. It downloads `https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip`, unzips it to `.godot-bin/godot`, and skips the download if that file exists. Add `.godot-bin/` and `.godot/` to `.gitignore`.
- [ ] **Step 2:** Write `project.godot` with name "RPG Combat Slice", the display settings from Global Constraints, `rendering/textures/canvas_textures/default_texture_filter=0`, and the input actions `action` (Z, Space, Joypad button 0), `cancel` (X, Escape, Joypad button 1), `debug_losses` (F9). It uses the built-in `ui_up`, `ui_down`, `ui_left`, `ui_right` and `ui_accept` for menus.
- [ ] **Step 3:** Write `tests/test_case.gd` and `tests/run_tests.gd`. The runner `extends SceneTree`, lists `res://tests/unit/`, loads every `test_*.gd`, calls every method starting with `test_` on a fresh instance, prints `PASS name` or `FAIL name: message`, prints a total, and calls `quit(1)` if anything failed, otherwise `quit(0)`.
- [ ] **Step 4:** Write `tools/run_tests.sh`: run `.godot-bin/godot --headless --path . --import`, then `.godot-bin/godot --headless --path . -s res://tests/run_tests.gd`, and exit with the second command's code.
- [ ] **Step 5:** Write `tests/unit/test_smoke.gd` with `test_truth()` asserting `assert_true(true)` and `test_tuning_loaded()` asserting `assert_almost(Tuning.ATTACK_PERFECT_MULT, 1.5)`. Run `./tools/get_godot.sh && ./tools/run_tests.sh`. Expected: FAIL, because `Tuning` does not exist yet.
- [ ] **Step 6:** Write `scripts/combat/tuning.gd` with every constant from the table. Run `./tools/run_tests.sh`. Expected: `2 passed, 0 failed`, exit code 0.
- [ ] **Step 7:** Temporarily change the smoke test to `assert_true(false)` and confirm the exit code is 1, then revert. This proves failures are caught.
- [ ] **Step 8:** Commit: `git commit -m "feat: Godot project scaffold and headless test runner"`

### Task 2: Battler data and runtime battler

**Files:**
- Create: `scripts/combat/battler_data.gd`, `scripts/combat/skill_data.gd`, `scripts/combat/battler.gd`, `tests/unit/test_battler.gd`

**Interfaces:**
- Produces: `class_name BattlerData extends Resource` with `@export var id: StringName`, `display_name: String`, `max_hp: int`, `atk: int`, `def: int`, `speed: int`, `defense_style: DefenseStyle` (enum `DefenseStyle { PARRY, DODGE, BLOCK }` declared in this class), `skills: Array[SkillData]` and `color: Color` (the placeholder sprite color).
- Produces: `class_name SkillData extends Resource` with `id`, `display_name`, `sp_cost: int`, `power: float`, `target: Target` (enum `Target { ENEMY, ALLY, ALL_ALLIES, ALLY_KO }`), `effect: Effect` (enum `Effect { DAMAGE, HEAL, REVIVE }`) and `timed: bool`.
- Produces: `class_name Battler extends RefCounted` with `data: BattlerData`, `hp: int`, `sp: int`, `gauge: float`, `func _init(d: BattlerData)` (starts at full HP, SP 0, gauge 0), `is_ko() -> bool`, `take_damage(n: int) -> int` (returns the damage actually taken, HP floors at 0), `heal(n: int) -> int` (does nothing while KO, caps at max), `revive(pct: float) -> bool` (only from KO, sets HP to `ceil(max_hp * pct)`, at least 1), `add_sp(n: int)` (clamps 0 to `Tuning.SP_MAX`), `full_restore()`.

- [ ] **Step 1:** Write tests: `test_starts_full`, `test_damage_floors_at_zero` (100 HP, take 150, `hp == 0`, `is_ko()`, returned 100), `test_heal_caps_at_max`, `test_heal_ignored_when_ko`, `test_revive_only_from_ko` (alive returns false; KO with 0.25 on 100 HP gives `hp == 25`), `test_sp_clamped` (add 9, `sp == 5`).
- [ ] **Step 2:** Run `./tools/run_tests.sh`. Expected: FAIL, the classes are missing.
- [ ] **Step 3:** Implement the three classes.
- [ ] **Step 4:** Run tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat: battler data and runtime battler`

### Task 3: Timing judge

**Files:**
- Create: `scripts/combat/timing_judge.gd`, `tests/unit/test_timing_judge.gd`

**Interfaces:**
- Consumes: `Tuning`, `BattlerData.DefenseStyle`.
- Produces: `class_name TimingJudge extends RefCounted` with enums `AttackResult { PERFECT, GOOD, NORMAL }` and `DefenseResult { PERFECT_PARRY, DODGE, BLOCK, GRAZE, MISS }`, plus these static functions:
  - `judge_attack(press_delta: float) -> AttackResult`. `press_delta` is press time minus impact time, and `INF` means no press.
  - `attack_mult(r: AttackResult) -> float`
  - `judge_defense(style: BattlerData.DefenseStyle, press_delta: float, held_at_hit: bool) -> DefenseResult`. `INF` means no press. A delta below `-Tuning.LOCKOUT` returns MISS.
  - `defense_mult(r: DefenseResult) -> float`
  - `grants_counter(r: DefenseResult) -> bool` (true only for PERFECT_PARRY)

- [ ] **Step 1:** Write tests. Attack: `judge_attack(0.0) == PERFECT`, `0.06 == PERFECT`, `-0.1 == GOOD`, `0.3 == NORMAL`, `INF == NORMAL`, and `attack_mult(NORMAL) == 1.0`. Parry: `0.04 → PERFECT_PARRY`, `0.12 → GRAZE`, `0.3 → MISS`. Dodge: `-0.09 → DODGE`, `0.18 → GRAZE`. Block: `(-0.25, held=true) → BLOCK`, `(-0.25, held=false) → MISS`, `(0.1, held=true) → GRAZE`. `test_mash_before_window_locks_out`: for every style, `judge_defense(style, -0.5, true) == MISS`. Multipliers: PERFECT_PARRY and DODGE give 0.0, BLOCK 0.25, GRAZE 0.5, MISS 1.0. `grants_counter` is true only for PERFECT_PARRY.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Windows are inclusive. Read every number from `Tuning`.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: timing judge for attacks and three defense styles`

### Task 4: Damage calculation

**Files:**
- Create: `scripts/combat/damage_calc.gd`, `tests/unit/test_damage_calc.gd`

**Interfaces:**
- Produces: `class_name DamageCalc extends RefCounted`, static:
  - `damage(atk: int, power: float, mult: float, def: int) -> int`. Uses the formula in Tuning. Returns 0 when `mult == 0.0`, otherwise at least 1.
  - `heal_amount(max_hp: int, power: float) -> int` (`ceil(max_hp * power)`)
  - `counter_damage(attacker_atk: int, target_def: int) -> int` (`damage(attacker_atk, 1.0, Tuning.COUNTER_MULT, target_def)`)

- [ ] **Step 1:** Write tests: `damage(20, 1.0, 1.0, 10) == 15`, `damage(20, 1.0, 1.5, 10) == 25`, `damage(1, 1.0, 1.0, 50) == 1`, `damage(20, 1.0, 0.0, 10) == 0`, `heal_amount(130, 0.4) == 52`, `counter_damage(20, 10) == 5`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: damage calculation`

### Task 5: Turn timeline

**Files:**
- Create: `scripts/combat/turn_timeline.gd`, `tests/unit/test_turn_timeline.gd`

**Interfaces:**
- Consumes: `Battler` (`gauge`, `data.speed`, `is_ko()`).
- Produces: `class_name TurnTimeline extends RefCounted` with:
  - `func _init(battlers: Array[Battler])`. Order in the array is the tie-break order, with party first and boss last.
  - `next_actor() -> Battler`. Advances every living battler's gauge by whole ticks of `speed` until at least one reaches 100. The highest gauge acts, and ties go to the earlier array index. The actor's gauge drops by 100. KO battlers are skipped and do not gain gauge.
  - `preview(n: int) -> Array[Battler]`. Simulates on copies of the gauges without mutating anything.
  - `replace(outgoing: Battler, incoming: Battler)`. Puts `incoming` into the array slot of `outgoing` and copies its gauge.

- [ ] **Step 1:** Write tests. `test_faster_acts_first` (speeds 10 and 20, first actor is the speed 20 one). `test_double_speed_acts_twice`: in `preview(6)` with speeds 10 and 20, the speed 20 battler appears 4 times. `test_preview_does_not_mutate`: gauges are unchanged after preview. `test_ko_skipped`. `test_tie_breaks_by_order`. `test_swap_inherits_gauge`: after a tick, replacing A with fresh B gives `B.gauge == A's gauge` and B sits in A's position.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: turn timeline with preview`

### Task 6: Party, swapping, bench recovery

**Files:**
- Create: `scripts/combat/party.gd`, `tests/unit/test_party.gd`

**Interfaces:**
- Consumes: `Battler`.
- Produces: `class_name Party extends RefCounted` with:
  - `func _init(members: Array[Battler])`. Exactly 6 members: indices 0 to 3 start active and 4 to 5 start on the bench.
  - `active: Array[Battler]` (size 4) and `bench: Array[Battler]` (size 2)
  - `begin_turn()` resets the swap allowance.
  - `can_swap(active_idx: int, bench_idx: int) -> bool` and `swap(active_idx: int, bench_idx: int) -> bool`. These are refused if a swap was already used this turn or the bench member is KO. On success the two exchange slots and the function returns true.
  - `living_active() -> Array[Battler]`
  - `bench_recover()` heals living bench members by `ceil(max_hp * Tuning.BENCH_RECOVER_PCT)`.
  - `auto_fill() -> Array` returns `[outgoing, incoming]` pairs. When every active member is KO, living bench members move into KO slots in index order. It does not use the swap allowance.
  - `is_wiped() -> bool` is true when all 6 are KO.
  - `full_restore_all()`

- [ ] **Step 1:** Write tests: `test_initial_slots`. `test_one_swap_per_turn` (second swap returns false and `begin_turn()` allows it again). `test_cannot_swap_in_ko`. `test_swap_out_ko_active_allowed`. `test_bench_recover_5pct` (100 max HP at 50 becomes 55, and a KO bench member stays at 0). `test_auto_fill_when_all_active_down` (4 KO active and 2 living bench: after `auto_fill()`, `living_active().size() == 2` and `is_wiped() == false`). `test_wipe_requires_all_six`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: party slots, swapping, bench recovery`

### Task 7: Boss attacks and boss brain

**Files:**
- Create: `scripts/combat/boss_attack.gd`, `scripts/combat/boss_brain.gd`, `tests/unit/test_boss_brain.gd`

**Interfaces:**
- Produces: `class_name BossAttack extends Resource` with `id`, `display_name`, `power: float`, `hit_times: PackedFloat32Array` (seconds after the telegraph starts; one entry per hit), `party_wide: bool`, `weight: int`, `telegraph_text: String`.
- Produces: `class_name BossBrain extends RefCounted` with `func _init(attacks: Array[BossAttack], seed: int)` and `choose(living_targets: Array[Battler]) -> Dictionary` returning `{ "attack": BossAttack, "targets": Array[Battler] }`. Selection is weighted random from a `RandomNumberGenerator` seeded with `seed`. It never picks the same attack 3 times in a row and never picks a `party_wide` attack twice in a row. A single-target attack hits one random living target. A party-wide attack targets every living active member.

- [ ] **Step 1:** Write tests. `test_deterministic_with_seed`: two brains with seed 42 produce the same 20 choices. `test_no_triple_repeat`: over 500 choices there are no 3 identical in a row. `test_party_wide_not_twice`. `test_party_wide_targets_all_living`. `test_single_target_is_living` (never a KO member).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: boss attack patterns and brain`

### Task 8: Loss assist and GameState autoload

**Files:**
- Create: `scripts/combat/loss_assist.gd`, `scripts/autoload/game_state.gd`, `tests/unit/test_loss_assist.gd`
- Modify: `project.godot` (register autoload `GameState`)

**Interfaces:**
- Produces: `class_name LossAssist extends RefCounted` with enum `Option { SAVE_POINT, RETRY_FULL, RETRY_KEEP_HP, RETRY_ONE_HP }` and:
  - `record_loss(boss_id: StringName, boss_hp: int, boss_max_hp: int)` increments the count and stores the HP clamped to `1..boss_max_hp`.
  - `losses(boss_id) -> int`
  - `options(boss_id) -> Array[Option]`, following the tiers in Global Constraints and always in enum order.
  - `start_hp(boss_id, option: Option, boss_max_hp: int) -> int`. SAVE_POINT and RETRY_FULL return max. KEEP_HP returns the stored HP. ONE_HP returns 1.
  - `record_victory(boss_id)` resets the count and the stored HP.
  - `debug_set_losses(boss_id, n: int)`
- Produces: autoload `GameState` (a `Node`) with `var loss_assist := LossAssist.new()`, `var pending_boss_start_hp: int = -1` and `var last_boss_id: StringName`.

- [ ] **Step 1:** Write tests: `test_tiers` (with losses 0, 1, 3, 4, 10, 11, 20, 21 and 50, the option arrays are exactly `[S]`, `[S]`, `[S]`, `[S,F]`, `[S,F]`, `[S,F,K]`, `[S,F,K]`, `[S,F,K,O]`, `[S,F,K,O]`). `test_per_boss` (losses to boss A do not affect boss B). `test_victory_resets`. `test_keep_hp_uses_last_loss` (record HP 400, then 250, and KEEP returns 250). `test_keep_hp_clamped` (record 0 gives 1, and record 9999 with max 600 gives 600). `test_one_hp`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, and register the autoload.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: tiered loss assist`

### Task 9: Battle controller

**Files:**
- Create: `scripts/combat/battle_controller.gd`, `tests/unit/test_battle_controller.gd`

**Interfaces:**
- Consumes: everything from Tasks 2 to 8.
- Produces: `class_name BattleController extends RefCounted` with:
  - enum `Phase { PLAYER_CHOOSE, PLAYER_TIMING, ENEMY_DEFENSE, VICTORY, DEFEAT }`
  - Signals: `phase_changed(phase)`, `actor_changed(actor: Battler)`, `damage_dealt(target: Battler, amount: int, result_label: String)`, `healed(target: Battler, amount: int)`, `enemy_attack_started(attack: BossAttack, targets: Array)`, `swapped(outgoing: Battler, incoming: Battler)`, `battle_ended(victory: bool)`
  - `func _init(party: Party, boss: Battler, attacks: Array[BossAttack], seed: int, boss_start_hp: int = -1)`
  - `start()` advances to the first actor.
  - `phase: Phase`, `actor: Battler`, `pending_attack: BossAttack`, `pending_targets: Array`, `timeline: TurnTimeline`, `items: Dictionary` (starts as `{ "potion": 3, "revive": 2 }`)
  - Player side: `choose_attack()`, `choose_skill(skill: SkillData, target: Battler) -> bool` (false if SP is short or the target is invalid), `choose_item(item_id: String, target: Battler) -> bool`, and `swap(active_idx: int, bench_idx: int) -> bool` (stays in PLAYER_CHOOSE). Timed actions go to PLAYER_TIMING, and untimed ones resolve immediately.
  - `resolve_player_timing(press_delta: float)`
  - Enemy side: when the boss is the actor, the controller picks with `BossBrain`, emits `enemy_attack_started` and enters ENEMY_DEFENSE.
  - `resolve_enemy_hit(hit_index: int, press_delta: float, held_at_hit: bool)`. For a party-wide attack one call applies to all `pending_targets`. Each target uses its own `defense_style`, but all share the one input. After the last hit index the turn ends. A repeated call for a hit index already resolved is ignored.
  - At the end of every party member's turn the controller calls `party.bench_recover()`. After any damage it calls `party.auto_fill()` (and `timeline.replace` for each pair). It checks VICTORY when the boss HP reaches 0 and DEFEAT on `party.is_wiped()`.
  - A potion heals 40% of max HP. A revive restores 25% of max HP. Using an item uses the turn.

- [ ] **Step 1:** Write tests with a fixed seed and small test data built in the test file:
  - `test_first_actor_is_fastest`
  - `test_timed_attack_perfect_more_damage` (two controllers, delta 0.0 compared with INF: the first deals more damage)
  - `test_miss_timing_still_hits` (INF still lowers boss HP)
  - `test_attack_gives_sp`
  - `test_skill_needs_sp`
  - `test_swap_does_not_end_turn` (after swapping, the phase is still PLAYER_CHOOSE with the same actor slot)
  - `test_perfect_parry_no_damage_and_counter`
  - `test_party_wide_one_input_all_targets` (one call with delta 0.0, every target's HP is unchanged)
  - `test_multi_hit_each_hit_judged_once` (calling hit 0 twice only applies damage once)
  - `test_revive_item`
  - `test_victory_when_boss_zero`
  - `test_defeat_only_when_all_six_down`
  - `test_boss_start_hp_respected` (with `boss_start_hp = 1`, the boss starts at 1)
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: all tests pass, including those from earlier tasks.
- [ ] **Step 5:** Commit: `feat: battle controller state machine`

### Task 10: Placeholder content

**Files:**
- Create: `data/skills/*.tres`, `data/characters/*.tres` (6 files), `data/bosses/warden.tres`, `data/bosses/warden_attacks/*.tres` (3 files), `tests/unit/test_content.gd`

**Interfaces:**
- Produces: the paths `res://data/characters/{kael,mira,ren,tess,oda,vey}.tres` (load order gives the starting slots, with oda and vey on the bench) and `res://data/bosses/warden.tres` (a `BattlerData` with id `&"warden"`). The boss attacks are loaded from `res://data/bosses/warden_attacks/`.

Content (placeholder, builder's call):

| Char | HP | ATK | DEF | SPD | Style | Skills |
|---|---|---|---|---|---|---|
| Kael | 140 | 18 | 14 | 9 | BLOCK | Shield Bash (2 SP, 1.4 power, timed) |
| Mira | 95 | 16 | 8 | 12 | PARRY | Mend (2 SP, heal 0.35, ally), Revive Light (4 SP, revive, ally KO) |
| Ren | 100 | 22 | 9 | 14 | DODGE | Twin Cut (3 SP, 1.8 power, timed) |
| Tess | 90 | 24 | 7 | 10 | PARRY | Flare (3 SP, 2.0 power, timed) |
| Oda | 130 | 19 | 13 | 8 | BLOCK | Rally (3 SP, heal 0.2, all allies) |
| Vey | 85 | 20 | 8 | 15 | DODGE | Pierce (2 SP, 1.5 power, timed) |

Boss "Warden": HP 600, ATK 26, DEF 10, SPD 11. Attacks:
- Crushing Swing: single target, power 1.6, `hit_times [1.2]`, weight 3
- Flurry: single target, power 0.6, `hit_times [0.6, 0.9, 1.2]`, weight 3
- Shockwave: party-wide, power 1.0, `hit_times [1.5]`, weight 2

- [ ] **Step 1:** Write `test_content.gd`: all 6 characters load with a valid defense style, the warden loads with 3 attacks, and every attack has at least one hit time of 0.5 s or more. That last check means every attack has a readable wind-up.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Create the `.tres` files.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5:** Commit: `feat: placeholder characters and Warden boss`

### Task 11: Battle scene (view)

**Files:**
- Create: `scenes/battle/battle.tscn`, `scenes/battle/battle.gd`, `scenes/battle/ui/timeline_bar.tscn/.gd`, `scenes/battle/ui/party_panel.tscn/.gd`, `scenes/battle/ui/action_menu.tscn/.gd`, `scenes/battle/ui/timing_prompt.tscn/.gd`, `tests/unit/test_battle_scene_loads.gd`
- Modify: `project.godot` (main scene `res://scenes/save_point/save_point.tscn` is set in Task 12; set `battle.tscn` as main for now)

**Interfaces:**
- Consumes: `BattleController`, content paths from Task 10, `GameState.pending_boss_start_hp`.
- Produces: `battle.tscn` root script with `signal finished(victory: bool)`. On defeat it calls `GameState.loss_assist.record_loss(...)` with the boss's current HP. On victory it calls `record_victory`. Then it changes scene to `res://scenes/defeat/defeat.tscn` or shows a victory panel.

Behavior:
- Placeholder art: each battler is a colored `ColorRect` (from `BattlerData.color`) with a name label. The boss is a larger rectangle at top-left. Party is bottom-right, with bench names listed small.
- `timeline_bar` shows `controller.timeline.preview(6)` as name chips.
- `party_panel` shows HP and SP bars for active members and names plus HP for the bench.
- `action_menu`: Attack, Skill, Item, Swap. Swap is greyed out once used this turn. Navigation uses ui actions, and `cancel` goes back.
- `timing_prompt`: on PLAYER_TIMING, an attack animation plays with an impact at 0.5 s and a shrinking ring that closes at impact. The `action` press time is measured with `Time.get_ticks_usec()`. Delta, or `INF` if there's no press by 0.4 s after impact, goes to `resolve_player_timing`.
- On ENEMY_DEFENSE: show the `telegraph_text`, highlight targets with a flashing outline, animate the boss wind-up so each hit lands visibly at its `hit_times` entry, and flash a "!" cue 0.3 s before each hit. Record the first `action` press per hit, and for BLOCK style whether it's held at the hit. Call `resolve_enemy_hit` at each hit time plus the graze window.
- Floating text shows each result: "PERFECT!", "PARRY!", "DODGE", "BLOCK", "GRAZE", and damage numbers.
- `debug_losses` (F9) opens a small number input that calls `GameState.loss_assist.debug_set_losses(&"warden", n)`.

- [ ] **Step 1:** Write `test_battle_scene_loads.gd`: `load("res://scenes/battle/battle.tscn").instantiate()` is not null and has a `finished` signal.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Build the scenes and scripts.
- [ ] **Step 4:** Run tests. Expected: pass.
- [ ] **Step 5:** Smoke-run headless for 5 seconds: `.godot-bin/godot --headless --path . --quit-after 300`. Expected: no `SCRIPT ERROR` lines in the output.
- [ ] **Step 6:** Commit: `feat: battle scene with placeholder art and timing prompts`

### Task 12: Defeat screen, save point and retry flow

**Files:**
- Create: `scenes/defeat/defeat.tscn/.gd`, `scenes/save_point/save_point.tscn/.gd`, `tests/unit/test_flow_scenes_load.gd`
- Modify: `project.godot` (main scene becomes `res://scenes/save_point/save_point.tscn`)

**Interfaces:**
- Consumes: `GameState.loss_assist`, `GameState.pending_boss_start_hp`, `battle.tscn`.

Behavior:
- Save point: a placeholder room with a glowing save marker and the text "Boss room ahead". Pressing `action` sets `GameState.pending_boss_start_hp = -1` and loads the battle.
- Defeat screen: shows "Defeated (N)", then lists `options(&"warden")` with plain labels: "Return to save point", "Retry now", "Retry now, boss keeps its damage (X HP)", and "Retry now, boss at 1 HP". Picking one sets `pending_boss_start_hp = start_hp(...)` and loads the battle, or for SAVE_POINT loads the save point. The party is always rebuilt at full HP.
- Victory: a panel with "Warden defeated" and "Fight again" (returns to the save point).

- [ ] **Step 1:** Write `test_flow_scenes_load.gd`: both scenes instantiate, and the main scene setting in `ProjectSettings` is the save point.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Build the scenes.
- [ ] **Step 4:** Run tests and the headless smoke run. Expected: pass, with no script errors.
- [ ] **Step 5:** Commit: `feat: save point, defeat screen and retry flow`

### Task 13: Playtest handoff

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Write `README.md` covering: install Godot 4.6.1 (standard version, from godotengine.org), open the project folder with "Import", press F5 to play, the controls (Z or Space or gamepad A for action, X or Esc or gamepad B to cancel, arrows or d-pad for menus, F9 to set the loss count), and the tuning file `scripts/combat/tuning.gd` for timing changes.
- [ ] **Step 2:** Run the full test suite. Expected: all pass.
- [ ] **Step 3:** Commit and push: `git push -u origin claude/nifty-hopper-n9860y`
- [ ] **Step 4:** Hand over to the creator for the playtest. The milestone is done when they have played several times, the fight keeps them alert, and they want to retry after losing. Feedback goes into `tuning.gd` and the boss data.
