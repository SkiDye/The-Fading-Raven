class_name BTDecorator
extends BTNode

## Decorator 노드 기본 클래스
## 단일 자식의 결과를 변형

var child: BTNode


func set_child(c: BTNode) -> BTDecorator:
	child = c
	return self


func reset() -> void:
	if child:
		child.reset()


# =====================================================
# INVERTER NODE
# 자식 결과를 반전 (SUCCESS <-> FAILURE)
# =====================================================

class Inverter extends BTDecorator:
	func _init() -> void:
		name = "Inverter"

	func tick(actor: Node, context: Dictionary) -> Status:
		if child == null:
			return Status.FAILURE

		var status := child.tick(actor, context)

		match status:
			Status.SUCCESS:
				return Status.FAILURE
			Status.FAILURE:
				return Status.SUCCESS
			_:
				return status


# =====================================================
# SUCCEEDER NODE
# 항상 SUCCESS 반환
# =====================================================

class Succeeder extends BTDecorator:
	func _init() -> void:
		name = "Succeeder"

	func tick(actor: Node, context: Dictionary) -> Status:
		if child:
			child.tick(actor, context)
		return Status.SUCCESS


# =====================================================
# FAILER NODE
# 항상 FAILURE 반환
# =====================================================

class Failer extends BTDecorator:
	func _init() -> void:
		name = "Failer"

	func tick(actor: Node, context: Dictionary) -> Status:
		if child:
			child.tick(actor, context)
		return Status.FAILURE


# =====================================================
# REPEATER NODE
# 자식을 반복 실행
# =====================================================

class Repeater extends BTDecorator:
	var max_count: int = -1  # -1 = 무한
	var _current_count: int = 0

	func _init(count: int = -1) -> void:
		name = "Repeater"
		max_count = count

	func reset() -> void:
		super.reset()
		_current_count = 0

	func tick(actor: Node, context: Dictionary) -> Status:
		if child == null:
			return Status.FAILURE

		if max_count > 0 and _current_count >= max_count:
			return Status.SUCCESS

		var status := child.tick(actor, context)

		if status == Status.RUNNING:
			return Status.RUNNING

		_current_count += 1
		child.reset()

		if max_count > 0 and _current_count >= max_count:
			return Status.SUCCESS

		return Status.RUNNING


# =====================================================
# REPEAT UNTIL FAIL NODE
# 자식이 FAILURE할 때까지 반복
# =====================================================

class RepeatUntilFail extends BTDecorator:
	func _init() -> void:
		name = "RepeatUntilFail"

	func tick(actor: Node, context: Dictionary) -> Status:
		if child == null:
			return Status.SUCCESS

		var status := child.tick(actor, context)

		if status == Status.FAILURE:
			return Status.SUCCESS

		if status == Status.SUCCESS:
			child.reset()

		return Status.RUNNING


# =====================================================
# COOLDOWN NODE
# 쿨다운 기간 동안 자식 실행 방지
# =====================================================

class Cooldown extends BTDecorator:
	var cooldown_time: float = 1.0
	var _last_execution_time: float = -INF

	func _init(duration: float = 1.0) -> void:
		name = "Cooldown"
		cooldown_time = duration

	func tick(actor: Node, context: Dictionary) -> Status:
		if child == null:
			return Status.FAILURE

		var current_time: float = context.get("time", 0.0)

		if current_time - _last_execution_time < cooldown_time:
			return Status.FAILURE

		var status := child.tick(actor, context)

		if status != Status.RUNNING:
			_last_execution_time = current_time

		return status

	func reset() -> void:
		super.reset()
		_last_execution_time = -INF


# =====================================================
# TIMEOUT NODE
# 제한 시간 내 완료되지 않으면 FAILURE
# =====================================================

class Timeout extends BTDecorator:
	var timeout_duration: float = 5.0
	var _start_time: float = -1.0
	var _is_running: bool = false

	func _init(duration: float = 5.0) -> void:
		name = "Timeout"
		timeout_duration = duration

	func reset() -> void:
		super.reset()
		_start_time = -1.0
		_is_running = false

	func tick(actor: Node, context: Dictionary) -> Status:
		if child == null:
			return Status.FAILURE

		var current_time: float = context.get("time", 0.0)

		if not _is_running:
			_start_time = current_time
			_is_running = true

		if current_time - _start_time >= timeout_duration:
			_is_running = false
			return Status.FAILURE

		var status := child.tick(actor, context)

		if status != Status.RUNNING:
			_is_running = false

		return status


# =====================================================
# CONDITION GUARD NODE
# 조건이 참일 때만 자식 실행
# =====================================================

class ConditionGuard extends BTDecorator:
	var condition: Callable

	func _init(cond: Callable = Callable()) -> void:
		name = "ConditionGuard"
		condition = cond

	func tick(actor: Node, context: Dictionary) -> Status:
		if not condition.is_valid():
			return Status.FAILURE

		if not condition.call(actor, context):
			return Status.FAILURE

		if child == null:
			return Status.SUCCESS

		return child.tick(actor, context)
