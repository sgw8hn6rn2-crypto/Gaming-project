class_name BattlerData
extends Resource
## Static stats for a character or boss.

enum DefenseStyle { PARRY, DODGE, BLOCK }

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 100
@export var atk: int = 10
@export var def: int = 5
@export var speed: int = 10
@export var defense_style: DefenseStyle = DefenseStyle.PARRY
@export var skills: Array[SkillData] = []
## Placeholder sprite color.
@export var color: Color = Color.WHITE
