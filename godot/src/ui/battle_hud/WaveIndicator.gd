class_name WaveIndicator
extends Control

## 웨이브 진행 상황 표시 UI
## 현재 웨이브 / 총 웨이브, 진행률


@onready var _wave_label: Label = $VBoxContainer/WaveLabel
@onready var _progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _preview_container: Control = $VBoxContainer/PreviewContainer

var _current_wave: int = 0
var _total_waves: int = 0
var _tween: Tween
var _preview_tween: Tween


func _ready() -> void:
	_connect_signals()
	_update_display()


func _connect_signals() -> void:
	if EventBus:
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.wave_ended.connect(_on_wave_ended)
		EventBus.all_waves_cleared.connect(_on_all_waves_cleared)


func _exit_tree() -> void:
	if EventBus:
		if EventBus.wave_started.is_connected(_on_wave_started):
			EventBus.wave_started.disconnect(_on_wave_started)
		if EventBus.wave_ended.is_connected(_on_wave_ended):
			EventBus.wave_ended.disconnect(_on_wave_ended)
		if EventBus.all_waves_cleared.is_connected(_on_all_waves_cleared):
			EventBus.all_waves_cleared.disconnect(_on_all_waves_cleared)


## 웨이브 표시
## [param current]: 현재 웨이브 번호
## [param total]: 총 웨이브 수
func show_wave(current: int, total: int) -> void:
	_current_wave = current
	_total_waves = total
	_update_display()
	_play_wave_start_animation()


## 웨이브 클리어 표시
func show_wave_clear() -> void:
	if _status_label:
		_status_label.text = "WAVE CLEAR!"
		_status_label.modulate = Color(0.4, 1.0, 0.4)

	_play_wave_clear_animation()


## 모든 웨이브 클리어 표시
func show_all_clear() -> void:
	if _wave_label:
		_wave_label.text = "ALL WAVES CLEARED!"
		_wave_label.modulate = Color(1.0, 0.9, 0.3)

	if _status_label:
		_status_label.text = "VICTORY!"
		_status_label.modulate = Color(1.0, 0.9, 0.3)

	if _progress_bar:
		_progress_bar.value = 100.0

	_play_victory_animation()


func _update_display() -> void:
	if _wave_label:
		if _total_waves > 0:
			_wave_label.text = "Wave %d / %d" % [_current_wave, _total_waves]
		else:
			_wave_label.text = "Wave %d" % _current_wave
		_wave_label.modulate = Color.WHITE

	if _progress_bar and _total_waves > 0:
		_progress_bar.value = float(_current_wave - 1) / float(_total_waves) * 100.0

	if _status_label:
		_status_label.text = "In Progress..."
		_status_label.modulate = Color(1.0, 0.7, 0.3)


func _play_wave_start_animation() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()

	# 웨이브 레이블 펄스 효과
	if _wave_label:
		_wave_label.scale = Vector2(1.2, 1.2)
		_tween.tween_property(_wave_label, "scale", Vector2(1.0, 1.0), 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_wave_clear_animation() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()

	# 상태 레이블 페이드 인/아웃
	if _status_label:
		_tween.tween_property(_status_label, "modulate:a", 1.0, 0.2)
		_tween.tween_interval(1.0)
		_tween.tween_property(_status_label, "modulate:a", 0.5, 0.3)


func _play_victory_animation() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween().set_loops(3)

	# 반짝임 효과
	if _wave_label:
		_tween.tween_property(_wave_label, "modulate", Color(1.0, 1.0, 0.5), 0.3)
		_tween.tween_property(_wave_label, "modulate", Color(1.0, 0.9, 0.3), 0.3)


# ===== SCOUT PREVIEW =====

## Scout 능력으로 다음 웨이브 미리보기
func show_scout_preview(preview: Array) -> void:
	if preview.is_empty():
		EventBus.show_toast.emit("다음 웨이브 정보 없음", Constants.ToastType.INFO, 2.0)
		return

	# 프리뷰 텍스트 구성
	var preview_text := "== SCOUT: 다음 웨이브 ==\n"
	for entry in preview:
		var enemy_id: String = entry.get("enemy_id", "unknown")
		var count: int = entry.get("count", 0)
		var display_name := _get_enemy_display_name(enemy_id)
		preview_text += "%s x%d\n" % [display_name, count]

	# 상태 레이블에 표시
	if _status_label:
		_status_label.text = preview_text.strip_edges()
		_status_label.modulate = Color(0.4, 0.8, 1.0)

	# 웨이브 레이블에도 표시
	if _wave_label:
		_wave_label.text = "SCOUT PREVIEW"
		_wave_label.modulate = Color(0.4, 0.8, 1.0)

	_play_scout_animation()

	# 일정 시간 후 복원
	await get_tree().create_timer(5.0).timeout
	_update_display()


func _get_enemy_display_name(enemy_id: String) -> String:
	match enemy_id:
		"rusher":
			return "돌격병"
		"gunner":
			return "사수"
		"shield_trooper":
			return "방패병"
		"jumper":
			return "점퍼"
		"heavy_trooper":
			return "중장병"
		"hacker":
			return "해커"
		"brute":
			return "브루트"
		"sniper":
			return "저격수"
		"drone_carrier":
			return "드론 캐리어"
		"shield_generator":
			return "실드 제너레이터"
		"storm_creature":
			return "폭풍 생명체"
		"pirate_captain":
			return "해적 대장"
		_:
			return enemy_id


func _play_scout_animation() -> void:
	if _preview_tween and _preview_tween.is_running():
		_preview_tween.kill()

	_preview_tween = create_tween()

	# 펄스 효과
	if _status_label:
		_preview_tween.tween_property(_status_label, "modulate:a", 1.0, 0.2)
		_preview_tween.tween_property(_status_label, "modulate:a", 0.8, 0.3)
		_preview_tween.set_loops(2)


# ===== SIGNAL HANDLERS =====

func _on_wave_started(wave_num: int, total: int, preview: Array) -> void:
	# wave_num이 -1이면 Scout 프리뷰 모드
	if wave_num < 0:
		show_scout_preview(preview)
	else:
		show_wave(wave_num, total)


func _on_wave_ended(_wave_num: int) -> void:
	show_wave_clear()


func _on_all_waves_cleared() -> void:
	show_all_clear()
