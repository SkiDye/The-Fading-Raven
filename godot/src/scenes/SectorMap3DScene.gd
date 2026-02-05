class_name SectorMap3DScene
extends Node3D

## 3D 섹터 맵 씬 컨트롤러
## Bad North 스타일 3D 캠페인 맵

# ===== SIGNALS =====

signal node_selected(node_id: String)
signal node_entered(node_id: String)
signal upgrade_requested(team_leader: Node)


# ===== CONSTANTS =====

const NODE_COLORS: Dictionary = {
	Constants.NodeType.START: Color(0.3, 0.7, 1.0),
	Constants.NodeType.BATTLE: Color(0.9, 0.4, 0.4),
	Constants.NodeType.COMMANDER: Color(0.4, 0.9, 0.4),
	Constants.NodeType.RESCUE: Color(0.4, 0.9, 0.4),
	Constants.NodeType.EQUIPMENT: Color(1.0, 0.8, 0.3),
	Constants.NodeType.SALVAGE: Color(1.0, 0.8, 0.3),
	Constants.NodeType.DEPOT: Color(0.6, 0.8, 1.0),
	Constants.NodeType.STORM: Color(0.8, 0.3, 0.8),
	Constants.NodeType.BOSS: Color(1.0, 0.2, 0.2),
	Constants.NodeType.REST: Color(0.3, 0.9, 0.6),
	Constants.NodeType.GATE: Color(0.3, 1.0, 1.0),
	Constants.NodeType.BEACON: Color(0.9, 0.9, 0.3)
}

const LAYER_SPACING: float = 8.0  # 레이어 간 Z 간격
const NODE_SPACING: float = 5.0   # 노드 간 X 간격


# ===== CONFIGURATION =====

@export var camera_speed: float = 10.0
@export var camera_zoom_speed: float = 2.0
@export var storm_color: Color = Color(0.6, 0.1, 0.8, 0.6)


# ===== CHILD NODES =====

@onready var camera: Camera3D = $Camera3D
@onready var nodes_container: Node3D = $NodesContainer
@onready var connections_container: Node3D = $ConnectionsContainer
@onready var storm_wall: Node3D = $StormWall
@onready var environment: WorldEnvironment = $WorldEnvironment

# UI References
@onready var back_btn: Button = $UI/SectorMapHUD/TopBar/BackBtn
@onready var pause_btn: Button = $UI/SectorMapHUD/TopBar/PauseBtn
@onready var depth_label: Label = $UI/SectorMapHUD/TopBar/DepthLabel
@onready var credits_label: Label = $UI/SectorMapHUD/TopBar/CreditsLabel
@onready var team_slots: HBoxContainer = $UI/SectorMapHUD/BottomPanel/HBox/MarginLeft/TeamSlots
@onready var upgrade_btn: Button = $UI/SectorMapHUD/BottomPanel/HBox/ActionPanel/UpgradeBtn
@onready var next_turn_btn: Button = $UI/SectorMapHUD/BottomPanel/HBox/ActionPanel/NextTurnBtn
@onready var node_info_panel: PanelContainer = $UI/SectorMapHUD/NodeInfoPanel
@onready var node_title: Label = $UI/SectorMapHUD/NodeInfoPanel/VBox/MarginTop/NodeTitle
@onready var node_desc: RichTextLabel = $UI/SectorMapHUD/NodeInfoPanel/VBox/NodeDesc
@onready var reward_value: Label = $UI/SectorMapHUD/NodeInfoPanel/VBox/RewardPreview/RewardValue
@onready var enter_btn: Button = $UI/SectorMapHUD/NodeInfoPanel/VBox/MarginBottom/EnterBtn


# ===== STATE =====

var _sector_data: Dictionary = {}
var _node_objects: Dictionary = {}  # node_id -> Node3D
var _current_node_id: String = ""
var _selected_node_id: String = ""
var _storm_depth: int = 0

var _camera_target: Vector3 = Vector3.ZERO
var _camera_zoom: float = 20.0
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_connect_signals()
	_initialize_sector()
	_update_ui()


func _process(delta: float) -> void:
	_process_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	_handle_camera_input(event)
	_handle_node_selection(event)


# ===== SETUP =====

func _setup_environment() -> void:
	if environment == null:
		environment = WorldEnvironment.new()
		environment.name = "WorldEnvironment"
		add_child(environment)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.3)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.3
	environment.environment = env


func _setup_camera() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _camera_zoom
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.position = Vector3(0, 30, 20)
	camera.far = 200.0


func _connect_signals() -> void:
	if EventBus:
		EventBus.storm_front_advanced.connect(_on_storm_advanced)

	# UI 버튼 연결
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if next_turn_btn:
		next_turn_btn.pressed.connect(_on_next_turn_pressed)
	if enter_btn:
		enter_btn.pressed.connect(_on_enter_pressed)

	# 노드 진입 시 씬 전환
	node_entered.connect(_on_node_entered_transition)


func _initialize_sector() -> void:
	# GameState에서 섹터 데이터 로드 또는 생성
	if GameState and GameState.has_method("get_sector_data"):
		var data: Dictionary = GameState.get_sector_data()
		if not data.is_empty():
			setup(data)
			if GameState.has_method("get_current_node_id"):
				set_current_node(GameState.get_current_node_id())
			return

	# 섹터 데이터가 없으면 테스트용 생성
	_generate_test_sector()


func _generate_test_sector() -> void:
	# 테스트용 섹터 생성
	var nodes: Array = []
	var node_id := 0

	# 레이어별 노드 생성
	for layer in range(6):
		var nodes_in_layer: int
		var node_types: Array

		match layer:
			0:  # 시작
				nodes_in_layer = 1
				node_types = [Constants.NodeType.START]
			1, 2, 3:  # 중간
				nodes_in_layer = 2 + (layer % 2)
				node_types = [Constants.NodeType.BATTLE, Constants.NodeType.RESCUE, Constants.NodeType.REST]
			4:  # 보스 전
				nodes_in_layer = 2
				node_types = [Constants.NodeType.BATTLE, Constants.NodeType.DEPOT]
			5:  # 보스
				nodes_in_layer = 1
				node_types = [Constants.NodeType.GATE]

		for i in range(nodes_in_layer):
			var node_type: int = node_types[i % node_types.size()]
			var node_data := {
				"id": "node_%d" % node_id,
				"layer": layer,
				"type": node_type,
				"connections_out": [] as Array
			}
			nodes.append(node_data)
			node_id += 1

	# 연결 생성 (레이어 간)
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var current_layer: int = node.layer

		for j in range(nodes.size()):
			var other: Dictionary = nodes[j]
			if other.layer == current_layer + 1:
				# 다음 레이어의 노드와 연결
				node.connections_out.append(other.id)

	_sector_data = {"nodes": nodes}
	_rebuild_map()

	# 시작 노드로 설정
	if not nodes.is_empty():
		_current_node_id = nodes[0].id
		_camera_target = Vector3.ZERO


func _on_node_entered_transition(node_id: String) -> void:
	# 노드 타입에 따라 다른 씬으로 전환
	var node_data := _get_node_data(node_id)
	if node_data.is_empty():
		return

	var node_type: int = node_data.get("type", Constants.NodeType.BATTLE)

	# GameState에 현재 노드 저장
	if GameState and GameState.has_method("set_current_node_id"):
		GameState.set_current_node_id(node_id)

	match node_type:
		Constants.NodeType.START:
			# 시작 노드 - 아무것도 안함
			_current_node_id = node_id
			_update_node_visuals()

		Constants.NodeType.BATTLE, Constants.NodeType.STORM, Constants.NodeType.BOSS:
			# 전투 노드 -> StationPreview3D
			if GameState and GameState.has_method("set_current_station"):
				var station_data := {"node_id": node_id, "node_type": node_type}
				GameState.set_current_station(station_data)

			var preview_scene := "res://scenes/campaign/StationPreview3D.tscn"
			if ResourceLoader.exists(preview_scene):
				get_tree().change_scene_to_file(preview_scene)

		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			# 구조 노드 - 직접 결과 처리
			_handle_rescue_node(node_id)

		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE, Constants.NodeType.DEPOT:
			# 장비 노드 - 직접 결과 처리
			_handle_equipment_node(node_id)

		Constants.NodeType.REST:
			# 휴식 노드 - 회복 처리
			_handle_rest_node(node_id)

		Constants.NodeType.GATE:
			# 탈출 게이트 - 승리
			_handle_victory()


func _handle_rescue_node(node_id: String) -> void:
	_current_node_id = node_id

	# 새 팀장 추가 (50% 확률)
	if randf() > 0.5:
		var dialog := AcceptDialog.new()
		dialog.title = "Survivor Rescued!"
		dialog.dialog_text = "A new team leader has joined your crew!"
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func():
			dialog.queue_free()
			# TODO: 실제 팀장 추가 로직
		)
	else:
		var dialog := AcceptDialog.new()
		dialog.title = "Empty Station"
		dialog.dialog_text = "No survivors found. You received 2 credits."
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func():
			dialog.queue_free()
			if GameState and GameState.has_method("add_credits"):
				GameState.add_credits(2)
		)

	_update_node_visuals()
	_update_ui()


func _handle_equipment_node(node_id: String) -> void:
	_current_node_id = node_id

	var dialog := AcceptDialog.new()
	dialog.title = "Salvage Found!"
	dialog.dialog_text = "You found useful equipment!\n(TODO: Equipment selection)"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

	_update_node_visuals()
	_update_ui()


func _handle_rest_node(node_id: String) -> void:
	_current_node_id = node_id

	# 모든 크루 회복
	if GameState and GameState.has_method("heal_all_crews"):
		GameState.heal_all_crews()

	var dialog := AcceptDialog.new()
	dialog.title = "Rest Stop"
	dialog.dialog_text = "Your crew has fully recovered."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

	_update_node_visuals()
	_update_ui()


func _handle_victory() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "VICTORY!"
	dialog.dialog_text = "You have reached the escape gate!\nYour crew survives to fight another day."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if GameState:
			GameState.end_run(true)
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)


# ===== PUBLIC API =====

## 섹터 맵 데이터 설정
func setup(data: Dictionary) -> void:
	_sector_data = data
	_rebuild_map()


## 현재 노드 설정
func set_current_node(node_id: String) -> void:
	_current_node_id = node_id
	_update_node_visuals()

	# 현재 노드로 카메라 이동
	if _node_objects.has(node_id):
		var node_obj: Node3D = _node_objects[node_id]
		_camera_target = node_obj.global_position


## 스톰 깊이 설정
func set_storm_depth(depth: int) -> void:
	_storm_depth = depth
	_update_storm_wall()
	_update_node_visuals()


## 노드 선택
func select_node(node_id: String) -> void:
	_selected_node_id = node_id
	_update_node_visuals()
	_show_node_info(node_id)
	node_selected.emit(node_id)


## 노드 진입 시도
func try_enter_node(node_id: String) -> bool:
	if not _can_enter_node(node_id):
		return false

	node_entered.emit(node_id)
	return true


# ===== MAP BUILDING =====

func _rebuild_map() -> void:
	_clear_map()
	_build_nodes()
	_build_connections()
	_update_storm_wall()
	_update_node_visuals()


func _clear_map() -> void:
	# 노드 제거
	if nodes_container:
		for child in nodes_container.get_children():
			child.queue_free()
	_node_objects.clear()

	# 연결선 제거
	if connections_container:
		for child in connections_container.get_children():
			child.queue_free()


func _build_nodes() -> void:
	if not _sector_data.has("nodes"):
		return

	if nodes_container == null:
		nodes_container = Node3D.new()
		nodes_container.name = "NodesContainer"
		add_child(nodes_container)

	var nodes: Array = _sector_data.nodes

	# 레이어별 노드 수 계산
	var layer_counts: Dictionary = {}
	var max_layer: int = 0
	for node in nodes:
		var layer: int = node.get("layer", 0)
		layer_counts[layer] = layer_counts.get(layer, 0) + 1
		max_layer = maxi(max_layer, layer)

	# 노드 생성
	var layer_indices: Dictionary = {}

	for node in nodes:
		var node_id: String = node.get("id", "")
		var layer: int = node.get("layer", 0)
		var node_type: int = node.get("type", Constants.NodeType.BATTLE)

		var idx: int = layer_indices.get(layer, 0)
		layer_indices[layer] = idx + 1

		var count_in_layer: int = layer_counts.get(layer, 1)

		# 위치 계산
		var x: float = (idx - (count_in_layer - 1) * 0.5) * NODE_SPACING
		var z: float = layer * LAYER_SPACING

		var node_obj := _create_node_object(node_id, node_type)
		node_obj.position = Vector3(x, 0, z)
		nodes_container.add_child(node_obj)
		_node_objects[node_id] = node_obj


func _create_node_object(node_id: String, node_type: int) -> Node3D:
	var node_obj := Node3D.new()
	node_obj.name = "Node_" + node_id
	node_obj.set_meta("node_id", node_id)
	node_obj.set_meta("node_type", node_type)

	# 베이스 메시 (육각형 또는 박스)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	var mesh: Mesh
	match node_type:
		Constants.NodeType.GATE:
			# 게이트 - 토러스
			var torus := TorusMesh.new()
			torus.inner_radius = 0.3
			torus.outer_radius = 0.8
			mesh = torus
		Constants.NodeType.STORM:
			# 폭풍 - 구
			var sphere := SphereMesh.new()
			sphere.radius = 0.6
			sphere.height = 1.2
			mesh = sphere
		Constants.NodeType.BOSS:
			# 보스 - 큰 박스
			var box := BoxMesh.new()
			box.size = Vector3(1.2, 0.8, 1.2)
			mesh = box
		_:
			# 기본 - 실린더
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 0.4
			mesh = cylinder

	# 재질 설정
	var material := StandardMaterial3D.new()
	var color: Color = NODE_COLORS.get(node_type, Color.WHITE)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.3
	material.metallic = 0.3
	material.roughness = 0.6
	mesh.material = material

	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.3
	node_obj.add_child(mesh_instance)

	# 라벨
	var label := Label3D.new()
	label.name = "Label"
	label.text = _get_node_label(node_type)
	label.font_size = 48
	label.position.y = 1.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color.WHITE
	node_obj.add_child(label)

	# 선택 영역 (Area3D)
	var area := Area3D.new()
	area.name = "ClickArea"
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_node_input_event.bind(node_id))
	node_obj.add_child(area)

	return node_obj


func _get_node_label(node_type: int) -> String:
	match node_type:
		Constants.NodeType.START: return "START"
		Constants.NodeType.BATTLE: return "BATTLE"
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE: return "RESCUE"
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE: return "SALVAGE"
		Constants.NodeType.DEPOT: return "DEPOT"
		Constants.NodeType.STORM: return "STORM"
		Constants.NodeType.BOSS: return "BOSS"
		Constants.NodeType.REST: return "REST"
		Constants.NodeType.GATE: return "GATE"
		Constants.NodeType.BEACON: return "BEACON"
		_: return "???"


func _build_connections() -> void:
	if not _sector_data.has("nodes"):
		return

	if connections_container == null:
		connections_container = Node3D.new()
		connections_container.name = "ConnectionsContainer"
		add_child(connections_container)

	var nodes: Array = _sector_data.nodes

	for node in nodes:
		var node_id: String = node.get("id", "")
		var connections: Array = node.get("connections_out", [])

		if not _node_objects.has(node_id):
			continue

		var from_pos: Vector3 = _node_objects[node_id].position

		for conn_id in connections:
			if not _node_objects.has(conn_id):
				continue

			var to_pos: Vector3 = _node_objects[conn_id].position
			var line := _create_connection_line(from_pos, to_pos)
			connections_container.add_child(line)


func _create_connection_line(from_pos: Vector3, to_pos: Vector3) -> Node3D:
	var line := Node3D.new()

	# 튜브 메시로 연결선 생성
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()

	var direction := to_pos - from_pos
	var length := direction.length()

	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = length

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.5, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylinder.material = material

	mesh_instance.mesh = cylinder

	# 위치 설정
	line.position = (from_pos + to_pos) * 0.5
	line.position.y = 0.1

	# 방향 회전 (look_at 대신 직접 계산)
	if direction.length() > 0.01:
		var forward := direction.normalized()
		# 실린더는 Y축 방향이므로 forward를 Y축에 맞춤
		var angle := Vector3.UP.angle_to(forward)
		var axis := Vector3.UP.cross(forward).normalized()
		if axis.length() > 0.001:
			line.transform.basis = Basis(axis, angle)

	line.add_child(mesh_instance)

	return line


# ===== STORM WALL =====

func _update_storm_wall() -> void:
	if storm_wall == null:
		storm_wall = Node3D.new()
		storm_wall.name = "StormWall"
		add_child(storm_wall)
		_create_storm_wall_mesh()

	# 스톰 위치 업데이트
	storm_wall.position.z = _storm_depth * LAYER_SPACING - LAYER_SPACING * 0.5


func _create_storm_wall_mesh() -> void:
	# 스톰 벽 메시
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(50, 10, 2)

	var material := StandardMaterial3D.new()
	material.albedo_color = storm_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.5, 0.1, 0.6)
	material.emission_energy_multiplier = 1.0
	box.material = material

	mesh_instance.mesh = box
	mesh_instance.position.y = 5
	storm_wall.add_child(mesh_instance)


# ===== NODE VISUALS =====

func _update_node_visuals() -> void:
	# 접근 가능한 노드 ID 목록
	var accessible_ids: Array = []
	var current_data := _get_node_data(_current_node_id)
	if not current_data.is_empty():
		accessible_ids = current_data.get("connections_out", [])

	for node_id in _node_objects:
		var node_obj: Node3D = _node_objects[node_id]
		var mesh: MeshInstance3D = node_obj.get_node_or_null("Mesh")
		if mesh == null:
			continue

		var node_data := _get_node_data(node_id)
		var node_type: int = node_data.get("type", Constants.NodeType.BATTLE)
		var node_layer: int = node_data.get("layer", 0)
		var base_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

		var material: StandardMaterial3D
		if mesh.mesh and mesh.mesh.material:
			material = mesh.mesh.material.duplicate()
		else:
			material = StandardMaterial3D.new()

		# 스톰에 삼켜진 노드
		if node_layer <= _storm_depth:
			material.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
			material.emission_enabled = false
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# 현재 노드
		elif node_id == _current_node_id:
			material.albedo_color = Color.GOLD
			material.emission = Color.GOLD
			material.emission_energy_multiplier = 0.8
		# 선택된 노드
		elif node_id == _selected_node_id:
			material.albedo_color = Color.WHITE
			material.emission = Color.WHITE
			material.emission_energy_multiplier = 0.6
		# 접근 가능한 노드
		elif node_id in accessible_ids:
			material.albedo_color = base_color
			material.emission = base_color
			material.emission_energy_multiplier = 0.3
		# 접근 불가 노드
		else:
			material.albedo_color = base_color.darkened(0.6)
			material.emission_enabled = false

		mesh.material_override = material


# ===== CAMERA =====

func _process_camera(delta: float) -> void:
	if camera == null:
		return

	# 부드러운 이동
	var target_pos := Vector3(_camera_target.x, 30, _camera_target.z + 20)
	camera.position = camera.position.lerp(target_pos, 5.0 * delta)

	# 부드러운 줌
	camera.size = lerpf(camera.size, _camera_zoom, 5.0 * delta)


func _handle_camera_input(event: InputEvent) -> void:
	# 마우스 휠 줌
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_zoom = clampf(_camera_zoom - camera_zoom_speed, 10.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_zoom = clampf(_camera_zoom + camera_zoom_speed, 10.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position

	# 마우스 드래그 이동
	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _drag_start
		_drag_start = event.position
		_camera_target.x -= delta.x * 0.05 * _camera_zoom / 20.0
		_camera_target.z -= delta.y * 0.05 * _camera_zoom / 20.0

	# 키보드 이동
	if event is InputEventKey and event.pressed:
		var move := Vector3.ZERO
		match event.keycode:
			KEY_W, KEY_UP:
				move.z = -1
			KEY_S, KEY_DOWN:
				move.z = 1
			KEY_A, KEY_LEFT:
				move.x = -1
			KEY_D, KEY_RIGHT:
				move.x = 1

		if move != Vector3.ZERO:
			_camera_target += move * camera_speed * 0.1


# ===== INPUT =====

func _handle_node_selection(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_raycast_node_selection(event.position)

	# U 키 - 업그레이드 화면
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		_on_upgrade_pressed()


func _raycast_node_selection(screen_pos: Vector2) -> void:
	if camera == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	# Y=0 평면과 교차
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		var hit_pos := from + dir * t

		# 가장 가까운 노드 찾기
		var closest_id: String = ""
		var closest_dist: float = 2.0  # 선택 반경

		for node_id in _node_objects:
			var node_obj: Node3D = _node_objects[node_id]
			var dist := hit_pos.distance_to(node_obj.position)
			if dist < closest_dist:
				closest_dist = dist
				closest_id = node_id

		if closest_id != "":
			_on_node_clicked(closest_id)


func _on_node_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, node_id: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_node_clicked(node_id)


var _last_click_time: int = 0
var _last_click_node: String = ""
const DOUBLE_CLICK_TIME: int = 400

func _on_node_clicked(node_id: String) -> void:
	var current_time: int = Time.get_ticks_msec()

	# 더블클릭 체크
	if node_id == _last_click_node and (current_time - _last_click_time) < DOUBLE_CLICK_TIME:
		# 더블클릭 - 진입 시도
		if _can_enter_node(node_id):
			node_entered.emit(node_id)
			if EventBus:
				EventBus.sector_node_entered.emit(node_id)
		_last_click_node = ""
		return

	_last_click_time = current_time
	_last_click_node = node_id

	# 단일 클릭 - 선택
	select_node(node_id)


# ===== HELPERS =====

func _get_node_data(node_id: String) -> Dictionary:
	if not _sector_data.has("nodes"):
		return {}

	for node in _sector_data.nodes:
		if node.get("id", "") == node_id:
			return node

	return {}


func _can_enter_node(node_id: String) -> bool:
	# 현재 노드와 같으면 불가
	if node_id == _current_node_id:
		return false

	# 현재 노드에서 연결된 노드인지 확인
	var current_data := _get_node_data(_current_node_id)
	if current_data.is_empty():
		return true

	var connections: Array = current_data.get("connections_out", [])
	if not (node_id in connections):
		return false

	# 스톰에 삼켜진 노드인지 확인
	var node_data := _get_node_data(node_id)
	if not node_data.is_empty():
		var layer: int = node_data.get("layer", 0)
		if layer <= _storm_depth:
			return false

	return true


func _on_storm_advanced(new_depth: int) -> void:
	set_storm_depth(new_depth)


# ===== UI HANDLERS =====

func _on_back_pressed() -> void:
	# 메뉴로 돌아가기 확인
	var confirm := ConfirmationDialog.new()
	confirm.title = "Return to Menu?"
	confirm.dialog_text = "Your progress will be saved."
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		confirm.queue_free()
		if GameState:
			GameState.save_game()
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)
	confirm.canceled.connect(func(): confirm.queue_free())


func _on_pause_pressed() -> void:
	# 일시정지 메뉴 (간단 구현)
	get_tree().paused = not get_tree().paused


func _on_upgrade_pressed() -> void:
	# 업그레이드 화면으로 전환
	var upgrade_scene := "res://src/ui/campaign/UpgradeScreen.tscn"
	if ResourceLoader.exists(upgrade_scene):
		get_tree().change_scene_to_file(upgrade_scene)
	else:
		push_warning("[SectorMap3D] UpgradeScreen.tscn not found")


func _on_next_turn_pressed() -> void:
	# 턴 종료 확인
	var confirm := ConfirmationDialog.new()
	confirm.title = "End Turn?"
	confirm.dialog_text = "The storm front will advance.\nNodes behind the front will be lost!"
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		confirm.queue_free()
		_advance_storm()
	)
	confirm.canceled.connect(func(): confirm.queue_free())


func _on_enter_pressed() -> void:
	if _selected_node_id.is_empty():
		return

	if _can_enter_node(_selected_node_id):
		node_entered.emit(_selected_node_id)
		if EventBus:
			EventBus.sector_node_entered.emit(_selected_node_id)


func _advance_storm() -> void:
	_storm_depth += 1
	_update_storm_wall()
	_update_node_visuals()
	_update_ui()

	if EventBus:
		EventBus.storm_front_advanced.emit(_storm_depth)

	# 현재 노드가 스톰에 삼켜졌는지 확인
	var current_data := _get_node_data(_current_node_id)
	if not current_data.is_empty():
		var layer: int = current_data.get("layer", 0)
		if layer <= _storm_depth:
			_show_storm_game_over()


func _show_storm_game_over() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "CONSUMED BY STORM"
	dialog.dialog_text = "Your crew was caught by the advancing storm.\nYour journey ends here."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if GameState:
			GameState.end_run(false)
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)


# ===== UI UPDATE =====

func _update_ui() -> void:
	_update_depth_label()
	_update_credits_label()
	_update_team_slots()


func _update_depth_label() -> void:
	if depth_label == null:
		return

	var current_layer: int = 0
	var current_data := _get_node_data(_current_node_id)
	if not current_data.is_empty():
		current_layer = current_data.get("layer", 0)

	depth_label.text = "Depth: %d / Storm: %d" % [current_layer, _storm_depth]


func _update_credits_label() -> void:
	if credits_label == null:
		return

	var credits: int = 0
	if GameState and GameState.has_method("get_credits"):
		credits = GameState.get_credits()

	credits_label.text = "Credits: %d" % credits


func _update_team_slots() -> void:
	if team_slots == null:
		return

	# 기존 슬롯 제거
	for child in team_slots.get_children():
		child.queue_free()

	# 크루 정보 가져오기
	var crews: Array = []
	if GameState and GameState.has_method("get_crews"):
		crews = GameState.get_crews()

	# 팀 슬롯 생성
	for i in range(crews.size()):
		var crew = crews[i]
		var slot := _create_team_slot(crew, i)
		team_slots.add_child(slot)


func _create_team_slot(crew: Variant, index: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(80, 100)

	var vbox := VBoxContainer.new()
	slot.add_child(vbox)

	# 클래스 아이콘/이름
	var class_id: String = ""
	if crew is Dictionary:
		class_id = crew.get("class_id", "militia")
	elif "class_id" in crew:
		class_id = crew.class_id

	var class_label := Label.new()
	class_label.text = class_id.to_upper().substr(0, 3)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(class_label)

	# 인덱스 표시
	var index_label := Label.new()
	index_label.text = "[%d]" % (index + 1)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.add_theme_font_size_override("font_size", 10)
	index_label.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(index_label)

	# 클릭 시 업그레이드 화면
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			upgrade_requested.emit(crew)
			_on_upgrade_pressed()
	)

	return slot


func _show_node_info(node_id: String) -> void:
	if node_info_panel == null:
		return

	var node_data := _get_node_data(node_id)
	if node_data.is_empty():
		node_info_panel.visible = false
		return

	var node_type: int = node_data.get("type", Constants.NodeType.BATTLE)

	if node_title:
		node_title.text = _get_node_label(node_type)

	if node_desc:
		node_desc.text = _get_node_description(node_type)

	if reward_value:
		reward_value.text = _get_node_reward_text(node_type)

	if enter_btn:
		enter_btn.disabled = not _can_enter_node(node_id)

	node_info_panel.visible = true


func _hide_node_info() -> void:
	if node_info_panel:
		node_info_panel.visible = false


func _get_node_description(node_type: int) -> String:
	match node_type:
		Constants.NodeType.START:
			return "Starting point of your journey."
		Constants.NodeType.BATTLE:
			return "Defend the station from enemy waves."
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			return "Rescue survivors. A new team leader may join your crew."
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			return "Salvage equipment from the wreckage."
		Constants.NodeType.DEPOT:
			return "Supply depot. Free equipment available."
		Constants.NodeType.STORM:
			return "Storm zone. Limited visibility, tougher enemies."
		Constants.NodeType.BOSS:
			return "A powerful pirate commander awaits."
		Constants.NodeType.REST:
			return "Safe haven. Recover your crew's health."
		Constants.NodeType.GATE:
			return "The escape gate. Reach here to survive."
		Constants.NodeType.BEACON:
			return "Activate the beacon for a checkpoint."
		_:
			return ""


func _get_node_reward_text(node_type: int) -> String:
	match node_type:
		Constants.NodeType.BATTLE:
			return "2-4 Credits"
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			return "New Team Leader"
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			return "Equipment"
		Constants.NodeType.DEPOT:
			return "Free Equipment"
		Constants.NodeType.STORM:
			return "4-6 Credits"
		Constants.NodeType.BOSS:
			return "6-10 Credits"
		Constants.NodeType.REST:
			return "Full Recovery"
		Constants.NodeType.GATE:
			return "VICTORY"
		_:
			return ""
