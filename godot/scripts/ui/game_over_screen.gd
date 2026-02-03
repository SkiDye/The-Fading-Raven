## GameOverScreen - 게임 오버 화면 UI
extends Control

@onready var turns_label: Label = $CenterContainer/VBoxContainer/StatsContainer/TurnsLabel
@onready var stations_label: Label = $CenterContainer/VBoxContainer/StatsContainer/StationsLabel
@onready var enemies_label: Label = $CenterContainer/VBoxContainer/StatsContainer/EnemiesLabel
@onready var score_label: Label = $CenterContainer/VBoxContainer/StatsContainer/ScoreLabel
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	_display_stats()


func _display_stats() -> void:
	var run := GameState.get_current_run()
	if run == null:
		return

	turns_label.text = "Turns Survived: %d" % run.turn
	stations_label.text = "Stations Defended: %d" % run.stats.get("stations_defended", 0)
	enemies_label.text = "Enemies Killed: %d" % run.stats.get("enemies_killed", 0)
	score_label.text = "Final Score: %d" % GameState.calculate_score()


func _on_retry_pressed() -> void:
	GameState.clear_run()
	var seed_string := RngManager.generate_seed_string()
	GameState.start_new_run(seed_string, Balance.Difficulty.NORMAL)
	SceneManager.go_to_sector_map()


func _on_main_menu_pressed() -> void:
	GameState.clear_run()
	SceneManager.go_to_main_menu()
