class_name DropPod3D
extends Node3D

## 3D 침투정 (적 수송선)
## 적을 실어와 정거장에 상륙시킴

# ===== SIGNALS =====

signal approaching(eta: float)
signal landed(tile_pos: Vector2i)
signal enemies_deployed(enemies: Array)
signal departed()


# ===== CONFIGURATION =====

@export var approach_speed: float = 5.0
@export var landing_duration: float = 1.0


# ===== STATE =====

enum State { APPROACHING, LANDING, DEPLOYED, DEPARTING }

var current_state: State = State.APPROACHING
var target_tile: Vector2i = Vector2i.ZERO
var target_position: Vector3 = Vector3.ZERO
var enemy_payload: Array = []  # 탑승한 적 데이터

var _approach_start: Vector3 = Vector3.ZERO
var _landing_timer: float = 0.0


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	add_to_group("drop_pods")
	_load_model()


func _process(delta: float) -> void:
	match current_state:
		State.APPROACHING:
			_process_approach(delta)
		State.LANDING:
			_process_landing(delta)
		State.DEPARTING:
			_process_depart(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("target_tile"):
		target_tile = data.target_tile
		target_position = Vector3(target_tile.x + 0.5, 0, target_tile.y + 0.5)

	if data.has("enemies"):
		enemy_payload = data.enemies

	if data.has("approach_direction"):
		var dir: Vector3 = data.approach_direction
		_approach_start = target_position - dir.normalized() * 20.0
		_approach_start.y = 5.0  # 높이에서 접근
		global_position = _approach_start

	_load_model()


func _load_model() -> void:
	var model_path := "res://assets/models/vehicles/boarding_pod.glb"

	if ResourceLoader.exists(model_path) and model_container:
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			for child in model_container.get_children():
				child.queue_free()

			var model := model_scene.instantiate()
			model_container.add_child(model)


# ===== APPROACH =====

func start_approach() -> void:
	current_state = State.APPROACHING

	# 타겟 방향으로 회전
	look_at(target_position)


func _process_approach(delta: float) -> void:
	var direction := (target_position - global_position).normalized()
	var distance := global_position.distance_to(target_position)

	# ETA 계산
	var eta := distance / approach_speed
	approaching.emit(eta)

	# 착륙 지점 도달
	if distance < 0.5:
		_start_landing()
		return

	# 이동
	global_position += direction * approach_speed * delta


func _start_landing() -> void:
	current_state = State.LANDING
	_landing_timer = 0.0

	# 착륙 애니메이션
	if animation_player and animation_player.has_animation("land"):
		animation_player.play("land")


func _process_landing(delta: float) -> void:
	_landing_timer += delta

	# 착륙 완료
	if _landing_timer >= landing_duration:
		_deploy_enemies()


# ===== DEPLOY =====

func _deploy_enemies() -> void:
	current_state = State.DEPLOYED
	landed.emit(target_tile)

	# 적 생성 요청
	var deployed: Array = []
	for enemy_data in enemy_payload:
		deployed.append(enemy_data)

	enemies_deployed.emit(deployed)

	# 잠시 후 퇴각
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_start_depart)


# ===== DEPART =====

func _start_depart() -> void:
	current_state = State.DEPARTING
	departed.emit()

	if animation_player and animation_player.has_animation("depart"):
		animation_player.play("depart")


func _process_depart(delta: float) -> void:
	# 위로 상승하며 퇴각
	global_position.y += approach_speed * delta

	# 일정 높이 도달 시 제거
	if global_position.y > 15.0:
		queue_free()


# ===== UTILITIES =====

func get_enemy_count() -> int:
	return enemy_payload.size()
