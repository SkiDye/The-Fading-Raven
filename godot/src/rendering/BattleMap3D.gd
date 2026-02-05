class_name BattleMap3D
extends Node3D

## 3D 아이소메트릭 전투 맵
## Bad North 스타일의 스테이션 렌더링

# ===== SIGNALS =====

signal tile_clicked(tile_pos: Vector2i)
signal tile_hovered(tile_pos: Vector2i)
signal entity_clicked(entity: Node3D)


# ===== CONFIGURATION =====

@export_group("Grid Settings")
@export var tile_size: float = 1.0
@export var wall_height: float = 2.0
@export var elevated_height: float = 1.0

@export_group("Materials")
@export var floor_material: StandardMaterial3D
@export var wall_material: StandardMaterial3D
@export var void_material: StandardMaterial3D
@export var facility_material: StandardMaterial3D


# ===== CHILD NODES =====

var _tile_grid: Node = null
var _tiles_container: Node3D
var _entities_container: Node3D
var _effects_container: Node3D
var _highlight_mesh: MeshInstance3D


# ===== STATE =====

var _width: int = 0
var _height: int = 0
var _tile_meshes: Dictionary = {}  # Vector2i -> MeshInstance3D
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _selected_tiles: Array[Vector2i] = []
var _tile_types: Dictionary = {}   # Vector2i -> TileType (from layout)
var _tile_elevations: Dictionary = {}  # Vector2i -> int (from layout)


# ===== PRELOADS =====

var _guardian_scene: PackedScene
var _rusher_scene: PackedScene
var _facility_scene: PackedScene
var _boarding_pod_scene: PackedScene


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_containers()
	_setup_materials()
	_setup_highlight()
	_load_model_scenes()


func _setup_containers() -> void:
	_tiles_container = Node3D.new()
	_tiles_container.name = "Tiles"
	add_child(_tiles_container)

	_entities_container = Node3D.new()
	_entities_container.name = "Entities"
	add_child(_entities_container)

	_effects_container = Node3D.new()
	_effects_container.name = "Effects"
	add_child(_effects_container)


func _setup_materials() -> void:
	# 바닥 재질
	if floor_material == null:
		floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color(0.35, 0.4, 0.5)
		floor_material.roughness = 0.8

	# 벽 재질
	if wall_material == null:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.5, 0.55, 0.6)
		wall_material.roughness = 0.7

	# 우주 공간 (투명)
	if void_material == null:
		void_material = StandardMaterial3D.new()
		void_material.albedo_color = Color(0.05, 0.05, 0.1, 0.3)
		void_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 시설 재질
	if facility_material == null:
		facility_material = StandardMaterial3D.new()
		facility_material.albedo_color = Color(0.3, 0.5, 0.7)
		facility_material.roughness = 0.6
		facility_material.metallic = 0.2


func _setup_highlight() -> void:
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.name = "TileHighlight"

	var highlight_mat := StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1.0, 1.0, 0.5, 0.4)
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size * 0.95, tile_size * 0.95)
	plane.material = highlight_mat

	_highlight_mesh.mesh = plane
	_highlight_mesh.visible = false
	add_child(_highlight_mesh)


func _load_model_scenes() -> void:
	# 3D 엔티티 씬 로드 (우선) 또는 GLB 파일 로드 (폴백)
	var crew_scene_path := "res://src/entities/crew/CrewSquad3D.tscn"
	var enemy_scene_path := "res://src/entities/enemy/EnemyUnit3D.tscn"
	var facility_scene_path := "res://src/entities/facility/Facility3D.tscn"
	var pod_scene_path := "res://src/entities/vehicle/DropPod3D.tscn"

	# 엔티티 씬 로드
	if ResourceLoader.exists(crew_scene_path):
		_guardian_scene = load(crew_scene_path)
	elif ResourceLoader.exists("res://assets/models/crews/guardian.glb"):
		_guardian_scene = load("res://assets/models/crews/guardian.glb")

	if ResourceLoader.exists(enemy_scene_path):
		_rusher_scene = load(enemy_scene_path)
	elif ResourceLoader.exists("res://assets/models/enemies/rusher.glb"):
		_rusher_scene = load("res://assets/models/enemies/rusher.glb")

	if ResourceLoader.exists(facility_scene_path):
		_facility_scene = load(facility_scene_path)
	elif ResourceLoader.exists("res://assets/models/facilities/residential_sml.glb"):
		_facility_scene = load("res://assets/models/facilities/residential_sml.glb")

	if ResourceLoader.exists(pod_scene_path):
		_boarding_pod_scene = load(pod_scene_path)
	elif ResourceLoader.exists("res://assets/models/vehicles/boarding_pod.glb"):
		_boarding_pod_scene = load("res://assets/models/vehicles/boarding_pod.glb")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)


# ===== PUBLIC API =====

## 타일 그리드 설정
func set_tile_grid(grid: Node) -> void:
	_tile_grid = grid
	if grid:
		_width = grid.width if "width" in grid else 10
		_height = grid.height if "height" in grid else 10
	rebuild_map()


## 맵 크기 직접 설정
func set_map_size(width: int, height: int) -> void:
	_width = width
	_height = height
	# rebuild_map() 호출은 외부에서 명시적으로 해야 함


## StationLayout에서 타일/고도 정보 복사
func initialize_from_layout(layout: Variant) -> void:
	if layout == null:
		return

	_tile_types.clear()
	_tile_elevations.clear()

	for y in range(layout.height):
		for x in range(layout.width):
			var pos := Vector2i(x, y)
			var tile_type: int = layout.get_tile(pos)
			var elevation: int = 0
			if layout.has_method("get_elevation"):
				elevation = layout.get_elevation(pos)
			_tile_types[pos] = tile_type
			_tile_elevations[pos] = elevation

	print("[BattleMap3D] Loaded layout: %dx%d, tiles: %d" % [layout.width, layout.height, _tile_types.size()])


## 맵 재생성
func rebuild_map() -> void:
	_clear_tiles()
	_generate_tiles()


## 크루 스폰
func spawn_crew(tile_pos: Vector2i, class_id: String) -> Node3D:
	var crew_node: Node3D

	if _guardian_scene:
		crew_node = _guardian_scene.instantiate()
	else:
		crew_node = _create_placeholder_unit(class_id, Color.BLUE)

	_entities_container.add_child(crew_node)
	crew_node.position = tile_to_world(tile_pos)

	# 엔티티 씬인 경우 initialize 호출
	if crew_node.has_method("initialize"):
		crew_node.initialize({
			"class_id": class_id,
			"tile_position": tile_pos
		})
	else:
		crew_node.set_meta("tile_pos", tile_pos)
		crew_node.set_meta("class_id", class_id)
		crew_node.set_meta("is_crew", true)

	return crew_node


## 적 스폰
func spawn_enemy(tile_pos: Vector2i, enemy_id: String) -> Node3D:
	var enemy_node: Node3D

	if _rusher_scene:
		enemy_node = _rusher_scene.instantiate()
	else:
		enemy_node = _create_placeholder_unit(enemy_id, Color.RED)

	_entities_container.add_child(enemy_node)
	enemy_node.position = tile_to_world(tile_pos)

	# 엔티티 씬인 경우 initialize 호출
	if enemy_node.has_method("initialize"):
		enemy_node.initialize({
			"enemy_id": enemy_id,
			"tile_position": tile_pos
		})
	else:
		enemy_node.set_meta("tile_pos", tile_pos)
		enemy_node.set_meta("enemy_id", enemy_id)
		enemy_node.set_meta("is_enemy", true)

	return enemy_node


## 시설 스폰
func spawn_facility(tile_pos: Vector2i, facility_id: String) -> Node3D:
	var facility_node: Node3D

	if _facility_scene:
		facility_node = _facility_scene.instantiate()
	else:
		facility_node = _create_placeholder_facility(facility_id)

	_entities_container.add_child(facility_node)
	facility_node.position = tile_to_world(tile_pos)

	# 엔티티 씬인 경우 initialize 호출
	if facility_node.has_method("initialize"):
		facility_node.initialize({
			"facility_id": facility_id,
			"tile_position": tile_pos
		})
	else:
		facility_node.set_meta("tile_pos", tile_pos)
		facility_node.set_meta("facility_id", facility_id)

	return facility_node


## 침투정 스폰
func spawn_drop_pod(target_tile: Vector2i, enemies: Array, approach_dir: Vector3 = Vector3.BACK) -> Node3D:
	var pod_node: Node3D

	if _boarding_pod_scene:
		pod_node = _boarding_pod_scene.instantiate()
	else:
		pod_node = _create_placeholder_vehicle()

	_entities_container.add_child(pod_node)

	# 엔티티 씬인 경우 initialize 호출
	if pod_node.has_method("initialize"):
		pod_node.initialize({
			"target_tile": target_tile,
			"enemies": enemies,
			"approach_direction": approach_dir
		})
		pod_node.start_approach()
	else:
		var world_pos := tile_to_world(target_tile) - approach_dir.normalized() * 15.0
		world_pos.y = 5.0
		pod_node.position = world_pos
		pod_node.look_at(tile_to_world(target_tile))

	return pod_node


## 침투정 스폰 (레거시 호환)
func spawn_boarding_pod(world_pos: Vector3, direction: Vector3) -> Node3D:
	var tile_pos := world_to_tile(world_pos + direction * 10.0)
	return spawn_drop_pod(tile_pos, [], -direction)


## 타일 하이라이트
func highlight_tile(tile_pos: Vector2i, show: bool = true) -> void:
	if show and _is_valid_tile(tile_pos):
		_highlight_mesh.visible = true
		_highlight_mesh.position = tile_to_world(tile_pos) + Vector3(0, 0.05, 0)
	else:
		_highlight_mesh.visible = false


## 이동 범위 표시
func show_move_range(tiles: Array[Vector2i], color: Color = Color(0.3, 0.5, 0.9, 0.3)) -> void:
	for tile_pos in tiles:
		_highlight_tile_mesh(tile_pos, color)


## 공격 범위 표시
func show_attack_range(tiles: Array[Vector2i], color: Color = Color(0.9, 0.3, 0.3, 0.3)) -> void:
	for tile_pos in tiles:
		_highlight_tile_mesh(tile_pos, color)


## 범위 표시 제거
func clear_range_display() -> void:
	for tile_pos in _tile_meshes:
		var mesh: MeshInstance3D = _tile_meshes[tile_pos]
		if mesh and mesh.has_meta("highlight_overlay"):
			var overlay: MeshInstance3D = mesh.get_meta("highlight_overlay")
			if overlay:
				overlay.queue_free()
			mesh.remove_meta("highlight_overlay")


## 타일 좌표 → 월드 좌표
func tile_to_world(tile_pos: Vector2i) -> Vector3:
	return Vector3(
		tile_pos.x * tile_size + tile_size * 0.5,
		0,
		tile_pos.y * tile_size + tile_size * 0.5
	)


## 월드 좌표 → 타일 좌표
func world_to_tile(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.z / tile_size)
	)


## 맵 경계 가져오기
func get_map_bounds() -> AABB:
	return AABB(
		Vector3.ZERO,
		Vector3(_width * tile_size, wall_height * 2, _height * tile_size)
	)


# ===== PRIVATE: TILE GENERATION =====

func _clear_tiles() -> void:
	for child in _tiles_container.get_children():
		child.queue_free()
	_tile_meshes.clear()


func _generate_tiles() -> void:
	for y in range(_height):
		for x in range(_width):
			var tile_pos := Vector2i(x, y)
			_create_tile_mesh(tile_pos)


func _create_tile_mesh(tile_pos: Vector2i) -> void:
	var tile_type: int = _get_tile_type(tile_pos)
	var elevation: int = _get_tile_elevation(tile_pos)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Tile_%d_%d" % [tile_pos.x, tile_pos.y]

	match tile_type:
		Constants.TileType.VOID:
			_setup_void_tile(mesh_instance, tile_pos)
		Constants.TileType.FLOOR:
			_setup_floor_tile(mesh_instance, tile_pos, elevation)
		Constants.TileType.WALL:
			_setup_wall_tile(mesh_instance, tile_pos, elevation)
		Constants.TileType.FACILITY:
			_setup_floor_tile(mesh_instance, tile_pos, elevation)
		Constants.TileType.AIRLOCK:
			_setup_airlock_tile(mesh_instance, tile_pos, elevation)
		Constants.TileType.ELEVATED:
			_setup_elevated_tile(mesh_instance, tile_pos)
		Constants.TileType.LOWERED:
			_setup_lowered_tile(mesh_instance, tile_pos)
		Constants.TileType.COVER_HALF, Constants.TileType.COVER_FULL:
			_setup_cover_tile(mesh_instance, tile_pos, elevation, tile_type == Constants.TileType.COVER_FULL)
		_:
			_setup_floor_tile(mesh_instance, tile_pos, elevation)

	_tiles_container.add_child(mesh_instance)
	_tile_meshes[tile_pos] = mesh_instance


func _setup_void_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size, tile_size)
	plane.material = void_material
	mesh_instance.mesh = plane
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, -0.5, 0)


func _setup_floor_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i, elevation: int) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size * 0.98, tile_size * 0.98)
	plane.material = floor_material
	mesh_instance.mesh = plane
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, elevation * elevated_height, 0)

	# 높이가 있으면 측면 추가
	if elevation > 0:
		_add_tile_sides(mesh_instance, elevation)


func _setup_wall_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i, elevation: int) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(tile_size * 0.98, wall_height, tile_size * 0.98)
	box.material = wall_material
	mesh_instance.mesh = box
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, wall_height * 0.5 + elevation * elevated_height, 0)


func _setup_airlock_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i, elevation: int) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size * 0.98, tile_size * 0.98)

	var airlock_mat := StandardMaterial3D.new()
	airlock_mat.albedo_color = Color(0.6, 0.3, 0.3)
	airlock_mat.roughness = 0.7
	plane.material = airlock_mat

	mesh_instance.mesh = plane
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, elevation * elevated_height, 0)

	# 경고 표시 추가
	var warning := _create_warning_marker()
	warning.position = Vector3(0, 0.1, 0)
	mesh_instance.add_child(warning)


func _setup_elevated_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(tile_size * 0.98, elevated_height, tile_size * 0.98)

	var elevated_mat := StandardMaterial3D.new()
	elevated_mat.albedo_color = Color(0.45, 0.5, 0.55)
	elevated_mat.roughness = 0.8
	box.material = elevated_mat

	mesh_instance.mesh = box
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, elevated_height * 0.5, 0)


func _setup_lowered_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size * 0.98, tile_size * 0.98)

	var lowered_mat := StandardMaterial3D.new()
	lowered_mat.albedo_color = Color(0.25, 0.3, 0.35)
	lowered_mat.roughness = 0.9
	plane.material = lowered_mat

	mesh_instance.mesh = plane
	mesh_instance.position = tile_to_world(tile_pos) + Vector3(0, -0.3, 0)


func _setup_cover_tile(mesh_instance: MeshInstance3D, tile_pos: Vector2i, elevation: int, is_full: bool) -> void:
	# 바닥
	_setup_floor_tile(mesh_instance, tile_pos, elevation)

	# 엄폐물 박스
	var cover := MeshInstance3D.new()
	var box := BoxMesh.new()
	var cover_height: float = 0.8 if is_full else 0.4
	box.size = Vector3(tile_size * 0.4, cover_height, tile_size * 0.4)

	var cover_mat := StandardMaterial3D.new()
	cover_mat.albedo_color = Color(0.5, 0.45, 0.4)
	cover_mat.roughness = 0.8
	box.material = cover_mat

	cover.mesh = box
	cover.position = Vector3(0, cover_height * 0.5 + 0.05, 0)
	mesh_instance.add_child(cover)


func _add_tile_sides(mesh_instance: MeshInstance3D, height: int) -> void:
	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_color = Color(0.3, 0.35, 0.4)
	side_mat.roughness = 0.8

	var side_height: float = height * elevated_height

	# 4방향 측면
	var directions := [
		Vector3(tile_size * 0.5, -side_height * 0.5, 0),
		Vector3(-tile_size * 0.5, -side_height * 0.5, 0),
		Vector3(0, -side_height * 0.5, tile_size * 0.5),
		Vector3(0, -side_height * 0.5, -tile_size * 0.5),
	]
	var rotations := [90.0, -90.0, 0.0, 180.0]

	for i in range(4):
		var side := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(tile_size * 0.98, side_height)
		plane.material = side_mat
		side.mesh = plane
		side.position = directions[i]
		side.rotation_degrees.y = rotations[i]
		side.rotation_degrees.x = 90
		mesh_instance.add_child(side)


func _create_warning_marker() -> Node3D:
	var marker := Node3D.new()

	# 삼각형 경고 표시
	var warning_mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.3, 0.2, 0.3)

	var warning_mat := StandardMaterial3D.new()
	warning_mat.albedo_color = Color(1.0, 0.8, 0.0)
	warning_mat.emission_enabled = true
	warning_mat.emission = Color(1.0, 0.8, 0.0)
	warning_mat.emission_energy_multiplier = 0.5
	prism.material = warning_mat

	warning_mesh.mesh = prism
	marker.add_child(warning_mesh)

	return marker


# ===== PRIVATE: PLACEHOLDERS =====

func _create_placeholder_unit(id: String, color: Color) -> Node3D:
	var unit := Node3D.new()
	unit.name = "Unit_" + id

	# 캡슐 메시
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	capsule.material = mat

	mesh.mesh = capsule
	mesh.position.y = 0.4
	unit.add_child(mesh)

	# 방향 표시 (앞면)
	var front := MeshInstance3D.new()
	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(0.1, 0.1, 0.15)

	var front_mat := StandardMaterial3D.new()
	front_mat.albedo_color = color.lightened(0.3)
	front_mesh.material = front_mat

	front.mesh = front_mesh
	front.position = Vector3(0, 0.5, 0.25)
	unit.add_child(front)

	return unit


func _create_placeholder_facility(id: String) -> Node3D:
	var facility := Node3D.new()
	facility.name = "Facility_" + id

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(tile_size * 0.8, 1.2, tile_size * 0.8)
	box.material = facility_material

	mesh.mesh = box
	mesh.position.y = 0.6
	facility.add_child(mesh)

	return facility


func _create_placeholder_vehicle() -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "Vehicle"

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.5, 1.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.5)
	mat.metallic = 0.5
	box.material = mat

	mesh.mesh = box
	mesh.position.y = 0.25
	vehicle.add_child(mesh)

	return vehicle


# ===== PRIVATE: HELPERS =====

func _get_tile_type(pos: Vector2i) -> int:
	# 먼저 layout에서 로드된 데이터 확인
	if _tile_types.has(pos):
		return _tile_types[pos]

	# 폴백: tile_grid
	if _tile_grid == null:
		return Constants.TileType.FLOOR

	var tile = _tile_grid.get_tile(pos) if _tile_grid.has_method("get_tile") else null
	if tile and "type" in tile:
		return tile.type

	return Constants.TileType.FLOOR


func _get_tile_elevation(pos: Vector2i) -> int:
	# 먼저 layout에서 로드된 데이터 확인
	if _tile_elevations.has(pos):
		return _tile_elevations[pos]

	# 폴백: tile_grid
	if _tile_grid == null:
		return 0

	var tile = _tile_grid.get_tile(pos) if _tile_grid.has_method("get_tile") else null
	if tile and "elevation" in tile:
		return tile.elevation

	return 0


func _is_valid_tile(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _width and pos.y >= 0 and pos.y < _height


func _highlight_tile_mesh(tile_pos: Vector2i, color: Color) -> void:
	if not _tile_meshes.has(tile_pos):
		return

	var tile_mesh: MeshInstance3D = _tile_meshes[tile_pos]

	# 기존 오버레이 제거
	if tile_mesh.has_meta("highlight_overlay"):
		var old_overlay: MeshInstance3D = tile_mesh.get_meta("highlight_overlay")
		if old_overlay:
			old_overlay.queue_free()

	# 새 오버레이 생성
	var overlay := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(tile_size * 0.95, tile_size * 0.95)

	var overlay_mat := StandardMaterial3D.new()
	overlay_mat.albedo_color = color
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = overlay_mat

	overlay.mesh = plane
	overlay.position.y = 0.02
	tile_mesh.add_child(overlay)
	tile_mesh.set_meta("highlight_overlay", overlay)


func _update_hover(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	# Y=0 평면과 교차
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		var world_pos := from + dir * t
		var new_hovered := world_to_tile(world_pos)

		if new_hovered != _hovered_tile and _is_valid_tile(new_hovered):
			_hovered_tile = new_hovered
			highlight_tile(_hovered_tile)
			tile_hovered.emit(_hovered_tile)


func _handle_click(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	# Y=0 평면과 교차
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		var world_pos := from + dir * t
		var tile_pos := world_to_tile(world_pos)

		if _is_valid_tile(tile_pos):
			tile_clicked.emit(tile_pos)
