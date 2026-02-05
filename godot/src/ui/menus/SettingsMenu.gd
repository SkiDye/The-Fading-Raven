class_name SettingsMenu
extends Control

## 설정 메뉴
## 볼륨, 화면, 언어, 접근성 설정


@onready var _title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var _audio_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AudioLabel
@onready var _master_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MasterVolume/Label
@onready var _master_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MasterVolume/MasterSlider
@onready var _bgm_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BGMVolume/Label
@onready var _bgm_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BGMVolume/BGMSlider
@onready var _sfx_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SFXVolume/Label
@onready var _sfx_slider: HSlider = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SFXVolume/SFXSlider
@onready var _display_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DisplayLabel
@onready var _fullscreen_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Fullscreen/Label
@onready var _fullscreen_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Fullscreen/FullscreenCheck
@onready var _language_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Language/Label
@onready var _language_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Language/LanguageBtn
@onready var _accessibility_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AccessibilityLabel
@onready var _screen_shake_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScreenShake/Label
@onready var _screen_shake_check: CheckButton = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScreenShake/ScreenShakeCheck
@onready var _back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackBtn

var _previous_scene: String = ""


func _ready() -> void:
	_load_settings()
	_setup_signals()
	_update_localized_text()

	# 언어 변경 시 UI 업데이트
	if Localization:
		Localization.locale_changed.connect(_on_locale_changed)


func _setup_signals() -> void:
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_volume_changed)

	if _bgm_slider:
		_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	if _language_btn:
		_language_btn.pressed.connect(_on_language_pressed)

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

	# 언어 버튼 텍스트 업데이트
	_update_language_button()


func _save_settings() -> void:
	# 설정 저장은 각 핸들러에서 즉시 처리
	pass


func _update_localized_text() -> void:
	## 모든 UI 텍스트를 현재 로케일로 업데이트
	if not Localization:
		return

	if _title_label:
		_title_label.text = Localization.get_text("settings.title").to_upper()

	if _audio_label:
		_audio_label.text = "Audio"  # 섹션 레이블은 영어 유지 (디자인 선택)

	if _master_label:
		_master_label.text = Localization.get_text("settings.music_volume").replace("Music", "Master")

	if _bgm_label:
		_bgm_label.text = Localization.get_text("settings.music_volume")

	if _sfx_label:
		_sfx_label.text = Localization.get_text("settings.sfx_volume")

	if _display_label:
		_display_label.text = "Display"

	if _fullscreen_label:
		_fullscreen_label.text = Localization.get_text("settings.fullscreen")

	if _language_label:
		_language_label.text = Localization.get_text("settings.language")

	if _accessibility_label:
		_accessibility_label.text = "Accessibility"

	if _screen_shake_label:
		_screen_shake_label.text = "Screen Shake"

	if _back_btn:
		_back_btn.text = Localization.get_text("common.back").to_upper()

	_update_language_button()


func _update_language_button() -> void:
	if _language_btn == null or not Localization:
		return
	var current_locale: String = Localization.get_locale()
	_language_btn.text = Localization.get_locale_display_name(current_locale)


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


func _on_language_pressed() -> void:
	# 다음 언어로 순환
	if Localization:
		Localization.cycle_locale()


func _on_locale_changed(_new_locale: String) -> void:
	_update_localized_text()


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
