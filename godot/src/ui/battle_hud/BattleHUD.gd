class_name BattleHUD
extends CanvasLayer

## 전투 화면 HUD
## 크루 패널, 웨이브 표시, Raven 패널, 시설 상태 통합


@onready var _crew_panel: CrewPanel = $LeftPanel/CrewPanel
@onready var _wave_indicator: WaveIndicator = $TopPanel/WaveIndicator
@onready var _raven_panel: RavenPanel = $BottomPanel/RavenPanel
@onready var _facility_status: FacilityStatus = $RightPanel/FacilityStatus
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _skill_targeting_overlay: Control = $SkillTargetingOverlay
@onready var _credits_label: Label = $TopPanel/CreditsLabel

var battle_controller: Node  # BattleController


func _ready() -> void:
	_connect_signals()

	if _pause_overlay:
		_pause_overlay.visible = false

	if _skill_targeting_overlay:
		_skill_targeting_overlay.visible = false


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
		var key := event.keycode
		if key >= KEY_1 and key <= KEY_5:
			var index := key - KEY_1
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


func _show_crew_actions(_crew: Node) -> void:
	# 선택된 크루의 스킬/장비 버튼 활성화
	pass


func _hide_crew_actions() -> void:
	# 스킬/장비 버튼 비활성화
	pass


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
