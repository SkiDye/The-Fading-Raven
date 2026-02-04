class_name SeededRNG
extends RefCounted

## Xorshift128+ 기반 시드 RNG
## 동일 시드 -> 동일 결과 보장
## [br][br]
## 사용 예:
## [codeblock]
## var rng = SeededRNG.new(12345)
## var value = rng.range_int(1, 10)
## [/codeblock]


var _state: Array[int] = [0, 0]
var _initial_seed: int = 0


func _init(seed: int = 0) -> void:
	if seed == 0:
		seed = int(Time.get_unix_time_from_system() * 1000) % 0x7FFFFFFF
	_initial_seed = seed
	_seed(seed)


## 시드 값 반환
func get_seed() -> int:
	return _initial_seed


## 시드 재설정
func reset(seed: int = -1) -> void:
	if seed == -1:
		seed = _initial_seed
	_seed(seed)


func _seed(seed: int) -> void:
	_state[0] = _splitmix64(seed)
	_state[1] = _splitmix64(seed + 0x9E3779B9)


func _splitmix64(x: int) -> int:
	x = ((x ^ (x >> 30)) * 0xBF58476D) & 0x7FFFFFFF
	x = ((x ^ (x >> 27)) * 0x94D049BB) & 0x7FFFFFFF
	return (x ^ (x >> 31)) & 0x7FFFFFFF


## 다음 정수 반환 (0 ~ 0x7FFFFFFF)
func next_int() -> int:
	var s0 := _state[0]
	var s1 := _state[1]
	var result := (s0 + s1) & 0x7FFFFFFF

	s1 ^= s0
	_state[0] = ((s0 << 24) | (s0 >> 7)) ^ s1 ^ ((s1 << 16) & 0x7FFFFFFF)
	_state[1] = ((s1 << 37) | (s1 >> -6)) & 0x7FFFFFFF

	# Godot int 범위 내로 유지
	_state[0] = _state[0] & 0x7FFFFFFF
	_state[1] = _state[1] & 0x7FFFFFFF

	return result


## 0.0 ~ 1.0 사이의 실수 반환
func next_float() -> float:
	return float(next_int()) / float(0x7FFFFFFF)


## min_val 이상 max_val 이하의 정수 반환
func range_int(min_val: int, max_val: int) -> int:
	if min_val >= max_val:
		return min_val
	return min_val + (next_int() % (max_val - min_val + 1))


## min_val 이상 max_val 미만의 실수 반환
func range_float(min_val: float, max_val: float) -> float:
	return min_val + next_float() * (max_val - min_val)


## probability 확률로 true 반환 (0.0 ~ 1.0)
func chance(probability: float) -> bool:
	return next_float() < probability


## 배열에서 랜덤 요소 선택
func choice(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[next_int() % array.size()]


## 가중치 기반 랜덤 선택
## [br][br]
## [param items]: 선택할 요소들
## [param weights]: 각 요소의 가중치
func weighted_choice(items: Array, weights: Array) -> Variant:
	if items.is_empty():
		return null

	var total := 0.0
	for w in weights:
		total += float(w)

	if total <= 0:
		return choice(items)

	var r := next_float() * total
	var cumulative := 0.0

	for i in range(items.size()):
		if i < weights.size():
			cumulative += float(weights[i])
		if r <= cumulative:
			return items[i]

	return items[-1]


## 배열 섞기 (Fisher-Yates)
func shuffle(array: Array) -> Array:
	var result := array.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := range_int(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result


## 정규 분포 랜덤 (Box-Muller)
## [br][br]
## [param mean]: 평균값
## [param stddev]: 표준편차
func normal(mean: float = 0.0, stddev: float = 1.0) -> float:
	var u1 := next_float()
	var u2 := next_float()

	# 0 방지
	if u1 < 0.0001:
		u1 = 0.0001

	var z0 := sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mean + z0 * stddev


## 지정 범위 내 정규 분포 (범위 벗어나면 재시도)
func normal_clamped(mean: float, stddev: float, min_val: float, max_val: float) -> float:
	for i in range(10):  # 최대 10회 시도
		var value := normal(mean, stddev)
		if value >= min_val and value <= max_val:
			return value
	return clamp(normal(mean, stddev), min_val, max_val)
