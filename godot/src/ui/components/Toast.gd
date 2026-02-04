class_name Toast
extends PanelContainer

## 토스트 알림 메시지 컴포넌트
## 일정 시간 후 자동으로 사라짐


@onready var _icon: TextureRect = $MarginContainer/HBoxContainer/Icon
@onready var _message_label: Label = $MarginContainer/HBoxContainer/MessageLabel

const COLORS: Dictionary = {
	Constants.ToastType.INFO: Color(1.0, 1.0, 1.0),
	Constants.ToastType.SUCCESS: Color(0.4, 0.9, 0.4),
	Constants.ToastType.WARNING: Color(1.0, 0.85, 0.3),
	Constants.ToastType.ERROR: Color(1.0, 0.4, 0.4)
}

const ICONS: Dictionary = {
	Constants.ToastType.INFO: "ℹ️",
	Constants.ToastType.SUCCESS: "✓",
	Constants.ToastType.WARNING: "⚠",
	Constants.ToastType.ERROR: "✗"
}

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0


## 토스트 메시지 표시
## [param message]: 표시할 메시지
## [param toast_type]: 토스트 타입 (Constants.ToastType)
## [param duration]: 표시 시간 (초)
func show_message(message: String, toast_type: int, duration: float = 3.0) -> void:
	# 메시지 설정
	if _message_label:
		_message_label.text = message
		_message_label.modulate = COLORS.get(toast_type, Color.WHITE)

	# 아이콘 설정 (텍스트로 대체)
	# 실제 프로젝트에서는 텍스처 사용

	# 페이드 인
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	# 대기
	await get_tree().create_timer(duration).timeout

	# 페이드 아웃
	if is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await _tween.finished
		queue_free()


## 즉시 숨기기
func hide_immediately() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	queue_free()
