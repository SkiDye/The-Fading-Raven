class_name FacilityStatus
extends VBoxContainer

## 시설 상태 표시 UI
## 시설별 체력 및 크레딧 가치 표시


class FacilityEntry:
	var facility: Node
	var container: HBoxContainer
	var name_label: Label
	var health_bar: ProgressBar
	var credits_label: Label


var _facilities: Dictionary = {}  # facility_id -> FacilityEntry


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus:
		EventBus.facility_damaged.connect(_on_facility_damaged)
		EventBus.facility_destroyed.connect(_on_facility_destroyed)
		EventBus.facility_repaired.connect(_on_facility_repaired)


func _exit_tree() -> void:
	if EventBus:
		if EventBus.facility_damaged.is_connected(_on_facility_damaged):
			EventBus.facility_damaged.disconnect(_on_facility_damaged)
		if EventBus.facility_destroyed.is_connected(_on_facility_destroyed):
			EventBus.facility_destroyed.disconnect(_on_facility_destroyed)
		if EventBus.facility_repaired.is_connected(_on_facility_repaired):
			EventBus.facility_repaired.disconnect(_on_facility_repaired)


## 모든 시설 항목 제거
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_facilities.clear()


## 시설 추가
## [param facility]: Facility 노드
func add_facility(facility: Node) -> void:
	var facility_id: String = _get_facility_id(facility)
	if facility_id.is_empty():
		facility_id = str(facility.get_instance_id())

	if _facilities.has(facility_id):
		return

	# UI 요소 생성
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(80, 0)
	name_label.text = _get_facility_name(facility)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	container.add_child(name_label)

	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(60, 12)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	health_bar.value = 100.0
	container.add_child(health_bar)

	var credits_label := Label.new()
	credits_label.custom_minimum_size = Vector2(40, 0)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.text = _get_credits_text(facility)
	container.add_child(credits_label)

	add_child(container)

	# 엔트리 저장
	var entry := FacilityEntry.new()
	entry.facility = facility
	entry.container = container
	entry.name_label = name_label
	entry.health_bar = health_bar
	entry.credits_label = credits_label
	_facilities[facility_id] = entry

	# 시설 시그널 연결
	if facility.has_signal("health_changed"):
		facility.health_changed.connect(_on_specific_facility_health_changed.bind(facility_id))

	_update_facility_health(facility_id)


## 시설 제거
## [param facility]: Facility 노드
func remove_facility(facility: Node) -> void:
	var facility_id: String = _get_facility_id(facility)
	if facility_id.is_empty():
		facility_id = str(facility.get_instance_id())

	if _facilities.has(facility_id):
		var entry: FacilityEntry = _facilities[facility_id]
		entry.container.queue_free()
		_facilities.erase(facility_id)


func _get_facility_id(facility: Node) -> String:
	if facility == null:
		return ""

	if "entity_id" in facility:
		return facility.entity_id

	if "facility_data" in facility and facility.facility_data:
		if "id" in facility.facility_data:
			return facility.facility_data.id

	return ""


func _get_facility_name(facility: Node) -> String:
	if facility == null:
		return "Unknown"

	if "facility_data" in facility and facility.facility_data:
		if "display_name" in facility.facility_data:
			return facility.facility_data.display_name

	if "display_name" in facility:
		return facility.display_name

	return "Facility"


func _get_credits_text(facility: Node) -> String:
	var credits: int = 0

	if facility and "facility_data" in facility and facility.facility_data:
		if "credits" in facility.facility_data:
			credits = facility.facility_data.credits

	if credits > 0:
		return "+%d" % credits
	return ""


func _update_facility_health(facility_id: String) -> void:
	if not _facilities.has(facility_id):
		return

	var entry: FacilityEntry = _facilities[facility_id]
	if entry.facility == null:
		return

	var current_hp: int = 1
	var max_hp: int = 1

	if "current_hp" in entry.facility:
		current_hp = entry.facility.current_hp
	if "max_hp" in entry.facility:
		max_hp = entry.facility.max_hp

	max_hp = maxi(1, max_hp)
	var ratio := float(current_hp) / float(max_hp)
	entry.health_bar.value = ratio * 100.0

	# 색상 변경
	if ratio <= 0.0:
		entry.health_bar.modulate = Color(0.5, 0.5, 0.5)
		entry.name_label.modulate = Color(0.5, 0.5, 0.5)
		entry.credits_label.text = "X"
	elif ratio <= 0.3:
		entry.health_bar.modulate = Color(1.0, 0.3, 0.3)
	elif ratio <= 0.6:
		entry.health_bar.modulate = Color(1.0, 0.7, 0.3)
	else:
		entry.health_bar.modulate = Color(0.3, 0.9, 0.3)


# ===== SIGNAL HANDLERS =====

func _on_facility_damaged(facility: Node, _current_hp: int, _max_hp: int) -> void:
	var facility_id := _get_facility_id(facility)
	if facility_id.is_empty():
		facility_id = str(facility.get_instance_id())
	_update_facility_health(facility_id)


func _on_facility_destroyed(facility: Node) -> void:
	var facility_id := _get_facility_id(facility)
	if facility_id.is_empty():
		facility_id = str(facility.get_instance_id())
	_update_facility_health(facility_id)


func _on_facility_repaired(facility: Node) -> void:
	var facility_id := _get_facility_id(facility)
	if facility_id.is_empty():
		facility_id = str(facility.get_instance_id())
	_update_facility_health(facility_id)


func _on_specific_facility_health_changed(current: int, max_hp: int, facility_id: String) -> void:
	_update_facility_health(facility_id)
