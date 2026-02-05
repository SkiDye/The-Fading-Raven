class_name SquadSelectionScene
extends Control

## 분대 선택 씬
## "SELECT YOUR SQUADS" 화면 - 전투에 참여할 최대 4팀 선택

# ===== SIGNALS =====

signal deploy_pressed(selected_squads: Array)
signal back_pressed()


# ===== CONSTANTS =====

const MAX_SQUADS: int = 4
const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.6, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.8, 0.7, 0.3),
	"bionic": Color(0.7, 0.3, 0.8),
	"militia": Color(0.5, 0.5, 0.5)
}


# ===== CHILD NODES =====

@onready var title_label: Label = $VBox/Title
@onready var selected_container: HBoxContainer = $VBox/SelectedPanel/SelectedTeams
@onready var available_container: GridContainer = $VBox/AvailablePanel/ScrollContainer/AvailableTeams
@onready var deploy_btn: Button = $VBox/BottomBar/DeployBtn
@onready var back_btn: Button = $VBox/BottomBar/BackBtn
@onready var count_label: Label = $VBox/BottomBar/CountLabel


# ===== STATE =====

var _available_squads: Array = []  # All available squad data
var _selected_squads: Array = []   # Selected squad data (max 4)
var _selected_slots: Array = []    # UI slot references
var _available_cards: Dictionary = {}  # squad_id -> card node


# ===== LIFECYCLE =====

func _ready() -> void:
	_connect_signals()
	_setup_slots()
	_load_squads_from_gamestate()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 1-4 키로 선택/해제
		var key_index: int = -1
		match event.keycode:
			KEY_1: key_index = 0
			KEY_2: key_index = 1
			KEY_3: key_index = 2
			KEY_4: key_index = 3

		if key_index >= 0 and key_index < _selected_squads.size():
			_remove_squad(key_index)


func _connect_signals() -> void:
	if deploy_btn:
		deploy_btn.pressed.connect(_on_deploy_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)


func _setup_slots() -> void:
	# 선택 슬롯 4개 초기화
	if selected_container == null:
		return

	for child in selected_container.get_children():
		child.queue_free()

	_selected_slots.clear()

	for i in range(MAX_SQUADS):
		var slot := _create_empty_slot(i)
		selected_container.add_child(slot)
		_selected_slots.append(slot)


## GameState에서 분대 데이터 로드
func _load_squads_from_gamestate() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		push_warning("[SquadSelection] GameState not found!")
		return

	var squads: Array = game_state.get_crews()
	print("[SquadSelection] Loaded %d squads from GameState" % squads.size())

	if squads.is_empty():
		push_warning("[SquadSelection] No crews in GameState - is run active? %s" % game_state.is_run_active())
		return

	setup(squads)


# ===== PUBLIC API =====

## 사용 가능한 분대 설정
func setup(squads: Array) -> void:
	_available_squads = squads.duplicate()
	_selected_squads.clear()

	_rebuild_available_cards()
	_update_slots()
	_update_ui()


## 특정 분대를 미리 선택 상태로 설정
func preselect(squad_ids: Array) -> void:
	for squad_id in squad_ids:
		for squad in _available_squads:
			var id: String = _get_squad_id(squad)
			if id == squad_id and _selected_squads.size() < MAX_SQUADS:
				_selected_squads.append(squad)
				break

	_update_slots()
	_update_ui()


# ===== UI BUILDING =====

func _rebuild_available_cards() -> void:
	if available_container == null:
		return

	for child in available_container.get_children():
		child.queue_free()

	_available_cards.clear()

	for squad in _available_squads:
		var card := _create_squad_card(squad)
		available_container.add_child(card)
		_available_cards[_get_squad_id(squad)] = card


func _create_empty_slot(index: int) -> Control:
	var slot := PanelContainer.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(140, 160)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	stylebox.border_color = Color(0.3, 0.3, 0.4)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# 빈 슬롯 표시
	var empty_label := Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "[%d]" % (index + 1)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 32)
	empty_label.modulate = Color(0.4, 0.4, 0.5)
	vbox.add_child(empty_label)

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Empty"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.modulate = Color(0.4, 0.4, 0.5)
	vbox.add_child(hint_label)

	return slot


func _create_squad_card(squad: Variant) -> Control:
	var card := PanelContainer.new()
	var squad_id := _get_squad_id(squad)
	var class_id := _get_class_id(squad)
	card.name = "Card_" + squad_id
	card.custom_minimum_size = Vector2(120, 140)

	var class_color: Color = CLASS_COLORS.get(class_id, Color.WHITE)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(class_color.r * 0.2, class_color.g * 0.2, class_color.b * 0.2, 0.9)
	stylebox.border_color = class_color
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# 클래스 아이콘 (대체: 텍스트)
	var icon_label := Label.new()
	icon_label.text = _get_class_icon(class_id)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.modulate = class_color
	vbox.add_child(icon_label)

	# 클래스 이름
	var name_label := Label.new()
	name_label.text = class_id.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# 체력 바
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(100, 10)
	hp_bar.value = _get_health_percent(squad)
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	# 랭크/레벨
	var rank: int = _get_rank(squad)
	var rank_label := Label.new()
	rank_label.text = _get_rank_name(rank)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 10)
	rank_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(rank_label)

	# 클릭 이벤트
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_squad_card_clicked(squad)
	)

	return card


func _update_slots() -> void:
	for i in range(MAX_SQUADS):
		var slot: Control = _selected_slots[i]
		var content: VBoxContainer = slot.get_node_or_null("Content")
		if content == null:
			continue

		# 기존 내용 제거
		for child in content.get_children():
			child.queue_free()

		if i < _selected_squads.size():
			# 선택된 분대 표시
			var squad = _selected_squads[i]
			_fill_slot(content, squad, i)
		else:
			# 빈 슬롯 표시
			_fill_empty_slot(content, i)

	# 사용 가능한 카드 업데이트
	for squad_id in _available_cards:
		var card: Control = _available_cards[squad_id]
		var is_selected := false
		for selected in _selected_squads:
			if _get_squad_id(selected) == squad_id:
				is_selected = true
				break

		card.modulate = Color(0.4, 0.4, 0.4) if is_selected else Color.WHITE


func _fill_slot(content: VBoxContainer, squad: Variant, index: int) -> void:
	var class_id := _get_class_id(squad)
	var class_color: Color = CLASS_COLORS.get(class_id, Color.WHITE)

	# 인덱스
	var index_label := Label.new()
	index_label.text = "[%d]" % (index + 1)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.add_theme_font_size_override("font_size", 14)
	index_label.modulate = Color(0.6, 0.6, 0.6)
	content.add_child(index_label)

	# 클래스 아이콘
	var icon_label := Label.new()
	icon_label.text = _get_class_icon(class_id)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_label.modulate = class_color
	content.add_child(icon_label)

	# 클래스 이름
	var name_label := Label.new()
	name_label.text = class_id.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	content.add_child(name_label)

	# 제거 버튼
	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(30, 30)
	remove_btn.pressed.connect(func(): _remove_squad(index))
	content.add_child(remove_btn)


func _fill_empty_slot(content: VBoxContainer, index: int) -> void:
	var empty_label := Label.new()
	empty_label.text = "[%d]" % (index + 1)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 32)
	empty_label.modulate = Color(0.4, 0.4, 0.5)
	content.add_child(empty_label)

	var hint_label := Label.new()
	hint_label.text = "Empty"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.modulate = Color(0.4, 0.4, 0.5)
	content.add_child(hint_label)


func _update_ui() -> void:
	# 카운트 업데이트
	if count_label:
		count_label.text = "%d / %d Selected" % [_selected_squads.size(), MAX_SQUADS]

	# 배치 버튼 활성화
	if deploy_btn:
		deploy_btn.disabled = _selected_squads.is_empty()


# ===== SQUAD MANAGEMENT =====

func _on_squad_card_clicked(squad: Variant) -> void:
	var squad_id := _get_squad_id(squad)

	# 이미 선택됨 -> 제거
	for i in range(_selected_squads.size()):
		if _get_squad_id(_selected_squads[i]) == squad_id:
			_remove_squad(i)
			return

	# 선택 추가
	if _selected_squads.size() < MAX_SQUADS:
		_selected_squads.append(squad)
		_update_slots()
		_update_ui()


func _remove_squad(index: int) -> void:
	if index < 0 or index >= _selected_squads.size():
		return

	_selected_squads.remove_at(index)
	_update_slots()
	_update_ui()


# ===== DATA ACCESSORS =====

func _get_squad_id(squad: Variant) -> String:
	if squad is Dictionary:
		return squad.get("id", "")
	elif "id" in squad:
		return squad.id
	return ""


func _get_class_id(squad: Variant) -> String:
	if squad is Dictionary:
		return squad.get("class_id", "militia")
	elif "class_id" in squad:
		return squad.class_id
	return "militia"


func _get_rank(squad: Variant) -> int:
	if squad is Dictionary:
		# class_rank (from NewGameSetup) 또는 rank 둘 다 지원
		if squad.has("class_rank"):
			return squad.get("class_rank", 0)
		return squad.get("rank", 0)
	elif "class_rank" in squad:
		return squad.class_rank
	elif "rank" in squad:
		return squad.rank
	return 0


func _get_health_percent(squad: Variant) -> float:
	var current: int = 100
	var max_hp: int = 100
	if squad is Dictionary:
		current = squad.get("current_hp", 100)
		max_hp = squad.get("max_hp", 100)
	elif "current_hp" in squad and "max_hp" in squad:
		current = squad.current_hp
		max_hp = squad.max_hp

	return float(current) / float(max_hp) * 100.0 if max_hp > 0 else 100.0


func _get_rank_name(rank: int) -> String:
	match rank:
		0: return "Militia"
		1: return "Standard"
		2: return "Veteran"
		3: return "Elite"
		_: return "Unknown"


func _get_class_icon(class_id: String) -> String:
	match class_id:
		"guardian": return "🛡"
		"sentinel": return "⚔"
		"ranger": return "🎯"
		"engineer": return "🔧"
		"bionic": return "⚡"
		_: return "👤"


# ===== UI HANDLERS =====

func _on_deploy_pressed() -> void:
	if _selected_squads.is_empty():
		return

	# 선택한 분대를 GameState에 저장
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state:
		game_state.battle_squads = _selected_squads.duplicate()

	deploy_pressed.emit(_selected_squads.duplicate())

	# Battle3D로 전환
	get_tree().change_scene_to_file("res://scenes/battle/Battle3D.tscn")


func _on_back_pressed() -> void:
	back_pressed.emit()
	# StationPreview로 복귀
	get_tree().change_scene_to_file("res://scenes/campaign/StationPreview3D.tscn")
