class_name HitEffect3D
extends Node3D

## 3D 피격 이펙트
## 작은 파티클 버스트


# ===== SIGNALS =====

signal finished()


# ===== EXPORTS =====

@export var auto_destroy: bool = true
@export var lifetime: float = 0.5
@export var hit_color: Color = Color(1.0, 0.3, 0.1, 1.0)


# ===== CHILD NODES =====

@onready var particles: GPUParticles3D = $Particles
@onready var flash_light: OmniLight3D = $FlashLight


# ===== LIFECYCLE =====

func _ready() -> void:
	_start_effect()


func _start_effect() -> void:
	# 파티클 색상 설정
	if particles and particles.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = particles.process_material.duplicate()
		mat.color = hit_color
		particles.process_material = mat
		particles.emitting = true

	# 라이트 플래시
	if flash_light:
		flash_light.light_color = hit_color
		flash_light.light_energy = 2.0

		var tween := create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, lifetime * 0.3)

	# 자동 제거
	if auto_destroy:
		await get_tree().create_timer(lifetime).timeout
		finished.emit()
		queue_free()


# ===== PUBLIC API =====

func set_hit_color(color: Color) -> void:
	hit_color = color
	if is_inside_tree():
		_apply_color()


func _apply_color() -> void:
	if particles and particles.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = particles.process_material
		mat.color = hit_color

	if flash_light:
		flash_light.light_color = hit_color


func set_direction(dir: Vector3) -> void:
	# 파티클 방향 설정
	if dir.length() > 0.01:
		look_at(global_position + dir)
