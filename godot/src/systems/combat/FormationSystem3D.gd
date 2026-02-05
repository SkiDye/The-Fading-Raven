class_name FormationSystem3D
extends RefCounted

## 3D 포메이션 시스템
## 분대원들의 배치 위치 계산


# ===== FORMATION TYPES =====

enum FormationType {
	LINE,       # 일렬 횡대
	SQUARE,     # 사각형
	WEDGE,      # 쐐기형 (V자)
	CIRCLE,     # 원형
	STAGGERED   # 지그재그
}


# ===== CONSTANTS =====

const DEFAULT_SPACING: float = 0.4


# ===== PUBLIC API =====

## 포메이션 위치 배열 반환
## [param count]: 유닛 수
## [param type]: 포메이션 타입
## [param spacing]: 유닛 간 간격
## [return]: 로컬 좌표 배열 (중심 기준)
static func get_formation_positions(count: int, type: FormationType, spacing: float = DEFAULT_SPACING) -> Array[Vector3]:
	match type:
		FormationType.LINE:
			return _get_line_formation(count, spacing)
		FormationType.SQUARE:
			return _get_square_formation(count, spacing)
		FormationType.WEDGE:
			return _get_wedge_formation(count, spacing)
		FormationType.CIRCLE:
			return _get_circle_formation(count, spacing)
		FormationType.STAGGERED:
			return _get_staggered_formation(count, spacing)
		_:
			return _get_line_formation(count, spacing)


## 클래스별 기본 포메이션 반환
static func get_default_formation_for_class(class_id: String) -> FormationType:
	match class_id:
		"guardian":
			return FormationType.LINE      # 방패병 - 일렬
		"sentinel":
			return FormationType.WEDGE     # 창병 - 쐐기형
		"ranger":
			return FormationType.STAGGERED # 사격병 - 지그재그
		"engineer":
			return FormationType.SQUARE    # 기술자 - 사각형
		"bionic":
			return FormationType.CIRCLE    # 바이오닉 - 원형
		_:
			return FormationType.SQUARE


## 특정 인덱스의 멤버가 리더인지 확인
static func is_leader_position(index: int, type: FormationType) -> bool:
	match type:
		FormationType.LINE:
			return index == 0
		FormationType.SQUARE:
			return index == 0
		FormationType.WEDGE:
			return index == 0  # 쐐기 끝이 리더
		FormationType.CIRCLE:
			return index == 0  # 중앙이 리더
		FormationType.STAGGERED:
			return index == 0
		_:
			return index == 0


# ===== FORMATION IMPLEMENTATIONS =====

## 일렬 횡대 (가로로 나열)
static func _get_line_formation(count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var half_width := (count - 1) * spacing * 0.5

	for i in range(count):
		var x := i * spacing - half_width
		positions.append(Vector3(x, 0, 0))

	return positions


## 사각형 배치
static func _get_square_formation(count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# 가로 세로 비율 계산
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))

	var half_width := (cols - 1) * spacing * 0.5
	var half_depth := (rows - 1) * spacing * 0.5

	var index := 0
	for row in range(rows):
		for col in range(cols):
			if index >= count:
				break
			var x := col * spacing - half_width
			var z := row * spacing - half_depth
			positions.append(Vector3(x, 0, z))
			index += 1

	return positions


## 쐐기형 (V자 형태, 전방이 뾰족)
static func _get_wedge_formation(count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# 첫 번째는 리더 (가장 앞)
	positions.append(Vector3(0, 0, -spacing * 0.5))

	var remaining := count - 1
	var row := 1

	while remaining > 0:
		# 각 행에 2명씩 (좌우)
		var row_z := row * spacing * 0.7

		if remaining >= 1:
			var offset_x := row * spacing * 0.6
			positions.append(Vector3(-offset_x, 0, row_z))
			remaining -= 1

		if remaining >= 1:
			var offset_x := row * spacing * 0.6
			positions.append(Vector3(offset_x, 0, row_z))
			remaining -= 1

		row += 1

	return positions


## 원형 배치
static func _get_circle_formation(count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	if count == 1:
		positions.append(Vector3.ZERO)
		return positions

	# 리더는 중앙
	positions.append(Vector3.ZERO)

	# 나머지는 원형으로 배치
	var remaining := count - 1
	var radius := spacing * 1.2
	var angle_step := TAU / remaining

	for i in range(remaining):
		var angle := i * angle_step
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		positions.append(Vector3(x, 0, z))

	return positions


## 지그재그 배치 (사격에 유리)
static func _get_staggered_formation(count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	var cols := 4  # 4열 고정
	var rows := ceili(float(count) / float(cols))

	var half_width := (cols - 1) * spacing * 0.5
	var half_depth := (rows - 1) * spacing * 0.6

	var index := 0
	for row in range(rows):
		var row_offset := spacing * 0.5 if row % 2 == 1 else 0.0
		for col in range(cols):
			if index >= count:
				break
			var x := col * spacing - half_width + row_offset
			var z := row * spacing * 0.6 - half_depth
			positions.append(Vector3(x, 0, z))
			index += 1

	return positions


# ===== UTILITIES =====

## 포메이션 회전 적용
static func rotate_formation(positions: Array[Vector3], rotation_y: float) -> Array[Vector3]:
	var rotated: Array[Vector3] = []
	var basis := Basis(Vector3.UP, rotation_y)

	for pos in positions:
		rotated.append(basis * pos)

	return rotated


## 포메이션 스케일 적용
static func scale_formation(positions: Array[Vector3], scale: float) -> Array[Vector3]:
	var scaled: Array[Vector3] = []

	for pos in positions:
		scaled.append(pos * scale)

	return scaled


## 포메이션 타입 이름 반환
static func get_formation_name(type: FormationType) -> String:
	match type:
		FormationType.LINE:
			return "Line"
		FormationType.SQUARE:
			return "Square"
		FormationType.WEDGE:
			return "Wedge"
		FormationType.CIRCLE:
			return "Circle"
		FormationType.STAGGERED:
			return "Staggered"
		_:
			return "Unknown"
