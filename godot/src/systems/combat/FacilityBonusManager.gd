class_name FacilityBonusManager
extends Node

## 시설 보너스 관리자
## 맵의 활성 시설들로부터 보너스를 계산하고 제공


# ===== SIGNALS =====

signal bonuses_updated()


# ===== CACHED BONUSES =====

var _crew_damage_bonus: float = 0.0
var _recovery_speed_bonus: float = 0.0
var _raven_extra_charges: int = 0
var _turret_damage_bonus: float = 0.0

var _facilities: Array = []


# ===== PUBLIC API =====

## 시설 목록 설정 및 보너스 계산
func set_facilities(facilities: Array) -> void:
	_facilities = facilities
	_recalculate_bonuses()


## 시설 추가
func add_facility(facility: Node) -> void:
	if facility not in _facilities:
		_facilities.append(facility)
		_recalculate_bonuses()


## 시설 제거 (파괴 시)
func remove_facility(facility: Node) -> void:
	_facilities.erase(facility)
	_recalculate_bonuses()


## 크루 데미지 보너스 (무기고: +20%)
func get_crew_damage_bonus() -> float:
	return _crew_damage_bonus


## 회복 속도 보너스 (의료시설: -50% 시간 = +100% 속도)
func get_recovery_speed_bonus() -> float:
	return _recovery_speed_bonus


## Raven 추가 충전 횟수 (통신탑: +1)
func get_raven_extra_charges() -> int:
	return _raven_extra_charges


## 터렛 데미지 보너스 (발전소: +50%)
func get_turret_damage_bonus() -> float:
	return _turret_damage_bonus


## 특정 보너스 조회 (범용)
func get_bonus(stat_name: String) -> float:
	match stat_name:
		"crew_damage":
			return _crew_damage_bonus
		"recovery_speed":
			return _recovery_speed_bonus
		"turret_damage":
			return _turret_damage_bonus
		"raven_extra_charges":
			return float(_raven_extra_charges)
		_:
			return _get_custom_bonus(stat_name)


## 의료시설이 활성 상태인지 확인
func has_active_medical() -> bool:
	for facility in _facilities:
		if _is_facility_alive(facility) and _get_facility_type(facility) == Constants.FacilityType.MEDICAL:
			return true
	return false


## 통신탑이 활성 상태인지 확인
func has_active_comm_tower() -> bool:
	for facility in _facilities:
		if _is_facility_alive(facility) and _get_facility_type(facility) == Constants.FacilityType.COMM_TOWER:
			return true
	return false


# ===== PRIVATE =====

func _recalculate_bonuses() -> void:
	_crew_damage_bonus = 0.0
	_recovery_speed_bonus = 0.0
	_raven_extra_charges = 0
	_turret_damage_bonus = 0.0

	for facility in _facilities:
		if not _is_facility_alive(facility):
			continue

		var bonus_dict: Dictionary = _get_facility_bonus(facility)

		# 각 보너스 누적
		_crew_damage_bonus += bonus_dict.get("crew_damage", 0.0)
		_recovery_speed_bonus += bonus_dict.get("recovery_speed", 0.0)
		_raven_extra_charges += int(bonus_dict.get("raven_extra_charges", 0))
		_turret_damage_bonus += bonus_dict.get("turret_damage", 0.0)

	bonuses_updated.emit()


func _get_custom_bonus(stat_name: String) -> float:
	var total: float = 0.0
	for facility in _facilities:
		if not _is_facility_alive(facility):
			continue
		var bonus_dict: Dictionary = _get_facility_bonus(facility)
		total += bonus_dict.get(stat_name, 0.0)
	return total


func _is_facility_alive(facility: Variant) -> bool:
	if facility is Node:
		if "is_destroyed" in facility:
			return not facility.is_destroyed
		if "is_alive" in facility:
			return facility.is_alive
		return is_instance_valid(facility)
	elif facility is Dictionary:
		return facility.get("is_alive", true)
	return false


func _get_facility_type(facility: Variant) -> int:
	if facility is Node and "facility_data" in facility:
		var data: Resource = facility.facility_data
		if data and "facility_type" in data:
			return data.facility_type
	elif facility is Dictionary:
		return facility.get("facility_type", 0)
	return 0


func _get_facility_bonus(facility: Variant) -> Dictionary:
	if facility is Node:
		if facility.has_method("get_passive_bonus"):
			# FacilityData의 모든 보너스 반환
			if "facility_data" in facility and facility.facility_data:
				return facility.facility_data.passive_bonus
		if "facility_data" in facility and facility.facility_data:
			var data: Resource = facility.facility_data
			if "passive_bonus" in data:
				return data.passive_bonus
	elif facility is Dictionary:
		var data = facility.get("data")
		if data is Resource and "passive_bonus" in data:
			return data.passive_bonus
		elif data is Dictionary:
			return data.get("passive_bonus", {})
	return {}
