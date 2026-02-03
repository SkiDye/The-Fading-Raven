## EventBus - 전역 이벤트 시스템
## 게임 내 컴포넌트 간 느슨한 결합을 위한 시그널 허브
extends Node

# ===========================================
# 게임 상태 이벤트
# ===========================================

signal game_started(seed_string: String, difficulty: int)
signal game_ended(is_victory: bool)
signal game_paused()
signal game_resumed()

# ===========================================
# 런 진행 이벤트
# ===========================================

signal run_started(run_data: Resource)
signal run_ended(is_victory: bool, stats: Dictionary)
signal turn_advanced(turn: int)
signal credits_changed(new_amount: int, delta: int)

# ===========================================
# 섹터 맵 이벤트
# ===========================================

signal sector_generated(sector_data: Dictionary)
signal node_selected(node_id: int)
signal node_visited(node_id: int, node_type: String)
signal storm_advanced(new_position: int)

# ===========================================
# 전투 이벤트
# ===========================================

signal battle_started(station_layout: Dictionary)
signal battle_ended(is_victory: bool, rewards: Dictionary)
signal wave_started(wave_index: int, total_waves: int)
signal wave_cleared(wave_index: int)
signal all_waves_cleared()

# ===========================================
# 크루 이벤트
# ===========================================

signal crew_selected(crew: Node)
signal crew_deselected()
signal crew_moved(crew: Node, from: Vector2i, to: Vector2i)
signal crew_attacked(crew: Node, target: Node, damage: int)
signal crew_damaged(crew: Node, amount: int, source: Node)
signal crew_member_died(crew: Node, remaining: int)
signal crew_wiped(crew: Node)
signal crew_skill_used(crew: Node, skill_id: String)
signal crew_recovering(crew: Node, time_remaining: float)
signal crew_recovered(crew: Node)

# Bad North 전용
signal crew_lance_raised(crew: Node)  # 센티넬 무력화
signal crew_lance_lowered(crew: Node)
signal crew_shield_disabled(crew: Node)  # 가디언 근접전 중
signal crew_shield_enabled(crew: Node)

# ===========================================
# 적 이벤트
# ===========================================

signal enemy_spawned(enemy: Node, spawn_point: Vector2i)
signal enemy_landed(enemy: Node, position: Vector2i)
signal enemy_attacked(enemy: Node, target: Node, damage: int)
signal enemy_damaged(enemy: Node, amount: int, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal enemy_reached_facility(enemy: Node, facility: Node)

# ===========================================
# 시설 이벤트
# ===========================================

signal facility_damaged(facility: Node, amount: int)
signal facility_destroyed(facility: Node)
signal facility_repaired(facility: Node)

# ===========================================
# Raven 드론 이벤트
# ===========================================

signal raven_ability_used(ability_id: String)
signal raven_scout_revealed(area: Rect2i)
signal raven_flare_activated(position: Vector2i)
signal raven_resupply_delivered(crew: Node)
signal raven_orbital_strike_called(position: Vector2i)
signal raven_orbital_strike_landed(position: Vector2i, damage: int)

# ===========================================
# 업그레이드/상점 이벤트
# ===========================================

signal crew_recruited(crew_data: Resource)
signal crew_skill_upgraded(crew: Node, new_level: int)
signal crew_ranked_up(crew: Node, new_rank: String)
signal equipment_acquired(equipment_data: Resource)
signal equipment_equipped(crew: Node, equipment: Resource)
signal equipment_upgraded(equipment: Resource, new_level: int)

# ===========================================
# UI 이벤트
# ===========================================

signal tooltip_requested(text: String, position: Vector2)
signal tooltip_hidden()
signal toast_message(message: String, type: String)
signal dialog_opened(dialog_id: String)
signal dialog_closed(dialog_id: String)

# ===========================================
# 메타 진행 이벤트
# ===========================================

signal achievement_unlocked(achievement_id: String)
signal class_unlocked(class_id: String)
signal difficulty_unlocked(difficulty: int)

# ===========================================
# 헬퍼 함수
# ===========================================

## 토스트 메시지 표시 (편의 함수)
func show_toast(message: String, type: String = "info") -> void:
	toast_message.emit(message, type)


## 크레딧 변경 알림 (편의 함수)
func notify_credits_change(new_amount: int, delta: int) -> void:
	credits_changed.emit(new_amount, delta)
	if delta > 0:
		show_toast("+%d 크레딧" % delta, "success")
	elif delta < 0:
		show_toast("%d 크레딧" % delta, "warning")
