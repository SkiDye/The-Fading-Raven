## SectorMap - 섹터 맵 UI
## 캠페인 진행 및 노드 선택
extends Control

# ===========================================
# 씬 참조
# ===========================================

@onready var map_renderer: SectorMapRenderer = $MapRenderer
@onready var turn_label: Label = $HUD/TopBar/TurnLabel
@onready var credits_label: Label = $HUD/TopBar/CreditsLabel
@onready var seed_label: Label = $HUD/TopBar/SeedLabel
@onready var crew_button: Button = $HUD/BottomBar/CrewButton
@onready var upgrade_button: Button = $HUD/BottomBar/UpgradeButton
@onready var menu_button: Button = $HUD/BottomBar/MenuButton
@onready var node_info_panel: PanelContainer = $HUD/NodeInfoPanel
@onready var node_type_label: Label = $HUD/NodeInfoPanel/VBox/TypeLabel
@onready var node_desc_label: Label = $HUD/NodeInfoPanel/VBox/DescLabel
@onready var enter_button: Button = $HUD/NodeInfoPanel/VBox/EnterButton

# 상태
var sector_data: Dictionary = {}
var selected_node_id: int = -1


# ===========================================
# 초기화
# ===========================================

func _ready() -> void:
	# 버튼 연결
	crew_button.pressed.connect(_on_crew_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	enter_button.pressed.connect(_on_enter_pressed)

	# 맵 렌더러 이벤트
	map_renderer.node_clicked.connect(_on_node_clicked)
	map_renderer.node_hovered.connect(_on_node_hovered)

	# 이벤트 버스
	EventBus.credits_changed.connect(_on_credits_changed)
	EventBus.turn_advanced.connect(_on_turn_advanced)

	# 섹터 데이터 로드 또는 생성
	_load_or_generate_sector()

	# HUD 업데이트
	_update_hud()
	_hide_node_info()


func _load_or_generate_sector() -> void:
	var run := GameState.get_current_run()
	if run == null:
		push_error("No active run!")
		return

	# 기존 섹터 데이터 확인
	if run.sector_nodes.is_empty():
		# 새 섹터 생성
		sector_data = SectorGenerator.generate(run.difficulty)
		run.sector_nodes = sector_data.get("nodes", [])
		GameState.save_run()
	else:
		# 기존 데이터 복원
		sector_data = {
			"nodes": run.sector_nodes,
			"storm_line": run.storm_line,
			"difficulty": run.difficulty,
		}
		# rows 재구성
		_rebuild_rows()

	# 현재 노드 ID
	var current_id := run.current_node_id

	# 맵 렌더러 설정
	map_renderer.setup(sector_data, current_id)


func _rebuild_rows() -> void:
	# 노드들을 행별로 재구성
	var rows: Array[Array] = []
	var max_row := 0

	for node in sector_data.get("nodes", []):
		var row: int = node.get("row", 0)
		max_row = maxi(max_row, row)

	for _i in range(max_row + 1):
		rows.append([])

	for node in sector_data.get("nodes", []):
		var row: int = node.get("row", 0)
		rows[row].append(node)

	sector_data["rows"] = rows


# ===========================================
# HUD 업데이트
# ===========================================

func _update_hud() -> void:
	var run := GameState.get_current_run()
	if run:
		turn_label.text = "Turn: %d" % run.turn
		credits_label.text = "Credits: %d" % run.credits
		seed_label.text = "Seed: %s" % run.seed_string


func _on_credits_changed(_new_amount: int, _delta: int) -> void:
	_update_hud()


func _on_turn_advanced(_turn: int) -> void:
	_update_hud()

	# 스톰 라인 업데이트
	var run := GameState.get_current_run()
	if run:
		sector_data["storm_line"] = run.storm_line
		map_renderer.queue_redraw()


# ===========================================
# 노드 상호작용
# ===========================================

func _on_node_clicked(node_id: int) -> void:
	selected_node_id = node_id
	_show_node_info(node_id)


func _on_node_hovered(node_id: int) -> void:
	if node_id >= 0:
		# 툴팁 표시 (간단히)
		pass


func _show_node_info(node_id: int) -> void:
	var node := SectorGenerator.get_node_by_id(sector_data, node_id)
	if node.is_empty():
		_hide_node_info()
		return

	var node_type: int = node.get("type", 0)

	# 노드 타입별 정보
	var type_info := _get_node_type_info(node_type)
	node_type_label.text = type_info["name"]
	node_desc_label.text = type_info["description"]

	# 진입 버튼
	var is_available := _can_enter_node(node_id)
	enter_button.disabled = not is_available
	enter_button.text = "ENTER" if is_available else "UNAVAILABLE"

	node_info_panel.visible = true


func _hide_node_info() -> void:
	node_info_panel.visible = false
	selected_node_id = -1


func _get_node_type_info(node_type: int) -> Dictionary:
	match node_type:
		SectorGenerator.NodeType.START:
			return {"name": "시작 지점", "description": "여정이 시작됩니다."}
		SectorGenerator.NodeType.STATION:
			return {"name": "정거장 방어", "description": "우주 정거장을 적으로부터 방어하세요."}
		SectorGenerator.NodeType.ELITE_STATION:
			return {"name": "엘리트 전투", "description": "강력한 적이 기다립니다. 보상도 큽니다."}
		SectorGenerator.NodeType.SHOP:
			return {"name": "상점", "description": "장비를 구매하거나 크루를 업그레이드할 수 있습니다."}
		SectorGenerator.NodeType.EVENT:
			return {"name": "미지의 이벤트", "description": "무엇이 기다리고 있을지 모릅니다."}
		SectorGenerator.NodeType.REST:
			return {"name": "휴식", "description": "크루를 치료할 수 있습니다."}
		SectorGenerator.NodeType.BOSS:
			return {"name": "보스", "description": "섹터의 우두머리가 기다립니다."}
		SectorGenerator.NodeType.GATE:
			return {"name": "섹터 게이트", "description": "다음 섹터로 이동합니다."}
		_:
			return {"name": "알 수 없음", "description": ""}


func _can_enter_node(node_id: int) -> bool:
	var run := GameState.get_current_run()
	if run == null:
		return false

	var current_id := run.current_node_id

	# 시작 노드
	if current_id < 0:
		var node := SectorGenerator.get_node_by_id(sector_data, node_id)
		return node.get("type") == SectorGenerator.NodeType.START

	# 연결된 노드만 진입 가능
	var current := SectorGenerator.get_node_by_id(sector_data, current_id)
	if current.is_empty():
		return false

	return node_id in current.get("connections", [])


func _on_enter_pressed() -> void:
	if selected_node_id < 0:
		return

	if not _can_enter_node(selected_node_id):
		return

	_enter_node(selected_node_id)


func _enter_node(node_id: int) -> void:
	var node := SectorGenerator.get_node_by_id(sector_data, node_id)
	if node.is_empty():
		return

	var run := GameState.get_current_run()
	if run == null:
		return

	# 노드 방문 처리
	SectorGenerator.visit_node(sector_data, node_id)
	run.current_node_id = node_id
	if node_id not in run.visited_nodes:
		run.visited_nodes.append(node_id)

	# 섹터 데이터 동기화
	run.sector_nodes = sector_data.get("nodes", [])
	GameState.save_run()

	# 노드 타입별 처리
	var node_type: int = node.get("type", 0)

	match node_type:
		SectorGenerator.NodeType.START:
			# 시작 노드 - 아무것도 안함
			map_renderer.setup(sector_data, node_id)
			_hide_node_info()

		SectorGenerator.NodeType.STATION, SectorGenerator.NodeType.ELITE_STATION:
			# 전투 시작
			var station_data := {
				"turn": run.turn,
				"difficulty": run.difficulty,
				"is_elite": node_type == SectorGenerator.NodeType.ELITE_STATION,
			}
			SceneManager.start_battle(station_data)

		SectorGenerator.NodeType.BOSS:
			# 보스 전투
			var station_data := {
				"turn": run.turn,
				"difficulty": run.difficulty,
				"is_boss": true,
				"boss_type": node.get("data", {}).get("boss_type", "pirate_captain"),
			}
			SceneManager.start_battle(station_data)

		SectorGenerator.NodeType.SHOP:
			# 상점/업그레이드
			SceneManager.go_to_upgrade()

		SectorGenerator.NodeType.EVENT:
			# 이벤트 처리 (간소화)
			_handle_event(node)

		SectorGenerator.NodeType.REST:
			# 휴식 - 크루 치료
			_handle_rest()

		SectorGenerator.NodeType.GATE:
			# 섹터 클리어
			_handle_gate()


func _handle_event(node: Dictionary) -> void:
	var event_type: String = node.get("data", {}).get("event_type", "abandoned_cargo")

	match event_type:
		"abandoned_cargo":
			# 크레딧 획득
			var credits := RngManager.range_int(RngManager.STREAM_ITEMS, 10, 25)
			GameState.add_credits(credits)
			EventBus.show_toast("+%d Credits found!" % credits, "success")

		"equipment_cache":
			# 장비 획득 (상점으로 이동)
			SceneManager.go_to_upgrade()
			return

		_:
			# 기본: 크레딧
			GameState.add_credits(5)
			EventBus.show_toast("+5 Credits", "info")

	# 맵 업데이트
	map_renderer.setup(sector_data, GameState.get_current_run().current_node_id)
	_hide_node_info()


func _handle_rest() -> void:
	# 모든 크루 치료
	var run := GameState.get_current_run()
	if run == null:
		return

	for crew in run.crews:
		if crew.get("is_alive", false):
			var max_size: int = crew.get("max_squad_size", 8)
			crew["squad_size"] = max_size

	GameState.save_run()
	EventBus.show_toast("All crews fully healed!", "success")

	# 맵 업데이트
	map_renderer.setup(sector_data, run.current_node_id)
	_hide_node_info()


func _handle_gate() -> void:
	# 섹터 클리어 - 승리!
	GameState.end_run(true)
	SceneManager.go_to_victory()


# ===========================================
# 버튼 핸들러
# ===========================================

func _on_crew_pressed() -> void:
	# 크루 정보 패널 (간소화)
	SceneManager.go_to_upgrade()


func _on_upgrade_pressed() -> void:
	SceneManager.go_to_upgrade()


func _on_menu_pressed() -> void:
	# 확인 다이얼로그 없이 메인 메뉴로
	SceneManager.go_to_main_menu()
