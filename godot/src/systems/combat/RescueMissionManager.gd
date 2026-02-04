class_name RescueMissionManager
extends Node

## RESCUE 미션 관리자
## 탈출자 보호 전투를 처리하고, 성공 시 새 팀장 + 크루 보상


# ===== SIGNALS =====

signal rescue_mission_started()
signal rescue_mission_completed(success: bool)
signal survivor_damaged(current_hp: int, max_hp: int)
signal survivor_died()
signal survivor_rescued()


# ===== CONFIGURATION =====

@export var survivor_max_hp: int = 100
@export var survivor_defense: float = 0.0  # 방어력 없음 (보호 필요)


# ===== STATE =====

var is_rescue_mission: bool = false
var survivor_hp: int = 100
var survivor_position: Vector2i = Vector2i.ZERO
var survivor_node: Node = null

var _battle_controller: Node = null
var _reward_data: Dictionary = {}


# ===== LIFECYCLE =====

func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus:
		EventBus.battle_ended.connect(_on_battle_ended)


# ===== PUBLIC API =====

## 초기화
func initialize(battle_controller: Node) -> void:
	_battle_controller = battle_controller


## RESCUE 미션 시작
func start_rescue_mission(station_data: Variant) -> void:
	is_rescue_mission = true
	survivor_hp = survivor_max_hp

	# 탈출자 스폰 위치 결정 (시설 근처)
	survivor_position = _get_survivor_spawn_position(station_data)

	# 탈출자 노드 생성
	_spawn_survivor()

	# 보상 데이터 생성 (팀장 + 크루 4명)
	_reward_data = _generate_rescue_reward()

	rescue_mission_started.emit()
	EventBus.show_toast.emit("구조 임무: 탈출자를 보호하세요!", Constants.ToastType.INFO, 3.0)


## 탈출자에게 피해 적용
func damage_survivor(amount: int, source: Node = null) -> int:
	if not is_rescue_mission or survivor_hp <= 0:
		return 0

	var actual_damage: int = int(amount * (1.0 - survivor_defense))
	survivor_hp = maxi(0, survivor_hp - actual_damage)

	survivor_damaged.emit(survivor_hp, survivor_max_hp)

	if survivor_hp <= 0:
		_on_survivor_died()

	return actual_damage


## 탈출자가 살아있는지 확인
func is_survivor_alive() -> bool:
	return is_rescue_mission and survivor_hp > 0


## 탈출자 위치 반환
func get_survivor_position() -> Vector2i:
	return survivor_position


## 보상 데이터 반환
func get_reward_data() -> Dictionary:
	return _reward_data


# ===== PRIVATE =====

func _get_survivor_spawn_position(station_data: Variant) -> Vector2i:
	## 시설 근처에서 탈출자 스폰 위치 선택
	if _battle_controller == null:
		return Vector2i(5, 5)

	# 시설 위치 중 하나 선택
	if _battle_controller.get("facilities") and not _battle_controller.facilities.is_empty():
		var facility = _battle_controller.facilities[0]
		if facility is Node and "tile_position" in facility:
			return facility.tile_position + Vector2i(1, 0)
		elif facility is Dictionary:
			return facility.get("position", Vector2i(5, 5)) + Vector2i(1, 0)

	return Vector2i(5, 5)


func _spawn_survivor() -> void:
	## 탈출자 엔티티 생성
	# 간단한 Node2D로 생성 (전용 씬이 없는 경우)
	survivor_node = Node2D.new()
	survivor_node.name = "Survivor"
	survivor_node.set_meta("is_survivor", true)
	survivor_node.set("tile_position", survivor_position)
	survivor_node.set("is_alive", true)
	survivor_node.set("current_hp", survivor_hp)
	survivor_node.set("max_hp", survivor_max_hp)

	# 월드 좌표 설정
	survivor_node.global_position = Vector2(
		survivor_position.x * Constants.TILE_SIZE + Constants.TILE_SIZE / 2,
		survivor_position.y * Constants.TILE_SIZE + Constants.TILE_SIZE / 2
	)

	# 그룹 추가 (적이 타겟할 수 있도록)
	survivor_node.add_to_group("survivors")
	survivor_node.add_to_group("allies")

	if _battle_controller:
		_battle_controller.add_child(survivor_node)


func _generate_rescue_reward() -> Dictionary:
	## 구조 보상 생성 (새 팀장 + 크루 4명)
	var available_classes: Array[String] = ["guardian", "sentinel", "ranger", "engineer", "bionic"]

	# 랜덤 클래스 선택
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var class_id: String = available_classes[rng.randi() % available_classes.size()]

	return {
		"type": "new_team_leader",
		"class_id": class_id,
		"crew_count": 4,  # 기본 분대원 수
		"rank": 0,  # Standard 등급
		"skill_level": 0,
		"equipment_id": "",
		"trait_id": ""
	}


func _on_survivor_died() -> void:
	survivor_died.emit()
	EventBus.show_toast.emit("탈출자 사망! 보상 없음", Constants.ToastType.ERROR, 3.0)

	if survivor_node and is_instance_valid(survivor_node):
		survivor_node.set("is_alive", false)


func _on_battle_ended(victory: bool) -> void:
	if not is_rescue_mission:
		return

	if victory and is_survivor_alive():
		# 구조 성공
		survivor_rescued.emit()
		rescue_mission_completed.emit(true)
		_grant_rescue_reward()
	else:
		# 구조 실패 (탈출자 사망 또는 전투 패배)
		rescue_mission_completed.emit(false)

	# 리셋
	_cleanup()


func _grant_rescue_reward() -> void:
	## 보상 지급 (새 팀장 추가)
	if _reward_data.is_empty():
		return

	EventBus.show_toast.emit("구조 성공! 새 팀장이 합류했습니다!", Constants.ToastType.SUCCESS, 4.0)

	# GameState에 새 크루 추가
	if GameState and GameState.has_method("add_crew"):
		var new_crew_data := {
			"id": "rescued_%d" % Time.get_ticks_msec(),
			"class_id": _reward_data.class_id,
			"rank": _reward_data.rank,
			"skill_level": _reward_data.skill_level,
			"equipment_id": _reward_data.equipment_id,
			"trait_id": _reward_data.trait_id,
			"current_hp_ratio": 1.0,
			"is_alive": true
		}
		GameState.add_crew(new_crew_data)


func _cleanup() -> void:
	is_rescue_mission = false
	survivor_hp = 0
	survivor_position = Vector2i.ZERO
	_reward_data = {}

	if survivor_node and is_instance_valid(survivor_node):
		survivor_node.queue_free()
		survivor_node = null
