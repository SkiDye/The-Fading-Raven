class_name DamageCalculator
extends Node

## 데미지 계산 시스템
## 고지대 보너스, 크리티컬, 특성 보너스 등 적용


# ===== CONFIGURATION =====

## 크리티컬 확률 (0.0 ~ 1.0)
@export var critical_chance: float = 0.1

## 크리티컬 배율
@export var critical_multiplier: float = 1.5

## 암살 배율 (바이오닉 비교전 적 공격)
@export var assassination_multiplier: float = 2.0


# ===== REFERENCES =====

var _battle_controller: Node = null


func _ready() -> void:
	_battle_controller = get_parent()


## 데미지 계산
## [param attacker]: 공격자 노드
## [param defender]: 방어자 노드
## [param base_damage]: 기본 데미지
## [param damage_type]: 데미지 타입
## [return]: 최종 데미지
func calculate_damage(
	attacker: Node,
	defender: Node,
	base_damage: int,
	damage_type: Constants.DamageType
) -> Dictionary:
	var result := {
		"damage": 0,
		"is_critical": false,
		"is_assassination": false,
		"modifiers": []
	}

	var damage := float(base_damage)

	# 고지대 보너스
	damage = _apply_elevation_bonus(attacker, defender, damage, result)

	# 암살 보너스 (바이오닉)
	damage = _apply_assassination_bonus(attacker, defender, damage, result)

	# 크리티컬
	damage = _apply_critical(damage, result)

	# 공격자 특성 보너스
	damage = _apply_attacker_traits(attacker, damage, damage_type, result)

	# 방어자 특성/방어 보너스
	damage = _apply_defender_modifiers(defender, damage, damage_type, result)

	# 엄폐 보너스
	damage = _apply_cover_bonus(defender, damage, result)

	# 최소 데미지 1 보장
	result.damage = maxi(1, int(damage))

	return result


## 간단한 데미지 계산 (결과 딕셔너리 없이)
func calculate_damage_simple(
	attacker: Node,
	defender: Node,
	base_damage: int,
	damage_type: Constants.DamageType
) -> int:
	var result := calculate_damage(attacker, defender, base_damage, damage_type)
	return result.damage


# ===== ELEVATION =====

func _apply_elevation_bonus(
	attacker: Node,
	defender: Node,
	damage: float,
	result: Dictionary
) -> float:
	if not _battle_controller or not _battle_controller.has_method("get_tile_grid"):
		return damage

	var grid = _battle_controller.get_tile_grid()
	if grid == null:
		return damage

	if not attacker.has_method("get") or not defender.has_method("get"):
		# tile_position 속성 확인
		if not "tile_position" in attacker or not "tile_position" in defender:
			return damage

	var attacker_pos: Vector2i = attacker.tile_position
	var defender_pos: Vector2i = defender.tile_position

	var bonus := _get_elevation_bonus(grid, attacker_pos, defender_pos)
	if bonus > 0:
		result.modifiers.append("elevation_+%d%%" % int(bonus * 100))
		damage *= (1.0 + bonus)

	return damage


func _get_elevation_bonus(grid: Node, attacker_pos: Vector2i, defender_pos: Vector2i) -> float:
	if not grid.has_method("get_elevation"):
		return 0.0

	var attacker_elevation: int = grid.get_elevation(attacker_pos)
	var defender_elevation: int = grid.get_elevation(defender_pos)

	if attacker_elevation > defender_elevation:
		return Constants.BALANCE.get("elevation_damage_bonus", 0.15)

	return 0.0


# ===== ASSASSINATION =====

func _apply_assassination_bonus(
	attacker: Node,
	defender: Node,
	damage: float,
	result: Dictionary
) -> float:
	# 바이오닉 클래스만 암살 보너스
	if not _is_bionic_class(attacker):
		return damage

	# 방어자가 교전 중이 아닌 경우에만
	if _is_in_combat(defender):
		return damage

	result.is_assassination = true
	result.modifiers.append("assassination_x%.1f" % assassination_multiplier)
	return damage * assassination_multiplier


func _is_bionic_class(entity: Node) -> bool:
	if not entity.has_method("get") and not "crew_data" in entity:
		return false

	var crew_data = entity.get("crew_data")
	if crew_data == null:
		return false

	var class_id: String = ""
	if crew_data is Resource and crew_data.has_method("get"):
		class_id = crew_data.get("class_id") if "class_id" in crew_data else ""
	elif crew_data is Dictionary:
		class_id = crew_data.get("class_id", "")

	return class_id == "bionic"


func _is_in_combat(entity: Node) -> bool:
	if "is_in_combat" in entity:
		return entity.is_in_combat
	if "current_target" in entity and entity.current_target != null:
		return true
	return false


# ===== CRITICAL =====

func _apply_critical(damage: float, result: Dictionary) -> float:
	if randf() < critical_chance:
		result.is_critical = true
		result.modifiers.append("critical_x%.1f" % critical_multiplier)
		return damage * critical_multiplier
	return damage


# ===== ATTACKER TRAITS =====

func _apply_attacker_traits(
	attacker: Node,
	damage: float,
	_damage_type: Constants.DamageType,
	result: Dictionary
) -> float:
	var trait_data := _get_trait_data(attacker)
	if trait_data == null:
		return damage

	var trait_id: String = trait_data.get("id", "") if trait_data is Dictionary else trait_data.id

	match trait_id:
		"sharp_edge":
			damage *= 1.2
			result.modifiers.append("sharp_edge_+20%")
		"power_surge":
			damage *= 1.15
			result.modifiers.append("power_surge_+15%")
		"berserker":
			# 체력이 낮을수록 데미지 증가
			var hp_ratio := _get_health_ratio(attacker)
			if hp_ratio < 0.5:
				var bonus := (1.0 - hp_ratio) * 0.5  # 최대 +50%
				damage *= (1.0 + bonus)
				result.modifiers.append("berserker_+%d%%" % int(bonus * 100))

	return damage


# ===== DEFENDER MODIFIERS =====

func _apply_defender_modifiers(
	defender: Node,
	damage: float,
	damage_type: Constants.DamageType,
	result: Dictionary
) -> float:
	# 방어 특성
	var trait_data := _get_trait_data(defender)
	if trait_data != null:
		var trait_id: String = trait_data.get("id", "") if trait_data is Dictionary else trait_data.id

		match trait_id:
			"reinforced_armor":
				damage *= 0.75
				result.modifiers.append("reinforced_armor_-25%")
			"energy_shield":
				if damage_type == Constants.DamageType.ENERGY:
					damage *= 0.5
					result.modifiers.append("energy_shield_-50%")
			"evasive":
				# 10% 확률로 회피
				if randf() < 0.1:
					damage = 0
					result.modifiers.append("evaded")

	# 가디언 실드 방어 (원거리 공격에 대해)
	if _has_guardian_shield(defender) and _is_ranged_damage(damage_type):
		damage *= 0.1  # 90% 감소
		result.modifiers.append("guardian_shield_-90%")

	return damage


func _has_guardian_shield(entity: Node) -> bool:
	if not "crew_data" in entity:
		return false

	var crew_data = entity.get("crew_data")
	if crew_data == null:
		return false

	var class_id: String = ""
	if crew_data is Resource:
		class_id = crew_data.class_id if "class_id" in crew_data else ""
	elif crew_data is Dictionary:
		class_id = crew_data.get("class_id", "")

	# 가디언이고 교전 중이 아닐 때만 실드 활성
	if class_id != "guardian":
		return false

	return not _is_in_combat(entity)


func _is_ranged_damage(damage_type: Constants.DamageType) -> bool:
	return damage_type == Constants.DamageType.ENERGY or damage_type == Constants.DamageType.PHYSICAL


# ===== COVER =====

func _apply_cover_bonus(defender: Node, damage: float, result: Dictionary) -> float:
	if not _battle_controller or not _battle_controller.has_method("get_tile_grid"):
		return damage

	var grid = _battle_controller.get_tile_grid()
	if grid == null:
		return damage

	if not "tile_position" in defender:
		return damage

	var tile_type := _get_tile_type(grid, defender.tile_position)

	match tile_type:
		Constants.TileType.COVER_HALF:
			damage *= (1.0 - Constants.BALANCE.get("cover_half_reduction", 0.25))
			result.modifiers.append("half_cover_-25%")
		Constants.TileType.COVER_FULL:
			damage *= (1.0 - Constants.BALANCE.get("cover_full_reduction", 0.50))
			result.modifiers.append("full_cover_-50%")

	return damage


func _get_tile_type(grid: Node, pos: Vector2i) -> int:
	if grid.has_method("get_tile_type"):
		return grid.get_tile_type(pos)
	if grid.has_method("get_tile"):
		var tile = grid.get_tile(pos)
		if tile and "type" in tile:
			return tile.type
	return Constants.TileType.FLOOR


# ===== UTILITY =====

func _get_trait_data(entity: Node) -> Variant:
	if not "crew_data" in entity:
		return null

	var crew_data = entity.get("crew_data")
	if crew_data == null:
		return null

	if crew_data is Resource:
		var trait_id: String = crew_data.trait_id if "trait_id" in crew_data else ""
		if trait_id == "":
			return null
		return Constants.get_trait(trait_id)
	elif crew_data is Dictionary:
		var trait_id: String = crew_data.get("trait_id", "")
		if trait_id == "":
			return null
		return Constants.get_trait(trait_id)

	return null


func _get_health_ratio(entity: Node) -> float:
	if entity.has_method("get_health_ratio"):
		return entity.get_health_ratio()
	if "current_hp" in entity and "max_hp" in entity:
		if entity.max_hp > 0:
			return float(entity.current_hp) / float(entity.max_hp)
	return 1.0


# ===== KNOCKBACK =====

## 넉백 강도 계산
func calculate_knockback(
	attacker: Node,
	defender: Node,
	base_knockback: float
) -> float:
	var knockback := base_knockback

	# 공격자 특성: Heavy Impact
	var attacker_trait := _get_trait_data(attacker)
	if attacker_trait:
		var trait_id: String = attacker_trait.get("id", "") if attacker_trait is Dictionary else attacker_trait.id
		if trait_id == "heavy_impact":
			knockback *= 1.5

	# 방어자 특성: Steady Stance (넉백 면역)
	var defender_trait := _get_trait_data(defender)
	if defender_trait:
		var trait_id: String = defender_trait.get("id", "") if defender_trait is Dictionary else defender_trait.id
		if trait_id == "steady_stance":
			knockback = 0.0

	return knockback
