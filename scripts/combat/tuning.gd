class_name Tuning
extends RefCounted
## Every combat tuning value in one place. Change these after playtesting.

# Player attack timing (seconds from impact, inclusive windows)
const ATTACK_PERFECT_WINDOW := 0.06
const ATTACK_PERFECT_MULT := 1.5
const ATTACK_GOOD_WINDOW := 0.15
const ATTACK_GOOD_MULT := 1.2
const ATTACK_NORMAL_MULT := 1.0

# PARRY style
const PARRY_PERFECT_WINDOW := 0.05
## Any parry press outside the perfect window breaks the guard.
const PARRY_FAIL_MULT := 1.25
const COUNTER_MULT := 0.5

# DODGE style
const DODGE_WINDOW := 0.15
const DODGE_GRAZE_WINDOW := 0.25

# BLOCK style
const BLOCK_EARLY_WINDOW := 0.30
const BLOCK_LATE_GRAZE_WINDOW := 0.15
const BLOCK_MULT := 0.25

# Shared defense
## Seconds the targets blink red before the defense squares start closing in.
const DEFENSE_WARNING := 0.8
const GRAZE_MULT := 0.5
const MISS_MULT := 1.0
const LOCKOUT := 0.40

# Party
const BENCH_RECOVER_PCT := 0.05
const SP_MAX := 5
const SP_PER_ATTACK := 1
const SP_PER_PERFECT_PARRY := 1

# Timeline
const GAUGE_FULL := 100.0

# Damage: max(1, round(atk * power * mult - def * DEF_FACTOR))
const DEF_FACTOR := 0.5

# Items
const POTION_HEAL_PCT := 0.4
const REVIVE_PCT := 0.25
