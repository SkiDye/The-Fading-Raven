class_name EnemyUnit3D
extends Node3D

## 3D 적 유닛
## AI 제어, 시설/크루 공격

# ===== SIGNALS =====

signal health_changed(current: int, max_hp: int)
signal died()
signal target_reached(target: Node)
signal attack_started(target: Node)


# ===== CONFIGURATION =====

@export var enemy_id: String = "rusher"
@export var max_hp: int = 30
@export var move_speed: float = 2.0
@export var attack_damage: int = 8
@export var attack_range: float = 1.2
@export var attack_cooldown: float = 1.5


# ===== STATE =====

var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 30
var is_alive: bool = true
var is_moving: bool = false
var is_attacking: bool = false
var current_target: Node = null
var team: int = 1  # 1 = 적

var _attack_timer: float = 0.0
var _target_position: Vector3 = Vector3.ZERO


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var health_bar: Node3D = $HealthBar3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("units")
	_load_model()


func _process(delta: float) -> void:
	if not is_alive:
		return

	_attack_timer -= delta

	if is_attacking and current_target:
		_process_attack(delta)
	elif is_moving:
		_process_movement(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("enemy_id"):
		enemy_id = data.enemy_id
	if data.has("max_hp"):
		max_hp = data.max_hp
	if data.has("tile_position"):
		tile_position = data.tile_position
	if data.has("move_speed"):
		move_speed = data.move_speed
	if data.has("attack_damage"):
		attack_damage = data.attack_damage

	current_hp = max_hp
	_load_model()


func _load_model() -> void:
	var model_path := "res://assets/models/enemies/%s.glb" % enemy_id

	if not ResourceLoader.exists(model_path):
		model_path = "res://assets/models/enemies/rusher.glb"

	if ResourceLoader.exists(model_path) and model_container:
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			for child in model_container.get_children():
				child.queue_free()

			var model := model_scene.instantiate()
			model_container.add_child(model)


# ===== AI =====

func set_target(target: Node) -> void:
	current_target = target

	if target and is_instance_valid(target):
		if "global_position" in target:
			_target_position = target.global_position
		is_moving = true

		if animation_player and animation_player.has_animation("walk"):
			animation_player.play("walk")


func _process_movement(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		is_moving = false
		return

	# 타겟 위치 갱신
	if "global_position" in current_target:
		_target_position = current_target.global_position

	var direction := (_target_position - global_position)
	direction.y = 0
	var distance := direction.length()

	# 공격 범위 도달
	if distance < attack_range:
		is_moving = false
		start_attack()
		return

	# 이동
	direction = direction.normalized()
	global_position += direction * move_speed * delta

	# 회전
	if direction.length() > 0.01:
		look_at(global_position + direction)


func start_attack() -> void:
	if current_target == null:
		return

	is_attacking = true
	attack_started.emit(current_target)

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")


func _process_attack(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		is_attacking = false
		return

	# 타겟이 죽었는지 확인
	if "is_alive" in current_target and not current_target.is_alive:
		is_attacking = false
		current_target = null
		return

	# 공격 쿨다운
	if _attack_timer <= 0:
		_perform_attack()
		_attack_timer = attack_cooldown


func _perform_attack() -> void:
	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage, self)


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	if not is_alive:
		return

	current_hp -= amount
	current_hp = maxi(current_hp, 0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()

	if current_hp <= 0:
		_die()


func _die() -> void:
	is_alive = false
	is_moving = false
	is_attacking = false
	died.emit()

	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

	EventBus.entity_died.emit(self)

	# 제거
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


func _update_health_bar() -> void:
	if health_bar == null:
		return

	var fill := health_bar.get_node_or_null("Fill")
	if fill:
		fill.scale.x = float(current_hp) / float(max_hp)


# ===== UTILITIES =====

func get_enemy_id() -> String:
	return enemy_id
