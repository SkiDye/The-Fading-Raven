class_name RavenPanel
extends HBoxContainer

## Raven 드론 능력 버튼 패널
## Scout, Flare, Resupply, Orbital Strike


@onready var _scout_btn: Button = $ScoutBtn
@onready var _flare_btn: Button = $FlareBtn
@onready var _resupply_btn: Button = $ResupplyBtn
@onready var _orbital_btn: Button = $OrbitalBtn

var _ability_buttons: Dictionary = {}
var _charges: Dictionary = {}


func _ready() -> void:
	_setup_buttons()
	_connect_signals()


func _setup_buttons() -> void:
	# 버튼 매핑
	if _scout_btn:
		_ability_buttons[Constants.RavenAbility.SCOUT] = _scout_btn
		_scout_btn.pressed.connect(_on_ability_pressed.bind(Constants.RavenAbility.SCOUT))

	if _flare_btn:
		_ability_buttons[Constants.RavenAbility.FLARE] = _flare_btn
		_flare_btn.pressed.connect(_on_ability_pressed.bind(Constants.RavenAbility.FLARE))

	if _resupply_btn:
		_ability_buttons[Constants.RavenAbility.RESUPPLY] = _resupply_btn
		_resupply_btn.pressed.connect(_on_ability_pressed.bind(Constants.RavenAbility.RESUPPLY))

	if _orbital_btn:
		_ability_buttons[Constants.RavenAbility.ORBITAL_STRIKE] = _orbital_btn
		_orbital_btn.pressed.connect(_on_ability_pressed.bind(Constants.RavenAbility.ORBITAL_STRIKE))

	# 초기 충전량 설정
	_charges[Constants.RavenAbility.SCOUT] = -1  # 무제한
	_charges[Constants.RavenAbility.FLARE] = 2
	_charges[Constants.RavenAbility.RESUPPLY] = 1
	_charges[Constants.RavenAbility.ORBITAL_STRIKE] = 1

	# 버튼 텍스트 업데이트
	for ability in _ability_buttons:
		update_charges(ability, _charges.get(ability, 0))


func _connect_signals() -> void:
	if EventBus:
		EventBus.raven_charges_changed.connect(_on_raven_charges_changed)


func _exit_tree() -> void:
	if EventBus and EventBus.raven_charges_changed.is_connected(_on_raven_charges_changed):
		EventBus.raven_charges_changed.disconnect(_on_raven_charges_changed)


## 충전량 업데이트
## [param ability]: Raven 능력 (Constants.RavenAbility)
## [param charges]: 남은 충전량 (-1 = 무제한)
func update_charges(ability: int, charges: int) -> void:
	_charges[ability] = charges

	var btn: Button = _ability_buttons.get(ability)
	if btn == null:
		return

	var ability_name := _get_ability_name(ability)

	if charges < 0:
		btn.text = "%s (∞)" % ability_name
		btn.disabled = false
	elif charges == 0:
		btn.text = "%s (0)" % ability_name
		btn.disabled = true
	else:
		btn.text = "%s (%d)" % [ability_name, charges]
		btn.disabled = false


## 모든 버튼 비활성화
func disable_all() -> void:
	for ability in _ability_buttons:
		_ability_buttons[ability].disabled = true


## 충전량에 따라 버튼 활성화
func enable_available() -> void:
	for ability in _ability_buttons:
		var charges: int = _charges.get(ability, 0)
		_ability_buttons[ability].disabled = (charges == 0)


func _get_ability_name(ability: int) -> String:
	match ability:
		Constants.RavenAbility.SCOUT:
			return "Scout"
		Constants.RavenAbility.FLARE:
			return "Flare"
		Constants.RavenAbility.RESUPPLY:
			return "Resupply"
		Constants.RavenAbility.ORBITAL_STRIKE:
			return "Orbital"
		_:
			return "Unknown"


func _get_ability_tooltip(ability: int) -> String:
	match ability:
		Constants.RavenAbility.SCOUT:
			return "정찰: 다음 웨이브 미리보기"
		Constants.RavenAbility.FLARE:
			return "조명탄: 범위 내 시야 확보"
		Constants.RavenAbility.RESUPPLY:
			return "보급: 범위 내 크루 체력 회복"
		Constants.RavenAbility.ORBITAL_STRIKE:
			return "궤도 폭격: 범위 내 대규모 피해"
		_:
			return ""


# ===== SIGNAL HANDLERS =====

func _on_ability_pressed(ability: int) -> void:
	var charges: int = _charges.get(ability, 0)

	# 충전량 확인
	if charges == 0:
		EventBus.show_toast.emit("충전량이 부족합니다", Constants.ToastType.WARNING, 2.0)
		return

	# 모든 능력은 raven_ability_used 이벤트로 통합
	# BattleController에서 Scout은 즉시 실행, 나머지는 타겟팅 모드로 전환
	EventBus.raven_ability_used.emit(ability)


func _on_raven_charges_changed(ability: int, charges: int) -> void:
	update_charges(ability, charges)
