class_name SectorMap3DScene
extends Node3D

## 3D 성계 지도 씬 컨트롤러
## Bad North 스타일 3D 캠페인 맵 - 우주 테마

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
var _camera_zoom: float = 15.0  # Battle3D와 동일
var _camera_rotation: float = 45.0  # 현재 회전 각도
var _target_rotation: float = 45.0  # 목표 회전 각도
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_distance: float = 0.0  # 드래그 거리 추적
const DRAG_THRESHOLD: float = 5.0  # 드래그 판정 임계값
const ISOMETRIC_ANGLE: float = 35.264  # arctan(1/sqrt(2))
const ORBIT_DISTANCE: float = 20.0  # 카메라 공전 거리


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
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.15, 0.12, 0.25)
	env.ambient_light_energy = 0.4

	# 우주 배경 스카이
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.02, 0.01, 0.08)       # 깊은 우주
	sky_material.sky_horizon_color = Color(0.08, 0.04, 0.15)   # 보라빛 성운
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_material.ground_horizon_color = Color(0.05, 0.02, 0.1)
	sky_material.sun_angle_max = 0  # 태양 숨기기
	sky.sky_material = sky_material
	env.sky = sky

	# Glow 효과 (노드 빛남)
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# 톤매핑
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	environment.environment = env

	# 별 필드 생성
	_create_star_field()
	# 성운 파티클 생성
	_create_nebula_clouds()


func _setup_camera() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _camera_zoom
	# Battle3D와 동일한 아이소메트릭 각도
	camera.rotation_degrees = Vector3(-ISOMETRIC_ANGLE, _camera_rotation, 0)
	_update_camera_orbit_position()
	camera.far = 200.0


func _connect_signals() -> void:
	if EventBus:
		EventBus.storm_front_advanced.connect(_on_storm_advanced)

	# UI 버튼 연결
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
		# 일시정지 상태에서도 버튼 작동하도록 설정
		pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if next_turn_btn:
		next_turn_btn.pressed.connect(_on_next_turn_pressed)
	if enter_btn:
		enter_btn.pressed.connect(_on_enter_pressed)

	# 노드 진입 시 씬 전환
	node_entered.connect(_on_node_entered_transition)


func _create_star_field() -> void:
	## 절차적 별 필드 생성
	var star_container := Node3D.new()
	star_container.name = "StarField"
	add_child(star_container)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # 일관된 별 배치

	# 여러 층의 별들
	for i in range(200):
		var star := MeshInstance3D.new()
		var sphere := SphereMesh.new()

		# 별 크기 (먼 별은 작게)
		var size: float = rng.randf_range(0.05, 0.2)
		sphere.radius = size
		sphere.height = size * 2

		# 별 재질 (빛나는 흰색/파란색/노란색)
		var mat := StandardMaterial3D.new()
		var star_colors := [
			Color(1.0, 1.0, 1.0),      # 흰색
			Color(0.8, 0.9, 1.0),      # 청백색
			Color(1.0, 0.95, 0.8),     # 노란빛
			Color(0.9, 0.8, 1.0),      # 보라빛
		]
		mat.albedo_color = star_colors[rng.randi() % star_colors.size()]
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = rng.randf_range(0.5, 2.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material = mat

		star.mesh = sphere
		star.position = Vector3(
			rng.randf_range(-80, 80),
			rng.randf_range(-30, 50),
			rng.randf_range(-50, 100)
		)

		star_container.add_child(star)


func _create_nebula_clouds() -> void:
	## 성운 구름 효과
	var nebula_container := Node3D.new()
	nebula_container.name = "NebulaClouds"
	add_child(nebula_container)

	var rng := RandomNumberGenerator.new()
	rng.seed = 123

	# 여러 개의 반투명 성운 구름
	for i in range(8):
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(15, 40)
		sphere.height = sphere.radius * 2

		var mat := StandardMaterial3D.new()
		var nebula_colors := [
			Color(0.3, 0.1, 0.5, 0.08),   # 보라
			Color(0.1, 0.2, 0.4, 0.06),   # 파랑
			Color(0.4, 0.1, 0.3, 0.05),   # 자주
			Color(0.2, 0.3, 0.5, 0.07),   # 청록
		]
		mat.albedo_color = nebula_colors[rng.randi() % nebula_colors.size()]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		sphere.material = mat

		cloud.mesh = sphere
		cloud.position = Vector3(
			rng.randf_range(-40, 40),
			rng.randf_range(-20, 20),
			rng.randf_range(0, 80)
		)

		nebula_container.add_child(cloud)


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

	# GameState에 저장
	if GameState and GameState.has_method("set_sector_data"):
		GameState.set_sector_data(_sector_data)
		GameState.set_current_node_id(_current_node_id)


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

		# 모든 전투 노드 → 바로 Battle3D로 이동 (미리보기/분대선택 건너뜀)
		Constants.NodeType.BATTLE, Constants.NodeType.STORM, Constants.NodeType.BOSS, \
		Constants.NodeType.RESCUE, Constants.NodeType.COMMANDER, \
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			if GameState and GameState.has_method("set_current_station"):
				var station_data := {
					"node_id": node_id,
					"node_type": node_type,
					"is_rescue": node_type in [Constants.NodeType.RESCUE, Constants.NodeType.COMMANDER],
					"is_equipment": node_type in [Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE]
				}
				GameState.set_current_station(station_data)

			# 모든 가용 분대를 battle_squads에 설정 (분대 선택 건너뜀)
			if GameState and GameState.has_method("get_crews"):
				var all_crews: Array = GameState.get_crews()
				# 최대 4팀까지만 전투 참여
				var battle_crews: Array = all_crews.slice(0, mini(4, all_crews.size()))
				GameState.battle_squads = battle_crews
				print("[SectorMap3D] Auto-assigned %d squads to battle" % battle_crews.size())

			# 바로 Battle3D로 이동
			var battle_scene := "res://scenes/battle/Battle3D.tscn"
			if ResourceLoader.exists(battle_scene):
				get_tree().change_scene_to_file(battle_scene)

		Constants.NodeType.DEPOT:
			# 보급 정거장 - 무료 장비 (전투 없음)
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
		dialog.title = Localization.get_text("dialog.rescue_success_title")
		dialog.dialog_text = Localization.get_text("dialog.rescue_success_desc")
		dialog.exclusive = false
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func():
			dialog.queue_free()
			# TODO: 실제 팀장 추가 로직
		)
	else:
		var dialog := AcceptDialog.new()
		dialog.title = Localization.get_text("dialog.rescue_empty_title")
		dialog.dialog_text = Localization.get_text("dialog.rescue_empty_desc")
		dialog.exclusive = false
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
	dialog.title = Localization.get_text("dialog.salvage_title")
	dialog.dialog_text = Localization.get_text("dialog.salvage_desc")
	dialog.exclusive = false
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
	dialog.title = Localization.get_text("dialog.rest_title")
	dialog.dialog_text = Localization.get_text("dialog.rest_desc")
	dialog.exclusive = false
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

	_update_node_visuals()
	_update_ui()


func _handle_victory() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = Localization.get_text("dialog.victory_title")
	dialog.dialog_text = Localization.get_text("dialog.victory_desc")
	dialog.exclusive = false
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if GameState:
			GameState.end_run(true)
		var tree := get_tree()
		if tree:
			tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
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

	# GameState에 저장
	if GameState and GameState.has_method("set_current_node_id"):
		GameState.set_current_node_id(node_id)


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

	# 스테이션 이름 생성
	var station_name: String = _generate_station_name(node_id, node_type)
	node_obj.set_meta("station_name", station_name)

	# 타입별 미니 스테이션 생성
	var station_mesh := _create_station_mesh(node_type)
	station_mesh.name = "Mesh"
	node_obj.add_child(station_mesh)

	# 스테이션 디테일 추가 (안테나, 라이트 등)
	_add_station_details(node_obj, node_type)

	# 스테이션 이름 라벨
	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = station_name
	name_label.font_size = 28
	name_label.position.y = -0.8
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.modulate = Color(0.7, 0.8, 0.9, 0.9)
	name_label.outline_modulate = Color(0, 0, 0, 0.5)
	name_label.outline_size = 4
	node_obj.add_child(name_label)

	# 타입 아이콘 라벨
	var type_label := Label3D.new()
	type_label.name = "TypeLabel"
	type_label.text = _get_node_icon(node_type)
	type_label.font_size = 64
	type_label.position.y = 1.8
	type_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	type_label.no_depth_test = true
	type_label.modulate = NODE_COLORS.get(node_type, Color.WHITE)
	node_obj.add_child(type_label)

	# 선택 영역 (Area3D)
	var area := Area3D.new()
	area.name = "ClickArea"
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_node_input_event.bind(node_id))
	node_obj.add_child(area)

	return node_obj


func _create_station_mesh(node_type: int) -> Node3D:
	## 노드 타입별 미니 스테이션 메시 생성
	var station := Node3D.new()
	var base_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

	match node_type:
		Constants.NodeType.START:
			# 시작점 - 작은 안전한 정거장
			_add_cylinder_module(station, Vector3.ZERO, 0.4, 0.3, base_color)
			_add_ring(station, Vector3(0, 0.2, 0), 0.5, 0.08, base_color.lightened(0.3))

		Constants.NodeType.BATTLE:
			# 전투 - 무장 정거장 (팔각형 + 포탑)
			_add_box_module(station, Vector3.ZERO, Vector3(0.8, 0.4, 0.8), base_color)
			_add_cylinder_module(station, Vector3(0.3, 0.3, 0.3), 0.15, 0.3, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(-0.3, 0.3, -0.3), 0.15, 0.3, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(0.3, 0.3, -0.3), 0.15, 0.3, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(-0.3, 0.3, 0.3), 0.15, 0.3, base_color.darkened(0.2))

		Constants.NodeType.RESCUE, Constants.NodeType.COMMANDER:
			# 구조 - 신호 발신기 (안테나 + 깜빡이는 불빛)
			_add_cylinder_module(station, Vector3.ZERO, 0.3, 0.5, base_color)
			_add_cylinder_module(station, Vector3(0, 0.5, 0), 0.05, 0.8, Color(0.6, 0.6, 0.7))
			_add_sphere_module(station, Vector3(0, 1.0, 0), 0.12, Color(0.3, 1.0, 0.3))

		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			# 장비/인양 - 화물 컨테이너들
			_add_box_module(station, Vector3(-0.25, 0, 0), Vector3(0.4, 0.35, 0.5), base_color)
			_add_box_module(station, Vector3(0.25, 0, 0), Vector3(0.4, 0.35, 0.5), base_color.darkened(0.15))
			_add_box_module(station, Vector3(0, 0.3, 0), Vector3(0.3, 0.25, 0.4), base_color.lightened(0.1))

		Constants.NodeType.DEPOT:
			# 보급 정거장 - 큰 원형 + 도킹 암
			_add_cylinder_module(station, Vector3.ZERO, 0.5, 0.3, base_color)
			_add_box_module(station, Vector3(0.6, 0, 0), Vector3(0.3, 0.15, 0.1), base_color.darkened(0.2))
			_add_box_module(station, Vector3(-0.6, 0, 0), Vector3(0.3, 0.15, 0.1), base_color.darkened(0.2))
			_add_box_module(station, Vector3(0, 0, 0.6), Vector3(0.1, 0.15, 0.3), base_color.darkened(0.2))

		Constants.NodeType.STORM:
			# 폭풍 지역 - 손상된 스테이션
			_add_box_module(station, Vector3.ZERO, Vector3(0.6, 0.4, 0.6), base_color)
			_add_box_module(station, Vector3(0.2, 0.2, 0.15), Vector3(0.25, 0.15, 0.2), base_color.darkened(0.3))
			# 손상 표시 (기울어진 파편)
			var debris := _add_box_module(station, Vector3(-0.3, 0.1, 0.2), Vector3(0.2, 0.1, 0.15), Color(0.3, 0.3, 0.35))
			debris.rotation_degrees = Vector3(15, 0, -20)

		Constants.NodeType.BOSS:
			# 보스 - 거대한 요새 스테이션
			_add_box_module(station, Vector3.ZERO, Vector3(1.0, 0.5, 1.0), base_color)
			_add_cylinder_module(station, Vector3(0, 0.4, 0), 0.4, 0.4, base_color.darkened(0.1))
			_add_cylinder_module(station, Vector3(0.4, 0.3, 0.4), 0.2, 0.5, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(-0.4, 0.3, -0.4), 0.2, 0.5, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(0.4, 0.3, -0.4), 0.2, 0.5, base_color.darkened(0.2))
			_add_cylinder_module(station, Vector3(-0.4, 0.3, 0.4), 0.2, 0.5, base_color.darkened(0.2))
			_add_ring(station, Vector3(0, 0.2, 0), 0.7, 0.1, Color(0.8, 0.2, 0.2))

		Constants.NodeType.REST:
			# 휴식 - 안전한 정박지 (돔 형태)
			_add_sphere_module(station, Vector3(0, 0.2, 0), 0.5, base_color)
			_add_ring(station, Vector3(0, 0, 0), 0.6, 0.08, base_color.lightened(0.2))
			_add_cylinder_module(station, Vector3(0, -0.3, 0), 0.3, 0.15, base_color.darkened(0.2))

		Constants.NodeType.GATE:
			# 탈출 게이트 - 워프 포털 (토러스 + 에너지)
			_add_torus(station, Vector3.ZERO, 0.6, 0.15, base_color)
			_add_torus(station, Vector3.ZERO, 0.45, 0.08, Color(0.5, 1.0, 1.0))
			# 내부 에너지 디스크
			var energy_disk := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = 0.4
			disk.bottom_radius = 0.4
			disk.height = 0.02
			var energy_mat := StandardMaterial3D.new()
			energy_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.5)
			energy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			energy_mat.emission_enabled = true
			energy_mat.emission = Color(0.3, 0.8, 1.0)
			energy_mat.emission_energy_multiplier = 2.0
			disk.material = energy_mat
			energy_disk.mesh = disk
			station.add_child(energy_disk)

		Constants.NodeType.BEACON:
			# 비콘 - 신호 타워
			_add_cylinder_module(station, Vector3.ZERO, 0.2, 0.8, base_color)
			_add_sphere_module(station, Vector3(0, 0.5, 0), 0.15, Color(1.0, 0.9, 0.3))

		_:
			# 기본 - 단순 실린더
			_add_cylinder_module(station, Vector3.ZERO, 0.4, 0.4, base_color)

	return station


func _add_cylinder_module(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.4
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.2
	cylinder.material = mat

	mesh_inst.mesh = cylinder
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	return mesh_inst


func _add_box_module(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.4
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.2
	box.material = mat

	mesh_inst.mesh = box
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	return mesh_inst


func _add_sphere_module(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0
	sphere.material = mat

	mesh_inst.mesh = sphere
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	return mesh_inst


func _add_ring(parent: Node3D, pos: Vector3, outer_radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = outer_radius - thickness
	torus.outer_radius = outer_radius

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	torus.material = mat

	mesh_inst.mesh = torus
	mesh_inst.position = pos
	mesh_inst.rotation_degrees.x = 90
	parent.add_child(mesh_inst)
	return mesh_inst


func _add_torus(parent: Node3D, pos: Vector3, outer_radius: float, inner_radius: float, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = outer_radius - inner_radius
	torus.outer_radius = outer_radius

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	torus.material = mat

	mesh_inst.mesh = torus
	mesh_inst.position = pos
	mesh_inst.rotation_degrees.x = 90
	parent.add_child(mesh_inst)
	return mesh_inst


func _add_station_details(node_obj: Node3D, node_type: int) -> void:
	## 스테이션에 디테일 추가 (라이트, 안테나 등)
	var base_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

	# 상단 라이트
	var light := OmniLight3D.new()
	light.name = "StationLight"
	light.light_color = base_color.lightened(0.5)
	light.light_energy = 0.5
	light.omni_range = 3.0
	light.position.y = 0.5
	node_obj.add_child(light)

	# 일부 타입에 추가 디테일
	match node_type:
		Constants.NodeType.RESCUE, Constants.NodeType.COMMANDER:
			# 깜빡이는 비콘 라이트
			var beacon_light := OmniLight3D.new()
			beacon_light.name = "BeaconLight"
			beacon_light.light_color = Color(0.3, 1.0, 0.3)
			beacon_light.light_energy = 1.5
			beacon_light.omni_range = 5.0
			beacon_light.position.y = 1.0
			node_obj.add_child(beacon_light)
			# TODO: 애니메이션 추가

		Constants.NodeType.GATE:
			# 게이트 에너지 라이트
			var gate_light := OmniLight3D.new()
			gate_light.name = "GateLight"
			gate_light.light_color = Color(0.3, 0.8, 1.0)
			gate_light.light_energy = 2.0
			gate_light.omni_range = 6.0
			gate_light.position.y = 0
			node_obj.add_child(gate_light)


func _get_node_icon(node_type: int) -> String:
	## 노드 타입별 아이콘 (이모지)
	match node_type:
		Constants.NodeType.START: return "🏠"
		Constants.NodeType.BATTLE: return "⚔"
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE: return "🆘"
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE: return "📦"
		Constants.NodeType.DEPOT: return "⛽"
		Constants.NodeType.STORM: return "⚡"
		Constants.NodeType.BOSS: return "💀"
		Constants.NodeType.REST: return "🛏"
		Constants.NodeType.GATE: return "🚀"
		Constants.NodeType.BEACON: return "📡"
		_: return "?"


func _generate_station_name(node_id: String, node_type: int) -> String:
	## 절차적 정거장 이름 생성
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node_id)

	var prefix_keys := ["outpost", "station", "relay", "haven", "point", "base", "platform"]
	var greek := ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Theta", "Omega"]
	var names := ["Kepler", "Nova", "Orion", "Vega", "Sirius", "Altair", "Rigel", "Polaris", "Deneb", "Arcturus"]

	var name_type: int = rng.randi() % 4

	match node_type:
		Constants.NodeType.START:
			return Localization.get_text("station_prefix.homebase") + " Alpha"
		Constants.NodeType.GATE:
			return Localization.get_text("station_prefix.warp_gate") + " " + greek[rng.randi() % greek.size()]
		Constants.NodeType.BOSS:
			return Localization.get_text("station_prefix.fortress") + " " + names[rng.randi() % names.size()]
		Constants.NodeType.REST:
			return Localization.get_text("station_prefix.haven") + " " + greek[rng.randi() % greek.size()]
		_:
			var prefix_key: String = prefix_keys[rng.randi() % prefix_keys.size()]
			var prefix: String = Localization.get_text("station_prefix." + prefix_key)
			match name_type:
				0:
					return prefix + " " + greek[rng.randi() % greek.size()]
				1:
					return names[rng.randi() % names.size()] + " " + str(rng.randi_range(1, 9))
				2:
					return prefix + " " + names[rng.randi() % names.size()]
				_:
					return greek[rng.randi() % greek.size()] + "-" + str(rng.randi_range(1, 99))


func _get_node_label(node_type: int) -> String:
	## 노드 타입 라벨 (다국어 지원)
	match node_type:
		Constants.NodeType.START: return Localization.get_text("node_type.start")
		Constants.NodeType.BATTLE: return Localization.get_text("node_type.battle")
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE: return Localization.get_text("node_type.rescue")
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE: return Localization.get_text("node_type.salvage")
		Constants.NodeType.DEPOT: return Localization.get_text("node_type.depot")
		Constants.NodeType.STORM: return Localization.get_text("node_type.storm")
		Constants.NodeType.BOSS: return Localization.get_text("node_type.boss")
		Constants.NodeType.REST: return Localization.get_text("node_type.rest")
		Constants.NodeType.GATE: return Localization.get_text("node_type.gate")
		Constants.NodeType.BEACON: return Localization.get_text("node_type.beacon")
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
	## 점선 스타일의 항로 연결선
	var line := Node3D.new()
	line.name = "Route"

	var direction := to_pos - from_pos
	var length := direction.length()

	if length < 0.1:
		return line

	var forward := direction.normalized()

	# 점선 효과: 여러 개의 작은 세그먼트
	var segment_length: float = 0.3
	var gap_length: float = 0.2
	var total_step: float = segment_length + gap_length
	var segment_count: int = int(length / total_step)

	for i in range(segment_count):
		var t: float = float(i) / float(segment_count)
		var segment_pos: Vector3 = from_pos.lerp(to_pos, t + 0.5 / float(segment_count))
		segment_pos.y = 0.05

		var segment := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.04
		capsule.height = segment_length

		# 거리에 따라 색상 그라데이션
		var route_color := Color(0.3, 0.5, 0.7, 0.6).lerp(Color(0.5, 0.7, 0.9, 0.8), t)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = route_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.5, 0.7)
		mat.emission_energy_multiplier = 0.3
		capsule.material = mat

		segment.mesh = capsule
		segment.position = segment_pos

		# 방향 회전
		var angle := Vector3.UP.angle_to(forward)
		var axis := Vector3.UP.cross(forward)
		if axis.length() > 0.001:
			segment.transform.basis = Basis(axis.normalized(), angle)

		line.add_child(segment)

	# 방향 화살표 (끝점 근처)
	var arrow_pos: Vector3 = from_pos.lerp(to_pos, 0.7)
	arrow_pos.y = 0.1
	var arrow := _create_route_arrow(forward)
	arrow.position = arrow_pos
	line.add_child(arrow)

	return line


func _create_route_arrow(direction: Vector3) -> MeshInstance3D:
	## 항로 방향 화살표
	var arrow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.15, 0.25, 0.15)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.7, 0.9, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.6, 0.8)
	mat.emission_energy_multiplier = 0.5
	prism.material = mat

	arrow.mesh = prism

	# 방향으로 회전
	var angle := Vector3.FORWARD.signed_angle_to(Vector3(direction.x, 0, direction.z).normalized(), Vector3.UP)
	arrow.rotation.y = angle
	arrow.rotation.x = -PI / 2  # 앞으로 눕히기

	return arrow


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
	## 드라마틱한 스톰 성운 효과

	# 메인 스톰 벽 (여러 층)
	for i in range(5):
		var layer := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(60, 12 - i * 1.5, 3 + i * 0.5)

		var mat := StandardMaterial3D.new()
		var alpha: float = 0.15 - i * 0.02
		mat.albedo_color = Color(0.5 + i * 0.05, 0.1, 0.6 - i * 0.05, alpha)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.1, 0.7)
		mat.emission_energy_multiplier = 0.8 - i * 0.1
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = mat

		layer.mesh = box
		layer.position = Vector3(0, 4, -i * 1.5)
		storm_wall.add_child(layer)

	# 스톰 에너지 볼들
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for i in range(12):
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.5, 1.5)
		sphere.height = sphere.radius * 2

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.2, 0.9, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.3, 1.0)
		mat.emission_energy_multiplier = 1.5
		sphere.material = mat

		orb.mesh = sphere
		orb.position = Vector3(
			rng.randf_range(-25, 25),
			rng.randf_range(1, 8),
			rng.randf_range(-3, 0)
		)
		storm_wall.add_child(orb)

	# 스톰 라이트
	var storm_light := OmniLight3D.new()
	storm_light.name = "StormLight"
	storm_light.light_color = Color(0.6, 0.2, 0.8)
	storm_light.light_energy = 2.0
	storm_light.omni_range = 20.0
	storm_light.position = Vector3(0, 5, 0)
	storm_wall.add_child(storm_light)

	# 경고 텍스트
	var warning := Label3D.new()
	warning.name = "StormWarning"
	warning.text = "⚠ " + Localization.get_text("star_system.storm_warning") + " ⚠"
	warning.font_size = 72
	warning.position = Vector3(0, 10, 1)
	warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warning.modulate = Color(1.0, 0.3, 0.5)
	warning.outline_modulate = Color(0.3, 0, 0.2)
	warning.outline_size = 8
	storm_wall.add_child(warning)


# ===== NODE VISUALS =====

func _update_node_visuals() -> void:
	# 접근 가능한 노드 ID 목록
	var accessible_ids: Array = []
	var current_data := _get_node_data(_current_node_id)
	if not current_data.is_empty():
		accessible_ids = current_data.get("connections_out", [])

	for node_id in _node_objects:
		var node_obj: Node3D = _node_objects[node_id]
		var mesh_container: Node3D = node_obj.get_node_or_null("Mesh")
		if mesh_container == null:
			continue

		var node_data := _get_node_data(node_id)
		var node_type: int = node_data.get("type", Constants.NodeType.BATTLE)
		var node_layer: int = node_data.get("layer", 0)
		var base_color: Color = NODE_COLORS.get(node_type, Color.WHITE)

		# 상태별 색상/효과 결정
		var target_color: Color = base_color
		var emission_mult: float = 0.3
		var is_dimmed: bool = false

		# 스톰에 삼켜진 노드
		if node_layer <= _storm_depth:
			target_color = Color(0.15, 0.1, 0.2)
			emission_mult = 0.0
			is_dimmed = true
		# 현재 노드
		elif node_id == _current_node_id:
			target_color = Color.GOLD
			emission_mult = 1.0
		# 선택된 노드
		elif node_id == _selected_node_id:
			target_color = Color.WHITE
			emission_mult = 0.8
		# 접근 가능한 노드
		elif node_id in accessible_ids:
			emission_mult = 0.5
		# 접근 불가 노드
		else:
			target_color = base_color.darkened(0.5)
			emission_mult = 0.1

		# 모든 자식 메시에 적용
		_apply_visual_state_recursive(mesh_container, target_color, emission_mult, is_dimmed)

		# 타입 라벨 색상 업데이트
		var type_label: Label3D = node_obj.get_node_or_null("TypeLabel")
		if type_label:
			if is_dimmed:
				type_label.modulate = Color(0.3, 0.3, 0.3, 0.5)
			elif node_id == _current_node_id:
				type_label.modulate = Color.GOLD
			elif node_id == _selected_node_id:
				type_label.modulate = Color.WHITE
			else:
				type_label.modulate = base_color

		# 이름 라벨 색상 업데이트
		var name_label: Label3D = node_obj.get_node_or_null("NameLabel")
		if name_label:
			if is_dimmed:
				name_label.modulate = Color(0.3, 0.3, 0.3, 0.3)
			elif node_id == _current_node_id:
				name_label.modulate = Color(1.0, 0.9, 0.6)
			else:
				name_label.modulate = Color(0.7, 0.8, 0.9, 0.9)

		# 스테이션 라이트 업데이트
		var station_light: OmniLight3D = node_obj.get_node_or_null("StationLight")
		if station_light:
			station_light.light_energy = 0.0 if is_dimmed else (1.0 if node_id == _current_node_id else 0.5)


func _apply_visual_state_recursive(node: Node, color: Color, emission_mult: float, is_dimmed: bool) -> void:
	## 노드의 모든 자식 메시에 시각 상태 적용
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node
		if mesh_inst.mesh and mesh_inst.mesh.material:
			var mat: StandardMaterial3D = mesh_inst.mesh.material.duplicate()
			if is_dimmed:
				mat.albedo_color = mat.albedo_color.darkened(0.7)
				mat.emission_enabled = false
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				# 원래 색상 비율 유지하면서 밝기만 조정
				var brightness: float = color.v
				mat.emission_energy_multiplier = emission_mult
			mesh_inst.material_override = mat

	for child in node.get_children():
		_apply_visual_state_recursive(child, color, emission_mult, is_dimmed)


# ===== CAMERA =====

func _process_camera(delta: float) -> void:
	if camera == null:
		return

	# 부드러운 회전
	_camera_rotation = lerpf(_camera_rotation, _target_rotation, 8.0 * delta)
	camera.rotation_degrees = Vector3(-ISOMETRIC_ANGLE, _camera_rotation, 0)

	# 공전 위치 계산 (타겟 중심으로)
	_update_camera_orbit_position()

	# 부드러운 줌
	camera.size = lerpf(camera.size, _camera_zoom, 5.0 * delta)


func _update_camera_orbit_position() -> void:
	## 카메라 공전 위치 계산 (Battle3D 스타일)
	var angle_rad := deg_to_rad(_camera_rotation)
	var offset := Vector3(
		sin(angle_rad) * ORBIT_DISTANCE + _camera_target.x,
		ORBIT_DISTANCE * 0.8,
		cos(angle_rad) * ORBIT_DISTANCE + _camera_target.z
	)
	camera.position = offset


func _handle_camera_input(event: InputEvent) -> void:
	# 마우스 휠 줌
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_zoom = clampf(_camera_zoom - camera_zoom_speed, 10.0, 40.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_zoom = clampf(_camera_zoom + camera_zoom_speed, 10.0, 40.0)
		# 왼쪽 또는 중간 버튼으로 드래그
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_drag_start = event.position
				_drag_distance = 0.0
			else:
				_is_dragging = false

	# 마우스 드래그 이동 (회전 방향 보정)
	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _drag_start
		_drag_distance += delta.length()
		_drag_start = event.position
		# 회전 각도에 따라 이동 방향 보정
		var angle_rad := deg_to_rad(_camera_rotation)
		var world_delta := Vector3(
			-delta.x * cos(angle_rad) - delta.y * sin(angle_rad),
			0,
			delta.x * sin(angle_rad) - delta.y * cos(angle_rad)
		) * 0.03 * _camera_zoom / 15.0
		_camera_target += world_delta

	# 키보드 입력
	if event is InputEventKey and event.pressed:
		# Q/E: 45도 스냅 회전 (Battle3D와 동일)
		if event.keycode == KEY_Q:
			_target_rotation -= 45.0
		elif event.keycode == KEY_E:
			_target_rotation += 45.0
		else:
			# WASD: 이동 (회전 방향 보정)
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
				# 카메라 회전에 맞춰 이동 방향 보정
				var angle_rad := deg_to_rad(_camera_rotation)
				var rotated_move := Vector3(
					move.x * cos(angle_rad) - move.z * sin(angle_rad),
					0,
					move.x * sin(angle_rad) + move.z * cos(angle_rad)
				)
				_camera_target += rotated_move * camera_speed * 0.1


# ===== INPUT =====

func _handle_node_selection(event: InputEvent) -> void:
	# 왼쪽 버튼 릴리스 시 드래그가 아니었으면 노드 선택
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _drag_distance < DRAG_THRESHOLD:
				_raycast_node_selection(event.position)

	# U 키 - 업그레이드 화면
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		_on_upgrade_pressed()

	# ENTER/SPACE 키 - 선택된 노드 진입
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_enter_pressed()


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


func _on_node_clicked(node_id: String) -> void:
	## 노드 클릭 - 선택만 (진입은 ENTER 버튼으로)
	select_node(node_id)

	# 선택된 노드로 카메라 이동
	if _node_objects.has(node_id):
		var node_obj: Node3D = _node_objects[node_id]
		_camera_target = node_obj.global_position


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
	confirm.title = Localization.get_text("dialog.return_to_menu_title")
	confirm.dialog_text = Localization.get_text("dialog.return_to_menu_desc")
	confirm.exclusive = false
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		confirm.queue_free()
		if GameState:
			GameState.save_game()
		var tree := get_tree()
		if tree:
			tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)
	confirm.canceled.connect(func(): confirm.queue_free())


func _on_pause_pressed() -> void:
	# 일시정지 메뉴 (간단 구현)
	get_tree().paused = not get_tree().paused


func _on_upgrade_pressed() -> void:
	# 업그레이드 화면으로 전환
	var tree := get_tree()
	if tree == null:
		push_warning("[SectorMap3D] Not in scene tree")
		return

	var upgrade_scene := "res://src/ui/campaign/UpgradeScreen.tscn"
	if ResourceLoader.exists(upgrade_scene):
		tree.change_scene_to_file(upgrade_scene)
	else:
		push_warning("[SectorMap3D] UpgradeScreen.tscn not found")


func _on_next_turn_pressed() -> void:
	# 턴 종료 확인
	var confirm := ConfirmationDialog.new()
	confirm.title = Localization.get_text("dialog.end_turn_title")
	confirm.dialog_text = Localization.get_text("dialog.end_turn_desc")
	confirm.exclusive = false
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
	dialog.title = Localization.get_text("dialog.storm_consumed_title")
	dialog.dialog_text = Localization.get_text("dialog.storm_consumed_desc")
	dialog.exclusive = false
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		if GameState:
			GameState.end_run(false)
		var tree := get_tree()
		if tree:
			tree.change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
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

	depth_label.text = Localization.get_text("star_system.depth_label", [current_layer, _storm_depth])


func _update_credits_label() -> void:
	if credits_label == null:
		return

	var credits: int = 0
	if GameState and GameState.has_method("get_credits"):
		credits = GameState.get_credits()

	credits_label.text = Localization.get_text("star_system.credits_label", [credits])


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

	# 스테이션 이름 가져오기
	var station_name: String = ""
	if _node_objects.has(node_id):
		var node_obj: Node3D = _node_objects[node_id]
		station_name = node_obj.get_meta("station_name", "")

	if node_title:
		# 스테이션 이름 + 타입
		var type_label: String = _get_node_label(node_type)
		if station_name != "":
			node_title.text = "%s\n[%s]" % [station_name, type_label]
		else:
			node_title.text = type_label

	if node_desc:
		node_desc.text = _get_node_description(node_type)

	if reward_value:
		reward_value.text = _get_node_reward_text(node_type)

	if enter_btn:
		var can_enter: bool = _can_enter_node(node_id)
		enter_btn.disabled = not can_enter
		enter_btn.text = "ENTER [Space]" if can_enter else "Cannot Enter"

	node_info_panel.visible = true


func _hide_node_info() -> void:
	if node_info_panel:
		node_info_panel.visible = false


func _get_node_description(node_type: int) -> String:
	match node_type:
		Constants.NodeType.START:
			return Localization.get_text("node_description.start")
		Constants.NodeType.BATTLE:
			return Localization.get_text("node_description.battle")
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			return Localization.get_text("node_description.rescue")
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			return Localization.get_text("node_description.salvage")
		Constants.NodeType.DEPOT:
			return Localization.get_text("node_description.depot")
		Constants.NodeType.STORM:
			return Localization.get_text("node_description.storm")
		Constants.NodeType.BOSS:
			return Localization.get_text("node_description.boss")
		Constants.NodeType.REST:
			return Localization.get_text("node_description.rest")
		Constants.NodeType.GATE:
			return Localization.get_text("node_description.gate")
		Constants.NodeType.BEACON:
			return Localization.get_text("node_description.beacon")
		_:
			return ""


func _get_node_reward_text(node_type: int) -> String:
	match node_type:
		Constants.NodeType.BATTLE:
			return Localization.get_text("node_reward.battle")
		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			return Localization.get_text("node_reward.rescue")
		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			return Localization.get_text("node_reward.salvage")
		Constants.NodeType.DEPOT:
			return Localization.get_text("node_reward.depot")
		Constants.NodeType.STORM:
			return Localization.get_text("node_reward.storm")
		Constants.NodeType.BOSS:
			return Localization.get_text("node_reward.boss")
		Constants.NodeType.REST:
			return Localization.get_text("node_reward.rest")
		Constants.NodeType.GATE:
			return Localization.get_text("node_reward.gate")
		_:
			return ""
