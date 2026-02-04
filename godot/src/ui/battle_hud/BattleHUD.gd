class_name BattleHUD
extends CanvasLayer

## 전투 화면 HUD
## 크루 패널, 웨이브 표시, Raven 패널, 시설 상태 통합


@onready var _crew_panel: CrewPanel = $LeftPanel/MarginContainer/CrewPanel
@onready var _wave_indicator: WaveIndicator = $TopPanel/WaveIndicator
@onready var _raven_panel: RavenPanel = $BottomPanel/RavenPanel
@onready var _facility_status: FacilityStatus = $RightPanel/MarginContainer/VBoxContainer/FacilityStatus
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _skill_targeting_overlay: Control = $SkillTargetingOverlay
@onready var _credits_label: Label = $TopPanel/CreditsLabel
@onready var _evac_button: Button = $BottomPanel/EvacButton
@onready var _evac_progress: ProgressBar = $BottomPanel/EvacProgress

# 명령 버튼 패널
@onready var _command_panel: HBoxContainer = $CommandPanel
@onready var _move_btn: Button = $CommandPanel/MoveBtn
@onready var _skill_btn: Button = $CommandPanel/SkillBtn
@onready var _resupply_btn: Button = $CommandPanel/ResupplyBtn

# 웨이브 방향 화살표 및 Final Wave
@onready var _wave_direction_arrows: WaveDirectionArrows = $WaveDirectionArrows
@onready var _final_wave_label: Label = $FinalWaveLabel

# 카메라 회전 버튼
@onready var _rotate_left_btn: Button = $CameraButtons/RotateLeftBtn
@onready var _rotate_right_btn: Button = $CameraButtons/RotateRightBtn

signal camera_rotate_requested(direction: int)  # -1 = left, 1 = right

var battle_controller: Node  # BattleController
var _selected_crew: Node  # 현재 선택된 크루
var _final_wave_tween: Tween


func _ready() -> void:
	_connect_signals()
	_setup_command_buttons()

	if _pause_overlay:
		_pause_overlay.visible = false

	if _skill_targeting_overlay:
		_skill_targeting_overlay.visible = false

	if _command_panel:
		_command_panel.visible = false

	if _evac_button:
		_evac_button.pressed.connect(_on_evac_button_pressed)
		_evac_button.text = "Emergency Evac"
		_evac_button.tooltip_text = "긴급 귀환: 크루 전원 생존, 크레딧 0"

	if _evac_progress:
		_evac_progress.visible = false

	if _final_wave_label:
		_final_wave_label.visible = false

	# 카메라 회전 버튼 연결
	if _rotate_left_btn:
		_rotate_left_btn.pressed.connect(_on_rotate_left_pressed)
	if _rotate_right_btn:
		_rotate_right_btn.pressed.connect(_on_rotate_right_pressed)


func _setup_command_buttons() -> void:
	if _move_btn:
		_move_btn.pressed.connect(_on_move_btn_pressed)

	if _skill_btn:
		_skill_btn.pressed.connect(_on_skill_btn_pressed)

	if _resupply_btn:
		_resupply_btn.pressed.connect(_on_resupply_btn_pressed)


func _connect_signals() -> void:
	if EventBus:
		EventBus.crew_selected.connect(_on_crew_selected)
		EventBus.crew_deselected.connect(_on_crew_deselected)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.wave_ended.connect(_on_wave_ended)
		EventBus.game_paused.connect(_on_game_paused)
		EventBus.game_resumed.connect(_on_game_resumed)
		EventBus.skill_targeting_started.connect(_on_skill_targeting_started)
		EventBus.skill_targeting_ended.connect(_on_skill_targeting_ended)
		EventBus.raven_charges_changed.connect(_on_raven_charges_changed)

	if GameState and GameState.has_signal("credits_changed"):
		GameState.credits_changed.connect(_on_credits_changed)


func _exit_tree() -> void:
	if EventBus:
		EventBus.disconnect_all_for_node(self)


func _input(event: InputEvent) -> void:
	# 크루 선택 단축키 (1-5)
	if event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var index: int = key - KEY_1
			if _crew_panel:
				_crew_panel.select_by_index(index)


## 전투 컨트롤러로 초기화
## [param controller]: BattleController 노드
func initialize(controller: Node) -> void:
	battle_controller = controller
	_setup_crew_panel()
	_setup_raven_panel()
	_setup_facility_status()
	_update_credits()
	_setup_evac_ui()


func _setup_evac_ui() -> void:
	if battle_controller == null:
		return

	# BattleController의 evac 시그널 연결
	if battle_controller.has_signal("emergency_evac_started"):
		battle_controller.emergency_evac_started.connect(_start_evac_ui)
	if battle_controller.has_signal("emergency_evac_completed"):
		battle_controller.emergency_evac_completed.connect(_end_evac_ui)


func _setup_crew_panel() -> void:
	if _crew_panel == null or battle_controller == null:
		return

	_crew_panel.clear_crews()

	# 크루 목록 가져오기
	var crews: Array = []
	if "crews" in battle_controller:
		crews = battle_controller.crews
	elif "all_crews" in battle_controller:
		crews = battle_controller.all_crews
	elif battle_controller.has_method("get_crews"):
		crews = battle_controller.get_crews()

	for crew in crews:
		_crew_panel.add_crew(crew)


func _setup_raven_panel() -> void:
	if _raven_panel == null:
		return

	# GameState에서 Raven 충전량 가져오기
	if GameState and GameState.has_method("get_raven_charges"):
		_raven_panel.update_charges(Constants.RavenAbility.SCOUT, -1)  # 무제한
		_raven_panel.update_charges(Constants.RavenAbility.FLARE,
			GameState.get_raven_charges(Constants.RavenAbility.FLARE))
		_raven_panel.update_charges(Constants.RavenAbility.RESUPPLY,
			GameState.get_raven_charges(Constants.RavenAbility.RESUPPLY))
		_raven_panel.update_charges(Constants.RavenAbility.ORBITAL_STRIKE,
			GameState.get_raven_charges(Constants.RavenAbility.ORBITAL_STRIKE))
	else:
		# 기본값
		_raven_panel.update_charges(Constants.RavenAbility.SCOUT, -1)
		_raven_panel.update_charges(Constants.RavenAbility.FLARE, 2)
		_raven_panel.update_charges(Constants.RavenAbility.RESUPPLY, 1)
		_raven_panel.update_charges(Constants.RavenAbility.ORBITAL_STRIKE, 1)


func _setup_facility_status() -> void:
	if _facility_status == null or battle_controller == null:
		return

	_facility_status.clear()

	# 시설 목록 가져오기
	var facilities: Array = []
	if "facilities" in battle_controller:
		facilities = battle_controller.facilities
	elif battle_controller.has_method("get_facilities"):
		facilities = battle_controller.get_facilities()

	for facility in facilities:
		_facility_status.add_facility(facility)


func _update_credits() -> void:
	if _credits_label == null:
		return

	var credits: int = 0
	if GameState and "credits" in GameState:
		credits = GameState.credits

	_credits_label.text = "Credits: %d" % credits


func _show_crew_actions(crew: Node) -> void:
	_selected_crew = crew

	if _command_panel:
		_command_panel.visible = true

	# 스킬 버튼 상태 업데이트
	if _skill_btn and crew:
		var can_use: bool = crew.can_use_skill() if crew.has_method("can_use_skill") else false
		_skill_btn.disabled = not can_use

		# 스킬 쿨다운 표시
		if crew.has_method("get_effective_cooldown") and "skill_cooldown_remaining" in crew:
			var remaining: float = crew.skill_cooldown_remaining
			if remaining > 0:
				_skill_btn.text = "Skill (%.0fs)" % remaining
			else:
				_skill_btn.text = "Skill"
		else:
			_skill_btn.text = "Skill"

	# Resupply 버튼 상태 업데이트
	if _resupply_btn and crew:
		var can_resupply: bool = false
		if crew.has_method("get_alive_count") and crew.has_method("get_max_squad_size"):
			can_resupply = crew.get_alive_count() < crew.get_max_squad_size()

		# 회복 중이면 비활성화
		if "is_recovering" in crew and crew.is_recovering:
			_resupply_btn.disabled = true
			_resupply_btn.text = "Resupplying..."
		else:
			_resupply_btn.disabled = not can_resupply
			_resupply_btn.text = "Resupply"


func _hide_crew_actions() -> void:
	_selected_crew = null

	if _command_panel:
		_command_panel.visible = false


# ===== SIGNAL HANDLERS =====

func _on_crew_selected(crew: Node) -> void:
	if _crew_panel:
		_crew_panel.select_crew(crew)
	_show_crew_actions(crew)


func _on_crew_deselected() -> void:
	if _crew_panel:
		_crew_panel.deselect()
	_hide_crew_actions()


func _on_wave_started(wave_num: int, total: int, _preview: Array) -> void:
	if _wave_indicator:
		_wave_indicator.show_wave(wave_num, total)

	# Final Wave 표시
	if wave_num == total and total > 0:
		_show_final_wave()


func _on_wave_ended(_wave_num: int) -> void:
	if _wave_indicator:
		_wave_indicator.show_wave_clear()


func _on_game_paused() -> void:
	if _pause_overlay:
		_pause_overlay.visible = true


func _on_game_resumed() -> void:
	if _pause_overlay:
		_pause_overlay.visible = false


func _on_skill_targeting_started(_crew: Node, _skill_id: String) -> void:
	if _skill_targeting_overlay:
		_skill_targeting_overlay.visible = true


func _on_skill_targeting_ended() -> void:
	if _skill_targeting_overlay:
		_skill_targeting_overlay.visible = false


func _on_raven_charges_changed(ability: int, charges: int) -> void:
	if _raven_panel:
		_raven_panel.update_charges(ability, charges)


func _on_credits_changed(amount: int) -> void:
	if _credits_label:
		_credits_label.text = "Credits: %d" % amount


func _on_evac_button_pressed() -> void:
	if battle_controller == null:
		return

	if battle_controller.has_method("start_emergency_evac"):
		var success: bool = battle_controller.start_emergency_evac()
		if success:
			_start_evac_ui()


func _start_evac_ui() -> void:
	if _evac_button:
		_evac_button.disabled = true
		_evac_button.text = "Evacuating..."

	if _evac_progress:
		_evac_progress.visible = true
		_evac_progress.value = 0


func _update_evac_progress(progress: float) -> void:
	if _evac_progress:
		_evac_progress.value = progress * 100.0


func _end_evac_ui() -> void:
	if _evac_button:
		_evac_button.disabled = false
		_evac_button.text = "Emergency Evac"

	if _evac_progress:
		_evac_progress.visible = false


func _process(delta: float) -> void:
	# 귀환 진행 중이면 프로그레스 바 업데이트
	if battle_controller and "is_evacuating" in battle_controller and battle_controller.is_evacuating:
		if "evac_timer" in battle_controller and "EVAC_DELAY" in battle_controller:
			var progress: float = 1.0 - (battle_controller.evac_timer / battle_controller.EVAC_DELAY)
			_update_evac_progress(progress)

	# 선택된 크루의 상태 업데이트
	if _selected_crew and _command_panel and _command_panel.visible:
		_update_command_buttons()


func _update_command_buttons() -> void:
	if _selected_crew == null:
		return

	# 스킬 버튼 쿨다운 업데이트
	if _skill_btn:
		var can_use: bool = _selected_crew.can_use_skill() if _selected_crew.has_method("can_use_skill") else false
		_skill_btn.disabled = not can_use

		if "skill_cooldown_remaining" in _selected_crew:
			var remaining: float = _selected_crew.skill_cooldown_remaining
			if remaining > 0:
				_skill_btn.text = "Skill (%.0fs)" % remaining
			else:
				_skill_btn.text = "Skill"

	# Resupply 상태 업데이트
	if _resupply_btn:
		if "is_recovering" in _selected_crew and _selected_crew.is_recovering:
			_resupply_btn.disabled = true
			_resupply_btn.text = "Resupplying..."
		else:
			var can_resupply: bool = false
			if _selected_crew.has_method("get_alive_count") and _selected_crew.has_method("get_max_squad_size"):
				can_resupply = _selected_crew.get_alive_count() < _selected_crew.get_max_squad_size()
			_resupply_btn.disabled = not can_resupply
			_resupply_btn.text = "Resupply"


# ===== COMMAND BUTTON HANDLERS =====

func _on_move_btn_pressed() -> void:
	if _selected_crew == null:
		return

	# 이동 모드 활성화 요청
	EventBus.move_mode_requested.emit(_selected_crew)


func _on_skill_btn_pressed() -> void:
	if _selected_crew == null:
		return

	if not _selected_crew.has_method("can_use_skill"):
		return

	if not _selected_crew.can_use_skill():
		EventBus.show_toast.emit("스킬 쿨다운 중입니다!", Constants.ToastType.WARNING, 2.0)
		return

	# 스킬 타겟팅 모드 시작
	var skill_id: String = ""
	if _selected_crew.has_method("_get_skill_id"):
		skill_id = _selected_crew._get_skill_id()

	EventBus.skill_targeting_started.emit(_selected_crew, skill_id)


func _on_resupply_btn_pressed() -> void:
	if _selected_crew == null:
		return

	# 이미 회복 중이면 무시
	if "is_recovering" in _selected_crew and _selected_crew.is_recovering:
		EventBus.show_toast.emit("이미 회복 중입니다!", Constants.ToastType.WARNING, 2.0)
		return

	# 시설 위에 있는지 확인 및 회복 시작
	if battle_controller and battle_controller.has_method("start_crew_resupply"):
		var success: bool = battle_controller.start_crew_resupply(_selected_crew)
		if not success:
			EventBus.show_toast.emit("시설 위에서만 회복할 수 있습니다!", Constants.ToastType.WARNING, 2.0)
	elif _selected_crew.has_method("start_recovery"):
		_selected_crew.start_recovery()


# ===== FINAL WAVE =====

func _show_final_wave() -> void:
	if _final_wave_label == null:
		return

	_final_wave_label.visible = true
	_final_wave_label.modulate = Color(1, 0.3, 0.3, 0)
	_final_wave_label.scale = Vector2(1.5, 1.5)

	if _final_wave_tween and _final_wave_tween.is_running():
		_final_wave_tween.kill()

	_final_wave_tween = create_tween()

	# 페이드 인 + 스케일 다운
	_final_wave_tween.tween_property(_final_wave_label, "modulate:a", 1.0, 0.3)
	_final_wave_tween.parallel().tween_property(_final_wave_label, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 잠시 대기
	_final_wave_tween.tween_interval(2.0)

	# 펄스 효과 (3회)
	for i in range(3):
		_final_wave_tween.tween_property(_final_wave_label, "modulate", Color(1, 0.5, 0.5, 1), 0.2)
		_final_wave_tween.tween_property(_final_wave_label, "modulate", Color(1, 0.3, 0.3, 1), 0.2)

	# 페이드 아웃
	_final_wave_tween.tween_property(_final_wave_label, "modulate:a", 0.0, 0.5)
	_final_wave_tween.tween_callback(func(): _final_wave_label.visible = false)


# ===== CAMERA ROTATION =====

func _on_rotate_left_pressed() -> void:
	camera_rotate_requested.emit(-1)


func _on_rotate_right_pressed() -> void:
	camera_rotate_requested.emit(1)
