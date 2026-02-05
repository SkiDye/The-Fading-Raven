class_name MainMenu
extends Control

## 메인 메뉴 화면
## 새 게임, 계속하기, 설정, 종료


@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $VBoxContainer/SubtitleLabel
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
	_update_localized_text()

	# 언어 변경 시 UI 업데이트
	if Localization:
		Localization.locale_changed.connect(_on_locale_changed)


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


func _update_localized_text() -> void:
	## 모든 UI 텍스트를 현재 로케일로 업데이트
	if not Localization:
		return

	if _title_label:
		_title_label.text = Localization.get_text("main_menu.title").to_upper()

	if _new_game_btn:
		_new_game_btn.text = Localization.get_text("main_menu.new_game").to_upper()

	if _continue_btn:
		_continue_btn.text = Localization.get_text("main_menu.continue_game").to_upper()

	if _settings_btn:
		_settings_btn.text = Localization.get_text("main_menu.settings").to_upper()

	if _credits_btn:
		_credits_btn.text = Localization.get_text("common.credits").to_upper()

	if _quit_btn:
		_quit_btn.text = Localization.get_text("main_menu.quit").to_upper()


func _on_locale_changed(_new_locale: String) -> void:
	_update_localized_text()


# ===== BUTTON HANDLERS =====

func _on_new_game_pressed() -> void:
	# NewGameSetup으로 이동 (난이도 & 시작 팀장 선택)
	var new_game_setup := "res://scenes/campaign/NewGameSetup.tscn"
	if ResourceLoader.exists(new_game_setup):
		get_tree().change_scene_to_file(new_game_setup)
		return

	# NewGameSetup이 없으면 바로 섹터맵으로
	if GameState:
		GameState.start_new_run(-1, Constants.Difficulty.NORMAL)

	var sector_map := "res://scenes/campaign/SectorMap3D.tscn"
	if ResourceLoader.exists(sector_map):
		get_tree().change_scene_to_file(sector_map)
	else:
		push_warning("MainMenu: SectorMap3D scene not found")


func _on_continue_pressed() -> void:
	if GameState and GameState.has_method("load_game"):
		if GameState.load_game():
			var sector_map := "res://scenes/campaign/SectorMap3D.tscn"
			if ResourceLoader.exists(sector_map):
				get_tree().change_scene_to_file(sector_map)
			else:
				push_warning("MainMenu: SectorMap3D scene not found")


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
		GameState.start_new_run(-1, difficulty)

	var sector_map := "res://scenes/campaign/SectorMap3D.tscn"
	if ResourceLoader.exists(sector_map):
		get_tree().change_scene_to_file(sector_map)
