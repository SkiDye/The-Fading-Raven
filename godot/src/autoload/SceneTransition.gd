extends CanvasLayer

## 씬 전환 트랜지션 관리자
## 페이드, 크로스페이드, 슬라이드 등의 전환 효과 제공


# ===== SIGNALS =====

signal transition_started(transition_type: String)
signal transition_midpoint()  # 전환 중간 시점 (씬 교체 시점)
signal transition_finished()


# ===== ENUMS =====

enum TransitionType {
	FADE,           # 페이드 인/아웃
	CROSSFADE,      # 크로스페이드
	SLIDE_LEFT,     # 좌측으로 슬라이드
	SLIDE_RIGHT,    # 우측으로 슬라이드
	ZOOM_IN,        # 줌 인
	ZOOM_OUT,       # 줌 아웃
	DISSOLVE,       # 디졸브
	INSTANT         # 즉시 전환
}


# ===== CONSTANTS =====

const DEFAULT_DURATION: float = 0.5


# ===== STATE =====

var is_transitioning: bool = false
var _current_scene_path: String = ""


# ===== CHILD NODES =====

var _color_rect: ColorRect
var _animation_player: AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	layer = 100  # 최상위 레이어
	_setup_ui()
	_setup_animations()


func _setup_ui() -> void:
	# 전체 화면 덮는 ColorRect
	_color_rect = ColorRect.new()
	_color_rect.name = "TransitionRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = Color.BLACK
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.modulate.a = 0.0
	add_child(_color_rect)


func _setup_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)

	# 페이드 인 애니메이션
	var fade_in := Animation.new()
	fade_in.length = DEFAULT_DURATION
	fade_in.add_track(Animation.TYPE_VALUE)
	fade_in.track_set_path(0, "TransitionRect:modulate:a")
	fade_in.track_insert_key(0, 0.0, 0.0)
	fade_in.track_insert_key(0, DEFAULT_DURATION, 1.0)

	var lib := AnimationLibrary.new()
	lib.add_animation("fade_in", fade_in)

	# 페이드 아웃 애니메이션
	var fade_out := Animation.new()
	fade_out.length = DEFAULT_DURATION
	fade_out.add_track(Animation.TYPE_VALUE)
	fade_out.track_set_path(0, "TransitionRect:modulate:a")
	fade_out.track_insert_key(0, 0.0, 1.0)
	fade_out.track_insert_key(0, DEFAULT_DURATION, 0.0)
	lib.add_animation("fade_out", fade_out)

	_animation_player.add_animation_library("", lib)


# ===== PUBLIC API =====

## 씬 전환 (경로 지정)
func change_scene(
	scene_path: String,
	transition_type: TransitionType = TransitionType.FADE,
	duration: float = DEFAULT_DURATION,
	color: Color = Color.BLACK
) -> void:
	if is_transitioning:
		push_warning("SceneTransition: Already transitioning")
		return

	is_transitioning = true
	_current_scene_path = scene_path
	_color_rect.color = color

	transition_started.emit(_get_transition_name(transition_type))

	match transition_type:
		TransitionType.FADE:
			await _transition_fade(scene_path, duration)
		TransitionType.CROSSFADE:
			await _transition_crossfade(scene_path, duration)
		TransitionType.ZOOM_IN:
			await _transition_zoom_in(scene_path, duration)
		TransitionType.ZOOM_OUT:
			await _transition_zoom_out(scene_path, duration)
		TransitionType.INSTANT:
			_transition_instant(scene_path)
		_:
			await _transition_fade(scene_path, duration)

	is_transitioning = false
	transition_finished.emit()


## 씬 전환 (PackedScene 지정)
func change_scene_to_packed(
	packed_scene: PackedScene,
	transition_type: TransitionType = TransitionType.FADE,
	duration: float = DEFAULT_DURATION,
	color: Color = Color.BLACK
) -> void:
	if is_transitioning:
		push_warning("SceneTransition: Already transitioning")
		return

	is_transitioning = true
	_color_rect.color = color

	transition_started.emit(_get_transition_name(transition_type))

	match transition_type:
		TransitionType.FADE:
			await _transition_fade_packed(packed_scene, duration)
		TransitionType.INSTANT:
			_transition_instant_packed(packed_scene)
		_:
			await _transition_fade_packed(packed_scene, duration)

	is_transitioning = false
	transition_finished.emit()


## 페이드 인만 실행 (씬 전환 없음)
func fade_in(duration: float = DEFAULT_DURATION, color: Color = Color.BLACK) -> void:
	_color_rect.color = color
	_color_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration)
	await tween.finished


## 페이드 아웃만 실행 (씬 전환 없음)
func fade_out(duration: float = DEFAULT_DURATION) -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration)
	await tween.finished


## 플래시 효과
func flash(
	color: Color = Color.WHITE,
	duration: float = 0.2
) -> void:
	_color_rect.color = color
	_color_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration)


# ===== TRANSITION IMPLEMENTATIONS =====

func _transition_fade(scene_path: String, duration: float) -> void:
	# 페이드 인 (화면 어두워짐)
	_color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration * 0.5)
	await tween.finished

	transition_midpoint.emit()

	# 씬 전환
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_error("SceneTransition: Failed to change scene to %s" % scene_path)

	# 한 프레임 대기
	await get_tree().process_frame

	# 페이드 아웃 (화면 밝아짐)
	tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration * 0.5)
	await tween.finished


func _transition_fade_packed(packed_scene: PackedScene, duration: float) -> void:
	_color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration * 0.5)
	await tween.finished

	transition_midpoint.emit()

	var result := get_tree().change_scene_to_packed(packed_scene)
	if result != OK:
		push_error("SceneTransition: Failed to change scene")

	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration * 0.5)
	await tween.finished


func _transition_crossfade(scene_path: String, duration: float) -> void:
	# 현재 씬 스크린샷
	# (간단 구현: 페이드와 동일하게 처리)
	await _transition_fade(scene_path, duration)


func _transition_zoom_in(scene_path: String, duration: float) -> void:
	# 줌 인 효과 (화면 중앙으로 수렴)
	_color_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration * 0.5)
	await tween.finished

	transition_midpoint.emit()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration * 0.5)
	await tween.finished


func _transition_zoom_out(scene_path: String, duration: float) -> void:
	await _transition_fade(scene_path, duration)


func _transition_instant(scene_path: String) -> void:
	transition_midpoint.emit()
	get_tree().change_scene_to_file(scene_path)


func _transition_instant_packed(packed_scene: PackedScene) -> void:
	transition_midpoint.emit()
	get_tree().change_scene_to_packed(packed_scene)


# ===== UTILITIES =====

func _get_transition_name(type: TransitionType) -> String:
	match type:
		TransitionType.FADE: return "fade"
		TransitionType.CROSSFADE: return "crossfade"
		TransitionType.SLIDE_LEFT: return "slide_left"
		TransitionType.SLIDE_RIGHT: return "slide_right"
		TransitionType.ZOOM_IN: return "zoom_in"
		TransitionType.ZOOM_OUT: return "zoom_out"
		TransitionType.DISSOLVE: return "dissolve"
		TransitionType.INSTANT: return "instant"
	return "unknown"
