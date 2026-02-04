extends Node2D

## 전투 씬 컨트롤러
## BattleController, WaveManager, TileGrid를 초기화하고 연결

@onready var battle_controller: BattleController = $BattleController
@onready var tile_grid: TileGrid = $TileGridContainer/TileGrid
@onready var wave_manager: WaveManager = $Systems/WaveManager
@onready var crews_container: Node2D = $EntityContainer/Crews
@onready var enemies_container: Node2D = $EntityContainer/Enemies
@onready var camera: Camera2D = $Camera2D

# UI
@onready var wave_label: Label = $UI/BattleHUD/TopBar/MarginLeft/WaveLabel
@onready var enemy_count_label: Label = $UI/BattleHUD/TopBar/EnemyCountLabel
@onready var crew_slots: HBoxContainer = $UI/BattleHUD/BottomBar/MarginLeft/CrewSlots
@onready var pause_overlay: ColorRect = $UI/PauseOverlay
@onready var resume_btn: Button = $UI/PauseOverlay/ResumeBtn
@onready var menu_btn: Button = $UI/PauseOverlay/MenuBtn

# Raven buttons
@onready var scout_btn: Button = $UI/BattleHUD/BottomBar/RavenPanel/RavenButtons/ScoutBtn
@onready var flare_btn: Button = $UI/BattleHUD/BottomBar/RavenPanel/RavenButtons/FlareBtn
@onready var resupply_btn: Button = $UI/BattleHUD/BottomBar/RavenPanel/RavenButtons/ResupplyBtn
@onready var orbital_btn: Button = $UI/BattleHUD/BottomBar/RavenPanel/RavenButtons/OrbitalBtn

var _is_initialized: bool = false


func _ready() -> void:
	_connect_signals()
	_setup_ui()
	call_deferred("_initialize_battle")


func _connect_signals() -> void:
	# Battle controller signals
	if battle_controller:
		battle_controller.battle_ended.connect(_on_battle_ended)
		battle_controller.pause_state_changed.connect(_on_pause_changed)
		battle_controller.wave_progress_changed.connect(_on_wave_progress_changed)
		battle_controller.selection_changed.connect(_on_selection_changed)

	# Wave manager signals
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_ended.connect(_on_wave_ended)
		wave_manager.enemy_spawned.connect(_on_enemy_spawned)

	# UI buttons
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)

	# Raven buttons
	if scout_btn:
		scout_btn.pressed.connect(func(): _use_raven_ability(Constants.RavenAbility.SCOUT))
	if flare_btn:
		flare_btn.pressed.connect(func(): _use_raven_ability(Constants.RavenAbility.FLARE))
	if resupply_btn:
		resupply_btn.pressed.connect(func(): _use_raven_ability(Constants.RavenAbility.RESUPPLY))
	if orbital_btn:
		orbital_btn.pressed.connect(func(): _use_raven_ability(Constants.RavenAbility.ORBITAL_STRIKE))


func _setup_ui() -> void:
	if pause_overlay:
		pause_overlay.visible = false


func _initialize_battle() -> void:
	if _is_initialized:
		return

	print("[BattleScene] Initializing battle...")

	# 1. 타일 그리드 초기화
	_setup_tile_grid()

	# 2. 웨이브 매니저 초기화
	_setup_wave_manager()

	# 3. 크루 데이터 가져오기
	var crew_data_list: Array = _get_crew_data()

	# 4. 스테이션 데이터 생성
	var station_data: Dictionary = _create_station_data()

	# 5. BattleController 설정
	if battle_controller:
		battle_controller.tile_grid = tile_grid
		battle_controller.wave_manager = wave_manager

	# 6. 전투 시작
	if battle_controller:
		battle_controller.start_battle(station_data, crew_data_list)

	# 7. 웨이브 시작
	_start_waves(station_data)

	# 8. 카메라 위치 조정
	_setup_camera()

	# 9. 크루 슬롯 UI 생성
	_create_crew_slot_ui()

	_is_initialized = true
	print("[BattleScene] Battle initialized! Crews: %d" % crew_data_list.size())


func _setup_tile_grid() -> void:
	if tile_grid == null:
		push_warning("[BattleScene] TileGrid not found")
		return

	# 기본 그리드 초기화 (20x15)
	tile_grid.initialize(20, 15)

	# 진입점 설정 (맵 가장자리)
	var entry_points: Array[Vector2i] = [
		Vector2i(0, 7),   # 왼쪽
		Vector2i(19, 7),  # 오른쪽
		Vector2i(10, 0),  # 위쪽
		Vector2i(10, 14)  # 아래쪽
	]

	for entry in entry_points:
		var tile = tile_grid.get_tile(entry)
		if tile:
			tile.is_entry_point = true


func _setup_wave_manager() -> void:
	if wave_manager == null:
		push_warning("[BattleScene] WaveManager not found")
		return

	if tile_grid and battle_controller:
		wave_manager.initialize(tile_grid, battle_controller, GameState.current_difficulty if GameState else Constants.Difficulty.NORMAL)


func _get_crew_data() -> Array:
	# GameState에서 크루 데이터 가져오기
	if GameState:
		var crews = GameState.get_crews()
		if not crews.is_empty():
			return crews

	# 기본 테스트 크루
	return [
		{"id": "crew_1", "class_id": "guardian", "rank": 1, "skill_level": 1, "equipment_id": "", "trait_id": ""},
		{"id": "crew_2", "class_id": "ranger", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""},
		{"id": "crew_3", "class_id": "engineer", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""}
	]


func _create_station_data() -> Dictionary:
	# 기본 스테이션 데이터
	var station_depth: int = 1
	if GameState and GameState.current_run.has("current_depth"):
		station_depth = GameState.current_run.current_depth

	return {
		"width": 20,
		"height": 15,
		"depth": station_depth,
		"entry_points": [
			Vector2i(0, 7),
			Vector2i(19, 7),
			Vector2i(10, 0),
			Vector2i(10, 14)
		],
		"facilities": [
			{"position": Vector2i(10, 7), "data": {"id": "power_plant", "credits": 5}},
			{"position": Vector2i(5, 5), "data": {"id": "armory", "credits": 3}},
			{"position": Vector2i(15, 10), "data": {"id": "medical", "credits": 4}}
		]
	}


func _start_waves(station_data: Dictionary) -> void:
	if wave_manager == null:
		return

	var entry_points: Array[Vector2i] = []
	for entry in station_data.get("entry_points", []):
		entry_points.append(entry)

	var station_depth: int = station_data.get("depth", 1)
	var seed_value: int = GameState.current_seed if GameState else randi()

	wave_manager.setup_waves(station_depth, entry_points, seed_value)
	wave_manager.start_next_wave()


func _setup_camera() -> void:
	if camera == null:
		return

	# 맵 중앙으로 카메라 이동
	var center_x: float = tile_grid.width * Constants.TILE_SIZE / 2.0 if tile_grid else 320.0
	var center_y: float = tile_grid.height * Constants.TILE_SIZE / 2.0 if tile_grid else 240.0

	camera.position = Vector2(center_x, center_y)
	camera.zoom = Vector2(1.2, 1.2)


func _create_crew_slot_ui() -> void:
	if crew_slots == null:
		return

	# 기존 슬롯 제거
	for child in crew_slots.get_children():
		child.queue_free()

	# 크루별 슬롯 생성
	var crews: Array = battle_controller.crews if battle_controller else []
	for i in range(crews.size()):
		var crew = crews[i]
		var slot := _create_crew_slot(crew, i)
		crew_slots.add_child(slot)


func _create_crew_slot(crew: Node, index: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(100, 80)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(vbox)

	# 클래스 이름
	var class_id: String = "Unknown"
	if "class_id" in crew:
		class_id = crew.class_id
	elif crew.has_meta("class_id"):
		class_id = crew.get_meta("class_id")

	var name_label := Label.new()
	name_label.text = "[%d] %s" % [index + 1, class_id.to_upper()]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# HP 바
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(90, 10)
	hp_bar.value = 100
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	# 스킬 버튼
	var skill_btn := Button.new()
	skill_btn.text = "Q: Skill"
	skill_btn.custom_minimum_size = Vector2(90, 25)
	skill_btn.pressed.connect(func(): _use_crew_skill(crew))
	vbox.add_child(skill_btn)

	# 선택 버튼
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if battle_controller:
				battle_controller.select_squad(crew)
	)

	return slot


func _process(_delta: float) -> void:
	_update_ui()


func _update_ui() -> void:
	# 적 수 업데이트
	if enemy_count_label and wave_manager:
		enemy_count_label.text = "Enemies: %d" % wave_manager.get_remaining_enemies()

	# Raven 버튼 상태 업데이트
	_update_raven_buttons()


func _update_raven_buttons() -> void:
	if GameState == null:
		return

	if scout_btn:
		var charges = GameState.get_raven_charges(Constants.RavenAbility.SCOUT)
		scout_btn.text = "Scout" if charges < 0 else "Scout (%d)" % charges
		scout_btn.disabled = charges == 0

	if flare_btn:
		var charges = GameState.get_raven_charges(Constants.RavenAbility.FLARE)
		flare_btn.text = "Flare (%d)" % charges
		flare_btn.disabled = charges == 0

	if resupply_btn:
		var charges = GameState.get_raven_charges(Constants.RavenAbility.RESUPPLY)
		resupply_btn.text = "Supply (%d)" % charges
		resupply_btn.disabled = charges == 0

	if orbital_btn:
		var charges = GameState.get_raven_charges(Constants.RavenAbility.ORBITAL_STRIKE)
		orbital_btn.text = "Strike (%d)" % charges
		orbital_btn.disabled = charges == 0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if battle_controller and battle_controller.is_paused:
					_on_resume_pressed()
				else:
					_show_pause_menu()
			KEY_Q:
				_use_selected_crew_skill()
			KEY_1:
				_select_crew_by_index(0)
			KEY_2:
				_select_crew_by_index(1)
			KEY_3:
				_select_crew_by_index(2)
			KEY_4:
				_select_crew_by_index(3)


func _select_crew_by_index(index: int) -> void:
	if battle_controller == null:
		return

	if index < battle_controller.crews.size():
		battle_controller.select_squad(battle_controller.crews[index])


func _use_selected_crew_skill() -> void:
	if battle_controller == null or battle_controller.selected_squad == null:
		return

	var crew = battle_controller.selected_squad
	if crew.has_method("can_use_skill") and crew.can_use_skill():
		if crew.has_method("use_skill"):
			crew.use_skill(null)  # 타겟 없이 사용 (스킬에 따라 다름)


func _use_crew_skill(crew: Node) -> void:
	if crew.has_method("can_use_skill") and crew.can_use_skill():
		if crew.has_method("use_skill"):
			crew.use_skill(null)


func _use_raven_ability(ability: int) -> void:
	if battle_controller and battle_controller.raven_system:
		battle_controller.start_raven_targeting(ability)


func _show_pause_menu() -> void:
	if battle_controller:
		battle_controller.toggle_pause()


# ===== SIGNAL HANDLERS =====

func _on_battle_ended(result: BattleController.BattleResult) -> void:
	print("[BattleScene] Battle ended! Victory: %s, Credits: %d" % [result.victory, result.credits_earned])

	# GameState에 결과 저장
	if GameState:
		var stage_result := {
			"victory": result.victory,
			"enemies_killed": result.enemies_killed,
			"facilities_saved": result.facilities_saved,
			"facilities_total": result.facilities_total,
			"credits_earned": result.credits_earned,
			"crew_results": []
		}
		GameState.end_stage(stage_result)

	# 결과 화면 표시 후 캠페인으로 복귀
	await get_tree().create_timer(2.0).timeout

	if result.victory:
		_return_to_campaign()
	else:
		_show_game_over()


func _on_pause_changed(is_paused: bool) -> void:
	if pause_overlay:
		pause_overlay.visible = is_paused


func _on_wave_progress_changed(current: int, total: int) -> void:
	if wave_label:
		wave_label.text = "Wave %d/%d" % [current, total]


func _on_selection_changed(selected: Node) -> void:
	# 선택된 크루 강조
	for crew in battle_controller.crews:
		if crew.has_method("set_selected"):
			crew.set_selected(crew == selected)


func _on_wave_started(wave_num: int) -> void:
	print("[BattleScene] Wave %d started!" % wave_num)
	if wave_label and wave_manager:
		wave_label.text = "Wave %d/%d" % [wave_num, wave_manager.get_total_waves()]


func _on_wave_ended(wave_num: int) -> void:
	print("[BattleScene] Wave %d cleared!" % wave_num)


func _on_enemy_spawned(enemy: Node) -> void:
	# 적이 올바른 컨테이너에 있는지 확인
	if enemy.get_parent() != enemies_container:
		enemy.reparent(enemies_container)


func _on_resume_pressed() -> void:
	if battle_controller:
		battle_controller.toggle_pause()


func _on_menu_pressed() -> void:
	# 전투 종료하고 메인 메뉴로
	if GameState:
		GameState.end_run(false)
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")


func _return_to_campaign() -> void:
	var campaign_scene := "res://scenes/campaign/Campaign.tscn"
	if ResourceLoader.exists(campaign_scene):
		get_tree().change_scene_to_file(campaign_scene)
	else:
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")


func _show_game_over() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "GAME OVER"
	dialog.dialog_text = "Your crew has been wiped out."
	dialog.dialog_hide_on_ok = true
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)
