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
	else:
		pos = entity.global_position

	var entity_type := "unknown"
	if entity.is_in_group("crews"):
		entity_type = "crew"
	elif entity.is_in_group("enemies"):
		entity_type = "enemy"

	spawn_death_effect(pos, entity_type)


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
