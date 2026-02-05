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
const MEMBER_SPACING: float = 0.4


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
var skill_cooldown: float = 0.0
var skill_max_cooldown: float = 20.0
var equipment_id: String = ""

# 이동
var _move_path: Array[Vector3] = []
var _move_index: int = 0

# 개별 멤버
var _members: Array[SquadMember3D] = []
var _formation_type: FormationSystem3D.FormationType = FormationSystem3D.FormationType.SQUARE

# 프리로드
var _member_scene: PackedScene


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
	add_to_group("crews")
	add_to_group("units")


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 스킬 쿨다운
	if skill_cooldown > 0:
		skill_cooldown -= delta

	# 이동 처리
	if is_moving and not _move_path.is_empty():
		_process_movement(delta)

	# 전투 처리
	if is_in_combat and current_target:
		_process_combat(delta)


func _load_member_scene() -> void:
	var path := "res://src/entities/crew/SquadMember3D.tscn"
	if ResourceLoader.exists(path):
		_member_scene = load(path)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("class_id"):
		class_id = data.class_id
	if data.has("max_members"):
		max_members = data.max_members
	if data.has("tile_position"):
		tile_position = data.tile_position
	if data.has("equipment_id"):
		equipment_id = data.equipment_id

	members_alive = max_members
	_formation_type = FormationSystem3D.get_default_formation_for_class(class_id)
	_setup_health()
	_spawn_squad_members()


func _setup_health() -> void:
	max_hp = members_alive * HP_PER_MEMBER
	current_hp = max_hp


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

		member.died.connect(_on_member_visual_died.bind(i))
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
	EventBus.crew_selected.emit(self)


func deselect() -> void:
	is_selected = false
	_update_selection_visual()


func _update_selection_visual() -> void:
	if selection_indicator:
		selection_indicator.visible = is_selected


# ===== MOVEMENT =====

func command_move(target_tile: Vector2i, path: Array = []) -> void:
	if not is_alive or is_in_combat:
		return

	tile_position = target_tile

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

	# 멤버들 걷기 애니메이션
	for member in _members:
		if member.is_alive:
			member.play_walk()


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

	# 멤버들 idle
	for member in _members:
		if member.is_alive:
			member.play_idle()


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


func _process_combat(_delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		end_combat()
		return

	if "is_alive" in current_target and not current_target.is_alive:
		end_combat()
		return

	var distance := global_position.distance_to(current_target.global_position)
	if distance > attack_range * 2:
		var dir := (current_target.global_position - global_position).normalized()
		global_position += dir * move_speed * get_process_delta_time()


func end_combat() -> void:
	is_in_combat = false
	current_target = null
	combat_ended.emit()

	for member in _members:
		if member.is_alive:
			member.play_idle()


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	if not is_alive:
		return

	current_hp -= amount
	current_hp = maxi(current_hp, 0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()

	# 멤버 사망 동기화
	var new_members := ceili(float(current_hp) / float(HP_PER_MEMBER))
	if new_members < members_alive:
		_sync_members_to_health(new_members)
		member_died.emit(members_alive)

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

	# 모든 멤버 사망
	for member in _members:
		if member.is_alive:
			member.die()

	EventBus.entity_died.emit(self)

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(queue_free)


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
	if EffectsManager3D:
		var direction := -global_transform.basis.z
		EffectsManager3D.spawn_skill_effect_3d(_get_skill_id_for_class(), global_position, direction)

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
	EventBus.turret_deploy_requested.emit(self, tile_position)


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
