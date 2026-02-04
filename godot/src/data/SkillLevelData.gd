class_name SkillLevelData
extends Resource

## 스킬 레벨별 효과 정의
## 각 스킬은 최대 3레벨까지 업그레이드 가능


@export var level: int = 1

## 효과 수치들
@export var damage_multiplier: float = 1.0
@export var range_tiles: float = 3.0
@export var radius_tiles: float = 0.0
@export var knockback_force: float = 0.0
@export var stun_duration: float = 0.0
@export var duration: float = 0.0

## 특수 효과 (스킬별 고유)
@export var special_effects: Dictionary = {}

## 업그레이드 비용 (이 레벨로 올리는 비용)
@export var upgrade_cost: int = 0

## 레벨별 설명
@export_multiline var description: String = ""
@export_multiline var description_ko: String = ""
