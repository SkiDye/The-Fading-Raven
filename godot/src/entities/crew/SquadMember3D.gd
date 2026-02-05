class_name SquadMember3D
extends Node3D

## 분대 개별 멤버 3D
## 분대 내 개별 크루원 시각적 표현


# ===== SIGNALS =====

signal died()
signal revived()


# ===== CONFIGURATION =====

@export var member_index: int = 0
@export var is_leader: bool = false


# ===== STATE =====

var class_id: String = "militia"
var is_alive: bool = true
var target_position: Vector3 = Vector3.ZERO
var _current_velocity: Vector3 = Vector3.ZERO

const MOVE_SPEED: float = 5.0
const POSITION_THRESHOLD: float = 0.05


# ===== CHILD NODES =====

var _model_container: Node3D
var _mesh: MeshInstance3D


# ===== CLASS COLORS =====

const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.5, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.9, 0.7, 0.2),
	"bionic": Color(0.7, 0.3, 0.9),
	"militia": Color(0.5, 0.5, 0.5)
}


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_model_container()


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 목표 위치로 부드럽게 이동
	_update_position(delta)


# ===== INITIALIZATION =====

func initialize(p_class_id: String, index: int, leader: bool = false) -> void:
	class_id = p_class_id
	member_index = index
	is_leader = leader
	is_alive = true

	_create_member_mesh()


func _setup_model_container() -> void:
	_model_container = Node3D.new()
	_model_container.name = "ModelContainer"
	add_child(_model_container)


func _create_member_mesh() -> void:
	if _model_container == null:
		_setup_model_container()

	# 기존 메시 제거
	for child in _model_container.get_children():
		child.queue_free()

	var color: Color = CLASS_COLORS.get(class_id, Color.GRAY)

	# 리더는 약간 더 크고 밝게
	var size_mult := 1.15 if is_leader else 1.0
	if is_leader:
		color = color.lightened(0.15)

	match class_id:
		"guardian":
			_create_guardian_mesh(color, size_mult)
		"sentinel":
			_create_sentinel_mesh(color, size_mult)
		"ranger":
			_create_ranger_mesh(color, size_mult)
		"engineer":
			_create_engineer_mesh(color, size_mult)
		"bionic":
			_create_bionic_mesh(color, size_mult)
		_:
			_create_militia_mesh(color, size_mult)


# ===== POSITION MANAGEMENT =====

func set_target_position(pos: Vector3) -> void:
	target_position = pos


func set_immediate_position(pos: Vector3) -> void:
	target_position = pos
	position = pos


func _update_position(delta: float) -> void:
	var diff := target_position - position
	if diff.length() < POSITION_THRESHOLD:
		position = target_position
		return

	# 부드러운 이동
	var move_dir := diff.normalized()
	var move_dist := minf(diff.length(), MOVE_SPEED * delta)
	position += move_dir * move_dist


# ===== DEATH/REVIVE =====

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	died.emit()

	# 사망 애니메이션
	_play_death_animation()


func revive() -> void:
	if is_alive:
		return

	is_alive = true
	revived.emit()

	# 부활 애니메이션
	_play_revive_animation()


func _play_death_animation() -> void:
	var tween := create_tween()

	# 쓰러지는 효과
	tween.tween_property(self, "rotation_degrees:x", 90.0, 0.3)
	tween.parallel().tween_property(self, "position:y", -0.1, 0.3)

	# 페이드아웃
	if _mesh and _mesh.material_override:
		var mat: StandardMaterial3D = _mesh.material_override
		tween.tween_property(mat, "albedo_color:a", 0.3, 0.5)


func _play_revive_animation() -> void:
	var tween := create_tween()

	# 일어나는 효과
	tween.tween_property(self, "rotation_degrees:x", 0.0, 0.3)
	tween.parallel().tween_property(self, "position:y", 0.0, 0.3)

	# 페이드인
	if _mesh and _mesh.material_override:
		var mat: StandardMaterial3D = _mesh.material_override
		tween.tween_property(mat, "albedo_color:a", 1.0, 0.3)


# ===== ANIMATION STATES =====

func play_idle() -> void:
	# 약간의 idle 움직임 (선택적)
	pass


func play_walk() -> void:
	# 걷기 애니메이션 효과 (선택적 - 간단한 바운스)
	pass


func play_attack() -> void:
	# 공격 애니메이션
	var tween := create_tween()
	tween.tween_property(self, "position:z", position.z - 0.15, 0.1)
	tween.tween_property(self, "position:z", position.z, 0.1)


# ===== MESH CREATION =====

func _create_guardian_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (넓은 박스)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.18, 0.25, 0.1) * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.13 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 실드
	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.2, 0.22, 0.03) * scale / 0.35
	shield.mesh = shield_mesh
	shield.position = Vector3(0, 0.12 * size_mult, -0.08 * size_mult)
	shield.material_override = _create_material(color.lightened(0.3))
	_model_container.add_child(shield)

	# 머리
	_add_head(color, Vector3(0, 0.28 * size_mult, 0), size_mult)


func _create_sentinel_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (가는 캡슐)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06 * scale / 0.35
	body_mesh.height = 0.22 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.11 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 창
	var lance := MeshInstance3D.new()
	var lance_mesh := CylinderMesh.new()
	lance_mesh.top_radius = 0.008 * scale / 0.35
	lance_mesh.bottom_radius = 0.015 * scale / 0.35
	lance_mesh.height = 0.4 * scale / 0.35
	lance.mesh = lance_mesh
	lance.position = Vector3(0.06 * size_mult, 0.15 * size_mult, -0.1 * size_mult)
	lance.rotation_degrees = Vector3(-30, 0, 15)
	lance.material_override = _create_material(Color(0.7, 0.7, 0.8))
	_model_container.add_child(lance)

	_add_head(color, Vector3(0, 0.26 * size_mult, 0), size_mult)


func _create_ranger_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.065 * scale / 0.35
	body_mesh.height = 0.2 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.1 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 총
	var rifle := MeshInstance3D.new()
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.025, 0.025, 0.15) * scale / 0.35
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(0.06 * size_mult, 0.12 * size_mult, -0.05 * size_mult)
	rifle.material_override = _create_material(Color(0.3, 0.3, 0.35))
	_model_container.add_child(rifle)

	_add_head(color, Vector3(0, 0.24 * size_mult, 0), size_mult)


func _create_engineer_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (박스)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.13, 0.18, 0.11) * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.09 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 백팩
	var backpack := MeshInstance3D.new()
	var bp_mesh := BoxMesh.new()
	bp_mesh.size = Vector3(0.1, 0.12, 0.06) * scale / 0.35
	backpack.mesh = bp_mesh
	backpack.position = Vector3(0, 0.1 * size_mult, 0.08 * size_mult)
	backpack.material_override = _create_material(color.darkened(0.3))
	_model_container.add_child(backpack)

	_add_head(color, Vector3(0, 0.22 * size_mult, 0), size_mult, true)


func _create_bionic_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (가는 캡슐)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.05 * scale / 0.35
	body_mesh.height = 0.22 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.11 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 블레이드 팔
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.012, 0.012, 0.12) * scale / 0.35

	var blade_l := MeshInstance3D.new()
	blade_l.mesh = blade_mesh
	blade_l.position = Vector3(-0.08 * size_mult, 0.11 * size_mult, -0.05 * size_mult)
	blade_l.rotation_degrees = Vector3(-20, 15, 0)
	blade_l.material_override = _create_material(Color(0.9, 0.2, 0.9))
	_model_container.add_child(blade_l)

	var blade_r := MeshInstance3D.new()
	blade_r.mesh = blade_mesh
	blade_r.position = Vector3(0.08 * size_mult, 0.11 * size_mult, -0.05 * size_mult)
	blade_r.rotation_degrees = Vector3(-20, -15, 0)
	blade_r.material_override = _create_material(Color(0.9, 0.2, 0.9))
	_model_container.add_child(blade_r)

	_add_head(color.lightened(0.2), Vector3(0, 0.26 * size_mult, 0), size_mult)


func _create_militia_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 기본 캡슐
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06 * scale / 0.35
	body_mesh.height = 0.18 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.09 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	_add_head(color, Vector3(0, 0.22 * size_mult, 0), size_mult)


func _add_head(color: Color, pos: Vector3, size_mult: float, helmet: bool = false) -> void:
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	var base_radius := 0.04 if not helmet else 0.045
	head_mesh.radius = base_radius * size_mult
	head_mesh.height = base_radius * 2 * size_mult
	head.mesh = head_mesh
	head.position = pos

	if helmet:
		head.material_override = _create_material(color.darkened(0.2))
	else:
		head.material_override = _create_material(Color(0.9, 0.75, 0.6))

	_model_container.add_child(head)


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
