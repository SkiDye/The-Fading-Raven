class_name TraitData
extends Resource

## 특성 정적 데이터
## S02에서 리소스 파일(.tres) 생성 예정


@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String

@export_group("Classification")
@export var is_positive: bool = true
@export var rarity: int = 1  # 1=common, 2=uncommon, 3=rare

@export_group("Requirements")
@export var required_class: String = ""  # 빈 문자열이면 모든 클래스 가능
@export var incompatible_traits: Array[String] = []

@export_group("Effects")
@export var stat_modifiers: Dictionary = {}  # {"hp": 0.1, "damage": -0.05}
@export var special_effects: Array[String] = []  # ["immune_poison", "double_heal"]

@export_group("Visual")
@export var icon: Texture2D
@export var color: Color = Color.WHITE


func get_stat_modifier(stat_name: String) -> float:
	return stat_modifiers.get(stat_name, 0.0)


func has_special_effect(effect_id: String) -> bool:
	return effect_id in special_effects


func is_compatible_with(other_trait_id: String) -> bool:
	return not (other_trait_id in incompatible_traits)


func is_usable_by_class(class_id: String) -> bool:
	if required_class == "":
		return true
	return required_class == class_id
