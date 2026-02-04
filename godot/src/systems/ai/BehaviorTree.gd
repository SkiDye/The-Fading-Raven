class_name BehaviorTree
extends RefCounted

## 행동 트리 기본 구조
## 적 AI의 의사결정 트리를 구성하는 노드들


# ===== ENUMS =====

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}


# ===== BASE NODE =====

class BTNode:
	## 행동 트리 기본 노드

	var children: Array = []  # Array of BTNode

	func tick(_entity: Node, _delta: float) -> int:
		return Status.SUCCESS

	func add_child(child: BTNode) -> BTNode:
		children.append(child)
		return self


# ===== COMPOSITE NODES =====

class BTSelector extends BTNode:
	## 자식 중 하나가 성공할 때까지 순차 실행
	## OR 로직: 하나라도 성공하면 성공

	func tick(entity: Node, delta: float) -> int:
		for child in children:
			var status: int = child.tick(entity, delta)
			if status != Status.FAILURE:
				return status
		return Status.FAILURE


class BTSequence extends BTNode:
	## 모든 자식이 성공해야 성공
	## AND 로직: 하나라도 실패하면 실패

	func tick(entity: Node, delta: float) -> int:
		for child in children:
			var status: int = child.tick(entity, delta)
			if status != Status.SUCCESS:
				return status
		return Status.SUCCESS


class BTParallel extends BTNode:
	## 모든 자식을 동시에 실행
	## 설정에 따라 성공/실패 판정

	var require_all_success: bool = true

	func tick(entity: Node, delta: float) -> int:
		var success_count: int = 0
		var failure_count: int = 0

		for child in children:
			var status: int = child.tick(entity, delta)
			match status:
				Status.SUCCESS:
					success_count += 1
				Status.FAILURE:
					failure_count += 1

		if require_all_success:
			if failure_count > 0:
				return Status.FAILURE
			if success_count == children.size():
				return Status.SUCCESS
		else:
			if success_count > 0:
				return Status.SUCCESS
			if failure_count == children.size():
				return Status.FAILURE

		return Status.RUNNING


class BTRandomSelector extends BTNode:
	## 자식을 랜덤 순서로 실행

	func tick(entity: Node, delta: float) -> int:
		var shuffled: Array = children.duplicate()
		shuffled.shuffle()

		for child in shuffled:
			var status: int = child.tick(entity, delta)
			if status != Status.FAILURE:
				return status
		return Status.FAILURE


# ===== DECORATOR NODES =====

class BTInverter extends BTNode:
	## 자식 결과를 반전

	func tick(entity: Node, delta: float) -> int:
		if children.is_empty():
			return Status.FAILURE

		var status: int = children[0].tick(entity, delta)
		match status:
			Status.SUCCESS:
				return Status.FAILURE
			Status.FAILURE:
				return Status.SUCCESS
			_:
				return status


class BTRepeater extends BTNode:
	## 자식을 N번 반복 실행

	var repeat_count: int = 1
	var _current_count: int = 0

	func _init(count: int = 1):
		repeat_count = count

	func tick(entity: Node, delta: float) -> int:
		if children.is_empty():
			return Status.FAILURE

		while _current_count < repeat_count:
			var status: int = children[0].tick(entity, delta)
			if status == Status.RUNNING:
				return Status.RUNNING
			if status == Status.FAILURE:
				_current_count = 0
				return Status.FAILURE
			_current_count += 1

		_current_count = 0
		return Status.SUCCESS


class BTSucceeder extends BTNode:
	## 자식 결과와 관계없이 항상 성공

	func tick(entity: Node, delta: float) -> int:
		if not children.is_empty():
			children[0].tick(entity, delta)
		return Status.SUCCESS


class BTUntilFail extends BTNode:
	## 자식이 실패할 때까지 반복

	func tick(entity: Node, delta: float) -> int:
		if children.is_empty():
			return Status.FAILURE

		var status: int = children[0].tick(entity, delta)
		if status == Status.FAILURE:
			return Status.SUCCESS
		return Status.RUNNING


class BTCooldown extends BTNode:
	## 쿨다운이 지나야 자식 실행

	var cooldown_time: float = 1.0
	var _last_run_time: float = -INF

	func _init(cooldown: float = 1.0):
		cooldown_time = cooldown

	func tick(entity: Node, delta: float) -> int:
		var current_time: float = Time.get_ticks_msec() / 1000.0

		if current_time - _last_run_time < cooldown_time:
			return Status.FAILURE

		if children.is_empty():
			return Status.FAILURE

		var status: int = children[0].tick(entity, delta)
		if status != Status.RUNNING:
			_last_run_time = current_time

		return status


# ===== LEAF NODES =====

class BTCondition extends BTNode:
	## 조건 체크 노드

	var condition: Callable

	func _init(cond: Callable):
		condition = cond

	func tick(entity: Node, _delta: float) -> int:
		if condition.is_valid() and condition.call(entity):
			return Status.SUCCESS
		return Status.FAILURE


class BTAction extends BTNode:
	## 행동 실행 노드

	var action: Callable

	func _init(act: Callable):
		action = act

	func tick(entity: Node, delta: float) -> int:
		if action.is_valid():
			return action.call(entity, delta)
		return Status.FAILURE


class BTWait extends BTNode:
	## 일정 시간 대기

	var wait_time: float = 1.0
	var _elapsed: float = 0.0

	func _init(time: float = 1.0):
		wait_time = time

	func tick(_entity: Node, delta: float) -> int:
		_elapsed += delta
		if _elapsed >= wait_time:
			_elapsed = 0.0
			return Status.SUCCESS
		return Status.RUNNING


class BTLog extends BTNode:
	## 디버그 로그 출력

	var message: String

	func _init(msg: String):
		message = msg

	func tick(entity: Node, _delta: float) -> int:
		print("[BT] %s - Entity: %s" % [message, entity.name if entity else "null"])
		return Status.SUCCESS


# ===== BUILDER HELPERS =====

## 셀렉터 노드 생성
static func selector(node_children: Array = []) -> BTSelector:
	var node := BTSelector.new()
	for child in node_children:
		node.children.append(child)
	return node


## 시퀀스 노드 생성
static func sequence(node_children: Array = []) -> BTSequence:
	var node := BTSequence.new()
	for child in node_children:
		node.children.append(child)
	return node


## 조건 노드 생성
static func condition(cond: Callable) -> BTCondition:
	return BTCondition.new(cond)


## 액션 노드 생성
static func action(act: Callable) -> BTAction:
	return BTAction.new(act)


## 반전 데코레이터 생성
static func invert(child: BTNode) -> BTInverter:
	var node := BTInverter.new()
	node.children.append(child)
	return node


## 쿨다운 데코레이터 생성
static func cooldown(time: float, child: BTNode) -> BTCooldown:
	var node := BTCooldown.new(time)
	node.children.append(child)
	return node


## 대기 노드 생성
static func wait(time: float) -> BTWait:
	return BTWait.new(time)


## 병렬 노드 생성
static func parallel(node_children: Array = [], require_all: bool = true) -> BTParallel:
	var node := BTParallel.new()
	node.require_all_success = require_all
	for child in node_children:
		node.children.append(child)
	return node


## 랜덤 셀렉터 생성
static func random_selector(node_children: Array = []) -> BTRandomSelector:
	var node := BTRandomSelector.new()
	for child in node_children:
		node.children.append(child)
	return node


## 반복 데코레이터 생성
static func repeat(count: int, child: BTNode) -> BTRepeater:
	var node := BTRepeater.new(count)
	node.children.append(child)
	return node


## 성공 보장 데코레이터 생성
static func always_succeed(child: BTNode) -> BTSucceeder:
	var node := BTSucceeder.new()
	node.children.append(child)
	return node


## 실패할 때까지 반복 생성
static func until_fail(child: BTNode) -> BTUntilFail:
	var node := BTUntilFail.new()
	node.children.append(child)
	return node


## 로그 노드 생성
static func log(message: String) -> BTLog:
	return BTLog.new(message)


# ===== TREE RUNNER =====

class TreeRunner:
	## BehaviorTree 실행 관리자

	var root: BTNode
	var blackboard: Dictionary = {}

	func _init(root_node: BTNode = null):
		root = root_node

	func tick(entity: Node, delta: float) -> int:
		if root == null:
			return Status.FAILURE
		return root.tick(entity, delta)

	func set_root(node: BTNode) -> TreeRunner:
		root = node
		return self

	func set_blackboard_value(key: String, value: Variant) -> void:
		blackboard[key] = value

	func get_blackboard_value(key: String, default: Variant = null) -> Variant:
		return blackboard.get(key, default)
