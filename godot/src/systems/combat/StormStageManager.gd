class_name StormStageManager
extends Node

## 폭풍 스테이지 관리자
## Fog of War 활성화, 적 가시성 처리, Flare 연동


# ===== SIGNALS =====

signal storm_mode_activated()
signal storm_mode_deactivated()
signal enemy_revealed(enemy: Node)
signal enemy_hidden(enemy: Node)


# ===== CONFIGURATION =====

@export var crew_vision_range: int = 5
@export var flare_vision_range: int = 8


# ===== STATE =====

var is_storm_mode: bool = false
var _tile_grid = null  # TileGrid
var _battle_controller: Node = null
var _hidden_enemies: Dictionary = {}  # enemy_id -> enemy


# ===== LIFECYCLE =====

func _ready() -> void:
	_connect_signals()


func _process(delta: float) -> void:
	if not is_storm_mode:
		return

	# 시야 소스 시간 업데이트
	if _tile_grid:
		_tile_grid.update_vision_sources(delta)

	# 크루 위치 기반 시야 업데이트
	_update_crew_vision()

	# 적 가시성 업데이트
	_update_enemy_visibility()


func _connect_signals() -> void:
	if EventBus:
		EventBus.raven_ability_used.connect(_on_raven_ability_used)


# ===== PUBLIC API =====

## 초기화
func initialize(tile_grid, battle_controller: Node) -> void:
	_tile_grid = tile_grid
	_battle_controller = battle_controller


## 폭풍 모드 활성화
func activate_storm_mode() -> void:
	if is_storm_mode:
		return

	is_storm_mode = true

	if _tile_grid:
		_tile_grid.set_fog_of_war(true)

	# 모든 적 숨김 처리
	_hide_all_enemies()

	storm_mode_activated.emit()
	EventBus.show_toast.emit("폭풍 진입: 시야 제한!", Constants.ToastType.WARNING, 3.0)


## 폭풍 모드 비활성화
func deactivate_storm_mode() -> void:
	if not is_storm_mode:
		return

	is_storm_mode = false

	if _tile_grid:
		_tile_grid.set_fog_of_war(false)

	# 모든 적 표시
	_reveal_all_enemies()

	storm_mode_deactivated.emit()


## Flare 시야 추가
func add_flare_vision(position: Vector2i, duration: float) -> void:
	if _tile_grid:
		_tile_grid.add_vision_source(position, flare_vision_range, duration)

	# 즉시 가시성 업데이트
	_update_enemy_visibility()


## 적이 현재 보이는지 확인
func is_enemy_visible(enemy: Node) -> bool:
	if not is_storm_mode:
		return true

	if _tile_grid == null:
		return true

	var enemy_pos: Vector2i = enemy.tile_position if "tile_position" in enemy else Vector2i.ZERO
	return _tile_grid.is_tile_visible(enemy_pos)


# ===== PRIVATE =====

func _update_crew_vision() -> void:
	if _tile_grid == null or _battle_controller == null:
		return

	var crew_positions: Array[Vector2i] = []

	# 크루 위치 수집
	if "crews" in _battle_controller:
		for crew in _battle_controller.crews:
			if _is_crew_alive(crew):
				var pos: Vector2i = crew.tile_position if "tile_position" in crew else Vector2i.ZERO
				crew_positions.append(pos)

	_tile_grid.update_crew_vision(crew_positions)


func _update_enemy_visibility() -> void:
	if _battle_controller == null or not "enemies" in _battle_controller:
		return

	for enemy in _battle_controller.enemies:
		if not _is_entity_alive(enemy):
			continue

		var is_visible := is_enemy_visible(enemy)
		var was_hidden: bool = _hidden_enemies.has(enemy.get_instance_id())

		if is_visible and was_hidden:
			# 적 드러남
			_reveal_enemy(enemy)
		elif not is_visible and not was_hidden:
			# 적 숨김
			_hide_enemy(enemy)


func _hide_all_enemies() -> void:
	if _battle_controller == null or not "enemies" in _battle_controller:
		return

	for enemy in _battle_controller.enemies:
		if _is_entity_alive(enemy):
			_hide_enemy(enemy)


func _reveal_all_enemies() -> void:
	for enemy_id in _hidden_enemies.keys():
		var enemy = _hidden_enemies[enemy_id]
		if is_instance_valid(enemy):
			_reveal_enemy(enemy)

	_hidden_enemies.clear()


func _hide_enemy(enemy: Node) -> void:
	var enemy_id = enemy.get_instance_id()
	if _hidden_enemies.has(enemy_id):
		return

	_hidden_enemies[enemy_id] = enemy

	# 시각적 숨김
	if enemy.has_method("set_visible"):
		enemy.set_visible(false)
	elif "visible" in enemy:
		enemy.visible = false

	# 타겟팅 불가 플래그
	if "is_hidden" in enemy:
		enemy.is_hidden = true

	enemy_hidden.emit(enemy)


func _reveal_enemy(enemy: Node) -> void:
	var enemy_id = enemy.get_instance_id()
	_hidden_enemies.erase(enemy_id)

	# 시각적 표시
	if enemy.has_method("set_visible"):
		enemy.set_visible(true)
	elif "visible" in enemy:
		enemy.visible = true

	# 타겟팅 가능 플래그
	if "is_hidden" in enemy:
		enemy.is_hidden = false

	enemy_revealed.emit(enemy)


func _is_crew_alive(crew: Node) -> bool:
	if not is_instance_valid(crew):
		return false
	if "is_alive" in crew:
		return crew.is_alive
	return true


func _is_entity_alive(entity: Node) -> bool:
	if not is_instance_valid(entity):
		return false
	if "is_alive" in entity:
		return entity.is_alive
	return true


# ===== EVENT HANDLERS =====

func _on_raven_ability_used(ability: int) -> void:
	# Flare 능력 사용 시 시야 추가
	if ability == Constants.RavenAbility.FLARE:
		# RavenSystem에서 처리하므로 여기서는 추가 처리 없음
		pass
