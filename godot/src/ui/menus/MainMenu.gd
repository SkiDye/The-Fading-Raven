class_name MainMenu
extends Control

## 메인 메뉴 화면
## 새 게임, 계속하기, 설정, 종료


@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _new_game_btn: Button = $VBoxContainer/ButtonsContainer/NewGameBtn
@onready var _continue_btn: Button = $VBoxContainer/ButtonsContainer/ContinueBtn
@onready var _settings_btn: Button = $VBoxContainer/ButtonsContainer/SettingsBtn
@onready var _credits_btn: Button = $VBoxContainer/ButtonsContainer/CreditsBtn
@onready var _quit_btn: Button = $VBoxContainer/ButtonsContainer/QuitBtn
@onready var _version_label: Label = $VersionLabel


func _ready() -> void:
	_setup_buttons()
	_update_continue_button()
	_set_version()


func _setup_buttons() -> void:
	if _new_game_btn:
		_new_game_btn.pressed.connect(_on_new_game_pressed)

	if _continue_btn:
		_continue_btn.pressed.connect(_on_continue_pressed)

	if _settings_btn:
		_settings_btn.pressed.connect(_on_settings_pressed)

	if _credits_btn:
		_credits_btn.pressed.connect(_on_credits_pressed)

	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit_pressed)


func _update_continue_button() -> void:
	if _continue_btn == null:
		return

	# GameState에서 저장 데이터 확인
	var has_save := false

	if GameState and GameState.has_method("has_save_game"):
		has_save = GameState.has_save_game()

	_continue_btn.disabled = not has_save


func _set_version() -> void:
	if _version_label:
		_version_label.text = "v0.1.0 - Development"


# ===== BUTTON HANDLERS =====

func _on_new_game_pressed() -> void:
	# 새 런 시작 후 캠페인으로 이동
	if GameState:
		GameState.start_new_run(-1, Constants.Difficulty.NORMAL)

	var campaign_scene := "res://scenes/campaign/Campaign.tscn"
	if ResourceLoader.exists(campaign_scene):
		get_tree().change_scene_to_file(campaign_scene)
	else:
		# 캠페인 씬이 없으면 테스트 전투로 폴백
		var test_battle := "res://scenes/battle/TestBattle.tscn"
		if ResourceLoader.exists(test_battle):
			get_tree().change_scene_to_file(test_battle)
		else:
			push_warning("MainMenu: Campaign/TestBattle scene not found")


func _on_continue_pressed() -> void:
	if GameState and GameState.has_method("load_game"):
		if GameState.load_game():
			var sector_scene := "res://scenes/campaign/SectorMap.tscn"
			if ResourceLoader.exists(sector_scene):
				get_tree().change_scene_to_file(sector_scene)
			else:
				push_warning("MainMenu: SectorMap scene not found")


func _on_settings_pressed() -> void:
	var settings_scene := "res://scenes/ui/Settings.tscn"

	if ResourceLoader.exists(settings_scene):
		get_tree().change_scene_to_file(settings_scene)
	else:
		# SettingsMenu가 같은 폴더에 있는 경우
		var alt_path := "res://src/ui/menus/SettingsMenu.tscn"
		if ResourceLoader.exists(alt_path):
			get_tree().change_scene_to_file(alt_path)
		else:
			push_warning("MainMenu: Settings scene not found")


func _on_credits_pressed() -> void:
	var credits_scene := "res://scenes/ui/Credits.tscn"

	if ResourceLoader.exists(credits_scene):
		get_tree().change_scene_to_file(credits_scene)
	else:
		push_warning("MainMenu: Credits scene not found")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_new_game(difficulty: int) -> void:
	if GameState and GameState.has_method("start_new_run"):
		GameState.start_new_run(-1)  # -1 = 랜덤 시드

	var sector_scene := "res://scenes/campaign/SectorMap.tscn"
	if ResourceLoader.exists(sector_scene):
		get_tree().change_scene_to_file(sector_scene)
