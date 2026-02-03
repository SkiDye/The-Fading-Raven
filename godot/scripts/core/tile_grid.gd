## TileGrid - 타일 기반 그리드 시스템
## 정거장 레이아웃과 전투 맵 관리
extends RefCounted
class_name TileGrid

# ===========================================
# 타일 타입
# ===========================================

enum TileType {
	VOID = 0,       # 우주 공간 (즉사)
	FLOOR = 1,      # 기본 바닥
	WALL = 2,       # 벽 (이동/시야 차단)
	FACILITY = 3,   # 시설 (방어 목표)
	AIRLOCK = 4,    # 에어락 (적 스폰 지점)
	ELEVATED = 5,   # 높은 지형 (+사거리)
	LOWERED = 6,    # 낮은 지형 (엄폐)
	COVER = 7,      # 엄폐물 (반엄폐)
}

# 타일별 이동 비용 (0 = 이동 불가)
const TILE_COSTS := {
	TileType.VOID: 0,
	TileType.FLOOR: 1,
	TileType.WALL: 0,
	TileType.FACILITY: 1,
	TileType.AIRLOCK: 1,
	TileType.ELEVATED: 2,
	TileType.LOWERED: 1,
	TileType.COVER: 1,
}

# 타일별 높이 레벨
const TILE_HEIGHTS := {
	TileType.VOID: -1,
	TileType.FLOOR: 0,
	TileType.WALL: 2,
	TileType.FACILITY: 0,
	TileType.AIRLOCK: 0,
	TileType.ELEVATED: 1,
	TileType.LOWERED: -1,
	TileType.COVER: 0,
}

# ===========================================
# 그리드 데이터
# ===========================================

var width: int = 0
var height: int = 0
var tiles: Array[int] = []  # TileType values
var entities: Dictionary = {}  # Vector2i -> Array[Node]
var facilities: Array[Dictionary] = []  # {position: Vector2i, health: int, max_health: int}
var airlocks: Array[Vector2i] = []


# ===========================================
# 초기화
# ===========================================

func _init(w: int = 20, h: int = 15) -> void:
	resize(w, h)


func resize(w: int, h: int) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	tiles.fill(TileType.VOID)
	entities.clear()
	facilities.clear()
	airlocks.clear()


func clear() -> void:
	tiles.fill(TileType.VOID)
	entities.clear()
	facilities.clear()
	airlocks.clear()


# ===========================================
# 타일 접근
# ===========================================

func _index(x: int, y: int) -> int:
	return y * width + x


func is_valid(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func is_valid_v(pos: Vector2i) -> bool:
	return is_valid(pos.x, pos.y)


func get_tile(x: int, y: int) -> TileType:
	if not is_valid(x, y):
		return TileType.VOID
	return tiles[_index(x, y)] as TileType


func get_tile_v(pos: Vector2i) -> TileType:
	return get_tile(pos.x, pos.y)


func set_tile(x: int, y: int, tile_type: TileType) -> void:
	if is_valid(x, y):
		tiles[_index(x, y)] = tile_type

		# 시설/에어락 추적
		var pos := Vector2i(x, y)
		if tile_type == TileType.FACILITY:
			if not _has_facility_at(pos):
				facilities.append({
					"position": pos,
					"health": Balance.FACILITY["health"],
					"max_health": Balance.FACILITY["health"],
				})
		elif tile_type == TileType.AIRLOCK:
			if pos not in airlocks:
				airlocks.append(pos)


func set_tile_v(pos: Vector2i, tile_type: TileType) -> void:
	set_tile(pos.x, pos.y, tile_type)


func _has_facility_at(pos: Vector2i) -> bool:
	for f in facilities:
		if f["position"] == pos:
			return true
	return false


# ===========================================
# 타일 속성 조회
# ===========================================

func is_walkable(x: int, y: int) -> bool:
	return TILE_COSTS.get(get_tile(x, y), 0) > 0


func is_walkable_v(pos: Vector2i) -> bool:
	return is_walkable(pos.x, pos.y)


func get_move_cost(x: int, y: int) -> int:
	return TILE_COSTS.get(get_tile(x, y), 0)


func get_move_cost_v(pos: Vector2i) -> int:
	return get_move_cost(pos.x, pos.y)


func get_height(x: int, y: int) -> int:
	return TILE_HEIGHTS.get(get_tile(x, y), 0)


func get_height_v(pos: Vector2i) -> int:
	return get_height(pos.x, pos.y)


func is_void(x: int, y: int) -> bool:
	return get_tile(x, y) == TileType.VOID


func is_void_v(pos: Vector2i) -> bool:
	return is_void(pos.x, pos.y)


func provides_cover(x: int, y: int) -> bool:
	var tile := get_tile(x, y)
	return tile == TileType.COVER or tile == TileType.LOWERED


func provides_cover_v(pos: Vector2i) -> bool:
	return provides_cover(pos.x, pos.y)


func is_elevated(x: int, y: int) -> bool:
	return get_tile(x, y) == TileType.ELEVATED


func is_elevated_v(pos: Vector2i) -> bool:
	return is_elevated(pos.x, pos.y)


# ===========================================
# 엔티티 관리
# ===========================================

func add_entity(pos: Vector2i, entity: Node) -> void:
	if not entities.has(pos):
		entities[pos] = []
	if entity not in entities[pos]:
		entities[pos].append(entity)


func remove_entity(pos: Vector2i, entity: Node) -> void:
	if entities.has(pos):
		entities[pos].erase(entity)
		if entities[pos].is_empty():
			entities.erase(pos)


func move_entity(entity: Node, from: Vector2i, to: Vector2i) -> void:
	remove_entity(from, entity)
	add_entity(to, entity)


func get_entities_at(pos: Vector2i) -> Array:
	return entities.get(pos, [])


func has_entity_at(pos: Vector2i) -> bool:
	return not get_entities_at(pos).is_empty()


func get_enemies_at(pos: Vector2i) -> Array:
	var result := []
	for e in get_entities_at(pos):
		if e.is_in_group("enemies"):
			result.append(e)
	return result


func get_crews_at(pos: Vector2i) -> Array:
	var result := []
	for e in get_entities_at(pos):
		if e.is_in_group("crews"):
			result.append(e)
	return result


# ===========================================
# 시설 관리
# ===========================================

func get_facility_at(pos: Vector2i) -> Dictionary:
	for f in facilities:
		if f["position"] == pos:
			return f
	return {}


func damage_facility(pos: Vector2i, amount: int) -> bool:
	var facility := get_facility_at(pos)
	if facility.is_empty():
		return false

	facility["health"] = maxi(0, facility["health"] - amount)
	return facility["health"] <= 0  # 파괴됨


func get_intact_facilities() -> Array[Dictionary]:
	var intact: Array[Dictionary] = []
	for f in facilities:
		if f["health"] > 0:
			intact.append(f)
	return intact


func get_destroyed_facilities() -> Array[Dictionary]:
	var destroyed: Array[Dictionary] = []
	for f in facilities:
		if f["health"] <= 0:
			destroyed.append(f)
	return destroyed


# ===========================================
# 이웃 조회
# ===========================================

func get_neighbors(pos: Vector2i, include_diagonal: bool = false) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []

	# 4방향
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

	# 8방향
	if include_diagonal:
		dirs.append_array([
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1)
		])

	for d in dirs:
		var n := pos + d
		if is_valid_v(n):
			neighbors.append(n)

	return neighbors


func get_walkable_neighbors(pos: Vector2i, include_diagonal: bool = false) -> Array[Vector2i]:
	var walkable: Array[Vector2i] = []
	for n in get_neighbors(pos, include_diagonal):
		if is_walkable_v(n):
			walkable.append(n)
	return walkable


# ===========================================
# 범위 조회
# ===========================================

func get_tiles_in_range(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for dy in range(-max_range, max_range + 1):
		for dx in range(-max_range, max_range + 1):
			var dist := absi(dx) + absi(dy)  # 맨해튼 거리
			if dist >= min_range and dist <= max_range:
				var pos := center + Vector2i(dx, dy)
				if is_valid_v(pos):
					result.append(pos)

	return result


func get_tiles_in_radius(center: Vector2i, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var r_int := int(ceil(radius))

	for dy in range(-r_int, r_int + 1):
		for dx in range(-r_int, r_int + 1):
			var pos := center + Vector2i(dx, dy)
			if is_valid_v(pos) and Vector2(dx, dy).length() <= radius:
				result.append(pos)

	return result


# ===========================================
# 시야 확인 (간단한 레이캐스트)
# ===========================================

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var dx := to.x - from.x
	var dy := to.y - from.y
	var steps := maxi(absi(dx), absi(dy))

	if steps == 0:
		return true

	var x_step := float(dx) / steps
	var y_step := float(dy) / steps

	var x := float(from.x) + 0.5
	var y := float(from.y) + 0.5

	for _i in range(steps):
		x += x_step
		y += y_step

		var check_pos := Vector2i(int(x), int(y))
		if check_pos != from and check_pos != to:
			var tile := get_tile_v(check_pos)
			if tile == TileType.WALL:
				return false

	return true


# ===========================================
# 직렬화
# ===========================================

func serialize() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"tiles": tiles.duplicate(),
		"facilities": facilities.duplicate(true),
		"airlocks": airlocks.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	width = data.get("width", 20)
	height = data.get("height", 15)
	tiles = data.get("tiles", [])
	facilities = data.get("facilities", [])
	airlocks = data.get("airlocks", [])
	entities.clear()


# ===========================================
# 디버그
# ===========================================

func debug_print() -> void:
	var symbols := {
		TileType.VOID: " ",
		TileType.FLOOR: ".",
		TileType.WALL: "#",
		TileType.FACILITY: "F",
		TileType.AIRLOCK: "A",
		TileType.ELEVATED: "^",
		TileType.LOWERED: "v",
		TileType.COVER: "=",
	}

	for y in range(height):
		var row := ""
		for x in range(width):
			row += symbols.get(get_tile(x, y), "?")
		print(row)
