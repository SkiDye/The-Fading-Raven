class_name UpgradeScreen
extends Control

## Bad North 스타일 업그레이드 화면
## 팀장 목록, 클래스 선택, 등급/스킬 업그레이드, 장비 관리


signal upgrade_completed()
signal back_requested()


# ===== 노드 참조 =====

# 상단바
@onready var _credits_label: Label = $TopBar/HBox/CreditsContainer/CreditsLabel
@onready var _back_btn: Button = $TopBar/HBox/BackBtn

# 좌측 패널 - 팀장 목록
@onready var _crew_list: VBoxContainer = $MainContent/LeftPanel/VBox/ScrollContainer/CrewList

# 우측 패널 - 상세 정보
@onready var _right_panel: PanelContainer = $MainContent/RightPanel
@onready var _no_selection_panel: PanelContainer = $MainContent/NoSelectionPanel

# 헤더 섹션
@onready var _portrait: ColorRect = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/PortraitContainer/Portrait
@onready var _class_icon: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/PortraitContainer/ClassIcon
@onready var _crew_name_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/InfoVBox/CrewNameLabel
@onready var _class_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/InfoVBox/ClassLabel
@onready var _rank_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/InfoVBox/RankLabel
@onready var _trait_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/InfoVBox/TraitLabel
@onready var _stats_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HeaderSection/InfoVBox/StatsLabel

# 클래스 선택 섹션
@onready var _class_selection_section: VBoxContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/ClassSelectionSection
@onready var _class_grid: GridContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/ClassSelectionSection/ClassGrid

# 등급 업그레이드 섹션
@onready var _rank_upgrade_section: VBoxContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/RankUpgradeSection
@onready var _current_rank_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/RankUpgradeSection/RankInfo/CurrentRank/RankName
@onready var _next_rank_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/RankUpgradeSection/RankInfo/NextRank/RankName
@onready var _upgrade_rank_btn: Button = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/RankUpgradeSection/UpgradeRankBtn

# 스킬 섹션
@onready var _skill_section: VBoxContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/SkillSection
@onready var _skill_name_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/SkillSection/SkillInfo/SkillDetails/SkillName
@onready var _skill_desc_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/SkillSection/SkillInfo/SkillDetails/SkillDesc
@onready var _skill_level_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/SkillSection/SkillInfo/LevelContainer/LevelValue
@onready var _upgrade_skill_btn: Button = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/SkillSection/UpgradeSkillBtn

# 체력 섹션
@onready var _health_section: VBoxContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HealthSection
@onready var _health_bar: ProgressBar = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HealthSection/HealthInfo/HealthDetails/HealthBar
@onready var _health_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HealthSection/HealthInfo/HealthDetails/HealthLabel
@onready var _heal_btn: Button = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/HealthSection/HealBtn

# 장비 섹션
@onready var _equipment_section: VBoxContainer = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/EquipmentSection
@onready var _equip_icon: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/EquipmentSection/EquipmentSlot/HBox/Margin/EquipIcon
@onready var _equip_name_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/EquipmentSection/EquipmentSlot/HBox/EquipInfo/EquipName
@onready var _equip_desc_label: Label = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/EquipmentSection/EquipmentSlot/HBox/EquipInfo/EquipDesc
@onready var _change_equip_btn: Button = $MainContent/RightPanel/ScrollContainer/ContentMargin/VBox/EquipmentSection/ChangeEquipBtn


# ===== 상수 =====

const CLASS_COLORS: Dictionary = {
	"militia": Color(0.5, 0.5, 0.5),
	"guardian": Color(0.3, 0.5, 0.8),
	"sentinel": Color(0.8, 0.3, 0.3),
	"ranger": Color(0.3, 0.7, 0.4),
	"engineer": Color(0.8, 0.6, 0.2),
	"bionic": Color(0.6, 0.3, 0.8)
}

const CLASS_ICONS: Dictionary = {
	"militia": "?",
	"guardian": "O",  # Shield
	"sentinel": "/",  # Lance
	"ranger": "+",    # Crosshair
	"engineer": "#",  # Gear
	"bionic": "X"     # Blade
}

const RANK_NAMES: Array = ["", "Standard", "Veteran", "Elite"]
const CLASS_SELECT_COST: int = 6
const HEAL_COST_PER_HP: int = 1


# ===== 상태 =====

var _selected_crew: Dictionary = {}
var _crews: Array = []
var _preselect_crew_id: String = ""


# ===== 초기화 =====

func _ready() -> void:
	_connect_signals()
	_show_no_selection()
	# 자동으로 크루 로드 (씬 전환 후)
	call_deferred("_auto_load_crews")


func _connect_signals() -> void:
	if _back_btn:
		_back_btn.pressed.connect(_on_back_pressed)
	if _upgrade_rank_btn:
		_upgrade_rank_btn.pressed.connect(_on_upgrade_rank_pressed)
	if _upgrade_skill_btn:
		_upgrade_skill_btn.pressed.connect(_on_upgrade_skill_pressed)
	if _heal_btn:
		_heal_btn.pressed.connect(_on_heal_pressed)
	if _change_equip_btn:
		_change_equip_btn.pressed.connect(_on_change_equip_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


## 자동 크루 로드 (씬 전환 후)
func _auto_load_crews() -> void:
	if not _crews.is_empty():
		return  # 이미 설정됨

	if GameState and GameState.has_method("get_crews"):
		var crews: Array = GameState.get_crews()
		if crews.size() > 0:
			setup(crews)
		else:
			# 테스트 크루 생성
			_create_test_crews()


func _create_test_crews() -> void:
	var test_crews := [
		{
			"id": "crew_1",
			"class_id": "militia",
			"class_rank": 0,
			"skill_level": 0,
			"current_hp": 8,
			"equipment_id": "",
			"trait_id": "",
			"kills": 0,
			"losses": 0
		},
		{
			"id": "crew_2",
			"class_id": "militia",
			"class_rank": 0,
			"skill_level": 0,
			"current_hp": 8,
			"equipment_id": "",
			"trait_id": "",
			"kills": 0,
			"losses": 0
		}
	]

	for crew in test_crews:
		if GameState:
			GameState.add_crew(crew)

	setup(test_crews)


## 크루 목록 설정
func setup(crews: Array, preselect_id: String = "") -> void:
	_crews = crews
	_preselect_crew_id = preselect_id
	_refresh_crew_list()
	_update_credits()

	# 사전 선택된 크루가 있으면 선택
	if preselect_id != "":
		for crew in _crews:
			if crew.get("id", "") == preselect_id:
				_on_crew_selected(crew)
				return

	_show_no_selection()


# ===== 크루 목록 =====

func _refresh_crew_list() -> void:
	if _crew_list == null:
		return

	# 기존 항목 제거
	for child in _crew_list.get_children():
		child.queue_free()

	# 크루 카드 생성
	for crew in _crews:
		var card := _create_crew_card(crew)
		_crew_list.add_child(card)


func _create_crew_card(crew: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)

	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	# 초상화 (색상 원)
	var portrait_container := PanelContainer.new()
	portrait_container.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(portrait_container)

	var portrait := ColorRect.new()
	portrait.color = _get_class_color(crew.get("class_id", "militia"))
	portrait_container.add_child(portrait)

	var icon := Label.new()
	icon.text = _get_class_icon(crew.get("class_id", "militia"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 24)
	portrait_container.add_child(icon)

	# 정보
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	info_vbox.add_child(margin)

	var info_inner := VBoxContainer.new()
	margin.add_child(info_inner)

	# 이름
	var name_label := Label.new()
	name_label.text = _get_display_name(crew)
	name_label.add_theme_font_size_override("font_size", 16)
	info_inner.add_child(name_label)

	# 체력
	var health_label := Label.new()
	var current_hp: int = crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(crew)
	health_label.text = "%d / %d" % [current_hp, max_hp]
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_inner.add_child(health_label)

	# 클릭 이벤트
	var btn := Button.new()
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_crew_selected.bind(crew))
	card.add_child(btn)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return card


# ===== 상세 패널 =====

func _show_no_selection() -> void:
	_right_panel.visible = false
	_no_selection_panel.visible = true
	_selected_crew = {}


func _show_detail_panel() -> void:
	_right_panel.visible = true
	_no_selection_panel.visible = false


func _update_detail_panel() -> void:
	if _selected_crew.is_empty():
		_show_no_selection()
		return

	_show_detail_panel()

	var class_id: String = _selected_crew.get("class_id", "militia")
	var class_rank: int = _selected_crew.get("class_rank", 1)
	var is_militia: bool = class_id == "militia" or class_id == ""

	# 헤더 업데이트
	_update_header_section(class_id, class_rank)

	# 클래스 선택 (Militia일 때만)
	_class_selection_section.visible = is_militia
	if is_militia:
		_populate_class_selection()

	# 등급 업그레이드 (클래스 선택 후)
	_rank_upgrade_section.visible = not is_militia and class_rank < 3
	if not is_militia:
		_update_rank_upgrade_section(class_rank)

	# 스킬 섹션
	_skill_section.visible = not is_militia
	if not is_militia:
		_update_skill_section()

	# 체력 섹션
	_update_health_section()

	# 장비 섹션
	_update_equipment_section()


func _update_header_section(class_id: String, class_rank: int) -> void:
	# 초상화 색상
	if _portrait:
		_portrait.color = _get_class_color(class_id)

	# 클래스 아이콘
	if _class_icon:
		_class_icon.text = _get_class_icon(class_id)

	# 이름
	if _crew_name_label:
		_crew_name_label.text = _get_display_name(_selected_crew)

	# 클래스
	if _class_label:
		if class_id == "militia" or class_id == "":
			_class_label.text = "Militia"
		else:
			_class_label.text = class_id.capitalize()

	# 등급
	if _rank_label:
		if class_id == "militia" or class_id == "":
			_rank_label.text = "Untrained"
		else:
			_rank_label.text = RANK_NAMES[class_rank] if class_rank < RANK_NAMES.size() else "Elite"

	# 특성
	if _trait_label:
		var trait_id: String = _selected_crew.get("trait_id", "")
		if trait_id != "":
			var trait_data = Constants.get_trait(trait_id)
			if trait_data and "display_name" in trait_data:
				_trait_label.text = trait_data.display_name
			else:
				_trait_label.text = trait_id.capitalize()
		else:
			_trait_label.text = ""

	# 통계
	if _stats_label:
		var kills: int = _selected_crew.get("kills", 0)
		var losses: int = _selected_crew.get("losses", 0)
		_stats_label.text = "Kills: %d | Losses: %d" % [kills, losses]


func _populate_class_selection() -> void:
	if _class_grid == null:
		return

	# 기존 버튼 제거
	for child in _class_grid.get_children():
		child.queue_free()

	# 클래스 버튼 생성
	var classes := ["guardian", "sentinel", "ranger", "engineer", "bionic"]

	for class_id in classes:
		var btn := _create_class_button(class_id)
		_class_grid.add_child(btn)


func _create_class_button(class_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 14)

	# 해금 여부 확인
	var is_unlocked: bool = GameState.is_class_unlocked(class_id)

	if is_unlocked:
		btn.text = "%s  [%s]\n%d Credits" % [class_id.capitalize(), _get_class_icon(class_id), CLASS_SELECT_COST]
		btn.disabled = not _can_afford(CLASS_SELECT_COST)
		btn.pressed.connect(_on_class_selected.bind(class_id))
	else:
		btn.text = "%s\n[LOCKED]" % class_id.capitalize()
		btn.disabled = true

	return btn


func _update_rank_upgrade_section(current_rank: int) -> void:
	# 현재 등급
	if _current_rank_label:
		_current_rank_label.text = RANK_NAMES[current_rank] if current_rank < RANK_NAMES.size() else "Elite"

	# 다음 등급
	var next_rank: int = current_rank + 1
	if _next_rank_label:
		if next_rank < RANK_NAMES.size():
			_next_rank_label.text = RANK_NAMES[next_rank]
		else:
			_next_rank_label.text = "MAX"

	# 업그레이드 버튼
	if _upgrade_rank_btn:
		if next_rank >= RANK_NAMES.size():
			_upgrade_rank_btn.text = "MAX RANK"
			_upgrade_rank_btn.disabled = true
		else:
			var cost: int = _get_rank_upgrade_cost(current_rank)
			_upgrade_rank_btn.text = "UPGRADE - %d Credits" % cost
			_upgrade_rank_btn.disabled = not _can_afford(cost)


func _update_skill_section() -> void:
	var class_id: String = _selected_crew.get("class_id", "")
	var skill_level: int = _selected_crew.get("skill_level", 1)
	var class_data = Constants.get_crew_class(class_id) if class_id else null

	# 스킬 이름
	if _skill_name_label:
		if class_data and "skill_id" in class_data:
			_skill_name_label.text = class_data.skill_id.replace("_", " ").capitalize()
		else:
			_skill_name_label.text = "Skill"

	# 스킬 설명
	if _skill_desc_label:
		_skill_desc_label.text = _get_skill_description(class_id, skill_level)

	# 스킬 레벨
	if _skill_level_label:
		_skill_level_label.text = "%d/3" % skill_level

	# 업그레이드 버튼
	if _upgrade_skill_btn:
		if skill_level >= 3:
			_upgrade_skill_btn.text = "MAX LEVEL"
			_upgrade_skill_btn.disabled = true
		else:
			var cost: int = _get_skill_upgrade_cost(skill_level)
			_upgrade_skill_btn.text = "UPGRADE - %d Credits" % cost
			_upgrade_skill_btn.disabled = not _can_afford(cost)


func _update_health_section() -> void:
	var current_hp: int = _selected_crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(_selected_crew)
	var missing: int = max_hp - current_hp

	# 체력바
	if _health_bar:
		_health_bar.max_value = max_hp
		_health_bar.value = current_hp

	# 체력 텍스트
	if _health_label:
		_health_label.text = "%d / %d members" % [current_hp, max_hp]

	# 힐 버튼
	if _heal_btn:
		if missing <= 0:
			_heal_btn.text = "FULL STRENGTH"
			_heal_btn.disabled = true
		else:
			var cost: int = missing * HEAL_COST_PER_HP
			_heal_btn.text = "HEAL +%d - %d Credits" % [missing, cost]
			_heal_btn.disabled = not _can_afford(cost)


func _update_equipment_section() -> void:
	var equipment_id: String = _selected_crew.get("equipment_id", "")

	if equipment_id == "":
		if _equip_icon:
			_equip_icon.text = "[ ]"
		if _equip_name_label:
			_equip_name_label.text = "Empty Slot"
		if _equip_desc_label:
			_equip_desc_label.text = "No equipment equipped"
	else:
		var equipment_data = Constants.get_equipment(equipment_id)
		if equipment_data:
			if _equip_icon:
				_equip_icon.text = "[*]"
			if _equip_name_label:
				if "display_name" in equipment_data:
					_equip_name_label.text = equipment_data.display_name
				else:
					_equip_name_label.text = equipment_id.capitalize()
			if _equip_desc_label:
				if "description" in equipment_data:
					_equip_desc_label.text = equipment_data.description
				else:
					_equip_desc_label.text = ""


# ===== 헬퍼 함수 =====

func _get_display_name(crew: Dictionary) -> String:
	var class_id: String = crew.get("class_id", "")
	if class_id == "" or class_id == "militia":
		return "Militia"

	var class_data = Constants.get_crew_class(class_id)
	if class_data and "display_name" in class_data:
		return class_data.display_name
	return class_id.capitalize()


func _get_class_color(class_id: String) -> Color:
	if CLASS_COLORS.has(class_id):
		return CLASS_COLORS[class_id]
	return CLASS_COLORS["militia"]


func _get_class_icon(class_id: String) -> String:
	if CLASS_ICONS.has(class_id):
		return CLASS_ICONS[class_id]
	return "?"


func _get_max_squad_size(crew: Dictionary) -> int:
	var class_id: String = crew.get("class_id", "")
	if class_id == "" or class_id == "militia":
		return 8
	return Constants.BALANCE.squad_size.get(class_id, 8)


func _get_skill_description(class_id: String, level: int) -> String:
	match class_id:
		"guardian":
			return "Shield Bash - Stun enemies"
		"sentinel":
			return "Lance Charge - Powerful thrust"
		"ranger":
			return "Volley Fire - Ranged barrage"
		"engineer":
			return "Deploy Turret - Automated defense"
		"bionic":
			return "Blink - Teleport strike"
	return "Unknown skill"


func _get_rank_upgrade_cost(current_rank: int) -> int:
	var costs: Array = Constants.BALANCE.upgrade_costs.class_rank
	var cost_index: int = current_rank - 1
	if cost_index >= 0 and cost_index < costs.size():
		return costs[cost_index]
	return 999


func _get_skill_upgrade_cost(current_level: int) -> int:
	var costs: Array = Constants.BALANCE.upgrade_costs.skill_level
	var cost_index: int = current_level - 1
	if cost_index >= 0 and cost_index < costs.size():
		return costs[cost_index]
	return 999


func _can_afford(cost: int) -> bool:
	return GameState.get_credits() >= cost


func _update_credits() -> void:
	if _credits_label:
		_credits_label.text = str(GameState.get_credits())


# ===== 시그널 핸들러 =====

func _on_crew_selected(crew: Dictionary) -> void:
	_selected_crew = crew
	_update_detail_panel()


func _on_class_selected(class_id: String) -> void:
	if _selected_crew.is_empty():
		return

	if not _can_afford(CLASS_SELECT_COST):
		return

	if GameState.spend_credits(CLASS_SELECT_COST):
		_selected_crew.class_id = class_id
		_selected_crew.class_rank = 1
		_selected_crew.skill_level = 1

		# 분대 크기 조정
		var new_max: int = _get_max_squad_size(_selected_crew)
		if _selected_crew.get("current_hp", 0) > new_max:
			_selected_crew.current_hp = new_max

		_update_credits()
		_update_detail_panel()
		_refresh_crew_list()


func _on_upgrade_rank_pressed() -> void:
	if _selected_crew.is_empty():
		return

	var current_rank: int = _selected_crew.get("class_rank", 1)
	if current_rank >= 3:
		return

	var cost: int = _get_rank_upgrade_cost(current_rank)

	if GameState.spend_credits(cost):
		_selected_crew.class_rank = current_rank + 1
		_update_credits()
		_update_detail_panel()
		_refresh_crew_list()


func _on_upgrade_skill_pressed() -> void:
	if _selected_crew.is_empty():
		return

	var skill_level: int = _selected_crew.get("skill_level", 1)
	if skill_level >= 3:
		return

	var cost: int = _get_skill_upgrade_cost(skill_level)

	if GameState.spend_credits(cost):
		_selected_crew.skill_level = skill_level + 1
		_update_credits()
		_update_detail_panel()


func _on_heal_pressed() -> void:
	if _selected_crew.is_empty():
		return

	var current_hp: int = _selected_crew.get("current_hp", 0)
	var max_hp: int = _get_max_squad_size(_selected_crew)
	var missing: int = max_hp - current_hp

	if missing <= 0:
		return

	var cost: int = missing * HEAL_COST_PER_HP

	if GameState.spend_credits(cost):
		_selected_crew.current_hp = max_hp
		_update_credits()
		_update_detail_panel()
		_refresh_crew_list()


func _on_change_equip_pressed() -> void:
	# TODO: 장비 선택 모달 표시
	print("[UpgradeScreen] Change equipment - TODO")


func _on_back_pressed() -> void:
	upgrade_completed.emit()
	back_requested.emit()

	# Campaign3D로 복귀
	var campaign_scene := "res://scenes/campaign/Campaign3D.tscn"
	if ResourceLoader.exists(campaign_scene):
		get_tree().change_scene_to_file(campaign_scene)
	else:
		# 폴백: 2D 섹터맵
		var sector_scene := "res://scenes/campaign/Campaign.tscn"
		if ResourceLoader.exists(sector_scene):
			get_tree().change_scene_to_file(sector_scene)
