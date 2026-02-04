extends Node

## 전역 이벤트 버스
## 시스템 간 느슨한 결합을 위한 시그널 허브
## S03에서 상세 구현 예정


# ===== COMBAT SIGNALS =====

signal damage_dealt(source: Node, target: Node, amount: int, damage_type: int)
signal entity_died(entity: Node)
signal crew_member_died(squad: Node, member: Node)
signal squad_wiped(squad: Node)
signal skill_used(caster: Node, skill_id: String, target: Variant, level: int)
signal equipment_activated(user: Node, equipment_id: String)
signal knockback_applied(target: Node, direction: Vector2, force: float)
signal stun_applied(target: Node, duration: float)
signal entity_fell_to_void(entity: Node)


# ===== WAVE SIGNALS =====

signal wave_started(wave_number: int, total_waves: int, enemy_preview: Array)
signal wave_ended(wave_number: int)
signal all_waves_cleared()
signal enemy_spawned(enemy: Node, entry_point: Vector2i)
signal enemy_group_landing(entry_point: Vector2i, count: int)


# ===== FACILITY SIGNALS =====

signal facility_damaged(facility: Node, current_hp: int, max_hp: int)
signal facility_destroyed(facility: Node)
signal facility_repair_started(facility: Node, engineer: Node)
signal facility_repaired(facility: Node)
signal crew_recovery_started(crew: Node, facility: Node)
signal crew_recovery_completed(crew: Node)


# ===== TURRET SIGNALS =====

signal turret_deployed(turret: Node, position: Vector2i)
signal turret_destroyed(turret: Node)
signal turret_hacked(turret: Node, hacker: Node)
signal turret_hack_cleared(turret: Node)


# ===== UI SIGNALS =====

signal show_tooltip(content: String, position: Vector2)
signal hide_tooltip()
signal show_toast(message: String, toast_type: int, duration: float)
signal show_modal(title: String, content: String, buttons: Array)
signal modal_closed(result: String)
signal show_floating_text(text: String, position: Vector2, color: Color)
signal screen_shake(intensity: float, duration: float)
signal screen_flash(color: Color, duration: float)


# ===== SELECTION SIGNALS =====

signal crew_selected(crew: Node)
signal crew_deselected()
signal tile_hovered(position: Vector2i)
signal tile_clicked(position: Vector2i, button: int)
signal move_command_issued(crew: Node, target: Vector2i)
signal move_mode_requested(crew: Node)
signal move_mode_ended()
signal skill_targeting_started(crew: Node, skill_id: String)
signal skill_targeting_ended()
signal resupply_requested(crew: Node)


# ===== RAVEN SIGNALS =====

signal raven_ability_used(ability: int)
signal raven_charges_changed(ability: int, charges: int)
signal orbital_strike_targeting_started()
signal orbital_strike_fired(position: Vector2i)


# ===== GAME FLOW SIGNALS =====

signal game_paused()
signal game_resumed()
signal slow_motion_started()
signal slow_motion_ended()
signal battle_started()
signal battle_ended(victory: bool)
signal emergency_evac_started()
signal emergency_evac_completed()
signal emergency_evac_progress(progress: float)


# ===== CAMPAIGN SIGNALS =====

signal sector_node_selected(node_id: String)
signal sector_node_entered(node_id: String)
signal storm_front_advanced(new_depth: int)
signal commander_encountered(commander_data: Variant)
signal equipment_found(equipment_data: Variant)


# ===== META PROGRESSION SIGNALS =====

signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal class_unlocked(class_id: String)
signal equipment_unlocked(equipment_id: String)
signal trait_unlocked(trait_id: String)
signal difficulty_unlocked(difficulty: int)


# ===== AUDIO SIGNALS =====

signal play_sfx(sfx_id: String, position: Vector2)
signal play_bgm(bgm_id: String, fade_duration: float)
signal stop_bgm(fade_duration: float)


# ===== UTILITY =====

## 특정 노드의 모든 연결 해제 (씬 전환 시 사용)
func disconnect_all_for_node(node: Node) -> void:
	for sig in get_signal_list():
		var signal_name: String = sig.name
		for connection in get_signal_connection_list(signal_name):
			if connection.callable.get_object() == node:
				disconnect(signal_name, connection.callable)
