class_name EnemyUnit3D
extends Node3D

## 3D 적 유닛
## AI 제어, 시설/크루 공격

# ===== SIGNALS =====

signal health_changed(current: int, max_hp: int)
signal died()
signal target_reached(target: Node)
signal attack_started(target: Node)


# ===== CONFIGURATION =====

@export var enemy_id: String = "rusher"
@export var max_hp: int = 30
@export var move_speed: float = 2.0
@export var attack_damage: int = 8
@export var attack_range: float = 1.2
@export var attack_cooldown: float = 1.5


# ===== STATE =====

var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 30
var is_alive: bool = true
var is_moving: bool = false
var is_attacking: bool = false
var current_target: Node = null
var team: int = 1  # 1 = 적

# 방어 스탯 (막기/회피 추가)
var armor: float = 0.0
var evasion: float = 0.0
var block_chance: float = 0.0  # 막기 확률
var block_reduction: float = 0.5  # 막기 시 데미지 감소율

## 개별 멤버 타겟팅 (Bad North 스타일)
var current_member_target: SquadMember3D = null

var _attack_timer: float = 0.0
var _target_position: Vector3 = Vector3.ZERO
var _projectile_scene: PackedScene


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var health_bar: Node3D = $HealthBar3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("units")
	_load_projectile_scene()
	_load_model()


func _load_projectile_scene() -> void:
	var path := "res://src/entities/projectile/Projectile3D.tscn"
	if ResourceLoader.exists(path):
		_projectile_scene = load(path)


func _process(delta: float) -> void:
	if not is_alive:
		return

	_attack_timer -= delta

	if is_attacking and current_target:
		_process_attack(delta)
	elif is_moving:
		_process_movement(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("enemy_id"):
		enemy_id = data.enemy_id
	if data.has("tile_position"):
		tile_position = data.tile_position

	# 리소스에서 적 스탯 로드
	_load_enemy_stats()

	# data에서 오버라이드 (선택적)
	if data.has("max_hp"):
		max_hp = data.max_hp
	if data.has("move_speed"):
		move_speed = data.move_speed
	if data.has("attack_damage"):
		attack_damage = data.attack_damage

	current_hp = max_hp
	_load_model()


func _load_enemy_stats() -> void:
	var enemy_data: Resource = Constants.get_enemy(enemy_id)
	if enemy_data == null:
		push_warning("EnemyUnit3D: Enemy data not found for '%s', using defaults" % enemy_id)
		_apply_default_defense_stats()
		return

	# 리소스 스탯 적용
	if "hp" in enemy_data:
		max_hp = enemy_data.hp
	if "damage" in enemy_data:
		attack_damage = enemy_data.damage
	if "attack_range" in enemy_data:
		attack_range = enemy_data.attack_range
	if "move_speed" in enemy_data:
		move_speed = enemy_data.move_speed
	if "attack_speed" in enemy_data and enemy_data.attack_speed > 0:
		attack_cooldown = 1.0 / enemy_data.attack_speed
	if "armor" in enemy_data:
		armor = enemy_data.armor
	if "evasion" in enemy_data:
		evasion = enemy_data.evasion

	# 방어 스탯 적용
	_apply_default_defense_stats()


func _apply_default_defense_stats() -> void:
	## 적 유형별 방어 스탯
	match enemy_id:
		"shield_trooper":
			block_chance = 0.5  # 높은 막기
			evasion = 0.05
			block_reduction = 0.7
		"brute":
			block_chance = 0.3
			evasion = 0.0  # 느려서 회피 못함
			block_reduction = 0.6
		"jumper":
			block_chance = 0.1
			evasion = 0.4  # 높은 회피
			block_reduction = 0.4
		"rusher":
			block_chance = 0.05
			evasion = 0.2
			block_reduction = 0.4
		_:
			block_chance = 0.1
			evasion = 0.15
			block_reduction = 0.5


func _load_model() -> void:
	if model_container == null:
		return

	# 기존 모델 제거
	for child in model_container.get_children():
		child.queue_free()

	# GLB 모델 로드 시도
	var glb_path := "res://assets/models/enemies/%s.glb" % enemy_id
	if FileAccess.file_exists(glb_path):
		if _load_glb_model(glb_path):
			return

	# 폴백: 프로시저럴 메시 생성
	_create_procedural_model()


func _load_glb_model(path: String) -> bool:
	## GLB 모델 로드
	var scene: PackedScene = load(path)
	if scene == null:
		return false

	var model: Node3D = scene.instantiate()
	if model == null:
		return false

	# 적 타입별 스케일 조정
	var scale_mult: float = 0.4
	match enemy_id:
		"rusher":
			scale_mult = 0.25  # 러셔는 더 작게
		"brute", "heavy_trooper":
			scale_mult = 0.5  # 큰 적은 더 크게
		_:
			scale_mult = 0.4

	model.scale = Vector3.ONE * scale_mult
	# 모델 중심이 피벗이므로 Y 오프셋으로 바닥 위에 배치
	model.position = Vector3(0, 0.2 * scale_mult / 0.4, 0)
	model_container.add_child(model)
	return true


# ===== AI =====

func set_target(target: Node) -> void:
	current_target = target
	current_member_target = null  # 멤버 타겟 초기화

	if target and is_instance_valid(target):
		if "global_position" in target:
			_target_position = target.global_position
		is_moving = true

		if animation_player and animation_player.has_animation("walk"):
			animation_player.play("walk")


func _process_movement(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		is_moving = false
		return

	# 타겟 위치 갱신
	if "global_position" in current_target:
		_target_position = current_target.global_position

	var direction := (_target_position - global_position)
	direction.y = 0
	var distance := direction.length()

	# 공격 범위 도달
	if distance < attack_range:
		is_moving = false
		start_attack()
		return

	# 이동
	direction = direction.normalized()
	global_position += direction * move_speed * delta

	# 회전
	if direction.length() > 0.01:
		look_at(global_position + direction)


func start_attack() -> void:
	if current_target == null:
		return

	is_attacking = true
	attack_started.emit(current_target)

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")


func _process_attack(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		is_attacking = false
		current_member_target = null
		return

	# 타겟이 죽었는지 확인
	if "is_alive" in current_target and not current_target.is_alive:
		is_attacking = false
		current_target = null
		current_member_target = null
		return

	# 개별 멤버 타겟팅 (근접 공격 시)
	if current_member_target == null or not current_member_target.is_alive:
		current_member_target = _find_nearest_member()

	# 공격 쿨다운
	if _attack_timer <= 0:
		_perform_attack()
		_attack_timer = attack_cooldown


func _find_nearest_member() -> SquadMember3D:
	## 타겟 분대에서 가장 가까운 살아있는 멤버 찾기
	if current_target == null or not is_instance_valid(current_target):
		return null

	if not current_target is CrewSquad3D:
		return null

	var squad: CrewSquad3D = current_target as CrewSquad3D
	var nearest: SquadMember3D = null
	var nearest_dist: float = INF

	for member in squad._members:
		if not member.is_alive:
			continue
		var dist: float = global_position.distance_to(member.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = member

	return nearest


func _perform_attack() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return

	# 적 유형별 공격 방식
	match enemy_id:
		"gunner", "sniper", "heavy_trooper":
			# 원거리: 투사체 발사
			_spawn_ranged_attack()
		_:
			# 근거리: 즉시 데미지 + 이펙트
			_spawn_melee_attack()


func _spawn_ranged_attack() -> void:
	## 원거리 공격: 투사체 생성
	if current_target == null or not is_instance_valid(current_target):
		return

	if _projectile_scene:
		var projectile: Projectile3D = _projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)

		var from_pos: Vector3 = global_position + Vector3(0, 0.4, 0)
		var target_pos: Vector3 = current_target.global_position + Vector3(0, 0.3, 0)
		# 발사 편차 추가 (±0.45 범위 - 적은 부정확함)
		var spread := Vector3(
			randf_range(-0.45, 0.45),
			randf_range(-0.15, 0.15),
			randf_range(-0.45, 0.45)
		)
		projectile.launch(from_pos, target_pos + spread, attack_damage, self)

		# 적 투사체 색상 변경 (빨간색)
		var mesh: MeshInstance3D = projectile.get_node_or_null("Mesh")
		if mesh and mesh.material_override:
			var mat: StandardMaterial3D = mesh.material_override.duplicate()
			mat.emission = Color(1, 0.2, 0.2)
			mesh.material_override = mat
	else:
		# 폴백: 즉시 데미지
		if current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage, self)


func _spawn_melee_attack() -> void:
	## 근거리 공격: 개별 멤버 타겟팅
	if current_target == null or not is_instance_valid(current_target):
		return

	# 개별 멤버가 있으면 그 멤버 공격
	if current_member_target and current_member_target.is_alive:
		current_member_target.take_individual_damage(attack_damage, self)
		_spawn_melee_effect_at(current_member_target.global_position)
	elif current_target.has_method("take_damage"):
		# 폴백: 분대 전체에 데미지
		current_target.take_damage(attack_damage, self)
		_spawn_melee_effect()


func _spawn_melee_effect() -> void:
	## 근접 공격 슬래시 이펙트
	if current_target == null or not is_instance_valid(current_target):
		return
	_spawn_melee_effect_at(current_target.global_position)


func _spawn_melee_effect_at(target_pos: Vector3) -> void:
	## 지정 위치에 슬래시 이펙트 생성
	if not is_inside_tree():
		return

	# 적 공격은 빨간색 계열
	var effect_color := Color(0.9, 0.2, 0.2, 0.8)

	# 슬래시 이펙트 생성
	var effect := MeshInstance3D.new()
	var slash_mesh := BoxMesh.new()
	slash_mesh.size = Vector3(0.5, 0.04, 0.08)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = effect_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = effect_color
	mat.emission_energy_multiplier = 2.0
	effect.mesh = slash_mesh
	effect.material_override = mat

	# 위치 저장 (트리 추가 전)
	var effect_pos: Vector3 = target_pos + Vector3(0, 0.3, 0)
	var my_pos: Vector3 = global_position

	# 트리에 추가 후 위치/회전 설정
	get_tree().current_scene.add_child(effect)
	effect.global_position = effect_pos
	effect.look_at(my_pos)
	effect.rotate_y(randf_range(-0.3, 0.3))

	# 슬래시 애니메이션
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3(1.4, 1.4, 1.4), 0.1)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(effect.queue_free)


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> void:
	## 데미지 처리 (막기/회피 포함)
	if not is_alive:
		return

	# 1. 회피 체크
	if randf() < evasion:
		_play_evade_effect()
		return

	# 2. 막기 체크
	var final_damage: int = amount
	if randf() < block_chance:
		final_damage = int(amount * (1.0 - block_reduction))
		_play_block_effect()

	current_hp -= final_damage
	current_hp = maxi(current_hp, 0)

	health_changed.emit(current_hp, max_hp)
	_update_health_bar()
	_flash_damage()

	if current_hp <= 0:
		_die()


func take_individual_damage(amount: int, attacker: Node = null) -> void:
	## 개별 멤버로부터 데미지 (1:1 전투 시스템용)
	take_damage(amount, attacker)


func _play_evade_effect() -> void:
	## 회피 이펙트
	var side_dir: float = 1.0 if randf() > 0.5 else -1.0
	var tween := create_tween()
	tween.tween_property(self, "global_position:x", global_position.x + side_dir * 0.2, 0.1)
	tween.tween_property(self, "global_position:x", global_position.x, 0.15)


func _play_block_effect() -> void:
	## 막기 이펙트
	var tween := create_tween()
	tween.tween_property(self, "global_position:z", global_position.z + 0.1, 0.05)
	tween.tween_property(self, "global_position:z", global_position.z, 0.1)


func _flash_damage() -> void:
	## 피격 플래시
	if model_container and model_container.get_child_count() > 0:
		var first_mesh: MeshInstance3D = model_container.get_child(0) as MeshInstance3D
		if first_mesh and first_mesh.material_override:
			var mat: StandardMaterial3D = first_mesh.material_override
			var original_color: Color = mat.albedo_color
			mat.albedo_color = Color(1, 0.4, 0.4)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(self) and first_mesh and first_mesh.material_override:
				mat.albedo_color = original_color


func _die() -> void:
	is_alive = false
	is_moving = false
	is_attacking = false
	died.emit()

	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

	EventBus.entity_died.emit(self)

	# 제거
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


func _update_health_bar() -> void:
	if health_bar == null:
		return

	var fill := health_bar.get_node_or_null("Fill")
	if fill:
		fill.scale.x = float(current_hp) / float(max_hp)


# ===== UTILITIES =====

func get_enemy_id() -> String:
	return enemy_id


# ===== PROCEDURAL MODEL =====

const ENEMY_COLORS: Dictionary = {
	"rusher": Color(0.8, 0.2, 0.2),
	"gunner": Color(0.6, 0.4, 0.2),
	"shield_trooper": Color(0.3, 0.3, 0.6),
	"jumper": Color(0.2, 0.7, 0.5),
	"heavy_trooper": Color(0.5, 0.2, 0.2),
	"hacker": Color(0.2, 0.8, 0.8),
	"sniper": Color(0.4, 0.5, 0.3),
	"brute": Color(0.6, 0.15, 0.15),
	"storm_creature": Color(0.5, 0.3, 0.7)
}

func _create_procedural_model() -> void:
	if model_container == null:
		return

	var color: Color = ENEMY_COLORS.get(enemy_id, Color(0.7, 0.2, 0.2))

	match enemy_id:
		"rusher":
			_create_rusher_mesh(color)
		"gunner":
			_create_gunner_mesh(color)
		"shield_trooper":
			_create_shield_trooper_mesh(color)
		"jumper":
			_create_jumper_mesh(color)
		"heavy_trooper":
			_create_heavy_trooper_mesh(color)
		"hacker":
			_create_hacker_mesh(color)
		"sniper":
			_create_sniper_mesh(color)
		"brute":
			_create_brute_mesh(color)
		"storm_creature":
			_create_storm_creature_mesh(color)
		_:
			_create_rusher_mesh(color)


func _create_rusher_mesh(color: Color) -> void:
	# Rusher: 가볍고 빠른 형태
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.55
	body.mesh = body_mesh
	body.position = Vector3(0, 0.28, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 팔 (공격 자세)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.3, 0.08)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.18, 0.25, -0.1)
	arm.rotation_degrees = Vector3(-45, 0, 20)
	arm.material_override = _create_material(color.darkened(0.2))
	model_container.add_child(arm)

	_add_enemy_head(color, Vector3(0, 0.7, 0))


func _create_gunner_mesh(color: Color) -> void:
	# Gunner: 총을 든 형태
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 0.6
	body.mesh = body_mesh
	body.position = Vector3(0, 0.3, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 총
	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.1, 0.1, 0.45)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.2, 0.35, -0.2)
	gun.material_override = _create_material(Color(0.25, 0.25, 0.25))
	model_container.add_child(gun)

	_add_enemy_head(color, Vector3(0, 0.75, 0))


func _create_shield_trooper_mesh(color: Color) -> void:
	# Shield Trooper: 방패를 든 형태
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.45, 0.7, 0.3)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.35, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 방패
	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.5, 0.6, 0.06)
	shield.mesh = shield_mesh
	shield.position = Vector3(0, 0.35, -0.22)
	shield.material_override = _create_material(Color(0.4, 0.4, 0.5))
	model_container.add_child(shield)

	_add_enemy_head(color, Vector3(0, 0.85, 0))


func _create_jumper_mesh(color: Color) -> void:
	# Jumper: 점프팩을 단 형태
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.17
	body_mesh.height = 0.5
	body.mesh = body_mesh
	body.position = Vector3(0, 0.25, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 점프팩
	var pack := MeshInstance3D.new()
	var pack_mesh := CylinderMesh.new()
	pack_mesh.top_radius = 0.12
	pack_mesh.bottom_radius = 0.15
	pack_mesh.height = 0.35
	pack.mesh = pack_mesh
	pack.position = Vector3(0, 0.25, 0.2)
	pack.material_override = _create_material(Color(0.3, 0.3, 0.35))
	model_container.add_child(pack)

	_add_enemy_head(color, Vector3(0, 0.65, 0))


func _create_heavy_trooper_mesh(color: Color) -> void:
	# Heavy Trooper: 크고 무거운 형태
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.55, 0.75, 0.4)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.38, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 중화기
	var gun := MeshInstance3D.new()
	var gun_mesh := CylinderMesh.new()
	gun_mesh.top_radius = 0.06
	gun_mesh.bottom_radius = 0.08
	gun_mesh.height = 0.6
	gun.mesh = gun_mesh
	gun.position = Vector3(0.3, 0.4, -0.2)
	gun.rotation_degrees = Vector3(90, 0, 0)
	gun.material_override = _create_material(Color(0.2, 0.2, 0.2))
	model_container.add_child(gun)

	_add_enemy_head(color, Vector3(0, 0.9, 0), true)


func _create_hacker_mesh(color: Color) -> void:
	# Hacker: 기술자 형태
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.16
	body_mesh.height = 0.5
	body.mesh = body_mesh
	body.position = Vector3(0, 0.25, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 안테나
	var antenna := MeshInstance3D.new()
	var ant_mesh := CylinderMesh.new()
	ant_mesh.top_radius = 0.01
	ant_mesh.bottom_radius = 0.02
	ant_mesh.height = 0.3
	antenna.mesh = ant_mesh
	antenna.position = Vector3(0, 0.8, 0)
	antenna.material_override = _create_material(Color(0.2, 0.9, 0.9))
	model_container.add_child(antenna)

	_add_enemy_head(color, Vector3(0, 0.65, 0))


func _create_sniper_mesh(color: Color) -> void:
	# Sniper: 저격수 형태
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.17
	body_mesh.height = 0.6
	body.mesh = body_mesh
	body.position = Vector3(0, 0.3, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 긴 저격총
	var rifle := MeshInstance3D.new()
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.06, 0.06, 0.7)
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(0.2, 0.4, -0.25)
	rifle.material_override = _create_material(Color(0.2, 0.25, 0.2))
	model_container.add_child(rifle)

	_add_enemy_head(color, Vector3(0, 0.75, 0))


func _create_brute_mesh(color: Color) -> void:
	# Brute: 거대한 형태
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.7, 1.0, 0.5)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.5, 0)
	body.material_override = _create_material(color)
	model_container.add_child(body)

	# 큰 팔
	var arm_l := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.2, 0.6, 0.2)
	arm_l.mesh = arm_mesh
	arm_l.position = Vector3(-0.45, 0.4, 0)
	arm_l.material_override = _create_material(color.darkened(0.15))
	model_container.add_child(arm_l)

	var arm_r := MeshInstance3D.new()
	arm_r.mesh = arm_mesh
	arm_r.position = Vector3(0.45, 0.4, 0)
	arm_r.material_override = _create_material(color.darkened(0.15))
	model_container.add_child(arm_r)

	_add_enemy_head(color, Vector3(0, 1.15, 0), true)


func _create_storm_creature_mesh(color: Color) -> void:
	# Storm Creature: 유령 같은 형태
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 0.7
	body.mesh = body_mesh
	body.position = Vector3(0, 0.4, 0)
	var mat := _create_material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	body.material_override = mat
	model_container.add_child(body)

	# 꼬리 같은 하단
	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.25
	tail_mesh.bottom_radius = 0.05
	tail_mesh.height = 0.4
	tail.mesh = tail_mesh
	tail.position = Vector3(0, 0.05, 0)
	tail.material_override = mat
	model_container.add_child(tail)


func _add_enemy_head(color: Color, pos: Vector3, helmet: bool = false) -> void:
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.11 if not helmet else 0.14
	head_mesh.height = 0.22 if not helmet else 0.28
	head.mesh = head_mesh
	head.position = pos
	head.material_override = _create_material(color.darkened(0.1) if helmet else Color(0.6, 0.5, 0.4))
	model_container.add_child(head)


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	return mat
