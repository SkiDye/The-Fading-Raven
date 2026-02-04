class_name CrewPanel
extends VBoxContainer

## 전투 중 크루 목록을 표시하는 패널
## 크루 선택, 체력/쿨다운 표시


const CREW_SLOT_SCENE_PATH: String = "res://src/ui/battle_hud/CrewSlot.tscn"

var _crew_slot_scene: PackedScene
var _crew_slots: Dictionary = {}  # crew_id -> CrewSlot
var _selected_crew: Node = null


func _ready() -> void:
	# 크루 슬롯 씬 로드
	if ResourceLoader.exists(CREW_SLOT_SCENE_PATH):
		_crew_slot_scene = load(CREW_SLOT_SCENE_PATH)
	else:
		push_warning("CrewPanel: CrewSlot scene not found at %s" % CREW_SLOT_SCENE_PATH)


## 모든 크루 슬롯 제거
func clear_crews() -> void:
	for child in get_children():
		child.queue_free()
	_crew_slots.clear()
	_selected_crew = null


## 크루 추가
## [param crew]: CrewSquad 노드
func add_crew(crew: Node) -> void:
	if _crew_slot_scene == null:
		push_warning("CrewPanel: Cannot add crew - slot scene not loaded")
		return

	var crew_id: String = _get_crew_id(crew)
	if crew_id.is_empty():
		crew_id = str(crew.get_instance_id())

	# 이미 존재하는 경우 무시
	if _crew_slots.has(crew_id):
		return

	var slot: CrewSlot = _crew_slot_scene.instantiate()
	add_child(slot)

	var index := _crew_slots.size()
	slot.setup(crew, index)
	slot.clicked.connect(_on_slot_clicked)

	_crew_slots[crew_id] = slot


## 크루 제거
## [param crew]: CrewSquad 노드
func remove_crew(crew: Node) -> void:
	var crew_id: String = _get_crew_id(crew)
	if crew_id.is_empty():
		crew_id = str(crew.get_instance_id())

	if _crew_slots.has(crew_id):
		var slot: CrewSlot = _crew_slots[crew_id]
		_crew_slots.erase(crew_id)
		slot.queue_free()

		if _selected_crew == crew:
			_selected_crew = null


## 크루 선택
## [param crew]: 선택할 CrewSquad 노드
func select_crew(crew: Node) -> void:
	_selected_crew = crew
	var crew_id: String = _get_crew_id(crew)
	if crew_id.is_empty():
		crew_id = str(crew.get_instance_id())

	for id in _crew_slots:
		var slot: CrewSlot = _crew_slots[id]
		slot.set_selected(id == crew_id)


## 인덱스로 크루 선택
## [param index]: 슬롯 인덱스 (0부터 시작)
func select_by_index(index: int) -> void:
	var keys := _crew_slots.keys()
	if index >= 0 and index < keys.size():
		var crew_id: String = keys[index]
		var slot: CrewSlot = _crew_slots[crew_id]
		if slot and slot.crew:
			EventBus.crew_selected.emit(slot.crew)


## 선택 해제
func deselect() -> void:
	_selected_crew = null
	for id in _crew_slots:
		_crew_slots[id].set_selected(false)


## 현재 선택된 크루 반환
func get_selected_crew() -> Node:
	return _selected_crew


## 슬롯 개수 반환
func get_slot_count() -> int:
	return _crew_slots.size()


func _get_crew_id(crew: Node) -> String:
	if crew == null:
		return ""

	if "entity_id" in crew:
		return crew.entity_id

	if "crew_data" in crew and crew.crew_data:
		if "id" in crew.crew_data:
			return crew.crew_data.id

	return ""


# ===== SIGNAL HANDLERS =====

func _on_slot_clicked(slot: CrewSlot) -> void:
	if slot and slot.crew:
		EventBus.crew_selected.emit(slot.crew)
