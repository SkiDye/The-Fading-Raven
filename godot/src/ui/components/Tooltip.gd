class_name Tooltip
extends PanelContainer

## 마우스 오버 시 정보를 표시하는 툴팁 컴포넌트
## EventBus.show_tooltip / hide_tooltip 시그널에 반응


@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _content_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentLabel

var follow_mouse: bool = true
var offset: Vector2 = Vector2(16, 16)

var _is_showing: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# EventBus 연결
	if EventBus:
		EventBus.show_tooltip.connect(_on_show_tooltip)
		EventBus.hide_tooltip.connect(_on_hide_tooltip)


func _process(_delta: float) -> void:
	if _is_showing and follow_mouse:
		_update_position()


func _exit_tree() -> void:
	if EventBus:
		if EventBus.show_tooltip.is_connected(_on_show_tooltip):
			EventBus.show_tooltip.disconnect(_on_show_tooltip)
		if EventBus.hide_tooltip.is_connected(_on_hide_tooltip):
			EventBus.hide_tooltip.disconnect(_on_hide_tooltip)


## 툴팁 표시
## [param title]: 제목 (빈 문자열이면 숨김)
## [param content]: 본문 내용
## [param pos]: 고정 위치 (Vector2.ZERO면 마우스 따라다님)
func show_tooltip(title: String, content: String, pos: Vector2 = Vector2.ZERO) -> void:
	# 제목 설정
	if _title_label:
		_title_label.text = title
		_title_label.visible = not title.is_empty()

	# 내용 설정
	if _content_label:
		_content_label.text = content

	# 위치 설정
	if pos != Vector2.ZERO:
		global_position = pos + offset
		follow_mouse = false
	else:
		follow_mouse = true
		_update_position()

	visible = true
	_is_showing = true


## 툴팁 숨기기
func hide_tooltip() -> void:
	visible = false
	_is_showing = false


## 마우스 위치에 맞춰 툴팁 위치 업데이트
func _update_position() -> void:
	var mouse_pos := get_global_mouse_position()
	var screen_size := get_viewport_rect().size

	var new_pos := mouse_pos + offset

	# 화면 오른쪽 경계 체크
	if new_pos.x + size.x > screen_size.x:
		new_pos.x = mouse_pos.x - size.x - offset.x

	# 화면 아래쪽 경계 체크
	if new_pos.y + size.y > screen_size.y:
		new_pos.y = mouse_pos.y - size.y - offset.y

	# 화면 왼쪽/위쪽 경계 체크
	new_pos.x = maxf(0, new_pos.x)
	new_pos.y = maxf(0, new_pos.y)

	global_position = new_pos


# ===== SIGNAL HANDLERS =====

func _on_show_tooltip(content: String, pos: Vector2) -> void:
	show_tooltip("", content, pos)


func _on_hide_tooltip() -> void:
	hide_tooltip()
