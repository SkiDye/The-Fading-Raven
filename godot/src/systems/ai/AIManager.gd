class_name AIManager
extends Node

## 적 AI 관리자
## 행동 트리 기반으로 모든 적의 AI를 실행


# ===== CONSTANTS =====

const TILE_SIZE: int = Constants.TILE_SIZE
const MIN_RETREAT_DISTANCE: float = 64.0  # 2타일
const OPTIMAL_RANGED_DISTANCE: float = 128.0  # 4타일


# ===== VARIABLES =====

var behavior_trees: Dictionary = {}  # behavior_id -> BTNode
var _tile_grid: Node
var _battle_controller: Node
var _is_active: bool = false


# ===== INITIALIZATION =====

func _ready() -> void:
	_setup_behavior_trees()


## AI 시스템 초기화
func initialize(tile_grid: Node, battle_controller: Node) -> void:
	_tile_grid = tile_grid
	_battle_controller = battle_controller
	_is_active = true


## AI 시스템 비활성화
func deactivate() -> void:
	_is_active = false


## AI 시스템 활성화
func activate() -> void:
	_is_active = true


# ===== PROCESS =====

func _process(delta: float) -> void:
	if not _is_active:
		return

	if _battle_controller == null:
		return

	# 모든 적 AI 업데이트
	var enemies: Array = _get_enemies()
	for enemy in enemies:
		if _should_update_ai(enemy):
			_update_enemy_ai(enemy, delta)


func _get_enemies() -> Array:
	if _battle_controller.has_method("get_enemies"):
		return _battle_controller.get_enemies()

	if _battle_controller.get("enemies") != null:
		return _battle_controller.enemies

	# 폴백: 그룹에서 가져오기
	return get_tree().get_nodes_in_group("enemies")


func _should_update_ai(enemy: Node) -> bool:
	# 살아있고 착륙 완료된 적만 업데이트
	if enemy == null:
		return false

	if enemy.get("is_alive") == false:
		return false

	if enemy.get("has_landed") == false:
		return false

	# 스턴 상태 체크
	if enemy.get("current_state") == Constants.EntityState.STUNNED:
		return false

	return true


func _update_enemy_ai(enemy: Node, delta: float) -> void:
	var behavior_id: String = _get_behavior_id(enemy)
	var bt: BehaviorTree.BTNode = behavior_trees.get(behavior_id)

	if bt != null:
		bt.tick(enemy, delta)


func _get_behavior_id(enemy: Node) -> String:
	# enemy_data에서 behavior_id 가져오기
	if enemy.get("enemy_data") != null:
		var data: Resource = enemy.enemy_data
		if data.get("behavior_id") != null:
			return data.behavior_id

	# 메타데이터에서 가져오기
	if enemy.has_meta("behavior_id"):
		return enemy.get_meta("behavior_id")

	# 기본값
	return "melee_rush"


# ===== BEHAVIOR TREE SETUP =====

func _setup_behavior_trees() -> void:
	behavior_trees["melee_rush"] = _create_melee_rush_bt()
	behavior_trees["ranged"] = _create_ranged_bt()
	behavior_trees["jumper"] = _create_jumper_bt()
	behavior_trees["brute"] = _create_brute_bt()
	behavior_trees["sniper"] = _create_sniper_bt()
	behavior_trees["hacker"] = _create_hacker_bt()
	behavior_trees["shield_trooper"] = _create_shield_trooper_bt()
	behavior_trees["heavy_trooper"] = _create_heavy_trooper_bt()
	behavior_trees["drone_carrier"] = _create_drone_carrier_bt()
	behavior_trees["shield_generator"] = _create_shield_generator_bt()


# ===== BEHAVIOR TREES =====

func _create_melee_rush_bt() -> BehaviorTree.BTSelector:
	## 근접 돌격 AI: 타겟 찾기 -> 접근 -> 공격
	return BehaviorTree.selector([
		# 1. 타겟이 있고 근접하면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_attack_range(e)),
			BehaviorTree.action(_action_attack)
		]),
		# 2. 타겟이 있으면 추적
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.action(_action_chase)
		]),
		# 3. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_ranged_bt() -> BehaviorTree.BTSelector:
	## 원거리 AI: 적정 거리 유지하며 공격
	return BehaviorTree.selector([
		# 1. 너무 가까우면 후퇴
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_too_close(e)),
			BehaviorTree.action(_action_retreat)
		]),
		# 2. 사거리 내면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_range(e)),
			BehaviorTree.condition(func(e): return _has_line_of_sight(e)),
			BehaviorTree.action(_action_ranged_attack)
		]),
		# 3. 적정 거리로 접근
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.action(_action_approach_ranged)
		]),
		# 4. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_jumper_bt() -> BehaviorTree.BTSelector:
	## 점프 공격 AI
	return BehaviorTree.selector([
		# 1. 점프 가능하면 점프 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_method("can_jump") and e.can_jump()),
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_jump_range(e)),
			BehaviorTree.action(_action_jump_attack)
		]),
		# 2. 일반 근접 행동
		_create_melee_rush_bt()
	])


func _create_brute_bt() -> BehaviorTree.BTSelector:
	## 브루트 AI: 느리지만 강력한 근접 공격
	return BehaviorTree.selector([
		# 1. 근접하면 강력 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_attack_range(e)),
			BehaviorTree.action(_action_heavy_attack)
		]),
		# 2. 느리게 추적
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.action(_action_chase)
		]),
		# 3. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_sniper_bt() -> BehaviorTree.BTSelector:
	## 스나이퍼 AI: 조준 후 고데미지 공격
	return BehaviorTree.selector([
		# 1. 조준 중이면 계속 조준
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.get("sniper_aim_target") != null),
			BehaviorTree.action(_action_continue_aiming)
		]),
		# 2. 타겟이 있고 사거리 내면 조준 시작
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_sniper_range(e)),
			BehaviorTree.condition(func(e): return _has_line_of_sight(e)),
			BehaviorTree.action(_action_start_aiming)
		]),
		# 3. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_hacker_bt() -> BehaviorTree.BTSelector:
	## 해커 AI: 터렛 해킹 우선
	return BehaviorTree.selector([
		# 1. 해킹 중이면 계속
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.get("hacker_hack_target") != null),
			BehaviorTree.action(_action_continue_hacking)
		]),
		# 2. 근처 터렛 해킹 시도
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return _has_nearby_turret(e)),
			BehaviorTree.action(_action_hack_turret)
		]),
		# 3. 터렛으로 이동
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return _find_hackable_turret(e) != null),
			BehaviorTree.action(_action_approach_turret)
		]),
		# 4. 일반 원거리 행동
		_create_ranged_bt()
	])


func _create_shield_trooper_bt() -> BehaviorTree.BTSelector:
	## 쉴드 트루퍼 AI: 방패로 아군 보호하며 전진
	return BehaviorTree.selector([
		# 1. 근접하면 방패 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_in_attack_range(e)),
			BehaviorTree.action(_action_shield_attack)
		]),
		# 2. 추적 (방패 전면 유지)
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.action(_action_chase)
		]),
		# 3. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_heavy_trooper_bt() -> BehaviorTree.BTSelector:
	## 헤비 트루퍼 AI: 중화기 사용
	return _create_ranged_bt()  # 기본 원거리 로직 사용


func _create_drone_carrier_bt() -> BehaviorTree.BTSelector:
	## 드론 캐리어 AI: 드론 생성 및 관리
	return BehaviorTree.selector([
		# 1. 드론 생성 가능하면 생성
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_method("can_spawn_drone") and e.can_spawn_drone()),
			BehaviorTree.cooldown(5.0, BehaviorTree.action(_action_spawn_drone))
		]),
		# 2. 안전 거리 유지
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.current_target != null),
			BehaviorTree.condition(func(e): return _is_too_close(e)),
			BehaviorTree.action(_action_retreat)
		]),
		# 3. 타겟 찾기
		BehaviorTree.action(_action_find_target)
	])


func _create_shield_generator_bt() -> BehaviorTree.BTSelector:
	## 쉴드 제너레이터 AI: 제자리에서 보호막 유지
	return BehaviorTree.selector([
		# 1. 보호막 유지
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_method("is_shield_active") and e.is_shield_active()),
			BehaviorTree.action(func(e, _d): return BehaviorTree.Status.RUNNING)
		]),
		# 2. 보호막 활성화
		BehaviorTree.action(_action_activate_shield)
	])


# ===== CONDITIONS =====

func _is_in_attack_range(enemy: Node) -> bool:
	if enemy.current_target == null:
		return false

	var dist: float = enemy.global_position.distance_to(enemy.current_target.global_position)
	var attack_range: float = _get_attack_range(enemy)

	return dist <= attack_range


func _is_in_range(enemy: Node) -> bool:
	return _is_in_attack_range(enemy)


func _is_in_jump_range(enemy: Node) -> bool:
	if enemy.current_target == null:
		return false

	var dist: float = enemy.global_position.distance_to(enemy.current_target.global_position)
	var jump_range: float = 5.0 * TILE_SIZE  # 5타일

	return dist <= jump_range and dist > TILE_SIZE


func _is_in_sniper_range(enemy: Node) -> bool:
	if enemy.current_target == null:
		return false

	var dist: float = enemy.global_position.distance_to(enemy.current_target.global_position)
	var sniper_range: float = 10.0 * TILE_SIZE  # 10타일

	return dist <= sniper_range


func _is_too_close(enemy: Node) -> bool:
	if enemy.current_target == null:
		return false

	var dist: float = enemy.global_position.distance_to(enemy.current_target.global_position)
	return dist < MIN_RETREAT_DISTANCE


func _has_line_of_sight(enemy: Node) -> bool:
	if enemy.current_target == null:
		return false

	if _tile_grid == null:
		return true

	if not _tile_grid.has_method("has_line_of_sight"):
		return true

	var from_tile: Vector2i = Utils.world_to_tile(enemy.global_position)
	var to_tile: Vector2i = Utils.world_to_tile(enemy.current_target.global_position)

	return _tile_grid.has_line_of_sight(from_tile, to_tile)


func _has_nearby_turret(enemy: Node) -> bool:
	var turret: Node = _find_hackable_turret(enemy)
	if turret == null:
		return false

	var dist: float = enemy.global_position.distance_to(turret.global_position)
	return dist < TILE_SIZE * 2


func _find_hackable_turret(enemy: Node) -> Node:
	var turrets: Array = get_tree().get_nodes_in_group("turrets")

	for turret in turrets:
		if turret.get("is_hacked") == false:
			return turret

	return null


func _get_attack_range(enemy: Node) -> float:
	if enemy.get("enemy_data") != null:
		var data: Resource = enemy.enemy_data
		if data.get("attack_range") != null:
			return data.attack_range * TILE_SIZE

	return 1.0 * TILE_SIZE


func _get_move_speed(enemy: Node) -> float:
	if enemy.get("enemy_data") != null:
		var data: Resource = enemy.enemy_data
		if data.get("move_speed") != null:
			return data.move_speed * TILE_SIZE

	return 1.5 * TILE_SIZE


# ===== ACTIONS =====

func _action_find_target(enemy: Node, _delta: float) -> int:
	var best_target: Node = null
	var best_score: float = -INF

	# 크루 탐색
	var crews: Array = _get_crews()
	for crew in crews:
		if not _is_valid_target(crew):
			continue

		var score: float = _calculate_target_score(enemy, crew)
		if score > best_score:
			best_score = score
			best_target = crew

	# 시설 탐색 (크루가 없을 때)
	if best_target == null:
		var facilities: Array = _get_facilities()
		for facility in facilities:
			if not _is_valid_target(facility):
				continue

			var score: float = _calculate_target_score(enemy, facility) * 0.5
			if score > best_score:
				best_score = score
				best_target = facility

	if best_target != null:
		_set_target(enemy, best_target)
		return BehaviorTree.Status.SUCCESS

	return BehaviorTree.Status.FAILURE


func _action_chase(enemy: Node, delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	var target_pos: Vector2 = enemy.current_target.global_position
	var direction: Vector2 = (target_pos - enemy.global_position).normalized()
	var speed: float = _get_move_speed(enemy)

	enemy.global_position += direction * speed * delta

	# 타일 위치 업데이트
	_update_tile_position(enemy)

	return BehaviorTree.Status.RUNNING


func _action_attack(enemy: Node, _delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	if not _is_valid_target(enemy.current_target):
		_set_target(enemy, null)
		return BehaviorTree.Status.FAILURE

	# 공격 실행
	var damage: int = _get_base_damage(enemy)

	if enemy.current_target.has_method("take_damage"):
		enemy.current_target.take_damage(damage, Constants.DamageType.PHYSICAL, enemy)

	# 공격 애니메이션/쿨다운 처리는 EnemyUnit에서
	if enemy.has_method("perform_attack"):
		enemy.perform_attack()

	return BehaviorTree.Status.SUCCESS


func _action_heavy_attack(enemy: Node, _delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	# 브루트 강력 공격 (2배 데미지)
	var damage: int = _get_base_damage(enemy) * 2

	if enemy.current_target.has_method("take_damage"):
		enemy.current_target.take_damage(damage, Constants.DamageType.PHYSICAL, enemy)

	# 넉백 적용
	if enemy.current_target.has_method("apply_knockback"):
		var direction: Vector2 = (enemy.current_target.global_position - enemy.global_position).normalized()
		enemy.current_target.apply_knockback(direction, 2.0)

	return BehaviorTree.Status.SUCCESS


func _action_ranged_attack(enemy: Node, _delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	# 투사체 생성
	if enemy.has_method("fire_projectile"):
		enemy.fire_projectile(enemy.current_target)
	else:
		# 직접 데미지 (투사체 시스템 없을 때)
		var damage: int = _get_base_damage(enemy)
		if enemy.current_target.has_method("take_damage"):
			enemy.current_target.take_damage(damage, Constants.DamageType.ENERGY, enemy)

	return BehaviorTree.Status.SUCCESS


func _action_retreat(enemy: Node, delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	var away_direction: Vector2 = (enemy.global_position - enemy.current_target.global_position).normalized()
	var speed: float = _get_move_speed(enemy)

	enemy.global_position += away_direction * speed * delta
	_update_tile_position(enemy)

	return BehaviorTree.Status.RUNNING


func _action_approach_ranged(enemy: Node, delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	var target_pos: Vector2 = enemy.current_target.global_position
	var dist: float = enemy.global_position.distance_to(target_pos)

	# 적정 거리에 도달하면 정지
	if dist <= OPTIMAL_RANGED_DISTANCE and dist >= MIN_RETREAT_DISTANCE:
		return BehaviorTree.Status.SUCCESS

	var direction: Vector2 = (target_pos - enemy.global_position).normalized()
	var speed: float = _get_move_speed(enemy)

	enemy.global_position += direction * speed * delta
	_update_tile_position(enemy)

	return BehaviorTree.Status.RUNNING


func _action_jump_attack(enemy: Node, _delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	var target_tile: Vector2i = Utils.world_to_tile(enemy.current_target.global_position)

	if enemy.has_method("perform_jump"):
		enemy.perform_jump(target_tile)

	return BehaviorTree.Status.SUCCESS


func _action_start_aiming(enemy: Node, _delta: float) -> int:
	if enemy.current_target == null:
		return BehaviorTree.Status.FAILURE

	enemy.set("sniper_aim_target", enemy.current_target)
	enemy.set("sniper_aim_time", 0.0)

	# 조준 경고 이벤트
	EventBus.show_floating_text.emit("!", enemy.global_position, Color.RED)

	return BehaviorTree.Status.SUCCESS


func _action_continue_aiming(enemy: Node, delta: float) -> int:
	var aim_target: Node = enemy.get("sniper_aim_target")
	if aim_target == null or not _is_valid_target(aim_target):
		enemy.set("sniper_aim_target", null)
		return BehaviorTree.Status.FAILURE

	var aim_time: float = enemy.get("sniper_aim_time") + delta
	enemy.set("sniper_aim_time", aim_time)

	# 2초 조준 후 발사
	if aim_time >= 2.0:
		# 고데미지 공격
		var damage: int = _get_base_damage(enemy) * 3
		if aim_target.has_method("take_damage"):
			aim_target.take_damage(damage, Constants.DamageType.ENERGY, enemy)

		enemy.set("sniper_aim_target", null)
		enemy.set("sniper_aim_time", 0.0)
		return BehaviorTree.Status.SUCCESS

	return BehaviorTree.Status.RUNNING


func _action_hack_turret(enemy: Node, _delta: float) -> int:
	var turret: Node = _find_hackable_turret(enemy)
	if turret == null:
		return BehaviorTree.Status.FAILURE

	var dist: float = enemy.global_position.distance_to(turret.global_position)
	if dist > TILE_SIZE * 2:
		return BehaviorTree.Status.FAILURE

	# 해킹 시작
	enemy.set("hacker_hack_target", turret)
	enemy.set("hacker_hack_progress", 0.0)

	return BehaviorTree.Status.SUCCESS


func _action_continue_hacking(enemy: Node, delta: float) -> int:
	var turret: Node = enemy.get("hacker_hack_target")
	if turret == null:
		return BehaviorTree.Status.FAILURE

	var progress: float = enemy.get("hacker_hack_progress") + delta
	enemy.set("hacker_hack_progress", progress)

	# 3초 후 해킹 완료
	if progress >= 3.0:
		if turret.has_method("set_hacked"):
			turret.set_hacked(true, enemy)

		EventBus.turret_hacked.emit(turret, enemy)

		enemy.set("hacker_hack_target", null)
		enemy.set("hacker_hack_progress", 0.0)
		return BehaviorTree.Status.SUCCESS

	return BehaviorTree.Status.RUNNING


func _action_approach_turret(enemy: Node, delta: float) -> int:
	var turret: Node = _find_hackable_turret(enemy)
	if turret == null:
		return BehaviorTree.Status.FAILURE

	var direction: Vector2 = (turret.global_position - enemy.global_position).normalized()
	var speed: float = _get_move_speed(enemy)

	enemy.global_position += direction * speed * delta
	_update_tile_position(enemy)

	return BehaviorTree.Status.RUNNING


func _action_shield_attack(enemy: Node, _delta: float) -> int:
	return _action_attack(enemy, _delta)


func _action_spawn_drone(enemy: Node, _delta: float) -> int:
	if enemy.has_method("spawn_drone"):
		enemy.spawn_drone()
		EventBus.show_floating_text.emit("Drone!", enemy.global_position, Color.YELLOW)

	return BehaviorTree.Status.SUCCESS


func _action_activate_shield(enemy: Node, _delta: float) -> int:
	if enemy.has_method("activate_shield"):
		enemy.activate_shield()

	return BehaviorTree.Status.SUCCESS


# ===== UTILITY =====

func _get_crews() -> Array:
	if _battle_controller != null and _battle_controller.has_method("get_crews"):
		return _battle_controller.get_crews()

	if _battle_controller != null and _battle_controller.get("crews") != null:
		return _battle_controller.crews

	return get_tree().get_nodes_in_group("crews")


func _get_facilities() -> Array:
	if _battle_controller != null and _battle_controller.get("facilities") != null:
		return _battle_controller.facilities

	return get_tree().get_nodes_in_group("facilities")


func _is_valid_target(target: Node) -> bool:
	if target == null:
		return false

	if target.get("is_alive") == false:
		return false

	return true


func _calculate_target_score(enemy: Node, target: Node) -> float:
	var dist: float = enemy.global_position.distance_to(target.global_position)
	var score: float = 1000.0 - dist  # 가까울수록 높은 점수

	# 크루가 시설보다 우선
	if target.is_in_group("crews"):
		score += 500.0

	return score


func _set_target(enemy: Node, target: Node) -> void:
	if enemy.has_method("set_target"):
		enemy.set_target(target)
	else:
		enemy.set("current_target", target)


func _get_base_damage(enemy: Node) -> int:
	if enemy.get("enemy_data") != null:
		var data: Resource = enemy.enemy_data
		if data.get("base_damage") != null:
			return data.base_damage

	return 5


func _update_tile_position(enemy: Node) -> void:
	var tile_pos: Vector2i = Utils.world_to_tile(enemy.global_position)
	enemy.set("tile_position", tile_pos)
