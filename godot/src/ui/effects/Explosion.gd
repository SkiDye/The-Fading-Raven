class_name Explosion
extends Node2D

## 폭발 이펙트
## AOE 공격, 사망 이펙트 등에 사용

@onready var particles: GPUParticles2D = $Particles
@onready var light: PointLight2D = $Light

var _base_scale: float = 1.0


func _ready() -> void:
	if particles == null:
		_create_particles()
	if light == null:
		_create_light()


func _create_particles() -> void:
	particles = GPUParticles2D.new()
	particles.name = "Particles"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 30
	particles.lifetime = 0.6

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, 100, 0)
	material.scale_min = 3.0
	material.scale_max = 8.0
	material.color = Color.ORANGE

	particles.process_material = material
	add_child(particles)


func _create_light() -> void:
	light = PointLight2D.new()
	light.name = "Light"
	light.color = Color.ORANGE
	light.energy = 2.0
	light.texture_scale = 2.0
	add_child(light)


## 폭발 이펙트 설정
## [param radius]: 폭발 반경 (스케일 결정)
func setup(radius: float) -> void:
	if particles == null:
		_create_particles()
	if light == null:
		_create_light()

	# 반경에 따른 스케일 계산
	_base_scale = radius / 64.0
	scale = Vector2.ONE * _base_scale

	# 파티클 시작
	particles.emitting = true

	# 라이트 페이드
	if light:
		light.energy = 3.0
		var tween := create_tween()
		tween.tween_property(light, "energy", 0.0, 0.5)

	# 자동 제거
	_auto_free()


func _auto_free() -> void:
	await get_tree().create_timer(1.0).timeout
	queue_free()
