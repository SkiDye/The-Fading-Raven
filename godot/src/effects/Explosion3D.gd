class_name Explosion3D
extends Node3D

## 3D 폭발 이펙트
## GPUParticles3D 기반


# ===== SIGNALS =====

signal finished()


# ===== EXPORTS =====

@export var auto_destroy: bool = true
@export var lifetime: float = 1.5
@export var size: float = 1.0  # 폭발 크기 배율


# ===== CHILD NODES =====

@onready var particles_fire: GPUParticles3D = $ParticlesFire
@onready var particles_smoke: GPUParticles3D = $ParticlesSmoke
@onready var particles_sparks: GPUParticles3D = $ParticlesSparks
@onready var light: OmniLight3D = $OmniLight3D
@onready var audio: AudioStreamPlayer3D = $AudioPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	_apply_size()
	_start_explosion()


func _apply_size() -> void:
	scale = Vector3.ONE * size

	if light:
		light.omni_range *= size
		light.light_energy *= size


func _start_explosion() -> void:
	# 파티클 시작
	if particles_fire:
		particles_fire.emitting = true
	if particles_smoke:
		particles_smoke.emitting = true
	if particles_sparks:
		particles_sparks.emitting = true

	# 오디오 재생
	if audio:
		audio.play()

	# 라이트 페이드 아웃
	if light:
		var tween := create_tween()
		tween.tween_property(light, "light_energy", 0.0, lifetime * 0.5)

	# 자동 제거
	if auto_destroy:
		await get_tree().create_timer(lifetime).timeout
		finished.emit()
		queue_free()


# ===== PUBLIC API =====

func set_explosion_size(new_size: float) -> void:
	size = new_size
	_apply_size()


func set_color(color: Color) -> void:
	# 파티클 색상 변경
	if particles_fire and particles_fire.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = particles_fire.process_material
		mat.color = color

	if light:
		light.light_color = color
