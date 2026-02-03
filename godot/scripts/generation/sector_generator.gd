## SectorGenerator - 섹터 맵 생성
## DAG 기반 노드 연결 및 이벤트 배치
extends RefCounted
class_name SectorGenerator

# ===========================================
# 노드 타입
# ===========================================

enum NodeType {
	START,
	STATION,        # 일반 전투
	ELITE_STATION,  # 엘리트 전투
	SHOP,           # 상점/업그레이드
	EVENT,          # 이벤트
	REST,           # 휴식/회복
	BOSS,           # 보스
	GATE,           # 섹터 이동 (최종)
}

const NODE_ICONS := {
	NodeType.START: "S",
	NodeType.STATION: "O",
	NodeType.ELITE_STATION: "E",
	NodeType.SHOP: "$",
	NodeType.EVENT: "?",
	NodeType.REST: "R",
	NodeType.BOSS: "B",
	NodeType.GATE: "G",
}


# ===========================================
# 생성 설정
# ===========================================

const SECTOR_ROWS := 7       # 행 수 (시작~게이트)
const MIN_NODES_PER_ROW := 2
const MAX_NODES_PER_ROW := 4
const MIN_CONNECTIONS := 1
const MAX_CONNECTIONS := 3


# ===========================================
# 섹터 생성
# ===========================================

## 섹터 맵 생성
static func generate(difficulty: int) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var node_id := 0

	# 행별 노드 생성
	var rows: Array[Array] = []

	for row_idx in range(SECTOR_ROWS):
		var row_nodes: Array[Dictionary] = []

		if row_idx == 0:
			# 시작 노드
			row_nodes.append(_create_node(node_id, row_idx, 0.5, NodeType.START))
			node_id += 1
		elif row_idx == SECTOR_ROWS - 1:
			# 게이트 노드
			row_nodes.append(_create_node(node_id, row_idx, 0.5, NodeType.GATE))
			node_id += 1
		elif row_idx == SECTOR_ROWS - 2:
			# 보스 노드
			row_nodes.append(_create_node(node_id, row_idx, 0.5, NodeType.BOSS))
			node_id += 1
		else:
			# 일반 행
			var node_count := RngManager.range_int(
				RngManager.STREAM_SECTOR_MAP,
				MIN_NODES_PER_ROW,
				MAX_NODES_PER_ROW
			)

			for i in range(node_count):
				var x_pos := (i + 0.5) / float(node_count)
				var node_type := _determine_node_type(row_idx, difficulty)
				row_nodes.append(_create_node(node_id, row_idx, x_pos, node_type))
				node_id += 1

		rows.append(row_nodes)
		nodes.append_array(row_nodes)

	# 노드 연결
	_connect_nodes(rows)

	# 스톰 라인 초기 위치
	var storm_line := SECTOR_ROWS  # 맨 아래에서 시작

	return {
		"nodes": nodes,
		"rows": rows,
		"storm_line": storm_line,
		"difficulty": difficulty,
	}


# ===========================================
# 노드 생성
# ===========================================

static func _create_node(id: int, row: int, x_pos: float, type: int) -> Dictionary:
	return {
		"id": id,
		"row": row,
		"x_position": x_pos,
		"type": type,
		"connections": [],  # 연결된 노드 ID들
		"visited": false,
		"revealed": row <= 1,  # 시작 근처만 공개
		"data": _generate_node_data(type),
	}


static func _generate_node_data(type: int) -> Dictionary:
	match type:
		NodeType.STATION:
			return {
				"difficulty_modifier": RngManager.range_float(RngManager.STREAM_SECTOR_MAP, 0.9, 1.1),
				"reward_modifier": 1.0,
			}
		NodeType.ELITE_STATION:
			return {
				"difficulty_modifier": 1.5,
				"reward_modifier": 1.5,
				"guaranteed_equipment": RngManager.chance(RngManager.STREAM_SECTOR_MAP, 0.5),
			}
		NodeType.SHOP:
			return {
				"shop_type": RngManager.pick(RngManager.STREAM_SECTOR_MAP, ["equipment", "upgrade", "recruit"]),
			}
		NodeType.EVENT:
			return {
				"event_type": _pick_event_type(),
			}
		NodeType.REST:
			return {
				"heal_amount": Balance.ECONOMY["heal_amount"],
			}
		NodeType.BOSS:
			return {
				"boss_type": RngManager.pick(RngManager.STREAM_SECTOR_MAP, ["hive_queen", "war_chief", "overlord"]),
			}
		_:
			return {}


static func _determine_node_type(row: int, difficulty: int) -> int:
	# 확률 기반 노드 타입 결정
	var weights: Dictionary

	if row <= 2:
		# 초반: 전투 위주
		weights = {
			NodeType.STATION: 60,
			NodeType.SHOP: 20,
			NodeType.EVENT: 15,
			NodeType.REST: 5,
		}
	elif row <= 4:
		# 중반: 다양한 이벤트
		weights = {
			NodeType.STATION: 40,
			NodeType.ELITE_STATION: 15,
			NodeType.SHOP: 20,
			NodeType.EVENT: 15,
			NodeType.REST: 10,
		}
	else:
		# 후반: 엘리트 증가
		weights = {
			NodeType.STATION: 30,
			NodeType.ELITE_STATION: 25,
			NodeType.SHOP: 15,
			NodeType.EVENT: 15,
			NodeType.REST: 15,
		}

	# 난이도에 따른 조정
	if difficulty >= Balance.Difficulty.HARD:
		weights[NodeType.ELITE_STATION] = weights.get(NodeType.ELITE_STATION, 0) + 10
		weights[NodeType.REST] = maxi(0, weights.get(NodeType.REST, 0) - 5)

	var types: Array = []
	var type_weights: Array = []

	for type in weights:
		types.append(type)
		type_weights.append(weights[type])

	return RngManager.weighted_pick(RngManager.STREAM_SECTOR_MAP, types, type_weights)


static func _pick_event_type() -> String:
	var events := [
		"abandoned_cargo",      # 자원 획득
		"distress_signal",      # 전투 or 보상
		"mysterious_trader",    # 특수 거래
		"crew_challenge",       # 도전 -> 보상
		"equipment_cache",      # 장비 발견
	]
	return RngManager.pick(RngManager.STREAM_SECTOR_MAP, events)


# ===========================================
# 노드 연결
# ===========================================

static func _connect_nodes(rows: Array[Array]) -> void:
	for row_idx in range(rows.size() - 1):
		var current_row: Array = rows[row_idx]
		var next_row: Array = rows[row_idx + 1]

		if current_row.is_empty() or next_row.is_empty():
			continue

		# 각 노드에서 다음 행으로 연결
		for node in current_row:
			var connection_count := RngManager.range_int(
				RngManager.STREAM_SECTOR_MAP,
				MIN_CONNECTIONS,
				mini(MAX_CONNECTIONS, next_row.size())
			)

			# 가장 가까운 노드들 선택
			var sorted_next := next_row.duplicate()
			sorted_next.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var dist_a: float = absf(a["x_position"] - node["x_position"])
				var dist_b: float = absf(b["x_position"] - node["x_position"])
				return dist_a < dist_b
			)

			for i in range(mini(connection_count, sorted_next.size())):
				var target: Dictionary = sorted_next[i]
				if target["id"] not in node["connections"]:
					node["connections"].append(target["id"])

		# 모든 다음 행 노드가 연결되었는지 확인
		for next_node in next_row:
			var has_incoming := false
			for node in current_row:
				if next_node["id"] in node["connections"]:
					has_incoming = true
					break

			if not has_incoming:
				# 가장 가까운 이전 노드와 연결
				var closest: Dictionary = current_row[0]
				var min_dist: float = INF

				for node in current_row:
					var dist: float = absf(node["x_position"] - next_node["x_position"])
					if dist < min_dist:
						min_dist = dist
						closest = node

				closest["connections"].append(next_node["id"])


# ===========================================
# 유틸리티
# ===========================================

## 노드 ID로 노드 찾기
static func get_node_by_id(sector_data: Dictionary, node_id: int) -> Dictionary:
	for node in sector_data["nodes"]:
		if node["id"] == node_id:
			return node
	return {}


## 현재 위치에서 이동 가능한 노드들
static func get_available_nodes(sector_data: Dictionary, current_node_id: int) -> Array[Dictionary]:
	var current := get_node_by_id(sector_data, current_node_id)
	if current.is_empty():
		return []

	var available: Array[Dictionary] = []
	var connections: Array = current.get("connections", [])

	for conn_id in connections:
		var node := get_node_by_id(sector_data, conn_id)
		if not node.is_empty():
			available.append(node)

	return available


## 스톰 라인 진행
static func advance_storm(sector_data: Dictionary) -> void:
	sector_data["storm_line"] -= 1

	# 스톰에 닿은 노드들 제거/비활성화
	for node in sector_data["nodes"]:
		if node["row"] >= sector_data["storm_line"]:
			node["destroyed"] = true


## 노드 방문 처리
static func visit_node(sector_data: Dictionary, node_id: int) -> void:
	var node := get_node_by_id(sector_data, node_id)
	if not node.is_empty():
		node["visited"] = true

		# 연결된 노드 공개
		for conn_id in node.get("connections", []):
			var connected := get_node_by_id(sector_data, conn_id)
			if not connected.is_empty():
				connected["revealed"] = true


## 섹터 클리어 여부
static func is_sector_complete(sector_data: Dictionary) -> bool:
	for node in sector_data["nodes"]:
		if node["type"] == NodeType.GATE and node["visited"]:
			return true
	return false


## 디버그 출력
static func debug_print(sector_data: Dictionary) -> void:
	print("=== Sector Map ===")
	print("Storm Line: Row %d" % sector_data["storm_line"])

	var rows: Array = sector_data.get("rows", [])
	for row_idx in range(rows.size()):
		var row: Array = rows[row_idx]
		var row_str := "Row %d: " % row_idx

		for node in row:
			var icon: String = NODE_ICONS.get(node["type"], "?")
			var visited := "V" if node["visited"] else " "
			row_str += "[%s%s] " % [icon, visited]

		print(row_str)
