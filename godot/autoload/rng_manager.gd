## RngManager - 시드 기반 RNG 관리
## 7개 독립 스트림으로 결정론적 생성 보장
extends Node

# 스트림 이름
const STREAM_SECTOR_MAP := "sector_map"
const STREAM_STATION_LAYOUT := "station_layout"
const STREAM_ENEMY_WAVES := "enemy_waves"
const STREAM_ITEMS := "items"
const STREAM_TRAITS := "traits"
const STREAM_COMBAT := "combat"
const STREAM_VISUAL := "visual"

# 스트림 XOR 시드 (독립성 보장)
const STREAM_SEEDS := {
	STREAM_SECTOR_MAP: 0xAAAAAAAA,
	STREAM_STATION_LAYOUT: 0xBBBBBBBB,
	STREAM_ENEMY_WAVES: 0xCCCCCCCC,
	STREAM_ITEMS: 0xDDDDDDDD,
	STREAM_TRAITS: 0xEEEEEEEE,
	STREAM_COMBAT: 0x11111111,
	STREAM_VISUAL: 0xFFFFFFFF,
}

# 시드 문자셋
const SEED_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _master_seed: int = 0
var _streams: Dictionary = {}

signal seed_changed(new_seed: String)


func _ready() -> void:
	# 초기 시드 설정
	set_master_seed(generate_seed_string())


## 마스터 시드 설정 및 모든 스트림 초기화
func set_master_seed(seed_string: String) -> void:
	_master_seed = parse_seed_string(seed_string)
	_initialize_streams()
	seed_changed.emit(seed_string)


## 모든 스트림 초기화
func _initialize_streams() -> void:
	_streams.clear()
	for stream_name in STREAM_SEEDS.keys():
		var stream_seed := _master_seed ^ STREAM_SEEDS[stream_name]
		var rng := RandomNumberGenerator.new()
		rng.seed = stream_seed
		_streams[stream_name] = rng


## 특정 스트림 가져오기
func get_stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		push_error("Unknown RNG stream: " + stream_name)
		return RandomNumberGenerator.new()
	return _streams[stream_name]


## 시드 문자열 생성 (XXXX-XXXX-XXXX 형식)
func generate_seed_string() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var parts: PackedStringArray = []
	for _i in range(3):
		var part := ""
		for _j in range(4):
			part += SEED_CHARS[rng.randi() % SEED_CHARS.length()]
		parts.append(part)

	return "-".join(parts)


## 시드 문자열을 정수로 변환
func parse_seed_string(seed_string: String) -> int:
	var clean := seed_string.to_upper().replace("-", "")
	if clean.length() != 12:
		push_error("Invalid seed format: " + seed_string)
		return 0

	var result: int = 0
	for c in clean:
		var idx := SEED_CHARS.find(c)
		if idx == -1:
			push_error("Invalid character in seed: " + c)
			return 0
		result = result * 36 + idx

	return result


## 시드 문자열 유효성 검사
func is_valid_seed_string(seed_string: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$")
	return pattern.search(seed_string.to_upper()) != null


## 시드 문자열 포맷팅
func format_seed_string(input: String) -> String:
	var clean := ""
	for c in input.to_upper():
		if c in SEED_CHARS:
			clean += c
	clean = clean.substr(0, 12)

	var parts: PackedStringArray = []
	for i in range(0, clean.length(), 4):
		parts.append(clean.substr(i, 4))

	return "-".join(parts)


## 현재 마스터 시드 (정수)
func get_master_seed() -> int:
	return _master_seed


## 현재 시드 문자열
func get_seed_string() -> String:
	# 역변환 (정수 → 문자열)
	var seed_val := _master_seed
	var chars := ""
	for _i in range(12):
		chars = SEED_CHARS[seed_val % 36] + chars
		seed_val = seed_val / 36
	return format_seed_string(chars)


# ===========================================
# 편의 함수 (스트림별 래퍼)
# ===========================================

## 범위 내 정수 (min, max 포함)
func range_int(stream_name: String, min_val: int, max_val: int) -> int:
	return get_stream(stream_name).randi_range(min_val, max_val)


## 범위 내 실수
func range_float(stream_name: String, min_val: float, max_val: float) -> float:
	return get_stream(stream_name).randf_range(min_val, max_val)


## 0~1 랜덤 실수
func randf(stream_name: String) -> float:
	return get_stream(stream_name).randf()


## 확률 체크
func chance(stream_name: String, probability: float) -> bool:
	return get_stream(stream_name).randf() < probability


## 배열에서 랜덤 선택
func pick(stream_name: String, array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[get_stream(stream_name).randi() % array.size()]


## 배열에서 여러 개 랜덤 선택 (중복 없음)
func pick_multiple(stream_name: String, array: Array, count: int) -> Array:
	var shuffled := shuffle(stream_name, array.duplicate())
	return shuffled.slice(0, mini(count, shuffled.size()))


## 가중치 랜덤 선택
func weighted_pick(stream_name: String, items: Array, weights: Array) -> Variant:
	if items.is_empty() or weights.is_empty():
		return null

	var total_weight := 0.0
	for w in weights:
		total_weight += w

	var random := randf(stream_name) * total_weight

	for i in range(items.size()):
		random -= weights[i]
		if random <= 0:
			return items[i]

	return items[items.size() - 1]


## Fisher-Yates 셔플
func shuffle(stream_name: String, array: Array) -> Array:
	var result := array.duplicate()
	var rng := get_stream(stream_name)

	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp

	return result


## 정규 분포 (Box-Muller)
func normal(stream_name: String, mean: float = 0.0, stddev: float = 1.0) -> float:
	var rng := get_stream(stream_name)
	var u1 := rng.randf()
	var u2 := rng.randf()
	var z0 := sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return mean + z0 * stddev


## 클램프된 가우시안
func gaussian(stream_name: String, mean: float, stddev: float, min_val: float, max_val: float) -> float:
	var value: float
	for _i in range(100):  # 최대 시도 횟수
		value = normal(stream_name, mean, stddev)
		if value >= min_val and value <= max_val:
			return value
	return clampf(value, min_val, max_val)
