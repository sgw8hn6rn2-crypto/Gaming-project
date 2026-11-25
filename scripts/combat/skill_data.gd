class_name SkillData
extends Resource
## One skill a character can use on their turn.

enum Target { ENEMY, ALLY, ALL_ALLIES, ALLY_KO }
enum Effect { DAMAGE, HEAL, REVIVE }

@export var id: StringName
@export var display_name: String
@export var sp_cost: int = 0
## Damage multiplier for DAMAGE, fraction of max HP for HEAL and REVIVE.
@export var power: float = 1.0
@export var target: Target = Target.ENEMY
@export var effect: Effect = Effect.DAMAGE
## Timed skills show the attack timing prompt.
@export var timed: bool = false
