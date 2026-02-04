class_name CrewSlot
extends PanelContainer

## 크루 패널에서 개별 크루를 표시하는 슬롯
## 체력바, 스킬 쿨다운, 선택 상태 표시


signal clicked(slot: CrewSlot)
signal skill_button_pressed(slot: CrewSlot)
signal equipment_button_pressed(slot: CrewSlot)

@onready var _class_icon: TextureRect = $MarginContainer/HBoxContainer/ClassIcon
@onready var _info_container: VBoxContainer = $MarginContainer/HBoxContainer/InfoContainer
@onready var _name_label: Label = $MarginContainer/HBoxContainer/InfoContainer/NameLabel
@onready var _health_bar: ProgressBar = $MarginContainer/HBoxContainer/InfoContainer/HealthBar
@onready var _skill_cooldown: ProgressBar = $MarginContainer/HBoxContainer/InfoContainer/SkillCooldown
@onready var _selection_indicator: ColorRect = $SelectionIndicator
@onready var _hotkey_label: Label = $HotkeyLabel

var crew: Node  # CrewSquad
var slot_index: int = 0

var _is_selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	if _selection_indicator:
		_selection_indicator.visible = false


## 크루 데이터로 슬롯 설정
## [param crew_node]: CrewSquad 노드
## [param index]: 슬롯 인덱스 (단축키 표시용)
func setup(crew_node: Node, index: int = 0) -> void:
	crew = crew_node
	slot_index = index

	# 핫키 레이블 설정
	if _hotkey_label:
		_hotkey_label.text = str(index + 1)

	# 이름 설정
	if _name_label and crew:
		var class_data = _get_class_data()
		if class_data:
			_name_label.text = class_data.display_name if class_data.display_name else class_data.id
		else:
			_name_label.text = "Crew"

	# 시그널 연결
	if crew:
		if crew.has_signal("health_changed"):
			crew.health_changed.connect(_on_health_changed)
		if crew.has_signal("skill_cooldown_changed"):
			crew.skill_cooldown_changed.connect(_on_skill_cooldown_changed)

	_update_health()
	_update_skill_cooldown(0.0, 1.0)


## 선택 상태 설정
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _selection_indicator:
		_selection_indicator.visible = selected


## 선택 상태 반환
func is_selected() -> bool:
	return _is_selected


func _get_class_data():
	if crew == null:
		return null

	if crew.has_method("get_class_data"):
		return crew.get_class_data()

	if "crew_data" in crew and crew.crew_data:
		if "class_data" in crew.crew_data:
			return crew.crew_data.class_data
		elif "class_id" in crew.crew_data:
			return Constants.get_crew_class(crew.crew_data.class_id)

	return null


func _update_health() -> void:
	if _health_bar == null or crew == null:
		return

	var alive: int = 1
	var total: int = 1

	if crew.has_method("get_alive_count"):
		alive = crew.get_alive_count()
	elif "current_hp" in crew:
		alive = crew.current_hp

	if crew.has_method("get_max_squad_size"):
		total = crew.get_max_squad_size()
	elif "max_hp" in crew:
		total = crew.max_hp
	else:
		var class_data = _get_class_data()
		if class_data and "base_squad_size" in class_data:
			total = class_data.base_squad_size

	total = maxi(1, total)
	_health_bar.value = float(alive) / float(total) * 100.0

	# 체력 색상 변경
	var ratio := float(alive) / float(total)
	if ratio <= 0.25:
		_health_bar.modulate = Color(1.0, 0.3, 0.3)
	elif ratio <= 0.5:
		_health_bar.modulate = Color(1.0, 0.7, 0.3)
	else:
		_health_bar.modulate = Color(0.3, 0.9, 0.3)


func _update_skill_cooldown(remaining: float, total: float) -> void:
	if _skill_cooldown == null:
		return

	if total <= 0:
		_skill_cooldown.value = 100.0
	else:
		_skill_cooldown.value = (1.0 - remaining / total) * 100.0

	# 스킬 준비 완료 시 색상 변경
	if _skill_cooldown.value >= 100.0:
		_skill_cooldown.modulate = Color(0.3, 0.7, 1.0)
	else:
		_skill_cooldown.modulate = Color(0.5, 0.5, 0.5)


# ===== SIGNAL HANDLERS =====

func _on_health_changed(_current: int, _max_hp: int) -> void:
	_update_health()


func _on_skill_cooldown_changed(remaining: float, total: float) -> void:
	_update_skill_cooldown(remaining, total)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
