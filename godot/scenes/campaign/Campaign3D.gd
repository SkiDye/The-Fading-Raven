extends Node3D

## 3D 캠페인 씬 컨트롤러
## SectorMap3D와 게임 로직 연동

const SectorGeneratorClass = preload("res://src/systems/campaign/SectorGenerator.gd")

@onready var sector_map_3d = $SectorMap3D

var _sector_generator  # SectorGenerator
var _sector_data  # SectorGenerator.SectorData
var _current_node_id: String = ""
var _battles_since_storm: int = 0


func _ready() -> void:
	_connect_signals()
	call_deferred("_start_campaign")


func _connect_signals() -> void:
	if sector_map_3d:
		sector_map_3d.node_entered.connect(_on_node_entered)
		sector_map_3d.upgrade_requested.connect(_on_upgrade_requested)

	if EventBus:
		EventBus.battle_ended.connect(_on_battle_ended)


func _start_campaign() -> void:
	# 게임 상태 시작
	if GameState and not GameState.is_run_active():
		GameState.start_new_run(-1, Constants.Difficulty.NORMAL)

	# 섹터 맵 생성
	_sector_generator = SectorGeneratorClass.new()
	var seed_value: int = GameState.current_seed if GameState else randi()
	var difficulty: int = GameState.current_difficulty if GameState else Constants.Difficulty.NORMAL

	_sector_data = _sector_generator.generate(seed_value, difficulty)

	# 시작 노드 설정
	var start_node = _sector_data.get_start_node()
	if start_node:
		_current_node_id = start_node.id

	# 맵 업데이트
	_update_sector_map()

	# 테스트 크루 생성 (없으면)
	if GameState and GameState.get_crews().is_empty():
		_create_test_crews()

	print("[Campaign3D] Started! Seed: %d, Depth: %d" % [seed_value, _sector_data.total_depth])


func _update_sector_map() -> void:
	if sector_map_3d == null or _sector_data == null:
		return

	var map_data := _convert_sector_to_dict()
	sector_map_3d.setup(map_data)
	sector_map_3d.set_current_node(_current_node_id)
	sector_map_3d.set_storm_depth(_sector_data.storm_depth)
	sector_map_3d._update_ui()


func _convert_sector_to_dict() -> Dictionary:
	var nodes: Array = []

	for layer in _sector_data.layers:
		for node in layer:
			nodes.append({
				"id": node.id,
				"layer": node.layer,
				"x_position": node.x_position,
				"type": node.node_type,
				"connections_out": node.connections_out,
				"visited": node.visited,
				"difficulty_score": node.difficulty_score
			})

	return {
		"nodes": nodes,
		"total_depth": _sector_data.total_depth,
		"storm_depth": _sector_data.storm_depth
	}


func _create_test_crews() -> void:
	var test_crews := [
		{"id": "crew_1", "class_id": "guardian", "rank": 1, "skill_level": 1, "equipment_id": "", "trait_id": ""},
		{"id": "crew_2", "class_id": "ranger", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""},
		{"id": "crew_3", "class_id": "engineer", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""}
	]

	for crew_data in test_crews:
		if GameState:
			GameState.add_crew(crew_data)


func _on_node_entered(node_id: String) -> void:
	var node = _sector_data.get_node(node_id)
	if node == null:
		push_warning("[Campaign3D] Node not found: " + node_id)
		return

	# 이동 가능 여부 체크
	if not _can_move_to_node(node_id):
		print("[Campaign3D] Cannot move to node: " + node_id)
		return

	# 노드 이동
	_current_node_id = node_id
	node.visited = true
	_sector_data.current_node_id = node_id

	print("[Campaign3D] Entered node: %s (type: %d)" % [node_id, node.node_type])

	# 노드 타입에 따른 처리
	match node.node_type:
		Constants.NodeType.START:
			_update_sector_map()

		Constants.NodeType.BATTLE, Constants.NodeType.STORM, Constants.NodeType.BOSS:
			_enter_battle(node)

		Constants.NodeType.COMMANDER, Constants.NodeType.RESCUE:
			_enter_rescue_event(node)

		Constants.NodeType.EQUIPMENT, Constants.NodeType.SALVAGE:
			_enter_salvage_event(node)

		Constants.NodeType.DEPOT:
			_enter_depot_event(node)

		Constants.NodeType.REST:
			_enter_rest_event(node)

		Constants.NodeType.GATE:
			_enter_gate(node)

		_:
			_update_sector_map()


func _can_move_to_node(node_id: String) -> bool:
	var start_node = _sector_data.get_start_node()
	if start_node and _current_node_id == start_node.id:
		return true

	var current_node = _sector_data.get_node(_current_node_id)
	if current_node == null:
		return false

	return node_id in current_node.connections_out


func _enter_battle(node: Variant) -> void:
	if GameState:
		GameState.start_stage(node.id)

	print("[Campaign3D] Starting battle at node: " + node.id)

	# 3D 전투 씬으로 전환
	var battle_scene := "res://scenes/battle/Battle3D.tscn"
	if ResourceLoader.exists(battle_scene):
		get_tree().change_scene_to_file(battle_scene)
	else:
		push_warning("[Campaign3D] Battle3D.tscn not found")


func _enter_rescue_event(node: Variant) -> void:
	print("[Campaign3D] Rescue event at: " + node.id)
	_show_event_popup("Survivors Rescued!", "A new team leader has joined your crew.")
	node.consumed = true
	_update_sector_map()


func _enter_salvage_event(node: Variant) -> void:
	print("[Campaign3D] Salvage event at: " + node.id)
	_show_event_popup("Equipment Found!", "You salvaged useful equipment from the wreckage.")
	node.consumed = true
	_update_sector_map()


func _enter_depot_event(node: Variant) -> void:
	print("[Campaign3D] Depot event at: " + node.id)
	_show_event_popup("Supply Depot", "Free equipment has been added to your inventory.")
	node.consumed = true
	_update_sector_map()


func _enter_rest_event(node: Variant) -> void:
	print("[Campaign3D] Rest event at: " + node.id)
	_show_event_popup("Rest Stop", "Your crew has fully recovered.")
	node.consumed = true
	_update_sector_map()


func _enter_gate(node: Variant) -> void:
	print("[Campaign3D] VICTORY! Reached the gate!")
	if GameState:
		GameState.end_run(true)
	_show_victory_screen()


func _show_event_popup(title: String, description: String) -> void:
	var popup := AcceptDialog.new()
	popup.title = title
	popup.dialog_text = description
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())


func _show_victory_screen() -> void:
	var victory := AcceptDialog.new()
	victory.title = "VICTORY!"
	victory.dialog_text = "Congratulations! You have escaped the storm!"
	add_child(victory)
	victory.popup_centered()
	victory.confirmed.connect(func():
		victory.queue_free()
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)


func _on_battle_ended(victory: bool) -> void:
	print("[Campaign3D] Battle ended. Victory: " + str(victory))

	if not victory:
		if GameState:
			GameState.end_run(false)
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
		return

	# 승리 - 스톰 진행
	_battles_since_storm += 1
	var storm_rate := Constants.get_storm_advance_rate(GameState.current_difficulty)

	if _battles_since_storm >= storm_rate:
		_sector_data.advance_storm()
		_battles_since_storm = 0
		EventBus.storm_front_advanced.emit(_sector_data.storm_depth)

	_update_sector_map()


func _on_upgrade_requested(_team_leader: Variant) -> void:
	# 업그레이드 화면으로 전환
	var upgrade_scene := "res://src/ui/campaign/UpgradeScreen.tscn"
	if ResourceLoader.exists(upgrade_scene):
		get_tree().change_scene_to_file(upgrade_scene)
