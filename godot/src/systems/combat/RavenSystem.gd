class_name RavenSystem
extends Node

## Raven 드론 능력 시스템
## Scout, Flare, Resupply, Orbital Strike 4종 능력 관리


# ===== SIGNALS =====

signal ability_used(ability: Constants.RavenAbility)
signal ability_failed(ability: Constants.RavenAbility, reason: String)
signal ability_targeting_started(ability: Constants.RavenAbility)
signal ability_targeting_cancelled()


# ===== CONFIGURATION =====

@export var scout_preview_duration: float = 10.0
@export var flare_duration: float = 10.0
@export var flare_radius: int = 5
@export var resupply_radius: int = 3
@export var resupply_heal_percent: float = 0.5
@export var orbital_strike_radius: int = 2
@export var orbital_strike_damage: int = 50
@export var orbital_strike_delay: float = 1.5


# ===== STATE =====

var _is_targeting: bool = false
var _targeting_ability: Constants.RavenAbility
var _active_flares: Array[Dictionary] = []


# ===== REFERENCES =====

var _battle_controller: Node = null
var facility_bonus_manager = null  # FacilityBonusManager
var storm_stage_manager = null  # StormStageManager


func _ready() -> void:
	_battle_controller = get_parent()


func _process(delta: float) -> void:
	_process_flares(delta)


# ===== PUBLIC API =====

## 능력 사용 가능 여부
func can_use(ability: Constants.RavenAbility) -> bool:
	var charges := get_charges(ability)
	return charges != 0  # -1은 무제한, 0은 사용 불가


## 능력 실행 (타겟팅 불필요한 것들)
func execute_ability(ability: Constants.RavenAbility, target: Variant = null) -> bool:
	if not can_use(ability):
		ability_failed.emit(ability, "no_charges")
		return false

	var success := false

	match ability:
		Constants.RavenAbility.SCOUT:
			success = _execute_scout()
		Constants.RavenAbility.FLARE:
			if target != null:
				success = _execute_flare(target)
			else:
				ability_failed.emit(ability, "no_target")
				return false
		Constants.RavenAbility.RESUPPLY:
			if target != null:
				success = _execute_resupply(target)
			else:
				ability_failed.emit(ability, "no_target")
				return false
		Constants.RavenAbility.ORBITAL_STRIKE:
			if target != null:
				success = _execute_orbital_strike(target)
			else:
				ability_failed.emit(ability, "no_target")
				return false

	if success:
		GameState.use_raven_ability(ability)
		ability_used.emit(ability)

	return success


## 타겟팅 시작
func start_targeting(ability: Constants.RavenAbility) -> void:
	if not can_use(ability):
		ability_failed.emit(ability, "no_charges")
		return

	# Scout은 타겟팅 불필요
	if ability == Constants.RavenAbility.SCOUT:
		execute_ability(ability)
		return

	_is_targeting = true
	_targeting_ability = ability
	ability_targeting_started.emit(ability)

	if ability == Constants.RavenAbility.ORBITAL_STRIKE:
		EventBus.orbital_strike_targeting_started.emit()


## 타겟팅 취소
func cancel_targeting() -> void:
	if _is_targeting:
		_is_targeting = false
		ability_targeting_cancelled.emit()
		EventBus.skill_targeting_ended.emit()


## 타겟팅 확인
func confirm_targeting(target_pos: Vector2i) -> void:
	if not _is_targeting:
		return

	var ability := _targeting_ability
	_is_targeting = false

	execute_ability(ability, target_pos)


## 남은 충전 수 (시설 보너스 포함)
func get_charges(ability: Constants.RavenAbility) -> int:
	var base_charges: int = GameState.get_raven_charges(ability)

	# 무제한(-1)이면 그대로 반환
	if base_charges < 0:
		return base_charges

	# 통신탑 보너스: +1 추가 충전
	var extra: int = 0
	if facility_bonus_manager:
		extra = facility_bonus_manager.get_raven_extra_charges()

	return base_charges + extra


## 타겟팅 중인지
func is_targeting() -> bool:
	return _is_targeting


## 현재 타겟팅 중인 능력
func get_targeting_ability() -> Constants.RavenAbility:
	return _targeting_ability


## 모든 능력 정보
func get_all_abilities() -> Array[Dictionary]:
	return [
		{
			"id": Constants.RavenAbility.SCOUT,
			"name": "Scout",
			"name_ko": "정찰",
			"description": "다음 웨이브 적 구성 미리보기",
			"charges": get_charges(Constants.RavenAbility.SCOUT),
			"needs_target": false
		},
		{
			"id": Constants.RavenAbility.FLARE,
			"name": "Flare",
			"name_ko": "조명탄",
			"description": "지정 위치 주변 시야 확보 (%.0f초)" % flare_duration,
			"charges": get_charges(Constants.RavenAbility.FLARE),
			"needs_target": true,
			"radius": flare_radius
		},
		{
			"id": Constants.RavenAbility.RESUPPLY,
			"name": "Resupply",
			"name_ko": "보급",
			"description": "지정 위치 크루 체력 %.0f%% 회복" % (resupply_heal_percent * 100),
			"charges": get_charges(Constants.RavenAbility.RESUPPLY),
			"needs_target": true,
			"radius": resupply_radius
		},
		{
			"id": Constants.RavenAbility.ORBITAL_STRIKE,
			"name": "Orbital Strike",
			"name_ko": "궤도 폭격",
			"description": "지정 위치 범위 피해 (아군 포함!)",
			"charges": get_charges(Constants.RavenAbility.ORBITAL_STRIKE),
			"needs_target": true,
			"radius": orbital_strike_radius,
			"warning": "아군 피해 주의"
		}
	]


# ===== ABILITY IMPLEMENTATIONS =====

## Scout - 다음 웨이브 미리보기
func _execute_scout() -> bool:
	if not _battle_controller:
		return false

	# WaveManager에서 다음 웨이브 정보 가져오기
	var preview: Array = []

	if _battle_controller.has_node("WaveManager"):
		var wave_manager := _battle_controller.get_node("WaveManager")
		if wave_manager.has_method("get_next_wave_preview"):
			preview = wave_manager.get_next_wave_preview()

	# UI에 표시
	EventBus.wave_started.emit(-1, -1, preview)  # -1은 프리뷰 표시

	_spawn_effect("scout", Vector2.ZERO, {"preview": preview})

	return true


## Flare - 범위 시야 확보
func _execute_flare(target: Variant) -> bool:
	var target_pos: Vector2i = _parse_target_position(target)
	if target_pos == Vector2i(-9999, -9999):
		return false

	var grid := _get_tile_grid()
	if grid == null:
		return false

	# 플레어 데이터 저장
	var flare_data := {
		"position": target_pos,
		"world_position": _tile_to_world(grid, target_pos),
		"remaining": flare_duration,
		"radius": flare_radius
	}
	_active_flares.append(flare_data)

	# 시야 시스템에 알림 (있다면)
	if grid.has_method("add_vision_source"):
		grid.add_vision_source(target_pos, flare_radius, flare_duration)

	# 폭풍 스테이지 매니저에도 알림
	if storm_stage_manager and storm_stage_manager.has_method("add_flare_vision"):
		storm_stage_manager.add_flare_vision(target_pos, flare_duration)

	_spawn_effect("flare", flare_data.world_position, {"radius": flare_radius * Constants.TILE_SIZE})

	return true


func _process_flares(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_active_flares.size()):
		_active_flares[i].remaining -= delta
		if _active_flares[i].remaining <= 0:
			to_remove.append(i)

	# 역순으로 제거
	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		var flare := _active_flares[idx]

		# 시야 시스템에서 제거
		var grid := _get_tile_grid()
		if grid and grid.has_method("remove_vision_source"):
			grid.remove_vision_source(flare.position)

		_active_flares.remove_at(idx)


## Resupply - 범위 내 크루 회복
func _execute_resupply(target: Variant) -> bool:
	var target_pos: Vector2i = _parse_target_position(target)
	if target_pos == Vector2i(-9999, -9999):
		return false

	var grid := _get_tile_grid()
	if grid == null:
		return false

	var affected_tiles := _get_tiles_in_range(target_pos, resupply_radius)
	affected_tiles.append(target_pos)

	var healed_count := 0

	# 범위 내 아군 크루 회복
	if _battle_controller and "crews" in _battle_controller:
		for crew in _battle_controller.crews:
			if not crew.is_alive:
				continue

			var crew_pos: Vector2i = crew.tile_position
			if _is_in_tiles(crew_pos, affected_tiles):
				var max_hp := 100
				if "max_hp" in crew:
					max_hp = crew.max_hp

				var heal_amount := int(max_hp * resupply_heal_percent)

				if crew.has_method("heal"):
					crew.heal(heal_amount)
				elif "current_hp" in crew:
					crew.current_hp = mini(crew.current_hp + heal_amount, max_hp)

				EventBus.show_floating_text.emit("+%d" % heal_amount, crew.global_position, Color.GREEN)
				healed_count += 1

	var world_pos := _tile_to_world(grid, target_pos)
	_spawn_effect("resupply", world_pos, {
		"radius": resupply_radius * Constants.TILE_SIZE,
		"healed_count": healed_count
	})

	return true


## Orbital Strike - 범위 피해 (아군 포함!)
func _execute_orbital_strike(target: Variant) -> bool:
	var target_pos: Vector2i = _parse_target_position(target)
	if target_pos == Vector2i(-9999, -9999):
		return false

	var grid := _get_tile_grid()
	if grid == null:
		return false

	var world_pos := _tile_to_world(grid, target_pos)

	# 타겟팅 표시
	EventBus.orbital_strike_fired.emit(target_pos)

	# 딜레이 후 폭발
	var timer := get_tree().create_timer(orbital_strike_delay)
	timer.timeout.connect(_on_orbital_strike_impact.bind(target_pos, world_pos))

	# 경고 이펙트
	_spawn_effect("orbital_warning", world_pos, {
		"radius": orbital_strike_radius * Constants.TILE_SIZE,
		"delay": orbital_strike_delay
	})

	return true


func _on_orbital_strike_impact(target_pos: Vector2i, world_pos: Vector2) -> void:
	var affected_tiles := _get_tiles_in_range(target_pos, orbital_strike_radius)
	affected_tiles.append(target_pos)

	var grid := _get_tile_grid()

	# 범위 내 모든 유닛에 피해 (아군 포함!)
	for tile_pos in affected_tiles:
		var occupant := _get_occupant(grid, tile_pos) if grid else null
		if occupant and occupant.has_method("take_damage"):
			occupant.take_damage(orbital_strike_damage, Constants.DamageType.EXPLOSIVE, self)

	# 크루도 확인 (grid occupant가 아닐 수 있음)
	if _battle_controller and "crews" in _battle_controller:
		for crew in _battle_controller.crews:
			if not crew.is_alive:
				continue
			if _is_in_tiles(crew.tile_position, affected_tiles):
				crew.take_damage(orbital_strike_damage, Constants.DamageType.EXPLOSIVE, self)

	# 적도 확인
	if _battle_controller and "enemies" in _battle_controller:
		for enemy in _battle_controller.enemies:
			if not enemy.is_alive:
				continue
			if _is_in_tiles(enemy.tile_position, affected_tiles):
				enemy.take_damage(orbital_strike_damage, Constants.DamageType.EXPLOSIVE, self)

	# 폭발 이펙트
	_spawn_effect("orbital_explosion", world_pos, {
		"radius": orbital_strike_radius * Constants.TILE_SIZE
	})

	# 화면 흔들림
	EventBus.screen_shake.emit(10.0, 0.5)


# ===== UTILITY FUNCTIONS =====

func _parse_target_position(target: Variant) -> Vector2i:
	if target is Vector2i:
		return target
	elif target is Vector2:
		var grid := _get_tile_grid()
		if grid:
			return _world_to_tile(grid, target)
		return Vector2i(int(target.x / Constants.TILE_SIZE), int(target.y / Constants.TILE_SIZE))
	return Vector2i(-9999, -9999)  # 잘못된 값


func _get_tile_grid() -> Node:
	if _battle_controller and _battle_controller.has_method("get_tile_grid"):
		return _battle_controller.get_tile_grid()
	return null


func _get_tiles_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dx in range(-range_val, range_val + 1):
		for dy in range(-range_val, range_val + 1):
			if abs(dx) + abs(dy) <= range_val and (dx != 0 or dy != 0):
				tiles.append(Vector2i(center.x + dx, center.y + dy))
	return tiles


func _is_in_tiles(pos: Vector2i, tiles: Array) -> bool:
	for tile_pos in tiles:
		if tile_pos is Vector2i and tile_pos == pos:
			return true
	return pos in tiles


func _get_occupant(grid: Node, pos: Vector2i) -> Node:
	if grid and grid.has_method("get_occupant"):
		return grid.get_occupant(pos)
	return null


func _world_to_tile(grid: Node, world_pos: Vector2) -> Vector2i:
	if grid.has_method("world_to_tile"):
		return grid.world_to_tile(world_pos)
	return Vector2i(int(world_pos.x / Constants.TILE_SIZE), int(world_pos.y / Constants.TILE_SIZE))


func _tile_to_world(grid: Node, tile_pos: Vector2i) -> Vector2:
	if grid.has_method("tile_to_world"):
		return grid.tile_to_world(tile_pos)
	return Vector2(tile_pos.x * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF,
				   tile_pos.y * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF)


func _spawn_effect(effect_type: String, position: Vector2, params: Dictionary = {}) -> void:
	if EffectsManager and EffectsManager.has_method("spawn_effect"):
		EffectsManager.spawn_effect(effect_type, position, params)
	else:
		# 기본 피드백
		match effect_type:
			"scout":
				EventBus.show_toast.emit("Raven: 정찰 완료", Constants.ToastType.INFO, 3.0)
			"flare":
				EventBus.show_toast.emit("Raven: 조명탄 투하", Constants.ToastType.INFO, 2.0)
			"resupply":
				EventBus.show_toast.emit("Raven: 보급 완료", Constants.ToastType.SUCCESS, 2.0)
			"orbital_warning":
				EventBus.show_toast.emit("경고: 궤도 폭격 대기!", Constants.ToastType.WARNING, 2.0)
			"orbital_explosion":
				EventBus.show_toast.emit("궤도 폭격 착탄!", Constants.ToastType.ERROR, 2.0)
