class_name CrewSquad3D
extends Node3D

## 3D 크루 분대
## 팀장 + 크루원으로 구성된 분대 유닛

# ===== SIGNALS =====

signal health_changed(current: int, max_hp: int)
signal member_died(remaining: int)
signal squad_eliminated()
signal skill_activated(skill_id: String)
signal movement_started(target_pos: Vector3)
signal movement_finished()
signal combat_started(enemy: Node3D)
signal combat_ended()


# ===== CONFIGURATION =====

@export var class_id: String = "guardian"
@export var max_members: int = 8
@export var move_speed: float = 3.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0


# ===== STATE =====

var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 100
var max_hp: int = 100
var members_alive: int = 8
var is_alive: bool = true
var is_selected: bool = false
var is_moving: bool = false
var is_in_combat: bool = false
var current_target: Node3D = null
var team: int = 0  # 0 = 플레이어

# 스킬/장비
var skill_cooldown: float = 0.0
var skill_max_cooldown: float = 20.0
var equipment_id: String = ""

# 이동
var _move_path: Array[Vector3] = []
var _move_index: int = 0


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var selection_indicator: Node3D = $SelectionIndicator
@onready var health_bar: Node3D = $HealthBar3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_health()
	_update_selection_visual()
	add_to_group("crews")
	add_to_group("units")


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 스킬 쿨다운
	if skill_cooldown > 0:
		skill_cooldown -= delta

	# 이동 처리
	if is_moving and not _move_path.is_empty():
		_process_movement(delta)

	# 전투 처리
	if is_in_combat and current_target:
		_process_combat(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("class_id"):
		class_id = data.class_id
	if data.has("max_members"):
		max_members = data.max_members
	if data.has("tile_position"):
		tile_position = data.tile_position
	if data.has("equipment_id"):
		equipment_id = data.equipment_id

	members_alive = max_members
	_setup_health()
	_load_model()


func _setup_health() -> void:
	# 멤버당 HP 계산
	max_hp = members_alive * 12  # 멤버당 12 HP
	current_hp = max_hp


func _load_model() -> void:
	# 클래스별 GLB 모델 로드
	var model_path := "res://assets/models/crews/%s.glb" % class_id

	if not ResourceLoader.exists(model_path):
		model_path = "res://assets/models/crews/guardian.glb"

	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene and model_container:
			# 기존 모델 제거
			for child in model_container.get_children():
				child.queue_free()

			var model := model_scene.instantiate()
			model_container.add_child(model)


# ===== SELECTION =====

func select() -> void:
	is_selected = true
	_update_selection_visual()

	# Tactical Mode 진입 (BattleController에서 처리)
	EventBus.crew_selected.emit(self)


func deselect() -> void:
	is_selected = false
	_update_selection_visual()


func _update_selection_visual() -> void:
	if selection_indicator:
		selection_indicator.visible = is_selected


# ===== MOVEMENT =====

func command_move(target_tile: Vector2i, path: Array = []) -> void:
	if not is_alive or is_in_combat:
		return

	tile_position = target_tile

	# 경로가 있으면 경로 따라 이동
	if not path.is_empty():
		_move_path.clear()
		for tile_pos in path:
			var world_pos := _tile_to_world(tile_pos)
			_move_path.append(world_pos)
		_move_index = 0
		is_moving = true
		movement_started.emit(_move_path[-1])
	else:
		# 직접 이동
		var target_world := _tile_to_world(target_tile)
		_move_path = [target_world]
		_move_index = 0
		is_moving = true
		movement_started.emit(target_world)

	# 이동 애니메이션
	if animation_player and animation_player.has_animation("walk"):
		animation_player.play("walk")


func _process_movement(delta: float) -> void:
	if _move_index >= _move_path.size():
		_finish_movement()
		return

	var target := _move_path[_move_index]
	var direction := (target - global_position).normalized()
	var distance := global_position.distance_to(target)

	if distance < 0.1:
		_move_index += 1
		if _move_index >= _move_path.size():
			_finish_movement()
		return

	# 이동
	global_position += direction * move_speed * delta

	# 방향 회전
	if direction.length() > 0.01:
		var look_target := global_position + Vector3(direction.x, 0, direction.z)
		look_at(look_target)


func _finish_movement() -> void:
	is_moving = false
	_move_path.clear()
	movement_finished.emit()

	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


# ===== COMBAT =====

func command_attack(enemy: Node3D) -> void:
	if not is_alive:
		return

	current_target = enemy
	is_in_combat = true
	combat_started.emit(enemy)

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")


func _process_combat(_delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		end_combat()
		return

	# 타겟이 죽었는지 확인
	if "is_alive" in current_target and not current_target.is_alive:
		end_combat()
		return

	# 공격 범위 확인
	var distance := global_position.distance_to(current_target.global_position)
	if distance > attack_range * 2:
		# 범위 벗어남 - 추적
		var dir := (current_target.global_position - global_position).normalized()
		global_position += dir * move_speed * get_process_delta_time()


func end_combat() -> void:
	is_in_combat = false
	current_target = null
	combat_ended.emit()

	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	if not is_alive:
		return

	current_hp -= amount
	current_hp = maxi(current_hp, 0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()

	# 멤버 사망 체크
	var new_members := ceili(float(current_hp) / 12.0)
	if new_members < members_alive:
		var died := members_alive - new_members
		members_alive = new_members
		member_died.emit(members_alive)

	# 분대 전멸 체크
	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	if not is_alive:
		return

	current_hp += amount
	current_hp = mini(current_hp, max_hp)

	# 멤버 회복
	members_alive = ceili(float(current_hp) / 12.0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()


func _die() -> void:
	is_alive = false
	members_alive = 0
	squad_eliminated.emit()

	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

	EventBus.entity_died.emit(self)

	# 일정 시간 후 제거
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(queue_free)


func _update_health_bar() -> void:
	if health_bar and health_bar.has_method("set_value"):
		health_bar.set_value(float(current_hp) / float(max_hp))


# ===== SKILLS =====

func use_skill(skill_id: String = "") -> bool:
	if not is_alive:
		return false

	if skill_cooldown > 0:
		return false

	skill_cooldown = skill_max_cooldown
	skill_activated.emit(skill_id)

	# 클래스별 스킬 실행
	match class_id:
		"guardian":
			_skill_shield_bash()
		"sentinel":
			_skill_lance_charge()
		"ranger":
			_skill_volley_fire()
		"engineer":
			_skill_deploy_turret()
		"bionic":
			_skill_blink()

	return true


func _skill_shield_bash() -> void:
	# 전방 돌진 + 넉백
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_lance_charge() -> void:
	# 돌격
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_volley_fire() -> void:
	# 일제 사격
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_deploy_turret() -> void:
	# 터렛 배치
	EventBus.turret_deploy_requested.emit(self, tile_position)


func _skill_blink() -> void:
	# 순간이동
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


# ===== RESUPPLY =====

func start_resupply(facility: Node) -> void:
	# 시설에서 재보급 시작
	set_meta("resupply_facility", facility)

	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


func finish_resupply() -> void:
	# 재보급 완료 - 체력 회복
	heal(max_hp - current_hp)
	remove_meta("resupply_facility")


# ===== UTILITIES =====

func _tile_to_world(tile_pos: Vector2i) -> Vector3:
	return Vector3(tile_pos.x + 0.5, 0, tile_pos.y + 0.5)


func get_class_id() -> String:
	return class_id


func get_health_percent() -> float:
	return float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
