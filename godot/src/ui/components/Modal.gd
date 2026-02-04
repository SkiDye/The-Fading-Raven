class_name Modal
extends Control

## 모달 대화상자 컴포넌트
## 확인/취소 등의 사용자 입력을 받음


signal closed(result: String)

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $CenterContainer/Panel
@onready var _title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var _content_label: RichTextLabel = $CenterContainer/Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var _buttons_container: HBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonsContainer

var result: String = ""
var close_on_overlay_click: bool = true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	if _overlay:
		_overlay.gui_input.connect(_on_overlay_input)


## 모달 표시
## [param title]: 제목
## [param content]: 본문 내용
## [param buttons]: 버튼 텍스트 배열 (기본: ["OK"])
func show_modal(title: String, content: String, buttons: Array = ["OK"]) -> void:
	# 제목 설정
	if _title_label:
		_title_label.text = title
		_title_label.visible = not title.is_empty()

	# 내용 설정
	if _content_label:
		_content_label.text = content

	# 기존 버튼 제거
	if _buttons_container:
		for child in _buttons_container.get_children():
			child.queue_free()

		# 버튼 생성
		for i in range(buttons.size()):
			var button_text: String = buttons[i]
			var btn := Button.new()
			btn.text = button_text
			btn.custom_minimum_size = Vector2(80, 32)
			btn.pressed.connect(_on_button_pressed.bind(button_text))

			# 첫 번째 버튼에 포커스
			if i == 0:
				btn.call_deferred("grab_focus")

			_buttons_container.add_child(btn)

	visible = true
	result = ""


## 모달 숨기기
func hide_modal() -> void:
	visible = false


## 확인 대화상자
func show_confirm(message: String, on_confirm: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
	show_modal("확인", message, ["확인", "취소"])

	# 결과 대기
	var res: String = await closed
	if res == "확인" and on_confirm.is_valid():
		on_confirm.call()
	elif res == "취소" and on_cancel.is_valid():
		on_cancel.call()


## 알림 대화상자
func show_alert(message: String, on_close: Callable = Callable()) -> void:
	show_modal("알림", message, ["확인"])

	await closed
	if on_close.is_valid():
		on_close.call()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_button_pressed("Cancel")
		get_viewport().set_input_as_handled()


# ===== SIGNAL HANDLERS =====

func _on_button_pressed(button_text: String) -> void:
	result = button_text
	closed.emit(result)

	if EventBus:
		EventBus.modal_closed.emit(result)

	hide_modal()


func _on_overlay_input(event: InputEvent) -> void:
	if close_on_overlay_click and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_button_pressed("Cancel")
