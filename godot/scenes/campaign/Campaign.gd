extends Control

## 캠페인 씬 컨트롤러
## 섹터맵 표시, 노드 이동, 전투 씬 전환 관리

@onready var sector_map_ui: SectorMapUI = $SectorMapUI
@onready var crew_panel: Control = $CrewPanel

var _sector_generator: SectorGenerator
var _sector_data: SectorGenerator.SectorData
var _current_node_id: String = ""


func _ready() -> void:
	_connect_signals()
	# UI 레이아웃이 완료된 후 초기화
	call_deferred("_start_campaign")


func _connect_signals() -> void:
	if sector_map_ui:
		sector_map_ui.node_entered.connect(_on_node_entered)
		sector_map_ui.back_pressed.connect(_on_back_pressed)

	# EventBus 연결
	if EventBus:
		EventBus.battle_ended.connect(_on_battle_ended)


func _start_campaign() -> void:
	# 게임 상태 시작
	if GameState and not GameState.is_run_active():
		GameState.start_new_run(-1, Constants.Difficulty.NORMAL)

	# 섹터 맵 생성
	_sector_generator = SectorGenerator.new()
	var seed_value: int = GameState.current_seed if GameState else randi()
	var difficulty: int = GameState.current_difficulty if GameState else Constants.Difficulty.NORMAL

	_sector_data = _sector_generator.generate(seed_value, difficulty)

	# 시작 노드 설정
	var start_node := _sector_data.get_start_node()
	if start_node:
		_current_node_id = start_node.id

	# UI 업데이트
	_update_sector_map()
	_update_crew_panel()

	print("[Campaign] Started! Seed: %d, Depth: %d" % [seed_value, _sector_data.total_depth])


func _update_sector_map() -> void:
	if sector_map_ui == null or _sector_data == null:
		return

	# SectorData를 Dictionary로 변환
	var map_data := _convert_sector_to_dict()
	sector_map_ui.setup(map_data)
	sector_map_ui.set_current_node(_current_node_id)
	sector_map_ui.set_storm_depth(_sector_data.storm_depth)


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
				"visited": node.visited
			})

	return {
		"nodes": nodes,
		"total_depth": _sector_data.total_depth,
		"storm_depth": _sector_data.storm_depth
	}


func _update_crew_panel() -> void:
	if crew_panel == null:
		return

	# 크루 정보 표시 (간단 버전)
	var crews: Array = []
	if GameState:
		crews = GameState.get_crews()

	# TODO: 크루 패널 UI 업데이트


func _on_node_entered(node_id: String) -> void:
	var node := _sector_data.get_node(node_id)
	if node == null:
		push_warning("Campaign: Node not found: " + node_id)
		return

	# 이동 가능 여부 체크
	if not _can_move_to_node(node_id):
		print("[Campaign] Cannot move to node: " + node_id)
		return

	# 노드 이동
	_current_node_id = node_id
	node.visited = true
	_sector_data.current_node_id = node_id

	print("[Campaign] Entered node: %s (type: %d)" % [node_id, node.node_type])

	# 노드 타입에 따른 처리
	match node.node_type:
		Constants.NodeType.START:
			_update_sector_map()

		Constants.NodeType.BATTLE, Constants.NodeType.STORM, Constants.NodeType.BOSS:
			_enter_battle(node)

		Constants.NodeType.COMMANDER:
			_enter_commander_event(node)

		Constants.NodeType.EQUIPMENT:
			_enter_equipment_event(node)

		Constants.NodeType.REST:
			_enter_rest_event(node)

		Constants.NodeType.GATE:
			_enter_gate(node)

		_:
			_update_sector_map()


func _can_move_to_node(node_id: String) -> bool:
	# 시작 노드에서는 어디든 갈 수 있음
	var start_node := _sector_data.get_start_node()
	if start_node and _current_node_id == start_node.id:
		return true

	# 현재 노드에서 연결된 노드인지 확인
	var current_node := _sector_data.get_node(_current_node_id)
	if current_node == null:
		return false

	return node_id in current_node.connections_out


func _enter_battle(node: SectorGenerator.SectorNode) -> void:
	# GameState에 스테이지 시작 알림
	if GameState:
		GameState.start_stage(node.id)

	# 테스트용 크루 데이터 생성 (없으면)
	if GameState and GameState.get_crews().is_empty():
		_create_test_crews()

	# 전투 씬으로 전환
	print("[Campaign] Starting battle at node: " + node.id)
	var battle_scene := "res://scenes/battle/Battle.tscn"
	if ResourceLoader.exists(battle_scene):
		get_tree().change_scene_to_file(battle_scene)
	else:
		push_warning("[Campaign] Battle.tscn not found, using TestBattle")
		get_tree().change_scene_to_file("res://scenes/battle/TestBattle.tscn")


func _create_test_crews() -> void:
	# 테스트용 크루 3개 추가
	var test_crews := [
		{"id": "crew_1", "class_id": "guardian", "rank": 1, "skill_level": 1, "equipment_id": "", "trait_id": ""},
		{"id": "crew_2", "class_id": "ranger", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""},
		{"id": "crew_3", "class_id": "engineer", "rank": 0, "skill_level": 0, "equipment_id": "", "trait_id": ""}
	]

	for crew_data in test_crews:
		if GameState:
			GameState.add_crew(crew_data)


func _enter_commander_event(node: SectorGenerator.SectorNode) -> void:
	# TODO: 커맨더 이벤트 UI
	print("[Campaign] Commander event at: " + node.id)
	_show_event_popup("Commander Recruited!", "A new crew member has joined your team.")
	node.consumed = true
	_update_sector_map()


func _enter_equipment_event(node: SectorGenerator.SectorNode) -> void:
	# TODO: 장비 이벤트 UI
	print("[Campaign] Equipment event at: " + node.id)
	_show_event_popup("Equipment Found!", "You found a piece of equipment.")
	node.consumed = true
	_update_sector_map()


func _enter_rest_event(node: SectorGenerator.SectorNode) -> void:
	# TODO: 휴식 이벤트 - 체력 회복
	print("[Campaign] Rest event at: " + node.id)
	_show_event_popup("Rest Stop", "Your crew has recovered some health.")
	node.consumed = true
	_update_sector_map()


func _enter_gate(node: SectorGenerator.SectorNode) -> void:
	# 게임 클리어!
	print("[Campaign] VICTORY! Reached the gate!")
	if GameState:
		GameState.end_run(true)

	_show_victory_screen()


func _show_event_popup(title: String, description: String) -> void:
	# 간단한 팝업 표시
	var popup := AcceptDialog.new()
	popup.title = title
	popup.dialog_text = description
	popup.dialog_hide_on_ok = true
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())


func _show_victory_screen() -> void:
	var victory := AcceptDialog.new()
	victory.title = "VICTORY!"
	victory.dialog_text = "Congratulations! You have escaped the storm!"
	victory.dialog_hide_on_ok = true
	add_child(victory)
	victory.popup_centered()
	victory.confirmed.connect(func():
		victory.queue_free()
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)


func _on_battle_ended(victory: bool) -> void:
	# 전투 결과 처리
	print("[Campaign] Battle ended. Victory: " + str(victory))

	if not victory:
		# 패배 - 게임 오버
		if GameState:
			GameState.end_run(false)
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
		return

	# 승리 - 스톰 진행
	_sector_data.advance_storm()

	# 맵으로 복귀
	_update_sector_map()


func _on_back_pressed() -> void:
	# 메인 메뉴로 돌아가기 확인
	var confirm := ConfirmationDialog.new()
	confirm.title = "Return to Menu?"
	confirm.dialog_text = "Your progress will be saved."
	confirm.dialog_hide_on_ok = true
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		confirm.queue_free()
		if GameState:
			GameState.save_game()
		get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
	)
	confirm.canceled.connect(func(): confirm.queue_free())
