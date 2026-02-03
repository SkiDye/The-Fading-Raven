## UpgradeScreen - 업그레이드 화면 UI
## 크루 관리, 스킬 업그레이드, 장비 관리
extends Control

# ===========================================
# 씬 참조
# ===========================================

@onready var credits_label: Label = $CreditsLabel
@onready var back_button: Button = $BackButton
@onready var tab_container: TabContainer = $TabContainer

# 크루 탭
@onready var crew_list: VBoxContainer = $TabContainer/Crews/ScrollContainer/CrewList

# 장비 탭
@onready var equipment_list: VBoxContainer = $TabContainer/Equipment/ScrollContainer/EquipmentList

# 선택된 크루 정보
@onready var selected_panel: PanelContainer = $SelectedPanel
@onready var selected_name: Label = $SelectedPanel/VBox/NameLabel
@onready var selected_class: Label = $SelectedPanel/VBox/ClassLabel
@onready var selected_stats: Label = $SelectedPanel/VBox/StatsLabel
@onready var heal_button: Button = $SelectedPanel/VBox/HealButton
@onready var skill_button: Button = $SelectedPanel/VBox/SkillButton
@onready var rank_button: Button = $SelectedPanel/VBox/RankButton

var selected_crew_index: int = -1


# ===========================================
# 초기화
# ===========================================

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	rank_button.pressed.connect(_on_rank_pressed)

	_update_credits()
	_populate_crew_list()
	_populate_equipment_list()
	_hide_selected_panel()

	EventBus.credits_changed.connect(_on_credits_changed)


# ===========================================
# UI 업데이트
# ===========================================

func _update_credits() -> void:
	credits_label.text = "Credits: %d" % GameState.get_credits()


func _on_credits_changed(_new_amount: int, _delta: int) -> void:
	_update_credits()
	_update_selected_panel()


# ===========================================
# 크루 목록
# ===========================================

func _populate_crew_list() -> void:
	# 기존 항목 제거
	for child in crew_list.get_children():
		child.queue_free()

	var run := GameState.get_current_run()
	if run == null:
		return

	for i in range(run.crews.size()):
		var crew: Dictionary = run.crews[i]
		_create_crew_item(i, crew)


func _create_crew_item(index: int, crew: Dictionary) -> void:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 50)

	# 상태 색상
	var is_alive: bool = crew.get("is_alive", true)
	var status_color := Color(0.8, 0.8, 0.8) if is_alive else Color(0.5, 0.3, 0.3)

	# 이름 버튼
	var name_btn := Button.new()
	name_btn.text = crew.get("name", "Unknown")
	name_btn.custom_minimum_size = Vector2(120, 40)
	name_btn.modulate = status_color
	name_btn.disabled = not is_alive
	name_btn.pressed.connect(_on_crew_selected.bind(index))
	container.add_child(name_btn)

	# 클래스
	var class_label := Label.new()
	var class_data: Dictionary = DataRegistry.get_crew_class(crew.get("class_id", ""))
	class_label.text = class_data.get("name", "?")
	class_label.custom_minimum_size = Vector2(80, 0)
	class_label.modulate = status_color
	container.add_child(class_label)

	# 분대 크기
	var squad_label := Label.new()
	squad_label.text = "%d/%d" % [crew.get("squad_size", 0), crew.get("max_squad_size", 8)]
	squad_label.custom_minimum_size = Vector2(60, 0)
	squad_label.modulate = status_color
	container.add_child(squad_label)

	# 스킬 레벨
	var skill_label := Label.new()
	skill_label.text = "Skill Lv.%d" % crew.get("skill_level", 0)
	skill_label.custom_minimum_size = Vector2(80, 0)
	container.add_child(skill_label)

	# 랭크
	var rank_label := Label.new()
	rank_label.text = crew.get("rank", "standard").capitalize()
	rank_label.custom_minimum_size = Vector2(80, 0)
	container.add_child(rank_label)

	crew_list.add_child(container)


# ===========================================
# 크루 선택
# ===========================================

func _on_crew_selected(index: int) -> void:
	selected_crew_index = index
	_update_selected_panel()
	selected_panel.visible = true


func _hide_selected_panel() -> void:
	selected_panel.visible = false
	selected_crew_index = -1


func _update_selected_panel() -> void:
	if selected_crew_index < 0:
		return

	var run := GameState.get_current_run()
	if run == null or selected_crew_index >= run.crews.size():
		_hide_selected_panel()
		return

	var crew: Dictionary = run.crews[selected_crew_index]
	var class_data: Dictionary = DataRegistry.get_crew_class(crew.get("class_id", ""))

	# 기본 정보
	selected_name.text = crew.get("name", "Unknown")
	selected_class.text = "%s (%s)" % [class_data.get("name", "?"), crew.get("rank", "standard").capitalize()]

	# 스탯
	var stats_text := "Squad: %d/%d\n" % [crew.get("squad_size", 0), crew.get("max_squad_size", 8)]
	stats_text += "Skill Level: %d/3\n" % crew.get("skill_level", 0)
	stats_text += "Trait: %s" % _get_trait_name(crew.get("trait_id", ""))
	selected_stats.text = stats_text

	# 버튼 상태
	_update_action_buttons(crew)


func _update_action_buttons(crew: Dictionary) -> void:
	var credits := GameState.get_credits()

	# 치료 버튼
	var squad_size: int = crew.get("squad_size", 0)
	var max_size: int = crew.get("max_squad_size", 8)
	var heal_cost: int = Balance.ECONOMY["heal_cost"]
	var can_heal := squad_size < max_size and credits >= heal_cost

	heal_button.text = "Heal (+2) - %d¢" % heal_cost
	heal_button.disabled = not can_heal

	# 스킬 업그레이드 버튼
	var skill_level: int = crew.get("skill_level", 0)
	var next_level := skill_level + 1

	if next_level <= 3:
		var skill_costs: Dictionary = Balance.ECONOMY["skill_upgrade_costs"]
		var skill_cost: int = skill_costs.get(next_level, 999)

		# 특성 할인
		if crew.get("trait_id") == "skillful":
			skill_cost = int(skill_cost * 0.5)

		var can_upgrade := credits >= skill_cost

		skill_button.text = "Skill Lv.%d - %d¢" % [next_level, skill_cost]
		skill_button.disabled = not can_upgrade
	else:
		skill_button.text = "Skill MAX"
		skill_button.disabled = true

	# 랭크업 버튼
	var rank: String = crew.get("rank", "standard")
	var next_rank := ""

	if rank == "standard":
		next_rank = "veteran"
	elif rank == "veteran":
		next_rank = "elite"

	if not next_rank.is_empty():
		var rank_cost: int = Balance.ECONOMY["rank_up_costs"].get(next_rank, 999)
		var can_rank := credits >= rank_cost

		rank_button.text = "Rank Up (%s) - %d¢" % [next_rank.capitalize(), rank_cost]
		rank_button.disabled = not can_rank
	else:
		rank_button.text = "Rank MAX"
		rank_button.disabled = true


func _get_trait_name(trait_id: String) -> String:
	if trait_id.is_empty():
		return "None"
	var trait_data: Dictionary = DataRegistry.get_trait(trait_id)
	return trait_data.get("name", trait_id)


# ===========================================
# 액션 버튼
# ===========================================

func _on_heal_pressed() -> void:
	if selected_crew_index < 0:
		return

	var run := GameState.get_current_run()
	if run == null:
		return

	var crew_id: String = run.crews[selected_crew_index].get("id", "")
	if GameState.heal_crew(crew_id):
		_populate_crew_list()
		_update_selected_panel()
		EventBus.show_toast("Crew healed!", "success")


func _on_skill_pressed() -> void:
	if selected_crew_index < 0:
		return

	var run := GameState.get_current_run()
	if run == null:
		return

	var crew_id: String = run.crews[selected_crew_index].get("id", "")
	if GameState.upgrade_crew_skill(crew_id):
		_populate_crew_list()
		_update_selected_panel()
		EventBus.show_toast("Skill upgraded!", "success")


func _on_rank_pressed() -> void:
	if selected_crew_index < 0:
		return

	var run := GameState.get_current_run()
	if run == null:
		return

	var crew_id: String = run.crews[selected_crew_index].get("id", "")
	if GameState.rank_up_crew(crew_id):
		_populate_crew_list()
		_update_selected_panel()
		EventBus.show_toast("Rank up!", "success")


# ===========================================
# 장비 목록
# ===========================================

func _populate_equipment_list() -> void:
	# 기존 항목 제거
	for child in equipment_list.get_children():
		child.queue_free()

	var run := GameState.get_current_run()
	if run == null:
		return

	# 인벤토리 장비
	if run.inventory_equipment.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No equipment in inventory"
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		equipment_list.add_child(empty_label)
		return

	for equipment_id in run.inventory_equipment:
		_create_equipment_item(equipment_id)


func _create_equipment_item(equipment_id: String) -> void:
	var equip_data: Dictionary = DataRegistry.get_equipment(equipment_id)
	if equip_data.is_empty():
		return

	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)

	# 이름
	var name_label := Label.new()
	name_label.text = equip_data.get("name", equipment_id)
	name_label.custom_minimum_size = Vector2(150, 0)
	container.add_child(name_label)

	# 타입
	var type_label := Label.new()
	type_label.text = equip_data.get("type", "?")
	type_label.custom_minimum_size = Vector2(100, 0)
	type_label.modulate = Color(0.6, 0.6, 0.7)
	container.add_child(type_label)

	# 장착 버튼
	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.custom_minimum_size = Vector2(80, 30)
	equip_btn.pressed.connect(_on_equip_pressed.bind(equipment_id))
	container.add_child(equip_btn)

	equipment_list.add_child(container)


func _on_equip_pressed(equipment_id: String) -> void:
	if selected_crew_index < 0:
		EventBus.show_toast("Select a crew first", "warning")
		return

	var run := GameState.get_current_run()
	if run == null:
		return

	var crew_id: String = run.crews[selected_crew_index].get("id", "")
	if GameState.equip_item(crew_id, equipment_id):
		# 인벤토리에서 제거
		run.inventory_equipment.erase(equipment_id)
		GameState.save_run()

		_populate_crew_list()
		_populate_equipment_list()
		_update_selected_panel()
		EventBus.show_toast("Equipment equipped!", "success")
	else:
		EventBus.show_toast("Cannot equip (already has equipment)", "warning")


# ===========================================
# 네비게이션
# ===========================================

func _on_back_pressed() -> void:
	SceneManager.go_to_sector_map()
