class_name CombatMatchmaker
extends RefCounted

## 1:1 전투 매칭 시스템
## Bad North 스타일 개별 유닛 교전 관리

# ===== TYPES =====

## 교전 쌍 정보
class EngagementPair:
	var attacker: Node3D  # SquadMember3D 또는 EnemyUnit3D
	var defender: Node3D
	var start_time: float

	func _init(a: Node3D, d: Node3D) -> void:
		attacker = a
		defender = d
		start_time = Time.get_ticks_msec() / 1000.0


# ===== STATE =====

## 활성 교전 쌍: attacker -> EngagementPair
var _active_engagements: Dictionary = {}

## 교전 중인 유닛 집합 (빠른 조회용)
var _engaged_units: Dictionary = {}  # Node3D -> true

## 대기 중인 유닛 큐 (매칭 대기)
var _waiting_queue: Array[Node3D] = []


# ===== MAIN API =====

func request_opponent(requester: Node3D, preferred_targets: Array = []) -> Node3D:
	## 교전 상대 요청
	## @param requester: 교전을 요청하는 유닛
	## @param preferred_targets: 우선 타겟 후보 (가까운 순)
	## @return: 매칭된 상대 또는 null

	if not is_instance_valid(requester):
		return null

	# 이미 교전 중이면 현재 상대 반환
	if is_engaged(requester):
		var pair: EngagementPair = _active_engagements.get(requester)
		if pair:
			return pair.defender
		return null

	# 유효한 타겟 찾기
	var target: Node3D = _find_best_target(requester, preferred_targets)

	if target:
		_create_engagement(requester, target)
		return target

	# 타겟 없으면 대기 큐에 추가
	if requester not in _waiting_queue:
		_waiting_queue.append(requester)

	return null


func release_engagement(unit: Node3D) -> void:
	## 교전 종료 처리
	if not is_instance_valid(unit):
		return

	# 공격자로서 교전 중이었으면
	if _active_engagements.has(unit):
		var pair: EngagementPair = _active_engagements[unit]
		if pair and is_instance_valid(pair.defender):
			_engaged_units.erase(pair.defender)
		_active_engagements.erase(unit)
		_engaged_units.erase(unit)

	# 방어자로서 교전 중이었으면
	for attacker in _active_engagements.keys():
		var pair: EngagementPair = _active_engagements[attacker]
		if pair and pair.defender == unit:
			_active_engagements.erase(attacker)
			_engaged_units.erase(attacker)
			break

	_engaged_units.erase(unit)

	# 대기 큐에서도 제거
	var idx: int = _waiting_queue.find(unit)
	if idx >= 0:
		_waiting_queue.remove_at(idx)


func is_engaged(unit: Node3D) -> bool:
	## 유닛이 교전 중인지 확인
	return _engaged_units.has(unit)


func get_opponent(unit: Node3D) -> Node3D:
	## 현재 교전 상대 반환
	if _active_engagements.has(unit):
		var pair: EngagementPair = _active_engagements[unit]
		if pair:
			return pair.defender

	# 방어자로서 확인
	for attacker in _active_engagements.keys():
		var pair: EngagementPair = _active_engagements[attacker]
		if pair and pair.defender == unit:
			return attacker

	return null


func get_engagement_count() -> int:
	## 현재 활성 교전 수
	return _active_engagements.size()


func clear_all() -> void:
	## 모든 교전 정리
	_active_engagements.clear()
	_engaged_units.clear()
	_waiting_queue.clear()


# ===== INTERNAL =====

func _find_best_target(requester: Node3D, preferred_targets: Array) -> Node3D:
	## 최적 타겟 찾기 (비교전 중인 가장 가까운 유닛)

	# 우선 후보에서 찾기
	for candidate in preferred_targets:
		if _is_valid_target(requester, candidate):
			return candidate

	return null


func _is_valid_target(requester: Node3D, target: Node3D) -> bool:
	## 유효한 타겟인지 확인
	if not is_instance_valid(target):
		return false

	# 죽은 유닛 제외
	if "is_alive" in target and not target.is_alive:
		return false

	# 같은 팀 제외
	if "team" in requester and "team" in target:
		if requester.team == target.team:
			return false

	# 이미 다른 유닛과 교전 중이면 제외 (1:1 유지)
	# 단, 아군 vs 적은 여러 아군이 한 적 공격 가능하도록 예외
	if is_engaged(target):
		# 적은 여러 아군에게 공격받을 수 있음
		if _is_enemy(target):
			return true
		return false

	return true


func _is_enemy(unit: Node3D) -> bool:
	## 적 유닛인지 확인
	if unit.is_in_group("enemies"):
		return true
	if "team" in unit and unit.team == 1:
		return true
	return false


func _create_engagement(attacker: Node3D, defender: Node3D) -> void:
	## 교전 쌍 생성
	var pair := EngagementPair.new(attacker, defender)
	_active_engagements[attacker] = pair
	_engaged_units[attacker] = true
	_engaged_units[defender] = true

	# 대기 큐에서 제거
	var idx: int = _waiting_queue.find(attacker)
	if idx >= 0:
		_waiting_queue.remove_at(idx)


func process_waiting_queue(available_targets: Array) -> void:
	## 대기 큐 처리 (매 프레임 호출)
	var to_remove: Array[int] = []

	for i in range(_waiting_queue.size()):
		var unit: Node3D = _waiting_queue[i]
		if not is_instance_valid(unit):
			to_remove.append(i)
			continue

		var target: Node3D = _find_best_target(unit, available_targets)
		if target:
			_create_engagement(unit, target)
			to_remove.append(i)

	# 역순으로 제거
	to_remove.reverse()
	for idx in to_remove:
		if idx < _waiting_queue.size():
			_waiting_queue.remove_at(idx)


# ===== DEBUG =====

func get_debug_info() -> String:
	var info := "=== CombatMatchmaker ===\n"
	info += "Active engagements: %d\n" % _active_engagements.size()
	info += "Engaged units: %d\n" % _engaged_units.size()
	info += "Waiting queue: %d\n" % _waiting_queue.size()
	return info
