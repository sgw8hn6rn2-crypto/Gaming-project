extends SceneTree
## Regenerates the placeholder .tres content. Run:
## .godot-bin/godot --headless --path . -s res://tools/generate_content.gd





func _skill(id: String, name: String, cost: int, power: float, target: int, effect: int, timed: bool) -> SkillData:
	var s := SkillData.new()
	s.id = StringName(id)
	s.display_name = name
	s.sp_cost = cost
	s.power = power
	s.target = target
	s.effect = effect
	s.timed = timed
	_save(s, "res://data/skills/%s.tres" % id)
	return load("res://data/skills/%s.tres" % id)


func _char(id: String, name: String, hp: int, atk: int, def: int, spd: int, skills: Array, color: Color) -> void:
	var d := BattlerData.new()
	d.id = StringName(id)
	d.display_name = name
	d.max_hp = hp
	d.atk = atk
	d.def = def
	d.speed = spd
	d.skills.assign(skills)
	d.color = color
	_save(d, "res://data/characters/%s.tres" % id)


func _attack(id: String, name: String, power: float, hits: Array, wide: bool, weight: int, text: String) -> void:
	var a := BossAttack.new()
	a.id = StringName(id)
	a.display_name = name
	a.power = power
	a.hit_times = PackedFloat32Array(hits)
	a.party_wide = wide
	a.weight = weight
	a.telegraph_text = text
	_save(a, "res://data/bosses/warden_attacks/%s.tres" % id)


func _save(r: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(r, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])


func _initialize() -> void:
	var bash := _skill("shield_bash", "Shield Bash", 2, 1.4, SkillData.Target.ENEMY, SkillData.Effect.DAMAGE, true)
	var mend := _skill("mend", "Mend", 2, 0.35, SkillData.Target.ALLY, SkillData.Effect.HEAL, false)
	var light := _skill("revive_light", "Revive Light", 4, 0.3, SkillData.Target.ALLY_KO, SkillData.Effect.REVIVE, false)
	var twin := _skill("twin_cut", "Twin Cut", 3, 1.8, SkillData.Target.ENEMY, SkillData.Effect.DAMAGE, true)
	var flare := _skill("flare", "Flare", 3, 2.0, SkillData.Target.ENEMY, SkillData.Effect.DAMAGE, true)
	var rally := _skill("rally", "Rally", 3, 0.2, SkillData.Target.ALL_ALLIES, SkillData.Effect.HEAL, false)
	var pierce := _skill("pierce", "Pierce", 2, 1.5, SkillData.Target.ENEMY, SkillData.Effect.DAMAGE, true)

	_char("kael", "Kael", 140, 18, 14, 9, [bash], Color("#4a7bd1"))
	_char("mira", "Mira", 95, 16, 8, 12, [mend, light], Color("#e2c044"))
	_char("ren", "Ren", 100, 22, 9, 14, [twin], Color("#3fb36b"))
	_char("tess", "Tess", 90, 24, 7, 10, [flare], Color("#d9534f"))
	_char("oda", "Oda", 130, 19, 13, 8, [rally], Color("#8a6bd1"))
	_char("vey", "Vey", 85, 20, 8, 15, [pierce], Color("#3fb3b3"))

	var w := BattlerData.new()
	w.id = &"warden"
	w.display_name = "The Warden"
	w.max_hp = 600
	w.atk = 26
	w.def = 10
	w.speed = 11
	w.color = Color("#6b6b7a")
	_save(w, "res://data/bosses/warden.tres")

	_attack("crushing_swing", "Crushing Swing", 1.6, [1.2], false, 3, "The Warden raises its hammer...")
	_attack("flurry", "Flurry", 0.6, [0.6, 0.9, 1.2], false, 3, "The Warden readies a flurry!")
	_attack("shockwave", "Shockwave", 1.0, [1.5], true, 2, "The ground trembles...")
	print("content generated")
	quit(0)
