class_name HitEffect
extends Node2D

## 히트 이펙트
## 데미지 타입에 따른 색상 파티클

@onready var particles: GPUParticles2D = $Particles


func _ready() -> void:
	# 파티클이 없으면 생성
	if particles == null:
		_create_particles()


func _create_particles() -> void:
	particles = GPUParticles2D.new()
	particles.name = "Particles"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 12
	particles.lifetime = 0.4

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 5.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 2.0
	material.scale_max = 4.0

	particles.process_material = material
	add_child(particles)


## 히트 이펙트 설정
## [param damage_type]: 데미지 타입 (색상 결정)
func setup(damage_type: Constants.DamageType) -> void:
	if particles == null:
		_create_particles()

	# 데미지 타입별 색상
	match damage_type:
		Constants.DamageType.PHYSICAL:
			particles.modulate = Color.WHITE
		Constants.DamageType.ENERGY:
			particles.modulate = Color.CYAN
		Constants.DamageType.EXPLOSIVE:
			particles.modulate = Color.ORANGE
		Constants.DamageType.TRUE:
			particles.modulate = Color.MAGENTA
		_:
			particles.modulate = Color.WHITE

	# 파티클 시작
	particles.emitting = true

	# 자동 제거
	_auto_free()


func _auto_free() -> void:
	if particles:
		await get_tree().create_timer(particles.lifetime + 0.1).timeout
	else:
		await get_tree().create_timer(0.5).timeout
	queue_free()
