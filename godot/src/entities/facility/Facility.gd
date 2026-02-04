class_name Facility
extends Node2D

## 스테이션 시설 엔티티
## 적에게 공격받으면 파괴될 수 있으며, 방어 시 크레딧 획득


# ===== SIGNALS =====

signal hp_changed(current: int, max_hp: int)
signal destroyed()
signal repair_started(engineer: Node)
signal repair_completed()
signal crew_recovery_started(crew: Node)
signal crew_recovery_completed(crew: Node)


# ===== EXPORTED =====

@export var facility_data: FacilityData

@export_group("State")
@export var tile_position: Vector2i = Vector2i.ZERO
@export var current_hp: int = 100
@export var is_destroyed: bool = false


# ===== PRIVATE =====

var _max_hp: int = 100
var _is_repairing: bool = false
var _repair_progress: float = 0.0
var _repairing_engineer: Node = null
var _recovering_crew: Node = null

const REPAIR_TIME: float = 5.0  # 수리 소요 시간 (초)
const RECOVERY_TIME_PER_UNIT: float = 2.0  # 유닛당 회복 시간


# ===== ONREADY =====

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var repair_timer: Timer = $RepairTimer
@onready var recovery_timer: Timer = $RecoveryTimer
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_facility()
	_connect_signals()


func _setup_facility() -> void:
	if facility_data:
		_max_hp = facility_data.max_hp
		current_hp = _max_hp
		_update_visual()


func _connect_signals() -> void:
	if repair_timer:
		repair_timer.timeout.connect(_on_repair_timer_timeout)
	if recovery_timer:
		recovery_timer.timeout.connect(_on_recovery_timer_timeout)


# ===== PUBLIC API =====

func initialize(data: FacilityData, pos: Vector2i) -> void:
	## 시설 초기화
	facility_data = data
	tile_position = pos
	position = Utils.tile_to_world(pos)

	_max_hp = data.max_hp
	current_hp = _max_hp
	is_destroyed = false

	_update_visual()


func take_damage(amount: int, source: Node = null) -> int:
	## 피해 받기, 실제 피해량 반환
	if is_destroyed:
		return 0

	var defense := 0.0
	if facility_data:
		defense = facility_data.defense

	var actual_damage := int(amount * (1.0 - defense))
	current_hp = maxi(0, current_hp - actual_damage)

	hp_changed.emit(current_hp, _max_hp)
	EventBus.facility_damaged.emit(self, current_hp, _max_hp)

	_update_health_bar()

	if current_hp <= 0:
		_on_destroyed()

	return actual_damage


func heal(amount: int) -> int:
	## 회복, 실제 회복량 반환
	if is_destroyed:
		return 0

	var old_hp := current_hp
	current_hp = mini(_max_hp, current_hp + amount)
	var healed := current_hp - old_hp

	if healed > 0:
		hp_changed.emit(current_hp, _max_hp)
		_update_health_bar()

	return healed


func start_repair(engineer: Node) -> bool:
	## 수리 시작 (엔지니어가 호출)
	if not is_destroyed or _is_repairing:
		return false

	_is_repairing = true
	_repairing_engineer = engineer
	_repair_progress = 0.0

	repair_started.emit(engineer)
	EventBus.facility_repair_started.emit(self, engineer)

	if repair_timer:
		repair_timer.start(REPAIR_TIME)

	return true


func cancel_repair() -> void:
	## 수리 취소
	if not _is_repairing:
		return

	_is_repairing = false
	_repairing_engineer = null
	_repair_progress = 0.0

	if repair_timer:
		repair_timer.stop()


func start_crew_recovery(crew: Node) -> bool:
	## 크루 회복 시작
	if is_destroyed or _recovering_crew != null:
		return false

	# 의료 시설만 회복 가능
	if facility_data and facility_data.facility_type != Constants.FacilityType.MEDICAL:
		return false

	_recovering_crew = crew
	crew_recovery_started.emit(crew)
	EventBus.crew_recovery_started.emit(crew, self)

	# 회복 시간 계산 (손실된 유닛 수 * 시간)
	var recovery_time := RECOVERY_TIME_PER_UNIT * 4  # 기본 4유닛 가정
	if crew.has_method("get_lost_count"):
		recovery_time = RECOVERY_TIME_PER_UNIT * crew.get_lost_count()

	if recovery_timer:
		recovery_timer.start(recovery_time)

	return true


func get_hp_ratio() -> float:
	## HP 비율 (0.0 ~ 1.0)
	if _max_hp <= 0:
		return 0.0
	return float(current_hp) / float(_max_hp)


func get_credits_value() -> int:
	## 방어 성공 시 크레딧
	if is_destroyed:
		return 0
	if facility_data:
		return facility_data.save_credits
	return 50


func get_passive_bonus(stat_name: String) -> float:
	## 패시브 보너스 조회
	if facility_data:
		return facility_data.get_bonus(stat_name)
	return 0.0


# ===== PRIVATE =====

func _on_destroyed() -> void:
	is_destroyed = true
	_is_repairing = false
	_repairing_engineer = null

	destroyed.emit()
	EventBus.facility_destroyed.emit(self)

	_update_visual()


func _on_repair_timer_timeout() -> void:
	if not _is_repairing:
		return

	# 수리 완료 - 50% HP로 복구
	is_destroyed = false
	current_hp = _max_hp / 2
	_is_repairing = false

	var engineer := _repairing_engineer
	_repairing_engineer = null

	repair_completed.emit()
	EventBus.facility_repaired.emit(self)

	hp_changed.emit(current_hp, _max_hp)
	_update_visual()


func _on_recovery_timer_timeout() -> void:
	if _recovering_crew == null:
		return

	var crew := _recovering_crew
	_recovering_crew = null

	crew_recovery_completed.emit(crew)
	EventBus.crew_recovery_completed.emit(crew)


func _update_visual() -> void:
	if sprite and facility_data:
		if is_destroyed and facility_data.destroyed_sprite:
			sprite.texture = facility_data.destroyed_sprite
		elif facility_data.sprite:
			sprite.texture = facility_data.sprite

		sprite.modulate = facility_data.color if not is_destroyed else Color(0.3, 0.3, 0.3)

	_update_health_bar()


func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = _max_hp
		health_bar.value = current_hp
		health_bar.visible = current_hp < _max_hp and not is_destroyed
