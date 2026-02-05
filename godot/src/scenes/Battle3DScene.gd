extends Node3D

## 3D 전투 씬 컨트롤러
## Bad North 스타일 아이소메트릭 전투
## 드롭팟 스폰 시스템 통합

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


# ===== SPAWN CONTROLLER =====

var _spawn_controller: SpawnController3D


# ===== STATE =====

var _crews: Array = []
var _enemies: Array = []
var _selected_crew: Node3D = null
var _is_paused: bool = false
var _is_placement_phase: bool = true
var _wave_number: int = 0
var _total_waves: int = 5
var _use_drop_pods: bool = true  # 드롭팟 사용 여부


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_spawn_controller()
	_setup_effects_manager()
	_connect_signals()
	_setup_ui()
	call_deferred("_initialize_battle")


func _setup_spawn_controller() -> void:
	_spawn_controller = SpawnController3D.new()
	_spawn_controller.name = "SpawnController3D"
	add_child(_spawn_controller)

	_spawn_controller.enemies_spawned.connect(_on_enemies_spawned)
	_spawn_controller.drop_pod_approaching.connect(_on_pod_approaching)
	_spawn_controller.drop_pod_landed.connect(_on_pod_landed)
	_spawn_controller.wave_spawn_complete.connect(_on_wave_spawn_complete)


func _setup_effects_manager() -> void:
	# 이펙트 매니저에 컨테이너 설정
	if EffectsManager3D and battle_map:
		var effects_container := battle_map.get_node_or_null("Effects")
		if effects_container == null:
			effects_container = Node3D.new()
			effects_container.name = "Effects"
			battle_map.add_child(effects_container)
		EffectsManager3D.set_effects_container(effects_container)


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

	if deploy_button:
		deploy_button.visible = true
	if placement_label:
		placement_label.visible = true


func _initialize_battle() -> void:
	print("[Battle3D] Initializing...")

	_create_test_map()
	_spawn_test_crews()

	# 스폰 컨트롤러에 배틀맵 설정
	if _spawn_controller and battle_map:
		_spawn_controller.set_battle_map(battle_map)

	_start_placement_phase()

	if camera and camera.has_method("center_on_map"):
		camera.center_on_map(15, 12, 1.0)

	print("[Battle3D] Initialized! Crews: %d" % _crews.size())


func _create_test_map() -> void:
	if battle_map == null:
		return

	battle_map.set_map_size(15, 12)
	battle_map.rebuild_map()

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
		var crew: Node3D = battle_map.spawn_crew(spawn_positions[i], crew_classes[i])
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

	if placement_phase:
		var spawn_area: Array[Vector2i] = []
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

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(90, 12)
	hp_bar.value = 100
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	var skill_btn := Button.new()
	skill_btn.text = "Q: Skill"
	skill_btn.custom_minimum_size = Vector2(90, 30)
	skill_btn.pressed.connect(func(): _use_crew_skill(crew))
	vbox.add_child(skill_btn)

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
	_check_wave_completion()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
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
	if wave_label:
		if _is_placement_phase:
			wave_label.text = "PLACEMENT PHASE"
		else:
			var pending := _spawn_controller.get_pending_pod_count() if _spawn_controller else 0
			if pending > 0:
				wave_label.text = "WAVE %d/%d (Incoming: %d)" % [_wave_number, _total_waves, pending]
			else:
				wave_label.text = "WAVE %d/%d" % [_wave_number, _total_waves]

	if enemy_count_label:
		var alive_enemies := _enemies.filter(func(e): return is_instance_valid(e) and e.get("is_alive", true))
		enemy_count_label.text = "Enemies: %d" % alive_enemies.size()

	if credits_label and GameState:
		credits_label.text = "Credits: %d" % GameState.get_credits()


func _check_wave_completion() -> void:
	if _is_placement_phase:
		return

	# 살아있는 적 확인
	var alive_enemies := _enemies.filter(func(e):
		return is_instance_valid(e) and (not "is_alive" in e or e.is_alive)
	)

	# 모든 적 처치 + 팟 없음
	var pending_pods := _spawn_controller.get_pending_pod_count() if _spawn_controller else 0
	if alive_enemies.is_empty() and pending_pods == 0:
		_on_wave_cleared()


# ===== SELECTION =====

func _select_crew(crew: Node3D) -> void:
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

		if not _is_placement_phase and placement_phase:
			placement_phase.start_reposition_mode(crew)


func _select_crew_by_index(index: int) -> void:
	if index < _crews.size():
		_select_crew(_crews[index])


func _set_crew_highlight(crew: Node3D, highlighted: bool) -> void:
	if highlighted:
		crew.scale = Vector3(1.2, 1.2, 1.2)
	else:
		crew.scale = Vector3(1.0, 1.0, 1.0)


# ===== TILE EVENTS =====

func _on_tile_clicked(tile_pos: Vector2i) -> void:
	print("[Battle3D] Tile clicked: ", tile_pos)

	if _is_placement_phase:
		return

	if _selected_crew:
		_move_crew_to(tile_pos)


func _on_tile_hovered(_tile_pos: Vector2i) -> void:
	pass


# ===== MOVEMENT =====

func _move_crew_to(tile_pos: Vector2i) -> void:
	if _selected_crew == null:
		return

	if _selected_crew.has_method("command_move"):
		_selected_crew.command_move(tile_pos)
	else:
		var world_pos: Vector3 = battle_map.tile_to_world(tile_pos) if battle_map else Vector3(tile_pos.x, 0, tile_pos.y)
		var tween := create_tween()
		tween.tween_property(_selected_crew, "position", world_pos, 0.3).set_trans(Tween.TRANS_QUAD)
		_selected_crew.set_meta("tile_pos", tile_pos)


# ===== PLACEMENT =====

func _on_deploy_pressed() -> void:
	if placement_phase and placement_phase.confirm_placement():
		_start_combat()


func _on_placement_ended() -> void:
	pass


func _on_crew_placed(crew: Node, tile_pos: Vector2i) -> void:
	print("[Battle3D] Crew placed at: ", tile_pos)


func _start_combat() -> void:
	_is_placement_phase = false

	if placement_label:
		placement_label.visible = false
	if deploy_button:
		deploy_button.visible = false

	_wave_number = 1
	_spawn_wave_enemies()

	print("[Battle3D] Combat started!")


# ===== ENEMIES =====

func _spawn_wave_enemies() -> void:
	if battle_map == null:
		return

	var enemy_count := 3 + _wave_number * 2

	if _use_drop_pods and _spawn_controller:
		_spawn_wave_via_pods(enemy_count)
	else:
		_spawn_wave_direct(enemy_count)


func _spawn_wave_via_pods(enemy_count: int) -> void:
	# 맵 가장자리 진입점
	var entry_points := [
		Vector2i(0, 6),
		Vector2i(14, 6),
		Vector2i(7, 0),
		Vector2i(7, 11)
	]

	# 적을 그룹으로 나누어 드롭팟에 배치
	var groups_count := mini(4, ceili(float(enemy_count) / 3.0))
	var enemies_per_group := ceili(float(enemy_count) / float(groups_count))

	for i in range(groups_count):
		var entry_point := entry_points[i % entry_points.size()]
		# 약간의 랜덤 오프셋
		entry_point += Vector2i(randi() % 3 - 1, randi() % 3 - 1)

		var group_count := mini(enemies_per_group, enemy_count - i * enemies_per_group)
		if group_count > 0:
			_spawn_controller.spawn_enemy_group_via_pod("rusher", group_count, entry_point)

	print("[Battle3D] Spawning %d enemies via %d drop pods" % [enemy_count, groups_count])


func _spawn_wave_direct(enemy_count: int) -> void:
	# 기존 직접 스폰 방식 (폴백)
	var spawn_positions := [
		Vector2i(0, 6),
		Vector2i(14, 6),
		Vector2i(7, 0),
		Vector2i(7, 11)
	]

	for i in range(enemy_count):
		var spawn_pos: Vector2i = spawn_positions[i % spawn_positions.size()]
		spawn_pos += Vector2i(randi() % 3 - 1, randi() % 3 - 1)

		var enemy: Node3D = battle_map.spawn_enemy(spawn_pos, "rusher")
		if enemy:
			_enemies.append(enemy)
			_set_enemy_target(enemy)

	print("[Battle3D] Spawned %d enemies directly" % enemy_count)


func _set_enemy_target(enemy: Node3D) -> void:
	if enemy.has_method("set_target") and not _crews.is_empty():
		var closest_target: Node = _find_closest_target(enemy)
		if closest_target:
			enemy.set_target(closest_target)


func _on_enemies_spawned(enemies: Array) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			_enemies.append(enemy)
			_set_enemy_target(enemy)

	print("[Battle3D] %d enemies deployed from drop pod" % enemies.size())


func _on_pod_approaching(pod: Node3D, eta: float, target_tile: Vector2i) -> void:
	print("[Battle3D] Drop pod approaching tile %s, ETA: %.1f" % [target_tile, eta])


func _on_pod_landed(pod: Node3D, target_tile: Vector2i) -> void:
	print("[Battle3D] Drop pod landed at %s" % target_tile)


func _on_wave_spawn_complete() -> void:
	print("[Battle3D] All drop pods for wave %d deployed" % _wave_number)


func _on_wave_cleared() -> void:
	_enemies.clear()

	if _wave_number >= _total_waves:
		_on_battle_victory()
	else:
		_wave_number += 1
		print("[Battle3D] Wave %d starting..." % _wave_number)

		# 다음 웨이브 딜레이
		get_tree().create_timer(2.0).timeout.connect(_spawn_wave_enemies)


func _on_battle_victory() -> void:
	print("[Battle3D] Battle Victory!")

	if EventBus:
		EventBus.battle_ended.emit(true)


func _find_closest_target(enemy: Node3D) -> Node:
	var closest: Node = null
	var min_dist: float = INF

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

	if EventBus:
		EventBus.raven_ability_used.emit(ability)


# ===== PAUSE =====

func _toggle_pause() -> void:
	_is_paused = not _is_paused

	if pause_overlay:
		pause_overlay.visible = _is_paused

	get_tree().paused = _is_paused


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
