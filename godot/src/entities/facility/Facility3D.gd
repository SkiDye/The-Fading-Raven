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
	if model_container == null:
		return

	# 기존 모델 제거
	for child in model_container.get_children():
		child.queue_free()

	var model_path := "res://assets/models/facilities/%s.glb" % facility_id

	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model := model_scene.instantiate()
			model_container.add_child(model)
			return

	# GLB 없으면 프로시저럴 메시 생성
	_create_procedural_model()


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


# ===== PROCEDURAL MODEL =====

const FACILITY_COLORS: Dictionary = {
	Constants.FacilityType.HOUSING: Color(0.5, 0.55, 0.6),
	Constants.FacilityType.MEDICAL: Color(0.3, 0.7, 0.4),
	Constants.FacilityType.ARMORY: Color(0.7, 0.4, 0.3),
	Constants.FacilityType.COMM_TOWER: Color(0.3, 0.5, 0.8),
	Constants.FacilityType.POWER_PLANT: Color(0.8, 0.7, 0.2)
}

func _create_procedural_model() -> void:
	if model_container == null:
		return

	var color: Color = FACILITY_COLORS.get(facility_type, Color(0.5, 0.5, 0.55))

	match facility_type:
		Constants.FacilityType.HOUSING:
			_create_housing_mesh(color)
		Constants.FacilityType.MEDICAL:
			_create_medical_mesh(color)
		Constants.FacilityType.ARMORY:
			_create_armory_mesh(color)
		Constants.FacilityType.COMM_TOWER:
			_create_comm_tower_mesh(color)
		Constants.FacilityType.POWER_PLANT:
			_create_power_plant_mesh(color)
		_:
			_create_housing_mesh(color)


func _create_housing_mesh(color: Color) -> void:
	# Housing: 주거 모듈 - 박스 형태
	var size_mult := 1.0 + credit_value * 0.2  # 크레딧 가치에 따라 크기 조절

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.8 * size_mult, 0.6 * size_mult, 0.8 * size_mult)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.3 * size_mult, 0)
	base.material_override = _create_material(color)
	model_container.add_child(base)

	# 지붕
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(0.9 * size_mult, 0.1, 0.9 * size_mult)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 0.65 * size_mult, 0)
	roof.material_override = _create_material(color.darkened(0.2))
	model_container.add_child(roof)

	# 문
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.2, 0.35, 0.05)
	door.mesh = door_mesh
	door.position = Vector3(0, 0.18, -0.4 * size_mult)
	door.material_override = _create_material(Color(0.3, 0.25, 0.2))
	model_container.add_child(door)


func _create_medical_mesh(color: Color) -> void:
	# Medical: 의료 시설 - 십자가 표시
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.5, 0.9)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.25, 0)
	base.material_override = _create_material(color)
	model_container.add_child(base)

	# 십자가 (수평)
	var cross_h := MeshInstance3D.new()
	var cross_h_mesh := BoxMesh.new()
	cross_h_mesh.size = Vector3(0.5, 0.08, 0.15)
	cross_h.mesh = cross_h_mesh
	cross_h.position = Vector3(0, 0.55, -0.4)
	cross_h.material_override = _create_material(Color(0.9, 0.2, 0.2))
	model_container.add_child(cross_h)

	# 십자가 (수직)
	var cross_v := MeshInstance3D.new()
	var cross_v_mesh := BoxMesh.new()
	cross_v_mesh.size = Vector3(0.15, 0.35, 0.08)
	cross_v.mesh = cross_v_mesh
	cross_v.position = Vector3(0, 0.55, -0.4)
	cross_v.material_override = _create_material(Color(0.9, 0.2, 0.2))
	model_container.add_child(cross_v)


func _create_armory_mesh(color: Color) -> void:
	# Armory: 무기고 - 단단한 형태
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.0, 0.4, 0.8)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.2, 0)
	base.material_override = _create_material(color)
	model_container.add_child(base)

	# 상단 구조물
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.7, 0.3, 0.6)
	top.mesh = top_mesh
	top.position = Vector3(0, 0.55, 0)
	top.material_override = _create_material(color.darkened(0.15))
	model_container.add_child(top)

	# 무기 랙 표시
	var rack := MeshInstance3D.new()
	var rack_mesh := BoxMesh.new()
	rack_mesh.size = Vector3(0.6, 0.25, 0.05)
	rack.mesh = rack_mesh
	rack.position = Vector3(0, 0.35, -0.38)
	rack.material_override = _create_material(Color(0.3, 0.3, 0.35))
	model_container.add_child(rack)


func _create_comm_tower_mesh(color: Color) -> void:
	# Comm Tower: 통신탑 - 높은 안테나
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.6, 0.3, 0.6)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.15, 0)
	base.material_override = _create_material(color)
	model_container.add_child(base)

	# 타워
	var tower := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.06
	tower_mesh.bottom_radius = 0.12
	tower_mesh.height = 1.0
	tower.mesh = tower_mesh
	tower.position = Vector3(0, 0.8, 0)
	tower.material_override = _create_material(Color(0.4, 0.4, 0.45))
	model_container.add_child(tower)

	# 안테나 접시
	var dish := MeshInstance3D.new()
	var dish_mesh := CylinderMesh.new()
	dish_mesh.top_radius = 0.25
	dish_mesh.bottom_radius = 0.15
	dish_mesh.height = 0.08
	dish.mesh = dish_mesh
	dish.position = Vector3(0, 1.1, 0)
	dish.rotation_degrees = Vector3(30, 0, 0)
	dish.material_override = _create_material(Color(0.7, 0.7, 0.75))
	model_container.add_child(dish)


func _create_power_plant_mesh(color: Color) -> void:
	# Power Plant: 발전소 - 원통형 리액터
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.25, 0.9)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.125, 0)
	base.material_override = _create_material(color)
	model_container.add_child(base)

	# 리액터 코어
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.3
	core_mesh.bottom_radius = 0.3
	core_mesh.height = 0.6
	core.mesh = core_mesh
	core.position = Vector3(0, 0.55, 0)
	var core_mat := _create_material(Color(0.9, 0.8, 0.2))
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.9, 0.7, 0.1)
	core_mat.emission_energy_multiplier = 0.5
	core.material_override = core_mat
	model_container.add_child(core)

	# 냉각 파이프
	for i in range(4):
		var pipe := MeshInstance3D.new()
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.05
		pipe_mesh.bottom_radius = 0.05
		pipe_mesh.height = 0.4
		pipe.mesh = pipe_mesh
		pipe.rotation_degrees = Vector3(90, 0, i * 90)
		pipe.position = Vector3(
			cos(deg_to_rad(i * 90)) * 0.35,
			0.55,
			sin(deg_to_rad(i * 90)) * 0.35
		)
		pipe.material_override = _create_material(Color(0.35, 0.35, 0.4))
		model_container.add_child(pipe)


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	return mat
