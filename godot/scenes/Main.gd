extends Node

## 메인 씬 컨트롤러
## 씬 전환 및 글로벌 게임 흐름 관리


@onready var scene_container: Node = $SceneContainer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var debug_layer: CanvasLayer = $DebugLayer
@onready var debug_info: Label = $DebugLayer/DebugInfo


var _current_scene: Node = null
var _debug_visible: bool = true


func _ready() -> void:
	_setup_debug()
	_connect_signals()
	print("[Main] The Fading Raven v0.1.0 initialized")
	print("[Main] Godot version: %s" % Engine.get_version_info().string)

	# 시작 시 메인 메뉴 로드
	call_deferred("_load_main_menu")


func _load_main_menu() -> void:
	change_scene("res://src/ui/menus/MainMenu.tscn")


func _setup_debug() -> void:
	if debug_info:
		debug_info.visible = _debug_visible


func _connect_signals() -> void:
	GameState.run_started.connect(_on_run_started)
	GameState.run_ended.connect(_on_run_ended)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)


func _input(event: InputEvent) -> void:
	# F3으로 디버그 정보 토글
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		if debug_info:
			debug_info.visible = _debug_visible


func _process(_delta: float) -> void:
	if _debug_visible and debug_info:
		_update_debug_info()


func _update_debug_info() -> void:
	var fps := Engine.get_frames_per_second()
	var run_active := "Yes" if GameState.is_run_active() else "No"
	var credits := GameState.get_credits()
	var paused := "Yes" if GameState.is_paused else "No"

	debug_info.text = """The Fading Raven v0.1.0
FPS: %d
Run Active: %s
Credits: %d
Paused: %s
[F3] Toggle Debug""" % [fps, run_active, credits, paused]


# ===== SCENE MANAGEMENT =====

func change_scene(scene_path: String) -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null

	if not ResourceLoader.exists(scene_path):
		push_error("[Main] Scene not found: %s" % scene_path)
		return

	var scene_resource := load(scene_path) as PackedScene
	if scene_resource:
		_current_scene = scene_resource.instantiate()
		scene_container.add_child(_current_scene)
		print("[Main] Scene changed to: %s" % scene_path)
	else:
		push_error("[Main] Failed to load scene: %s" % scene_path)


func get_current_scene() -> Node:
	return _current_scene


# ===== UI LAYER ACCESS =====

func get_tooltip_container() -> Control:
	return $UILayer/TooltipContainer as Control


func get_toast_container() -> Control:
	return $UILayer/ToastContainer as Control


func get_modal_container() -> Control:
	return $UILayer/ModalContainer as Control


# ===== SIGNAL HANDLERS =====

func _on_run_started(_seed_value: int) -> void:
	print("[Main] Run started with seed: %d" % _seed_value)


func _on_run_ended(victory: bool) -> void:
	var result := "Victory" if victory else "Defeat"
	print("[Main] Run ended: %s" % result)


func _on_game_paused() -> void:
	GameState.is_paused = true
	get_tree().paused = true


func _on_game_resumed() -> void:
	GameState.is_paused = false
	get_tree().paused = false
