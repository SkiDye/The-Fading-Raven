extends Node

## 다국어화(i18n) 시스템
## JSON 파일 기반 번역 관리

# ===== SIGNALS =====

signal locale_changed(new_locale: String)


# ===== CONSTANTS =====

const LOCALES_PATH: String = "res://locales/"
const DEFAULT_LOCALE: String = "ko"
const SUPPORTED_LOCALES: Array[String] = ["ko", "en"]


# ===== STATE =====

var _current_locale: String = DEFAULT_LOCALE
var _translations: Dictionary = {}  # locale -> {key -> text}
var _fallback_locale: String = "en"


# ===== LIFECYCLE =====

func _ready() -> void:
	_load_all_translations()
	_load_saved_locale()
	print("[Localization] Initialized. Locale: %s, Keys: %d" % [_current_locale, _translations.get(_current_locale, {}).size()])


# ===== PUBLIC API =====

## 현재 로케일 가져오기
func get_locale() -> String:
	return _current_locale


## 로케일 변경
func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		push_warning("[Localization] Unsupported locale: %s" % locale)
		return

	if locale == _current_locale:
		return

	_current_locale = locale
	_save_locale()
	locale_changed.emit(locale)
	print("[Localization] Locale changed to: %s" % locale)


## 다음 로케일로 순환
func cycle_locale() -> void:
	var idx: int = SUPPORTED_LOCALES.find(_current_locale)
	var next_idx: int = (idx + 1) % SUPPORTED_LOCALES.size()
	set_locale(SUPPORTED_LOCALES[next_idx])


## 번역 텍스트 가져오기
## @param key: 번역 키 (예: "node_type_battle")
## @param args: 포맷 인자 (예: [1, 2] -> "깊이: 1 / 스톰: 2")
func get_text(key: String, args: Array = []) -> String:
	var text: String = _get_translation(key)

	if args.is_empty():
		return text

	# %s, %d 등의 포맷 문자열 처리
	return text % args


## 번역 키가 존재하는지 확인
func has_key(key: String) -> bool:
	var translations: Dictionary = _translations.get(_current_locale, {})
	return translations.has(key)


## 지원 로케일 목록
func get_supported_locales() -> Array[String]:
	return SUPPORTED_LOCALES.duplicate()


## 로케일 표시 이름
func get_locale_display_name(locale: String) -> String:
	match locale:
		"ko": return "한국어"
		"en": return "English"
		"ja": return "日本語"
		"zh": return "中文"
		_: return locale


# ===== PRIVATE =====

func _load_all_translations() -> void:
	for locale in SUPPORTED_LOCALES:
		_load_translation_file(locale)


func _load_translation_file(locale: String) -> void:
	var file_path: String = LOCALES_PATH + locale + ".json"

	if not FileAccess.file_exists(file_path):
		push_warning("[Localization] Translation file not found: %s" % file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[Localization] Failed to open: %s" % file_path)
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("[Localization] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	_translations[locale] = json.data
	print("[Localization] Loaded %s: %d keys" % [locale, json.data.size()])


func _get_translation(key: String) -> String:
	# 중첩 키 지원 (예: "star_system.depth_label")
	var translations: Dictionary = _translations.get(_current_locale, {})
	var result: Variant = _get_nested_value(translations, key)

	if result != null:
		return str(result)

	# 폴백 로케일에서 찾기
	var fallback: Dictionary = _translations.get(_fallback_locale, {})
	result = _get_nested_value(fallback, key)

	if result != null:
		return str(result)

	# 키 자체 반환 (디버그용)
	push_warning("[Localization] Missing key: %s" % key)
	return "[%s]" % key


func _get_nested_value(dict: Dictionary, key: String) -> Variant:
	## 중첩된 딕셔너리에서 "a.b.c" 형태의 키로 값 조회
	var keys: PackedStringArray = key.split(".")
	var current: Variant = dict

	for k in keys:
		if current is Dictionary and current.has(k):
			current = current[k]
		else:
			return null

	return current


func _load_saved_locale() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved_locale: String = config.get_value("general", "locale", DEFAULT_LOCALE)
		if saved_locale in SUPPORTED_LOCALES:
			_current_locale = saved_locale


func _save_locale() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")  # 기존 설정 로드 (실패해도 OK)
	config.set_value("general", "locale", _current_locale)
	config.save("user://settings.cfg")
