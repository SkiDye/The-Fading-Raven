class_name BTLeaf
extends BTNode

## Leaf 노드 기본 클래스
## 실제 조건 검사나 행동 실행


# =====================================================
# CONDITION NODE
# 조건 검사 (Callable 또는 오버라이드)
# =====================================================

class Condition extends BTLeaf:
	var check_func: Callable

	func _init(func_ref: Callable = Callable()) -> void:
		name = "Condition"
		check_func = func_ref

	func tick(actor: Node, context: Dictionary) -> Status:
		var result: bool

		if check_func.is_valid():
			result = check_func.call(actor, context)
		else:
			result = _check(actor, context)

		return Status.SUCCESS if result else Status.FAILURE

	## 서브클래스에서 오버라이드
	func _check(_actor: Node, _context: Dictionary) -> bool:
		return false


# =====================================================
# ACTION NODE
# 행동 실행 (Callable 또는 오버라이드)
# =====================================================

class Action extends BTLeaf:
	var action_func: Callable

	func _init(func_ref: Callable = Callable()) -> void:
		name = "Action"
		action_func = func_ref

	func tick(actor: Node, context: Dictionary) -> Status:
		if action_func.is_valid():
			var result = action_func.call(actor, context)
			if result is int:
				return result
			return Status.SUCCESS if result else Status.FAILURE
		else:
			return _execute(actor, context)

	## 서브클래스에서 오버라이드
	func _execute(_actor: Node, _context: Dictionary) -> Status:
		return Status.SUCCESS


# =====================================================
# WAIT NODE
# 지정 시간 대기
# =====================================================

class Wait extends BTLeaf:
	var wait_time: float = 1.0
	var _elapsed: float = 0.0
	var _is_waiting: bool = false

	func _init(duration: float = 1.0) -> void:
		name = "Wait"
		wait_time = duration

	func reset() -> void:
		_elapsed = 0.0
		_is_waiting = false

	func tick(_actor: Node, context: Dictionary) -> Status:
		if not _is_waiting:
			_is_waiting = true
			_elapsed = 0.0

		var delta: float = context.get("delta", 0.016)
		_elapsed += delta

		if _elapsed >= wait_time:
			_is_waiting = false
			return Status.SUCCESS

		return Status.RUNNING


# =====================================================
# RANDOM WAIT NODE
# 랜덤 시간 대기
# =====================================================

class RandomWait extends BTLeaf:
	var min_time: float = 0.5
	var max_time: float = 2.0
	var _target_time: float = 0.0
	var _elapsed: float = 0.0
	var _is_waiting: bool = false

	func _init(min_t: float = 0.5, max_t: float = 2.0) -> void:
		name = "RandomWait"
		min_time = min_t
		max_time = max_t

	func reset() -> void:
		_elapsed = 0.0
		_is_waiting = false

	func tick(_actor: Node, context: Dictionary) -> Status:
		if not _is_waiting:
			_is_waiting = true
			_elapsed = 0.0
			_target_time = randf_range(min_time, max_time)

		var delta: float = context.get("delta", 0.016)
		_elapsed += delta

		if _elapsed >= _target_time:
			_is_waiting = false
			return Status.SUCCESS

		return Status.RUNNING


# =====================================================
# LOG NODE
# 디버그 로그 출력
# =====================================================

class Log extends BTLeaf:
	var message: String = ""
	var return_status: Status = Status.SUCCESS

	func _init(msg: String = "", status: Status = Status.SUCCESS) -> void:
		name = "Log"
		message = msg
		return_status = status

	func tick(actor: Node, _context: Dictionary) -> Status:
		print("[BT] %s: %s" % [actor.name if actor else "null", message])
		return return_status


# =====================================================
# ALWAYS SUCCESS NODE
# =====================================================

class AlwaysSuccess extends BTLeaf:
	func _init() -> void:
		name = "AlwaysSuccess"

	func tick(_actor: Node, _context: Dictionary) -> Status:
		return Status.SUCCESS


# =====================================================
# ALWAYS FAILURE NODE
# =====================================================

class AlwaysFailure extends BTLeaf:
	func _init() -> void:
		name = "AlwaysFailure"

	func tick(_actor: Node, _context: Dictionary) -> Status:
		return Status.FAILURE
