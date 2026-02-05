class_name TileGrid
extends Node2D

## 타일 기반 그리드 시스템
## [br][br]
## 경로 탐색, 시야선 계산, 타일 관리 등 전투 맵의 핵심 기능을 제공합니다.

# Preloads to avoid class_name resolution issues
const PathfindingClass = preload("res://src/systems/combat/Pathfinding.gd")
const LineOfSightClass = preload("res://src/systems/combat/LineOfSight.gd")
const UtilsClass = preload("res://src/utils/Utils.gd")
const ConstantsScript = preload("res://src/autoload/Constants.gd")

# Load at runtime to avoid circular reference issues
var GridTileDataClass: GDScript

func _init() -> void:
	GridTileDataClass = load("res://src/systems/combat/TileData.gd")


# ===== SIGNALS =====

signal tile_changed(pos: Vector2i, old_type: int, new_type: int)  # TileType enum values
signal occupant_changed(pos: Vector2i, old_occupant: Node, new_occupant: Node)
signal tile_visibility_changed(pos: Vector2i, is_visible: bool)
signal fog_of_war_toggled(enabled: bool)


# ===== CONSTANTS =====

const TILE_SIZE: int = 32  # From ConstantsScript.TILE_SIZE


# ===== EXPORTS =====

@export var width: int = 10
@export var height: int = 10


# ===== PROPERTIES =====

var tiles: Array = []  ## 2D array of GridTileData


# ===== PRIVATE =====

var _pathfinder  # Pathfinding
var _los_calculator  # LineOfSight

# ===== FOG OF WAR =====

var fog_of_war_enabled: bool = false
var _visible_tiles: Dictionary = {}  # Vector2i -> bool
var _vision_sources: Array[Dictionary] = []  # [{position, radius, duration, id}]
var _crew_vision_range: int = 5  # 크루 기본 시야 범위


# ===== LIFECYCLE =====

func _ready() -> void:
	_pathfinder = PathfindingClass.new(self)
	_los_calculator = LineOfSightClass.new(self)


# ===== INITIALIZATION =====

## 빈 그리드를 초기화합니다.
## [br][br]
## [param w]: 그리드 너비
## [param h]: 그리드 높이
func initialize(w: int, h: int) -> void:
	width = w
	height = h
	tiles.clear()

	for y in range(height):
		var row: Array = []
		for x in range(width):
			var tile = GridTileDataClass.new(Vector2i(x, y), ConstantsScript.TileType.FLOOR)
			row.append(tile)
		tiles.append(row)

	# Pathfinder와 LOS 재초기화
	if _pathfinder == null:
		_pathfinder = PathfindingClass.new(self)
	if _los_calculator == null:
		_los_calculator = LineOfSightClass.new(self)


## StationData에서 그리드를 초기화합니다.
## [br][br]
## [param station]: 정거장 데이터
func initialize_from_station_data(station) -> void:
	if station == null:
		push_warning("TileGrid.initialize_from_station_data: station is null")
		return

	width = station.width
	height = station.height
	tiles.clear()

	for y in range(height):
		var row: Array = []
		for x in range(width):
			var tile_type: ConstantsScript.TileType = station.tiles[y][x]
			var tile = GridTileDataClass.new(Vector2i(x, y), tile_type)

			# 고도 설정
			if station.get("height_map") and station.height_map.size() > y:
				if station.height_map[y].size() > x:
					tile.elevation = station.height_map[y][x]

			row.append(tile)
		tiles.append(row)

	# 진입점 마킹
	if station.get("entry_points"):
		for entry in station.entry_points:
			if is_valid_position(entry):
				get_tile(entry).is_entry_point = true

	# Pathfinder와 LOS 재초기화
	if _pathfinder == null:
		_pathfinder = PathfindingClass.new(self)
	if _los_calculator == null:
		_los_calculator = LineOfSightClass.new(self)


# ===== TILE ACCESS =====

## 주어진 위치의 타일을 반환합니다.
## [br][br]
## [param pos]: 타일 좌표
## [return]: GridTileData 또는 null
func get_tile(pos: Vector2i):
	if not is_valid_position(pos):
		return null
	return tiles[pos.y][pos.x]


## 주어진 위치의 타일 타입을 변경합니다.
## [br][br]
## [param pos]: 타일 좌표
## [param new_type]: 새 타일 타입
func set_tile_type(pos: Vector2i, new_type: ConstantsScript.TileType) -> void:
	if not is_valid_position(pos):
		return

	var tile = tiles[pos.y][pos.x]
	var old_type: ConstantsScript.TileType = tile.type
	tile.type = new_type
	tile_changed.emit(pos, old_type, new_type)


## 주어진 위치가 유효한 좌표인지 확인합니다.
## [br][br]
## [param pos]: 타일 좌표
## [return]: 유효 여부
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


## 주어진 위치가 이동 가능한지 확인합니다 (점유자 고려).
## [br][br]
## [param pos]: 타일 좌표
## [return]: 이동 가능 여부
func is_walkable(pos: Vector2i) -> bool:
	var tile = get_tile(pos)
	if tile == null:
		return false
	return tile.is_walkable() and tile.occupant == null


## 주어진 위치가 이동 가능한지 확인합니다 (점유자 무시).
## [br][br]
## [param pos]: 타일 좌표
## [return]: 이동 가능 여부
func is_walkable_ignore_occupant(pos: Vector2i) -> bool:
	var tile = get_tile(pos)
	if tile == null:
		return false
	return tile.is_walkable()


# ===== OCCUPANCY =====

## 타일에 점유자를 설정합니다.
## [br][br]
## [param pos]: 타일 좌표
## [param occupant]: 점유할 엔티티
func set_occupant(pos: Vector2i, occupant: Node) -> void:
	var tile = get_tile(pos)
	if tile == null:
		return

	var old_occupant: Node = tile.occupant
	tile.occupant = occupant
	occupant_changed.emit(pos, old_occupant, occupant)


## 타일의 점유자를 제거합니다.
## [br][br]
## [param pos]: 타일 좌표
func clear_occupant(pos: Vector2i) -> void:
	set_occupant(pos, null)


## 타일의 점유자를 반환합니다.
## [br][br]
## [param pos]: 타일 좌표
## [return]: 점유 엔티티 또는 null
func get_occupant(pos: Vector2i) -> Node:
	var tile = get_tile(pos)
	if tile == null:
		return null
	return tile.occupant


# ===== NEIGHBORS =====

## 주어진 위치의 이웃 타일들을 반환합니다.
## [br][br]
## [param pos]: 중심 타일 좌표
## [param include_diagonal]: 대각선 포함 여부
## [return]: 이웃 타일 좌표 배열
func get_neighbors(pos: Vector2i, include_diagonal: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	# 4방향
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),  # 상
		Vector2i(1, 0),   # 우
		Vector2i(0, 1),   # 하
		Vector2i(-1, 0),  # 좌
	]

	# 대각선 포함
	if include_diagonal:
		directions.append(Vector2i(1, -1))   # 우상
		directions.append(Vector2i(1, 1))    # 우하
		directions.append(Vector2i(-1, 1))   # 좌하
		directions.append(Vector2i(-1, -1))  # 좌상

	for dir in directions:
		var neighbor := pos + dir
		if is_valid_position(neighbor):
			result.append(neighbor)

	return result


## 주어진 위치의 이동 가능한 이웃 타일들을 반환합니다.
## [br][br]
## [param pos]: 중심 타일 좌표
## [param include_diagonal]: 대각선 포함 여부
## [return]: 이동 가능한 이웃 타일 좌표 배열
func get_walkable_neighbors(pos: Vector2i, include_diagonal: bool = false) -> Array[Vector2i]:
	var neighbors := get_neighbors(pos, include_diagonal)
	var result: Array[Vector2i] = []

	for n in neighbors:
		if is_walkable(n):
			result.append(n)

	return result


# ===== PATHFINDING =====

## 두 지점 사이의 경로를 찾습니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [param ignore_occupants]: 점유자 무시 여부
## [return]: 경로 타일 배열 (시작점 제외, 목표점 포함)
func find_path(from: Vector2i, to: Vector2i, ignore_occupants: bool = false) -> Array[Vector2i]:
	if _pathfinder == null:
		_pathfinder = PathfindingClass.new(self)
	return _pathfinder.find_path(from, to, ignore_occupants)


## 주어진 위치에서 도달 가능한 모든 타일을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param max_distance]: 최대 이동 거리
## [return]: 도달 가능한 타일 좌표 배열
func get_reachable_tiles(from: Vector2i, max_distance: int) -> Array[Vector2i]:
	if _pathfinder == null:
		_pathfinder = PathfindingClass.new(self)
	return _pathfinder.get_reachable_tiles(from, max_distance)


# ===== LINE OF SIGHT =====

## 두 지점 사이에 시야선이 있는지 확인합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [return]: 시야선 존재 여부
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if _los_calculator == null:
		_los_calculator = LineOfSightClass.new(self)
	return _los_calculator.has_los(from, to)


## 두 지점 사이의 시야선 경로를 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [return]: 시야선 경로 타일 배열
func get_line_of_sight(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if _los_calculator == null:
		_los_calculator = LineOfSightClass.new(self)
	return _los_calculator.get_los_tiles(from, to)


## 주어진 위치에서 볼 수 있는 모든 타일을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param max_range]: 최대 시야 거리
## [return]: 가시 타일 좌표 배열
func get_visible_tiles(from: Vector2i, max_range: int) -> Array[Vector2i]:
	if _los_calculator == null:
		_los_calculator = LineOfSightClass.new(self)
	return _los_calculator.get_visible_tiles(from, max_range)


# ===== RANGE QUERIES =====

## 범위 내의 모든 타일을 반환합니다.
## [br][br]
## [param center]: 중심 타일 좌표
## [param range_val]: 범위 반경
## [param shape]: 범위 모양 ("circle", "square", "diamond")
## [return]: 범위 내 타일 좌표 배열
func get_tiles_in_range(center: Vector2i, range_val: int, shape: String = "circle") -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	match shape:
		"circle":
			for y in range(-range_val, range_val + 1):
				for x in range(-range_val, range_val + 1):
					var pos := center + Vector2i(x, y)
					if is_valid_position(pos):
						var dist := UtilsClass.euclidean_distance(
							Vector2(center.x, center.y),
							Vector2(pos.x, pos.y)
						)
						if dist <= range_val:
							result.append(pos)

		"square":
			for y in range(-range_val, range_val + 1):
				for x in range(-range_val, range_val + 1):
					var pos := center + Vector2i(x, y)
					if is_valid_position(pos):
						result.append(pos)

		"diamond":
			for y in range(-range_val, range_val + 1):
				for x in range(-range_val, range_val + 1):
					var pos := center + Vector2i(x, y)
					if is_valid_position(pos):
						if abs(x) + abs(y) <= range_val:
							result.append(pos)

	return result


## 주어진 방향으로 뻗은 타일들을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param direction]: 방향 벡터
## [param max_distance]: 최대 거리
## [return]: 경로 상의 타일 좌표 배열
func get_tiles_in_direction(from: Vector2i, direction: Vector2, max_distance: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := Vector2(from.x, from.y)
	var dir_normalized := direction.normalized()

	for i in range(max_distance):
		current += dir_normalized
		var tile_pos := Vector2i(roundi(current.x), roundi(current.y))

		if not is_valid_position(tile_pos):
			break

		if tile_pos != from and not result.has(tile_pos):
			result.append(tile_pos)

			# 벽에 막히면 중단
			var tile = get_tile(tile_pos)
			if tile and tile.is_blocking_los():
				break

	return result


# ===== COORDINATE CONVERSION =====

## 월드 좌표를 타일 좌표로 변환합니다.
## [br][br]
## [param world_pos]: 월드 좌표
## [return]: 타일 좌표
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / TILE_SIZE),
		int(world_pos.y / TILE_SIZE)
	)


## 타일 좌표를 월드 좌표로 변환합니다 (타일 중심).
## [br][br]
## [param tile_pos]: 타일 좌표
## [return]: 월드 좌표 (타일 중심)
func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		tile_pos.x * TILE_SIZE + TILE_SIZE / 2,
		tile_pos.y * TILE_SIZE + TILE_SIZE / 2
	)


## 타일 좌표를 월드 좌표로 변환합니다 (타일 좌상단).
## [br][br]
## [param tile_pos]: 타일 좌표
## [return]: 월드 좌표 (타일 좌상단)
func tile_to_world_top_left(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)


# ===== ELEVATION =====

## 주어진 위치의 고도를 반환합니다.
## [br][br]
## [param pos]: 타일 좌표
## [return]: 고도 값
func get_elevation(pos: Vector2i) -> int:
	var tile = get_tile(pos)
	if tile == null:
		return 0
	return tile.elevation


## 고도 차이에 따른 데미지 보너스를 반환합니다.
## [br][br]
## [param attacker_pos]: 공격자 타일 좌표
## [param target_pos]: 타겟 타일 좌표
## [return]: 데미지 보너스 비율
func get_elevation_bonus(attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	var attacker_elev := get_elevation(attacker_pos)
	var target_elev := get_elevation(target_pos)

	if attacker_elev > target_elev:
		var constants_node := get_node_or_null("/root/Constants")
		if constants_node and constants_node.BALANCE.has("combat"):
			return constants_node.BALANCE.combat.get("elevation_damage_bonus", 0.2)
		return 0.2  # Default fallback
	return 0.0


# ===== ENTRY POINTS =====

## 모든 진입점을 반환합니다.
## [br][br]
## [return]: 진입점 타일 좌표 배열
func get_entry_points() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if tiles[y][x].is_entry_point:
				result.append(Vector2i(x, y))
	return result


# ===== FACILITIES =====

## 모든 시설 타일을 반환합니다.
## [br][br]
## [return]: 시설 타일 좌표 배열
func get_facility_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if tiles[y][x].type == ConstantsScript.TileType.FACILITY:
				result.append(Vector2i(x, y))
	return result


## 타일에 시설을 설정합니다.
## [br][br]
## [param pos]: 타일 좌표
## [param facility]: 시설 노드
func set_facility(pos: Vector2i, facility: Node) -> void:
	var tile = get_tile(pos)
	if tile:
		tile.facility = facility
		tile.type = ConstantsScript.TileType.FACILITY


## 주어진 위치의 시설을 반환합니다.
## [br][br]
## [param pos]: 타일 좌표
## [return]: 시설 노드 또는 null
func get_facility_at(pos: Vector2i) -> Node:
	var tile = get_tile(pos)
	if tile:
		return tile.facility
	return null


# ===== DEBUG =====

## 그리드를 콘솔에 출력합니다.
func print_grid() -> void:
	var symbols: Dictionary = {
		ConstantsScript.TileType.VOID: " ",
		ConstantsScript.TileType.FLOOR: ".",
		ConstantsScript.TileType.WALL: "#",
		ConstantsScript.TileType.AIRLOCK: "A",
		ConstantsScript.TileType.ELEVATED: "^",
		ConstantsScript.TileType.LOWERED: "v",
		ConstantsScript.TileType.FACILITY: "F",
		ConstantsScript.TileType.COVER_HALF: "-",
		ConstantsScript.TileType.COVER_FULL: "=",
	}

	for y in range(height):
		var line := ""
		for x in range(width):
			var tile = tiles[y][x]
			line += symbols.get(tile.type, "?")
		print(line)


# ===== FOG OF WAR SYSTEM =====

## Fog of War 활성화/비활성화
func set_fog_of_war(enabled: bool) -> void:
	fog_of_war_enabled = enabled
	fog_of_war_toggled.emit(enabled)

	if enabled:
		_recalculate_visibility()
	else:
		# 비활성화 시 모든 타일 가시
		_visible_tiles.clear()


## 타일이 현재 보이는지 확인
func is_tile_visible(pos: Vector2i) -> bool:
	if not fog_of_war_enabled:
		return true
	return _visible_tiles.get(pos, false)


## 시야 소스 추가 (Flare 등)
func add_vision_source(pos: Vector2i, radius: int, duration: float = -1.0) -> int:
	var source_id: int = _vision_sources.size()
	var source := {
		"id": source_id,
		"position": pos,
		"radius": radius,
		"duration": duration,  # -1이면 영구
		"remaining": duration
	}
	_vision_sources.append(source)
	_recalculate_visibility()
	return source_id


## 시야 소스 제거
func remove_vision_source(pos_or_id: Variant) -> void:
	if pos_or_id is int:
		# ID로 제거
		for i in range(_vision_sources.size() - 1, -1, -1):
			if _vision_sources[i].id == pos_or_id:
				_vision_sources.remove_at(i)
				break
	elif pos_or_id is Vector2i:
		# 위치로 제거
		for i in range(_vision_sources.size() - 1, -1, -1):
			if _vision_sources[i].position == pos_or_id:
				_vision_sources.remove_at(i)
				break

	_recalculate_visibility()


## 시야 소스 시간 업데이트 (delta마다 호출)
func update_vision_sources(delta: float) -> void:
	var changed := false

	for i in range(_vision_sources.size() - 1, -1, -1):
		var source: Dictionary = _vision_sources[i]
		if source.duration > 0:  # 시간 제한이 있는 경우
			source.remaining -= delta
			if source.remaining <= 0:
				_vision_sources.remove_at(i)
				changed = true

	if changed:
		_recalculate_visibility()


## 크루 위치로 시야 업데이트
func update_crew_vision(crew_positions: Array[Vector2i]) -> void:
	if not fog_of_war_enabled:
		return

	# 크루 시야 소스 갱신 (임시 소스로 처리)
	# 기존 크루 시야 제거
	for i in range(_vision_sources.size() - 1, -1, -1):
		if _vision_sources[i].get("is_crew", false):
			_vision_sources.remove_at(i)

	# 새 크루 시야 추가
	for pos in crew_positions:
		_vision_sources.append({
			"id": -1,  # 크루 시야는 ID 없음
			"position": pos,
			"radius": _crew_vision_range,
			"duration": -1.0,
			"remaining": -1.0,
			"is_crew": true
		})

	_recalculate_visibility()


## 시야 재계산
func _recalculate_visibility() -> void:
	if not fog_of_war_enabled:
		return

	var old_visible := _visible_tiles.duplicate()
	_visible_tiles.clear()

	# 모든 시야 소스에서 가시 타일 계산
	for source in _vision_sources:
		var visible_from_source := get_visible_tiles(source.position, source.radius)
		for tile_pos in visible_from_source:
			_visible_tiles[tile_pos] = true

	# 변경된 타일에 대해 시그널 발생
	for pos in _visible_tiles.keys():
		if not old_visible.get(pos, false):
			tile_visibility_changed.emit(pos, true)

	for pos in old_visible.keys():
		if not _visible_tiles.get(pos, false):
			tile_visibility_changed.emit(pos, false)


## 모든 가시 타일 반환
func get_all_visible_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in _visible_tiles.keys():
		if _visible_tiles[pos]:
			result.append(pos)
	return result


## 위치가 어둠 속인지 확인 (적 숨김용)
func is_in_fog(pos: Vector2i) -> bool:
	if not fog_of_war_enabled:
		return false
	return not _visible_tiles.get(pos, false)
