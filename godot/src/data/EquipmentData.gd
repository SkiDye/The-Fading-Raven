class_name EquipmentData
extends Resource

## 장비 정적 데이터
## S02에서 리소스 파일(.tres) 생성 예정


@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String

@export_group("Classification")
@export var equipment_type: int = Constants.EquipmentType.PASSIVE
@export var rarity: int = 1  # 1=common, 2=uncommon, 3=rare

@export_group("Requirements")
@export var required_class: String = ""  # 빈 문자열이면 모든 클래스 가능
@export var unlock_id: String = ""  # 메타 언락 필요시

@export_group("Passive Effects")
@export var stat_modifiers: Dictionary = {}  # {"hp": 0.1, "damage": 5}
@export var special_effects: Array[String] = []

@export_group("Active Effects")
@export var cooldown: float = 30.0
@export var charges: int = -1  # -1이면 쿨다운 기반
@export var active_effect_id: String = ""

@export_group("Visual")
@export var icon: Texture2D
@export var color: Color = Color.WHITE


func get_stat_modifier(stat_name: String, level: int) -> float:
	var base: float = float(stat_modifiers.get(stat_name, 0.0))
	# 레벨당 20% 증가
	return base * (1.0 + level * 0.2)


func is_usable_by_class(class_id: String) -> bool:
	if required_class == "":
		return true
	return required_class == class_id


func is_unlocked() -> bool:
	if unlock_id == "":
		return true
	return MetaProgress.has_unlock(unlock_id)
