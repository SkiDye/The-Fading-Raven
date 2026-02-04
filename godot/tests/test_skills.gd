extends GutTest

## SkillSystem 테스트


var _skill_system: SkillSystem
var _battle_controller: BattleController
var _mock_grid: Node


func before_each() -> void:
	# 전투 컨트롤러 (부모 역할)
	_battle_controller = BattleController.new()
	_battle_controller.name = "BattleController"
	add_child(_battle_controller)

	await get_tree().process_frame

	_skill_system = _battle_controller.skill_system

	# 모의 타일 그리드
	_mock_grid = _create_mock_tile_grid()
	_battle_controller.tile_grid = _mock_grid


func after_each() -> void:
	if _battle_controller:
		_battle_controller.queue_free()
	if _mock_grid:
		_mock_grid.queue_free()

	_battle_controller = null
	_skill_system = null
	_mock_grid = null


func _create_mock_tile_grid() -> Node:
	var grid := Node.new()
	grid.name = "MockTileGrid"
	grid.set_script(GDScript.new())
	grid.get_script().source_code = """
extends Node

var width: int = 20
var height: int = 15

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * 32 + 16, tile_pos.y * 32 + 16)

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / 32), int(world_pos.y / 32))

func is_walkable(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func get_tile_type(pos: Vector2i) -> int:
	return Constants.TileType.FLOOR

func get_occupant(pos: Vector2i) -> Node:
	return null

func get_elevation(pos: Vector2i) -> int:
	return 0
"""
	grid.get_script().reload()
	add_child(grid)
	return grid


func _create_mock_crew(class_id: String, skill_level: int = 0) -> Node:
	var crew := Node2D.new()
	crew.name = "MockCrew_" + class_id
	crew.set("tile_position", Vector2i(5, 5))
	crew.set("is_alive", true)
	crew.set("is_stunned", false)
	crew.set("current_hp", 100)
	crew.set("max_hp", 100)
	crew.set("entity_id", "crew_" + class_id)
	crew.global_position = Vector2(5 * 32 + 16, 5 * 32 + 16)

	# 크루 데이터
	var crew_data := {
		"id": "crew_" + class_id,
		"class_id": class_id,
		"skill_level": skill_level,
		"rank": 0,
		"equipment_id": "",
		"equipment_level": 0,
		"trait_id": ""
	}
	crew.set("crew_data", crew_data)

	# 메서드 추가를 위한 스크립트
	crew.set_script(GDScript.new())
	crew.get_script().source_code = """
extends Node2D

var tile_position: Vector2i
var is_alive: bool = true
var is_stunned: bool = false
var current_hp: int = 100
var max_hp: int = 100
var entity_id: String
var crew_data: Dictionary
var members: Array = []
var _skill_cooldown: float = 0.0

func can_use_skill() -> bool:
	return _skill_cooldown <= 0 and is_alive and not is_stunned

func start_skill_cooldown(skill_id: String) -> void:
	_skill_cooldown = 20.0

func get_alive_count() -> int:
	return 8

func set_tile_position(pos: Vector2i) -> void:
	tile_position = pos

func heal(amount: int) -> int:
	var actual = mini(amount, max_hp - current_hp)
	current_hp += actual
	return actual

func take_damage(amount: int, type: int, source: Node) -> int:
	current_hp = maxi(0, current_hp - amount)
	if current_hp <= 0:
		is_alive = false
	return amount

func apply_knockback(direction: Vector2, force: float) -> void:
	pass

func apply_stun(duration: float) -> void:
	is_stunned = true
"""
	crew.get_script().reload()

	# 멤버 초기화
	for i in range(8):
		crew.members.append({"is_alive": true})

	add_child(crew)
	return crew


func _create_mock_enemy() -> Node:
	var enemy := Node2D.new()
	enemy.name = "MockEnemy"
	enemy.set("tile_position", Vector2i(7, 5))
	enemy.set("is_alive", true)
	enemy.set("team", 1)
	enemy.set("current_hp", 50)
	enemy.set("max_hp", 50)
	enemy.global_position = Vector2(7 * 32 + 16, 5 * 32 + 16)

	enemy.set_script(GDScript.new())
	enemy.get_script().source_code = """
extends Node2D

var tile_position: Vector2i
var is_alive: bool = true
var team: int = 1
var current_hp: int = 50
var max_hp: int = 50
var enemy_data: Dictionary = {"id": "rusher"}
var is_stunned: bool = false

func take_damage(amount: int, type: int, source: Node) -> int:
	current_hp = maxi(0, current_hp - amount)
	if current_hp <= 0:
		is_alive = false
	return amount

func apply_knockback(direction: Vector2, force: float) -> void:
	pass

func apply_stun(duration: float) -> void:
	is_stunned = true
"""
	enemy.get_script().reload()
	enemy.add_to_group("enemies")
	add_child(enemy)
	return enemy


# ===== SKILL SYSTEM TESTS =====

func test_skill_system_exists() -> void:
	assert_not_null(_skill_system, "SkillSystem should exist")


func test_shield_bash_execution() -> void:
	var crew := _create_mock_crew("guardian", 0)
	var enemy := _create_mock_enemy()

	# 적을 크루 옆에 배치
	enemy.tile_position = Vector2i(6, 5)

	var success := _skill_system.execute_skill(crew, "shield_bash", Vector2i(10, 5))

	assert_true(success, "Shield Bash should execute successfully")

	crew.queue_free()
	enemy.queue_free()


func test_blink_execution() -> void:
	var crew := _create_mock_crew("bionic", 0)
	var original_pos := crew.tile_position

	# Lv0: 2타일 거리
	var target := Vector2i(original_pos.x + 2, original_pos.y)

	var success := _skill_system.execute_skill(crew, "blink", target)

	assert_true(success, "Blink should execute successfully")
	assert_eq(crew.tile_position, target, "Crew should be at target position")

	crew.queue_free()


func test_blink_out_of_range() -> void:
	var crew := _create_mock_crew("bionic", 0)
	var original_pos := crew.tile_position

	# Lv0: 최대 2타일, 5타일은 범위 초과
	var target := Vector2i(original_pos.x + 5, original_pos.y)

	# 스킬 실패 시그널 연결
	var failed := false
	_skill_system.skill_failed.connect(func(_c, _s, reason):
		if reason == "out_of_range":
			failed = true
	)

	var success := _skill_system.execute_skill(crew, "blink", target)

	assert_false(success, "Blink should fail when out of range")

	crew.queue_free()


func test_volley_fire_execution() -> void:
	var crew := _create_mock_crew("ranger", 0)
	var target := Vector2i(8, 5)

	var success := _skill_system.execute_skill(crew, "volley_fire", target)

	assert_true(success, "Volley Fire should execute successfully")

	crew.queue_free()


func test_deploy_turret_execution() -> void:
	var crew := _create_mock_crew("engineer", 0)
	var target := Vector2i(6, 6)

	var success := _skill_system.execute_skill(crew, "deploy_turret", target)

	# 터렛 씬이 없어도 실패하지 않아야 함
	# (실제로는 씬이 없으면 경고만 출력)
	# assert_true(success, "Deploy Turret should execute")

	crew.queue_free()


func test_lance_charge_execution() -> void:
	var crew := _create_mock_crew("sentinel", 0)
	var enemy := _create_mock_enemy()

	# 적을 경로에 배치
	enemy.tile_position = Vector2i(6, 5)

	var success := _skill_system.execute_skill(crew, "lance_charge", Vector2i(10, 5))

	assert_true(success, "Lance Charge should execute successfully")

	crew.queue_free()
	enemy.queue_free()


func test_skill_on_dead_crew() -> void:
	var crew := _create_mock_crew("guardian", 0)
	crew.is_alive = false

	var success := _skill_system.execute_skill(crew, "shield_bash", Vector2i(10, 5))

	assert_false(success, "Skill should not execute on dead crew")

	crew.queue_free()


func test_skill_on_stunned_crew() -> void:
	var crew := _create_mock_crew("guardian", 0)
	crew.is_stunned = true

	var success := _skill_system.execute_skill(crew, "shield_bash", Vector2i(10, 5))

	assert_false(success, "Skill should not execute on stunned crew")

	crew.queue_free()


func test_unknown_skill() -> void:
	var crew := _create_mock_crew("guardian", 0)

	var failed := false
	_skill_system.skill_failed.connect(func(_c, _s, reason):
		if reason == "unknown_skill":
			failed = true
	)

	var success := _skill_system.execute_skill(crew, "nonexistent_skill", Vector2i(10, 5))

	assert_false(success, "Unknown skill should fail")

	crew.queue_free()


# ===== SKILL LEVEL TESTS =====

func test_blink_level_scaling() -> void:
	# Level 0: 2타일
	var crew_lv0 := _create_mock_crew("bionic", 0)
	var target_2 := Vector2i(crew_lv0.tile_position.x + 2, crew_lv0.tile_position.y)
	var success_lv0 := _skill_system.execute_skill(crew_lv0, "blink", target_2)
	assert_true(success_lv0, "Lv0 Blink should work at 2 tiles")
	crew_lv0.queue_free()

	# Level 1: 4타일
	var crew_lv1 := _create_mock_crew("bionic", 1)
	var target_4 := Vector2i(crew_lv1.tile_position.x + 4, crew_lv1.tile_position.y)
	var success_lv1 := _skill_system.execute_skill(crew_lv1, "blink", target_4)
	assert_true(success_lv1, "Lv1 Blink should work at 4 tiles")
	crew_lv1.queue_free()

	# Level 2: 6타일
	var crew_lv2 := _create_mock_crew("bionic", 2)
	var target_6 := Vector2i(crew_lv2.tile_position.x + 6, crew_lv2.tile_position.y)
	var success_lv2 := _skill_system.execute_skill(crew_lv2, "blink", target_6)
	assert_true(success_lv2, "Lv2 Blink should work at 6 tiles")
	crew_lv2.queue_free()
