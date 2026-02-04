class_name StationData
extends Resource

## 정거장(스테이지) 정적 데이터
## S10에서 상세 구현 예정


@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String

@export_group("Map")
@export var width: int = 20
@export var height: int = 15
@export var tile_data: Array[int] = []  # TileType 배열
@export var height_map: Array[int] = []  # 높이 데이터 (0=기본, 1=높음, -1=낮음)

@export_group("Spawn Points")
@export var player_spawns: Array[Vector2i] = []
@export var enemy_spawns: Array[Vector2i] = []
@export var airlock_positions: Array[Vector2i] = []

@export_group("Facilities")
@export var facility_placements: Array[Dictionary] = []  # [{"id": "housing", "position": Vector2i}]

@export_group("Waves")
@export var wave_count: int = 5
@export var base_budget: int = 10
@export var budget_per_wave: float = 0.2
@export var allowed_enemies: Array[String] = []

@export_group("Environment")
@export var theme_id: String = "default"
@export var ambient_color: Color = Color.WHITE
@export var has_storm: bool = false
@export var storm_intensity: float = 0.0

@export_group("Rewards")
@export var base_credits: int = 50
@export var bonus_per_facility: int = 20


func get_tile_type(pos: Vector2i) -> int:
	var index := pos.y * width + pos.x
	if index < 0 or index >= tile_data.size():
		return Constants.TileType.VOID
	return tile_data[index]


func get_height(pos: Vector2i) -> int:
	var index := pos.y * width + pos.x
	if index < 0 or index >= height_map.size():
		return 0
	return height_map[index]


func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func is_walkable(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	var tile_type := get_tile_type(pos)
	return tile_type in [
		Constants.TileType.FLOOR,
		Constants.TileType.ELEVATED,
		Constants.TileType.LOWERED,
		Constants.TileType.COVER_HALF,
		Constants.TileType.COVER_FULL
	]


func get_total_budget(wave_number: int, difficulty: int) -> int:
	var budget := base_budget + int(budget_per_wave * (wave_number - 1) * base_budget)

	match difficulty:
		Constants.Difficulty.HARD:
			budget = int(budget * 1.2)
		Constants.Difficulty.VERY_HARD:
			budget = int(budget * 1.5)
		Constants.Difficulty.NIGHTMARE:
			budget = int(budget * 2.0)

	return budget
