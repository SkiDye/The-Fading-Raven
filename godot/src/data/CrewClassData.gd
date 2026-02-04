class_name CrewClassData
extends Resource

## 크루 클래스 정적 데이터
## S02에서 리소스 파일(.tres) 생성 예정


@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String

@export_group("Base Stats")
@export var base_squad_size: int = 8
@export var base_hp: int = 10
@export var base_damage: int = 3
@export var attack_speed: float = 1.0
@export var move_speed: float = 1.5
@export var attack_range: float = 1.0

@export_group("Visual")
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var sprite_sheet: Texture2D

@export_group("Skill")
@export var skill_id: String
@export var skill_name: String
@export var skill_description: String
@export var skill_cooldown: float = 20.0

@export_group("Combat Modifiers")
@export var strengths: Array[String] = []
@export var weaknesses: Array[String] = []
@export var armor: float = 0.0
@export var evasion: float = 0.0


func get_stat_at_rank(stat_name: String, rank: int) -> float:
	var base_value: float = 0.0
	match stat_name:
		"hp":
			base_value = float(base_hp)
		"damage":
			base_value = float(base_damage)
		"attack_speed":
			base_value = attack_speed
		"move_speed":
			base_value = move_speed
		_:
			return 0.0

	# 랭크당 10% 증가
	return base_value * (1.0 + rank * 0.1)
