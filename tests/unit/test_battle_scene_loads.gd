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
