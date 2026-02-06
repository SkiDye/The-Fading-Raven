class_name SquadMember3D
extends Node3D

## 분대 개별 멤버 3D
## 분대 내 개별 크루원 시각적 표현
## Bad North 스타일 1:1 전투 지원


# ===== SIGNALS =====

signal died()
signal revived()
signal individual_died(member: SquadMember3D)
signal took_damage(amount: int, remaining_hp: int)
signal opponent_killed(opponent: Node3D)


# ===== CONFIGURATION =====

@export var member_index: int = 0
@export var is_leader: bool = false

## 개별 전투 스탯
const DEFAULT_INDIVIDUAL_HP: int = 12
const ATTACK_RANGE: float = 0.8  # 근접 교전 범위
const ENGAGEMENT_MOVE_SPEED: float = 3.0  # 교전 시 이동 속도
const COMMANDER_COMBAT_RADIUS: float = 1.5  # 지휘관 중심 교전 제한 범위


# ===== STATE =====

var class_id: String = "militia"
var is_alive: bool = true
var target_position: Vector3 = Vector3.ZERO
var _current_velocity: Vector3 = Vector3.ZERO

## 개별 HP 시스템
var individual_hp: int = DEFAULT_INDIVIDUAL_HP
var max_individual_hp: int = DEFAULT_INDIVIDUAL_HP

## 1:1 교전 상태
var current_opponent: Node3D = null
var is_engaged: bool = false
var _engagement_position: Vector3 = Vector3.ZERO  # 교전 중 이동 목표

## 공격 쿨다운
var attack_damage: int = 10
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0

## 소속 분대 참조
var parent_squad: Node3D = null

## 분대 이동 상태
var _squad_is_moving: bool = false

## 개인별 교전 판단 편차 (초기화 시 랜덤 설정)
var _personal_follow_distance: float = 0.8  # 이 거리 이상 벌어지면 팀장 따라감
var _personal_aggression: float = 1.0  # 공격성 (높을수록 교전 유지)
var _disengage_delay: float = 0.0  # 교전 해제 지연 타이머
var _reaction_delay: float = 0.0  # 반응 지연 타이머

const BASE_FOLLOW_DISTANCE: float = 0.8
const FOLLOW_DISTANCE_VARIANCE: float = 0.4  # ±0.4 편차
const REACTION_TIME_MAX: float = 0.5  # 최대 반응 지연

const MOVE_SPEED: float = 5.0
const POSITION_THRESHOLD: float = 0.05


# ===== CHILD NODES =====

var _model_container: Node3D
var _mesh: MeshInstance3D
var _hitbox: Area3D  # 투사체 충돌용 히트박스


# ===== CLASS COLORS =====

const CLASS_COLORS: Dictionary = {
	"guardian": Color(0.3, 0.5, 0.9),
	"sentinel": Color(0.9, 0.5, 0.2),
	"ranger": Color(0.3, 0.8, 0.4),
	"engineer": Color(0.9, 0.7, 0.2),
	"bionic": Color(0.7, 0.3, 0.9),
	"militia": Color(0.5, 0.5, 0.5)
}


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_model_container()
	_setup_hitbox()


func _process(delta: float) -> void:
	if not is_alive:
		return

	# 반응 지연 처리
	if _reaction_delay > 0:
		_reaction_delay -= delta

	# 교전 해제 지연 처리
	if _disengage_delay > 0:
		_disengage_delay -= delta

	# 분대 이동 중: 팀장과 너무 멀어지면 따라감 (개인별 편차 적용)
	if _squad_is_moving:
		var dist_from_formation := position.length()  # 로컬 좌표계에서 중심(팀장)까지 거리
		# 공격성이 높으면 더 멀리까지 싸움
		var effective_follow_dist: float = _personal_follow_distance * _personal_aggression
		if dist_from_formation > effective_follow_dist:
			# 반응 지연 체크 (바로 따라가지 않음)
			if _reaction_delay <= 0:
				# 교전 중이어도 따라가기
				if is_engaged:
					end_engagement()
				_update_position(delta)
				return
			# 지연 중에는 현재 상태 유지
			if is_engaged:
				_process_individual_combat(delta)
			return

	# 1:1 전투 처리
	if is_engaged:
		_process_individual_combat(delta)
	else:
		# 목표 위치로 부드럽게 이동
		_update_position(delta)


# ===== INITIALIZATION =====

func initialize(p_class_id: String, index: int, leader: bool = false) -> void:
	class_id = p_class_id
	member_index = index
	is_leader = leader
	is_alive = true
	individual_hp = max_individual_hp

	# 개인별 교전 판단 편차 설정
	_randomize_personality()

	_create_member_mesh()


func _randomize_personality() -> void:
	## 각 멤버마다 다른 성격 부여
	# 팔로우 거리 편차: 0.5 ~ 1.1
	_personal_follow_distance = BASE_FOLLOW_DISTANCE + randf_range(-FOLLOW_DISTANCE_VARIANCE, FOLLOW_DISTANCE_VARIANCE)

	# 공격성: 0.6 ~ 1.4 (높으면 더 오래 싸움)
	_personal_aggression = randf_range(0.6, 1.4)

	# 이동 속도 약간의 편차
	# (MOVE_SPEED는 const라서 별도 변수 사용)
	pass


func set_combat_stats(hp: int, dmg: int, cooldown: float) -> void:
	## 분대에서 전투 스탯 설정
	max_individual_hp = hp
	individual_hp = hp
	attack_damage = dmg
	attack_cooldown = cooldown

	# 지휘관 보너스: HP 1.5배
	if is_leader:
		max_individual_hp = int(hp * 1.5)
		individual_hp = max_individual_hp


func _setup_model_container() -> void:
	_model_container = Node3D.new()
	_model_container.name = "ModelContainer"
	add_child(_model_container)


func _setup_hitbox() -> void:
	## 투사체 충돌용 히트박스 생성
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"

	# 충돌 레이어 설정 (Layer 2: SquadMember)
	_hitbox.collision_layer = 2
	_hitbox.collision_mask = 0  # 감지만 당함

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.15
	shape.height = 0.4
	collision.shape = shape
	collision.position = Vector3(0, 0.2, 0)

	_hitbox.add_child(collision)
	add_child(_hitbox)

	# 메타데이터로 소유자 참조
	_hitbox.set_meta("owner_member", self)


func _create_member_mesh() -> void:
	if _model_container == null:
		_setup_model_container()

	# 기존 메시 제거
	for child in _model_container.get_children():
		child.queue_free()

	# 리더는 약간 더 크게
	var size_mult := 1.15 if is_leader else 1.0

	# GLB 모델 로드 시도
	var glb_path := "res://assets/models/crews/%s.glb" % class_id
	if FileAccess.file_exists(glb_path):
		if _load_glb_model(glb_path, size_mult):
			return

	# 폴백: 프로시저럴 메시 생성
	var color: Color = CLASS_COLORS.get(class_id, Color.GRAY)
	if is_leader:
		color = color.lightened(0.15)

	match class_id:
		"guardian":
			_create_guardian_mesh(color, size_mult)
		"sentinel":
			_create_sentinel_mesh(color, size_mult)
		"ranger":
			_create_ranger_mesh(color, size_mult)
		"engineer":
			_create_engineer_mesh(color, size_mult)
		"bionic":
			_create_bionic_mesh(color, size_mult)
		_:
			_create_militia_mesh(color, size_mult)


func _load_glb_model(path: String, size_mult: float) -> bool:
	## GLB 모델 로드
	var scene: PackedScene = load(path)
	if scene == null:
		return false

	var model: Node3D = scene.instantiate()
	if model == null:
		return false

	model.scale = Vector3.ONE * 0.3 * size_mult  # 크기 조절
	# 모델 중심이 피벗이므로 Y 오프셋으로 바닥 위에 배치
	model.position = Vector3(0, 0.15 * size_mult, 0)
	_model_container.add_child(model)
	return true


func _create_sprite_member(texture_path: String, size_mult: float) -> void:
	## 텍스처 이미지로 빌보드 스프라이트 생성
	var sprite := Sprite3D.new()
	sprite.texture = load(texture_path)
	sprite.pixel_size = 0.003 * size_mult  # 픽셀당 월드 크기
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# 바닥에서 약간 위로
	sprite.position = Vector3(0, 0.25 * size_mult, 0)

	_model_container.add_child(sprite)
	_mesh = null  # Sprite3D는 MeshInstance3D가 아님


# ===== POSITION MANAGEMENT =====

func set_target_position(pos: Vector3) -> void:
	target_position = pos


func set_immediate_position(pos: Vector3) -> void:
	target_position = pos
	position = pos


func _update_position(delta: float) -> void:
	var diff := target_position - position
	if diff.length() < POSITION_THRESHOLD:
		position = target_position
		return

	# 부드러운 이동 (개인별 속도 편차)
	var move_dir := diff.normalized()
	# 멀수록 빨리 따라감, 가까우면 느긋하게
	var urgency: float = clampf(diff.length() / 0.5, 0.7, 1.3)
	var personal_speed: float = MOVE_SPEED * urgency * randf_range(0.9, 1.1)
	var move_dist := minf(diff.length(), personal_speed * delta)
	position += move_dir * move_dist


# ===== 1:1 COMBAT =====

## 방어/회피 스탯 (클래스별로 다름)
var block_chance: float = 0.0  # 막기 확률 (0.0~1.0)
var evade_chance: float = 0.0  # 회피 확률 (0.0~1.0)
var block_reduction: float = 0.5  # 막기 시 데미지 감소율


func set_defense_stats(block: float, evade: float, reduction: float = 0.5) -> void:
	## 방어 스탯 설정
	block_chance = clampf(block, 0.0, 0.8)
	evade_chance = clampf(evade, 0.0, 0.6)
	block_reduction = clampf(reduction, 0.3, 0.8)


func _process_individual_combat(delta: float) -> void:
	## 1:1 교전 처리
	if current_opponent == null or not is_instance_valid(current_opponent):
		end_engagement()
		return

	# 적이 죽었는지 확인
	if "is_alive" in current_opponent and not current_opponent.is_alive:
		opponent_killed.emit(current_opponent)
		end_engagement()
		return

	# 적이 팀장 범위 밖으로 나갔는지 확인 (개인별 공격성 적용)
	if parent_squad:
		var squad_pos: Vector3 = parent_squad.global_position
		var opponent_dist: float = squad_pos.distance_to(current_opponent.global_position)
		# 공격성이 높으면 더 멀리까지 추격
		var max_chase_dist: float = (COMMANDER_COMBAT_RADIUS + ATTACK_RANGE + 0.5) * _personal_aggression
		if opponent_dist > max_chase_dist:
			# 교전 해제 지연 (바로 포기하지 않음)
			if _disengage_delay <= 0:
				_disengage_delay = randf_range(0.1, 0.4)
				return
			# 적이 너무 멀어짐 - 교전 종료, 포메이션 복귀
			end_engagement()
			return
		else:
			# 다시 범위 안으로 들어오면 지연 리셋
			_disengage_delay = 0

	# 교전 위치로 이동 (로컬 좌표계 기준)
	var to_opponent := current_opponent.global_position - global_position
	to_opponent.y = 0
	var dist := to_opponent.length()

	if dist > ATTACK_RANGE:
		# 적에게 접근 (지휘관 범위 제한)
		var move_dir := to_opponent.normalized()
		# 이동 속도에 개인별 편차 (0.8 ~ 1.2배)
		var personal_speed: float = ENGAGEMENT_MOVE_SPEED * randf_range(0.85, 1.15)
		var new_pos := position + move_dir * personal_speed * delta

		# 지휘관 범위 체크 - 멤버가 포메이션 중심(0,0,0)에서 너무 멀어지면 제한
		var dist_from_center := new_pos.length()
		# 공격성에 따라 범위 약간 확장
		var personal_combat_radius: float = COMMANDER_COMBAT_RADIUS * _personal_aggression
		if dist_from_center > personal_combat_radius:
			# 범위 경계에서 멈춤
			new_pos = new_pos.normalized() * personal_combat_radius

		position = new_pos
	else:
		# 공격 범위 내: 공격 실행
		_attack_timer -= delta
		if _attack_timer <= 0:
			_perform_individual_attack()
			_attack_timer = attack_cooldown


func _perform_individual_attack() -> void:
	## 개별 멤버 공격 실행
	if current_opponent == null or not is_instance_valid(current_opponent):
		return

	play_attack()

	# 상대에게 데미지
	if current_opponent.has_method("take_individual_damage"):
		current_opponent.take_individual_damage(attack_damage, self)
	elif current_opponent.has_method("take_damage"):
		current_opponent.take_damage(attack_damage, parent_squad if parent_squad else self)


func take_individual_damage(amount: int, attacker: Node = null) -> void:
	## 개별 멤버 데미지 처리 (막기/회피 포함)
	if not is_alive:
		return

	# 1. 회피 체크
	if randf() < evade_chance:
		_play_evade_effect()
		return

	# 2. 막기 체크
	var final_damage: int = amount
	if randf() < block_chance:
		final_damage = int(amount * (1.0 - block_reduction))
		_play_block_effect()

	# 3. 데미지 적용
	individual_hp -= final_damage
	individual_hp = maxi(individual_hp, 0)

	took_damage.emit(final_damage, individual_hp)
	_flash_damage()

	if individual_hp <= 0:
		die()
		individual_died.emit(self)


func _play_evade_effect() -> void:
	## 회피 이펙트 (사이드 스텝)
	var side_dir: float = 1.0 if randf() > 0.5 else -1.0
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + side_dir * 0.15, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.1)


func _play_block_effect() -> void:
	## 막기 이펙트 (약간 뒤로 밀림)
	var tween := create_tween()
	tween.tween_property(self, "position:z", position.z + 0.08, 0.05)
	tween.tween_property(self, "position:z", position.z, 0.1)


func _flash_damage() -> void:
	## 피격 플래시
	if _mesh and _mesh.material_override:
		var mat: StandardMaterial3D = _mesh.material_override
		var original_color: Color = mat.albedo_color
		mat.albedo_color = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and _mesh and _mesh.material_override:
			mat.albedo_color = original_color


func start_engagement(opponent: Node3D) -> void:
	## 1:1 교전 시작
	# 지휘관은 교전하지 않음
	if is_leader:
		return

	# 반응 지연 중이면 아직 교전 안 함
	if _reaction_delay > 0:
		return

	current_opponent = opponent
	is_engaged = true
	# 첫 공격 타이밍 개인별 편차 (0.3 ~ 0.7 쿨다운)
	_attack_timer = attack_cooldown * randf_range(0.3, 0.7)


func end_engagement() -> void:
	## 교전 종료
	current_opponent = null
	is_engaged = false
	# 포메이션 위치로 복귀
	_return_to_formation()


func _return_to_formation() -> void:
	## 포메이션 위치로 복귀 애니메이션
	# target_position은 분대에서 설정됨
	pass


# ===== SQUAD MOVEMENT =====

func on_squad_moving() -> void:
	## 분대가 이동 시작할 때 호출
	_squad_is_moving = true
	# 개인별 반응 지연 (0 ~ 0.5초)
	_reaction_delay = randf_range(0, REACTION_TIME_MAX)
	play_walk()


func on_squad_stopped() -> void:
	## 분대가 이동 멈출 때 호출 (전투 태세)
	_squad_is_moving = false
	play_idle()


# ===== DEATH/REVIVE =====

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	died.emit()

	# 사망 애니메이션
	_play_death_animation()


func revive() -> void:
	if is_alive:
		return

	is_alive = true
	revived.emit()

	# 부활 애니메이션
	_play_revive_animation()


func _play_death_animation() -> void:
	var tween := create_tween()

	# 쓰러지는 효과
	tween.tween_property(self, "rotation_degrees:x", 90.0, 0.3)
	tween.parallel().tween_property(self, "position:y", -0.1, 0.3)

	# 페이드아웃
	if _mesh and _mesh.material_override:
		var mat: StandardMaterial3D = _mesh.material_override
		tween.tween_property(mat, "albedo_color:a", 0.3, 0.5)


func _play_revive_animation() -> void:
	var tween := create_tween()

	# 일어나는 효과
	tween.tween_property(self, "rotation_degrees:x", 0.0, 0.3)
	tween.parallel().tween_property(self, "position:y", 0.0, 0.3)

	# 페이드인
	if _mesh and _mesh.material_override:
		var mat: StandardMaterial3D = _mesh.material_override
		tween.tween_property(mat, "albedo_color:a", 1.0, 0.3)


# ===== ANIMATION STATES =====

func play_idle() -> void:
	# 약간의 idle 움직임 (선택적)
	pass


func play_walk() -> void:
	# 걷기 애니메이션 효과 (선택적 - 간단한 바운스)
	pass


func play_attack() -> void:
	# 공격 애니메이션
	var tween := create_tween()
	tween.tween_property(self, "position:z", position.z - 0.15, 0.1)
	tween.tween_property(self, "position:z", position.z, 0.1)


# ===== MESH CREATION =====

func _create_guardian_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (넓은 박스)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.18, 0.25, 0.1) * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.13 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 실드
	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.2, 0.22, 0.03) * scale / 0.35
	shield.mesh = shield_mesh
	shield.position = Vector3(0, 0.12 * size_mult, -0.08 * size_mult)
	shield.material_override = _create_material(color.lightened(0.3))
	_model_container.add_child(shield)

	# 머리
	_add_head(color, Vector3(0, 0.28 * size_mult, 0), size_mult)


func _create_sentinel_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (가는 캡슐)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06 * scale / 0.35
	body_mesh.height = 0.22 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.11 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 창
	var lance := MeshInstance3D.new()
	var lance_mesh := CylinderMesh.new()
	lance_mesh.top_radius = 0.008 * scale / 0.35
	lance_mesh.bottom_radius = 0.015 * scale / 0.35
	lance_mesh.height = 0.4 * scale / 0.35
	lance.mesh = lance_mesh
	lance.position = Vector3(0.06 * size_mult, 0.15 * size_mult, -0.1 * size_mult)
	lance.rotation_degrees = Vector3(-30, 0, 15)
	lance.material_override = _create_material(Color(0.7, 0.7, 0.8))
	_model_container.add_child(lance)

	_add_head(color, Vector3(0, 0.26 * size_mult, 0), size_mult)


func _create_ranger_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.065 * scale / 0.35
	body_mesh.height = 0.2 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.1 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 총
	var rifle := MeshInstance3D.new()
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.025, 0.025, 0.15) * scale / 0.35
	rifle.mesh = rifle_mesh
	rifle.position = Vector3(0.06 * size_mult, 0.12 * size_mult, -0.05 * size_mult)
	rifle.material_override = _create_material(Color(0.3, 0.3, 0.35))
	_model_container.add_child(rifle)

	_add_head(color, Vector3(0, 0.24 * size_mult, 0), size_mult)


func _create_engineer_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (박스)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.13, 0.18, 0.11) * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.09 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 백팩
	var backpack := MeshInstance3D.new()
	var bp_mesh := BoxMesh.new()
	bp_mesh.size = Vector3(0.1, 0.12, 0.06) * scale / 0.35
	backpack.mesh = bp_mesh
	backpack.position = Vector3(0, 0.1 * size_mult, 0.08 * size_mult)
	backpack.material_override = _create_material(color.darkened(0.3))
	_model_container.add_child(backpack)

	_add_head(color, Vector3(0, 0.22 * size_mult, 0), size_mult, true)


func _create_bionic_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 몸체 (가는 캡슐)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.05 * scale / 0.35
	body_mesh.height = 0.22 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.11 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	# 블레이드 팔
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.012, 0.012, 0.12) * scale / 0.35

	var blade_l := MeshInstance3D.new()
	blade_l.mesh = blade_mesh
	blade_l.position = Vector3(-0.08 * size_mult, 0.11 * size_mult, -0.05 * size_mult)
	blade_l.rotation_degrees = Vector3(-20, 15, 0)
	blade_l.material_override = _create_material(Color(0.9, 0.2, 0.9))
	_model_container.add_child(blade_l)

	var blade_r := MeshInstance3D.new()
	blade_r.mesh = blade_mesh
	blade_r.position = Vector3(0.08 * size_mult, 0.11 * size_mult, -0.05 * size_mult)
	blade_r.rotation_degrees = Vector3(-20, -15, 0)
	blade_r.material_override = _create_material(Color(0.9, 0.2, 0.9))
	_model_container.add_child(blade_r)

	_add_head(color.lightened(0.2), Vector3(0, 0.26 * size_mult, 0), size_mult)


func _create_militia_mesh(color: Color, size_mult: float) -> void:
	var scale := 0.35 * size_mult

	# 기본 캡슐
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.06 * scale / 0.35
	body_mesh.height = 0.18 * scale / 0.35
	body.mesh = body_mesh
	body.position = Vector3(0, 0.09 * size_mult, 0)
	body.material_override = _create_material(color)
	_model_container.add_child(body)
	_mesh = body

	_add_head(color, Vector3(0, 0.22 * size_mult, 0), size_mult)


func _add_head(color: Color, pos: Vector3, size_mult: float, helmet: bool = false) -> void:
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	var base_radius := 0.04 if not helmet else 0.045
	head_mesh.radius = base_radius * size_mult
	head_mesh.height = base_radius * 2 * size_mult
	head.mesh = head_mesh
	head.position = pos

	if helmet:
		head.material_override = _create_material(color.darkened(0.2))
	else:
		head.material_override = _create_material(Color(0.9, 0.75, 0.6))

	_model_container.add_child(head)


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat
