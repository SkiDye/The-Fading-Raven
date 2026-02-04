class_name UpgradeScreen
extends Control

## 업그레이드 화면
## 크루 힐, 스킬 업그레이드, 장비 장착


signal upgrade_completed()
signal back_requested()

@onready var _crew_list: VBoxContainer = $HSplitContainer/LeftPanel/MarginContainer/CrewList
@onready var _detail_panel: PanelContainer = $HSplitContainer/RightPanel
@onready var _crew_name_label: Label = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/CrewNameLabel
@onready var _health_container: HBoxContainer = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/HealthContainer
@onready var _health_label: Label = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/HealthContainer/HealthLabel
@onready var _heal_btn: Button = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/HealthContainer/HealBtn
@onready var _skill_container: VBoxContainer = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/SkillContainer
@onready var _skill_name_label: Label = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/SkillContainer/SkillNameLabel
@onready var _skill_level_label: Label = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/SkillContainer/SkillLevelLabel
@onready var _upgrade_skill_btn: Button = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/SkillContainer/UpgradeSkillBtn
@onready var _equipment_container: VBoxContainer = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/EquipmentContainer
@onready var _equipment_label: Label = $HSplitContainer/RightPanel/MarginContainer/VBoxContainer/EquipmentContainer/EquipmentLabel
@onready var _credits_label: Label = $TopBar/CreditsLabel
@onready var _done_btn: Button = $TopBar/DoneBtn

var _selected_crew: Dictionary = {}
var _crews: Array = []


func _ready() -> void:
	_connect_signals()
	_hide_detail_panel()


func _connect_signals() -> void:
	if _heal_btn:
		_heal_btn.pressed.connect(_on_heal_pressed)

	if _upgrade_skill_btn:
		_upgrade_skill_btn.pressed.connect(_on_upgrade_skill_pressed)

	if _done_btn:
		_done_btn.pressed.connect(_on_done_pressed)


## 크루 목록 설정
func setup(crews: Array) -> void:
	_crews = crews
	_refresh_crew_list()
	_update_credits()
	_hide_detail_panel()


func _refresh_crew_list() -> void:
	if _crew_list == null:
		return

	# 기존 항목 제거
	for child in _crew_list.get_children():
		child.queue_free()

	# 크루 버튼 생성
	for crew in _crews:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)

		var crew_id: String = crew.get("id", "")
		var class_id: String = crew.get("class_id", "")
		var class_data = Constants.get_crew_class(class_id) if class_id else null

		var display_name: String = ""
		if class_data and "display_name" in class_data:
			display_name = class_data.display_name
		else:
			display_name = class_id.capitalize() if class_id else "Crew"

		var health_text := _get_health_text(crew)
		btn.text = "%s  %s" % [display_name, health_text]
		btn.pressed.connect(_on_crew_selected.bind(crew))

		_crew_list.add_child(btn)


func _get_health_text(crew: Dictionary) -> String:
	var current: int = crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(crew)
	return "[%d/%d]" % [current, max_hp]


func _get_max_squad_size(crew: Dictionary) -> int:
	var class_id: String = crew.get("class_id", "")
	var class_data = Constants.get_crew_class(class_id) if class_id else null

	if class_data and "base_squad_size" in class_data:
		return class_data.base_squad_size

	return Constants.BALANCE.squad_size.get(class_id, 8)


func _update_credits() -> void:
	if _credits_label == null:
		return

	var credits: int = 0
	if GameState and "credits" in GameState:
		credits = GameState.credits

	_credits_label.text = "Credits: %d" % credits


func _hide_detail_panel() -> void:
	if _detail_panel:
		_detail_panel.visible = false


func _show_detail_panel() -> void:
	if _detail_panel:
		_detail_panel.visible = true


func _update_detail_panel() -> void:
	if _selected_crew.is_empty():
		_hide_detail_panel()
		return

	_show_detail_panel()

	var class_id: String = _selected_crew.get("class_id", "")
	var class_data = Constants.get_crew_class(class_id) if class_id else null

	# 이름
	if _crew_name_label:
		if class_data and "display_name" in class_data:
			_crew_name_label.text = class_data.display_name
		else:
			_crew_name_label.text = class_id.capitalize()

	# 체력
	_update_health_section()

	# 스킬
	_update_skill_section()

	# 장비
	_update_equipment_section()


func _update_health_section() -> void:
	var current: int = _selected_crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(_selected_crew)

	if _health_label:
		_health_label.text = "Health: %d / %d" % [current, max_hp]

	if _heal_btn:
		var missing := max_hp - current
		if missing <= 0:
			_heal_btn.text = "Full Health"
			_heal_btn.disabled = true
		else:
			var heal_cost := _get_heal_cost(missing)
			_heal_btn.text = "Heal (+%d) - %d credits" % [missing, heal_cost]
			_heal_btn.disabled = not _can_afford(heal_cost)


func _update_skill_section() -> void:
	var skill_level: int = _selected_crew.get("skill_level", 0)
	var class_id: String = _selected_crew.get("class_id", "")
	var class_data = Constants.get_crew_class(class_id) if class_id else null

	if _skill_name_label:
		if class_data and "skill_id" in class_data:
			_skill_name_label.text = class_data.skill_id.replace("_", " ").capitalize()
		else:
			_skill_name_label.text = "Skill"

	if _skill_level_label:
		_skill_level_label.text = "Level: %d / 3" % skill_level

	if _upgrade_skill_btn:
		if skill_level >= 3:
			_upgrade_skill_btn.text = "MAX LEVEL"
			_upgrade_skill_btn.disabled = true
		else:
			var upgrade_cost := _get_skill_upgrade_cost(skill_level)
			_upgrade_skill_btn.text = "Upgrade - %d credits" % upgrade_cost
			_upgrade_skill_btn.disabled = not _can_afford(upgrade_cost)


func _update_equipment_section() -> void:
	var equipment_id: String = _selected_crew.get("equipment_id", "")

	if _equipment_label:
		if equipment_id.is_empty():
			_equipment_label.text = "No equipment"
		else:
			var equipment_data = Constants.get_equipment(equipment_id)
			if equipment_data and "display_name" in equipment_data:
				_equipment_label.text = equipment_data.display_name
			else:
				_equipment_label.text = equipment_id.capitalize()


func _get_heal_cost(missing_hp: int) -> int:
	# 기본: HP당 1 크레딧
	return missing_hp


func _get_skill_upgrade_cost(current_level: int) -> int:
	var costs: Array = Constants.BALANCE.upgrade_costs.skill_level
	if current_level >= 0 and current_level < costs.size():
		return costs[current_level]
	return 999


func _can_afford(cost: int) -> bool:
	var credits: int = 0
	if GameState and "credits" in GameState:
		credits = GameState.credits
	return credits >= cost


func _spend_credits(amount: int) -> bool:
	if GameState and GameState.has_method("spend_credits"):
		return GameState.spend_credits(amount)
	elif GameState and "credits" in GameState:
		if GameState.credits >= amount:
			GameState.credits -= amount
			return true
	return false


# ===== SIGNAL HANDLERS =====

func _on_crew_selected(crew: Dictionary) -> void:
	_selected_crew = crew
	_update_detail_panel()


func _on_heal_pressed() -> void:
	if _selected_crew.is_empty():
		return

	var current: int = _selected_crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(_selected_crew)
	var missing := max_hp - current
	var cost := _get_heal_cost(missing)

	if _spend_credits(cost):
		_selected_crew.current_hp = max_hp

		_update_credits()
		_update_detail_panel()
		_refresh_crew_list()


func _on_upgrade_skill_pressed() -> void:
	if _selected_crew.is_empty():
		return

	var skill_level: int = _selected_crew.get("skill_level", 0)
	if skill_level >= 3:
		return

	var cost := _get_skill_upgrade_cost(skill_level)

	if _spend_credits(cost):
		_selected_crew.skill_level = skill_level + 1

		_update_credits()
		_update_detail_panel()


func _on_done_pressed() -> void:
	upgrade_completed.emit()
	back_requested.emit()

	# 섹터 맵으로 복귀
	var sector_scene := "res://scenes/campaign/SectorMap.tscn"
	if ResourceLoader.exists(sector_scene):
		get_tree().change_scene_to_file(sector_scene)
