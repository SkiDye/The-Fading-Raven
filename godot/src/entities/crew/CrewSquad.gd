class_name CrewSquad
extends Entity

## 크루 스쿼드
## 여러 CrewMember를 관리하고 이동, 전투, 스킬을 처리


# ===== SIGNALS =====

signal member_died(member: CrewMember)
signal squad_wiped()
signal skill_ready()
signal skill_cooldown_changed(remaining: float, total: float)
signal recovery_progress(progress: float)
signal recovery_completed()
signal formation_changed()
signal target_changed(new_target: Node)


# ===== CONSTANTS =====

const MEMBER_SCENE_PATH = "res://src/entities/crew/CrewMember.tscn"


# ===== EXPORTS =====

@export var class_id: String = "guardian"
@export var rank: int = 0  # 0=Rookie, 1=Standard, 2=Veteran, 3=Elite
@export var skill_level: int = 0
@export var equipment_id: String = ""
@export var equipment_level: int = 0
@export var trait_id: String = ""


# ===== PUBLIC VARIABLES =====

var members: Array[CrewMember] = []
var leader: CrewMember
var current_target: Node
var is_in_combat: bool = false
var is_recovering: bool = false
var skill_cooldown_remaining: float = 0.0
var formation_type: String = "line"
var formation_positions: Array[Vector2] = []


# ===== PRIVATE VARIABLES =====

var _member_scene: PackedScene
var _base_stats: Dictionary = {}
var _recovery_tick_count: int = 0
var _max_recovery_ticks: int = 10


# ===== ONREADY =====

@onready var members_container: Node2D = $Members
@onready var skill_cooldown_timer: Timer = $SkillCooldownTimer
@onready var recovery_timer: Timer = $RecoveryTimer
@onready var selection_indicator: ColorRect = $SelectionIndicator


# ===== LIFECYCLE =====

func _ready() -> void:
	super._ready()
	team = 0
	add_to_group("crews")

	_load_member_scene()
	_setup_base_stats()
	_setup_timers()


func _process(delta: float) -> void:
	super._process(delta)

	if is_stunned:
		return

	_update_skill_cooldown(delta)
	_process_combat(delta)
	_update_member_positions()


# ===== INITIALIZATION =====

func _load_member_scene() -> void:
	if ResourceLoader.exists(MEMBER_SCENE_PATH):
		_member_scene = load(MEMBER_SCENE_PATH)
	else:
		push_warning("CrewSquad: CrewMember scene not found at %s" % MEMBER_SCENE_PATH)


func _setup_base_stats() -> void:
	var squad_sizes = Constants.BALANCE.get("squad_size", {})

	_base_stats = {
		"guardian": {
			"squad_size": squad_sizes.get("guardian", 8),
			"hp": 10,
			"damage": 3,
			"attack_speed": 1.0,
			"move_speed": 1.5,
			"attack_range": 1.0,
			"cooldown": Constants.BALANCE.skill_cooldowns.get("shield_bash", 20.0),
			"color": Color(0.2, 0.6, 1.0),
			"formation": "line"
		},
		"sentinel": {
			"squad_size": squad_sizes.get("sentinel", 8),
			"hp": 12,
			"damage": 4,
			"attack_speed": 0.8,
			"move_speed": 1.2,
			"attack_range": 1.5,
			"cooldown": Constants.BALANCE.skill_cooldowns.get("lance_charge", 25.0),
			"color": Color(0.8, 0.8, 0.2),
			"formation": "line"
		},
		"ranger": {
			"squad_size": squad_sizes.get("ranger", 8),
			"hp": 8,
			"damage": 5,
			"attack_speed": 1.2,
			"move_speed": 1.3,
			"attack_range": 5.0,
			"cooldown": Constants.BALANCE.skill_cooldowns.get("volley_fire", 15.0),
			"color": Color(0.2, 0.8, 0.2),
			"formation": "square"
		},
		"engineer": {
			"squad_size": squad_sizes.get("engineer", 6),
			"hp": 8,
			"damage": 2,
			"attack_speed": 0.8,
			"move_speed": 1.4,
			"attack_range": 3.0,
			"cooldown": Constants.BALANCE.skill_cooldowns.get("deploy_turret", 30.0),
			"color": Color(1.0, 0.5, 0.0),
			"formation": "wedge"
		},
		"bionic": {
			"squad_size": squad_sizes.get("bionic", 5),
			"hp": 6,
			"damage": 6,
			"attack_speed": 1.5,
			"move_speed": 2.0,
			"attack_range": 1.0,
			"cooldown": Constants.BALANCE.skill_cooldowns.get("blink", 15.0),
			"color": Color(0.8, 0.2, 0.8),
			"formation": "wedge"
		}
	}


func _setup_timers() -> void:
	if skill_cooldown_timer:
		skill_cooldown_timer.one_shot = true
		skill_cooldown_timer.timeout.connect(_on_skill_cooldown_timeout)

	if recovery_timer:
		recovery_timer.one_shot = false
		recovery_timer.timeout.connect(_on_recovery_tick)


## 스쿼드를 초기화합니다.
## [param hp_ratio]: 초기 체력 비율 (0.0 ~ 1.0)
func initialize_squad(hp_ratio: float = 1.0) -> void:
	var stats = _get_class_stats()
	var squad_size = stats.squad_size

	# Entity의 base_move_speed 설정
	base_move_speed = stats.move_speed

	# 전체 체력 계산
	max_hp = squad_size * stats.hp
	current_hp = int(max_hp * hp_ratio)

	# 포메이션 설정
	formation_type = stats.formation
	_generate_formation(squad_size)

	# 멤버 생성
	_spawn_members(squad_size, stats)

	# 스킬 쿨다운 설정
	if skill_cooldown_timer:
		skill_cooldown_timer.wait_time = get_effective_cooldown()


func _spawn_members(count: int, stats: Dictionary) -> void:
	if _member_scene == null:
		push_warning("CrewSquad: Cannot spawn members, scene not loaded")
		return

	# 기존 멤버 제거
	for member in members:
		member.queue_free()
	members.clear()

	for i in range(count):
		var member: CrewMember = _member_scene.instantiate()
		member.squad = self
		member.is_leader = (i == 0)
		member.initialize(
			class_id,
			stats.hp,
			stats.damage,
			stats.attack_speed,
			stats.color
		)

		# Titan Frame 특성 (리더 HP 3배)
		if member.is_leader and trait_id == "titan_frame":
			member.apply_leader_bonus(3.0)

		members_container.add_child(member)
		members.append(member)

		if i == 0:
			leader = member

		member.died.connect(_on_member_died.bind(member))

	# 초기 체력에 맞게 멤버 사망 처리
	_sync_members_to_health()


func _sync_members_to_health() -> void:
	var stats = _get_class_stats()
	var alive_count = ceili(float(current_hp) / float(stats.hp))
	alive_count = clampi(alive_count, 0, members.size())

	for i in range(members.size()):
		if i < alive_count:
			if not members[i].is_alive:
				members[i].revive()
		else:
			if members[i].is_alive:
				members[i].is_alive = false
				members[i].visible = false


# ===== FORMATION =====

func _generate_formation(count: int) -> void:
	formation_positions.clear()

	match formation_type:
		"line":
			formation_positions = _generate_line_formation(count)
		"square":
			formation_positions = _generate_square_formation(count)
		"wedge":
			formation_positions = _generate_wedge_formation(count)
		_:
			formation_positions = _generate_line_formation(count)

	formation_changed.emit()


func _generate_line_formation(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var spacing = 8.0
	var start_x = -((count - 1) * spacing) / 2.0

	for i in range(count):
		result.append(Vector2(start_x + i * spacing, 0))

	return result


func _generate_square_formation(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var cols = int(ceil(sqrt(count)))
	var spacing = 8.0

	for i in range(count):
		@warning_ignore("integer_division")
		var row = i / cols
		var col = i % cols
		result.append(Vector2(
			(col - (cols - 1) / 2.0) * spacing,
			row * spacing
		))

	return result


func _generate_wedge_formation(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	result.append(Vector2.ZERO)

	var spacing = 8.0
	for i in range(1, count):
		@warning_ignore("integer_division")
		var row = (i + 1) / 2
		var side = 1 if i % 2 == 1 else -1
		result.append(Vector2(row * spacing * side * 0.7, row * spacing))

	return result


func _update_member_positions() -> void:
	if leader == null or formation_positions.is_empty():
		return

	for i in range(members.size()):
		if i < formation_positions.size() and members[i].is_alive:
			var target_pos = global_position + formation_positions[i]
			members[i].move_towards_position(target_pos, 0.1)


# ===== COMMANDS =====

## 이동 명령을 내립니다.
## [param target_tile]: 목표 타일
## [param path]: 경로 (타일 배열)
func command_move(target_tile: Vector2i, path: Array[Vector2i]) -> void:
	stop_recovery()
	move_along_path(path)
	EventBus.move_command_issued.emit(self, target_tile)


## 공격 명령을 내립니다.
## [param target]: 공격 대상
func command_attack(target: Node) -> void:
	current_target = target
	is_in_combat = true
	target_changed.emit(target)

	for member in members:
		if member.is_alive:
			member.set_target(target)


## 정지 명령을 내립니다.
func command_stop() -> void:
	stop_movement()
	current_target = null
	is_in_combat = false

	for member in members:
		member.clear_target()


# ===== COMBAT =====

func _process_combat(_delta: float) -> void:
	if not is_in_combat or current_target == null:
		return

	# 타겟 유효성 검사
	if not is_instance_valid(current_target):
		current_target = null
		is_in_combat = false
		return

	if "is_alive" in current_target and not current_target.is_alive:
		current_target = null
		is_in_combat = false
		return

	_set_state(Constants.EntityState.ATTACKING)


# ===== SKILLS =====

func _update_skill_cooldown(delta: float) -> void:
	if skill_cooldown_remaining > 0:
		skill_cooldown_remaining -= delta
		var total = get_effective_cooldown()
		skill_cooldown_changed.emit(skill_cooldown_remaining, total)

		if skill_cooldown_remaining <= 0:
			skill_cooldown_remaining = 0
			skill_ready.emit()


func _on_skill_cooldown_timeout() -> void:
	skill_ready.emit()


## 스킬 사용 가능 여부를 반환합니다.
func can_use_skill() -> bool:
	return skill_cooldown_remaining <= 0 and not is_stunned and is_alive


## 스킬을 사용합니다.
## [param target]: 스킬 타겟
## [return]: 성공 여부
func use_skill(target) -> bool:
	if not can_use_skill():
		return false

	var skill_id = _get_skill_id()
	skill_cooldown_remaining = get_effective_cooldown()

	EventBus.skill_used.emit(self, skill_id, target, skill_level)

	match skill_id:
		"shield_bash":
			_execute_shield_bash(target)
		"lance_charge":
			_execute_lance_charge(target)
		"volley_fire":
			_execute_volley_fire(target)
		"deploy_turret":
			_execute_deploy_turret(target)
		"blink":
			_execute_blink(target)

	return true


func _get_skill_id() -> String:
	match class_id:
		"guardian": return "shield_bash"
		"sentinel": return "lance_charge"
		"ranger": return "volley_fire"
		"engineer": return "deploy_turret"
		"bionic": return "blink"
		_: return ""


func _execute_shield_bash(_direction) -> void:
	_set_state(Constants.EntityState.USING_SKILL)
	# S08에서 실제 효과 구현


func _execute_lance_charge(_direction) -> void:
	_set_state(Constants.EntityState.USING_SKILL)
	# S08에서 실제 효과 구현


func _execute_volley_fire(_target_pos) -> void:
	_set_state(Constants.EntityState.USING_SKILL)
	# S08에서 실제 효과 구현


func _execute_deploy_turret(target_pos) -> void:
	var turret_scene_path = "res://src/entities/turret/Turret.tscn"

	if not ResourceLoader.exists(turret_scene_path):
		push_warning("CrewSquad: Turret scene not found")
		return

	var turret_scene = load(turret_scene_path)
	var turret = turret_scene.instantiate()
	turret.owner_squad = self
	turret.level = skill_level
	turret.tile_position = target_pos if target_pos is Vector2i else Vector2i(target_pos)

	get_parent().add_child(turret)
	turret.global_position = _tile_to_world(turret.tile_position)

	EventBus.turret_deployed.emit(turret, turret.tile_position)


func _execute_blink(target_pos) -> void:
	var target_tile = target_pos if target_pos is Vector2i else Vector2i(target_pos)
	set_tile_position(target_tile)

	# 레벨 3: 무적 적용
	if skill_level >= 2:
		set_invulnerable(0.5)

	_set_state(Constants.EntityState.IDLE)


# ===== EQUIPMENT =====

## 장비 사용 가능 여부를 반환합니다.
func can_use_equipment() -> bool:
	if equipment_id.is_empty():
		return false
	return true


## 장비를 사용합니다.
func use_equipment() -> bool:
	if not can_use_equipment():
		return false

	EventBus.equipment_activated.emit(self, equipment_id)
	return true


# ===== RECOVERY =====

## 회복을 시작합니다.
func start_recovery(facility: Node = null) -> void:
	if is_recovering:
		return

	if get_alive_count() >= get_max_squad_size():
		return

	is_recovering = true
	_recovery_tick_count = 0

	var recovery_time = _get_total_recovery_time(facility)
	recovery_timer.wait_time = recovery_time / _max_recovery_ticks
	recovery_timer.start()

	EventBus.crew_recovery_started.emit(self, facility)


func _get_total_recovery_time(facility: Node) -> float:
	var base_time = (get_max_squad_size() - get_alive_count()) * Constants.BALANCE.recovery_time_per_unit

	if trait_id == "quick_recovery":
		base_time *= 0.67

	if facility and facility.has_method("get_facility_id"):
		if facility.get_facility_id() == "medical":
			base_time *= 0.5

	return base_time


func _on_recovery_tick() -> void:
	if not is_recovering:
		return

	_recovery_tick_count += 1
	_revive_one_member()

	var alive_count = get_alive_count()
	var max_count = get_max_squad_size()
	var progress = float(alive_count) / float(max_count)
	recovery_progress.emit(progress)

	if alive_count >= max_count or _recovery_tick_count >= _max_recovery_ticks:
		_complete_recovery()


func _revive_one_member() -> void:
	for member in members:
		if not member.is_alive:
			member.revive()
			var stats = _get_class_stats()
			current_hp = mini(current_hp + stats.hp, max_hp)
			health_changed.emit(current_hp, max_hp)
			return


func _complete_recovery() -> void:
	is_recovering = false
	recovery_timer.stop()
	recovery_completed.emit()
	EventBus.crew_recovery_completed.emit(self)


## 회복을 중단합니다.
func stop_recovery() -> void:
	if is_recovering:
		is_recovering = false
		recovery_timer.stop()


# ===== MEMBER MANAGEMENT =====

## 살아있는 멤버 수를 반환합니다.
func get_alive_count() -> int:
	var count = 0
	for member in members:
		if member.is_alive:
			count += 1
	return count


## 최대 스쿼드 크기를 반환합니다.
func get_max_squad_size() -> int:
	var stats = _get_class_stats()
	var size = stats.squad_size

	if equipment_id == "command_module":
		size += 2

	return size


func _on_member_died(member: CrewMember) -> void:
	member_died.emit(member)
	EventBus.crew_member_died.emit(self, member)

	var stats = _get_class_stats()
	current_hp = get_alive_count() * stats.hp
	health_changed.emit(current_hp, max_hp)

	if get_alive_count() == 0:
		_on_squad_wiped()


func _on_squad_wiped() -> void:
	squad_wiped.emit()
	EventBus.squad_wiped.emit(self)
	_die()


# ===== DAMAGE CALCULATION =====

func _calculate_actual_damage(amount: int, damage_type: int, source: Node) -> int:
	var damage = amount

	# Guardian 실드 (교전 중이 아닐 때 에너지 90% 감소)
	if class_id == "guardian" and not is_in_combat:
		if damage_type == Constants.DamageType.ENERGY:
			damage = int(damage * 0.1)

	# Reinforced Armor 특성 (25% 감소)
	if trait_id == "reinforced_armor":
		damage = int(damage * 0.75)

	return damage


## 데미지를 받고 멤버에게 분배합니다.
func take_damage(amount: int, damage_type: int, source: Node = null) -> int:
	var actual = super.take_damage(amount, damage_type, source)

	# 랜덤 멤버에게 데미지 분배
	var alive_members: Array[CrewMember] = []
	for member in members:
		if member.is_alive:
			alive_members.append(member)

	if alive_members.size() > 0:
		var target_member = alive_members[randi() % alive_members.size()]
		target_member.take_damage(actual)

	return actual


# ===== STATS =====

func _get_class_stats() -> Dictionary:
	if _base_stats.has(class_id):
		return _base_stats[class_id]
	return _base_stats.get("guardian", {})


## 유효 공격력을 반환합니다.
func get_effective_damage() -> int:
	var stats = _get_class_stats()
	var damage = stats.get("damage", 3)

	damage = int(damage * (1.0 + rank * 0.1))

	if trait_id == "heavy_hitter":
		damage = int(damage * 1.3)

	return damage


## 유효 공격 속도를 반환합니다.
func get_effective_attack_speed() -> float:
	var stats = _get_class_stats()
	var speed = stats.get("attack_speed", 1.0)

	speed *= (1.0 + rank * 0.05)

	if trait_id == "rapid_fire":
		speed *= 1.25

	return speed


## 유효 이동 속도를 반환합니다.
func get_effective_move_speed() -> float:
	var stats = _get_class_stats()
	var speed = stats.get("move_speed", 1.5)

	if trait_id == "swift":
		speed *= 1.2

	return speed * _slow_multiplier


## 유효 스킬 쿨다운을 반환합니다.
func get_effective_cooldown() -> float:
	var stats = _get_class_stats()
	var cooldown = stats.get("cooldown", 20.0)

	cooldown *= (1.0 - rank * 0.05)

	if trait_id == "tactician":
		cooldown *= 0.8

	return cooldown


## 유효 공격 범위를 반환합니다.
func get_effective_attack_range() -> float:
	var stats = _get_class_stats()
	return stats.get("attack_range", 1.0)


# ===== SELECTION =====

## 선택 상태를 설정합니다.
func set_selected(selected: bool) -> void:
	if selection_indicator:
		selection_indicator.visible = selected


## 클래스 색상을 반환합니다.
func get_class_color() -> Color:
	var stats = _get_class_stats()
	return stats.get("color", Color.WHITE)
