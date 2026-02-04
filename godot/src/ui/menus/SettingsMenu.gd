class_name SettingsMenu
extends Control

## 설정 메뉴
## 볼륨, 화면, 접근성 설정


@onready var _master_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MasterVolume/MasterSlider
@onready var _bgm_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BGMVolume/BGMSlider
@onready var _sfx_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SFXVolume/SFXSlider
@onready var _fullscreen_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Fullscreen/FullscreenCheck
@onready var _screen_shake_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScreenShake/ScreenShakeCheck
@onready var _back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackBtn

var _previous_scene: String = ""


func _ready() -> void:
	_load_settings()
	_setup_signals()


func _setup_signals() -> void:
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_volume_changed)

	if _bgm_slider:
		_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	if _screen_shake_check:
		_screen_shake_check.toggled.connect(_on_screen_shake_toggled)

	if _back_btn:
		_back_btn.pressed.connect(_on_back_pressed)


func _load_settings() -> void:
	# AudioManager에서 볼륨 로드
	if AudioManager:
		if _master_slider and "master_volume" in AudioManager:
			_master_slider.value = AudioManager.master_volume * 100

		if _bgm_slider and "bgm_volume" in AudioManager:
			_bgm_slider.value = AudioManager.bgm_volume * 100

		if _sfx_slider and "sfx_volume" in AudioManager:
			_sfx_slider.value = AudioManager.sfx_volume * 100

	# 화면 설정
	if _fullscreen_check:
		var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_fullscreen_check.button_pressed = is_fullscreen

	# 스크린 셰이크 설정 (GameState에서 로드)
	if _screen_shake_check:
		var shake_enabled := true
		if GameState and "settings" in GameState and "screen_shake" in GameState.settings:
			shake_enabled = GameState.settings.screen_shake
		_screen_shake_check.button_pressed = shake_enabled


func _save_settings() -> void:
	# 설정 저장은 각 핸들러에서 즉시 처리
	pass


## 이전 씬 설정 (뒤로가기 용)
func set_previous_scene(scene_path: String) -> void:
	_previous_scene = scene_path


# ===== SIGNAL HANDLERS =====

func _on_master_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_master_volume"):
		AudioManager.set_master_volume(value / 100.0)


func _on_bgm_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_bgm_volume"):
		AudioManager.set_bgm_volume(value / 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_sfx_volume"):
		AudioManager.set_sfx_volume(value / 100.0)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_screen_shake_toggled(enabled: bool) -> void:
	if GameState:
		if not "settings" in GameState:
			GameState.settings = {}
		GameState.settings.screen_shake = enabled


func _on_back_pressed() -> void:
	if _previous_scene.is_empty():
		# 기본: 메인 메뉴로
		var main_menu := "res://src/ui/menus/MainMenu.tscn"
		if ResourceLoader.exists(main_menu):
			get_tree().change_scene_to_file(main_menu)
		else:
			# scenes 폴더 체크
			var alt_path := "res://scenes/ui/MainMenu.tscn"
			if ResourceLoader.exists(alt_path):
				get_tree().change_scene_to_file(alt_path)
	else:
		get_tree().change_scene_to_file(_previous_scene)
