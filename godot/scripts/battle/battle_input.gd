## BattleInput - 전투 입력 처리
## 크루 선택, 이동 명령, 스킬 사용
extends Node
class_name BattleInput

# ===========================================
# 상태
# ===========================================

enum InputMode {
	NORMAL,         # 일반 선택/이동
	SKILL_TARGET,   # 스킬 타겟 지정
	RAVEN_ABILITY,  # Raven 능력 타겟 지정
}

var mode: InputMode = InputMode.NORMAL
var selected_crew: CrewUnit = null
var pending_skill_id: String = ""
var pending_raven_ability: String = ""

# 참조
var battle_manager: BattleManager = null
var tile_renderer: TileRenderer = null
var camera: IsometricCamera = null
var pathfinder: Pathfinder = null
var grid: TileGrid = null


# ===========================================
# 시그널
# ===========================================

signal crew_selected(crew: CrewUnit)
signal crew_deselected()
signal move_command(crew: CrewUnit, target: Vector2i)
signal skill_command(crew: CrewUnit, skill_id: String, target: Vector2i)
signal raven_ability_command(ability_id: String, target: Vector2i)


# ===========================================
# 초기화
# ===========================================

func setup(manager: BattleManager, renderer: TileRenderer, cam: IsometricCamera) -> void:
	battle_manager = manager
	tile_renderer = renderer
	camera = cam
	grid = manager.grid
	pathfinder = manager.pathfinder


# ===========================================
# 입력 처리
# ===========================================

func _unhandled_input(event: InputEvent) -> void:
	if battle_manager == null or battle_manager.is_paused:
		return

	# 선택/클릭
	if event.is_action_pressed("select"):
		_handle_select()

	# 취소
	if event.is_action_pressed("cancel"):
		_handle_cancel()

	# 일시정지
	if event.is_action_pressed("pause"):
		battle_manager.toggle_pause()


func _handle_select() -> void:
	var grid_pos := tile_renderer.get_tile_at_mouse()

	match mode:
		InputMode.NORMAL:
			_handle_normal_select(grid_pos)
		InputMode.SKILL_TARGET:
			_handle_skill_target(grid_pos)
		InputMode.RAVEN_ABILITY:
			_handle_raven_target(grid_pos)


func _handle_cancel() -> void:
	match mode:
		InputMode.NORMAL:
			if selected_crew:
				_deselect_crew()
		InputMode.SKILL_TARGET, InputMode.RAVEN_ABILITY:
			_cancel_targeting()


# ===========================================
# 일반 선택/이동
# ===========================================

func _handle_normal_select(grid_pos: Vector2i) -> void:
	# 크루 선택 시도
	var crew := battle_manager.get_crew_at(grid_pos)
	if crew and crew.is_alive:
		_select_crew(crew)
		return

	# 이미 선택된 크루가 있으면 이동 명령
	if selected_crew and selected_crew.is_alive:
		if grid.is_walkable_v(grid_pos):
			_issue_move_command(grid_pos)
		else:
			# 적 클릭 시 공격 타겟 설정
			var enemy := battle_manager.get_enemy_at(grid_pos)
			if enemy:
				selected_crew.set_target(enemy)


func _select_crew(crew: CrewUnit) -> void:
	# 이전 선택 해제
	if selected_crew:
		selected_crew.deselect()

	selected_crew = crew
	selected_crew.select()

	# 슬로우 모션 활성화
	if camera:
		camera.enable_slow_motion()

	# 이동 가능 범위 표시
	_show_movement_range()

	crew_selected.emit(crew)
	EventBus.crew_selected.emit(crew)


func _deselect_crew() -> void:
	if selected_crew:
		selected_crew.deselect()

	selected_crew = null

	# 슬로우 모션 비활성화
	if camera:
		camera.disable_slow_motion()

	# 하이라이트 제거
	if tile_renderer:
		tile_renderer.clear_highlight()

	crew_deselected.emit()
	EventBus.crew_deselected.emit()


func _show_movement_range() -> void:
	if not selected_crew or not pathfinder or not tile_renderer:
		return

	# 이동 가능한 타일 계산
	var movement_points := 10  # 기본 이동력
	var reachable := pathfinder.get_reachable_tiles(selected_crew.grid_position, movement_points)

	tile_renderer.show_movement_range(reachable)


func _issue_move_command(target: Vector2i) -> void:
	if not selected_crew:
		return

	# 경로 확인
	var path := pathfinder.find_path(selected_crew.grid_position, target)
	if path.is_empty():
		return

	# 이동 시작
	selected_crew.move_to(target)
	move_command.emit(selected_crew, target)

	# 선택 유지하면서 범위 업데이트
	_show_movement_range()


# ===========================================
# 스킬 타겟팅
# ===========================================

func start_skill_targeting(skill_id: String) -> void:
	if not selected_crew:
		return

	mode = InputMode.SKILL_TARGET
	pending_skill_id = skill_id

	# 스킬 범위 표시
	_show_skill_range(skill_id)


func _handle_skill_target(grid_pos: Vector2i) -> void:
	if not selected_crew:
		_cancel_targeting()
		return

	# 스킬 사용
	var success := selected_crew.use_skill(grid_pos)

	if success:
		skill_command.emit(selected_crew, pending_skill_id, grid_pos)

	_cancel_targeting()


func _show_skill_range(skill_id: String) -> void:
	if not selected_crew or not tile_renderer:
		return

	# 스킬별 범위 계산
	var skill_range := 5  # 기본 범위
	var tiles := grid.get_tiles_in_range(selected_crew.grid_position, 0, skill_range)

	var skill_tiles: Array[Vector2i] = []
	for t in tiles:
		if grid.is_walkable_v(t):
			skill_tiles.append(t)

	tile_renderer.show_attack_range(skill_tiles, Color(0.9, 0.6, 0.2, 0.3))


# ===========================================
# Raven 능력 타겟팅
# ===========================================

func start_raven_targeting(ability_id: String) -> void:
	mode = InputMode.RAVEN_ABILITY
	pending_raven_ability = ability_id

	# 능력별 범위 표시
	_show_raven_range(ability_id)


func _handle_raven_target(grid_pos: Vector2i) -> void:
	# Raven 능력 사용
	raven_ability_command.emit(pending_raven_ability, grid_pos)
	EventBus.raven_ability_used.emit(pending_raven_ability)

	_cancel_targeting()


func _show_raven_range(ability_id: String) -> void:
	if not tile_renderer:
		return

	# 전체 맵 범위 (대부분의 Raven 능력)
	var tiles: Array[Vector2i] = []
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.is_walkable(x, y):
				tiles.append(Vector2i(x, y))

	tile_renderer.show_attack_range(tiles, Color(0.4, 0.8, 0.9, 0.2))


# ===========================================
# 타겟팅 취소
# ===========================================

func _cancel_targeting() -> void:
	mode = InputMode.NORMAL
	pending_skill_id = ""
	pending_raven_ability = ""

	# 이동 범위로 복귀
	if selected_crew:
		_show_movement_range()
	elif tile_renderer:
		tile_renderer.clear_highlight()


# ===========================================
# 유틸리티
# ===========================================

func get_selected_crew() -> CrewUnit:
	return selected_crew


func is_crew_selected() -> bool:
	return selected_crew != null


func is_targeting() -> bool:
	return mode != InputMode.NORMAL
