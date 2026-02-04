class_name Utils
extends RefCounted

## 유틸리티 함수 모음
## 정적 함수들로 프로젝트 전반에서 사용


## 두 Vector2i 사이의 맨해튼 거리
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## 두 Vector2i 사이의 체비셰프 거리 (대각선 허용)
static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## 두 Vector2 사이의 유클리드 거리
static func euclidean_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


## 배열에서 랜덤 요소 선택
static func random_choice(array: Array, rng: RandomNumberGenerator = null) -> Variant:
	if array.is_empty():
		return null
	if rng:
		return array[rng.randi() % array.size()]
	return array[randi() % array.size()]


## 가중치 기반 랜덤 선택
static func weighted_random_choice(items: Array, weights: Array, rng: RandomNumberGenerator = null) -> Variant:
	var total := 0.0
	for w in weights:
		total += float(w)

	var r := (rng.randf() if rng else randf()) * total
	var cumulative := 0.0

	for i in range(items.size()):
		cumulative += float(weights[i])
		if r <= cumulative:
			return items[i]

	return items[-1] if not items.is_empty() else null


## 값을 범위 내로 제한 (정수)
static func clamp_int(value: int, min_val: int, max_val: int) -> int:
	return maxi(min_val, mini(max_val, value))


## 선형 보간
static func lerp_float(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## 딕셔너리 깊은 복사
static func deep_copy(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		var value = dict[key]
		if value is Dictionary:
			result[key] = deep_copy(value)
		elif value is Array:
			result[key] = value.duplicate(true)
		else:
			result[key] = value
	return result


## 타일 좌표를 월드 좌표로 변환 (타일 중심)
static func tile_to_world(tile_pos: Vector2i, tile_size: int = Constants.TILE_SIZE) -> Vector2:
	return Vector2(
		tile_pos.x * tile_size + tile_size / 2,
		tile_pos.y * tile_size + tile_size / 2
	)


## 월드 좌표를 타일 좌표로 변환
static func world_to_tile(world_pos: Vector2, tile_size: int = Constants.TILE_SIZE) -> Vector2i:
	return Vector2i(
		int(world_pos.x / tile_size),
		int(world_pos.y / tile_size)
	)


## 배열 섞기 (Fisher-Yates)
static func shuffle_array(array: Array, rng: RandomNumberGenerator = null) -> Array:
	var result := array.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1) if rng else randi() % (i + 1)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result


## 퍼센트 확률 체크
static func percent_chance(percent: float, rng: RandomNumberGenerator = null) -> bool:
	var roll := rng.randf() * 100.0 if rng else randf() * 100.0
	return roll < percent


## 범위 내 랜덤 정수
static func rand_range_int(min_val: int, max_val: int, rng: RandomNumberGenerator = null) -> int:
	if rng:
		return rng.randi_range(min_val, max_val)
	return randi_range(min_val, max_val)


## 범위 내 랜덤 실수
static func rand_range_float(min_val: float, max_val: float, rng: RandomNumberGenerator = null) -> float:
	if rng:
		return rng.randf_range(min_val, max_val)
	return randf_range(min_val, max_val)


## 시간을 MM:SS 형식으로 포맷
static func format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]


## 숫자를 K/M 단위로 포맷
static func format_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(value)


## 방향 벡터를 8방향으로 정규화
static func snap_direction_8(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.001:
		return Vector2.ZERO

	var angle := direction.angle()
	var snapped := snappedf(angle, PI / 4)
	return Vector2.from_angle(snapped)


## 두 노드 사이의 각도 계산
static func angle_between_nodes(from: Node2D, to: Node2D) -> float:
	return from.global_position.angle_to_point(to.global_position)
