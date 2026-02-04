class_name BTComposite
extends BTNode

## Composite 노드 기본 클래스
## 여러 자식 노드를 관리

var _current_child_index: int = 0


func reset() -> void:
	super.reset()
	_current_child_index = 0


# =====================================================
# SELECTOR NODE
# 자식 중 하나가 SUCCESS하면 SUCCESS
# 모두 FAILURE하면 FAILURE
# =====================================================

class Selector extends BTComposite:
	func _init() -> void:
		name = "Selector"

	func tick(actor: Node, context: Dictionary) -> Status:
		while _current_child_index < children.size():
			var child := children[_current_child_index]
			var status := child.tick(actor, context)

			match status:
				Status.SUCCESS:
					_current_child_index = 0
					return Status.SUCCESS
				Status.RUNNING:
					return Status.RUNNING
				Status.FAILURE:
					_current_child_index += 1

		_current_child_index = 0
		return Status.FAILURE


# =====================================================
# SEQUENCE NODE
# 모든 자식이 SUCCESS해야 SUCCESS
# 하나라도 FAILURE하면 FAILURE
# =====================================================

class Sequence extends BTComposite:
	func _init() -> void:
		name = "Sequence"

	func tick(actor: Node, context: Dictionary) -> Status:
		while _current_child_index < children.size():
			var child := children[_current_child_index]
			var status := child.tick(actor, context)

			match status:
				Status.FAILURE:
					_current_child_index = 0
					return Status.FAILURE
				Status.RUNNING:
					return Status.RUNNING
				Status.SUCCESS:
					_current_child_index += 1

		_current_child_index = 0
		return Status.SUCCESS


# =====================================================
# PARALLEL NODE
# 모든 자식을 동시 실행
# policy에 따라 결과 결정
# =====================================================

class Parallel extends BTComposite:
	enum Policy {
		REQUIRE_ONE,  # 하나 SUCCESS면 SUCCESS
		REQUIRE_ALL   # 모두 SUCCESS해야 SUCCESS
	}

	var success_policy: Policy = Policy.REQUIRE_ONE
	var failure_policy: Policy = Policy.REQUIRE_ONE

	func _init(s_policy: Policy = Policy.REQUIRE_ONE, f_policy: Policy = Policy.REQUIRE_ONE) -> void:
		name = "Parallel"
		success_policy = s_policy
		failure_policy = f_policy

	func tick(actor: Node, context: Dictionary) -> Status:
		var success_count := 0
		var failure_count := 0

		for child in children:
			var status := child.tick(actor, context)

			match status:
				Status.SUCCESS:
					success_count += 1
				Status.FAILURE:
					failure_count += 1

		# Check failure first
		if failure_policy == Policy.REQUIRE_ONE and failure_count > 0:
			return Status.FAILURE
		if failure_policy == Policy.REQUIRE_ALL and failure_count == children.size():
			return Status.FAILURE

		# Check success
		if success_policy == Policy.REQUIRE_ONE and success_count > 0:
			return Status.SUCCESS
		if success_policy == Policy.REQUIRE_ALL and success_count == children.size():
			return Status.SUCCESS

		return Status.RUNNING


# =====================================================
# RANDOM SELECTOR NODE
# 자식 중 랜덤하게 선택하여 실행
# =====================================================

class RandomSelector extends BTComposite:
	var _shuffled_order: Array[int] = []
	var _needs_shuffle: bool = true

	func _init() -> void:
		name = "RandomSelector"

	func reset() -> void:
		super.reset()
		_needs_shuffle = true

	func tick(actor: Node, context: Dictionary) -> Status:
		if _needs_shuffle:
			_shuffle_children()
			_needs_shuffle = false

		while _current_child_index < _shuffled_order.size():
			var child_idx := _shuffled_order[_current_child_index]
			var child := children[child_idx]
			var status := child.tick(actor, context)

			match status:
				Status.SUCCESS:
					_current_child_index = 0
					_needs_shuffle = true
					return Status.SUCCESS
				Status.RUNNING:
					return Status.RUNNING
				Status.FAILURE:
					_current_child_index += 1

		_current_child_index = 0
		_needs_shuffle = true
		return Status.FAILURE

	func _shuffle_children() -> void:
		_shuffled_order.clear()
		for i in children.size():
			_shuffled_order.append(i)
		_shuffled_order.shuffle()
