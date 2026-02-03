## SettingsScreen - 설정 화면 UI
extends Control

@onready var sound_slider: HSlider = $CenterContainer/VBoxContainer/SoundVolume/Slider
@onready var sound_value: Label = $CenterContainer/VBoxContainer/SoundVolume/Value
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicVolume/Slider
@onready var music_value: Label = $CenterContainer/VBoxContainer/MusicVolume/Value
@onready var screen_shake_check: CheckBox = $CenterContainer/VBoxContainer/ScreenShake/CheckBox
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	# 현재 설정 로드
	sound_slider.value = GameState.settings.get("sound_volume", 70)
	music_slider.value = GameState.settings.get("music_volume", 50)
	screen_shake_check.button_pressed = GameState.settings.get("screen_shake", true)

	_update_labels()

	# 시그널 연결
	sound_slider.value_changed.connect(_on_sound_changed)
	music_slider.value_changed.connect(_on_music_changed)
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _update_labels() -> void:
	sound_value.text = str(int(sound_slider.value))
	music_value.text = str(int(music_slider.value))


func _on_sound_changed(value: float) -> void:
	GameState.settings["sound_volume"] = int(value)
	sound_value.text = str(int(value))
	# TODO: 실제 오디오 볼륨 적용


func _on_music_changed(value: float) -> void:
	GameState.settings["music_volume"] = int(value)
	music_value.text = str(int(value))
	# TODO: 실제 오디오 볼륨 적용


func _on_screen_shake_toggled(pressed: bool) -> void:
	GameState.settings["screen_shake"] = pressed


func _on_back_pressed() -> void:
	GameState.save_settings()
	SceneManager.go_to_main_menu()
