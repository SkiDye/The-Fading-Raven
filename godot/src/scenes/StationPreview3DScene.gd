class_name StationPreview3DScene
extends Node3D

## 정거장 미리보기 씬
## 전투 전 3D 지형 확인, 적 정보 표시

# ===== SIGNALS =====

signal continue_pressed()
signal back_pressed()


# ===== CONSTANTS =====

const ROTATION_SPEED: float = 60.0  # degrees per second
const ZOOM_SPEED: float = 2.0
const MIN_ZOOM: float = 8.0
const MAX_ZOOM: float = 25.0


# ===== PRELOADS =====

const StationGeneratorClass = preload("res://src/systems/campaign/StationGenerator.gd")


# ===== CHILD NODES =====

@onready var camera: Camera3D = $Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var station_container: Node3D = $StationContainer
@onready var environment: WorldEnvironment = $WorldEnvironment

# UI References
@onready var station_name_label: Label = $UI/StationInfoPanel/VBox/StationName
@onready var station_type_label: Label = $UI/StationInfoPanel/VBox/StationType
@onready var facility_count_label: Label = $UI/StationInfoPanel/VBox/FacilityCount
@onready var enemy_preview: HBoxContainer = $UI/StationInfoPanel/VBox/EnemyPreview
@onready var reward_label: Label = $UI/StationInfoPanel/VBox/RewardLabel
@onready var continue_btn: Button = $UI/BottomBar/ContinueBtn
@onready var back_btn: Button = $UI/BottomBar/BackBtn
@onready var instructions_label: Label = $UI/Instructions


# ===== STATE =====

var _station_data: Variant = null  # StationLayout
var _node_data: Dictionary = {}    # Sector node data
var _rotation_angle: float = 0.0
var _zoom_level: float = 15.0
var _is_rotating_left: bool = false
var _is_rotating_right: bool = false
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# Tile meshes for preview
var _tile_meshes: Dictionary = {}
var _facility_markers: Array = []
var _entry_markers: Array = []


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_connect_signals()


func _process(delta: float) -> void:
	_process_rotation(delta)
	_process_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	_handle_input(event)


# ===== SETUP =====

func _setup_environment() -> void:
	if environment == null:
		environment = WorldEnvironment.new()
		environment.name = "WorldEnvironment"
		add_child(environment)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.35, 0.4)
	env.ambient_light_energy = 0.6
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	environment.environment = env


func _setup_camera() -> void:
	if camera_pivot == null:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		add_child(camera_pivot)

	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera_pivot.add_child(camera)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom_level
	camera.rotation_degrees = Vector3(-35.264, 0, 0)
	camera.position = Vector3(0, 0, 20)
	camera.far = 100.0


func _connect_signals() -> void:
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)


# ===== PUBLIC API =====

## 스테이션 데이터 설정
func setup_station(station_layout: Variant, node_data: Dictionary = {}) -> void:
	_station_data = station_layout
	_node_data = node_data

	_clear_preview()
	_build_preview()
	_update_ui()
	_center_camera()


## 시드로 스테이션 생성 후 미리보기
func generate_and_preview(seed: int, difficulty_score: float, node_data: Dictionary = {}) -> void:
	var generator := StationGeneratorClass.new()
	var station_layout = generator.generate(seed, difficulty_score)
	setup_station(station_layout, node_data)


# ===== PREVIEW BUILDING =====

func _clear_preview() -> void:
	if station_container == null:
		station_container = Node3D.new()
		station_container.name = "StationContainer"
		add_child(station_container)

	for child in station_container.get_children():
		child.queue_free()

	_tile_meshes.clear()
	_facility_markers.clear()
	_entry_markers.clear()


func _build_preview() -> void:
	if _station_data == null:
		return

	var width: int = _station_data.width
	var height: int = _station_data.height

	# 중심점 계산
	var center := Vector3(width * 0.5, 0, height * 0.5)

	# 타일 생성
	for y in range(height):
		for x in range(width):
			var tile_pos := Vector2i(x, y)
			var tile_type: int = _station_data.get_tile(tile_pos)
			var elevation: int = _station_data.get_elevation(tile_pos) if _station_data.has_method("get_elevation") else 0

			if tile_type != Constants.TileType.VOID:
				var mesh := _create_tile_mesh(tile_pos, tile_type, elevation)
				mesh.position = Vector3(x + 0.5, elevation * 0.5, y + 0.5) - center
				station_container.add_child(mesh)
				_tile_meshes[tile_pos] = mesh

	# 시설 마커 생성
	for facility in _station_data.facilities:
		var marker := _create_facility_marker(facility)
		marker.position = Vector3(facility.position.x + 0.5, 1.5, facility.position.y + 0.5) - center
		station_container.add_child(marker)
		_facility_markers.append(marker)

	# 진입점 마커 생성
	for entry_point in _station_data.entry_points:
		var marker := _create_entry_marker(entry_point)
		marker.position = Vector3(entry_point.x + 0.5, 0.5, entry_point.y + 0.5) - center
		station_container.add_child(marker)
		_entry_markers.append(marker)


func _create_tile_mesh(tile_pos: Vector2i, tile_type: int, elevation: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Tile_%d_%d" % [tile_pos.x, tile_pos.y]

	var mesh: Mesh
	var material := StandardMaterial3D.new()

	match tile_type:
		Constants.TileType.FLOOR:
			mesh = _create_floor_mesh()
			material.albedo_color = Color(0.35, 0.4, 0.5)
		Constants.TileType.WALL:
			mesh = _create_wall_mesh()
			material.albedo_color = Color(0.5, 0.55, 0.6)
		Constants.TileType.AIRLOCK:
			mesh = _create_floor_mesh()
			material.albedo_color = Color(0.6, 0.3, 0.3)
			material.emission_enabled = true
			material.emission = Color(0.4, 0.1, 0.1)
			material.emission_energy_multiplier = 0.3
		Constants.TileType.ELEVATED:
			mesh = _create_elevated_mesh()
			material.albedo_color = Color(0.45, 0.5, 0.55)
		Constants.TileType.LOWERED:
			mesh = _create_floor_mesh()
			material.albedo_color = Color(0.25, 0.3, 0.35)
		Constants.TileType.FACILITY:
			mesh = _create_floor_mesh()
			material.albedo_color = Color(0.3, 0.5, 0.7)
		Constants.TileType.COVER_HALF, Constants.TileType.COVER_FULL:
			mesh = _create_cover_mesh(tile_type == Constants.TileType.COVER_FULL)
			material.albedo_color = Color(0.5, 0.45, 0.4)
		_:
			mesh = _create_floor_mesh()
			material.albedo_color = Color(0.3, 0.3, 0.3)

	material.roughness = 0.8

	mesh_instance.mesh = mesh
	mesh_instance.material_override = material

	return mesh_instance


func _create_floor_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.95, 0.95)
	return plane


func _create_wall_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 2.0, 0.95)
	return box


func _create_elevated_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 1.0, 0.95)
	return box


func _create_cover_mesh(is_full: bool) -> Mesh:
	var box := BoxMesh.new()
	var height: float = 0.8 if is_full else 0.4
	box.size = Vector3(0.4, height, 0.4)
	return box


func _create_facility_marker(facility: Variant) -> Node3D:
	var marker := Node3D.new()
	marker.name = "Facility_" + facility.facility_id

	# 건물 메시
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.0, 0.8)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.4, 0.6)
	material.emission_energy_multiplier = 0.5
	box.material = material

	mesh.mesh = box
	marker.add_child(mesh)

	# 라벨
	var label := Label3D.new()
	label.text = "F"
	label.font_size = 32
	label.position.y = 0.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.3, 0.8, 1.0)
	marker.add_child(label)

	return marker


func _create_entry_marker(entry_point: Vector2i) -> Node3D:
	var marker := Node3D.new()
	marker.name = "Entry_%d_%d" % [entry_point.x, entry_point.y]

	# 화살표 또는 경고 표시
	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.3, 0.5)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.3, 0.2)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.2, 0.1)
	material.emission_energy_multiplier = 0.8
	prism.material = material

	mesh.mesh = prism
	mesh.rotation_degrees.x = 180  # 아래 방향
	marker.add_child(mesh)

	# 라벨
	var label := Label3D.new()
	label.text = "!"
	label.font_size = 48
	label.position.y = 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.4, 0.3)
	marker.add_child(label)

	return marker


# ===== CAMERA CONTROL =====

func _center_camera() -> void:
	if camera_pivot:
		camera_pivot.position = Vector3.ZERO
		_rotation_angle = 45.0
		camera_pivot.rotation_degrees.y = _rotation_angle


func _process_rotation(delta: float) -> void:
	if _is_rotating_left:
		_rotation_angle -= ROTATION_SPEED * delta
	if _is_rotating_right:
		_rotation_angle += ROTATION_SPEED * delta

	if camera_pivot:
		camera_pivot.rotation_degrees.y = _rotation_angle


func _process_camera(delta: float) -> void:
	if camera:
		camera.size = lerpf(camera.size, _zoom_level, 5.0 * delta)


func _handle_input(event: InputEvent) -> void:
	# 키보드 회전
	if event is InputEventKey:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_is_rotating_left = event.pressed
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_is_rotating_right = event.pressed
		elif event.keycode == KEY_R and event.pressed:
			_zoom_level = clampf(_zoom_level - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.keycode == KEY_F and event.pressed:
			_zoom_level = clampf(_zoom_level + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)

	# 마우스 줌
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_level = clampf(_zoom_level - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_level = clampf(_zoom_level + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position

	# 마우스 드래그 회전
	if event is InputEventMouseMotion and _is_dragging:
		var delta_x: float = event.position.x - _drag_start.x
		_drag_start = event.position
		_rotation_angle += delta_x * 0.5


# ===== UI UPDATE =====

func _update_ui() -> void:
	if _station_data == null:
		return

	# 스테이션 이름
	if station_name_label:
		var station_name: String = "Station %d" % _station_data.seed
		if _node_data.has("id"):
			station_name = _node_data.id.to_upper()
		station_name_label.text = station_name

	# 스테이션 타입
	if station_type_label:
		var type_text: String = "Battle"
		if _node_data.has("type"):
			type_text = _get_type_name(_node_data.type)
		station_type_label.text = type_text

	# 시설 수
	if facility_count_label:
		facility_count_label.text = "Facilities: %d" % _station_data.facilities.size()

	# 보상
	if reward_label:
		var reward_text: String = "2-4 Credits"
		if _node_data.has("type"):
			reward_text = _get_reward_text(_node_data.type)
		reward_label.text = "Rewards: %s" % reward_text

	# 적 미리보기 (TODO: 실제 적 데이터 연동)
	_update_enemy_preview()


func _update_enemy_preview() -> void:
	if enemy_preview == null:
		return

	# 기존 제거
	for child in enemy_preview.get_children():
		if child.name != "Label":
			child.queue_free()

	# 테스트용 적 아이콘
	var enemy_types := ["Rusher", "Gunner", "Shield"]
	for enemy_type in enemy_types:
		var label := Label.new()
		label.text = enemy_type.substr(0, 1)
		label.add_theme_font_size_override("font_size", 16)
		label.modulate = Color(0.9, 0.4, 0.4)
		enemy_preview.add_child(label)


func _get_type_name(node_type: int) -> String:
	match node_type:
		Constants.NodeType.BATTLE: return "Battle"
		Constants.NodeType.STORM: return "Storm Zone"
		Constants.NodeType.BOSS: return "Boss Battle"
		Constants.NodeType.RESCUE: return "Rescue Mission"
		_: return "Unknown"


func _get_reward_text(node_type: int) -> String:
	match node_type:
		Constants.NodeType.BATTLE: return "2-4 Credits"
		Constants.NodeType.STORM: return "4-6 Credits"
		Constants.NodeType.BOSS: return "6-10 Credits"
		Constants.NodeType.RESCUE: return "New Team Leader"
		_: return "Unknown"


# ===== UI HANDLERS =====

func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_back_pressed() -> void:
	back_pressed.emit()
