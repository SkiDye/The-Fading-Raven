class_name CrewRuntimeData
extends Resource

## 크루 런타임 상태 데이터
## 세이브/로드 대상, S03에서 상세 구현


@export var id: String
@export var class_id: String  # CrewClassData.id 참조
@export var custom_name: String = ""

@export_group("Progression")
@export var rank: int = 0
@export var skill_level: int = 0
@export var experience: int = 0

@export_group("Equipment")
@export var equipment_id: String = ""
@export var equipment_level: int = 0

@export_group("Traits")
@export var trait_id: String = ""

@export_group("Status")
@export var current_hp_ratio: float = 1.0
@export var is_alive: bool = true
@export var is_deployed: bool = false


func get_class_data() -> CrewClassData:
	return Constants.get_crew_class(class_id) as CrewClassData


func get_display_name() -> String:
	if custom_name != "":
		return custom_name
	var class_data := get_class_data()
	if class_data:
		return class_data.display_name
	return "Unknown"


func get_max_hp() -> int:
	var class_data := get_class_data()
	if not class_data:
		return 10
	return int(class_data.get_stat_at_rank("hp", rank))


func get_current_hp() -> int:
	return int(get_max_hp() * current_hp_ratio)


func heal(amount: int) -> void:
	var max_hp := get_max_hp()
	var current := get_current_hp()
	var new_hp := mini(current + amount, max_hp)
	current_hp_ratio = float(new_hp) / float(max_hp)


func take_damage(amount: int) -> void:
	var max_hp := get_max_hp()
	var current := get_current_hp()
	var new_hp := maxi(current - amount, 0)
	current_hp_ratio = float(new_hp) / float(max_hp)
	if new_hp <= 0:
		is_alive = false


func duplicate_runtime() -> CrewRuntimeData:
	var copy := CrewRuntimeData.new()
	copy.id = id
	copy.class_id = class_id
	copy.custom_name = custom_name
	copy.rank = rank
	copy.skill_level = skill_level
	copy.experience = experience
	copy.equipment_id = equipment_id
	copy.equipment_level = equipment_level
	copy.trait_id = trait_id
	copy.current_hp_ratio = current_hp_ratio
	copy.is_alive = is_alive
	copy.is_deployed = is_deployed
	return copy
