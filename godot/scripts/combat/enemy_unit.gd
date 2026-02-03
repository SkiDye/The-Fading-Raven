## EnemyUnit - 적 유닛
## AI 기반 공격 로직
extends BaseUnit
class_name EnemyUnit

# ===========================================
# 적 데이터
# ===========================================

var enemy_type: String = ""
var enemy_data: Dictionary = {}

# 상태
var health: int = 100
var max_health: int = 100
var armor: int = 0

# AI 상태
var ai_state: String = "approaching"  # approaching, attacking, retreating
var target_facility: Vector2i = Vector2i(-1, -1)
var spawn_point: Vector2i = Vector2i.ZERO

# 특수 행동
var has_landed: bool = false
var is_charging: bool = false
var charge_target: BaseUnit = null


# ===========================================
# 시그널
# ===========================================

signal enemy_landed(enemy: EnemyUnit, position: Vector2i)
signal enemy_reached_facility(enemy: EnemyUnit, facility_pos: Vector2i)


# ===========================================
# 초기화
# ===========================================

func _setup_unit() -> void:
	team = 1
	add_to_group("enemies")


func initialize_enemy(type: String, tile_grid: TileGrid, path_finder: Pathfinder, spawn_pos: Vector2i) -> void:
	enemy_type = type
	enemy_data = DataRegistry.get_enemy(type)

	# 기본 데이터
	unit_id = str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	unit_name = enemy_data.get("name", type)

	# 스탯
	health = enemy_data.get("health", 100)
	max_health = health
	armor = enemy_data.get("armor", 0)
	move_speed = enemy_data.get("move_speed", 80.0)
	attack_damage = enemy_data.get("attack_damage", 10)
	attack_range = enemy_data.get("attack_range", 1)
	attack_cooldown = enemy_data.get("attack_speed", 1.5)

	spawn_point = spawn_pos

	# 그리드 초기화
	initialize({"id": unit_id, "name": unit_name, "position": spawn_pos}, tile_grid, path_finder)

	_update_health_bar()


# ===========================================
# AI 루프
# ===========================================

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_alive:
		return

	# AI 업데이트
	_update_ai(delta)


func _update_ai(_delta: float) -> void:
	match ai_state:
		"approaching":
			_ai_approach()
		"attacking":
			_ai_attack()
		"retreating":
			_ai_retreat()


func _ai_approach() -> void:
	# 이미 이동 중이면 스킵
	if combat_state == CombatMechanics.CombatState.MOVING:
		return

	# 가장 가까운 시설 찾기
	if target_facility == Vector2i(-1, -1):
		target_facility = pathfinder.find_nearest_facility(grid_position)

	if target_facility == Vector2i(-1, -1):
		return

	# 시설 도달 체크
	if grid_position == target_facility or get_grid_distance_to_pos(target_facility) <= 1:
		_on_reached_facility()
		return

	# 경로 상의 크루 확인
	var nearby_crew := _find_nearby_crew()
	if nearby_crew:
		set_target(nearby_crew)
		ai_state = "attacking"
		_set_state(CombatMechanics.CombatState.ENGAGING)
		return

	# 이동
	move_to(target_facility)


func _ai_attack() -> void:
	if not current_target or not current_target.is_alive:
		current_target = null
		ai_state = "approaching"
		_set_state(CombatMechanics.CombatState.IDLE)
		return

	# 거리 체크
	var dist := get_grid_distance_to(current_target)

	if dist > attack_range + 2:
		# 타겟이 너무 멀면 다시 접근
		ai_state = "approaching"
		return

	# 공격 범위 밖이면 접근
	if dist > attack_range:
		if combat_state != CombatMechanics.CombatState.MOVING:
			move_to(current_target.grid_position)
		return

	# 공격
	_set_state(CombatMechanics.CombatState.ENGAGING)


func _ai_retreat() -> void:
	# 후퇴 (특수 적용)
	if combat_state != CombatMechanics.CombatState.MOVING:
		# 스폰 포인트로 돌아가기
		move_to(spawn_point)


func _find_nearby_crew() -> CrewUnit:
	var search_range := 3

	for dy in range(-search_range, search_range + 1):
		for dx in range(-search_range, search_range + 1):
			var check_pos := grid_position + Vector2i(dx, dy)
			var crews := grid.get_crews_at(check_pos)
			if not crews.is_empty():
				return crews[0] as CrewUnit

	return null


func _on_reached_facility() -> void:
	enemy_reached_facility.emit(self, target_facility)
	EventBus.enemy_reached_facility.emit(self, target_facility)

	# 시설 공격 시작
	ai_state = "attacking"


# ===========================================
# 상륙 처리
# ===========================================

func land(landing_position: Vector2i) -> void:
	has_landed = true
	grid_position = landing_position

	if grid:
		grid.add_entity(grid_position, self)

	position = _grid_to_world(grid_position)

	enemy_landed.emit(self, landing_position)
	EventBus.enemy_landed.emit(self, landing_position)

	# 상륙 넉백 적용
	_apply_landing_knockback()


func _apply_landing_knockback() -> void:
	var knockback_range := Balance.LANDING_KNOCKBACK["range"]

	# 주변 크루 찾기
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var check_pos := grid_position + Vector2i(dx, dy)
			var crews := grid.get_crews_at(check_pos)

			for crew in crews:
				var crew_unit := crew as CrewUnit
				if not crew_unit:
					continue

				var knockback := CombatMechanics.calculate_landing_knockback(
					position,
					crew_unit.position,
					grid
				)

				if knockback["applied"]:
					_knockback_unit(crew_unit, knockback)


func _knockback_unit(unit: CrewUnit, knockback: Dictionary) -> void:
	var target_pos: Vector2i = knockback["target_position"]

	if knockback["is_void_death"]:
		# 우주로 추락
		unit.take_damage(9999, self, CombatMechanics.DamageType.VOID)
		EventBus.show_toast("%s 우주로 추락!" % unit.unit_name, "danger")
	elif knockback["is_valid"]:
		# 밀려남
		unit._update_grid_position(target_pos)
		unit.position = unit._grid_to_world(target_pos)


# ===========================================
# 전투 처리
# ===========================================

func _process_combat(delta: float) -> void:
	if not current_target or not current_target.is_alive:
		current_target = null
		return

	if attack_timer > 0:
		attack_timer -= delta
		return

	if not is_in_range(current_target, attack_range):
		return

	attack(current_target)


func _perform_attack(target: BaseUnit) -> void:
	var damage := attack_damage

	# 특수 공격 (적 타입별)
	damage = _apply_special_attack_bonus(damage, target)

	var damage_type := CombatMechanics.DamageType.MELEE
	if enemy_data.get("attack_type") == "ranged":
		damage_type = CombatMechanics.DamageType.RANGED

	target.take_damage(damage, self, damage_type)

	EventBus.enemy_attacked.emit(self, target, damage)


func _apply_special_attack_bonus(base_damage: int, target: BaseUnit) -> int:
	var damage := base_damage

	match enemy_type:
		"brute":
			# 브루트: 가디언에게 추가 데미지
			if target is CrewUnit and (target as CrewUnit).class_id == "guardian":
				damage = int(damage * 1.3)
		"berserker":
			# 버서커: 체력이 낮을수록 공격력 증가
			var health_ratio := float(health) / float(max_health)
			if health_ratio < 0.5:
				damage = int(damage * 1.5)
		"infiltrator":
			# 침투자: 후방 공격 시 추가 데미지
			damage = int(damage * 1.2)

	return damage


# ===========================================
# 데미지 처리
# ===========================================

func _calculate_damage_taken(base_damage: int, damage_type: CombatMechanics.DamageType, _source: BaseUnit) -> int:
	var damage := base_damage

	# 장갑 감소
	if damage_type == CombatMechanics.DamageType.MELEE or damage_type == CombatMechanics.DamageType.RANGED:
		damage = maxi(1, damage - armor)

	return damage


func _apply_damage(damage: int) -> void:
	health = maxi(0, health - damage)
	_update_health_bar()


func _check_death() -> bool:
	return health <= 0


func _die() -> void:
	super._die()
	EventBus.enemy_killed.emit(self, current_target)


# ===========================================
# UI
# ===========================================

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health


# ===========================================
# 유틸리티
# ===========================================

func get_grid_distance_to_pos(pos: Vector2i) -> int:
	return absi(grid_position.x - pos.x) + absi(grid_position.y - pos.y)


func get_threat_level() -> int:
	return enemy_data.get("budget", 1)
