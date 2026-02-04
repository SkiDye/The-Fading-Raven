class_name PauseMenu
extends Control

## 일시정지 메뉴
## 게임 중 ESC로 표시


signal resume_requested()
signal settings_requested()
signal main_menu_requested()
signal quit_requested()

@onready var _resume_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeBtn
@onready var _settings_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsBtn
@onready var _main_menu_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuBtn
@onready var _quit_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitBtn


func _ready() -> void:
	visible = false
	_setup_buttons()


func _setup_buttons() -> void:
	if _resume_btn:
		_resume_btn.pressed.connect(_on_resume_pressed)

	if _settings_btn:
		_settings_btn.pressed.connect(_on_settings_pressed)

	if _main_menu_btn:
		_main_menu_btn.pressed.connect(_on_main_menu_pressed)

	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()


## 메뉴 표시
func show_menu() -> void:
	visible = true
	get_tree().paused = true

	if EventBus:
		EventBus.game_paused.emit()

	# 첫 버튼에 포커스
	if _resume_btn:
		_resume_btn.grab_focus()


## 메뉴 숨기기
func hide_menu() -> void:
	visible = false
	get_tree().paused = false

	if EventBus:
		EventBus.game_resumed.emit()


## 일시정지 상태 토글
func toggle_pause() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()


# ===== SIGNAL HANDLERS =====

func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()

	# 설정 메뉴 표시 (오버레이 방식)
	var settings_scene := "res://src/ui/menus/SettingsMenu.tscn"
	if ResourceLoader.exists(settings_scene):
		var settings: PackedScene = load(settings_scene)
		var settings_instance: Control = settings.instantiate()
		get_parent().add_child(settings_instance)

		# 설정 메뉴에 이전 씬 설정
		if settings_instance.has_method("set_previous_scene"):
			settings_instance.set_previous_scene("")


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

	# 일시정지 해제
	get_tree().paused = false

	# 메인 메뉴로 이동
	var main_menu := "res://src/ui/menus/MainMenu.tscn"
	if ResourceLoader.exists(main_menu):
		get_tree().change_scene_to_file(main_menu)
	else:
		var alt_path := "res://scenes/ui/MainMenu.tscn"
		if ResourceLoader.exists(alt_path):
			get_tree().change_scene_to_file(alt_path)


func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()
