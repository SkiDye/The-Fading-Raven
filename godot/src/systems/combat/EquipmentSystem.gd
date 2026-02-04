class_name EquipmentSystem
extends Node

## 장비 시스템
## 패시브 효과 적용 및 액티브 장비 사용 관리


# ===== SIGNALS =====

signal equipment_used(crew: Node, equipment_id: String, target: Variant)
signal equipment_failed(crew: Node, equipment_id: String, reason: String)
signal equipment_cooldown_started(crew: Node, equipment_id: String, duration: float)
signal equipment_ready(crew: Node, equipment_id: String)


# ===== REFERENCES =====

var _battle_controller: Node = null


# ===== COOLDOWN TRACKING =====

## { crew_entity_id: { equipment_id: remaining_cooldown } }
var _cooldowns: Dictionary = {}

## { crew_entity_id: { equipment_id: remaining_charges } }
var _charges: Dictionary = {}


func _ready() -> void:
	_battle_controller = get_parent()


func _process(delta: float) -> void:
	_process_cooldowns(delta)


func _process_cooldowns(delta: float) -> void:
	for crew_id in _cooldowns.keys():
		var crew_cooldowns: Dictionary = _cooldowns[crew_id]
		var to_remove: Array[String] = []

		for equip_id in crew_cooldowns.keys():
			crew_cooldowns[equip_id] -= delta
			if crew_cooldowns[equip_id] <= 0:
				to_remove.append(equip_id)
				# 해당 크루 찾아서 ready 시그널
				var crew := _find_crew_by_id(crew_id)
				if crew:
					equipment_ready.emit(crew, equip_id)

		for equip_id in to_remove:
			crew_cooldowns.erase(equip_id)


# ===== PUBLIC API =====

## 장비 사용 가능 여부 확인
func can_use(crew: Node) -> bool:
	if not crew.is_alive:
		return false

	if "is_stunned" in crew and crew.is_stunned:
		return false

	var equipment_data: Variant = _get_equipment_data(crew)
	if equipment_data == null:
		return false

	# 패시브 장비는 사용 불가
	if _get_equipment_type(equipment_data) == Constants.EquipmentType.PASSIVE:
		return false

	# 쿨다운 확인
	if _is_on_cooldown(crew):
		return false

	# 충전 확인
	if _get_equipment_type(equipment_data) == Constants.EquipmentType.ACTIVE_CHARGES:
		if _get_remaining_charges(crew) <= 0:
			return false

	return true


## 장비 사용
func execute_equipment(crew: Node, target: Variant = null) -> bool:
	if not can_use(crew):
		equipment_failed.emit(crew, _get_equipment_id(crew), "equipment_not_ready")
		return false

	var equipment_data: Variant = _get_equipment_data(crew)
	if equipment_data == null:
		return false

	var equipment_id := _get_equipment_id(crew)
	var success := false

	# 장비 효과 실행
	match equipment_id:
		"shock_wave":
			success = _execute_shock_wave(crew)
		"adrenaline_injector":
			success = _execute_adrenaline_injector(crew)
		"emergency_shield":
			success = _execute_emergency_shield(crew)
		"repair_kit":
			success = _execute_repair_kit(crew)
		"stim_pack":
			success = _execute_stim_pack(crew)
		"emp_grenade":
			success = _execute_emp_grenade(crew, target)
		"deployable_cover":
			success = _execute_deployable_cover(crew, target)
		_:
			# 범용 액티브 효과 처리
			success = _execute_generic_active(crew, equipment_data, target)

	if success:
		_consume_usage(crew, equipment_data)
		equipment_used.emit(crew, equipment_id, target)
		EventBus.equipment_activated.emit(crew, equipment_id)

	return success


## 스탯 수정자 가져오기 (패시브 효과)
func get_stat_modifiers(crew: Node) -> Dictionary:
	var modifiers: Dictionary = {}

	var equipment_data: Variant = _get_equipment_data(crew)
	if equipment_data == null:
		return modifiers

	var level := _get_equipment_level(crew)

	if equipment_data is Resource:
		if "stat_modifiers" in equipment_data:
			for stat_name in equipment_data.stat_modifiers.keys():
				var base_value: float = equipment_data.stat_modifiers[stat_name]
				# 레벨당 20% 증가
				modifiers[stat_name] = base_value * (1.0 + level * 0.2)
	elif equipment_data is Dictionary:
		var stat_mods: Dictionary = equipment_data.get("stat_modifiers", {})
		for stat_name in stat_mods.keys():
			var base_value: float = stat_mods[stat_name]
			modifiers[stat_name] = base_value * (1.0 + level * 0.2)

	return modifiers


## 쿨다운 진행률 (0.0 ~ 1.0)
func get_cooldown_percent(crew: Node) -> float:
	var crew_id := _get_crew_entity_id(crew)
	var equipment_id := _get_equipment_id(crew)

	if not _cooldowns.has(crew_id):
		return 0.0

	var crew_cooldowns: Dictionary = _cooldowns[crew_id]
	if not crew_cooldowns.has(equipment_id):
		return 0.0

	var equipment_data: Variant = _get_equipment_data(crew)
	if equipment_data == null:
		return 0.0

	var max_cooldown := _get_equipment_cooldown(equipment_data)
	if max_cooldown <= 0:
		return 0.0

	return crew_cooldowns[equipment_id] / max_cooldown


## 남은 충전 수
func get_remaining_charges(crew: Node) -> int:
	return _get_remaining_charges(crew)


## 스테이지 시작 시 충전 초기화
func reset_charges_for_stage() -> void:
	_charges.clear()


## 크루 등록 (스테이지 시작 시)
func register_crew(crew: Node) -> void:
	var crew_id := _get_crew_entity_id(crew)
	var equipment_data: Variant = _get_equipment_data(crew)

	if equipment_data == null:
		return

	# 충전 초기화
	if _get_equipment_type(equipment_data) == Constants.EquipmentType.ACTIVE_CHARGES:
		var max_charges := _get_equipment_charges(equipment_data)
		if not _charges.has(crew_id):
			_charges[crew_id] = {}
		_charges[crew_id][_get_equipment_id(crew)] = max_charges


# ===== EQUIPMENT EFFECTS =====

## Shock Wave - 주변 적 넉백
func _execute_shock_wave(crew: Node) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var level := _get_equipment_level(crew)
	var range_val: int = [2, 3, 4][clampi(level, 0, 2)]
	var knockback_force: float = [2.0, 3.0, 4.0][clampi(level, 0, 2)]

	var center: Vector2i = crew.tile_position
	var affected_tiles := _get_tiles_in_range(grid, center, range_val)

	for tile_pos in affected_tiles:
		var occupant := _get_occupant(grid, tile_pos)
		if occupant and _is_enemy(occupant):
			var direction := Vector2(tile_pos.x - center.x, tile_pos.y - center.y)
			if direction.length() > 0:
				direction = direction.normalized()
			else:
				direction = Vector2.RIGHT

			occupant.apply_knockback(direction, knockback_force)

	# 이펙트
	_spawn_effect("shock_wave", crew.global_position, {"radius": range_val * Constants.TILE_SIZE})

	return true


## Adrenaline Injector - 일시적 속도 증가
func _execute_adrenaline_injector(crew: Node) -> bool:
	var level := _get_equipment_level(crew)
	var duration: float = [5.0, 7.0, 10.0][clampi(level, 0, 2)]
	var speed_bonus: float = [0.5, 0.75, 1.0][clampi(level, 0, 2)]

	if crew.has_method("apply_buff"):
		crew.apply_buff("speed", speed_bonus, duration)
	else:
		# 직접 처리
		_apply_timed_buff(crew, "move_speed", speed_bonus, duration)

	_spawn_effect("adrenaline", crew.global_position, {})

	return true


## Emergency Shield - 일시적 무적
func _execute_emergency_shield(crew: Node) -> bool:
	var level := _get_equipment_level(crew)
	var duration: float = [2.0, 3.0, 4.0][clampi(level, 0, 2)]

	if crew.has_method("apply_invincibility"):
		crew.apply_invincibility(duration)
	else:
		_apply_timed_buff(crew, "invincible", 1.0, duration)

	_spawn_effect("emergency_shield", crew.global_position, {})

	return true


## Repair Kit - 체력 회복
func _execute_repair_kit(crew: Node) -> bool:
	var level := _get_equipment_level(crew)
	var heal_percent: float = [0.3, 0.5, 0.7][clampi(level, 0, 2)]

	var max_hp := 100
	if "max_hp" in crew:
		max_hp = crew.max_hp

	var heal_amount := int(max_hp * heal_percent)

	if crew.has_method("heal"):
		crew.heal(heal_amount)
	elif "current_hp" in crew:
		crew.current_hp = mini(crew.current_hp + heal_amount, max_hp)

	_spawn_effect("heal", crew.global_position, {"amount": heal_amount})
	EventBus.show_floating_text.emit("+%d" % heal_amount, crew.global_position, Color.GREEN)

	return true


## Stim Pack - 공격 속도 증가
func _execute_stim_pack(crew: Node) -> bool:
	var level := _get_equipment_level(crew)
	var duration: float = [5.0, 7.0, 10.0][clampi(level, 0, 2)]
	var attack_speed_bonus: float = [0.3, 0.5, 0.75][clampi(level, 0, 2)]

	if crew.has_method("apply_buff"):
		crew.apply_buff("attack_speed", attack_speed_bonus, duration)
	else:
		_apply_timed_buff(crew, "attack_speed", attack_speed_bonus, duration)

	_spawn_effect("stim_pack", crew.global_position, {})

	return true


## EMP Grenade - 범위 스턴
func _execute_emp_grenade(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Vector2:
		target_pos = _world_to_tile(grid, target)
	else:
		return false

	var level := _get_equipment_level(crew)
	var range_val: int = [1, 2, 2][clampi(level, 0, 2)]
	var stun_duration: float = [1.5, 2.0, 3.0][clampi(level, 0, 2)]

	var affected_tiles := _get_tiles_in_range(grid, target_pos, range_val)
	affected_tiles.append(target_pos)

	for tile_pos in affected_tiles:
		var occupant := _get_occupant(grid, tile_pos)
		if occupant and _is_enemy(occupant):
			occupant.apply_stun(stun_duration)

	var world_pos := _tile_to_world(grid, target_pos)
	_spawn_effect("emp", world_pos, {"radius": range_val * Constants.TILE_SIZE})

	return true


## Deployable Cover - 임시 엄폐물 배치
func _execute_deployable_cover(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Vector2:
		target_pos = _world_to_tile(grid, target)
	else:
		return false

	# 유효한 위치인지 확인
	if not _is_walkable(grid, target_pos):
		return false

	var level := _get_equipment_level(crew)
	var cover_type: int = Constants.TileType.COVER_HALF if level < 2 else Constants.TileType.COVER_FULL

	# 타일 타입 변경
	if grid.has_method("set_tile_type"):
		grid.set_tile_type(target_pos, cover_type)

	_spawn_effect("cover_deploy", _tile_to_world(grid, target_pos), {})

	return true


## 범용 액티브 효과 처리
func _execute_generic_active(crew: Node, equipment_data: Variant, _target: Variant) -> bool:
	var effect_id: String = ""
	if equipment_data is Resource and "active_effect_id" in equipment_data:
		effect_id = equipment_data.active_effect_id
	elif equipment_data is Dictionary:
		effect_id = equipment_data.get("active_effect_id", "")

	if effect_id == "":
		return false

	# 기본 효과 처리
	_spawn_effect(effect_id, crew.global_position, {})
	return true


# ===== UTILITY FUNCTIONS =====

func _get_equipment_data(crew: Node) -> Variant:
	if not "crew_data" in crew:
		return null

	var crew_data = crew.crew_data
	if crew_data == null:
		return null

	var equipment_id: String = ""

	if crew_data is Resource:
		equipment_id = crew_data.equipment_id if "equipment_id" in crew_data else ""
	elif crew_data is Dictionary:
		equipment_id = crew_data.get("equipment_id", "")

	if equipment_id == "":
		return null

	return Constants.get_equipment(equipment_id)


func _get_equipment_id(crew: Node) -> String:
	if not "crew_data" in crew:
		return ""

	var crew_data = crew.crew_data
	if crew_data is Resource:
		return crew_data.equipment_id if "equipment_id" in crew_data else ""
	elif crew_data is Dictionary:
		return crew_data.get("equipment_id", "")

	return ""


func _get_equipment_level(crew: Node) -> int:
	if not "crew_data" in crew:
		return 0

	var crew_data = crew.crew_data
	if crew_data is Resource:
		return crew_data.equipment_level if "equipment_level" in crew_data else 0
	elif crew_data is Dictionary:
		return crew_data.get("equipment_level", 0)

	return 0


func _get_equipment_type(equipment_data: Variant) -> int:
	if equipment_data is Resource:
		return equipment_data.equipment_type if "equipment_type" in equipment_data else Constants.EquipmentType.PASSIVE
	elif equipment_data is Dictionary:
		return equipment_data.get("equipment_type", Constants.EquipmentType.PASSIVE)
	return Constants.EquipmentType.PASSIVE


func _get_equipment_cooldown(equipment_data: Variant) -> float:
	if equipment_data is Resource:
		return equipment_data.cooldown if "cooldown" in equipment_data else 30.0
	elif equipment_data is Dictionary:
		return equipment_data.get("cooldown", 30.0)
	return 30.0


func _get_equipment_charges(equipment_data: Variant) -> int:
	if equipment_data is Resource:
		return equipment_data.charges if "charges" in equipment_data else 1
	elif equipment_data is Dictionary:
		return equipment_data.get("charges", 1)
	return 1


func _get_crew_entity_id(crew: Node) -> String:
	if "entity_id" in crew:
		return crew.entity_id
	return str(crew.get_instance_id())


func _is_on_cooldown(crew: Node) -> bool:
	var crew_id := _get_crew_entity_id(crew)
	var equipment_id := _get_equipment_id(crew)

	if not _cooldowns.has(crew_id):
		return false

	return _cooldowns[crew_id].has(equipment_id)


func _get_remaining_charges(crew: Node) -> int:
	var crew_id := _get_crew_entity_id(crew)
	var equipment_id := _get_equipment_id(crew)

	if not _charges.has(crew_id):
		return 0

	return _charges[crew_id].get(equipment_id, 0)


func _consume_usage(crew: Node, equipment_data: Variant) -> void:
	var crew_id := _get_crew_entity_id(crew)
	var equipment_id := _get_equipment_id(crew)
	var equip_type := _get_equipment_type(equipment_data)

	if equip_type == Constants.EquipmentType.ACTIVE_COOLDOWN:
		# 쿨다운 시작
		var cooldown := _get_equipment_cooldown(equipment_data)
		if not _cooldowns.has(crew_id):
			_cooldowns[crew_id] = {}
		_cooldowns[crew_id][equipment_id] = cooldown
		equipment_cooldown_started.emit(crew, equipment_id, cooldown)

	elif equip_type == Constants.EquipmentType.ACTIVE_CHARGES:
		# 충전 감소
		if _charges.has(crew_id) and _charges[crew_id].has(equipment_id):
			_charges[crew_id][equipment_id] -= 1


func _find_crew_by_id(crew_id: String) -> Node:
	if not _battle_controller or not "crews" in _battle_controller:
		return null

	for crew in _battle_controller.crews:
		if _get_crew_entity_id(crew) == crew_id:
			return crew

	return null


func _get_tile_grid() -> Node:
	if _battle_controller and _battle_controller.has_method("get_tile_grid"):
		return _battle_controller.get_tile_grid()
	return null


func _get_tiles_in_range(grid: Node, center: Vector2i, range_val: int) -> Array[Vector2i]:
	if grid.has_method("get_tiles_in_range"):
		return grid.get_tiles_in_range(center, range_val)

	var tiles: Array[Vector2i] = []
	for dx in range(-range_val, range_val + 1):
		for dy in range(-range_val, range_val + 1):
			if abs(dx) + abs(dy) <= range_val and (dx != 0 or dy != 0):
				tiles.append(Vector2i(center.x + dx, center.y + dy))
	return tiles


func _get_occupant(grid: Node, pos: Vector2i) -> Node:
	if grid.has_method("get_occupant"):
		return grid.get_occupant(pos)
	return null


func _is_enemy(entity: Node) -> bool:
	if "team" in entity:
		return entity.team == 1
	return entity.is_in_group("enemies")


func _is_walkable(grid: Node, pos: Vector2i) -> bool:
	if grid.has_method("is_walkable"):
		return grid.is_walkable(pos)
	return true


func _world_to_tile(grid: Node, world_pos: Vector2) -> Vector2i:
	if grid.has_method("world_to_tile"):
		return grid.world_to_tile(world_pos)
	return Vector2i(int(world_pos.x / Constants.TILE_SIZE), int(world_pos.y / Constants.TILE_SIZE))


func _tile_to_world(grid: Node, tile_pos: Vector2i) -> Vector2:
	if grid.has_method("tile_to_world"):
		return grid.tile_to_world(tile_pos)
	return Vector2(tile_pos.x * Constants.TILE_SIZE, tile_pos.y * Constants.TILE_SIZE)


func _apply_timed_buff(crew: Node, stat_name: String, value: float, duration: float) -> void:
	# 간단한 타이머 기반 버프
	# 실제 구현에서는 별도 BuffSystem 사용 권장
	if crew.has_method("add_temp_modifier"):
		crew.add_temp_modifier(stat_name, value, duration)
	else:
		# 크루에 직접 저장
		if not "_temp_buffs" in crew:
			crew.set("_temp_buffs", {})
		crew._temp_buffs[stat_name] = {"value": value, "remaining": duration}


func _spawn_effect(effect_type: String, position: Vector2, params: Dictionary = {}) -> void:
	if EffectsManager and EffectsManager.has_method("spawn_effect"):
		EffectsManager.spawn_effect(effect_type, position, params)
