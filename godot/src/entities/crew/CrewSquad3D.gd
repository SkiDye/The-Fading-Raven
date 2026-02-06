class_name CrewSquad3D
extends Node3D

## 3D 크루 분대
## 팀장 + 크루원으로 구성된 분대 유닛
## 개별 SquadMember3D로 시각화됨

# ===== SIGNALS =====

signal health_changed(current: int, max_hp: int)
signal member_died(remaining: int)
signal squad_eliminated()
signal skill_activated(skill_id: String)
signal movement_started(target_pos: Vector3)
signal movement_finished()
signal combat_started(enemy: Node3D)
signal combat_ended()


# ===== CONFIGURATION =====

@export var class_id: String = "guardian"
@export var max_members: int = 8
@export var move_speed: float = 3.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

const HP_PER_MEMBER: int = 12
const MEMBER_SPACING: float = 0.15  # 한 타일(1x1) 안에 8명 컴팩트 정사각형 배치
const FORMATION_COMBAT_RADIUS: float = 1.0  # 지휘관 중심 교전 범위 (1타일)

## 1:1 전투 시스템
var _combat_matchmaker: CombatMatchmaker


# ===== STATE =====

var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 100
var max_hp: int = 100
var members_alive: int = 8
var is_alive: bool = true
var is_selected: bool = false
var is_moving: bool = false
var is_in_combat: bool = false
var current_target: Node3D = null
var team: int = 0  # 0 = 플레이어

# 스킬/장비
var skill_level: int = 0  # 0-2, 레벨업 시 정확도 향상
var skill_cooldown: float = 0.0
var skill_max_cooldown: float = 20.0
var equipment_id: String = ""

# 정확도 (레벨에 따라 편차 감소)
const BASE_SPREAD: float = 0.5  # 레벨 0 기본 편차
const SPREAD_PER_LEVEL: float = 0.15  # 레벨당 편차 감소량

# 이동
var _move_path: Array[Vector3] = []
var _move_index: int = 0

# 전투
var _attack_timer: float = 0.0

# 개별 멤버
var _members: Array[SquadMember3D] = []
var _formation_type: FormationSystem3D.FormationType = FormationSystem3D.FormationType.SQUARE

# 프리로드
var _member_scene: PackedScene
var _projectile_scene: PackedScene


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var selection_indicator: Node3D = $SelectionIndicator
@onready var health_bar: Node3D = $HealthBar3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	_load_member_scene()
	_setup_health()
	_update_selection_visual()
	_combat_matchmaker = CombatMatchmaker.new()
	add_to_group("crews")
	add_to_group("units")


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 스킬 쿨다운
	if skill_cooldown > 0:
		skill_cooldown -= delta

	# 이동 처리 (최우선)
	if is_moving and not _move_path.is_empty():
		_process_movement(delta)
		# 이동 중에도 전투 가능 - 멤버들이 팀장 범위 내에서 싸움
		_process_individual_engagements(delta)
		return

	# 1:1 전투 시스템: 개별 멤버 교전 관리
	_process_individual_engagements(delta)

	# 레거시 전투 처리 (원거리 클래스용)
	if is_in_combat and current_target:
		_process_combat(delta)
	elif not is_in_combat:
		# 자동 적 탐지 및 교전
		_auto_engage_nearby_enemy()


func _load_member_scene() -> void:
	var path := "res://src/entities/crew/SquadMember3D.tscn"
	if ResourceLoader.exists(path):
		_member_scene = load(path)

	var projectile_path := "res://src/entities/projectile/Projectile3D.tscn"
	if ResourceLoader.exists(projectile_path):
		_projectile_scene = load(projectile_path)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	# 1. class_id 먼저 설정
	if data.has("class_id"):
		class_id = data.class_id

	# 2. 리소스에서 클래스 스탯 로드
	_load_class_stats()

	# 3. data 오버라이드 (선택적)
	if data.has("max_members"):
		max_members = data.max_members
	if data.has("tile_position"):
		tile_position = data.tile_position
	if data.has("equipment_id"):
		equipment_id = data.equipment_id
	if data.has("skill_level"):
		skill_level = data.skill_level

	members_alive = max_members
	_formation_type = FormationSystem3D.get_default_formation_for_class(class_id)
	_setup_health()
	_spawn_squad_members()


func _load_class_stats() -> void:
	var class_data: Resource = Constants.get_crew_class(class_id)
	if class_data == null:
		push_warning("CrewSquad3D: Class data not found for '%s', using defaults" % class_id)
		return

	# 리소스 스탯 적용
	if "base_squad_size" in class_data:
		max_members = class_data.base_squad_size
	if "base_damage" in class_data:
		attack_damage = class_data.base_damage
	if "attack_range" in class_data:
		attack_range = class_data.attack_range
	if "move_speed" in class_data:
		move_speed = class_data.move_speed
	if "attack_speed" in class_data and class_data.attack_speed > 0:
		attack_cooldown = 1.0 / class_data.attack_speed
	if "skill_cooldown" in class_data:
		skill_max_cooldown = class_data.skill_cooldown


func _setup_health() -> void:
	## HP는 이제 멤버 HP 합산으로 계산 (하위 호환성)
	max_hp = members_alive * HP_PER_MEMBER
	current_hp = max_hp


func _get_class_defense_stats() -> Dictionary:
	## 클래스별 방어/회피 스탯
	match class_id:
		"guardian":
			return {"block": 0.4, "evade": 0.05, "reduction": 0.6}  # 높은 막기
		"sentinel":
			return {"block": 0.2, "evade": 0.15, "reduction": 0.5}  # 균형
		"ranger":
			return {"block": 0.05, "evade": 0.25, "reduction": 0.4}  # 높은 회피
		"engineer":
			return {"block": 0.15, "evade": 0.1, "reduction": 0.5}
		"bionic":
			return {"block": 0.1, "evade": 0.35, "reduction": 0.4}  # 매우 높은 회피
		_:
			return {"block": 0.1, "evade": 0.1, "reduction": 0.5}


func _spawn_squad_members() -> void:
	if model_container == null:
		return

	# 기존 모델/멤버 제거
	for child in model_container.get_children():
		child.queue_free()
	_members.clear()

	# 포메이션 위치 계산
	var positions := FormationSystem3D.get_formation_positions(
		max_members,
		_formation_type,
		MEMBER_SPACING
	)

	# 각 멤버 생성
	for i in range(max_members):
		var member: SquadMember3D

		if _member_scene:
			member = _member_scene.instantiate()
		else:
			# 폴백: 직접 생성
			member = SquadMember3D.new()

		model_container.add_child(member)

		var is_leader := FormationSystem3D.is_leader_position(i, _formation_type)
		member.initialize(class_id, i, is_leader)

		# 포메이션 위치 설정
		if i < positions.size():
			member.set_immediate_position(positions[i])

		# 전투 스탯 설정
		member.set_combat_stats(HP_PER_MEMBER, attack_damage, attack_cooldown)
		member.parent_squad = self

		# 방어 스탯 설정
		var defense := _get_class_defense_stats()
		member.set_defense_stats(defense.block, defense.evade, defense.reduction)

		# 시그널 연결
		member.died.connect(_on_member_visual_died.bind(i))
		member.individual_died.connect(_on_member_individual_died)
		member.opponent_killed.connect(_on_member_opponent_killed)
		_members.append(member)


func _load_model() -> void:
	# 이전 버전 호환: 이제 _spawn_squad_members()를 사용
	_spawn_squad_members()


# ===== FORMATION =====

func set_formation(type: FormationSystem3D.FormationType) -> void:
	_formation_type = type
	_update_formation_positions()


func _update_formation_positions() -> void:
	var positions := FormationSystem3D.get_formation_positions(
		members_alive,
		_formation_type,
		MEMBER_SPACING
	)

	# 현재 회전 적용
	var rotated := FormationSystem3D.rotate_formation(positions, rotation.y)

	var alive_index := 0
	for member in _members:
		if member.is_alive and alive_index < rotated.size():
			member.set_target_position(rotated[alive_index])
			alive_index += 1


# ===== SELECTION =====

func select() -> void:
	is_selected = true
	_update_selection_visual()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.crew_selected.emit(self)


func deselect() -> void:
	is_selected = false
	_update_selection_visual()


func _update_selection_visual() -> void:
	if selection_indicator:
		selection_indicator.visible = is_selected


# ===== MOVEMENT =====

func command_move(target_tile: Vector2i, path: Array = []) -> void:
	## 이동 명령 - 전투 중에도 최우선 수행
	if not is_alive:
		return

	tile_position = target_tile

	# 전투 중이어도 이동 명령 수행 (멤버들은 따라오면서 싸움)
	if is_in_combat:
		end_combat()

	if not path.is_empty():
		_move_path.clear()
		for tile_pos in path:
			var world_pos := _tile_to_world(tile_pos)
			_move_path.append(world_pos)
		_move_index = 0
		is_moving = true
		movement_started.emit(_move_path[-1])
	else:
		var target_world := _tile_to_world(target_tile)
		_move_path = [target_world]
		_move_index = 0
		is_moving = true
		movement_started.emit(target_world)

	# 멤버들에게 이동 알림 (교전 해제 후 따라옴)
	for member in _members:
		if member.is_alive:
			member.on_squad_moving()


func _process_movement(delta: float) -> void:
	if _move_index >= _move_path.size():
		_finish_movement()
		return

	var target := _move_path[_move_index]
	var direction := (target - global_position).normalized()
	var distance := global_position.distance_to(target)

	if distance < 0.1:
		_move_index += 1
		if _move_index >= _move_path.size():
			_finish_movement()
		return

	# 이동
	global_position += direction * move_speed * delta

	# 방향 회전
	if direction.length() > 0.01:
		var look_target := global_position + Vector3(direction.x, 0, direction.z)
		look_at(look_target)
		_update_formation_positions()


func _finish_movement() -> void:
	is_moving = false
	_move_path.clear()
	movement_finished.emit()

	# 멤버들에게 이동 완료 알림 (전투 태세)
	for member in _members:
		if member.is_alive:
			member.on_squad_stopped()


# ===== COMBAT =====

func command_attack(enemy: Node3D) -> void:
	if not is_alive:
		return

	current_target = enemy
	is_in_combat = true
	combat_started.emit(enemy)

	# 멤버들 공격 애니메이션
	for member in _members:
		if member.is_alive:
			member.play_attack()


func _process_combat(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		end_combat()
		return

	if "is_alive" in current_target and not current_target.is_alive:
		end_combat()
		return

	var distance := global_position.distance_to(current_target.global_position)

	# 분대는 이동하지 않음 - 공격 범위 밖이면 전투 종료
	if distance > attack_range + FORMATION_COMBAT_RADIUS:
		end_combat()
		return

	# 적 방향으로 회전만
	var dir := (current_target.global_position - global_position).normalized()
	if dir.length() > 0.01:
		look_at(global_position + Vector3(dir.x, 0, dir.z))

	# 공격 범위 내: 공격 실행
	_attack_timer -= delta
	if _attack_timer <= 0:
		_perform_attack()
		_attack_timer = attack_cooldown


func end_combat() -> void:
	is_in_combat = false
	current_target = null
	combat_ended.emit()

	for member in _members:
		if member.is_alive:
			member.play_idle()


func _perform_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return

	# 공격 애니메이션
	for member in _members:
		if member.is_alive:
			member.play_attack()

	# 클래스별 공격 방식
	match class_id:
		"ranger":
			# 원거리: 투사체 발사
			_spawn_ranged_attack()
		"engineer":
			# 엔지니어도 원거리 공격
			_spawn_ranged_attack()
		_:
			# 근거리: 즉시 데미지 + 이펙트
			_spawn_melee_attack()


func _spawn_ranged_attack() -> void:
	## 원거리 공격: 투사체 생성
	if current_target == null or not is_instance_valid(current_target):
		return

	var total_damage: int = attack_damage * members_alive
	var damage_per_shot: int = maxi(1, total_damage / maxi(1, members_alive))

	# 살아있는 멤버들이 각각 투사체 발사
	var alive_members: Array[SquadMember3D] = []
	for member in _members:
		if member.is_alive:
			alive_members.append(member)

	for i in range(alive_members.size()):
		# 약간씩 시간차를 두고 발사
		var delay: float = i * 0.08
		_spawn_projectile_delayed(alive_members[i], damage_per_shot, delay)


func _spawn_projectile_delayed(member: SquadMember3D, dmg: int, delay: float) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	if current_target == null or not is_instance_valid(current_target):
		return

	if _projectile_scene:
		var projectile: Projectile3D = _projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)

		var from_pos: Vector3 = member.global_position + Vector3(0, 0.3, 0)
		var target_pos: Vector3 = current_target.global_position + Vector3(0, 0.3, 0)
		# 발사 편차 (레벨에 따라 감소: 레벨0=±0.5, 레벨1=±0.35, 레벨2=±0.2)
		var current_spread: float = BASE_SPREAD - (skill_level * SPREAD_PER_LEVEL)
		var spread := Vector3(
			randf_range(-current_spread, current_spread),
			randf_range(-current_spread * 0.3, current_spread * 0.3),
			randf_range(-current_spread, current_spread)
		)
		projectile.launch(from_pos, target_pos + spread, dmg, self)
	else:
		# 폴백: 즉시 데미지
		if current_target.has_method("take_damage"):
			current_target.take_damage(dmg, self)


func _spawn_melee_attack() -> void:
	## 근거리 공격: 즉시 데미지 + 슬래시 이펙트
	if current_target == null or not is_instance_valid(current_target):
		return

	var total_damage: int = attack_damage * members_alive
	if current_target.has_method("take_damage"):
		current_target.take_damage(total_damage, self)

	# 근접 공격 이펙트 생성
	_spawn_melee_effect()


func _spawn_melee_effect() -> void:
	## 근접 공격 슬래시 이펙트
	if current_target == null or not is_instance_valid(current_target):
		return
	if not is_inside_tree():
		return

	# 클래스별 이펙트 색상
	var effect_color: Color
	match class_id:
		"guardian":
			effect_color = Color(0.3, 0.5, 0.9, 0.8)  # 파란색
		"sentinel":
			effect_color = Color(0.9, 0.5, 0.2, 0.8)  # 주황색
		"bionic":
			effect_color = Color(0.7, 0.3, 0.9, 0.8)  # 보라색
		_:
			effect_color = Color(0.8, 0.8, 0.8, 0.8)  # 흰색

	# 슬래시 이펙트 생성
	var effect := MeshInstance3D.new()
	var slash_mesh := BoxMesh.new()
	slash_mesh.size = Vector3(0.6, 0.05, 0.1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = effect_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = effect_color
	mat.emission_energy_multiplier = 2.0
	effect.mesh = slash_mesh
	effect.material_override = mat

	# 위치와 방향 계산 (트리 추가 전)
	var target_pos: Vector3 = current_target.global_position + Vector3(0, 0.4, 0)
	var squad_pos: Vector3 = global_position

	# 트리에 추가 후 위치/회전 설정
	get_tree().current_scene.add_child(effect)
	effect.global_position = target_pos
	effect.look_at(squad_pos)
	effect.rotate_y(randf_range(-0.3, 0.3))

	# 슬래시 애니메이션
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(effect.queue_free)


func _auto_engage_nearby_enemy() -> void:
	## 근처 적을 자동 탐지하여 교전 (팀장 위치 기준 1타일 이내만)
	var detection_range: float = FORMATION_COMBAT_RADIUS + attack_range  # 1타일 + 공격범위

	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node3D = null
	var closest_dist: float = detection_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node3D:
			if "is_alive" in enemy and not enemy.is_alive:
				continue
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = enemy

	if closest_enemy:
		command_attack(closest_enemy)


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	## 분대 데미지 (하위 호환성 - 영역 피해, 시설 효과용)
	## 개별 멤버에게 분배
	if not is_alive:
		return

	# 살아있는 멤버 중 랜덤하게 선택하여 데미지 분배
	var alive_members: Array[SquadMember3D] = []
	for member in _members:
		if member.is_alive:
			alive_members.append(member)

	if alive_members.is_empty():
		_die()
		return

	# 첫 번째 살아있는 멤버에게 데미지 (또는 랜덤 분배)
	var target_member: SquadMember3D = alive_members[randi() % alive_members.size()]
	target_member.take_individual_damage(amount, _source)

	# HP 동기화
	_sync_hp_from_members()

	if current_hp <= 0:
		_die()


func _sync_members_to_health(new_count: int) -> void:
	# 뒤에서부터 사망 처리
	var to_kill := members_alive - new_count
	var killed := 0

	for i in range(_members.size() - 1, -1, -1):
		if killed >= to_kill:
			break
		if _members[i].is_alive:
			_members[i].die()
			killed += 1

	members_alive = new_count
	_update_formation_positions()


func _on_member_visual_died(_index: int) -> void:
	# 시각적 사망 처리 완료 시 호출
	pass


func _on_member_individual_died(member: SquadMember3D) -> void:
	## 개별 멤버 사망 처리 (1:1 전투 시스템)
	_combat_matchmaker.release_engagement(member)

	# HP 동기화
	_sync_hp_from_members()

	members_alive = _count_alive_members()
	member_died.emit(members_alive)
	_update_formation_positions()

	if members_alive <= 0:
		_die()


func _on_member_opponent_killed(_opponent: Node3D) -> void:
	## 멤버가 적을 처치했을 때
	# 새로운 적 찾기는 _process_individual_engagements에서 처리
	pass


func _sync_hp_from_members() -> void:
	## 멤버 HP 합산으로 분대 HP 동기화
	var total: int = 0
	for member in _members:
		if member.is_alive:
			total += member.individual_hp
	current_hp = total
	health_changed.emit(current_hp, max_hp)
	_update_health_bar()


func _count_alive_members() -> int:
	var count: int = 0
	for member in _members:
		if member.is_alive:
			count += 1
	return count


func _process_individual_engagements(_delta: float) -> void:
	## 개별 멤버 교전 관리 (매 프레임)
	# 근접 클래스만 1:1 교전 (원거리는 기존 방식)
	if class_id in ["ranger", "engineer"]:
		return

	# 범위 내 적 탐지
	var nearby_enemies := _get_nearby_enemies()
	if nearby_enemies.is_empty():
		# 교전 중인 멤버들 복귀
		for member in _members:
			if member.is_alive and member.is_engaged:
				member.end_engagement()
		return

	# 비교전 멤버에게 적 할당
	for member in _members:
		if not member.is_alive:
			continue
		if member.is_leader:
			continue  # 지휘관은 위치 고정

		if not member.is_engaged:
			var target: Node3D = _combat_matchmaker.request_opponent(member, nearby_enemies)
			if target:
				member.start_engagement(target)


func _get_nearby_enemies() -> Array:
	## 교전 범위 내 적 목록 (팀장 위치 기준 1타일 이내, 가까운 순)
	var enemies: Array = []
	var detection_range: float = FORMATION_COMBAT_RADIUS + 0.5  # 1타일 + 약간의 여유

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue

		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < detection_range:
			enemies.append({"node": enemy, "dist": dist})

	# 거리순 정렬
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)

	var result: Array = []
	for e in enemies:
		result.append(e.node)
	return result


func heal(amount: int) -> void:
	if not is_alive:
		return

	current_hp += amount
	current_hp = mini(current_hp, max_hp)

	# 멤버 회복
	var new_members := ceili(float(current_hp) / float(HP_PER_MEMBER))
	if new_members > members_alive:
		_revive_members(new_members - members_alive)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()


func _revive_members(count: int) -> void:
	var revived := 0
	for member in _members:
		if revived >= count:
			break
		if not member.is_alive:
			member.revive()
			revived += 1
			members_alive += 1

	_update_formation_positions()


func _die() -> void:
	is_alive = false
	members_alive = 0
	squad_eliminated.emit()

	# 선택 해제
	deselect()

	# 모든 멤버 사망
	for member in _members:
		if member.is_alive:
			member.die()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.entity_died.emit(self)

	# 사망 표시 생성
	_spawn_death_marker()

	# 페이드아웃 후 제거
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(queue_free)


func _spawn_death_marker() -> void:
	## 사망 표시 (해골/십자가 마커)
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.4, 0.05, 0.4)
	marker.mesh = marker_mesh

	# 어두운 빨간색 마커
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.1, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	marker.position = Vector3(0, 0.03, 0)

	add_child(marker)

	# X 표시 생성
	var cross1 := MeshInstance3D.new()
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(0.5, 0.08, 0.08)
	cross1.mesh = cross_mesh
	cross1.rotation_degrees.y = 45
	cross1.position = Vector3(0, 0.08, 0)

	var cross_mat := StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.8, 0.2, 0.2)
	cross_mat.emission_enabled = true
	cross_mat.emission = Color(0.6, 0.1, 0.1)
	cross_mat.emission_energy_multiplier = 1.5
	cross1.material_override = cross_mat

	add_child(cross1)

	var cross2 := MeshInstance3D.new()
	cross2.mesh = cross_mesh
	cross2.rotation_degrees.y = -45
	cross2.position = Vector3(0, 0.08, 0)
	cross2.material_override = cross_mat
	add_child(cross2)

	# 헬스바 숨기기
	if health_bar:
		health_bar.visible = false

	# 선택 인디케이터 숨기기
	if selection_indicator:
		selection_indicator.visible = false

	# 마커 페이드아웃
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tween.parallel().tween_property(cross_mat, "albedo_color:a", 0.0, 1.0)


func _update_health_bar() -> void:
	if health_bar == null:
		return

	# HealthBar3D의 Fill 메시 스케일 조절
	var fill_node := health_bar.get_node_or_null("Fill")
	if fill_node:
		var percent := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		fill_node.scale.x = percent


# ===== SKILLS =====

func use_skill(skill_id: String = "") -> bool:
	if not is_alive:
		return false

	if skill_cooldown > 0:
		return false

	skill_cooldown = skill_max_cooldown
	skill_activated.emit(skill_id)

	# 3D 이펙트 매니저로 이펙트 스폰
	var effects_mgr := get_node_or_null("/root/EffectsManager3D")
	if effects_mgr:
		var direction := -global_transform.basis.z
		effects_mgr.spawn_skill_effect_3d(_get_skill_id_for_class(), global_position, direction)

	match class_id:
		"guardian":
			_skill_shield_bash()
		"sentinel":
			_skill_lance_charge()
		"ranger":
			_skill_volley_fire()
		"engineer":
			_skill_deploy_turret()
		"bionic":
			_skill_blink()

	return true


func _get_skill_id_for_class() -> String:
	match class_id:
		"guardian":
			return "shield_bash"
		"sentinel":
			return "lance_charge"
		"ranger":
			return "volley_fire"
		"engineer":
			return "deploy_turret"
		"bionic":
			return "blink"
		_:
			return ""


func _skill_shield_bash() -> void:
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_lance_charge() -> void:
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_volley_fire() -> void:
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


func _skill_deploy_turret() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.turret_deploy_requested.emit(self, tile_position)


func _skill_blink() -> void:
	if animation_player and animation_player.has_animation("skill"):
		animation_player.play("skill")


# ===== RESUPPLY =====

func start_resupply(facility: Node) -> void:
	set_meta("resupply_facility", facility)


func finish_resupply() -> void:
	heal(max_hp - current_hp)
	remove_meta("resupply_facility")


# ===== UTILITIES =====

func _tile_to_world(tile_pos: Vector2i) -> Vector3:
	return Vector3(tile_pos.x + 0.5, 0, tile_pos.y + 0.5)


func get_class_id() -> String:
	return class_id


func get_health_percent() -> float:
	return float(current_hp) / float(max_hp) if max_hp > 0 else 0.0


func get_members_alive() -> int:
	return members_alive


func get_formation_type() -> FormationSystem3D.FormationType:
	return _formation_type


# ===== PROCEDURAL MODEL (레거시 호환) =====
# 이제 SquadMember3D에서 개별 처리

const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.5, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.9, 0.7, 0.2),
	"bionic": Color(0.7, 0.3, 0.9),
	"militia": Color(0.5, 0.5, 0.5)
}

func _create_procedural_model() -> void:
	# 레거시 호환: 개별 멤버 스폰으로 대체
	_spawn_squad_members()


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
