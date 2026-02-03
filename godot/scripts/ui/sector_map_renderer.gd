## SectorMapRenderer - 섹터 맵 시각화
## 노드와 연결선 렌더링
extends Control
class_name SectorMapRenderer

# ===========================================
# 설정
# ===========================================

const NODE_RADIUS := 20.0
const NODE_SPACING_X := 150.0
const NODE_SPACING_Y := 100.0
const MARGIN := Vector2(100, 80)

# 노드 색상
const NODE_COLORS := {
	SectorGenerator.NodeType.START: Color(0.3, 0.7, 0.3),
	SectorGenerator.NodeType.STATION: Color(0.5, 0.5, 0.6),
	SectorGenerator.NodeType.ELITE_STATION: Color(0.8, 0.5, 0.2),
	SectorGenerator.NodeType.SHOP: Color(0.9, 0.8, 0.2),
	SectorGenerator.NodeType.EVENT: Color(0.6, 0.4, 0.8),
	SectorGenerator.NodeType.REST: Color(0.3, 0.8, 0.6),
	SectorGenerator.NodeType.BOSS: Color(0.9, 0.2, 0.2),
	SectorGenerator.NodeType.GATE: Color(0.2, 0.6, 0.9),
}

const NODE_ICONS := {
	SectorGenerator.NodeType.START: "S",
	SectorGenerator.NodeType.STATION: "⚔",
	SectorGenerator.NodeType.ELITE_STATION: "★",
	SectorGenerator.NodeType.SHOP: "$",
	SectorGenerator.NodeType.EVENT: "?",
	SectorGenerator.NodeType.REST: "♥",
	SectorGenerator.NodeType.BOSS: "☠",
	SectorGenerator.NodeType.GATE: "►",
}

# 참조
var sector_data: Dictionary = {}
var current_node_id: int = -1
var hovered_node_id: int = -1
var node_positions: Dictionary = {}  # node_id -> Vector2


# ===========================================
# 시그널
# ===========================================

signal node_clicked(node_id: int)
signal node_hovered(node_id: int)


# ===========================================
# 초기화
# ===========================================

func setup(data: Dictionary, current_id: int) -> void:
	sector_data = data
	current_node_id = current_id
	_calculate_node_positions()
	queue_redraw()


func _calculate_node_positions() -> void:
	node_positions.clear()

	var rows: Array = sector_data.get("rows", [])

	for row_idx in range(rows.size()):
		var row: Array = rows[row_idx]
		var row_width := row.size() * NODE_SPACING_X

		for i in range(row.size()):
			var node: Dictionary = row[i]
			var x := MARGIN.x + (size.x - MARGIN.x * 2) * node.get("x_position", 0.5)
			var y := MARGIN.y + row_idx * NODE_SPACING_Y

			node_positions[node["id"]] = Vector2(x, y)


# ===========================================
# 렌더링
# ===========================================

func _draw() -> void:
	if sector_data.is_empty():
		return

	# 스톰 라인
	_draw_storm_line()

	# 연결선 먼저 그리기
	_draw_connections()

	# 노드 그리기
	for node in sector_data.get("nodes", []):
		_draw_node(node)


func _draw_storm_line() -> void:
	var storm_line: int = sector_data.get("storm_line", 999)
	var y := MARGIN.y + storm_line * NODE_SPACING_Y

	# 스톰 영역 (반투명)
	draw_rect(Rect2(0, y, size.x, size.y - y), Color(0.8, 0.2, 0.2, 0.15))

	# 스톰 라인
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.9, 0.3, 0.3, 0.8), 3.0)

	# 라벨
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, y - 5),
		"STORM FRONT",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.9, 0.3, 0.3)
	)


func _draw_connections() -> void:
	for node in sector_data.get("nodes", []):
		var from_pos: Vector2 = node_positions.get(node["id"], Vector2.ZERO)
		var connections: Array = node.get("connections", [])

		for conn_id in connections:
			var to_pos: Vector2 = node_positions.get(conn_id, Vector2.ZERO)

			# 연결선 색상
			var color := Color(0.4, 0.4, 0.5, 0.5)

			# 현재 노드에서의 연결은 밝게
			if node["id"] == current_node_id:
				color = Color(0.6, 0.8, 0.6, 0.8)

			# 방문한 노드 연결
			if node.get("visited", false):
				color = Color(0.3, 0.5, 0.3, 0.6)

			draw_line(from_pos, to_pos, color, 2.0)


func _draw_node(node: Dictionary) -> void:
	var node_id: int = node["id"]
	var pos: Vector2 = node_positions.get(node_id, Vector2.ZERO)
	var node_type: int = node.get("type", SectorGenerator.NodeType.STATION)
	var is_visited: bool = node.get("visited", false)
	var is_revealed: bool = node.get("revealed", false)
	var is_destroyed: bool = node.get("destroyed", false)
	var is_current := node_id == current_node_id
	var is_hovered := node_id == hovered_node_id
	var is_available := _is_node_available(node_id)

	# 파괴된 노드
	if is_destroyed:
		draw_circle(pos, NODE_RADIUS, Color(0.3, 0.1, 0.1, 0.5))
		draw_string(ThemeDB.fallback_font, pos - Vector2(5, -5), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.5, 0.2, 0.2))
		return

	# 미공개 노드
	if not is_revealed:
		draw_circle(pos, NODE_RADIUS, Color(0.2, 0.2, 0.25, 0.5))
		draw_string(ThemeDB.fallback_font, pos - Vector2(5, -5), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.4, 0.4, 0.4))
		return

	# 노드 색상
	var color: Color = NODE_COLORS.get(node_type, Color.GRAY)

	if is_visited:
		color = color.darkened(0.4)
	elif is_hovered and is_available:
		color = color.lightened(0.2)

	# 현재 노드 표시
	if is_current:
		draw_circle(pos, NODE_RADIUS + 8, Color(0.9, 0.9, 0.3, 0.5))

	# 이동 가능 노드 표시
	if is_available and not is_visited:
		draw_circle(pos, NODE_RADIUS + 4, Color(0.5, 0.8, 0.5, 0.3))

	# 노드 원
	draw_circle(pos, NODE_RADIUS, color)

	# 테두리
	var outline_color := color.lightened(0.3) if is_available else color.darkened(0.2)
	draw_arc(pos, NODE_RADIUS, 0, TAU, 32, outline_color, 2.0)

	# 아이콘
	var icon: String = NODE_ICONS.get(node_type, "?")
	draw_string(
		ThemeDB.fallback_font,
		pos - Vector2(6, -6),
		icon,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		18,
		Color.WHITE if not is_visited else Color(0.6, 0.6, 0.6)
	)


func _is_node_available(node_id: int) -> bool:
	if current_node_id < 0:
		# 시작 노드만 선택 가능
		var node := SectorGenerator.get_node_by_id(sector_data, node_id)
		return node.get("type") == SectorGenerator.NodeType.START

	# 현재 노드에서 연결된 노드만 선택 가능
	var current := SectorGenerator.get_node_by_id(sector_data, current_node_id)
	return node_id in current.get("connections", [])


# ===========================================
# 입력 처리
# ===========================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos := event.position
		var found_id := -1

		for node_id in node_positions:
			var pos: Vector2 = node_positions[node_id]
			if pos.distance_to(mouse_pos) <= NODE_RADIUS:
				found_id = node_id
				break

		if found_id != hovered_node_id:
			hovered_node_id = found_id
			node_hovered.emit(hovered_node_id)
			queue_redraw()

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if hovered_node_id >= 0 and _is_node_available(hovered_node_id):
				node_clicked.emit(hovered_node_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_calculate_node_positions()
		queue_redraw()


# ===========================================
# 유틸리티
# ===========================================

func get_node_tooltip(node_id: int) -> String:
	var node := SectorGenerator.get_node_by_id(sector_data, node_id)
	if node.is_empty():
		return ""

	var node_type: int = node.get("type", 0)
	var type_names := {
		SectorGenerator.NodeType.START: "시작 지점",
		SectorGenerator.NodeType.STATION: "정거장 방어",
		SectorGenerator.NodeType.ELITE_STATION: "엘리트 전투",
		SectorGenerator.NodeType.SHOP: "상점",
		SectorGenerator.NodeType.EVENT: "이벤트",
		SectorGenerator.NodeType.REST: "휴식",
		SectorGenerator.NodeType.BOSS: "보스",
		SectorGenerator.NodeType.GATE: "섹터 게이트",
	}

	return type_names.get(node_type, "알 수 없음")
