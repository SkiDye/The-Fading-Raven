## VictoryScreen - 승리 화면 UI
extends Control

@onready var difficulty_label: Label = $CenterContainer/VBoxContainer/StatsContainer/DifficultyLabel
@onready var time_label: Label = $CenterContainer/VBoxContainer/StatsContainer/TimeLabel
@onready var stations_label: Label = $CenterContainer/VBoxContainer/StatsContainer/StationsLabel
@onready var perfect_label: Label = $CenterContainer/VBoxContainer/StatsContainer/PerfectLabel
@onready var enemies_label: Label = $CenterContainer/VBoxContainer/StatsContainer/EnemiesLabel
@onready var crews_lost_label: Label = $CenterContainer/VBoxContainer/StatsContainer/CrewsLostLabel
@onready var score_label: Label = $CenterContainer/VBoxContainer/StatsContainer/ScoreLabel
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	_display_stats()


func _display_stats() -> void:
	var run := GameState.get_current_run()
	if run == null:
		return

	# 난이도 이름
	var difficulty_names := ["Normal", "Hard", "Very Hard", "Nightmare"]
	var diff_idx: int = run.difficulty
	difficulty_label.text = "Difficulty: %s" % difficulty_names[diff_idx]

	# 플레이 시간
	time_label.text = "Time: %s" % run.get_run_duration_formatted()

	# 통계
	stations_label.text = "Stations Defended: %d" % run.stats.get("stations_defended", 0)
	perfect_label.text = "Perfect Defenses: %d" % run.stats.get("perfect_defenses", 0)
	enemies_label.text = "Enemies Killed: %d" % run.stats.get("enemies_killed", 0)
	crews_lost_label.text = "Crews Lost: %d" % run.stats.get("crews_lost", 0)

	# 최종 점수
	score_label.text = "Final Score: %d" % GameState.calculate_score()


func _on_continue_pressed() -> void:
	GameState.clear_run()
	var seed_string := RngManager.generate_seed_string()
	# 다음 난이도로 도전
	var next_difficulty: int = mini(
		GameState.get_current_run().difficulty + 1 if GameState.get_current_run() else 0,
		Balance.Difficulty.NIGHTMARE
	)
	GameState.start_new_run(seed_string, next_difficulty)
	SceneManager.go_to_sector_map()


func _on_main_menu_pressed() -> void:
	GameState.clear_run()
	SceneManager.go_to_main_menu()
