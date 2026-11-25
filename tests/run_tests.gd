extends SceneTree
## Discovers res://tests/unit/test_*.gd and runs every test_* method.

const TEST_DIR := "res://tests/unit/"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + f)
		if script == null or not script.can_instantiate():
			print("FAIL %s: could not load script" % f)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var inst = script.new()
			inst.call(name)
			if inst.failures.is_empty():
				print("PASS %s::%s" % [f, name])
				passed += 1
			else:
				print("FAIL %s::%s: %s" % [f, name, "; ".join(inst.failures)])
				failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
