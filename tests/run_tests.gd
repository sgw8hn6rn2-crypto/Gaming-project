extends SceneTree
## Discovers res://tests/unit/test_*.gd and runs every test_* method.

const TEST_DIR := "res://tests/unit/"


var _ran := false


## Tests run on the first frame so the root window is inside the tree and
## scene tests can add nodes.
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
	return false


func _run_all() -> void:
	var errors = load("res://tests/error_counter.gd").new()
	OS.add_logger(errors)
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
			var before: int = errors.count
			inst.call(name)
			if errors.count > before:
				inst.failures.append("%d engine/script error(s) during test" % (errors.count - before))
			if inst.failures.is_empty():
				print("PASS %s::%s" % [f, name])
				passed += 1
			else:
				print("FAIL %s::%s: %s" % [f, name, "; ".join(inst.failures)])
				failed += 1
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
