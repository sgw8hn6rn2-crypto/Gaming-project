class_name BossAttack
extends Resource
## One boss attack pattern.

@export var id: StringName
@export var display_name: String
@export var power: float = 1.0
## Seconds after the telegraph starts at which each hit lands.
@export var hit_times: PackedFloat32Array = PackedFloat32Array([1.0])
@export var party_wide: bool = false
@export var weight: int = 1
@export var telegraph_text: String = ""
