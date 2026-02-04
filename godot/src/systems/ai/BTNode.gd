class_name BTNode
extends RefCounted

## Behavior Tree 노드 기본 클래스
## 모든 BT 노드는 이 클래스를 상속


# ===== CONSTANTS =====

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING
}


# ===== PROPERTIES =====

var name: String = "BTNode"
var children: Array[BTNode] = []


# ===== VIRTUAL METHODS =====

## 노드 실행. 서브클래스에서 오버라이드
func tick(actor: Node, context: Dictionary) -> Status:
	return Status.FAILURE


## 노드 초기화 (트리 시작 시)
func initialize(_actor: Node, _context: Dictionary) -> void:
	pass


## 노드 리셋 (트리 재시작 시)
func reset() -> void:
	for child in children:
		child.reset()


# ===== CHILD MANAGEMENT =====

func add_child(child: BTNode) -> BTNode:
	children.append(child)
	return self


func add_children(new_children: Array[BTNode]) -> BTNode:
	children.append_array(new_children)
	return self


func get_child(index: int) -> BTNode:
	if index >= 0 and index < children.size():
		return children[index]
	return null


func get_child_count() -> int:
	return children.size()


# ===== BUILDER PATTERN =====

func set_name(n: String) -> BTNode:
	name = n
	return self


# ===== DEBUG =====

func _to_string() -> String:
	return "BTNode(%s)" % name


func get_tree_string(indent: int = 0) -> String:
	var result := "  ".repeat(indent) + str(self) + "\n"
	for child in children:
		result += child.get_tree_string(indent + 1)
	return result
