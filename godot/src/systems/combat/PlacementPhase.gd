class_name PlacementPhase
extends Node

## 배치 페이즈 관리자
## Bad North 스타일: 전투 시작 전 크루 배치 + 실시간 전투 중 재배치 가능

# ===== SIGNALS =====

signal placement_started()
signal placement_ended()
signal crew_placed(crew: Node, tile_pos: Vector2i)
signal crew_selected(crew: Node)
signal valid_positions_updated(positions: Array)


# ===== CONFIGURATION =====

@export var placement_time_limit: float = 0.0  # 0 = 무제한
@export var auto_slow_motion: bool = false  # 비활성화
@export var slow_motion_scale: float = 0.3


# ===== STATE =====

var is_placement_active: bool = false
var is_pre_battle: bool = false  # 전투 전 배치 vs 전투 중 배치
var selected_crew: Node = null
var available_crews: Array = []  # 배치 가능한 크루
var placed_crews: Dictionary = {}  # crew -> tile_pos
var valid_placement_tiles: Array[Vector2i] = []
var _placement_timer: float = 0.0


# ===== REFERENCES =====

var _battle_map: Node = null  # BattleMap3D
var _tile_grid: Node = null
var _battle_controller: Node = null


# ===== LIFECYCLE =====

func _process(delta: float) -> void:
	if not is_placement_active:
		return

	# 배치 시간 제한
	if placement_time_limit > 0:
		_placement_timer -= delta
		if _placement_timer <= 0:
			end_placement()


# ===== PUBLIC API =====

## 초기화
func initialize(battle_map: Node, tile_grid: Node, battle_controller: Node = null) -> void:
	_battle_map = battle_map
	_tile_grid = tile_grid
	_battle_controller = battle_controller
	# Battle3DScene에서 클릭 이벤트를 처리하고 place_crew_at() 직접 호출


## 전투 전 배치 시작 (Select Your Squads 단계)
func start_pre_battle_placement(crews: Array, spawn_area: Array[Vector2i] = []) -> void:
	is_placement_active = true
	is_pre_battle = true
	available_crews = crews.duplicate()
	placed_crews.clear()
	_placement_timer = placement_time_limit

	# 유효한 배치 위치 계산
	if spawn_area.is_empty():
		_calculate_default_spawn_area()
	else:
		valid_placement_tiles = spawn_area

	# 첫 번째 크루 자동 선택
	if not available_crews.is_empty():
		selected_crew = available_crews[0]
		crew_selected.emit(selected_crew)

	placement_started.emit()
	valid_positions_updated.emit(valid_placement_tiles)

	# 범위 표시
	if _battle_map and _battle_map.has_method("show_move_range"):
		_battle_map.show_move_range(valid_placement_tiles, Color(0.3, 0.8, 0.3, 0.3))


## 전투 중 재배치 모드 (크루 선택 시)
func start_reposition_mode(crew: Node) -> void:
	if crew == null:
		return

	is_placement_active = true
	is_pre_battle = false
	selected_crew = crew

	# 이동 가능 범위 계산
	_calculate_movement_range(crew)

	crew_selected.emit(crew)
	valid_positions_updated.emit(valid_placement_tiles)

	# 범위 표시
	if _battle_map and _battle_map.has_method("show_move_range"):
		_battle_map.show_move_range(valid_placement_tiles)


## 배치 종료
func end_placement() -> void:
	is_placement_active = false
	is_pre_battle = false
	selected_crew = null
	valid_placement_tiles.clear()

	# 슬로우 모션 해제
	Engine.time_scale = 1.0

	# 범위 표시 제거
	if _battle_map and _battle_map.has_method("clear_range_display"):
		_battle_map.clear_range_display()

	placement_ended.emit()


## 크루 선택
func select_crew(crew: Node) -> void:
	if not is_placement_active:
		return

	selected_crew = crew
	crew_selected.emit(crew)

	if not is_pre_battle:
		_calculate_movement_range(crew)
		valid_positions_updated.emit(valid_placement_tiles)

		if _battle_map and _battle_map.has_method("show_move_range"):
			_battle_map.show_move_range(valid_placement_tiles)


## 크루 배치 실행
func place_crew_at(crew: Node, tile_pos: Vector2i) -> bool:
	if crew == null:
		return false

	if not _is_valid_placement(tile_pos):
		print("[PlacementPhase] Invalid placement at: ", tile_pos)
		return false

	# 기존 위치에서 제거
	if placed_crews.has(crew):
		var old_pos: Vector2i = placed_crews[crew]
		_clear_tile_occupant(old_pos)

	# 새 위치에 배치
	placed_crews[crew] = tile_pos
	_set_tile_occupant(tile_pos, crew)

	# 크루 위치 업데이트
	_move_crew_to_tile(crew, tile_pos)

	# 전투 전 배치: available_crews에서 제거 후 다음 크루 자동 선택
	if is_pre_battle and crew in available_crews:
		available_crews.erase(crew)
		if not available_crews.is_empty():
			selected_crew = available_crews[0]
			crew_selected.emit(selected_crew)
		else:
			selected_crew = null

	crew_placed.emit(crew, tile_pos)

	return true


## 모든 크루가 배치되었는지 확인
func are_all_crews_placed() -> bool:
	return _all_crews_placed()


## 배치 확정 (Deploy 버튼)
func confirm_placement() -> bool:
	if is_pre_battle and not _all_crews_placed():
		# 최소 1명은 배치해야 함
		if placed_crews.is_empty():
			return false

	end_placement()
	return true


## 배치된 크루 목록
func get_placed_crews() -> Dictionary:
	return placed_crews.duplicate()


## 남은 배치 시간
func get_remaining_time() -> float:
	return _placement_timer if placement_time_limit > 0 else -1.0


# ===== PRIVATE =====

# 참고: 크루 배치는 Battle3DScene._on_tile_right_clicked → place_crew_at() 호출로 처리됨


func _calculate_default_spawn_area() -> void:
	valid_placement_tiles.clear()

	if _tile_grid == null:
		return

	var width: int = _tile_grid.width if "width" in _tile_grid else 10
	var height: int = _tile_grid.height if "height" in _tile_grid else 10

	# 맵 중앙 영역을 기본 스폰 영역으로
	var margin := 2
	for y in range(margin, height - margin):
		for x in range(margin, width - margin):
			var tile_pos := Vector2i(x, y)
			if _is_tile_walkable(tile_pos) and not _is_tile_occupied(tile_pos):
				valid_placement_tiles.append(tile_pos)


func _calculate_movement_range(crew: Node) -> void:
	valid_placement_tiles.clear()

	if _tile_grid == null or crew == null:
		return

	var current_pos: Vector2i = Vector2i.ZERO
	if "tile_position" in crew:
		current_pos = crew.tile_position
	elif crew.has_meta("tile_pos"):
		current_pos = crew.get_meta("tile_pos")

	# 이동 범위 (기본 5타일)
	var move_range: int = 5
	if "movement_range" in crew:
		move_range = crew.movement_range

	# 경로 탐색으로 도달 가능한 타일
	if _tile_grid.has_method("get_reachable_tiles"):
		valid_placement_tiles = _tile_grid.get_reachable_tiles(current_pos, move_range)
	else:
		# 단순 맨해튼 거리
		var width: int = _tile_grid.width if "width" in _tile_grid else 10
		var height: int = _tile_grid.height if "height" in _tile_grid else 10

		for y in range(height):
			for x in range(width):
				var tile_pos := Vector2i(x, y)
				var dist := absi(x - current_pos.x) + absi(y - current_pos.y)
				if dist <= move_range and dist > 0:
					if _is_tile_walkable(tile_pos) and not _is_tile_occupied(tile_pos):
						valid_placement_tiles.append(tile_pos)


func _is_valid_placement(tile_pos: Vector2i) -> bool:
	return tile_pos in valid_placement_tiles


func _is_tile_walkable(tile_pos: Vector2i) -> bool:
	if _tile_grid == null:
		return true

	if _tile_grid.has_method("is_walkable_ignore_occupant"):
		return _tile_grid.is_walkable_ignore_occupant(tile_pos)
	elif _tile_grid.has_method("is_walkable"):
		return _tile_grid.is_walkable(tile_pos)

	return true


func _is_tile_occupied(tile_pos: Vector2i) -> bool:
	if _tile_grid == null:
		return false

	if _tile_grid.has_method("get_occupant"):
		return _tile_grid.get_occupant(tile_pos) != null

	# placed_crews에서 확인
	for crew in placed_crews:
		if placed_crews[crew] == tile_pos:
			return true

	return false


func _set_tile_occupant(tile_pos: Vector2i, occupant: Node) -> void:
	if _tile_grid and _tile_grid.has_method("set_occupant"):
		_tile_grid.set_occupant(tile_pos, occupant)


func _clear_tile_occupant(tile_pos: Vector2i) -> void:
	if _tile_grid and _tile_grid.has_method("clear_occupant"):
		_tile_grid.clear_occupant(tile_pos)


func _move_crew_to_tile(crew: Node, tile_pos: Vector2i) -> void:
	# 크루 위치 속성 업데이트
	if "tile_position" in crew:
		crew.tile_position = tile_pos

	crew.set_meta("tile_pos", tile_pos)

	# 월드 위치 업데이트
	if _battle_map and _battle_map.has_method("tile_to_world"):
		var world_pos: Vector3 = _battle_map.tile_to_world(tile_pos)
		if crew is Node3D:
			crew.position = world_pos
		elif crew is Node2D:
			crew.position = Vector2(world_pos.x, world_pos.z)


func _all_crews_placed() -> bool:
	return available_crews.is_empty() and not placed_crews.is_empty()
