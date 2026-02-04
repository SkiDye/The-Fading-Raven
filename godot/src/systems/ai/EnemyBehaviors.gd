class_name EnemyBehaviors
extends RefCounted

## 적 유형별 Behavior Tree 패턴 정의
## 각 함수는 적 유형에 맞는 BT 루트 노드를 반환


# ===== HELPER FUNCTIONS =====

## 가장 가까운 크루 찾기
static func _find_nearest_crew(entity: Node) -> Node:
	var crews := entity.get_tree().get_nodes_in_group("crews")
	var nearest: Node = null
	var nearest_dist := INF

	for crew in crews:
		if not crew.is_alive:
			continue
		var dist: float = entity.global_position.distance_to(crew.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = crew

	return nearest


## 가장 가까운 시설 찾기
static func _find_nearest_facility(entity: Node) -> Node:
	var facilities := entity.get_tree().get_nodes_in_group("facilities")
	var nearest: Node = null
	var nearest_dist := INF

	for facility in facilities:
		if facility.has_method("is_destroyed") and facility.is_destroyed():
			continue
		var dist: float = entity.global_position.distance_to(facility.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = facility

	return nearest


## 가장 가까운 터렛 찾기 (해킹 가능)
static func _find_nearest_turret(entity: Node) -> Node:
	var turrets := entity.get_tree().get_nodes_in_group("turrets")
	var nearest: Node = null
	var nearest_dist := INF

	for turret in turrets:
		if turret.has_method("is_hacked") and turret.is_hacked():
			continue
		var dist: float = entity.global_position.distance_to(turret.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = turret

	return nearest


## 공격 범위 내 여부 확인
static func _is_in_attack_range(entity: Node, target: Node) -> bool:
	if target == null:
		return false
	var range_val: float = entity.attack_range if entity.has_method("get") else 1.0
	if entity.enemy_data:
		range_val = entity.enemy_data.attack_range
	var dist: float = entity.global_position.distance_to(target.global_position) / Constants.TILE_SIZE
	return dist <= range_val


# =====================================================
# MELEE BASIC (Rusher)
# 가장 단순한 근접 공격 패턴
# =====================================================

static func melee_basic() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 타겟이 있고 범위 내면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_attack)
		]),

		# 2. 타겟이 있으면 추적
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_target)
		]),

		# 3. 새 타겟 찾기
		BehaviorTree.sequence([
			BehaviorTree.action(_action_find_nearest_target),
			BehaviorTree.action(_action_move_to_target)
		])
	])


# =====================================================
# MELEE SHIELDED (Shield Trooper)
# 전방 실드로 원거리 방어하며 접근
# =====================================================

static func melee_shielded() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 공격 범위 내면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_attack)
		]),

		# 2. 타겟 방향 유지하며 전진 (실드 정면 유지)
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_face_target),
			BehaviorTree.action(_action_move_to_target)
		]),

		# 3. 새 타겟 찾기
		BehaviorTree.action(_action_find_nearest_target)
	])


# =====================================================
# RANGED BASIC (Gunner)
# 거리 유지하며 원거리 공격
# =====================================================

static func ranged_basic() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 너무 가까우면 후퇴
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return _is_too_close(e)),
			BehaviorTree.action(_action_retreat_from_target)
		]),

		# 2. 범위 내면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_ranged_attack)
		]),

		# 3. 범위 밖이면 접근
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_optimal_range)
		]),

		# 4. 새 타겟 찾기
		BehaviorTree.action(_action_find_nearest_target)
	])


static func _is_too_close(entity: Node) -> bool:
	if not entity.has_valid_target():
		return false
	var keep_dist: float = 2.0  # 기본 유지 거리
	if entity.enemy_data and entity.enemy_data.keep_distance > 0:
		keep_dist = entity.enemy_data.keep_distance
	var dist: float = entity.global_position.distance_to(entity.current_target.global_position) / Constants.TILE_SIZE
	return dist < keep_dist


# =====================================================
# MELEE JUMPER (Jumper)
# 방어선 우회 점프 공격
# =====================================================

static func melee_jumper() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 공격 범위 내면 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_attack)
		]),

		# 2. 점프 가능하고 타겟이 멀면 점프
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.can_jump()),
			BehaviorTree.condition(func(e): return _should_jump(e)),
			BehaviorTree.action(_action_jump_to_target)
		]),

		# 3. 일반 이동
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_target)
		]),

		# 4. 새 타겟 (후방 우선)
		BehaviorTree.action(_action_find_rear_target)
	])


static func _should_jump(entity: Node) -> bool:
	if not entity.has_valid_target():
		return false
	var dist: float = entity.global_position.distance_to(entity.current_target.global_position) / Constants.TILE_SIZE
	var jump_range: float = entity.enemy_data.jump_range if entity.enemy_data else 3.0
	return dist > 2.0 and dist <= jump_range


# =====================================================
# MELEE HEAVY (Heavy Trooper)
# 느리지만 강력, 수류탄 투척
# =====================================================

static func melee_heavy() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 수류탄 쿨다운 OK + 타겟 그룹 → 수류탄
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.can_throw_grenade()),
			BehaviorTree.condition(func(e): return _has_grouped_targets(e)),
			BehaviorTree.action(_action_throw_grenade)
		]),

		# 2. 근접 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_attack)
		]),

		# 3. 이동
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_target)
		]),

		BehaviorTree.action(_action_find_nearest_target)
	])


static func _has_grouped_targets(entity: Node) -> bool:
	var crews := entity.get_tree().get_nodes_in_group("crews")
	var grenade_range: float = 3.0 * Constants.TILE_SIZE
	var count := 0

	for crew in crews:
		if not crew.is_alive:
			continue
		var dist: float = entity.global_position.distance_to(crew.global_position)
		if dist <= grenade_range:
			count += 1

	return count >= 2


# =====================================================
# MELEE BRUTE (Brute)
# 고체력, 클리브 공격, 강력한 넉백
# =====================================================

static func melee_brute() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 클리브 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_cleave_attack)
		]),

		# 2. 느리게 전진
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_target)
		]),

		BehaviorTree.action(_action_find_nearest_target)
	])


# =====================================================
# SUPPORT HACKER (Hacker)
# 터렛 해킹 우선, 전투 회피
# =====================================================

static func support_hacker() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 해킹 중이면 계속
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e._is_hacking if e.has_method("get") else false),
			BehaviorTree.action(_action_continue_hacking)
		]),

		# 2. 해킹 가능한 터렛 근처면 해킹 시작
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return _has_nearby_turret(e)),
			BehaviorTree.action(_action_start_hacking)
		]),

		# 3. 터렛 찾아 이동
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return _find_nearest_turret(e) != null),
			BehaviorTree.action(_action_move_to_turret)
		]),

		# 4. 터렛 없으면 시설 공격
		BehaviorTree.sequence([
			BehaviorTree.action(_action_find_nearest_facility_target),
			BehaviorTree.action(_action_move_to_target)
		])
	])


static func _has_nearby_turret(entity: Node) -> bool:
	var turret := _find_nearest_turret(entity)
	if turret == null:
		return false
	var hack_range: float = (entity.enemy_data.hack_range * Constants.TILE_SIZE) if entity.enemy_data else 64.0
	return entity.global_position.distance_to(turret.global_position) <= hack_range


# =====================================================
# RANGED SNIPER (Sniper)
# 정지 후 조준, 고데미지 단발
# =====================================================

static func ranged_sniper() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 조준 중이면 계속
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e._is_aiming if e.has_method("get") else false),
			BehaviorTree.action(_action_continue_aiming)
		]),

		# 2. 사거리 내 타겟 있으면 조준 시작
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_start_aiming)
		]),

		# 3. 타겟 찾기 (가장 위협적인)
		BehaviorTree.action(_action_find_priority_target)
	])


# =====================================================
# SUPPORT CARRIER (Drone Carrier)
# 후방 유지, 드론 생성
# =====================================================

static func support_carrier() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 드론 스폰은 EnemyUnit._process_drone_carrier에서 처리

		# 2. 적당한 거리 유지
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return _is_too_close_to_front(e)),
			BehaviorTree.action(_action_retreat_to_safe_distance)
		]),

		# 3. 시설 방향으로 느리게 전진
		BehaviorTree.action(_action_move_toward_facility_slowly)
	])


static func _is_too_close_to_front(entity: Node) -> bool:
	var crews := entity.get_tree().get_nodes_in_group("crews")
	for crew in crews:
		if not crew.is_alive:
			continue
		var dist: float = entity.global_position.distance_to(crew.global_position) / Constants.TILE_SIZE
		if dist < 4.0:
			return true
	return false


# =====================================================
# SUPPORT SHIELD (Shield Generator)
# 아군 중심에 위치, 실드 제공
# =====================================================

static func support_shield() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. 실드 제공은 EnemyUnit._process_shield_generator에서 처리

		# 2. 아군 중심으로 이동
		BehaviorTree.action(_action_move_to_ally_center)
	])


# =====================================================
# KAMIKAZE (Storm Creature)
# 돌진 후 자폭
# =====================================================

static func kamikaze() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 자폭은 EnemyUnit._process_storm_creature에서 처리

		# 가장 가까운 타겟에게 돌진
		BehaviorTree.sequence([
			BehaviorTree.action(_action_find_nearest_target),
			BehaviorTree.action(_action_rush_to_target)
		])
	])


# =====================================================
# BOSS CAPTAIN (Pirate Captain)
# 복합 패턴: 버프 + 돌진 + 소환
# =====================================================

static func boss_captain() -> BehaviorTree.BTSelector:
	return BehaviorTree.selector([
		# 1. HP 낮으면 소환
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.get_health_ratio() < 0.5),
			BehaviorTree.cooldown(30.0, BehaviorTree.action(_action_summon_reinforcements))
		]),

		# 2. 돌진 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e._captain_charge_cooldown <= 0 if e.has_method("get") else true),
			BehaviorTree.action(_action_captain_charge)
		]),

		# 3. 일반 공격
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.condition(func(e): return e.is_target_in_range()),
			BehaviorTree.action(_action_attack)
		]),

		# 4. 이동
		BehaviorTree.sequence([
			BehaviorTree.condition(func(e): return e.has_valid_target()),
			BehaviorTree.action(_action_move_to_target)
		]),

		BehaviorTree.action(_action_find_nearest_target)
	])


# =====================================================
# BOSS STORM (Storm Core)
# 무적, 펄스 공격, 소환
# =====================================================

static func boss_storm() -> BehaviorTree.BTSelector:
	# 대부분의 메카닉이 EnemyUnit._process_boss에서 처리됨
	return BehaviorTree.selector([
		# 중앙에 고정
		BehaviorTree.action(_action_stay_in_center)
	])


# =====================================================
# ACTION IMPLEMENTATIONS
# =====================================================

static func _action_attack(entity: Node, _delta: float) -> int:
	if entity.has_method("attack") and entity.has_valid_target():
		entity.attack(entity.current_target)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_ranged_attack(entity: Node, _delta: float) -> int:
	return _action_attack(entity, _delta)


static func _action_cleave_attack(entity: Node, _delta: float) -> int:
	return _action_attack(entity, _delta)


static func _action_move_to_target(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	var target_pos: Vector2 = entity.current_target.global_position
	entity.move_to_position(target_pos)
	return BehaviorTree.Status.RUNNING


static func _action_face_target(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	entity.facing_direction = (entity.current_target.global_position - entity.global_position).normalized()
	return BehaviorTree.Status.SUCCESS


static func _action_find_nearest_target(entity: Node, _delta: float) -> int:
	var target := _find_nearest_crew(entity)
	if target:
		entity.set_target(target)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_find_rear_target(entity: Node, _delta: float) -> int:
	# Jumper: 후방의 레인저 등 우선
	var crews := entity.get_tree().get_nodes_in_group("crews")
	var best: Node = null
	var best_score := -INF

	for crew in crews:
		if not crew.is_alive:
			continue
		# 후방(y가 큰) 타겟 우선
		var score: float = crew.global_position.y
		if crew.has_method("get_class_id") and crew.get_class_id() == "ranger":
			score += 1000  # 레인저 우선
		if score > best_score:
			best_score = score
			best = crew

	if best:
		entity.set_target(best)
		return BehaviorTree.Status.SUCCESS
	return _action_find_nearest_target(entity, _delta)


static func _action_find_priority_target(entity: Node, _delta: float) -> int:
	# Sniper: 위협적인 타겟 우선
	return _action_find_nearest_target(entity, _delta)


static func _action_find_nearest_facility_target(entity: Node, _delta: float) -> int:
	var facility := _find_nearest_facility(entity)
	if facility:
		entity.set_target(facility)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_retreat_from_target(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	var away_dir: Vector2 = (entity.global_position - entity.current_target.global_position).normalized()
	var retreat_pos: Vector2 = entity.global_position + away_dir * Constants.TILE_SIZE * 2
	entity.move_to_position(retreat_pos)
	return BehaviorTree.Status.RUNNING


static func _action_move_to_optimal_range(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	var target_pos: Vector2 = entity.current_target.global_position
	var dir: Vector2 = (target_pos - entity.global_position).normalized()
	var optimal_range: float = (entity.enemy_data.attack_range - 0.5) * Constants.TILE_SIZE if entity.enemy_data else 64.0
	var optimal_pos: Vector2 = target_pos - dir * optimal_range

	entity.move_to_position(optimal_pos)
	return BehaviorTree.Status.RUNNING


static func _action_jump_to_target(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target() or not entity.has_method("perform_jump"):
		return BehaviorTree.Status.FAILURE

	var target_tile := Vector2i(
		int(entity.current_target.global_position.x / Constants.TILE_SIZE),
		int(entity.current_target.global_position.y / Constants.TILE_SIZE)
	)
	entity.perform_jump(target_tile)
	return BehaviorTree.Status.SUCCESS


static func _action_throw_grenade(entity: Node, _delta: float) -> int:
	if not entity.has_method("throw_grenade") or not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	entity.throw_grenade(entity.current_target.global_position)
	return BehaviorTree.Status.SUCCESS


static func _action_start_hacking(entity: Node, _delta: float) -> int:
	var turret := _find_nearest_turret(entity)
	if turret and entity.has_method("start_hacking"):
		entity.start_hacking(turret)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_continue_hacking(_entity: Node, _delta: float) -> int:
	return BehaviorTree.Status.RUNNING


static func _action_move_to_turret(entity: Node, _delta: float) -> int:
	var turret := _find_nearest_turret(entity)
	if turret:
		entity.move_to_position(turret.global_position)
		return BehaviorTree.Status.RUNNING
	return BehaviorTree.Status.FAILURE


static func _action_start_aiming(entity: Node, _delta: float) -> int:
	if entity.has_method("start_aiming") and entity.has_valid_target():
		entity.start_aiming(entity.current_target)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_continue_aiming(_entity: Node, _delta: float) -> int:
	return BehaviorTree.Status.RUNNING


static func _action_retreat_to_safe_distance(entity: Node, _delta: float) -> int:
	var nearest_crew := _find_nearest_crew(entity)
	if nearest_crew:
		var away_dir: Vector2 = (entity.global_position - nearest_crew.global_position).normalized()
		var safe_pos: Vector2 = entity.global_position + away_dir * Constants.TILE_SIZE * 2
		entity.move_to_position(safe_pos)
		return BehaviorTree.Status.RUNNING
	return BehaviorTree.Status.SUCCESS


static func _action_move_toward_facility_slowly(entity: Node, _delta: float) -> int:
	var facility := _find_nearest_facility(entity)
	if facility:
		entity.move_to_position(facility.global_position)
		return BehaviorTree.Status.RUNNING
	return BehaviorTree.Status.SUCCESS


static func _action_move_to_ally_center(entity: Node, _delta: float) -> int:
	var enemies := entity.get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return BehaviorTree.Status.SUCCESS

	var center := Vector2.ZERO
	var count := 0
	for enemy in enemies:
		if enemy == entity or not enemy.is_alive:
			continue
		center += enemy.global_position
		count += 1

	if count > 0:
		center /= count
		entity.move_to_position(center)
		return BehaviorTree.Status.RUNNING

	return BehaviorTree.Status.SUCCESS


static func _action_rush_to_target(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE
	entity.move_to_position(entity.current_target.global_position)
	return BehaviorTree.Status.RUNNING


static func _action_summon_reinforcements(entity: Node, _delta: float) -> int:
	if entity.has_method("captain_summon_reinforcements"):
		entity.captain_summon_reinforcements()
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_captain_charge(entity: Node, _delta: float) -> int:
	if not entity.has_valid_target():
		return BehaviorTree.Status.FAILURE

	var dir: Vector2 = (entity.current_target.global_position - entity.global_position).normalized()
	if entity.has_method("captain_charge_attack"):
		entity.captain_charge_attack(dir)
		return BehaviorTree.Status.SUCCESS
	return BehaviorTree.Status.FAILURE


static func _action_stay_in_center(_entity: Node, _delta: float) -> int:
	# Storm Core: 이동 안 함
	return BehaviorTree.Status.SUCCESS


# =====================================================
# BEHAVIOR FACTORY
# =====================================================

## 적 데이터의 behavior_id에 따라 적절한 BT 반환
static func create_behavior(behavior_id: String) -> BehaviorTree.BTSelector:
	match behavior_id:
		"melee_basic":
			return melee_basic()
		"melee_shielded":
			return melee_shielded()
		"ranged_basic":
			return ranged_basic()
		"melee_jumper":
			return melee_jumper()
		"melee_heavy":
			return melee_heavy()
		"melee_brute":
			return melee_brute()
		"support_hacker":
			return support_hacker()
		"ranged_sniper":
			return ranged_sniper()
		"support_carrier":
			return support_carrier()
		"support_shield":
			return support_shield()
		"kamikaze":
			return kamikaze()
		"boss_captain":
			return boss_captain()
		"boss_storm":
			return boss_storm()
		_:
			push_warning("Unknown behavior_id: %s, using melee_basic" % behavior_id)
			return melee_basic()
