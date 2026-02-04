extends Node3D

## 3D 전투 씬 컨트롤러
## Bad North 스타일 아이소메트릭 전투

# ===== REFERENCES =====

@onready var battle_map: Node3D = $BattleMap3D
@onready var battle_controller: Node = $BattleController
@onready var placement_phase: Node = $PlacementPhase
@onready var camera: Camera3D = $IsometricCamera

# UI References
@onready var wave_label: Label = $UI/BattleHUD/TopBar/WaveLabel
@onready var enemy_count_label: Label = $UI/BattleHUD/TopBar/EnemyCount
@onready var credits_label: Label = $UI/BattleHUD/TopBar/CreditsLabel
@onready var crew_slots: HBoxContainer = $UI/BattleHUD/BottomPanel/HBox/MarginLeft/CrewSlots
@onready var deploy_button: Button = $UI/BattleHUD/DeployButton
@onready var placement_label: Label = $UI/BattleHUD/PlacementLabel
@onready var pause_overlay: ColorRect = $UI/PauseOverlay
@onready var resume_btn: Button = $UI/PauseOverlay/ResumeBtn
@onready var menu_btn: Button = $UI/PauseOverlay/MenuBtn

# Raven buttons
@onready var scout_btn: Button = $UI/BattleHUD/BottomPanel/HBox/RavenPanel/RavenButtons/ScoutBtn
@onready var flare_btn: Button = $UI/BattleHUD/BottomPanel/HBox/RavenPanel/RavenButtons/FlareBtn
@onready var resupply_btn: Button = $UI/BattleHUD/BottomPanel/HBox/RavenPanel/RavenButtons/ResupplyBtn
@onready var orbital_btn: Button = $UI/BattleHUD/BottomPanel/HBox/RavenPanel/RavenButtons/OrbitalBtn


# ===== STATE =====

var _crews: Array = []
var _enemies: Array = []
var _selected_crew: Node3D = null
var _is_paused: bool = false
var _is_placement_phase: bool = true
var _wave_number: int = 0
var _total_waves: int = 5


# ===== LIFECYCLE =====

func _ready() -> void:
	_connect_signals()
	_setup_ui()
	call_deferred("_initialize_battle")


func _connect_signals() -> void:
	# Battle map signals
	if battle_map:
		battle_map.tile_clicked.connect(_on_tile_clicked)
		battle_map.tile_hovered.connect(_on_tile_hovered)

	# Placement phase signals
	if placement_phase:
		placement_phase.placement_ended.connect(_on_placement_ended)
		placement_phase.crew_placed.connect(_on_crew_placed)

	# UI buttons
	if deploy_button:
		deploy_button.pressed.connect(_on_deploy_pressed)
	if resume_btn:
		resume_btn.pressed.connect(_toggle_pause)
	if menu_btn:
		menu_btn.pressed.connect(_return_to_menu)

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

	# 배치 페이즈 UI
	if deploy_button:
		deploy_button.visible = true
	if placement_label:
		placement_label.visible = true


func _initialize_battle() -> void:
	print("[Battle3D] Initializing...")

	# 맵 생성
	_create_test_map()

	# 크루 생성
	_spawn_test_crews()

	# 배치 페이즈 시작
	_start_placement_phase()

	# 카메라 중앙 이동
	if camera and camera.has_method("center_on_map"):
		camera.center_on_map(15, 12, 1.0)

	print("[Battle3D] Initialized! Crews: %d" % _crews.size())


func _create_test_map() -> void:
	if battle_map == null:
		return

	# TileGrid가 없으면 맵 크기만 설정
	battle_map.set_map_size(15, 12)
	battle_map.rebuild_map()

	# 테스트 시설 배치
	battle_map.spawn_facility(Vector2i(7, 6), "power_plant")
	battle_map.spawn_facility(Vector2i(3, 4), "armory")
	battle_map.spawn_facility(Vector2i(11, 8), "medical")


func _spawn_test_crews() -> void:
	if battle_map == null:
		return

	var crew_classes := ["guardian", "ranger", "engineer"]
	var spawn_positions := [
		Vector2i(5, 6),
		Vector2i(6, 7),
		Vector2i(7, 8)
	]

	for i in range(crew_classes.size()):
		var crew := battle_map.spawn_crew(spawn_positions[i], crew_classes[i])
		if crew:
			crew.set_meta("index", i)
			_crews.append(crew)
			_create_crew_slot_ui(crew, i)


func _start_placement_phase() -> void:
	_is_placement_phase = true

	if placement_label:
		placement_label.visible = true
	if deploy_button:
		deploy_button.visible = true

	# 배치 페이즈 시작
	if placement_phase:
		var spawn_area: Array[Vector2i] = []
		# 맵 중앙 영역
		for y in range(3, 10):
			for x in range(3, 12):
				spawn_area.append(Vector2i(x, y))

		placement_phase.initialize(battle_map, null, battle_controller)
		placement_phase.start_pre_battle_placement(_crews, spawn_area)


func _create_crew_slot_ui(crew: Node3D, index: int) -> void:
	if crew_slots == null:
		return

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(100, 90)

	var vbox := VBoxContainer.new()
	slot.add_child(vbox)

	# 클래스 이름 - CrewSquad3D의 속성 또는 메타 사용
	var class_id: String = ""
	if crew.has_method("get_class_id"):
		class_id = crew.get_class_id()
	elif "class_id" in crew:
		class_id = crew.class_id
	else:
		class_id = crew.get_meta("class_id", "unknown")
	var name_label := Label.new()
	name_label.text = "[%d] %s" % [index + 1, class_id.to_upper()]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# HP 바
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(90, 12)
	hp_bar.value = 100
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	# 스킬 버튼
	var skill_btn := Button.new()
	skill_btn.text = "Q: Skill"
	skill_btn.custom_minimum_size = Vector2(90, 30)
	skill_btn.pressed.connect(func(): _use_crew_skill(crew))
	vbox.add_child(skill_btn)

	# 클릭으로 선택
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_crew(crew)
	)

	slot.set_meta("crew", crew)
	crew_slots.add_child(slot)


func _process(_delta: float) -> void:
	if _is_paused:
		return

	_update_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if _is_paused:
					_toggle_pause()
				else:
					_toggle_pause()
			KEY_SPACE:
				if not _is_placement_phase:
					_toggle_pause()
			KEY_1:
				_select_crew_by_index(0)
			KEY_2:
				_select_crew_by_index(1)
			KEY_3:
				_select_crew_by_index(2)
			KEY_4:
				_select_crew_by_index(3)
			KEY_Q:
				if _selected_crew:
					_use_crew_skill(_selected_crew)


func _update_ui() -> void:
	# 웨이브 표시
	if wave_label:
		if _is_placement_phase:
			wave_label.text = "PLACEMENT PHASE"
		else:
			wave_label.text = "WAVE %d/%d" % [_wave_number, _total_waves]

	# 적 수
	if enemy_count_label:
		enemy_count_label.text = "Enemies: %d" % _enemies.size()

	# 크레딧
	if credits_label and GameState:
		credits_label.text = "Credits: %d" % GameState.get_credits()


# ===== SELECTION =====

func _select_crew(crew: Node3D) -> void:
	# 이전 선택 해제
	if _selected_crew and is_instance_valid(_selected_crew):
		if _selected_crew.has_method("deselect"):
			_selected_crew.deselect()
		else:
			_set_crew_highlight(_selected_crew, false)

	_selected_crew = crew

	if crew:
		if crew.has_method("select"):
			crew.select()
		else:
			_set_crew_highlight(crew, true)

		var class_id: String = crew.get_class_id() if crew.has_method("get_class_id") else crew.get_meta("class_id", "unknown")
		print("[Battle3D] Selected: ", class_id)

		# 배치 페이즈가 아니면 이동 범위 표시
		if not _is_placement_phase and placement_phase:
			placement_phase.start_reposition_mode(crew)


func _select_crew_by_index(index: int) -> void:
	if index < _crews.size():
		_select_crew(_crews[index])


func _set_crew_highlight(crew: Node3D, highlighted: bool) -> void:
	# 하이라이트 효과 (스케일 변경 또는 색상 변경)
	if highlighted:
		crew.scale = Vector3(1.2, 1.2, 1.2)
	else:
		crew.scale = Vector3(1.0, 1.0, 1.0)


# ===== TILE EVENTS =====

func _on_tile_clicked(tile_pos: Vector2i) -> void:
	print("[Battle3D] Tile clicked: ", tile_pos)

	if _is_placement_phase:
		# 배치 페이즈에서는 placement_phase가 처리
		return

	if _selected_crew:
		# 선택된 크루 이동
		_move_crew_to(tile_pos)


func _on_tile_hovered(tile_pos: Vector2i) -> void:
	pass  # 호버 효과는 BattleMap3D에서 처리


# ===== MOVEMENT =====

func _move_crew_to(tile_pos: Vector2i) -> void:
	if _selected_crew == null:
		return

	# CrewSquad3D의 command_move() 메서드 활용
	if _selected_crew.has_method("command_move"):
		_selected_crew.command_move(tile_pos)
	else:
		# 폴백: 직접 이동
		var world_pos: Vector3 = battle_map.tile_to_world(tile_pos) if battle_map else Vector3(tile_pos.x, 0, tile_pos.y)
		var tween := create_tween()
		tween.tween_property(_selected_crew, "position", world_pos, 0.3).set_trans(Tween.TRANS_QUAD)
		_selected_crew.set_meta("tile_pos", tile_pos)


# ===== PLACEMENT =====

func _on_deploy_pressed() -> void:
	if placement_phase and placement_phase.confirm_placement():
		_start_combat()


func _on_placement_ended() -> void:
	pass  # 배치 종료는 _start_combat에서 처리


func _on_crew_placed(crew: Node, tile_pos: Vector2i) -> void:
	print("[Battle3D] Crew placed at: ", tile_pos)


func _start_combat() -> void:
	_is_placement_phase = false

	if placement_label:
		placement_label.visible = false
	if deploy_button:
		deploy_button.visible = false

	# 첫 웨이브 시작
	_wave_number = 1
	_spawn_wave_enemies()

	print("[Battle3D] Combat started!")


# ===== ENEMIES =====

func _spawn_wave_enemies() -> void:
	if battle_map == null:
		return

	var enemy_count := 3 + _wave_number * 2

	# 맵 가장자리에서 스폰
	var spawn_positions := [
		Vector2i(0, 6),
		Vector2i(14, 6),
		Vector2i(7, 0),
		Vector2i(7, 11)
	]

	for i in range(enemy_count):
		var spawn_pos := spawn_positions[i % spawn_positions.size()]
		spawn_pos += Vector2i(randi() % 3 - 1, randi() % 3 - 1)

		var enemy := battle_map.spawn_enemy(spawn_pos, "rusher")
		if enemy:
			_enemies.append(enemy)

			# EnemyUnit3D의 set_target()으로 AI 활성화
			if enemy.has_method("set_target") and not _crews.is_empty():
				# 가장 가까운 크루 또는 시설을 타겟으로 설정
				var closest_target: Node = _find_closest_target(enemy)
				if closest_target:
					enemy.set_target(closest_target)

	print("[Battle3D] Spawned %d enemies" % enemy_count)


func _find_closest_target(enemy: Node3D) -> Node:
	var closest: Node = null
	var min_dist: float = INF

	# 크루 중 가장 가까운 타겟
	for crew in _crews:
		if is_instance_valid(crew):
			var alive: bool = true
			if "is_alive" in crew:
				alive = crew.is_alive
			if alive:
				var dist: float = enemy.global_position.distance_to(crew.global_position)
				if dist < min_dist:
					min_dist = dist
					closest = crew

	return closest


# ===== SKILLS =====

func _use_crew_skill(crew: Node3D) -> void:
	if crew == null:
		return

	var class_id: String = crew.get_class_id() if crew.has_method("get_class_id") else crew.get_meta("class_id", "unknown")

	# CrewSquad3D의 use_skill() 메서드 호출
	if crew.has_method("use_skill"):
		var success: bool = crew.use_skill()
		if success:
			print("[Battle3D] Skill activated: ", class_id)
		else:
			print("[Battle3D] Skill on cooldown: ", class_id)
	else:
		print("[Battle3D] Skill used: ", class_id)


func _use_raven_ability(ability: int) -> void:
	print("[Battle3D] Raven ability: ", ability)

	# TODO: Raven 시스템 연동


# ===== PAUSE =====

func _toggle_pause() -> void:
	_is_paused = not _is_paused

	if pause_overlay:
		pause_overlay.visible = _is_paused

	get_tree().paused = _is_paused


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
