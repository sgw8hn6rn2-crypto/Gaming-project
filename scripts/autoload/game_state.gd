extends Node
## Global state that survives scene changes.

var loss_assist := LossAssist.new()
## Boss HP to start the next fight with. -1 means full HP.
var pending_boss_start_hp: int = -1
var last_boss_id: StringName = &""
