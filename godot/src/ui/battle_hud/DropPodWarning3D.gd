class_name DropPodWarning3D
extends Node3D

## 드롭팟 착륙 경고 UI
## 착륙 지점에 경고 링과 ETA 표시


# ===== SIGNALS =====

signal warning_finished()


# ===== CONFIGURATION =====

@export var ring_color: Color = Color(1.0, 0.3, 0.1, 0.7)
@export var pulse_speed: float = 2.0
@export var max_ring_scale: float = 1.5


# ===== STATE =====

var target_tile: Vector2i = Vector2i.ZERO
var eta: float = 3.0
var _time_remaining: float = 0.0
var _is_active: bool = false


# ===== CHILD NODES =====

var _outer_ring: MeshInstance3D
var _inner_ring: MeshInstance3D
var _eta_label: Label3D
var _danger_icon: Node3D


# ===== LIFECYCLE =====

func _ready() -> void:
	_create_warning_visuals()


func _process(delta: float) -> void:
	if not _is_active:
		return

	_time_remaining -= delta

	# ETA 업데이트
	if _eta_label:
		_eta_label.text = "%.1f" % maxf(_time_remaining, 0)

	# 펄스 애니메이션
	_update_pulse(delta)

	# 완료 체크
	if _time_remaining <= 0:
		_finish_warning()


# ===== INITIALIZATION =====

func initialize(tile: Vector2i, _world_pos: Vector3, countdown: float) -> void:
	target_tile = tile
	eta = countdown
	_time_remaining = countdown
	_is_active = true

	if _eta_label:
		_eta_label.text = "%.1f" % eta


# ===== VISUAL CREATION =====

func _create_warning_visuals() -> void:
	# 외부 링
	_outer_ring = MeshInstance3D.new()
	_outer_ring.name = "OuterRing"

	var outer_torus := TorusMesh.new()
	outer_torus.inner_radius = 0.7
	outer_torus.outer_radius = 0.9

	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = ring_color
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(ring_color.r, ring_color.g, ring_color.b)
	outer_mat.emission_energy_multiplier = 1.5
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_torus.material = outer_mat

	_outer_ring.mesh = outer_torus
	_outer_ring.rotation_degrees.x = 90
	_outer_ring.position.y = 0.05
	add_child(_outer_ring)

	# 내부 링
	_inner_ring = MeshInstance3D.new()
	_inner_ring.name = "InnerRing"

	var inner_torus := TorusMesh.new()
	inner_torus.inner_radius = 0.35
	inner_torus.outer_radius = 0.5

	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(1.0, 0.5, 0.1)
	inner_mat.emission_energy_multiplier = 2.0
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_torus.material = inner_mat

	_inner_ring.mesh = inner_torus
	_inner_ring.rotation_degrees.x = 90
	_inner_ring.position.y = 0.03
	add_child(_inner_ring)

	# 위험 표시 (X 마크)
	_danger_icon = _create_danger_icon()
	_danger_icon.position.y = 0.1
	add_child(_danger_icon)

	# ETA 라벨
	_eta_label = Label3D.new()
	_eta_label.name = "ETALabel"
	_eta_label.text = "0.0"
	_eta_label.font_size = 32
	_eta_label.modulate = Color.WHITE
	_eta_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_eta_label.no_depth_test = true
	_eta_label.position = Vector3(0, 1.5, 0)
	_eta_label.outline_modulate = Color.BLACK
	_eta_label.outline_size = 4
	add_child(_eta_label)

	# 경고 텍스트
	var warning_label := Label3D.new()
	warning_label.name = "WarningLabel"
	warning_label.text = "INCOMING!"
	warning_label.font_size = 24
	warning_label.modulate = Color(1.0, 0.4, 0.2)
	warning_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning_label.no_depth_test = true
	warning_label.position = Vector3(0, 1.9, 0)
	warning_label.outline_modulate = Color.BLACK
	warning_label.outline_size = 3
	add_child(warning_label)


func _create_danger_icon() -> Node3D:
	var icon := Node3D.new()
	icon.name = "DangerIcon"

	# X 마크 (두 개의 박스)
	var bar1 := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.8, 0.1, 0.1)

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
	bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bar_mat.emission_enabled = true
	bar_mat.emission = Color(1.0, 0.2, 0.1)
	bar_mat.emission_energy_multiplier = 2.0
	bar_mesh.material = bar_mat

	bar1.mesh = bar_mesh
	bar1.rotation_degrees.y = 45
	icon.add_child(bar1)

	var bar2 := MeshInstance3D.new()
	bar2.mesh = bar_mesh
	bar2.rotation_degrees.y = -45
	icon.add_child(bar2)

	return icon


# ===== ANIMATION =====

func _update_pulse(delta: float) -> void:
	var pulse := sin(Time.get_ticks_msec() * 0.001 * pulse_speed * TAU) * 0.5 + 0.5

	# 외부 링 펄스
	if _outer_ring:
		var scale_val := 1.0 + pulse * (max_ring_scale - 1.0)
		_outer_ring.scale = Vector3(scale_val, scale_val, 1.0)

		var mat: StandardMaterial3D = _outer_ring.mesh.material
		if mat:
			mat.albedo_color.a = 0.4 + pulse * 0.4

	# 내부 링 역펄스
	if _inner_ring:
		var inner_scale := 1.0 + (1.0 - pulse) * 0.3
		_inner_ring.scale = Vector3(inner_scale, inner_scale, 1.0)

	# 위험 아이콘 회전
	if _danger_icon:
		_danger_icon.rotation_degrees.y += delta * 90


func _finish_warning() -> void:
	_is_active = false
	warning_finished.emit()

	# 페이드아웃 후 제거 (3D 노드는 modulate 없음 - 스케일로 대체)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)
