class_name FloatingText
extends Node2D

## 플로팅 텍스트 이펙트
## 데미지 숫자, 상태 메시지 등 표시

@onready var label: Label = $Label

var velocity: Vector2 = Vector2(0, -50)
var lifetime: float = 1.0
var _initial_lifetime: float = 1.0


func _ready() -> void:
	# Label이 없으면 생성
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)


## 플로팅 텍스트 설정
## [param text]: 표시할 텍스트
## [param color]: 텍스트 색상
## [param size_mult]: 크기 배율
func setup(text: String, color: Color, size_mult: float = 1.0) -> void:
	if label:
		label.text = text
		label.modulate = color
		label.scale = Vector2.ONE * size_mult

		# 폰트 크기 설정
		label.add_theme_font_size_override("font_size", int(16 * size_mult))

	# 랜덤 X 오프셋으로 겹침 방지
	velocity.x = randf_range(-30, 30)

	_initial_lifetime = lifetime


func _process(delta: float) -> void:
	# 위로 이동 + 약간의 중력
	global_position += velocity * delta
	velocity.y += 80 * delta  # 감속

	# 시간 경과
	lifetime -= delta

	# 페이드 아웃
	var alpha := lifetime / _initial_lifetime
	modulate.a = alpha

	# 수명 종료
	if lifetime <= 0:
		queue_free()
