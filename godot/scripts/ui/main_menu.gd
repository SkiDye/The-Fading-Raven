## MainMenu - 메인 메뉴 UI
extends Control

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# 이어하기 버튼 활성화 여부
	continue_button.disabled = not GameState.has_active_run()


func _on_new_game_pressed() -> void:
	# TODO: 난이도/시드 선택 화면으로 이동
	var seed_string := RngManager.generate_seed_string()
	GameState.start_new_run(seed_string, Balance.Difficulty.NORMAL)
	SceneManager.go_to_sector_map()


func _on_continue_pressed() -> void:
	GameState.load_run()
	if GameState.has_active_run():
		SceneManager.go_to_sector_map()


func _on_settings_pressed() -> void:
	SceneManager.go_to_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
