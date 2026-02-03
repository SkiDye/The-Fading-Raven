## SceneManager - 씬 전환 관리
## 트랜지션 효과와 함께 씬 전환
extends Node

const TRANSITION_TIME := 0.3

enum Scene {
	MAIN_MENU,
	SECTOR_MAP,
	BATTLE,
	UPGRADE,
	SETTINGS,
	GAME_OVER,
	VICTORY,
}

const SCENE_PATHS := {
	Scene.MAIN_MENU: "res://scenes/main_menu.tscn",
	Scene.SECTOR_MAP: "res://scenes/sector_map.tscn",
	Scene.BATTLE: "res://scenes/battle.tscn",
	Scene.UPGRADE: "res://scenes/upgrade.tscn",
	Scene.SETTINGS: "res://scenes/settings.tscn",
	Scene.GAME_OVER: "res://scenes/game_over.tscn",
	Scene.VICTORY: "res://scenes/victory.tscn",
}

var _current_scene: Scene = Scene.MAIN_MENU
var _transition_overlay: ColorRect = null
var _is_transitioning: bool = false

# 씬 전환 시 전달할 데이터
var scene_data: Dictionary = {}

signal scene_changed(new_scene: Scene)
signal transition_started()
signal transition_finished()


func _ready() -> void:
	_create_transition_overlay()


func _create_transition_overlay() -> void:
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.BLACK
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.modulate.a = 0.0

	# 전체 화면 커버
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 최상위 레이어에 추가
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(_transition_overlay)
	add_child(canvas)


## 씬 전환 (페이드 효과)
func change_scene(target: Scene, data: Dictionary = {}) -> void:
	if _is_transitioning:
		return

	scene_data = data
	_is_transitioning = true
	transition_started.emit()

	# 페이드 아웃
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, TRANSITION_TIME)
	await tween.finished

	# 씬 변경
	var path: String = SCENE_PATHS.get(target, "")
	if path.is_empty():
		push_error("Unknown scene: %d" % target)
		_is_transitioning = false
		return

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Failed to change scene: %s" % path)
		_is_transitioning = false
		return

	_current_scene = target

	# 페이드 인
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", 0.0, TRANSITION_TIME)
	await tween.finished

	_is_transitioning = false
	scene_changed.emit(target)
	transition_finished.emit()


## 즉시 씬 전환 (트랜지션 없음)
func change_scene_instant(target: Scene, data: Dictionary = {}) -> void:
	scene_data = data

	var path: String = SCENE_PATHS.get(target, "")
	if path.is_empty():
		push_error("Unknown scene: %d" % target)
		return

	get_tree().change_scene_to_file(path)
	_current_scene = target
	scene_changed.emit(target)


## 현재 씬 가져오기
func get_current_scene() -> Scene:
	return _current_scene


## 전환 중인지 확인
func is_transitioning() -> bool:
	return _is_transitioning


## 메인 메뉴로 이동
func go_to_main_menu() -> void:
	change_scene(Scene.MAIN_MENU)


## 섹터 맵으로 이동
func go_to_sector_map() -> void:
	change_scene(Scene.SECTOR_MAP)


## 전투 시작
func start_battle(station_data: Dictionary) -> void:
	change_scene(Scene.BATTLE, {"station": station_data})


## 업그레이드 화면으로 이동
func go_to_upgrade() -> void:
	change_scene(Scene.UPGRADE)


## 게임 오버
func go_to_game_over() -> void:
	change_scene(Scene.GAME_OVER)


## 승리 화면
func go_to_victory() -> void:
	change_scene(Scene.VICTORY)


## 설정 화면으로 이동
func go_to_settings() -> void:
	change_scene(Scene.SETTINGS)
