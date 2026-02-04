class_name EnemyData
extends Resource

## 적 유닛 정적 데이터
## 15종 적의 기본 스탯, 행동 패턴, 특수 메카닉 정의


# ===== BASIC INFO =====

@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export_multiline var description: String


# ===== CLASSIFICATION =====

@export_group("Classification")
@export var tier: int = 1  # 1, 2, 3, 4(boss)
@export var wave_cost: int = 1
@export var min_depth: int = 0  # 최소 출현 깊이
@export var is_boss: bool = false


# ===== BASE STATS =====

@export_group("Base Stats")
@export var hp: int = 10
@export var damage: int = 3
@export var attack_speed: float = 1.0  # attacks per second
@export var move_speed: float = 1.5  # tiles per second
@export var attack_range: float = 1.0  # tiles


# ===== COMBAT =====

@export_group("Combat")
@export var damage_type: int = 0  # Constants.DamageType
@export var armor: float = 0.0
@export var evasion: float = 0.0
@export var knockback_resistance: float = 0.0


# ===== VISUAL =====

@export_group("Visual")
@export var icon: Texture2D
@export var sprite_sheet: Texture2D
@export var color: Color = Color.RED
@export var scale: float = 1.0


# ===== AI BEHAVIOR =====

@export_group("AI Behavior")
@export var behavior_id: String = "melee_basic"
@export var aggression: float = 1.0  # 0=passive, 1=normal, 2=aggressive
@export var target_priority: String = "nearest"  # nearest, facility, crew, turret, weakest


# ===== RANGED =====

@export_group("Ranged")
@export var is_ranged: bool = false
@export var projectile_speed: float = 5.0
@export var keep_distance: float = 0.0  # 유지하려는 거리


# ===== SHIELD =====

@export_group("Shield")
@export var has_shield: bool = false
@export var shield_direction: String = "front"  # front, all
@export var shield_reduction: float = 0.9  # 90% 감소


# ===== JUMP (Jumper) =====

@export_group("Jump")
@export var can_jump: bool = false
@export var jump_range: float = 3.0
@export var jump_cooldown: float = 3.0


# ===== HACKING (Hacker) =====

@export_group("Hacking")
@export var can_hack: bool = false
@export var hack_range: float = 2.0
@export var hack_time: float = 5.0


# ===== SNIPER =====

@export_group("Sniper")
@export var is_sniper: bool = false
@export var sniper_aim_time: float = 3.0
@export var sniper_damage_multiplier: float = 10.0


# ===== DRONE CARRIER =====

@export_group("Drone Carrier")
@export var spawns_drones: bool = false
@export var drone_spawn_interval: float = 10.0
@export var drone_spawn_count: int = 2
@export var max_drones: int = 6


# ===== SHIELD GENERATOR =====

@export_group("Shield Generator")
@export var provides_shield: bool = false
@export var shield_aoe_range: float = 2.0


# ===== SELF DESTRUCT (Storm Creature) =====

@export_group("Self Destruct")
@export var self_destructs: bool = false
@export var explosion_radius: float = 2.0
@export var explosion_damage: int = 20
@export var explosion_trigger_range: float = 0.5


# ===== CLEAVE (Brute) =====

@export_group("Cleave")
@export var has_cleave: bool = false
@export var cleave_angle: float = 120.0
@export var cleave_knockback: float = 3.0
@export var one_hit_kill: bool = false


# ===== GRENADE (Heavy Trooper) =====

@export_group("Grenade")
@export var throws_grenade: bool = false
@export var grenade_range: float = 3.0
@export var grenade_damage: int = 15
@export var grenade_radius: float = 1.5
@export var grenade_cooldown: float = 8.0


# ===== BOSS MECHANICS =====

@export_group("Boss")
@export var boss_abilities: Array[String] = []
@export var is_invulnerable: bool = false
@export var pulse_interval: float = 0.0
@export var pulse_damage: int = 0
@export var summon_interval: float = 0.0
@export var summon_type: String = ""
@export var summon_count: int = 0
@export var buff_allies: bool = false
@export var buff_damage_bonus: float = 0.5


# ===== COMBAT RELATIONS =====

@export_group("Combat Relations")
@export var counters: Array[String] = []  # 이 적을 효과적으로 처치하는 클래스
@export var threats: Array[String] = []   # 이 적이 위협하는 클래스


# ===== METHODS =====

## 난이도에 따른 스케일된 스탯 반환
func get_scaled_stats(difficulty: int, wave_number: int = 1) -> Dictionary:
	var scale_factor := 1.0 + (wave_number - 1) * 0.05

	# 난이도 배율
	var hp_mult := 1.0
	var dmg_mult := 1.0

	match difficulty:
		Constants.Difficulty.NORMAL:
			hp_mult = 1.0
			dmg_mult = 1.0
		Constants.Difficulty.HARD:
			hp_mult = 1.3
			dmg_mult = 1.2
		Constants.Difficulty.VERY_HARD:
			hp_mult = 1.6
			dmg_mult = 1.4
		Constants.Difficulty.NIGHTMARE:
			hp_mult = 2.0
			dmg_mult = 1.6

	return {
		"hp": int(hp * hp_mult * scale_factor),
		"damage": int(damage * dmg_mult * scale_factor),
		"attack_speed": attack_speed,
		"move_speed": move_speed
	}


## 특정 깊이에서 출현 가능 여부
func can_spawn_at_depth(depth: int) -> bool:
	return depth >= min_depth


## 특수 메카닉 보유 여부 확인
func has_special_mechanic() -> bool:
	return (has_shield or can_jump or can_hack or is_sniper or
			spawns_drones or provides_shield or self_destructs or
			has_cleave or throws_grenade or is_boss)


## 디버그용 문자열
func _to_string() -> String:
	return "EnemyData(%s, T%d, HP:%d, DMG:%d)" % [id, tier, hp, damage]
