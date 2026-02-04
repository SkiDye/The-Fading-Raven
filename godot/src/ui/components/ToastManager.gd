class_name ToastManager
extends VBoxContainer

## 토스트 알림을 관리하는 컨테이너
## EventBus.show_toast 시그널에 반응하여 토스트 생성


const TOAST_SCENE_PATH: String = "res://src/ui/components/Toast.tscn"
const MAX_TOASTS: int = 5

var _toast_scene: PackedScene


func _ready() -> void:
	# 토스트 씬 로드
	if ResourceLoader.exists(TOAST_SCENE_PATH):
		_toast_scene = load(TOAST_SCENE_PATH)
	else:
		push_warning("ToastManager: Toast scene not found at %s" % TOAST_SCENE_PATH)

	# EventBus 연결
	if EventBus:
		EventBus.show_toast.connect(_on_show_toast)


func _exit_tree() -> void:
	if EventBus and EventBus.show_toast.is_connected(_on_show_toast):
		EventBus.show_toast.disconnect(_on_show_toast)


## 토스트 표시
## [param message]: 표시할 메시지
## [param toast_type]: 토스트 타입 (Constants.ToastType)
## [param duration]: 표시 시간 (초)
func show_toast(message: String, toast_type: int = Constants.ToastType.INFO, duration: float = 3.0) -> void:
	if _toast_scene == null:
		push_warning("ToastManager: Cannot show toast - scene not loaded")
		return

	# 최대 개수 제한
	while get_child_count() >= MAX_TOASTS:
		var oldest := get_child(0)
		if oldest is Toast:
			oldest.hide_immediately()
		else:
			oldest.queue_free()

	# 새 토스트 생성
	var toast: Toast = _toast_scene.instantiate()
	add_child(toast)
	toast.show_message(message, toast_type, duration)


## 모든 토스트 제거
func clear_all() -> void:
	for child in get_children():
		if child is Toast:
			child.hide_immediately()
		else:
			child.queue_free()


# ===== SIGNAL HANDLERS =====

func _on_show_toast(message: String, toast_type: int, duration: float) -> void:
	show_toast(message, toast_type, duration)
