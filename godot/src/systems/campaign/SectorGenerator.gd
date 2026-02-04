class_name SectorGenerator
extends RefCounted

## DAG 기반 섹터 맵 생성기
## 동일 시드 -> 동일 맵 생성 보장
## [br][br]
## 사용 예:
## [codeblock]
## var generator = SectorGenerator.new()
## var sector = generator.generate(12345, Constants.Difficulty.NORMAL)
## [/codeblock]


# ===== INNER CLASSES =====

class SectorNode:
	## 섹터 맵의 단일 노드
	var id: String
	var layer: int
	var x_position: float  # 0.0 ~ 1.0 (수평 위치)
	var node_type: Constants.NodeType
	var difficulty_score: float
	var connections_out: Array[String] = []
	var station_seed: int
	var visited: bool = false
	var consumed: bool = false  # 이벤트 소비 여부

	func _to_string() -> String:
		return "SectorNode(%s, layer=%d, type=%d)" % [id, layer, node_type]


class SectorData:
	## 전체 섹터 맵 데이터
	var seed: int
	var difficulty: Constants.Difficulty
	var layers: Array = []  # Array of Array[SectorNode]
	var total_depth: int
	var nodes: Dictionary = {}  # id -> SectorNode
	var current_node_id: String = ""
	var storm_depth: int = -1  # 스톰이 도달한 최대 깊이

	func get_node(id: String) -> SectorNode:
		return nodes.get(id)

	func get_start_node() -> SectorNode:
		if layers.is_empty() or layers[0].is_empty():
			return null
		return layers[0][0]

	func get_gate_node() -> SectorNode:
		if layers.is_empty():
			return null
		var last_layer = layers[-1]
		for node in last_layer:
			if node.node_type == Constants.NodeType.GATE:
				return node
		return null

	func get_reachable_nodes(from_id: String) -> Array[SectorNode]:
		## 현재 노드에서 이동 가능한 노드들
		var result: Array[SectorNode] = []
		var from_node := get_node(from_id)
		if from_node == null:
			return result

		for out_id in from_node.connections_out:
			var out_node := get_node(out_id)
			if out_node and out_node.layer > storm_depth:
				result.append(out_node)

		return result

	func is_path_to_gate_available() -> bool:
		## 게이트까지 경로 존재 여부
		if current_node_id.is_empty():
			return true

		var visited_set: Dictionary = {}
		var queue: Array[String] = [current_node_id]

		while not queue.is_empty():
			var current: String = queue.pop_front() as String
			if visited_set.has(current):
				continue
			visited_set[current] = true

			var node: SectorNode = get_node(current)
			if node == null:
				continue

			if node.node_type == Constants.NodeType.GATE:
				return true

			for out_id in node.connections_out:
				var out_node: SectorNode = get_node(out_id)
				if out_node and out_node.layer > storm_depth:
					queue.append(out_id)

		return false

	func advance_storm() -> int:
		## 스톰 전선 진행, 새 스톰 깊이 반환
		storm_depth += 1
		return storm_depth


# ===== GENERATOR =====

const SeededRNGClass = preload("res://src/systems/campaign/SeededRNG.gd")

var _rng  # SeededRNG
var _difficulty: Constants.Difficulty


func generate(seed_value: int, difficulty: Constants.Difficulty) -> SectorData:
	## 섹터 맵 생성
	_rng = SeededRNGClass.new(seed_value)
	_difficulty = difficulty

	var data := SectorData.new()
	data.seed = seed_value
	data.difficulty = difficulty
	data.nodes = {}

	# 1. 깊이 결정 (난이도별 범위 사용)
	var depth_range: Array = Constants.get_sector_depth_range(difficulty)
	data.total_depth = _rng.range_int(depth_range[0], depth_range[1])

	# 2. 레이어별 노드 생성
	data.layers = []
	for layer_idx in range(data.total_depth + 1):
		var layer := _generate_layer(layer_idx, data.total_depth)
		data.layers.append(layer)

		for node in layer:
			data.nodes[node.id] = node

	# 3. 연결 생성
	_connect_layers(data)

	# 4. 이벤트 배치
	_place_events(data)

	# 5. 난이도 점수 계산
	_calculate_difficulty_scores(data)

	# 6. 시작 위치 설정
	var start_node := data.get_start_node()
	if start_node:
		data.current_node_id = start_node.id
		start_node.visited = true

	return data


func _generate_layer(layer_idx: int, total_depth: int) -> Array:
	var result: Array = []

	# 시작점 (단일 노드)
	if layer_idx == 0:
		var start := SectorNode.new()
		start.id = "node_0_0"
		start.layer = 0
		start.x_position = 0.5
		start.node_type = Constants.NodeType.START
		start.station_seed = _rng.next_int()
		result.append(start)
		return result

	# 게이트 (단일 노드)
	if layer_idx == total_depth:
		var gate := SectorNode.new()
		gate.id = "node_%d_0" % layer_idx
		gate.layer = layer_idx
		gate.x_position = 0.5
		gate.node_type = Constants.NodeType.GATE
		gate.station_seed = _rng.next_int()
		result.append(gate)
		return result

	# 일반 레이어 (난이도별 노드 수 범위 사용)
	var node_range: Array = Constants.get_nodes_per_layer_range(_difficulty)
	var node_count: int = _rng.range_int(node_range[0], node_range[1])

	var positions := _distribute_positions(node_count)

	for i in range(node_count):
		var node := SectorNode.new()
		node.id = "node_%d_%d" % [layer_idx, i]
		node.layer = layer_idx
		node.x_position = positions[i]
		node.node_type = Constants.NodeType.BATTLE  # 기본값
		node.station_seed = _rng.next_int()
		result.append(node)

	return result


func _distribute_positions(count: int) -> Array[float]:
	## 노드들을 수평으로 분산 배치
	if count == 1:
		return [0.5]

	var result: Array[float] = []
	var spacing := 1.0 / (count + 1)

	for i in range(count):
		var base: float = spacing * (i + 1)
		var jitter: float = _rng.range_float(-0.08, 0.08)
		result.append(clampf(base + jitter, 0.1, 0.9))

	return result


func _connect_layers(data: SectorData) -> void:
	## 레이어 간 연결 생성 (DAG 구조)
	for layer_idx in range(data.layers.size() - 1):
		var current_layer: Array = data.layers[layer_idx]
		var next_layer: Array = data.layers[layer_idx + 1]

		# 1. 모든 현재 노드가 최소 1개 연결 보장
		for node in current_layer:
			var nearest := _find_nearest_node(node, next_layer)
			if nearest and not node.connections_out.has(nearest.id):
				node.connections_out.append(nearest.id)

		# 2. 다음 레이어의 고립 노드 연결
		for node in next_layer:
			var has_incoming := false
			for prev_node in current_layer:
				if prev_node.connections_out.has(node.id):
					has_incoming = true
					break

			if not has_incoming:
				var nearest := _find_nearest_node(node, current_layer)
				if nearest:
					nearest.connections_out.append(node.id)

		# 3. 추가 연결 (분기, 40% 확률)
		for node in current_layer:
			if _rng.chance(0.4):
				var candidates: Array = []
				for n in next_layer:
					if not node.connections_out.has(n.id):
						candidates.append(n)

				if not candidates.is_empty():
					var extra = _rng.choice(candidates)
					if extra:
						node.connections_out.append(extra.id)


func _find_nearest_node(node: SectorNode, layer: Array) -> SectorNode:
	## x_position 기준 가장 가까운 노드 찾기
	var nearest: SectorNode = null
	var nearest_dist := INF

	for other in layer:
		var dist := absf(node.x_position - other.x_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other

	return nearest


func _place_events(data: SectorData) -> void:
	## 특수 이벤트 노드 배치
	var last_event_layer: Dictionary = {
		"rescue": -10,
		"equipment": -10,
		"salvage": -10,
		"depot": -10,
		"storm": -10,
		"boss": -10,
		"rest": -10,
		"beacon": -10
	}

	var event_counts: Dictionary = {
		"rescue": 0,
		"equipment": 0,
		"salvage": 0,
		"depot": 0,
		"beacon": 0
	}

	var intervals: Dictionary = Constants.BALANCE.campaign.get("event_intervals", {
		"rescue": 3,
		"equipment": 2,
		"salvage": 3,
		"depot": 4,
		"storm": 4,
		"boss": 5,
		"beacon": 6
	})
	var chances: Dictionary = Constants.BALANCE.campaign.get("event_chances", {
		"rescue": 0.25,
		"equipment": 0.3,
		"salvage": 0.2,
		"depot": 0.15,
		"storm": 0.2,
		"boss": 0.15,
		"rest": 0.5,
		"beacon": 0.2
	})

	for layer_idx in range(1, data.total_depth):
		var layer: Array = data.layers[layer_idx]

		for node in layer:
			if node.node_type != Constants.NodeType.BATTLE:
				continue

			# RESCUE 노드 (깊이 2+, 최대 3개) - 탈출자 보호 → 새 팀장 영입
			if layer_idx >= 2 and layer_idx - last_event_layer.rescue >= intervals.get("rescue", 3):
				if event_counts.rescue < 3 and _rng.chance(chances.get("rescue", 0.25)):
					node.node_type = Constants.NodeType.RESCUE
					event_counts.rescue += 1
					last_event_layer.rescue = layer_idx
					continue

			# 장비 노드 (깊이 1+, 최대 6개)
			if layer_idx >= 1 and layer_idx - last_event_layer.equipment >= intervals.get("equipment", 2):
				if event_counts.equipment < 6 and _rng.chance(chances.get("equipment", 0.3)):
					node.node_type = Constants.NodeType.EQUIPMENT
					event_counts.equipment += 1
					last_event_layer.equipment = layer_idx
					continue

			# SALVAGE 노드 (깊이 2+, 최대 4개) - 난파선 탐색 → 장비
			if layer_idx >= 2 and layer_idx - last_event_layer.salvage >= intervals.get("salvage", 3):
				if event_counts.salvage < 4 and _rng.chance(chances.get("salvage", 0.2)):
					node.node_type = Constants.NodeType.SALVAGE
					event_counts.salvage += 1
					last_event_layer.salvage = layer_idx
					continue

			# DEPOT 노드 (깊이 3+, 최대 2개) - 무료 장비
			if layer_idx >= 3 and layer_idx - last_event_layer.depot >= intervals.get("depot", 4):
				if event_counts.depot < 2 and _rng.chance(chances.get("depot", 0.15)):
					node.node_type = Constants.NodeType.DEPOT
					event_counts.depot += 1
					last_event_layer.depot = layer_idx
					continue

			# 스톰 노드 (깊이 4+)
			if layer_idx >= 4 and layer_idx - last_event_layer.storm >= intervals.get("storm", 4):
				if _rng.chance(chances.get("storm", 0.2)):
					node.node_type = Constants.NodeType.STORM
					last_event_layer.storm = layer_idx
					continue

			# 보스 노드 (깊이 5+, 5의 배수에서 확률 증가)
			if layer_idx >= 5 and layer_idx - last_event_layer.boss >= intervals.get("boss", 5):
				var boss_chance: float = chances.get("boss", 0.15)
				if layer_idx % 5 == 0:
					boss_chance = 0.7
				if _rng.chance(boss_chance):
					node.node_type = Constants.NodeType.BOSS
					last_event_layer.boss = layer_idx
					continue

			# 휴식 노드 (깊이 6, 12, 18)
			if layer_idx in [6, 12, 18]:
				if _rng.chance(chances.get("rest", 0.5)):
					node.node_type = Constants.NodeType.REST
					continue

			# BEACON 노드 (깊이 5+, 최대 2개) - 체크포인트
			if layer_idx >= 5 and layer_idx - last_event_layer.beacon >= intervals.get("beacon", 6):
				if event_counts.beacon < 2 and _rng.chance(chances.get("beacon", 0.2)):
					node.node_type = Constants.NodeType.BEACON
					event_counts.beacon += 1
					last_event_layer.beacon = layer_idx
					continue


func _calculate_difficulty_scores(data: SectorData) -> void:
	## 노드별 난이도 점수 계산
	var base_mult: Array[float] = [1.0, 1.5, 2.0, 2.5]
	var scale: Array[float] = [0.15, 0.20, 0.25, 0.30]

	var diff_idx := int(_difficulty)

	for layer_idx in range(data.total_depth + 1):
		for node in data.layers[layer_idx]:
			node.difficulty_score = base_mult[diff_idx] + layer_idx * scale[diff_idx]

			# 이벤트 타입별 보정
			match node.node_type:
				Constants.NodeType.STORM:
					node.difficulty_score *= 1.3
				Constants.NodeType.BOSS:
					node.difficulty_score *= 1.5
				Constants.NodeType.REST:
					node.difficulty_score = 0.0
				Constants.NodeType.START:
					node.difficulty_score = 0.0
				Constants.NodeType.GATE:
					node.difficulty_score *= 1.8


# ===== STATIC HELPERS =====

static func get_node_type_name(node_type: Constants.NodeType) -> String:
	match node_type:
		Constants.NodeType.START:
			return "Start"
		Constants.NodeType.BATTLE:
			return "Battle"
		Constants.NodeType.COMMANDER:
			return "Commander"
		Constants.NodeType.EQUIPMENT:
			return "Equipment"
		Constants.NodeType.STORM:
			return "Storm"
		Constants.NodeType.BOSS:
			return "Boss"
		Constants.NodeType.REST:
			return "Rest"
		Constants.NodeType.GATE:
			return "Gate"
		Constants.NodeType.RESCUE:
			return "Rescue"
		Constants.NodeType.SALVAGE:
			return "Salvage"
		Constants.NodeType.DEPOT:
			return "Depot"
		Constants.NodeType.BEACON:
			return "Beacon"
		_:
			return "Unknown"


static func get_node_type_name_ko(node_type: Constants.NodeType) -> String:
	match node_type:
		Constants.NodeType.START:
			return "시작"
		Constants.NodeType.BATTLE:
			return "전투"
		Constants.NodeType.COMMANDER:
			return "지휘관"
		Constants.NodeType.EQUIPMENT:
			return "장비"
		Constants.NodeType.STORM:
			return "폭풍"
		Constants.NodeType.BOSS:
			return "보스"
		Constants.NodeType.REST:
			return "휴식"
		Constants.NodeType.GATE:
			return "게이트"
		Constants.NodeType.RESCUE:
			return "구조"
		Constants.NodeType.SALVAGE:
			return "탐색"
		Constants.NodeType.DEPOT:
			return "보급"
		Constants.NodeType.BEACON:
			return "비콘"
		_:
			return "알 수 없음"


static func get_node_type_color(node_type: Constants.NodeType) -> Color:
	match node_type:
		Constants.NodeType.START:
			return Color.WHITE
		Constants.NodeType.BATTLE:
			return Color.CORNFLOWER_BLUE
		Constants.NodeType.COMMANDER:
			return Color.GOLD
		Constants.NodeType.EQUIPMENT:
			return Color.MEDIUM_PURPLE
		Constants.NodeType.STORM:
			return Color.CRIMSON
		Constants.NodeType.BOSS:
			return Color.DARK_RED
		Constants.NodeType.REST:
			return Color.LIME_GREEN
		Constants.NodeType.GATE:
			return Color.CYAN
		Constants.NodeType.RESCUE:
			return Color.ORANGE
		Constants.NodeType.SALVAGE:
			return Color.SANDY_BROWN
		Constants.NodeType.DEPOT:
			return Color.MEDIUM_SEA_GREEN
		Constants.NodeType.BEACON:
			return Color.DEEP_SKY_BLUE
		_:
			return Color.GRAY
