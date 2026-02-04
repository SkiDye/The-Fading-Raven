class_name SectorMapUI
extends Control

## 섹터 맵 UI
## 노드 표시, 선택, 스톰 프론트 시각화


signal node_selected(node_id: String)
signal node_entered(node_id: String)
signal back_pressed

const NODE_LABELS: Dictionary = {
	Constants.NodeType.START: "START",
	Constants.NodeType.BATTLE: "BATTLE",
	Constants.NodeType.COMMANDER: "CMDR",
	Constants.NodeType.EQUIPMENT: "EQUIP",
	Constants.NodeType.STORM: "STORM",
	Constants.NodeType.BOSS: "BOSS",
	Constants.NodeType.REST: "REST",
	Constants.NodeType.GATE: "GATE"
}

const NODE_ICONS: Dictionary = {
	Constants.NodeType.START: "🚀",
	Constants.NodeType.BATTLE: "⚔️",
	Constants.NodeType.COMMANDER: "🚩",
	Constants.NodeType.EQUIPMENT: "❓",
	Constants.NodeType.STORM: "⚡",
	Constants.NodeType.BOSS: "💀",
	Constants.NodeType.REST: "💚",
	Constants.NodeType.GATE: "🚪"
}

const NODE_COLORS: Dictionary = {
	Constants.NodeType.START: Color(0.3, 0.7, 1.0),
	Constants.NodeType.BATTLE: Color(0.9, 0.4, 0.4),
	Constants.NodeType.COMMANDER: Color(0.4, 0.9, 0.4),
	Constants.NodeType.EQUIPMENT: Color(1.0, 0.8, 0.3),
	Constants.NodeType.STORM: Color(0.8, 0.3, 0.8),
	Constants.NodeType.BOSS: Color(1.0, 0.2, 0.2),
	Constants.NodeType.REST: Color(0.3, 0.9, 0.6),
	Constants.NodeType.GATE: Color(0.3, 1.0, 1.0)
}

@onready var _map_container: Control = $MapContainer
@onready var _info_panel: PanelContainer = $InfoPanel
@onready var _node_name_label: Label = $InfoPanel/MarginContainer/VBoxContainer/NodeNameLabel
@onready var _node_desc_label: RichTextLabel = $InfoPanel/MarginContainer/VBoxContainer/NodeDescLabel
@onready var _enter_btn: Button = $InfoPanel/MarginContainer/VBoxContainer/EnterBtn
@onready var _storm_indicator: Control = $MapContainer/StormIndicator
@onready var _credits_label: Label = $TopBar/CreditsLabel
@onready var _depth_label: Label = $TopBar/DepthLabel
@onready var _back_btn: Button = $TopBar/BackBtn

var _sector_data: Dictionary = {}
var _node_buttons: Dictionary = {}  # node_id -> Button
var _selected_node_id: String = ""
var _current_node_id: String = ""
var _storm_depth: int = 0


func _ready() -> void:
	_connect_signals()

	if _info_panel:
		_info_panel.visible = false


func _connect_signals() -> void:
	if _enter_btn:
		_enter_btn.pressed.connect(_on_enter_pressed)

	if _back_btn:
		_back_btn.pressed.connect(_on_back_pressed)

	if EventBus:
		EventBus.storm_front_advanced.connect(_on_storm_advanced)


func _exit_tree() -> void:
	if EventBus and EventBus.storm_front_advanced.is_connected(_on_storm_advanced):
		EventBus.storm_front_advanced.disconnect(_on_storm_advanced)


## 섹터 맵 데이터 설정
## [param data]: 섹터맵 데이터 (SectorGenerator.generate() 결과)
func setup(data: Dictionary) -> void:
	_sector_data = data
	print("[SectorMapUI] setup called with %d nodes" % data.get("nodes", []).size())
	_clear_map()
	_build_map()
	_update_credits()
	_update_storm_indicator()


## 현재 노드 설정
func set_current_node(node_id: String) -> void:
	_current_node_id = node_id
	_update_node_visuals()


## 스톰 깊이 설정
func set_storm_depth(depth: int) -> void:
	_storm_depth = depth
	_update_storm_indicator()


func _clear_map() -> void:
	for child in _map_container.get_children():
		# Don't delete the StormIndicator which is part of the scene
		if child.name != "StormIndicator":
			child.queue_free()
	_node_buttons.clear()


func _build_map() -> void:
	if not _sector_data.has("nodes"):
		print("[SectorMapUI] _build_map: No nodes in sector_data!")
		return

	var nodes: Array = _sector_data.nodes
	print("[SectorMapUI] Building map with %d nodes" % nodes.size())

	if _map_container == null:
		print("[SectorMapUI] ERROR: _map_container is null!")
		return

	# 컨테이너 크기 확인 (0이면 기본값 사용)
	var map_width: float = _map_container.size.x if _map_container.size.x > 0 else 1000.0
	var map_height: float = _map_container.size.y if _map_container.size.y > 0 else 600.0
	print("[SectorMapUI] Map container size: %dx%d" % [int(map_width), int(map_height)])

	# 레이어 수 계산
	var max_layer: int = 0
	for node in nodes:
		if "layer" in node:
			max_layer = maxi(max_layer, node.layer)
	print("[SectorMapUI] Max layer: %d" % max_layer)

	# Padding and spacing
	var padding: float = 60.0
	var usable_width: float = map_width - padding * 2
	var usable_height: float = map_height - padding * 2
	var layer_height: float = usable_height / maxf(1, max_layer + 1)

	# 각 레이어별 노드 수 계산
	var layer_counts: Dictionary = {}
	for node in nodes:
		var layer: int = node.get("layer", 0)
		layer_counts[layer] = layer_counts.get(layer, 0) + 1

	var layer_indices: Dictionary = {}
	var node_positions: Dictionary = {}  # For drawing connection lines

	# First pass: calculate positions
	for node in nodes:
		var node_id: String = node.get("id", "")
		var layer: int = node.get("layer", 0)

		var idx: int = layer_indices.get(layer, 0)
		layer_indices[layer] = idx + 1

		var count_in_layer: int = layer_counts.get(layer, 1)
		var x_spacing: float = usable_width / maxf(1, count_in_layer)
		var x: float = padding + x_spacing * idx + x_spacing * 0.5
		var y: float = padding + layer_height * layer + layer_height * 0.5

		node_positions[node_id] = Vector2(x, y)

	# Draw connection lines first (so they appear behind buttons)
	var lines_container := Control.new()
	lines_container.name = "ConnectionLines"
	lines_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_container.add_child(lines_container)

	for node in nodes:
		var node_id: String = node.get("id", "")
		var connections: Array = node.get("connections_out", [])
		var from_pos: Vector2 = node_positions.get(node_id, Vector2.ZERO)

		for conn_id in connections:
			var to_pos: Vector2 = node_positions.get(conn_id, Vector2.ZERO)
			if to_pos != Vector2.ZERO:
				var line := _create_connection_line(from_pos, to_pos)
				lines_container.add_child(line)

	# Second pass: create buttons
	for node in nodes:
		var node_id: String = node.get("id", "")
		var node_type: int = node.get("type", Constants.NodeType.BATTLE)
		var pos: Vector2 = node_positions.get(node_id, Vector2.ZERO)
		var node_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

		# Create node button with styled appearance
		var btn := Button.new()
		btn.name = "Node_" + node_id
		btn.text = NODE_LABELS.get(node_type, "???")
		btn.custom_minimum_size = Vector2(70, 36)
		btn.position = Vector2(pos.x - 35, pos.y - 18)

		# Style the button
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color(node_color.r * 0.3, node_color.g * 0.3, node_color.b * 0.3, 0.9)
		stylebox.border_color = node_color
		stylebox.set_border_width_all(2)
		stylebox.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", stylebox)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(node_color.r * 0.5, node_color.g * 0.5, node_color.b * 0.5, 1.0)
		hover_style.border_color = Color.WHITE
		hover_style.set_border_width_all(2)
		hover_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = node_color
		pressed_style.border_color = Color.WHITE
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 11)

		btn.pressed.connect(_on_node_pressed.bind(node_id))

		_map_container.add_child(btn)
		_node_buttons[node_id] = btn

	print("[SectorMapUI] Created %d node buttons" % _node_buttons.size())


func _create_connection_line(from_pos: Vector2, to_pos: Vector2) -> Line2D:
	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2.0
	line.default_color = Color(0.4, 0.4, 0.5, 0.6)
	line.antialiased = true
	return line


func _update_node_visuals() -> void:
	# Get accessible node IDs from current position
	var accessible_ids: Array = []
	var current_data := _get_node_data(_current_node_id)
	if not current_data.is_empty():
		accessible_ids = current_data.get("connections_out", [])

	for node_id in _node_buttons:
		var btn: Button = _node_buttons[node_id]
		var node_data := _get_node_data(node_id)
		var node_type: int = node_data.get("type", Constants.NodeType.BATTLE) if not node_data.is_empty() else Constants.NodeType.BATTLE
		var node_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

		# 현재 노드 강조
		if node_id == _current_node_id:
			# Current node - bright gold border
			var current_style := StyleBoxFlat.new()
			current_style.bg_color = Color(0.2, 0.15, 0.0, 1.0)
			current_style.border_color = Color.GOLD
			current_style.set_border_width_all(3)
			current_style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", current_style)
			btn.add_theme_color_override("font_color", Color.GOLD)
		elif node_id in accessible_ids:
			# Accessible nodes - normal bright colors
			var accessible_style := StyleBoxFlat.new()
			accessible_style.bg_color = Color(node_color.r * 0.3, node_color.g * 0.3, node_color.b * 0.3, 0.9)
			accessible_style.border_color = node_color
			accessible_style.set_border_width_all(2)
			accessible_style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", accessible_style)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.disabled = false
		else:
			# Inaccessible nodes - dimmed
			var dimmed_style := StyleBoxFlat.new()
			dimmed_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
			dimmed_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
			dimmed_style.set_border_width_all(1)
			dimmed_style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", dimmed_style)
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			# Don't disable - still allow clicking to see info


func _update_credits() -> void:
	if _credits_label == null:
		return

	var credits: int = 0
	if GameState and "credits" in GameState:
		credits = GameState.credits

	_credits_label.text = "Credits: %d" % credits


func _update_storm_indicator() -> void:
	if _depth_label:
		_depth_label.text = "Depth: %d / Storm: %d" % [_get_current_depth(), _storm_depth]


func _get_current_depth() -> int:
	if _current_node_id.is_empty() or not _sector_data.has("nodes"):
		return 0

	for node in _sector_data.nodes:
		if node.get("id", "") == _current_node_id:
			return node.get("layer", 0)

	return 0


func _get_node_data(node_id: String) -> Dictionary:
	if not _sector_data.has("nodes"):
		return {}

	for node in _sector_data.nodes:
		if node.get("id", "") == node_id:
			return node

	return {}


func _show_node_info(node_id: String) -> void:
	if _info_panel == null:
		return

	var node_data := _get_node_data(node_id)
	if node_data.is_empty():
		_info_panel.visible = false
		return

	var node_type: int = node_data.get("type", Constants.NodeType.BATTLE)

	if _node_name_label:
		_node_name_label.text = _get_node_type_name(node_type)

	if _node_desc_label:
		_node_desc_label.text = _get_node_description(node_type)

	# 접근 가능 여부 체크
	var can_enter := _can_enter_node(node_id)
	if _enter_btn:
		_enter_btn.disabled = not can_enter

	_info_panel.visible = true


func _get_node_type_name(node_type: int) -> String:
	match node_type:
		Constants.NodeType.START: return "Start"
		Constants.NodeType.BATTLE: return "Battle"
		Constants.NodeType.COMMANDER: return "Commander"
		Constants.NodeType.EQUIPMENT: return "Equipment"
		Constants.NodeType.STORM: return "Storm"
		Constants.NodeType.BOSS: return "Boss"
		Constants.NodeType.REST: return "Rest"
		Constants.NodeType.GATE: return "Gate"
		_: return "Unknown"


func _get_node_description(node_type: int) -> String:
	match node_type:
		Constants.NodeType.START:
			return "Starting point of your journey."
		Constants.NodeType.BATTLE:
			return "Defend the station from enemy waves."
		Constants.NodeType.COMMANDER:
			return "Recruit a new crew commander."
		Constants.NodeType.EQUIPMENT:
			return "Find equipment for your crew."
		Constants.NodeType.STORM:
			return "Fight through the storm. Harder enemies, better rewards."
		Constants.NodeType.BOSS:
			return "Face a powerful boss enemy."
		Constants.NodeType.REST:
			return "Rest and recover your crew's health."
		Constants.NodeType.GATE:
			return "The final jump gate. Reach this to escape."
		_:
			return ""


func _can_enter_node(node_id: String) -> bool:
	# Already at this node
	if node_id == _current_node_id:
		return false

	# Check if connected from current node
	var current_data := _get_node_data(_current_node_id)
	if current_data.is_empty():
		return true  # No current node, allow any

	var connections: Array = current_data.get("connections_out", [])
	if not (node_id in connections):
		return false

	# Check if node is consumed by storm
	var node_data := _get_node_data(node_id)
	if not node_data.is_empty():
		var layer: int = node_data.get("layer", 0)
		if layer <= _storm_depth:
			return false

	return true


# ===== SIGNAL HANDLERS =====

func _on_node_pressed(node_id: String) -> void:
	_selected_node_id = node_id
	_show_node_info(node_id)
	node_selected.emit(node_id)


func _on_enter_pressed() -> void:
	if _selected_node_id.is_empty():
		return

	node_entered.emit(_selected_node_id)

	if EventBus:
		EventBus.sector_node_entered.emit(_selected_node_id)


func _on_storm_advanced(new_depth: int) -> void:
	set_storm_depth(new_depth)


func _on_back_pressed() -> void:
	back_pressed.emit()
