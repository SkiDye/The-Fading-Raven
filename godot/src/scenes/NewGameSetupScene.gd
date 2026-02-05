class_name NewGameSetupScene
extends Control

## 새 게임 설정 화면
## 난이도 선택 + 시작 팀장 2명 선택


# ===== SIGNALS =====

signal game_started(seed_value: int, difficulty: int, starting_crews: Array)
signal back_pressed()


# ===== CONSTANTS =====

const STARTING_CREW_COUNT: int = 2
const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.6, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.8, 0.7, 0.3),
	"bionic": Color(0.7, 0.3, 0.8),
	"militia": Color(0.5, 0.5, 0.5)
}

const CLASS_NAMES: Dictionary = {
	"guardian": "Guardian",
	"sentinel": "Sentinel",
	"ranger": "Ranger",
	"engineer": "Engineer",
	"bionic": "Bionic"
}

const CLASS_ICONS: Dictionary = {
	"guardian": "🛡",
	"sentinel": "⚔",
	"ranger": "🎯",
	"engineer": "🔧",
	"bionic": "⚡"
}

const CLASS_DESCRIPTIONS: Dictionary = {
	"guardian": "Heavy shields, defensive formation\nSkill: Shield Bash",
	"sentinel": "Lance charge, high damage\nSkill: Lance Charge",
	"ranger": "Ranged attacks\nSkill: Volley Fire",
	"engineer": "Deploys turrets\nSkill: Deploy Turret",
	"bionic": "Fast, assassination bonus\nSkill: Blink"
}


# ===== CHILD NODES =====

@onready var difficulty_container: HBoxContainer = $VBox/DifficultyPanel/HBox/DifficultyOptions
@onready var class_container: GridContainer = $VBox/ClassPanel/ScrollContainer/ClassGrid
@onready var selected_container: HBoxContainer = $VBox/SelectedPanel/SelectedCrews
@onready var start_btn: Button = $VBox/BottomBar/StartBtn
@onready var back_btn: Button = $VBox/BottomBar/BackBtn
@onready var seed_input: LineEdit = $VBox/SeedPanel/HBox/SeedInput
@onready var random_seed_btn: Button = $VBox/SeedPanel/HBox/RandomBtn


# ===== STATE =====

var _selected_difficulty: int = Constants.Difficulty.NORMAL
var _selected_classes: Array = []  # Array of class_id strings
var _difficulty_buttons: Dictionary = {}  # difficulty -> button
var _class_cards: Dictionary = {}  # class_id -> card


# ===== LIFECYCLE =====

func _ready() -> void:
	_connect_signals()
	_setup_difficulty_options()
	_setup_class_options()
	_setup_selected_slots()
	_generate_random_seed()
	_update_ui()


func _connect_signals() -> void:
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if random_seed_btn:
		random_seed_btn.pressed.connect(_generate_random_seed)


# ===== DIFFICULTY SETUP =====

func _setup_difficulty_options() -> void:
	if difficulty_container == null:
		return

	for child in difficulty_container.get_children():
		child.queue_free()

	_difficulty_buttons.clear()

	var difficulties := [
		Constants.Difficulty.NORMAL,
		Constants.Difficulty.HARD,
		Constants.Difficulty.VERY_HARD,
		Constants.Difficulty.NIGHTMARE
	]

	for diff in difficulties:
		var is_unlocked: bool = GameState.is_difficulty_unlocked(diff)
		var btn := _create_difficulty_button(diff, is_unlocked)
		difficulty_container.add_child(btn)
		_difficulty_buttons[diff] = btn


func _create_difficulty_button(difficulty: int, is_unlocked: bool) -> Button:
	var btn := Button.new()
	var diff_name := Constants.get_difficulty_name_ko(difficulty)
	var diff_color := Constants.get_difficulty_color(difficulty)

	btn.text = diff_name
	btn.custom_minimum_size = Vector2(120, 50)
	btn.disabled = not is_unlocked
	btn.toggle_mode = true
	btn.button_pressed = (difficulty == _selected_difficulty)

	if is_unlocked:
		btn.add_theme_color_override("font_color", diff_color)
		btn.add_theme_color_override("font_hover_color", diff_color)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		btn.text = diff_name + " 🔒"
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	btn.pressed.connect(func(): _select_difficulty(difficulty))

	return btn


func _select_difficulty(difficulty: int) -> void:
	if not GameState.is_difficulty_unlocked(difficulty):
		return

	_selected_difficulty = difficulty

	# Update button states
	for diff in _difficulty_buttons:
		var btn: Button = _difficulty_buttons[diff]
		btn.button_pressed = (diff == difficulty)

	_update_ui()


# ===== CLASS SETUP =====

func _setup_class_options() -> void:
	if class_container == null:
		return

	for child in class_container.get_children():
		child.queue_free()

	_class_cards.clear()

	var all_classes := ["guardian", "sentinel", "ranger", "engineer", "bionic"]

	for class_id in all_classes:
		var is_unlocked: bool = GameState.is_class_unlocked(class_id)
		var card := _create_class_card(class_id, is_unlocked)
		class_container.add_child(card)
		_class_cards[class_id] = card


func _create_class_card(class_id: String, is_unlocked: bool) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_" + class_id
	card.custom_minimum_size = Vector2(160, 180)

	var class_color: Color = CLASS_COLORS.get(class_id, Color.WHITE)

	var stylebox := StyleBoxFlat.new()
	if is_unlocked:
		stylebox.bg_color = Color(class_color.r * 0.15, class_color.g * 0.15, class_color.b * 0.15, 0.95)
		stylebox.border_color = class_color
	else:
		stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		stylebox.border_color = Color(0.3, 0.3, 0.3)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", stylebox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Icon
	var icon_label := Label.new()
	icon_label.text = CLASS_ICONS.get(class_id, "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	if is_unlocked:
		icon_label.modulate = class_color
	else:
		icon_label.modulate = Color(0.4, 0.4, 0.4)
	vbox.add_child(icon_label)

	# Name
	var name_label := Label.new()
	if is_unlocked:
		name_label.text = CLASS_NAMES.get(class_id, class_id)
	else:
		name_label.text = "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	if is_unlocked:
		desc_label.text = CLASS_DESCRIPTIONS.get(class_id, "")
	else:
		desc_label.text = "Locked"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	if is_unlocked:
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_on_class_card_clicked(class_id)
		)

	return card


func _on_class_card_clicked(class_id: String) -> void:
	# Toggle selection
	if class_id in _selected_classes:
		_selected_classes.erase(class_id)
	elif _selected_classes.size() < STARTING_CREW_COUNT:
		_selected_classes.append(class_id)

	_update_selected_slots()
	_update_class_card_states()
	_update_ui()


func _update_class_card_states() -> void:
	for class_id in _class_cards:
		var card: Control = _class_cards[class_id]
		var is_selected: bool = class_id in _selected_classes
		var is_unlocked: bool = GameState.is_class_unlocked(class_id)

		if not is_unlocked:
			card.modulate = Color(0.5, 0.5, 0.5)
		elif is_selected:
			card.modulate = Color(1.2, 1.2, 1.2)  # Brighter
		else:
			card.modulate = Color.WHITE


# ===== SELECTED SLOTS =====

func _setup_selected_slots() -> void:
	if selected_container == null:
		return

	for child in selected_container.get_children():
		child.queue_free()

	for i in range(STARTING_CREW_COUNT):
		var slot := _create_empty_slot(i)
		selected_container.add_child(slot)


func _create_empty_slot(index: int) -> Control:
	var slot := PanelContainer.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(120, 140)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	stylebox.border_color = Color(0.3, 0.3, 0.4)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	var label := Label.new()
	label.text = "Team %d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(label)

	var empty_label := Label.new()
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 40)
	empty_label.modulate = Color(0.4, 0.4, 0.5)
	vbox.add_child(empty_label)

	return slot


func _update_selected_slots() -> void:
	if selected_container == null:
		return

	var slots := selected_container.get_children()

	for i in range(STARTING_CREW_COUNT):
		if i >= slots.size():
			continue

		var slot: Control = slots[i]
		var content: VBoxContainer = slot.get_node_or_null("Content")
		if content == null:
			continue

		for child in content.get_children():
			child.queue_free()

		if i < _selected_classes.size():
			var class_id: String = _selected_classes[i]
			_fill_selected_slot(content, class_id, i)
		else:
			_fill_empty_slot(content, i)


func _fill_selected_slot(content: VBoxContainer, class_id: String, index: int) -> void:
	var class_color: Color = CLASS_COLORS.get(class_id, Color.WHITE)

	var label := Label.new()
	label.text = "Team %d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.6, 0.6, 0.6)
	content.add_child(label)

	var icon := Label.new()
	icon.text = CLASS_ICONS.get(class_id, "?")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 36)
	icon.modulate = class_color
	content.add_child(icon)

	var name_label := Label.new()
	name_label.text = CLASS_NAMES.get(class_id, class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	content.add_child(name_label)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.pressed.connect(func(): _remove_class(index))
	content.add_child(remove_btn)


func _fill_empty_slot(content: VBoxContainer, index: int) -> void:
	var label := Label.new()
	label.text = "Team %d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.5, 0.5, 0.5)
	content.add_child(label)

	var empty_label := Label.new()
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 40)
	empty_label.modulate = Color(0.4, 0.4, 0.5)
	content.add_child(empty_label)


func _remove_class(index: int) -> void:
	if index < 0 or index >= _selected_classes.size():
		return

	_selected_classes.remove_at(index)
	_update_selected_slots()
	_update_class_card_states()
	_update_ui()


# ===== SEED =====

func _generate_random_seed() -> void:
	var new_seed := randi()
	if seed_input:
		seed_input.text = str(new_seed)


func _get_seed_value() -> int:
	if seed_input and seed_input.text.is_valid_int():
		return int(seed_input.text)
	return randi()


# ===== UI UPDATE =====

func _update_ui() -> void:
	if start_btn:
		start_btn.disabled = _selected_classes.size() < STARTING_CREW_COUNT


# ===== HANDLERS =====

func _on_start_pressed() -> void:
	if _selected_classes.size() < STARTING_CREW_COUNT:
		return

	var seed_value := _get_seed_value()
	var starting_crews := _create_starting_crews()

	# Start new run
	GameState.start_new_run(seed_value, _selected_difficulty)

	# Add starting crews
	for crew in starting_crews:
		GameState.add_crew(crew)

	game_started.emit(seed_value, _selected_difficulty, starting_crews)

	# 섹터맵으로 전환
	var sector_map := "res://scenes/campaign/SectorMap3D.tscn"
	if ResourceLoader.exists(sector_map):
		get_tree().change_scene_to_file(sector_map)
	else:
		push_warning("NewGameSetup: SectorMap3D scene not found")


func _on_back_pressed() -> void:
	back_pressed.emit()

	# 메인 메뉴로 복귀
	var main_menu := "res://src/ui/menus/MainMenu.tscn"
	if ResourceLoader.exists(main_menu):
		get_tree().change_scene_to_file(main_menu)
	else:
		push_warning("NewGameSetup: MainMenu scene not found")


func _create_starting_crews() -> Array:
	var crews: Array = []
	var crew_id := 1

	for class_id in _selected_classes:
		var crew := {
			"id": "crew_%d" % crew_id,
			"name": "Team Leader %d" % crew_id,
			"class_id": class_id,
			"class_rank": 1,  # Standard
			"skill_level": 1,
			"max_hp": 100,
			"current_hp": 100,
			"max_squad_size": Constants.BALANCE.squad_size.get(class_id, 8),
			"current_squad_size": Constants.BALANCE.squad_size.get(class_id, 8),
			"equipment_id": "",
			"trait_ids": [],
			"is_dead": false,
			"kills": 0,
			"missions_completed": 0
		}
		crews.append(crew)
		crew_id += 1

	return crews
