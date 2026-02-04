class_name SkillSystem
extends Node

## 스킬 시스템
## 5종 크루 스킬 실행 관리


# ===== SIGNALS =====

signal skill_executed(crew: Node, skill_id: String, target: Variant)
signal skill_failed(crew: Node, skill_id: String, reason: String)


# ===== REFERENCES =====

var _battle_controller: Node = null
var _damage_calculator: Node = null


func _ready() -> void:
	_battle_controller = get_parent()
	if _battle_controller:
		_damage_calculator = _battle_controller.get_node_or_null("DamageCalculator")


## 스킬 실행
## [param crew]: 스킬 사용 크루
## [param skill_id]: 스킬 ID
## [param target]: 대상 (Vector2i 위치 또는 Vector2 방향)
## [return]: 성공 여부
func execute_skill(crew: Node, skill_id: String, target: Variant) -> bool:
	if not _can_use_skill(crew, skill_id):
		skill_failed.emit(crew, skill_id, "skill_not_ready")
		return false

	var success := false

	match skill_id:
		"shield_bash":
			success = _execute_shield_bash(crew, target)
		"lance_charge":
			success = _execute_lance_charge(crew, target)
		"volley_fire":
			success = _execute_volley_fire(crew, target)
		"deploy_turret":
			success = _execute_deploy_turret(crew, target)
		"blink":
			success = _execute_blink(crew, target)
		_:
			skill_failed.emit(crew, skill_id, "unknown_skill")
			return false

	if success:
		_start_skill_cooldown(crew, skill_id)
		skill_executed.emit(crew, skill_id, target)
		EventBus.skill_used.emit(crew, skill_id, target, _get_skill_level(crew))

	return success


## 스킬 사용 가능 여부 확인
func _can_use_skill(crew: Node, _skill_id: String) -> bool:
	if not crew.is_alive:
		return false

	# 스턴 상태면 사용 불가
	if "is_stunned" in crew and crew.is_stunned:
		return false

	# 쿨다운 확인
	if crew.has_method("can_use_skill"):
		return crew.can_use_skill()

	return true


func _get_skill_level(crew: Node) -> int:
	if "crew_data" in crew:
		var crew_data = crew.crew_data
		if crew_data is Resource and "skill_level" in crew_data:
			return crew_data.skill_level
		elif crew_data is Dictionary:
			return crew_data.get("skill_level", 0)
	return 0


func _start_skill_cooldown(crew: Node, skill_id: String) -> void:
	if crew.has_method("start_skill_cooldown"):
		crew.start_skill_cooldown(skill_id)


func _get_tile_grid() -> Node:
	if _battle_controller and _battle_controller.has_method("get_tile_grid"):
		return _battle_controller.get_tile_grid()
	return null


# ===== SHIELD BASH (Guardian) =====
## 지정 방향으로 돌진, 경로상 적에게 데미지 + 넉백

func _execute_shield_bash(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var level := _get_skill_level(crew)
	var level_data = _get_skill_level_data(crew, "shield_bash")

	# 레벨별 거리: Lv1=3, Lv2=5, Lv3=무제한
	var max_distance: int = [3, 5, 99][clampi(level, 0, 2)]
	var knockback_force: float = 2.0
	var stun_duration: float = 0.0

	if level_data:
		knockback_force = level_data.knockback_force if level_data.knockback_force > 0 else 2.0
		stun_duration = level_data.stun_duration

	# 방향 계산
	var direction := _calculate_direction(crew, target)
	if direction == Vector2.ZERO:
		return false

	# 경로상 타일들
	var start_pos: Vector2i = crew.tile_position
	var tiles := _get_tiles_in_direction(grid, start_pos, direction, max_distance)

	if tiles.is_empty():
		return false

	# 경로상 적들에게 넉백 + 데미지
	for tile_pos in tiles:
		var occupant := _get_occupant(grid, tile_pos)
		if occupant and _is_enemy(occupant):
			# 넉백
			occupant.apply_knockback(direction, knockback_force)
			# Lv3: 스턴
			if stun_duration > 0:
				occupant.apply_stun(stun_duration)
			# 데미지
			var damage := _get_crew_damage(crew)
			occupant.take_damage(damage, Constants.DamageType.PHYSICAL, crew)

	# 크루 이동
	var end_tile: Vector2i = tiles[-1] if not tiles.is_empty() else start_pos
	# 이동 가능한 마지막 타일 찾기
	for i in range(tiles.size() - 1, -1, -1):
		if _is_walkable(grid, tiles[i]):
			end_tile = tiles[i]
			break

	_move_crew_to_tile(crew, end_tile, grid)

	# 이펙트
	_spawn_effect("shield_bash", grid.tile_to_world(start_pos) if grid.has_method("tile_to_world") else Vector2.ZERO, {
		"end_pos": grid.tile_to_world(end_tile) if grid.has_method("tile_to_world") else Vector2.ZERO
	})

	return true


# ===== LANCE CHARGE (Sentinel) =====
## 직선 돌격, 경로상 모든 적에게 고데미지 (대부분 즉사)

func _execute_lance_charge(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var level := _get_skill_level(crew)

	# 레벨별 거리: Lv1=3, Lv2+=무제한
	var max_distance: int = 3 if level == 0 else 99

	# 방향 계산
	var direction := _calculate_direction(crew, target)
	if direction == Vector2.ZERO:
		return false

	var start_pos: Vector2i = crew.tile_position
	var tiles := _get_tiles_in_direction(grid, start_pos, direction, max_distance)

	if tiles.is_empty():
		return false

	# 고데미지
	var base_damage := _get_crew_damage(crew) * 5

	for tile_pos in tiles:
		var occupant := _get_occupant(grid, tile_pos)
		if occupant and _is_enemy(occupant):
			# 브루트는 Lv3에서만 즉사
			var is_brute := _is_brute(occupant)
			if is_brute and level < 2:
				occupant.take_damage(base_damage, Constants.DamageType.PHYSICAL, crew)
			else:
				# 즉사 데미지
				occupant.take_damage(9999, Constants.DamageType.PHYSICAL, crew)

	# 돌격 종료 위치로 이동
	var end_tile := start_pos
	for i in range(tiles.size() - 1, -1, -1):
		if _is_walkable(grid, tiles[i]):
			end_tile = tiles[i]
			break

	_move_crew_to_tile(crew, end_tile, grid)

	# 이펙트
	_spawn_effect("lance_charge", grid.tile_to_world(start_pos) if grid.has_method("tile_to_world") else Vector2.ZERO, {
		"direction": direction,
		"distance": tiles.size() * Constants.TILE_SIZE
	})

	return true


# ===== VOLLEY FIRE (Ranger) =====
## 지정 위치에 일제 사격

func _execute_volley_fire(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Vector2:
		target_pos = Vector2i(int(target.x), int(target.y))
	else:
		return false

	var level := _get_skill_level(crew)
	var level_data = _get_skill_level_data(crew, "volley_fire")

	# 생존 인원 수에 따른 탄환 수
	var alive_count := _get_alive_member_count(crew)
	var bullets_per_member: int = [1, 2, 3][clampi(level, 0, 2)]
	var total_bullets: int = alive_count * bullets_per_member

	var world_target: Vector2
	if grid.has_method("tile_to_world"):
		world_target = grid.tile_to_world(target_pos)
	else:
		world_target = Vector2(target_pos.x * Constants.TILE_SIZE, target_pos.y * Constants.TILE_SIZE)

	var base_damage := _get_crew_damage(crew)

	# Lv3: 관통 효과
	var is_piercing: bool = level >= 2

	# 투사체 발사
	_spawn_volley_projectiles(crew, world_target, total_bullets, base_damage, is_piercing)

	# 이펙트
	_spawn_effect("volley_fire", world_target, {
		"bullet_count": total_bullets
	})

	return true


func _spawn_volley_projectiles(crew: Node, target_pos: Vector2, count: int, damage: int, piercing: bool) -> void:
	if not _battle_controller:
		return

	# Projectile 씬 로드 시도
	var projectile_scene: PackedScene = null
	if ResourceLoader.exists("res://src/entities/projectile/Projectile.tscn"):
		projectile_scene = load("res://src/entities/projectile/Projectile.tscn")

	for i in range(count):
		# 발사 위치 약간 랜덤화
		var offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var spawn_pos: Vector2 = crew.global_position + offset

		# 타겟 위치 약간 랜덤화
		var target_offset := Vector2(randf_range(-16, 16), randf_range(-16, 16))
		var final_target := target_pos + target_offset

		if projectile_scene:
			var proj := projectile_scene.instantiate()
			proj.global_position = spawn_pos

			if proj.has_method("initialize"):
				proj.initialize(crew, final_target, damage, Constants.DamageType.ENERGY)

			if piercing and "aoe_radius" in proj:
				proj.aoe_radius = 16

			_battle_controller.add_child(proj)
		else:
			# 투사체 씬 없으면 즉시 데미지 처리
			_apply_instant_volley_damage(final_target, damage, crew)


func _apply_instant_volley_damage(target_pos: Vector2, damage: int, source: Node) -> void:
	var grid := _get_tile_grid()
	if grid == null:
		return

	var tile_pos: Vector2i
	if grid.has_method("world_to_tile"):
		tile_pos = grid.world_to_tile(target_pos)
	else:
		tile_pos = Vector2i(int(target_pos.x / Constants.TILE_SIZE), int(target_pos.y / Constants.TILE_SIZE))

	var occupant := _get_occupant(grid, tile_pos)
	if occupant and _is_enemy(occupant):
		occupant.take_damage(damage, Constants.DamageType.ENERGY, source)


# ===== DEPLOY TURRET (Engineer) =====
## 지정 위치에 터렛 설치

func _execute_deploy_turret(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Vector2:
		if grid.has_method("world_to_tile"):
			target_pos = grid.world_to_tile(target)
		else:
			target_pos = Vector2i(int(target.x / Constants.TILE_SIZE), int(target.y / Constants.TILE_SIZE))
	else:
		return false

	# 설치 가능 여부 확인
	if not _is_walkable(grid, target_pos):
		skill_failed.emit(crew, "deploy_turret", "invalid_position")
		return false

	# 이미 점유된 타일인지 확인
	if _get_occupant(grid, target_pos) != null:
		skill_failed.emit(crew, "deploy_turret", "tile_occupied")
		return false

	var level := _get_skill_level(crew)

	# 현재 터렛 수 확인 (레벨별 최대: 1, 2, 3)
	var max_turrets: int = [1, 2, 3][clampi(level, 0, 2)]
	var current_turrets := _count_crew_turrets(crew)

	if current_turrets >= max_turrets:
		skill_failed.emit(crew, "deploy_turret", "max_turrets_reached")
		return false

	# 터렛 생성
	_spawn_turret(crew, target_pos, level)

	return true


func _count_crew_turrets(crew: Node) -> int:
	if not _battle_controller or not "turrets" in _battle_controller:
		return 0

	var count := 0
	for turret in _battle_controller.turrets:
		if turret.has_method("get_owner") and turret.get_owner() == crew:
			count += 1
		elif "owner_id" in turret and "entity_id" in crew and turret.owner_id == crew.entity_id:
			count += 1

	return count


func _spawn_turret(crew: Node, pos: Vector2i, level: int) -> void:
	if not _battle_controller:
		return

	# Turret 씬 로드 시도
	var turret_scene: PackedScene = null
	if ResourceLoader.exists("res://src/entities/turret/Turret.tscn"):
		turret_scene = load("res://src/entities/turret/Turret.tscn")

	if turret_scene:
		var turret := turret_scene.instantiate()
		turret.tile_position = pos

		var grid := _get_tile_grid()
		if grid and grid.has_method("tile_to_world"):
			turret.global_position = grid.tile_to_world(pos)
		else:
			turret.global_position = Vector2(pos.x * Constants.TILE_SIZE, pos.y * Constants.TILE_SIZE)

		if turret.has_method("initialize"):
			turret.initialize(crew, level)

		_battle_controller.add_child(turret)
		EventBus.turret_deployed.emit(turret, pos)
	else:
		push_warning("SkillSystem: Turret scene not found")


# ===== BLINK (Bionic) =====
## 지정 위치로 순간이동

func _execute_blink(crew: Node, target: Variant) -> bool:
	var grid := _get_tile_grid()
	if grid == null:
		return false

	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Vector2:
		if grid.has_method("world_to_tile"):
			target_pos = grid.world_to_tile(target)
		else:
			target_pos = Vector2i(int(target.x / Constants.TILE_SIZE), int(target.y / Constants.TILE_SIZE))
	else:
		return false

	var level := _get_skill_level(crew)
	var level_data = _get_skill_level_data(crew, "blink")

	# 레벨별 거리: Lv1=2, Lv2=4, Lv3=6
	var max_distance: int = [2, 4, 6][clampi(level, 0, 2)]
	var stun_duration: float = 0.0

	if level_data and level_data.stun_duration > 0:
		stun_duration = level_data.stun_duration

	# 거리 확인
	var start_pos: Vector2i = crew.tile_position
	var distance := _calculate_tile_distance(start_pos, target_pos)

	if distance > max_distance:
		skill_failed.emit(crew, "blink", "out_of_range")
		return false

	# 목표 타일 유효성 확인
	if not _is_walkable(grid, target_pos):
		skill_failed.emit(crew, "blink", "invalid_position")
		return false

	var start_world_pos: Vector2 = crew.global_position

	# 순간이동
	_move_crew_to_tile(crew, target_pos, grid)

	# Lv3: 착지 스턴
	if stun_duration > 0:
		var nearby_tiles := _get_tiles_in_range(grid, target_pos, 1)
		for tile_pos in nearby_tiles:
			var occupant := _get_occupant(grid, tile_pos)
			if occupant and _is_enemy(occupant):
				occupant.apply_stun(stun_duration)

	# 이펙트
	_spawn_effect("blink", start_world_pos, {
		"end_pos": crew.global_position
	})

	return true


# ===== UTILITY FUNCTIONS =====

func _calculate_direction(crew: Node, target: Variant) -> Vector2:
	if target is Vector2:
		return target.normalized()
	elif target is Vector2i:
		var crew_pos := Vector2(crew.tile_position.x, crew.tile_position.y)
		var target_vec := Vector2(target.x, target.y)
		var dir := target_vec - crew_pos
		if dir.length() > 0:
			return dir.normalized()
	return Vector2.ZERO


func _get_tiles_in_direction(grid: Node, start: Vector2i, direction: Vector2, max_distance: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	# 방향을 8방향으로 스냅
	var dir_x := 0
	var dir_y := 0

	if abs(direction.x) > 0.3:
		dir_x = 1 if direction.x > 0 else -1
	if abs(direction.y) > 0.3:
		dir_y = 1 if direction.y > 0 else -1

	if dir_x == 0 and dir_y == 0:
		return tiles

	var current := start
	for i in range(max_distance):
		current = Vector2i(current.x + dir_x, current.y + dir_y)

		# 유효한 위치인지 확인
		if grid.has_method("is_valid_position"):
			if not grid.is_valid_position(current):
				break
		elif grid.has_method("get_tile"):
			if grid.get_tile(current) == null:
				break

		# 벽이면 중단
		var tile_type := _get_tile_type(grid, current)
		if tile_type == Constants.TileType.WALL or tile_type == Constants.TileType.VOID:
			break

		tiles.append(current)

	return tiles


func _get_tiles_in_range(grid: Node, center: Vector2i, range_val: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	if grid.has_method("get_tiles_in_range"):
		return grid.get_tiles_in_range(center, range_val)

	# 수동 계산
	for dx in range(-range_val, range_val + 1):
		for dy in range(-range_val, range_val + 1):
			if abs(dx) + abs(dy) <= range_val:  # 다이아몬드 형태
				var pos := Vector2i(center.x + dx, center.y + dy)
				if pos != center:
					tiles.append(pos)

	return tiles


func _get_tile_type(grid: Node, pos: Vector2i) -> int:
	if grid.has_method("get_tile_type"):
		return grid.get_tile_type(pos)
	if grid.has_method("get_tile"):
		var tile = grid.get_tile(pos)
		if tile and "type" in tile:
			return tile.type
	return Constants.TileType.FLOOR


func _is_walkable(grid: Node, pos: Vector2i) -> bool:
	if grid.has_method("is_walkable"):
		return grid.is_walkable(pos)
	var tile_type := _get_tile_type(grid, pos)
	return tile_type != Constants.TileType.WALL and tile_type != Constants.TileType.VOID


func _get_occupant(grid: Node, pos: Vector2i) -> Node:
	if grid.has_method("get_occupant"):
		return grid.get_occupant(pos)
	return null


func _is_enemy(entity: Node) -> bool:
	if "team" in entity:
		return entity.team == 1  # 1 = enemy
	return entity.is_in_group("enemies")


func _is_brute(entity: Node) -> bool:
	if "enemy_data" in entity:
		var enemy_data = entity.enemy_data
		if enemy_data is Resource and "id" in enemy_data:
			return enemy_data.id == "brute"
		elif enemy_data is Dictionary:
			return enemy_data.get("id", "") == "brute"
	return false


func _get_crew_damage(crew: Node) -> int:
	if "crew_data" in crew:
		var crew_data = crew.crew_data
		if crew_data is Resource and crew_data.has_method("get_class_data"):
			var class_data = crew_data.get_class_data()
			if class_data:
				var rank: int = crew_data.rank if "rank" in crew_data else 0
				return int(class_data.get_stat_at_rank("damage", rank))
	return 3  # 기본 데미지


func _get_alive_member_count(crew: Node) -> int:
	if crew.has_method("get_alive_count"):
		return crew.get_alive_count()
	if "members" in crew:
		var count := 0
		for member in crew.members:
			if "is_alive" in member and member.is_alive:
				count += 1
		return count
	return 8  # 기본 분대 크기


func _move_crew_to_tile(crew: Node, pos: Vector2i, grid: Node) -> void:
	crew.set_tile_position(pos)

	if grid.has_method("tile_to_world"):
		crew.global_position = grid.tile_to_world(pos)
	else:
		crew.global_position = Vector2(pos.x * Constants.TILE_SIZE, pos.y * Constants.TILE_SIZE)


func _calculate_tile_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)  # 맨해튼 거리


func _get_skill_level_data(crew: Node, skill_id: String) -> Variant:
	if not "crew_data" in crew:
		return null

	var crew_data = crew.crew_data
	if crew_data == null:
		return null

	var class_data = null  # CrewClassData
	if crew_data is Resource and crew_data.has_method("get_class_data"):
		class_data = crew_data.get_class_data()

	if class_data == null:
		return null

	# SkillData 가져오기
	var skill_data = Constants.get_skill(skill_id) if Constants.has_method("get_skill") else null

	if skill_data and skill_data.has_method("get_level_data"):
		var level: int = crew_data.skill_level if "skill_level" in crew_data else 0
		return skill_data.get_level_data(level)

	return null


func _spawn_effect(effect_type: String, position: Vector2, params: Dictionary = {}) -> void:
	if EffectsManager and EffectsManager.has_method("spawn_effect"):
		EffectsManager.spawn_effect(effect_type, position, params)
	else:
		# 이펙트 매니저가 없으면 시그널로 알림
		match effect_type:
			"shield_bash":
				EventBus.show_floating_text.emit("Shield Bash!", position, Color.CYAN)
			"lance_charge":
				EventBus.show_floating_text.emit("Lance Charge!", position, Color.ORANGE)
			"volley_fire":
				EventBus.show_floating_text.emit("Volley Fire!", position, Color.YELLOW)
			"blink":
				EventBus.show_floating_text.emit("Blink!", position, Color.PURPLE)
