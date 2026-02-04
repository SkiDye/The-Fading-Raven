class_name FacilityData
extends Resource

## 시설 정적 데이터
## S02에서 리소스 파일(.tres) 생성 예정


@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String

@export_group("Classification")
@export var facility_type: int = Constants.FacilityType.HOUSING
@export var size: Vector2i = Vector2i(2, 2)  # 타일 크기
@export var priority: int = 1  # 적 타겟팅 우선순위

@export_group("Stats")
@export var max_hp: int = 100
@export var defense: float = 0.0

@export_group("Effects")
@export var passive_bonus: Dictionary = {}  # {"crew_hp": 0.1, "crew_damage": 0.05}
@export var active_effect_id: String = ""
@export var effect_radius: float = 0.0  # 0이면 전역

@export_group("Rewards")
@export var save_credits: int = 50
@export var loss_penalty: String = ""  # "crew_damage", "morale_loss" 등

@export_group("Visual")
@export var icon: Texture2D
@export var sprite: Texture2D
@export var color: Color = Color.CYAN
@export var destroyed_sprite: Texture2D


func get_bonus(stat_name: String) -> float:
	return passive_bonus.get(stat_name, 0.0)


func get_tile_positions(origin: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			positions.append(origin + Vector2i(x, y))
	return positions
