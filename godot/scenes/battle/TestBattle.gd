extends Node2D

## 테스트 전투 씬
## 크루와 적을 스폰하고 실제 전투 테스트

@onready var battle_controller: Node = $BattleController
@onready var crews_container: Node2D = $EntityContainer/Crews
@onready var enemies_container: Node2D = $EntityContainer/Enemies
@onready var camera: Camera2D = $Camera2D
@onready var wave_label: Label = $UI/BattleHUD/TopBar/WaveLabel
@onready var enemy_count_label: Label = $UI/BattleHUD/TopBar/EnemyCountLabel
@onready var crew_panel: HBoxContainer = $UI/BattleHUD/BottomBar/CrewPanel

var _crew_scene: PackedScene
var _enemy_scene: PackedScene
var _crews: Array = []
var _enemies: Array = []
var _selected_crew: Node = null
var _wave_number: int = 1
var _total_waves: int = 5
var _spawn_timer: float = 0.0
var _is_paused: bool = false


func _ready() -> void:
	_load_scenes()
	_start_test_battle()
	_update_ui()
	# 카메라를 크루 위치로 이동
	if camera:
		camera.position = Vector2(400, 400)
		camera.zoom = Vector2(1.0, 1.0)
	print("[TestBattle] Ready! Crews: %d, Enemies: %d" % [_crews.size(), _enemies.size()])


func _load_scenes() -> void:
	if ResourceLoader.exists("res://src/entities/crew/CrewSquad.tscn"):
		_crew_scene = load("res://src/entities/crew/CrewSquad.tscn")

	if ResourceLoader.exists("res://src/entities/enemy/EnemyUnit.tscn"):
		_enemy_scene = load("res://src/entities/enemy/EnemyUnit.tscn")


func _start_test_battle() -> void:
	# 게임 상태 시작
	if GameState:
		GameState.start_new_run(-1, Constants.Difficulty.NORMAL)

	# 테스트 크루 3개 스폰
	_spawn_test_crews()

	# 첫 웨이브 적 스폰
	_spawn_wave_enemies()

	print("[TestBattle] Battle started!")


func _spawn_test_crews() -> void:
	var crew_classes := ["guardian", "ranger", "engineer"]
	var start_positions := [
		Vector2(100, 300),
		Vector2(100, 400),
		Vector2(100, 500)
	]

	for i in range(3):
		var crew: Node2D = _create_crew(crew_classes[i], start_positions[i])
		if crew:
			_crews.append(crew)
			crews_container.add_child(crew)
			_create_crew_button(crew, i)


func _create_crew(class_id: String, pos: Vector2) -> Node2D:
	if _crew_scene == null:
		# 씬이 없으면 간단한 대체 노드 생성
		var placeholder := _create_placeholder_crew(class_id)
		placeholder.position = pos
		return placeholder

	var crew: Node2D = _crew_scene.instantiate()
	crew.position = pos

	if crew.has_method("set_class_id"):
		crew.call("set_class_id", class_id)
	elif "class_id" in crew:
		crew.class_id = class_id

	if crew.has_method("initialize_squad"):
		crew.call("initialize_squad", 1.0)

	return crew


func _create_placeholder_crew(class_id: String) -> Node2D:
	var node := Node2D.new()
	node.name = "Crew_" + class_id
	node.set_meta("class_id", class_id)
	node.set_meta("is_crew", true)
	node.set_meta("hp", 100)
	node.set_meta("max_hp", 100)

	# 시각적 표현
	var sprite := ColorRect.new()
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)

	match class_id:
		"guardian":
			sprite.color = Color.BLUE
		"ranger":
			sprite.color = Color.GREEN
		"engineer":
			sprite.color = Color.ORANGE
		_:
			sprite.color = Color.WHITE

	node.add_child(sprite)

	# HP 바
	var hp_bar := ProgressBar.new()
	hp_bar.size = Vector2(40, 6)
	hp_bar.position = Vector2(-20, -30)
	hp_bar.value = 100
	hp_bar.show_percentage = false
	node.add_child(hp_bar)

	# 이름 라벨
	var label := Label.new()
	label.text = class_id.to_upper()
	label.position = Vector2(-20, 25)
	label.add_theme_font_size_override("font_size", 10)
	node.add_child(label)

	return node


func _spawn_wave_enemies() -> void:
	var enemy_count := 3 + _wave_number * 2
	var spawn_x := 800.0

	for i in range(enemy_count):
		var enemy: Node2D = _create_enemy("rusher", Vector2(spawn_x + randf() * 100, 200 + i * 60))
		if enemy:
			_enemies.append(enemy)
			enemies_container.add_child(enemy)


func _create_enemy(enemy_id: String, pos: Vector2) -> Node2D:
	if _enemy_scene == null:
		var placeholder := _create_placeholder_enemy(enemy_id)
		placeholder.position = pos
		return placeholder

	var enemy: Node2D = _enemy_scene.instantiate()
	enemy.position = pos

	if enemy.has_method("initialize"):
		var enemy_data: Resource = Constants.get_enemy(enemy_id)
		if enemy_data:
			enemy.call("initialize", enemy_data)

	return enemy


func _create_placeholder_enemy(enemy_id: String) -> Node2D:
	var node := Node2D.new()
	node.name = "Enemy_" + enemy_id
	node.set_meta("enemy_id", enemy_id)
	node.set_meta("is_enemy", true)
	node.set_meta("hp", 30)
	node.set_meta("max_hp", 30)

	var sprite := ColorRect.new()
	sprite.size = Vector2(30, 30)
	sprite.position = Vector2(-15, -15)
	sprite.color = Color.RED
	node.add_child(sprite)

	var hp_bar := ProgressBar.new()
	hp_bar.size = Vector2(30, 4)
	hp_bar.position = Vector2(-15, -22)
	hp_bar.value = 100
	hp_bar.show_percentage = false
	node.add_child(hp_bar)

	return node


func _create_crew_button(crew: Node, index: int) -> void:
	var btn := Button.new()
	var class_id: String = ""

	if crew.has_meta("class_id"):
		class_id = crew.get_meta("class_id")
	elif "class_id" in crew:
		class_id = crew.class_id
	else:
		class_id = "Crew " + str(index + 1)

	btn.text = "[%d] %s" % [index + 1, class_id.to_upper()]
	btn.custom_minimum_size = Vector2(120, 60)
	btn.pressed.connect(func(): _select_crew(crew))
	crew_panel.add_child(btn)


func _process(delta: float) -> void:
	if _is_paused:
		return

	_update_enemies(delta)
	_update_ui()
	_check_wave_complete()


func _update_enemies(delta: float) -> void:
	# 적들이 크루 쪽으로 이동
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.get_meta("hp", 0) <= 0:
			continue

		var target: Node2D = _find_nearest_crew(enemy.position)
		if target:
			var dir: Vector2 = (target.position - enemy.position).normalized()
			enemy.position += dir * 50.0 * delta

			# 충돌 체크 (간단)
			if enemy.position.distance_to(target.position) < 40:
				_deal_damage_to_crew(target, 5)


func _find_nearest_crew(from: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist := 9999.0

	for crew in _crews:
		if not is_instance_valid(crew):
			continue
		if crew.get_meta("hp", 0) <= 0:
			continue

		var dist := from.distance_to(crew.position)
		if dist < min_dist:
			min_dist = dist
			nearest = crew

	return nearest


func _deal_damage_to_crew(crew: Node, amount: int) -> void:
	var hp: int = crew.get_meta("hp", 100)
	hp -= amount
	crew.set_meta("hp", hp)

	# HP바 업데이트
	for child in crew.get_children():
		if child is ProgressBar:
			child.value = (float(hp) / crew.get_meta("max_hp", 100)) * 100

	if hp <= 0:
		crew.modulate = Color(0.3, 0.3, 0.3)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_1:
				if _crews.size() > 0:
					_select_crew(_crews[0])
			KEY_2:
				if _crews.size() > 1:
					_select_crew(_crews[1])
			KEY_3:
				if _crews.size() > 2:
					_select_crew(_crews[2])
			KEY_Q:
				_use_skill()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")

	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_global_mouse_position()

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mouse_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(mouse_pos)


func _handle_left_click(pos: Vector2) -> void:
	# 크루 선택
	for crew in _crews:
		if not is_instance_valid(crew):
			continue
		if crew.position.distance_to(pos) < 30:
			_select_crew(crew)
			return

	# 적 선택 (공격 대상)
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.position.distance_to(pos) < 25:
			if _selected_crew:
				_attack_enemy(enemy)
			return


func _handle_right_click(pos: Vector2) -> void:
	if _selected_crew == null:
		return

	# 적 우클릭 = 공격
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.position.distance_to(pos) < 25:
			_attack_enemy(enemy)
			return

	# 빈 공간 우클릭 = 이동
	_move_crew(pos)


func _select_crew(crew: Node) -> void:
	# 이전 선택 해제
	if _selected_crew and is_instance_valid(_selected_crew):
		_selected_crew.modulate = Color.WHITE

	_selected_crew = crew
	if crew:
		crew.modulate = Color.YELLOW
		print("[TestBattle] Selected: ", crew.name)


func _move_crew(target_pos: Vector2) -> void:
	if _selected_crew == null:
		return

	# 간단한 즉시 이동 (실제로는 트윈 사용)
	var tween := create_tween()
	tween.tween_property(_selected_crew, "position", target_pos, 0.5)
	print("[TestBattle] Moving to: ", target_pos)


func _attack_enemy(enemy: Node) -> void:
	if _selected_crew == null:
		return

	# 데미지 처리
	var hp: int = enemy.get_meta("hp", 30)
	var damage := 10
	hp -= damage
	enemy.set_meta("hp", hp)

	# HP바 업데이트
	for child in enemy.get_children():
		if child is ProgressBar:
			child.value = (float(hp) / enemy.get_meta("max_hp", 30)) * 100

	print("[TestBattle] Attack! Damage: %d, Enemy HP: %d" % [damage, hp])

	# 사망 처리
	if hp <= 0:
		enemy.queue_free()
		_enemies.erase(enemy)
		print("[TestBattle] Enemy killed!")


func _use_skill() -> void:
	if _selected_crew == null:
		return

	var class_id: String = _selected_crew.get_meta("class_id", "unknown")
	print("[TestBattle] Skill used: ", class_id)

	# 간단한 스킬 효과
	match class_id:
		"guardian":
			# Shield Bash - 주변 적 넉백
			for enemy in _enemies:
				if not is_instance_valid(enemy):
					continue
				if enemy.position.distance_to(_selected_crew.position) < 100:
					var dir: Vector2 = (enemy.position - _selected_crew.position).normalized()
					enemy.position += dir * 100
					_deal_damage_to_enemy(enemy, 15)
			print("[TestBattle] Shield Bash!")

		"ranger":
			# Volley Fire - 모든 적에게 데미지
			for enemy in _enemies:
				if is_instance_valid(enemy):
					_deal_damage_to_enemy(enemy, 8)
			print("[TestBattle] Volley Fire!")

		"engineer":
			# Deploy Turret - 터렛 설치 (간단히 표시만)
			var turret := ColorRect.new()
			turret.size = Vector2(20, 20)
			turret.position = _selected_crew.position + Vector2(50, 0)
			turret.color = Color.CYAN
			add_child(turret)
			print("[TestBattle] Turret Deployed!")


func _deal_damage_to_enemy(enemy: Node, amount: int) -> void:
	var hp: int = enemy.get_meta("hp", 30)
	hp -= amount
	enemy.set_meta("hp", hp)

	for child in enemy.get_children():
		if child is ProgressBar:
			child.value = (float(hp) / enemy.get_meta("max_hp", 30)) * 100

	if hp <= 0:
		enemy.queue_free()
		_enemies.erase(enemy)


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	print("[TestBattle] Paused: ", _is_paused)


func _check_wave_complete() -> void:
	# 살아있는 적 확인
	var alive_count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.get_meta("hp", 0) > 0:
			alive_count += 1

	if alive_count == 0 and _enemies.size() > 0:
		_enemies.clear()
		_wave_number += 1

		if _wave_number > _total_waves:
			print("[TestBattle] VICTORY!")
			_show_victory()
		else:
			print("[TestBattle] Wave %d complete! Starting wave %d" % [_wave_number - 1, _wave_number])
			_spawn_wave_enemies()


func _update_ui() -> void:
	if wave_label:
		wave_label.text = "Wave %d/%d" % [_wave_number, _total_waves]

	var alive_enemies := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.get_meta("hp", 0) > 0:
			alive_enemies += 1

	if enemy_count_label:
		enemy_count_label.text = "Enemies: %d" % alive_enemies


func _show_victory() -> void:
	var victory_label := Label.new()
	victory_label.text = "VICTORY!"
	victory_label.add_theme_font_size_override("font_size", 72)
	victory_label.add_theme_color_override("font_color", Color.GOLD)
	victory_label.position = Vector2(400, 300)
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(victory_label)

	# 3초 후 메인 메뉴로
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
