extends TestCase


func test_defeat_scene_instantiates() -> void:
	var s: PackedScene = load("res://scenes/defeat/defeat.tscn")
	assert_true(s != null)
	if s:
		var n := s.instantiate()
		assert_true(n != null)
		n.free()


func test_save_point_scene_instantiates() -> void:
	var s: PackedScene = load("res://scenes/save_point/save_point.tscn")
	assert_true(s != null)
	if s:
		var n := s.instantiate()
		assert_true(n != null)
		n.free()


func test_main_scene_is_save_point() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/save_point/save_point.tscn")


func test_defeat_lists_assist_options() -> void:
	var la: LossAssist = GameState.loss_assist
	la.debug_set_losses(&"warden", 21)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var n = load("res://scenes/defeat/defeat.tscn").instantiate()
	root.add_child(n)
	assert_eq(n.options.size(), 4)
	assert_true(String(n.labels[2]).contains("keeps its damage"))
	root.remove_child(n)
	n.free()
	la.debug_set_losses(&"warden", 0)


func test_defeat_ignores_input_right_after_opening() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var n = load("res://scenes/defeat/defeat.tscn").instantiate()
	root.add_child(n)
	assert_false(n.accepts_input(), "mash guard active")
	root.remove_child(n)
	n.free()


func test_save_point_ignores_input_right_after_opening() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var n = load("res://scenes/save_point/save_point.tscn").instantiate()
	root.add_child(n)
	assert_false(n.accepts_input(), "mash guard active")
	root.remove_child(n)
	n.free()
