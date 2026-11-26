extends Logger
## Counts engine and script errors so the runner can fail a test that crashed.

var count := 0
var _mutex := Mutex.new()


func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	count += 1
	_mutex.unlock()
