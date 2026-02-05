extends Node

## 전역 이펙트 매니저
## 파티클, 플로팅 텍스트, 화면 효과 관리


# ===== SCENE REFERENCES =====

var _floating_text_scene: PackedScene
var _hit_effect_scene: PackedScene
var _explosion_scene: PackedScene
var _projectile_scene: PackedScene

# ===== CONTAINERS =====

var effects_container: Node2D
var screen_effects: CanvasLayer

# ===== PERSISTENT BATTLE EFFECTS =====

## 피 스플래터들 (전투 끝까지 유지)
var _blood_splatters: Array[Node2D] = []

## 시체들 (전투 끝까지 유지)
var _corpses: Array[Node2D] = []

# ===== CONSTANTS =====

## Bad North 스타일 피 색상
const BLOOD_COLOR := Color("#C41E3A")

## 피 스플래터 설정
const BLOOD_SPLATTER_MIN_SIZE := 8.0
const BLOOD_SPLATTER_MAX_SIZE := 24.0
const BLOOD_SPLATTER_COUNT_ON_HIT := 2
const BLOOD_SPLATTER_COUNT_ON_DEATH := 5

## 시체 설정
const CORPSE_FADE_ALPHA := 0.7

# ===== SCREEN SHAKE =====

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _original_camera_offset: Vector2 = Vector2.ZERO

# ===== OBJECT POOL =====

var _effect_pool: Dictionary = {}
const POOL_SIZE: int = 20


func _ready() -> void:
	_load_scenes()
	_connect_signals()


func _load_scenes() -> void:
	# 지연 로드 패턴 - 파일 존재 시에만 로드
	var paths := {
		"floating_text": "res://src/ui/effects/FloatingText.tscn",
		"hit_effect": "res://src/ui/effects/HitEffect.tscn",
		"explosion": "res://src/ui/effects/Explosion.tscn",
		"projectile": "res://src/entities/projectile/Projectile.tscn"
	}

	if ResourceLoader.exists(paths["floating_text"]):
		_floating_text_scene = load(paths["floating_text"])

	if ResourceLoader.exists(paths["hit_effect"]):
		_hit_effect_scene = load(paths["hit_effect"])

	if ResourceLoader.exists(paths["explosion"]):
		_explosion_scene = load(paths["explosion"])

	if ResourceLoader.exists(paths["projectile"]):
		_projectile_scene = load(paths["projectile"])


func _connect_signals() -> void:
	if EventBus:
		EventBus.show_floating_text.connect(_on_show_floating_text)
		EventBus.screen_shake.connect(_on_screen_shake)
		EventBus.screen_flash.connect(_on_screen_flash)
		EventBus.damage_dealt.connect(_on_damage_dealt)
		EventBus.entity_died.connect(_on_entity_died)
		EventBus.battle_ended.connect(_on_battle_ended)
		EventBus.enemy_group_landing.connect(_on_enemy_group_landing)


## 이펙트 컨테이너 설정 (씬 전환 시 호출 필요)
## [param effects]: 이펙트를 담을 Node2D
## [param screen]: 화면 효과용 CanvasLayer
func set_containers(effects: Node2D, screen: CanvasLayer) -> void:
	effects_container = effects
	screen_effects = screen


# ===== PROJECTILE SPAWNING =====

## 투사체 생성
## [param src]: 발사 소스 노드
## [param tgt]: 타겟 (Node, Vector2, Vector2i)
## [param dmg]: 데미지량
## [param dmg_type]: 데미지 타입
## [param proj_type]: 투사체 타입
## [return]: 생성된 Projectile 노드
func spawn_projectile(
	src: Node,
	tgt: Variant,
	dmg: int,
	dmg_type: Constants.DamageType,
	proj_type: int = 0  # Projectile.ProjectileType.BULLET
) -> Node:
	if _projectile_scene == null or effects_container == null:
		push_warning("EffectsManager: Cannot spawn projectile - scene or container missing")
		return null

	var projectile := _projectile_scene.instantiate()
	projectile.projectile_type = proj_type
	projectile.global_position = src.global_position
	projectile.initialize(src, tgt, dmg, dmg_type)
	effects_container.add_child(projectile)

	return projectile


## AOE 투사체 생성
func spawn_aoe_projectile(
	src: Node,
	target_pos: Variant,
	dmg: int,
	dmg_type: Constants.DamageType,
	radius: float
) -> Node:
	if _projectile_scene == null or effects_container == null:
		return null

	var projectile := _projectile_scene.instantiate()
	projectile.projectile_type = 2  # GRENADE
	projectile.aoe_radius = radius
	projectile.global_position = src.global_position
	projectile.initialize(src, target_pos, dmg, dmg_type)
	effects_container.add_child(projectile)

	return projectile


# ===== FLOATING TEXT =====

## 플로팅 텍스트 생성
## [param text]: 표시할 텍스트
## [param pos]: 월드 좌표
## [param color]: 텍스트 색상
## [param size_mult]: 크기 배율 (1.0 = 기본)
func spawn_floating_text(text: String, pos: Vector2, color: Color = Color.WHITE, size_mult: float = 1.0) -> void:
	if _floating_text_scene == null or effects_container == null:
		return

	var ft := _floating_text_scene.instantiate()
	ft.global_position = pos
	if ft.has_method("setup"):
		ft.setup(text, color, size_mult)
	effects_container.add_child(ft)


## 데미지 숫자 텍스트 생성
## [param amount]: 데미지량 (양수=데미지, 음수=힐)
## [param pos]: 월드 좌표
## [param is_critical]: 크리티컬 여부
func spawn_damage_number(pos: Vector2, amount: int, is_critical: bool = false) -> void:
	var color := Color.RED if amount > 0 else Color.GREEN
	var size := 1.5 if is_critical else 1.0
	var text := str(amount) if amount > 0 else "+" + str(-amount)

	# 위치 약간 랜덤화
	var offset := Vector2(randf_range(-10, 10), randf_range(-5, 5))
	spawn_floating_text(text, pos + offset, color, size)


func _on_show_floating_text(text: String, pos: Vector2, color: Color) -> void:
	spawn_floating_text(text, pos, color)


func _on_damage_dealt(_source: Node, target: Node, amount: int, damage_type: Constants.DamageType) -> void:
	if not is_instance_valid(target):
		return

	var pos: Vector2
	if target.has_method("get_center_position"):
		pos = target.call("get_center_position")
	else:
		pos = target.global_position

	spawn_damage_number(pos, amount)
	spawn_hit_effect(pos, damage_type)

	# 피해 시 피 스플래터 생성 (물리/폭발 데미지만)
	if damage_type == Constants.DamageType.PHYSICAL or damage_type == Constants.DamageType.EXPLOSIVE:
		spawn_blood_splatters(pos, BLOOD_SPLATTER_COUNT_ON_HIT)


# ===== HIT EFFECTS =====

## 히트 이펙트 생성
## [param pos]: 월드 좌표
## [param damage_type]: 데미지 타입 (색상 결정)
func spawn_hit_effect(pos: Vector2, damage_type: Constants.DamageType) -> void:
	if _hit_effect_scene == null or effects_container == null:
		return

	var effect := _hit_effect_scene.instantiate()
	effect.global_position = pos
	if effect.has_method("setup"):
		effect.setup(damage_type)
	effects_container.add_child(effect)


## 사망 이펙트 생성
func spawn_death_effect(pos: Vector2, entity_type: String) -> void:
	# 사망 시 폭발 + 플로팅 텍스트
	spawn_explosion(pos, 32.0)

	var color := Color.CYAN if entity_type == "enemy" else Color.RED
	spawn_floating_text("X", pos, color, 1.5)


func _on_entity_died(entity: Node) -> void:
	if not is_instance_valid(entity):
		return

	var pos: Vector2
	if entity.has_method("get_center_position"):
		pos = entity.call("get_center_position")
	elif entity is Node3D:
		# 3D 엔티티의 경우 XZ를 XY로 변환
		var pos3d: Vector3 = entity.global_position
		pos = Vector2(pos3d.x, pos3d.z)
	else:
		pos = entity.global_position

	var entity_type := "unknown"
	if entity.is_in_group("crews"):
		entity_type = "crew"
	elif entity.is_in_group("enemies"):
		entity_type = "enemy"

	spawn_death_effect(pos, entity_type)

	# 사망 시 피 스플래터 다량 생성
	spawn_blood_splatters(pos, BLOOD_SPLATTER_COUNT_ON_DEATH)

	# 시체 생성
	spawn_corpse(pos, entity_type, entity)


# ===== EXPLOSIONS =====

## 폭발 이펙트 생성
## [param pos]: 월드 좌표
## [param radius]: 폭발 반경
func spawn_explosion(pos: Vector2, radius: float) -> void:
	if _explosion_scene == null or effects_container == null:
		return

	var explosion := _explosion_scene.instantiate()
	explosion.global_position = pos
	if explosion.has_method("setup"):
		explosion.setup(radius)
	effects_container.add_child(explosion)


## 총구 화염 이펙트
func spawn_muzzle_flash(pos: Vector2, direction: Vector2) -> void:
	# 간단한 히트 이펙트로 대체
	spawn_hit_effect(pos, Constants.DamageType.ENERGY)


# ===== SCREEN EFFECTS =====

func _on_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration

	var camera := get_viewport().get_camera_2d()
	if camera:
		_original_camera_offset = camera.offset


func _process(delta: float) -> void:
	if _shake_duration > 0:
		_shake_duration -= delta
		_apply_shake()
	elif _shake_intensity > 0:
		_shake_intensity = 0
		_reset_camera()


func _apply_shake() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.offset = _original_camera_offset + Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)


func _reset_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.offset = _original_camera_offset


func _on_screen_flash(color: Color, duration: float) -> void:
	if screen_effects == null:
		return

	var flash := ColorRect.new()
	flash.color = color
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_effects.add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)


## 화면 흔들림 트리거
## [param intensity]: 흔들림 강도 (픽셀)
## [param duration]: 지속 시간 (초)
func screen_shake(intensity: float = 1.0, duration: float = 0.3) -> void:
	_on_screen_shake(intensity, duration)


## 화면 플래시 트리거
## [param color]: 플래시 색상
## [param duration]: 페이드아웃 시간 (초)
func screen_flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	_on_screen_flash(color, duration)


## 카메라 줌 펀치 효과
func camera_zoom_punch(amount: float = 0.1, duration: float = 0.2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var original_zoom := camera.zoom
	var tween := create_tween()
	tween.tween_property(camera, "zoom", original_zoom * (1.0 + amount), duration * 0.3)
	tween.tween_property(camera, "zoom", original_zoom, duration * 0.7)


# ===== SKILL EFFECTS =====

## Shield Bash 돌진 이펙트
func spawn_shield_bash_effect(start: Vector2, end: Vector2) -> void:
	spawn_floating_text("BASH!", (start + end) / 2, Color.LIGHT_BLUE, 1.2)
	screen_shake(5.0, 0.2)


## Lance Charge 이펙트
func spawn_lance_charge_effect(start: Vector2, direction: Vector2, distance: float) -> void:
	var end := start + direction * distance
	spawn_floating_text("CHARGE!", (start + end) / 2, Color.GOLD, 1.2)
	screen_shake(8.0, 0.3)


## Volley Fire 일제 사격 이펙트
func spawn_volley_fire_effect(positions: Array) -> void:
	for pos in positions:
		if pos is Vector2:
			spawn_hit_effect(pos, Constants.DamageType.ENERGY)


## Blink 순간이동 이펙트
func spawn_blink_effect(start: Vector2, end: Vector2) -> void:
	spawn_floating_text("BLINK", start, Color.PURPLE, 0.8)
	spawn_hit_effect(start, Constants.DamageType.ENERGY)
	spawn_hit_effect(end, Constants.DamageType.ENERGY)


## Deploy Turret 이펙트
func spawn_turret_deploy_effect(pos: Vector2) -> void:
	spawn_floating_text("DEPLOY!", pos, Color.ORANGE, 1.0)
	screen_shake(3.0, 0.15)


## Orbital Strike 궤도 폭격 이펙트
func spawn_orbital_strike_effect(pos: Vector2, radius: float) -> void:
	spawn_explosion(pos, radius)
	screen_shake(15.0, 0.5)
	screen_flash(Color(1, 0.5, 0, 0.5), 0.3)
	camera_zoom_punch(0.15, 0.4)


# ===== BLOOD SPLATTER SYSTEM =====

## 피 스플래터 생성
## [param pos]: 월드 좌표
## [param count]: 생성할 스플래터 수
func spawn_blood_splatters(pos: Vector2, count: int = 1) -> void:
	if effects_container == null:
		return

	for i in range(count):
		var splatter := _create_blood_splatter()
		var offset := Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)
		splatter.global_position = pos + offset
		effects_container.add_child(splatter)
		_blood_splatters.append(splatter)


## 피 스플래터 노드 생성
func _create_blood_splatter() -> Node2D:
	var splatter := Node2D.new()
	splatter.name = "BloodSplatter"

	# 랜덤 크기
	var size := randf_range(BLOOD_SPLATTER_MIN_SIZE, BLOOD_SPLATTER_MAX_SIZE)

	# ColorRect로 간단한 스플래터 표현 (원형 느낌)
	var rect := ColorRect.new()
	rect.size = Vector2(size, size)
	rect.position = Vector2(-size / 2, -size / 2)
	rect.color = BLOOD_COLOR

	# 약간 투명하게 + 랜덤 알파
	rect.color.a = randf_range(0.6, 0.9)

	splatter.add_child(rect)

	# 랜덤 회전으로 다양한 형태 표현
	splatter.rotation = randf() * TAU

	# z-index를 낮게 설정하여 지면에 표시
	splatter.z_index = -1

	return splatter


# ===== CORPSE SYSTEM =====

## 시체 생성
## [param pos]: 월드 좌표
## [param entity_type]: "crew" 또는 "enemy"
## [param original_entity]: 원본 엔티티 (선택적)
func spawn_corpse(pos: Vector2, entity_type: String, original_entity: Node = null) -> void:
	if effects_container == null:
		return

	var corpse := _create_corpse(entity_type, original_entity)
	corpse.global_position = pos
	effects_container.add_child(corpse)
	_corpses.append(corpse)


## 시체 노드 생성
func _create_corpse(entity_type: String, original_entity: Node = null) -> Node2D:
	var corpse := Node2D.new()
	corpse.name = "Corpse"

	# 기본 시체 표현 (간단한 사각형)
	var rect := ColorRect.new()
	var size := Vector2(16, 8)  # 쓰러진 형태

	# 엔티티 타입에 따른 색상
	var base_color: Color
	if entity_type == "enemy":
		base_color = Color(0.15, 0.15, 0.15)  # 검은색 (적)
	else:
		base_color = Color(0.3, 0.5, 0.8)  # 파란색 (아군)

	rect.size = size
	rect.position = Vector2(-size.x / 2, -size.y / 2)
	rect.color = base_color
	rect.color.a = CORPSE_FADE_ALPHA

	corpse.add_child(rect)

	# 시체 위에 피 추가
	var blood_overlay := ColorRect.new()
	blood_overlay.size = Vector2(size.x * 0.6, size.y * 0.8)
	blood_overlay.position = Vector2(
		randf_range(-size.x / 4, size.x / 4) - blood_overlay.size.x / 2,
		-blood_overlay.size.y / 2
	)
	blood_overlay.color = BLOOD_COLOR
	blood_overlay.color.a = 0.7
	corpse.add_child(blood_overlay)

	# 랜덤 회전 (쓰러진 방향)
	corpse.rotation = randf_range(-0.5, 0.5)

	# z-index를 낮게 설정하여 살아있는 유닛 아래에 표시
	corpse.z_index = -1

	return corpse


# ===== BATTLE END CLEANUP =====

## 전투 종료 시 호출 - 피/시체 정리
func _on_battle_ended(_victory: bool) -> void:
	clear_battle_effects()


## 적 그룹 착륙 시 호출
func _on_enemy_group_landing(entry_point: Vector2i, count: int) -> void:
	# 타일 좌표를 월드 좌표로 변환
	var world_pos := Vector2(
		entry_point.x * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF,
		entry_point.y * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF
	)

	# 착륙 마커 효과
	spawn_landing_effect(world_pos, count)

	# 드롭쉽 트레일 (화면 위에서 착륙 지점으로)
	var screen_top := world_pos + Vector2(0, -300)
	spawn_dropship_trail(screen_top, world_pos)


## 전투 중 생성된 피/시체 모두 정리
func clear_battle_effects() -> void:
	# 피 스플래터 정리
	for splatter in _blood_splatters:
		if is_instance_valid(splatter):
			splatter.queue_free()
	_blood_splatters.clear()

	# 시체 정리
	for corpse in _corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	_corpses.clear()


## 특정 영역의 피/시체만 정리 (선택적)
func clear_effects_in_area(center: Vector2, radius: float) -> void:
	# 피 스플래터
	var splatters_to_remove: Array[Node2D] = []
	for splatter in _blood_splatters:
		if is_instance_valid(splatter):
			if splatter.global_position.distance_to(center) <= radius:
				splatter.queue_free()
				splatters_to_remove.append(splatter)

	for s in splatters_to_remove:
		_blood_splatters.erase(s)

	# 시체
	var corpses_to_remove: Array[Node2D] = []
	for corpse in _corpses:
		if is_instance_valid(corpse):
			if corpse.global_position.distance_to(center) <= radius:
				corpse.queue_free()
				corpses_to_remove.append(corpse)

	for c in corpses_to_remove:
		_corpses.erase(c)


# ===== ENEMY LANDING EFFECTS =====

## 적 그룹 착륙 효과 (드롭쉽 접근)
## [param entry_pos]: 진입점 월드 좌표
## [param enemy_count]: 착륙할 적 수
func spawn_landing_effect(entry_pos: Vector2, enemy_count: int) -> void:
	if effects_container == null:
		return

	# 착륙 경고 마커 생성
	var marker := _create_landing_marker(enemy_count)
	marker.global_position = entry_pos
	effects_container.add_child(marker)

	# 착륙 지점 펄스 효과
	_animate_landing_marker(marker)


## 착륙 마커 생성
func _create_landing_marker(enemy_count: int) -> Node2D:
	var marker := Node2D.new()
	marker.name = "LandingMarker"

	# 외부 원 (경고 표시)
	var outer_ring := _create_ring(40.0, Color(1.0, 0.3, 0.1, 0.5), 3.0)
	marker.add_child(outer_ring)

	# 내부 원 (착륙 지점)
	var inner_ring := _create_ring(24.0, Color(1.0, 0.5, 0.2, 0.7), 2.0)
	marker.add_child(inner_ring)

	# 적 수 표시
	if enemy_count > 1:
		var count_label := Label.new()
		count_label.text = "x%d" % enemy_count
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.position = Vector2(-16, -40)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		marker.add_child(count_label)

	marker.z_index = 10

	return marker


## 원형 링 생성 (간단한 구현)
func _create_ring(radius: float, color: Color, width: float) -> Node2D:
	var ring := Node2D.new()

	# ColorRect를 사용한 사각형 대신 중앙 빈 사각형으로 대략적 원형 표현
	# (실제 원형은 Polygon2D나 Line2D 필요)
	var rect := ColorRect.new()
	rect.size = Vector2(radius * 2, radius * 2)
	rect.position = Vector2(-radius, -radius)
	rect.color = color
	rect.color.a = 0.3
	ring.add_child(rect)

	# 중앙을 비우기 위한 검은 사각형
	var inner := ColorRect.new()
	var inner_size := radius * 2 - width * 2
	inner.size = Vector2(inner_size, inner_size)
	inner.position = Vector2(-inner_size / 2, -inner_size / 2)
	inner.color = Color(0, 0, 0, 0)  # 투명
	ring.add_child(inner)

	return ring


## 착륙 마커 애니메이션
func _animate_landing_marker(marker: Node2D) -> void:
	# 펄스 효과 (크기 변화)
	var tween := create_tween()
	tween.set_loops(3)  # 3번 반복

	tween.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(marker, "scale", Vector2(1.0, 1.0), 0.3)

	# 애니메이션 완료 후 페이드아웃
	tween.tween_property(marker, "modulate:a", 0.0, 0.5)
	tween.tween_callback(marker.queue_free)


## 드롭쉽 접근 트레일 효과
## [param start_pos]: 시작 위치 (화면 밖)
## [param end_pos]: 착륙 위치
func spawn_dropship_trail(start_pos: Vector2, end_pos: Vector2) -> void:
	if effects_container == null:
		return

	# 트레일 파티클 여러 개 생성
	var trail_count := 5
	var duration := 0.8

	for i in range(trail_count):
		var delay := i * 0.1
		get_tree().create_timer(delay).timeout.connect(
			_spawn_single_trail_particle.bind(start_pos, end_pos, duration - delay)
		)


## 개별 트레일 파티클
func _spawn_single_trail_particle(start_pos: Vector2, end_pos: Vector2, duration: float) -> void:
	if effects_container == null:
		return

	var particle := ColorRect.new()
	particle.size = Vector2(8, 8)
	particle.position = Vector2(-4, -4)
	particle.color = Color(1.0, 0.6, 0.2, 0.8)
	particle.z_index = 5

	var container := Node2D.new()
	container.add_child(particle)
	container.global_position = start_pos
	effects_container.add_child(container)

	# 이동 애니메이션
	var tween := create_tween()
	tween.tween_property(container, "global_position", end_pos, duration)
	tween.parallel().tween_property(container, "modulate:a", 0.0, duration)
	tween.tween_callback(container.queue_free)
