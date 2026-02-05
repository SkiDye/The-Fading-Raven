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


# ===== PUBLIC API =====

## 전투 결과 데이터 설정
func setup(result: Dictionary) -> void:
	_result_data = result

	_update_header()
	_update_stats()
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
			result_tag.text = "VICTORY"
			result_tag.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			result_tag.text = "DEFEAT"
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
			"New Team Leader",
			CLASS_ICONS.get(new_crew.get("class_id", ""), "👤") + " " + new_crew.get("name", "Unknown"),
			Color(0.3, 0.9, 0.3)
		)
		rewards_container.add_child(crew_item)

	# New equipment
	if new_equipment != null:
		var equip_item := _create_reward_item(
			"Equipment Found",
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
		status_label.text = "KIA"
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


# ===== HANDLERS =====

func _on_continue_pressed() -> void:
	continue_pressed.emit()
