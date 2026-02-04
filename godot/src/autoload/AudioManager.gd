extends Node

## 전역 오디오 매니저
## BGM/SFX 재생, 볼륨 컨트롤, 자동 이벤트 연결


# ===== SETTINGS =====

var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var is_muted: bool = false


# ===== INTERNAL =====

const MAX_SFX_PLAYERS: int = 16
const FADE_DURATION: float = 1.0

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _sfx_library: Dictionary = {}
var _bgm_library: Dictionary = {}


func _ready() -> void:
	_setup_players()
	_load_audio_library()
	_connect_signals()


func _setup_players() -> void:
	# BGM 플레이어
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	# SFX 풀
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)


func _load_audio_library() -> void:
	# SFX 경로 정의 (파일 존재 시에만 로드)
	var sfx_ids := [
		"hit_physical",
		"hit_energy",
		"hit_explosive",
		"skill_shield_bash",
		"skill_lance_charge",
		"skill_volley_fire",
		"skill_deploy_turret",
		"skill_blink",
		"enemy_spawn",
		"enemy_death",
		"crew_death",
		"facility_damage",
		"facility_destroyed",
		"wave_start",
		"wave_clear",
		"victory",
		"defeat",
		"ui_click",
		"ui_hover",
	]

	for sfx_id in sfx_ids:
		var sfx_path: String = "res://assets/audio/sfx/%s.wav" % sfx_id
		if ResourceLoader.exists(sfx_path):
			_sfx_library[sfx_id] = load(sfx_path)
		else:
			sfx_path = "res://assets/audio/sfx/%s.ogg" % sfx_id
			if ResourceLoader.exists(sfx_path):
				_sfx_library[sfx_id] = load(sfx_path)

	# BGM 경로 정의
	var bgm_ids := [
		"menu",
		"battle_calm",
		"battle_intense",
		"boss",
		"victory",
		"defeat",
	]

	for bgm_id in bgm_ids:
		var bgm_path: String = "res://assets/audio/music/%s.ogg" % bgm_id
		if ResourceLoader.exists(bgm_path):
			_bgm_library[bgm_id] = load(bgm_path)


func _connect_signals() -> void:
	if EventBus:
		EventBus.play_sfx.connect(_on_play_sfx)
		EventBus.play_bgm.connect(_on_play_bgm)
		EventBus.stop_bgm.connect(_on_stop_bgm)

		# 자동 SFX 연결
		EventBus.damage_dealt.connect(_on_damage_for_sfx)
		EventBus.entity_died.connect(_on_entity_died)
		EventBus.skill_used.connect(_on_skill_used)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.all_waves_cleared.connect(_on_waves_cleared)
		EventBus.facility_destroyed.connect(_on_facility_destroyed)


# ===== SFX =====

## SFX 재생
## [param sfx_id]: SFX 식별자
## [param volume_db]: 볼륨 조정 (dB)
func play_sfx(sfx_id: String, volume_db: float = 0.0) -> void:
	if is_muted:
		return

	# 라이브러리에서 먼저 확인
	var stream: AudioStream = null
	if _sfx_library.has(sfx_id):
		stream = _sfx_library[sfx_id]
	else:
		# 동적 로드 시도
		var path := "res://assets/audio/sfx/%s.wav" % sfx_id
		if ResourceLoader.exists(path):
			stream = load(path)
		else:
			path = "res://assets/audio/sfx/%s.ogg" % sfx_id
			if ResourceLoader.exists(path):
				stream = load(path)

	if stream == null:
		# 오디오 파일 없음 - 조용히 무시
		return

	var player := _sfx_players[_sfx_index]
	player.stream = stream
	player.volume_db = volume_db + linear_to_db(sfx_volume * master_volume)
	player.play()

	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS


## 위치 기반 SFX 재생 (현재는 일반 SFX와 동일)
func play_sfx_at_position(sfx_id: String, _pos: Vector2, volume_db: float = 0.0) -> void:
	play_sfx(sfx_id, volume_db)


func _on_play_sfx(sfx_id: String, _position: Vector2) -> void:
	play_sfx(sfx_id)


# ===== BGM =====

## BGM 재생
## [param bgm_id]: BGM 식별자
## [param fade_in]: 페이드인 시간 (초)
func play_bgm(bgm_id: String, fade_in: float = FADE_DURATION) -> void:
	# 라이브러리에서 먼저 확인
	var stream: AudioStream = null
	if _bgm_library.has(bgm_id):
		stream = _bgm_library[bgm_id]
	else:
		var path := "res://assets/audio/music/%s.ogg" % bgm_id
		if ResourceLoader.exists(path):
			stream = load(path)

	if stream == null:
		return

	var target_volume := linear_to_db(bgm_volume * master_volume)

	if _bgm_player.playing:
		# 크로스페이드
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", -40.0, fade_in / 2)
		tween.tween_callback(func():
			_bgm_player.stream = stream
			_bgm_player.play()
		)
		tween.tween_property(_bgm_player, "volume_db", target_volume, fade_in / 2)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
		create_tween().tween_property(_bgm_player, "volume_db", target_volume, fade_in)


## BGM 정지
## [param fade_out]: 페이드아웃 시간 (초)
func stop_bgm(fade_out: float = FADE_DURATION) -> void:
	if not _bgm_player.playing:
		return

	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", -40.0, fade_out)
	tween.tween_callback(_bgm_player.stop)


func _on_play_bgm(bgm_id: String, fade_duration: float) -> void:
	play_bgm(bgm_id, fade_duration)


func _on_stop_bgm(fade_duration: float) -> void:
	stop_bgm(fade_duration)


# ===== VOLUME CONTROL =====

## 마스터 볼륨 설정
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_update_bgm_volume()


## BGM 볼륨 설정
func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_update_bgm_volume()


## SFX 볼륨 설정
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)


func _update_bgm_volume() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.volume_db = linear_to_db(bgm_volume * master_volume)


## 음소거 설정
func set_muted(muted: bool) -> void:
	is_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


## 음소거 토글
func toggle_mute() -> void:
	set_muted(not is_muted)


# ===== AUTO SFX HANDLERS =====

func _on_damage_for_sfx(_source: Node, _target: Node, _amount: int, damage_type: Constants.DamageType) -> void:
	match damage_type:
		Constants.DamageType.PHYSICAL:
			play_sfx("hit_physical")
		Constants.DamageType.ENERGY:
			play_sfx("hit_energy")
		Constants.DamageType.EXPLOSIVE:
			play_sfx("hit_explosive")
		_:
			play_sfx("hit_physical")


func _on_entity_died(entity: Node) -> void:
	if not is_instance_valid(entity):
		return

	if entity.is_in_group("crews"):
		play_sfx("crew_death")
	elif entity.is_in_group("enemies"):
		play_sfx("enemy_death")


func _on_skill_used(_caster: Node, skill_id: String, _target: Variant, _level: int) -> void:
	var sfx_id := "skill_" + skill_id
	play_sfx(sfx_id)


func _on_wave_started(_wave_num: int, _total: int, _preview: Array) -> void:
	play_sfx("wave_start")


func _on_waves_cleared() -> void:
	play_sfx("wave_clear")


func _on_facility_destroyed(_facility: Node) -> void:
	play_sfx("facility_destroyed")


# ===== UTILITY =====

## 특정 BGM이 현재 재생 중인지 확인
func is_playing_bgm(bgm_id: String) -> bool:
	if not _bgm_player.playing:
		return false
	if _bgm_library.has(bgm_id):
		return _bgm_player.stream == _bgm_library[bgm_id]
	return false


## 현재 BGM 재생 중인지 확인
func is_bgm_playing() -> bool:
	return _bgm_player.playing
