class_name GridTileData
extends RefCounted

## 개별 타일의 데이터를 저장하는 클래스
## [br][br]
## 타일의 위치, 타입, 고도, 시설, 점유자 등의 정보를 관리합니다.

# Preload to avoid autoload resolution issues
const ConstantsScript = preload("res://src/autoload/Constants.gd")


# ===== PROPERTIES =====

var position: Vector2i
var type: int  # ConstantsScript.TileType value
var elevation: int = 0  ## 0 = 평지, 1 = 고지대, -1 = 저지대
var facility: Node = null  ## 시설 참조 (있을 경우)
var occupant: Node = null  ## 점유 엔티티 (있을 경우)
var is_entry_point: bool = false
var metadata: Dictionary = {}


# ===== INITIALIZATION =====

func _init(pos: Vector2i = Vector2i.ZERO, tile_type: int = ConstantsScript.TileType.FLOOR) -> void:
	position = pos
	type = tile_type
	elevation = 0


# ===== WALKABILITY =====

## 이 타일이 이동 가능한지 확인합니다.
## [br][br]
## [return]: 이동 가능 여부
func is_walkable() -> bool:
	match type:
		ConstantsScript.TileType.FLOOR, \
		ConstantsScript.TileType.AIRLOCK, \
		ConstantsScript.TileType.ELEVATED, \
		ConstantsScript.TileType.LOWERED, \
		ConstantsScript.TileType.FACILITY, \
		ConstantsScript.TileType.COVER_HALF, \
		ConstantsScript.TileType.COVER_FULL:
			return true
		_:
			return false


## 이 타일이 시야를 차단하는지 확인합니다.
## [br][br]
## [return]: 시야 차단 여부
func is_blocking_los() -> bool:
	match type:
		ConstantsScript.TileType.WALL, ConstantsScript.TileType.COVER_FULL:
			return true
		_:
			return false


## 이 타일이 부분적으로 시야를 차단하는지 확인합니다.
## [br][br]
## [return]: 부분 시야 차단 여부
func is_partial_cover() -> bool:
	return type == ConstantsScript.TileType.COVER_HALF


# ===== MOVEMENT COST =====

## 이 타일의 이동 비용을 반환합니다.
## [br][br]
## [return]: 이동 비용 (기본 1.0)
func get_movement_cost() -> float:
	match type:
		ConstantsScript.TileType.ELEVATED:
			return 1.5  # 고지대 이동 비용 증가
		ConstantsScript.TileType.LOWERED:
			return 0.8  # 저지대 이동 비용 감소
		_:
			return 1.0


# ===== COVER =====

## 이 타일의 엄폐 피해 감소율을 반환합니다.
## [br][br]
## [return]: 피해 감소율 (0.0 ~ 1.0)
func get_cover_reduction() -> float:
	match type:
		ConstantsScript.TileType.COVER_HALF:
			return 0.25  # Default cover_half_reduction
		ConstantsScript.TileType.COVER_FULL:
			return 0.50  # Default cover_full_reduction
		_:
			return 0.0


# ===== UTILITY =====

## 이 타일이 점유되어 있는지 확인합니다.
## [br][br]
## [return]: 점유 여부
func is_occupied() -> bool:
	return occupant != null


## 이 타일에 시설이 있는지 확인합니다.
## [br][br]
## [return]: 시설 존재 여부
func has_facility() -> bool:
	return facility != null


## 디버그용 문자열 반환
func _to_string() -> String:
	return "TileData(%s, %s, elev=%d)" % [position, ConstantsScript.TileType.keys()[type], elevation]
