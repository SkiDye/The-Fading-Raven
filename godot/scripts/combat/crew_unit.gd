## CrewUnit - 플레이어 크루 유닛
## Bad North 스타일 분대 관리
extends BaseUnit
class_name CrewUnit

# ===========================================
# 크루 데이터
# ===========================================

var crew_data: Dictionary = {}
var class_id: String = ""
var class_data: Dictionary = {}

# 분대 상태
var squad_size: int = 8
var max_squad_size: int = 8
var rank: String = "standard"
var trait_id: String = ""

# 스킬
var skill_level: int = 0
var skill_cooldown: float = 0.0
var charges_used: Dictionary = {}

# 장비
var equipment_id: String = ""
var equipment_level: int = 0

# Bad North 메카닉 상태
var in_melee: bool = false
var lance_raised: bool = true
var shield_active: bool = true
var recovery_timer: float = 0.0

# 배치
var is_deployed: bool = false
var assigned_facility: Vector2i = Vector2i(-1, -1)


# ===========================================
# 시그널
# ===========================================

signal squad_member_died(crew: CrewUnit, remaining: int)
signal squad_wiped(crew: CrewUnit)
signal skill_used(crew: CrewUnit, skill_id: String)
signal recovery_started(crew: CrewUnit, duration: float)
signal recovery_finished(crew: CrewUnit)
signal lance_state_changed(crew: CrewUnit, is_raised: bool)
signal shield_state_changed(crew: CrewUnit, is_active: bool)


# ===========================================
# 초기화
# ===========================================

func _setup_unit() -> void:
	team = 0
	add_to_group("crews")


func initialize_crew(data: Dictionary, tile_grid: TileGrid, path_finder: Pathfinder) -> void:
	crew_data = data.duplicate(true)

	# 기본 데이터
	unit_id = data.get("id", "")
	unit_name = data.get("name", "Crew")
	class_id = data.get("class_id", "guardian")

	# 클래스 데이터 로드
	class_data = DataRegistry.get_crew_class(class_id)

	# 상태 설정
	squad_size = data.get("squad_size", class_data.get("base_squad_size", 8))
	max_squad_size = data.get("max_squad_size", squad_size)
	rank = data.get("rank", "standard")
	trait_id = data.get("trait_id", "")
	skill_level = data.get("skill_level", 0)
	equipment_id = data.get("equipment_id", "")
	equipment_level = data.get("equipment_level", 0)

	# 전투 스탯
	move_speed = class_data.get("move_speed", 100.0)
	attack_damage = class_data.get("attack_damage", 10)
	attack_range = class_data.get("attack_range", 1)
	attack_cooldown = class_data.get("attack_speed", 1.0)

	# 그리드 초기화
	initialize(data, tile_grid, path_finder)

	_update_health_bar()


# ===========================================
# Bad North 메카닉
# ===========================================

## 센티넬 랜스 상태 업데이트
func update_lance_state(nearest_enemy_distance: float) -> void:
	if class_id != "sentinel":
		return

	var state := CombatMechanics.check_lance_state(position, nearest_enemy_distance)
	var was_raised := lance_raised
	lance_raised = state["is_raised"]

	if was_raised != lance_raised:
		lance_state_changed.emit(self, lance_raised)

		if lance_raised:
			EventBus.crew_lance_raised.emit(self)
		else:
			EventBus.crew_lance_lowered.emit(self)


## 가디언 실드 상태 업데이트
func update_shield_state(is_engaging_melee: bool) -> void:
	if class_id != "guardian":
		return

	var was_active := shield_active
	shield_active = not is_engaging_melee
	in_melee = is_engaging_melee

	if was_active != shield_active:
		shield_state_changed.emit(self, shield_active)

		if shield_active:
			EventBus.crew_shield_enabled.emit(self)
		else:
			EventBus.crew_shield_disabled.emit(self)


## 회복 시작 (시설에서)
func start_recovery() -> void:
	if squad_size >= max_squad_size:
		return

	var duration := CombatMechanics.calculate_recovery_time(squad_size)
	recovery_timer = duration
	_set_state(CombatMechanics.CombatState.RECOVERING)
	recovery_started.emit(self, duration)
	EventBus.crew_recovering.emit(self, duration)


func _process_recovery(delta: float) -> void:
	if recovery_timer <= 0:
		return

	recovery_timer -= delta

	if recovery_timer <= 0:
		_finish_recovery()


func _finish_recovery() -> void:
	# 분대원 1명 회복
	squad_size = mini(squad_size + 1, max_squad_size)
	_update_health_bar()

	_set_state(CombatMechanics.CombatState.IDLE)
	recovery_finished.emit(self)
	EventBus.crew_recovered.emit(self)


# ===========================================
# 데미지 처리
# ===========================================

func _calculate_damage_taken(base_damage: int, damage_type: CombatMechanics.DamageType, _source: BaseUnit) -> int:
	var defender_info := {
		"class_id": class_id,
		"trait_id": trait_id,
		"position": grid_position,
		"in_melee": in_melee,
	}

	return CombatMechanics.calculate_damage(base_damage, damage_type, {}, defender_info, grid)


func _apply_damage(damage: int) -> void:
	var result := CombatMechanics.calculate_casualties(damage, squad_size, {
		"trait_id": trait_id,
	})

	if result["casualties"] > 0:
		squad_size = result["remaining"]
		squad_member_died.emit(self, squad_size)
		EventBus.crew_member_died.emit(self, squad_size)

	_update_health_bar()


func _check_death() -> bool:
	return squad_size <= 0


func _die() -> void:
	super._die()
	squad_wiped.emit(self)
	EventBus.crew_wiped.emit(self)


# ===========================================
# 공격
# ===========================================

func _process_combat(delta: float) -> void:
	if not current_target or not current_target.is_alive:
		current_target = null
		_set_state(CombatMechanics.CombatState.IDLE)
		return

	# 센티넬 랜스 체크
	if class_id == "sentinel":
		var dist := get_distance_to(current_target)
		update_lance_state(dist)

		if not lance_raised:
			return  # 무력화됨

	# 공격 쿨다운 처리
	if attack_timer > 0:
		attack_timer -= delta
		return

	# 사거리 체크
	if not is_in_range(current_target, attack_range):
		return

	attack(current_target)


func _perform_attack(target: BaseUnit) -> void:
	var damage := attack_damage

	# 랭크 보너스
	var rank_bonus: Dictionary = Balance.ECONOMY["rank_bonuses"].get(rank, {})
	damage = int(damage * (1.0 + rank_bonus.get("damage_bonus", 0.0)))

	# 특성 보너스
	if trait_id == "sharp_edge":
		damage = int(damage * 1.1)

	# 상성 보너스
	if target is EnemyUnit:
		var enemy := target as EnemyUnit
		damage = int(damage * CombatMechanics.get_matchup_multiplier(class_id, enemy.enemy_type))

	target.take_damage(damage, self, _get_damage_type())

	# 이벤트
	EventBus.crew_attacked.emit(self, target, damage)


func _get_damage_type() -> CombatMechanics.DamageType:
	if class_data.get("attack_type") == "ranged":
		return CombatMechanics.DamageType.RANGED
	return CombatMechanics.DamageType.MELEE


# ===========================================
# 스킬
# ===========================================

func use_skill(target_position: Vector2i = Vector2i(-1, -1)) -> bool:
	var can_use := CombatMechanics.can_use_skill(crew_data, skill_level)

	if not can_use["can_use"]:
		return false

	# 스킬 실행
	_execute_skill(target_position)

	# 쿨다운 설정
	skill_cooldown = CombatMechanics.get_skill_cooldown(class_id, skill_level)

	# 사용 횟수 증가
	if not charges_used.has("skill"):
		charges_used["skill"] = 0
	charges_used["skill"] += 1

	skill_used.emit(self, class_data.get("skill", {}).get("id", ""))
	EventBus.crew_skill_used.emit(self, class_data.get("skill", {}).get("id", ""))

	return true


func _execute_skill(_target_position: Vector2i) -> void:
	# 클래스별 스킬 로직
	match class_id:
		"guardian":
			_skill_shield_bash()
		"sentinel":
			_skill_brace()
		"ranger":
			_skill_rapid_fire()
		"engineer":
			_skill_deploy_turret(_target_position)
		"bionic":
			_skill_overdrive()


func _skill_shield_bash() -> void:
	# 가디언: 방패 밀치기 - 전방 적 넉백
	pass


func _skill_brace() -> void:
	# 센티넬: 대기 자세 - 다음 공격 데미지 증가
	pass


func _skill_rapid_fire() -> void:
	# 레인저: 연사 - 잠시 공속 증가
	pass


func _skill_deploy_turret(_pos: Vector2i) -> void:
	# 엔지니어: 터렛 설치
	pass


func _skill_overdrive() -> void:
	# 바이오닉: 과부하 - 일시적 강화
	pass


# ===========================================
# UI 업데이트
# ===========================================

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_squad_size
		health_bar.value = squad_size


# ===========================================
# 데이터 동기화
# ===========================================

func sync_to_data() -> void:
	crew_data["squad_size"] = squad_size
	crew_data["max_squad_size"] = max_squad_size
	crew_data["skill_cooldown"] = skill_cooldown
	crew_data["charges_used"] = charges_used.duplicate()
	crew_data["is_alive"] = is_alive
	crew_data["is_deployed"] = is_deployed


func get_data() -> Dictionary:
	sync_to_data()
	return crew_data
