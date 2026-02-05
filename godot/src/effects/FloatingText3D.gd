class_name FloatingText3D
extends Node3D

## 3D 플로팅 텍스트
## 데미지 숫자, 힐 등 표시용 빌보드 Label3D


# ===== SIGNALS =====

signal finished()


# ===== EXPORTS =====

@export var auto_destroy: bool = true
@export var lifetime: float = 1.0
@export var rise_speed: float = 2.0
@export var fade_start: float = 0.5  # 페이드 시작 시점 (lifetime 비율)


# ===== STATE =====

var _elapsed: float = 0.0
var _initial_y: float = 0.0


# ===== CHILD NODES =====

@onready var label: Label3D = $Label3D


# ===== LIFECYCLE =====

func _ready() -> void:
	_initial_y = position.y


func _process(delta: float) -> void:
	_elapsed += delta

	# 위로 상승
	position.y = _initial_y + _elapsed * rise_speed

	# 페이드 아웃
	var progress: float = _elapsed / lifetime
	if progress > fade_start and label:
		var fade_progress: float = (progress - fade_start) / (1.0 - fade_start)
		label.modulate.a = 1.0 - fade_progress

	# 자동 제거
	if auto_destroy and _elapsed >= lifetime:
		finished.emit()
		queue_free()


# ===== PUBLIC API =====

## 데미지 텍스트 설정
func set_damage(amount: int, is_critical: bool = false) -> void:
	if label == null:
		return

	label.text = str(amount)

	if is_critical:
		label.text = str(amount) + "!"
		label.font_size = 48
		label.modulate = Color(1.0, 0.8, 0.2)  # 황금색
		label.outline_modulate = Color(0.8, 0.4, 0.0)
	else:
		label.font_size = 32
		label.modulate = Color(1.0, 0.3, 0.2)  # 빨간색
		label.outline_modulate = Color(0.4, 0.1, 0.1)


## 힐 텍스트 설정
func set_heal(amount: int) -> void:
	if label == null:
		return

	label.text = "+" + str(amount)
	label.font_size = 32
	label.modulate = Color(0.2, 1.0, 0.3)  # 초록색
	label.outline_modulate = Color(0.1, 0.4, 0.1)


## 상태 텍스트 설정
func set_status(text: String, color: Color = Color.WHITE) -> void:
	if label == null:
		return

	label.text = text
	label.font_size = 28
	label.modulate = color
	label.outline_modulate = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3)


## 커스텀 텍스트 설정
func set_text(text: String, size: int = 32, color: Color = Color.WHITE) -> void:
	if label == null:
		return

	label.text = text
	label.font_size = size
	label.modulate = color


## 크레딧 획득 텍스트
func set_credits(amount: int) -> void:
	if label == null:
		return

	label.text = "+%d" % amount
	label.font_size = 36
	label.modulate = Color(1.0, 0.85, 0.2)  # 골드
	label.outline_modulate = Color(0.5, 0.4, 0.1)
