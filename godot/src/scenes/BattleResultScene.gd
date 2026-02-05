class_name BattleResultScene
extends Control

## 전투 결과 화면
## 정거장 이름, 획득 크레딧, 시설 통계, 새 팀장/장비 표시


# ===== SIGNALS =====

signal continue_pressed()


# ===== CONSTANTS =====

const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.6, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.8, 0.7, 0.3),
	"bionic": Color(0.7, 0.3, 0.8)
}

const CLASS_ICONS: Dictionary = {
	"guardian": "🛡",
	"sentinel": "⚔",
	"ranger": "🎯",
	"engineer": "🔧",
	"bionic": "⚡"
}


# ===== CHILD NODES =====

@onready var station_name_label: Label = $VBox/Header/StationName
@onready var result_tag: Label = $VBox/Header/ResultTag
@onready var credits_label: Label = $VBox/StatsPanel/VBox/CreditsRow/Value
@onready var facilities_saved_label: Label = $VBox/StatsPanel/VBox/FacilitiesSavedRow/Value
@onready var facilities_lost_label: Label = $VBox/StatsPanel/VBox/FacilitiesLostRow/Value
@onready var enemies_killed_label: Label = $VBox/StatsPanel/VBox/EnemiesKilledRow/Value
@onready var perfect_bonus_row: HBoxContainer = $VBox/StatsPanel/VBox/PerfectBonusRow
@onready var perfect_bonus_label: Label = $VBox/StatsPanel/VBox/PerfectBonusRow/Value
@onready var rewards_container: VBoxContainer = $VBox/RewardsPanel/VBox/RewardsContent
@onready var rewards_panel: PanelContainer = $VBox/RewardsPanel
@onready var crew_status_container: HBoxContainer = $VBox/CrewPanel/CrewStatus
@onready var continue_btn: Button = $VBox/BottomBar/ContinueBtn


# ===== STATE =====

var _result_data: Dictionary = {}


# ===== LIFECYCLE =====

func _ready() -> void:
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)

	# Hide rewards panel by default
	if rewards_panel:
		rewards_panel.visible = false

	# Hide perfect bonus by default
	if perfect_bonus_row:
		perfect_bonus_row.visible = false

	# GameState에서 전투 결과 로드
	_load_result_from_game_state()


func _load_result_from_game_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return

	var result: Dictionary = {}

	# battle_result 메서드가 있으면 사용
	if game_state.has_method("get_battle_result"):
		result = game_state.get_battle_result()
	# 직접 속성 접근
	elif "battle_result" in game_state:
		result = game_state.battle_result

	if not result.is_empty():
		setup(result)


# ===== PUBLIC API =====

## 전투 결과 데이터 설정
func setup(result: Dictionary) -> void:
	_result_data = result

	_update_header()
	_update_stats()
	_give_node_type_rewards()  # 노드 타입별 보상 처리
	_update_rewards()
	_update_crew_status()


# ===== UI UPDATES =====

func _update_header() -> void:
	var station_name: String = _result_data.get("station_name", "Unknown Station")
	var is_victory: bool = _result_data.get("victory", false)

	if station_name_label:
		station_name_label.text = station_name

	if result_tag:
		if is_victory:
			result_tag.text = Localization.get_text("battle_result.victory")
			result_tag.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			result_tag.text = Localization.get_text("battle_result.defeat")
			result_tag.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _update_stats() -> void:
	var credits_earned: int = _result_data.get("credits_earned", 0)
	var facilities_saved: int = _result_data.get("facilities_saved", 0)
	var facilities_lost: int = _result_data.get("facilities_lost", 0)
	var enemies_killed: int = _result_data.get("enemies_killed", 0)
	var perfect_defense: bool = facilities_lost == 0 and _result_data.get("victory", false)

	if credits_label:
		credits_label.text = "+%d" % credits_earned
		credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	if facilities_saved_label:
		facilities_saved_label.text = str(facilities_saved)
		facilities_saved_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

	if facilities_lost_label:
		facilities_lost_label.text = str(facilities_lost)
		if facilities_lost > 0:
			facilities_lost_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			facilities_lost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	if enemies_killed_label:
		enemies_killed_label.text = str(enemies_killed)

	# Perfect defense bonus
	if perfect_bonus_row:
		perfect_bonus_row.visible = perfect_defense
	if perfect_bonus_label and perfect_defense:
		perfect_bonus_label.text = "+2"
		perfect_bonus_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.9))


func _update_rewards() -> void:
	var new_crew: Variant = _result_data.get("new_crew", null)
	var new_equipment: Variant = _result_data.get("new_equipment", null)

	var has_rewards: bool = new_crew != null or new_equipment != null

	if rewards_panel:
		rewards_panel.visible = has_rewards

	if not has_rewards or rewards_container == null:
		return

	# Clear previous rewards
	for child in rewards_container.get_children():
		child.queue_free()

	# New crew
	if new_crew != null:
		var crew_item := _create_reward_item(
			Localization.get_text("battle_result.new_crew"),
			CLASS_ICONS.get(new_crew.get("class_id", ""), "👤") + " " + new_crew.get("name", "Unknown"),
			Color(0.3, 0.9, 0.3)
		)
		rewards_container.add_child(crew_item)

	# New equipment
	if new_equipment != null:
		var equip_item := _create_reward_item(
			Localization.get_text("battle_result.new_equipment"),
			"⚙ " + new_equipment.get("name", "Unknown Item"),
			Color(0.9, 0.7, 0.2)
		)
		rewards_container.add_child(equip_item)


func _create_reward_item(title: String, description: String, color: Color) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)

	var title_label := Label.new()
	title_label.text = title + ":"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.custom_minimum_size.x = 150
	hbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", color)
	hbox.add_child(desc_label)

	return hbox


func _update_crew_status() -> void:
	if crew_status_container == null:
		return

	# Clear previous
	for child in crew_status_container.get_children():
		child.queue_free()

	var crew_results: Array = _result_data.get("crew_results", [])

	for crew in crew_results:
		var card := _create_crew_status_card(crew)
		crew_status_container.add_child(card)


func _create_crew_status_card(crew: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 120)

	var class_id: String = crew.get("class_id", "militia")
	var is_dead: bool = crew.get("is_dead", false)
	var current_hp: int = crew.get("current_hp", 0)
	var max_hp: int = crew.get("max_hp", 100)
	var squad_size: int = crew.get("current_squad_size", 0)
	var max_squad: int = crew.get("max_squad_size", 8)

	var class_color: Color = CLASS_COLORS.get(class_id, Color.WHITE)

	var stylebox := StyleBoxFlat.new()
	if is_dead:
		stylebox.bg_color = Color(0.2, 0.1, 0.1, 0.9)
		stylebox.border_color = Color(0.5, 0.2, 0.2)
	else:
		stylebox.bg_color = Color(class_color.r * 0.15, class_color.g * 0.15, class_color.b * 0.15, 0.9)
		stylebox.border_color = class_color
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Icon
	var icon := Label.new()
	icon.text = CLASS_ICONS.get(class_id, "?")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 32)
	if is_dead:
		icon.modulate = Color(0.4, 0.4, 0.4)
	else:
		icon.modulate = class_color
	vbox.add_child(icon)

	# Name
	var name_label := Label.new()
	name_label.text = crew.get("name", "Team Leader")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	if is_dead:
		name_label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(name_label)

	# Status
	var status_label := Label.new()
	if is_dead:
		status_label.text = Localization.get_text("battle_result.kia")
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		status_label.text = "%d/%d" % [squad_size, max_squad]
		if squad_size < max_squad:
			status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		else:
			status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	# HP bar (if alive)
	if not is_dead:
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(100, 8)
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		hp_bar.show_percentage = false
		vbox.add_child(hp_bar)

	return card


# ===== NODE TYPE REWARDS =====

func _give_node_type_rewards() -> void:
	## 노드 타입에 따른 추가 보상 처리
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return

	var station: Dictionary = game_state.current_station
	if station.is_empty():
		return

	var node_type: int = station.get("node_type", Constants.NodeType.BATTLE)
	var is_victory: bool = _result_data.get("victory", false)

	if not is_victory:
		return

	match node_type:
		Constants.NodeType.RESCUE, Constants.NodeType.COMMANDER:
			# 구조 미션 성공 - 새 팀장 추가
			_add_rescued_crew()
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			# 장비 미션 성공 - 장비 보상
			_add_equipment_reward()


func _add_rescued_crew() -> void:
	## 구조한 크루를 팀에 추가
	var class_options := ["guardian", "sentinel", "ranger", "engineer", "bionic"]
	var random_class: String = class_options[randi() % class_options.size()]

	var new_crew := {
		"id": "rescued_%d" % randi(),
		"name": "Rescued Survivor",
		"class_id": random_class,
		"class_rank": 1,
		"skill_level": 1,
		"current_hp": 80,
		"max_hp": 100,
		"current_squad_size": 6,
		"max_squad_size": 8,
		"equipment": [],
		"is_dead": false
	}

	_result_data["new_crew"] = new_crew

	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("add_crew"):
		game_state.add_crew(new_crew)

	print("[BattleResult] Added rescued crew: %s (%s)" % [new_crew.name, new_crew.class_id])


func _add_equipment_reward() -> void:
	## 장비 보상 추가
	var equipment_options := [
		{"id": "shield_booster", "name": "Shield Booster", "type": "passive"},
		{"id": "rapid_reload", "name": "Rapid Reload", "type": "passive"},
		{"id": "medkit", "name": "Emergency Medkit", "type": "active"},
		{"id": "grenade", "name": "Frag Grenade", "type": "active"}
	]

	var random_equip: Dictionary = equipment_options[randi() % equipment_options.size()]

	_result_data["new_equipment"] = random_equip

	# TODO: GameState에 장비 추가 로직

	print("[BattleResult] Added equipment reward: %s" % random_equip.name)


# ===== HANDLERS =====

func _on_continue_pressed() -> void:
	continue_pressed.emit()

	# 섹터맵으로 이동
	var sector_map_scenes := [
		"res://scenes/campaign/SectorMap3D.tscn",
		"res://src/scenes/SectorMap3DScene.tscn"
	]

	for path in sector_map_scenes:
		if ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)
			return

	# 섹터맵 없으면 메인 메뉴로
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
