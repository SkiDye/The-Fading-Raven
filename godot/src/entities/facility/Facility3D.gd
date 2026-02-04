class_name Facility3D
extends Node3D

## 3D 시설 (방어 대상)
## 방어 성공 시 크레딧 획득, 크루 재보급 가능

# ===== SIGNALS =====

signal health_changed(current: int, max_hp: int)
signal destroyed()
signal resupply_started(crew: Node)
signal resupply_finished(crew: Node)


# ===== CONFIGURATION =====

@export var facility_id: String = "residential"
@export var facility_type: Constants.FacilityType = Constants.FacilityType.HOUSING
@export var max_hp: int = 100
@export var credit_value: int = 2
@export var resupply_time: float = 5.0


# ===== STATE =====

var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 100
var is_alive: bool = true
var is_occupied: bool = false
var occupant: Node = null

var _resupply_timer: float = 0.0
var _is_resupplying: bool = false


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var health_bar: Node3D = $HealthBar3D
@onready var effect_container: Node3D = $EffectContainer


# ===== LIFECYCLE =====

func _ready() -> void:
	current_hp = max_hp
	add_to_group("facilities")
	_load_model()


func _process(delta: float) -> void:
	if not is_alive:
		return

	if _is_resupplying and occupant:
		_process_resupply(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("facility_id"):
		facility_id = data.facility_id
	if data.has("facility_type"):
		facility_type = data.facility_type
	if data.has("max_hp"):
		max_hp = data.max_hp
	if data.has("credit_value"):
		credit_value = data.credit_value
	if data.has("tile_position"):
		tile_position = data.tile_position

	current_hp = max_hp
	_load_model()


func _load_model() -> void:
	var model_path := "res://assets/models/facilities/%s.glb" % facility_id

	if not ResourceLoader.exists(model_path):
		model_path = "res://assets/models/facilities/residential_sml.glb"

	if ResourceLoader.exists(model_path) and model_container:
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			for child in model_container.get_children():
				child.queue_free()

			var model := model_scene.instantiate()
			model_container.add_child(model)


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	if not is_alive:
		return

	current_hp -= amount
	current_hp = maxi(current_hp, 0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()

	# 데미지 이펙트
	_spawn_damage_effect()

	if current_hp <= 0:
		_destroy()


func _destroy() -> void:
	is_alive = false
	destroyed.emit()

	# 재보급 중인 크루 처리
	if occupant and occupant.has_method("on_facility_destroyed"):
		occupant.on_facility_destroyed()

	EventBus.facility_destroyed.emit(self)

	# 파괴 이펙트
	_spawn_destroy_effect()

	# 모델 변경 (파괴된 상태)
	if model_container:
		for child in model_container.get_children():
			if child is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.2, 0.2, 0.2)
				child.material_override = mat


func _update_health_bar() -> void:
	if health_bar == null:
		return

	var fill := health_bar.get_node_or_null("Fill")
	if fill:
		fill.scale.x = float(current_hp) / float(max_hp)

	# 체력에 따라 색상 변경
	var health_percent := float(current_hp) / float(max_hp)
	var fill_mesh := fill as MeshInstance3D
	if fill_mesh:
		var mat := StandardMaterial3D.new()
		if health_percent > 0.5:
			mat.albedo_color = Color(0.2, 0.8, 0.2)
		elif health_percent > 0.25:
			mat.albedo_color = Color(0.8, 0.8, 0.2)
		else:
			mat.albedo_color = Color(0.8, 0.2, 0.2)
		fill_mesh.material_override = mat


# ===== RESUPPLY =====

func start_resupply(crew: Node) -> bool:
	if not is_alive:
		return false

	if is_occupied:
		return false

	is_occupied = true
	occupant = crew
	_is_resupplying = true
	_resupply_timer = 0.0

	resupply_started.emit(crew)

	return true


func _process_resupply(delta: float) -> void:
	_resupply_timer += delta

	if _resupply_timer >= resupply_time:
		_finish_resupply()


func _finish_resupply() -> void:
	_is_resupplying = false

	if occupant and occupant.has_method("finish_resupply"):
		occupant.finish_resupply()

	resupply_finished.emit(occupant)

	occupant = null
	is_occupied = false


func cancel_resupply() -> void:
	_is_resupplying = false
	is_occupied = false
	occupant = null


# ===== EFFECTS =====

func _spawn_damage_effect() -> void:
	if effect_container == null:
		return

	# TODO: 데미지 파티클 생성


func _spawn_destroy_effect() -> void:
	if effect_container == null:
		return

	# TODO: 폭발 파티클 생성


# ===== FACILITY BONUS =====

func get_bonus_type() -> Constants.FacilityType:
	return facility_type


func get_bonus_value() -> float:
	match facility_type:
		Constants.FacilityType.MEDICAL:
			return 0.25  # 재보급 속도 25% 증가
		Constants.FacilityType.ARMORY:
			return 0.15  # 공격력 15% 증가
		Constants.FacilityType.COMM_TOWER:
			return 0.2   # 시야 20% 증가
		Constants.FacilityType.POWER_PLANT:
			return 0.1   # Raven 쿨다운 10% 감소
		_:
			return 0.0


# ===== UTILITIES =====

func get_credit_value() -> int:
	return credit_value if is_alive else 0
