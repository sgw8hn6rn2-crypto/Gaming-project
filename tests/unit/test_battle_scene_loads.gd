extends TestCase


func test_battle_scene_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	assert_true(packed != null, "scene loads")
	if packed == null:
		return
	var node := packed.instantiate()
	assert_true(node != null)
	assert_true(node.has_signal("finished"))
	node.free()


func test_ui_scripts_parse() -> void:
	for p in ["timeline_bar", "party_panel", "action_menu", "timing_prompt"]:
		var s: GDScript = load("res://scenes/battle/ui/%s.gd" % p)
		assert_true(s != null and s.can_instantiate(), p)


func test_enemy_turn_frame_runs_without_errors() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var b = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(b)
	assert_true(b.is_inside_tree(), "inside tree")
	assert_true(b.ctrl != null, "_ready ran")
	if b.ctrl == null:
		root.remove_child(b)
		b.free()
		return
	var guard := 0
	while b.ctrl.phase != BattleController.Phase.ENEMY_DEFENSE and guard < 20:
		guard += 1
		b.ctrl.choose_attack()
		b.ctrl.resolve_player_timing(INF)
	assert_eq(b.ctrl.phase, BattleController.Phase.ENEMY_DEFENSE)
	b._process(0.016)
	assert_true(b._mode == b.Mode.DEFENSE)
	root.remove_child(b)
	b.free()


func _scene_in_enemy_turn(attack: BossAttack):
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var b = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(b)
	var only: Array[BossAttack] = [attack]
	b.ctrl.brain = BossBrain.new(only, 1)
	var guard := 0
	while b.ctrl.phase != BattleController.Phase.ENEMY_DEFENSE and guard < 20:
		guard += 1
		b.ctrl.choose_attack()
		b.ctrl.resolve_player_timing(INF)
	return b


func _free_scene(b) -> void:
	b.get_parent().remove_child(b)
	b.free()


func test_defense_square_closes_on_hit() -> void:
	var a := BossAttack.new()
	a.hit_times = PackedFloat32Array([1.2])
	var b = _scene_in_enemy_turn(a)
	# Halfway through the square's approach to the hit.
	b._t0 = b._now() - (1.2 - b.SQUARE_LEAD * 0.5)
	b._process(0.016)
	assert_eq(b._prompt.square_progresses.size(), 1)
	assert_almost(b._prompt.square_progresses[0], 0.5, 0.05)
	assert_eq(b._prompt.square_centers.size(), b.ctrl.pending_targets.size())
	# Before the approach starts, no square.
	b._t0 = b._now() - (1.2 - b.SQUARE_LEAD - 0.2)
	b._process(0.016)
	assert_eq(b._prompt.square_progresses.size(), 0, "hidden before lead")
	_free_scene(b)


func test_multi_hit_squares_overlap_with_full_lead() -> void:
	var a := BossAttack.new()
	a.hit_times = PackedFloat32Array([0.6, 0.9, 1.2])
	var b = _scene_in_enemy_turn(a)
	# At 0.45 s: hit 0 is 0.15 s away, hit 1 is 0.45 s away, hit 2 not yet in lead.
	b._t0 = b._now() - 0.45
	b._process(0.016)
	var p: PackedFloat32Array = b._prompt.square_progresses
	assert_eq(p.size(), 2)
	assert_almost(p[0], 1.0 - 0.15 / b.SQUARE_LEAD, 0.05)
	assert_almost(p[1], 1.0 - 0.45 / b.SQUARE_LEAD, 0.05)
	_free_scene(b)
