## BattleScene - 전투 씬 관리
## 전투 시스템 통합 및 UI 관리
extends Node2D

# ===========================================
# 씬 참조
# ===========================================

@onready var tile_renderer: TileRenderer = $TileRenderer
@onready var crews_container: Node2D = $Entities/Crews
@onready var enemies_container: Node2D = $Entities/Enemies
@onready var effects_container: Node2D = $Effects
@onready var camera: IsometricCamera = $Camera2D

# HUD
@onready var wave_label: Label = $HUD/TopBar/WaveLabel
@onready var enemies_label: Label = $HUD/TopBar/EnemiesLabel
@onready var facility_label: Label = $HUD/TopBar/FacilityHealthLabel
@onready var pause_button: Button = $HUD/PauseButton
@onready var crew_panel: VBoxContainer = $HUD/CrewPanel

# Raven 능력 버튼
@onready var scout_button: Button = $HUD/AbilityBar/ScoutButton
@onready var flare_button: Button = $HUD/AbilityBar/FlareButton
@onready var resupply_button: Button = $HUD/AbilityBar/ResupplyButton
@onready var orbital_button: Button = $HUD/AbilityBar/OrbitalButton

# 컴포넌트
var battle_manager: BattleManager = null
var battle_input: BattleInput = null


# ===========================================
# 초기화
# ===========================================

func _ready() -> void:
	# 컴포넌트 생성
	battle_manager = BattleManager.new()
	battle_manager.crews_container = crews_container
	battle_manager.enemies_container = enemies_container
	add_child(battle_manager)

	battle_input = BattleInput.new()
	add_child(battle_input)

	# 버튼 연결
	pause_button.pressed.connect(_on_pause_pressed)
	scout_button.pressed.connect(_on_scout_pressed)
	flare_button.pressed.connect(_on_flare_pressed)
	resupply_button.pressed.connect(_on_resupply_pressed)
	orbital_button.pressed.connect(_on_orbital_pressed)

	# 이벤트 연결
	battle_manager.wave_started.connect(_on_wave_started)
	battle_manager.wave_cleared.connect(_on_wave_cleared)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.enemy_spawned.connect(_on_enemy_spawned)
	battle_manager.facility_destroyed.connect(_on_facility_destroyed)

	battle_input.crew_selected.connect(_on_crew_selected)
	battle_input.crew_deselected.connect(_on_crew_deselected)

	# 씬 데이터에서 스테이션 정보 로드
	_setup_battle()


func _setup_battle() -> void:
	var station_data: Dictionary = SceneManager.scene_data.get("station", {})
	var run := GameState.get_current_run()

	if run == null:
		push_error("No active run!")
		return

	# 스테이션 데이터 설정
	station_data["turn"] = run.turn
	station_data["difficulty"] = run.difficulty

	# 크루 데이터
	var crews := GameState.get_alive_crews()

	# 전투 매니저 초기화
	battle_manager.initialize(station_data, crews)

	# 타일 렌더러 설정
	tile_renderer.setup(battle_manager.grid)

	# 입력 핸들러 설정
	battle_input.setup(battle_manager, tile_renderer, camera)

	# 카메라 경계 설정
	camera.set_bounds_from_grid(
		battle_manager.grid.width,
		battle_manager.grid.height,
		Vector2(TileRenderer.TILE_WIDTH, TileRenderer.TILE_HEIGHT)
	)

	# 카메라를 맵 중앙으로
	var center := tile_renderer.grid_to_screen(Vector2i(
		battle_manager.grid.width / 2,
		battle_manager.grid.height / 2
	))
	camera.move_to(center, true)

	# HUD 업데이트
	_update_hud()
	_update_raven_buttons()
	_update_crew_panel()

	# 전투 시작
	await get_tree().create_timer(1.0).timeout
	battle_manager.start_battle()


# ===========================================
# HUD 업데이트
# ===========================================

func _update_hud() -> void:
	if battle_manager == null:
		return

	var wave_count := battle_manager.waves.size()
	wave_label.text = "Wave: %d/%d" % [battle_manager.current_wave_index + 1, wave_count]
	enemies_label.text = "Enemies: %d" % battle_manager.enemy_units.size()

	# 시설 체력
	var total_health := 0
	var max_health := 0
	for facility in battle_manager.grid.facilities:
		total_health += facility.get("health", 0)
		max_health += facility.get("max_health", 100)

	var health_percent := 100 if max_health == 0 else int(float(total_health) / float(max_health) * 100)
	facility_label.text = "Facility: %d%%" % health_percent


func _update_raven_buttons() -> void:
	var run := GameState.get_current_run()
	if run == null:
		return

	var abilities: Dictionary = run.raven_abilities

	# 스카웃 (무제한)
	scout_button.text = "SCOUT"
	scout_button.disabled = false

	# 플레어
	var flare_uses: int = abilities.get("flare", 0)
	flare_button.text = "FLARE (%d)" % flare_uses
	flare_button.disabled = flare_uses <= 0

	# 보급
	var resupply_uses: int = abilities.get("resupply", 0)
	resupply_button.text = "RESUPPLY (%d)" % resupply_uses
	resupply_button.disabled = resupply_uses <= 0

	# 궤도 타격
	var orbital_uses: int = abilities.get("orbital_strike", 0)
	orbital_button.text = "ORBITAL (%d)" % orbital_uses
	orbital_button.disabled = orbital_uses <= 0


func _update_crew_panel() -> void:
	# 기존 아이템 제거
	for child in crew_panel.get_children():
		if child is Button:
			child.queue_free()

	# 크루 버튼 추가
	for crew in battle_manager.crew_units:
		var btn := Button.new()
		btn.text = "%s (%d/%d)" % [crew.unit_name, crew.squad_size, crew.max_squad_size]
		btn.custom_minimum_size = Vector2(150, 30)
		btn.pressed.connect(_on_crew_button_pressed.bind(crew))
		crew_panel.add_child(btn)


# ===========================================
# 이벤트 핸들러
# ===========================================

func _on_wave_started(wave_index: int, total: int) -> void:
	_update_hud()
	EventBus.show_toast("Wave %d/%d" % [wave_index + 1, total], "info")


func _on_wave_cleared(wave_index: int) -> void:
	_update_hud()
	EventBus.show_toast("Wave Cleared!", "success")


func _on_battle_ended(is_victory: bool, rewards: Dictionary) -> void:
	# 크루 데이터 동기화
	var crew_data := battle_manager.sync_crew_data()
	for i in range(mini(crew_data.size(), GameState.current_run.crews.size())):
		GameState.current_run.crews[i] = crew_data[i]

	if is_victory:
		GameState.record_station_defended(rewards.get("total", 0), rewards.get("is_perfect", false))
		GameState.record_enemies_killed(battle_manager.stats.get("enemies_killed", 0))
		GameState.advance_turn()

		# 보상 표시
		EventBus.show_toast("+%d Credits!" % rewards.get("total", 0), "success")

		await get_tree().create_timer(2.0).timeout
		SceneManager.go_to_sector_map()
	else:
		# 모든 시설 파괴 또는 모든 크루 전멸
		var alive_count := GameState.get_alive_crews().size()
		if alive_count == 0:
			GameState.end_run(false)
			await get_tree().create_timer(2.0).timeout
			SceneManager.go_to_game_over()
		else:
			GameState.advance_turn()
			await get_tree().create_timer(2.0).timeout
			SceneManager.go_to_sector_map()


func _on_enemy_spawned(_enemy: EnemyUnit) -> void:
	_update_hud()


func _on_facility_destroyed(_pos: Vector2i) -> void:
	_update_hud()
	EventBus.show_toast("Facility Destroyed!", "danger")
	tile_renderer.queue_redraw()


func _on_crew_selected(crew: CrewUnit) -> void:
	_update_crew_panel()


func _on_crew_deselected() -> void:
	_update_crew_panel()


func _on_crew_button_pressed(crew: CrewUnit) -> void:
	if crew.is_alive:
		battle_input._select_crew(crew)
		camera.focus_on(crew)


# ===========================================
# Raven 능력
# ===========================================

func _on_scout_pressed() -> void:
	# 스카웃: 시야 확장 (구현 단순화)
	EventBus.show_toast("Scout activated", "info")
	EventBus.raven_scout_revealed.emit(Rect2i(0, 0, battle_manager.grid.width, battle_manager.grid.height))


func _on_flare_pressed() -> void:
	battle_input.start_raven_targeting("flare")


func _on_resupply_pressed() -> void:
	# 선택된 크루에게 보급
	var selected := battle_input.get_selected_crew()
	if selected:
		selected.squad_size = selected.max_squad_size
		GameState.current_run.raven_abilities["resupply"] -= 1
		_update_raven_buttons()
		EventBus.show_toast("Resupply delivered!", "success")
		EventBus.raven_resupply_delivered.emit(selected)
	else:
		EventBus.show_toast("Select a crew first", "warning")


func _on_orbital_pressed() -> void:
	battle_input.start_raven_targeting("orbital_strike")


# ===========================================
# 일시정지
# ===========================================

func _on_pause_pressed() -> void:
	battle_manager.toggle_pause()
	pause_button.text = "RESUME" if battle_manager.is_paused else "PAUSE"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_pause_pressed()
