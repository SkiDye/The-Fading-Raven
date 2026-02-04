class_name SkillData
extends Resource

## 크루 스킬 정의
## 각 클래스는 하나의 고유 스킬을 가짐


enum SkillType {
	DIRECTION,  ## 방향 지정 (Shield Bash, Lance Charge)
	POSITION,   ## 위치 지정 (Volley Fire, Deploy Turret, Blink)
	SELF        ## 자기 자신 (버프 등)
}


@export var id: String = ""
@export var display_name: String = ""
@export var display_name_ko: String = ""

@export var skill_type: SkillType = SkillType.DIRECTION
@export var base_cooldown: float = 20.0

## 레벨별 효과 (인덱스 0 = 레벨 1)
@export var levels: Array[SkillLevelData] = []

## 아이콘 (선택)
@export var icon: Texture2D = null


## 해당 레벨의 효과 데이터 반환
func get_level_data(level: int) -> SkillLevelData:
	var idx := clampi(level - 1, 0, levels.size() - 1)
	if idx < levels.size():
		return levels[idx]
	return null


## 최대 레벨
func get_max_level() -> int:
	return levels.size()


## 해당 레벨의 쿨다운 반환 (레벨에 따른 감소 없음, 기본값)
func get_cooldown(_level: int) -> float:
	return base_cooldown
