class_name TestCase
extends RefCounted
## Base class for unit tests. Failures are collected, not thrown.

var failures: Array[String] = []


func assert_eq(a, b, msg := "") -> void:
	if typeof(a) != typeof(b) and not (_is_num(a) and _is_num(b)):
		failures.append("expected %s (%s), got %s (%s) %s" % [str(b), type_string(typeof(b)), str(a), type_string(typeof(a)), msg])
	elif a != b:
		failures.append("expected %s, got %s %s" % [str(b), str(a), msg])


func assert_true(c, msg := "") -> void:
	if not c:
		failures.append("expected true %s" % msg)


func assert_false(c, msg := "") -> void:
	if c:
		failures.append("expected false %s" % msg)


func assert_almost(a: float, b: float, eps := 0.001, msg := "") -> void:
	if absf(a - b) > eps:
		failures.append("expected ~%s, got %s %s" % [str(b), str(a), msg])


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
