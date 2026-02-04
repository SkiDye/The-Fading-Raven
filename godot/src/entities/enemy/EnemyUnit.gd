class_name EnemyUnit
extends Entity

## 적 유닛 클래스
## 15종 일반 적 + 2종 보스 구현
## 각 적의 특수 메카닉 포함


# ===== SIGNALS =====

signal target_changed(new_target: Node)
signal special_ability_used(ability_id: String)
signal landing_completed()


# ===== EXPORTS =====

@export var enemy_data: EnemyData


# ===== PUBLIC VARIABLES =====

var current_target: Node
var entry_point: Vector2i
var has_landed: bool = false
var special_state: Dictionary = {}


# ===== PRIVATE VARIABLES =====

# Sniper
var _sniper_aim_timer: float = 0.0
var _sniper_aim_target: Node

# Hacker
var _hacker_hack_target: Node
var _hacker_hack_progress: float = 0.0

# Drone Carrier
var _drone_spawn_timer: float = 0.0
var _spawned_drones: Array[Node] = []

# Shield Generator
var _shield_generator_active: bool = true

# Pirate Captain
var _captain_buff_active: bool = false
var _captain_charge_cooldown: float = 0.0


# ===== CONSTANTS (Defaults, overridden by EnemyData) =====

const DEFAULT_SNIPER_AIM_TIME: float = 3.0
const DEFAULT_HACKER_HACK_TIME: float = 5.0
const DEFAULT_HACKER_DETECT_RANGE: float = 96.0  # 3 tiles
const DEFAULT_HACKER_HACK_RANGE: float = 64.0    # 2 tiles
const DEFAULT_DRONE_SPAWN_INTERVAL: float = 10.0
const DEFAULT_SHIELD_RANGE: float = 64.0         # 2 tiles
const DEFAULT_SELF_DESTRUCT_RANGE: float = 16.0  # 0.5 tile
const DEFAULT_EXPLOSION_RANGE: float = 64.0      # 2 tiles
const DEFAULT_CAPTAIN_BUFF_RANGE: float = 96.0   # 3 tiles
const DEFAULT_CAPTAIN_CHARGE_COOLDOWN: float = 10.0


# ===== COMPUTED PROPERTIES FROM DATA =====

var sniper_aim_time: float:
	get: return enemy_data.sniper_aim_time if enemy_data else DEFAULT_SNIPER_AIM_TIME

var hacker_hack_time: float:
	get: return enemy_data.hack_time if enemy_data else DEFAULT_HACKER_HACK_TIME

var hacker_hack_range: float:
	get: return (enemy_data.hack_range * Constants.TILE_SIZE) if enemy_data else DEFAULT_HACKER_HACK_RANGE

var drone_spawn_interval: float:
	get: return enemy_data.drone_spawn_interval if enemy_data else DEFAULT_DRONE_SPAWN_INTERVAL

var shield_aoe_range: float:
	get: return (enemy_data.shield_aoe_range * Constants.TILE_SIZE) if enemy_data else DEFAULT_SHIELD_RANGE

var self_destruct_range: float:
	get: return (enemy_data.explosion_trigger_range * Constants.TILE_SIZE) if enemy_data else DEFAULT_SELF_DESTRUCT_RANGE

var explosion_range: float:
	get: return (enemy_data.explosion_radius * Constants.TILE_SIZE) if enemy_data else DEFAULT_EXPLOSION_RANGE


# ===== LIFECYCLE =====

func _ready() -> void:
	super._ready()
	team = 1
	add_to_group("enemies")

	if enemy_data:
		_initialize_from_data()


func _process(delta: float) -> void:
	super._process(delta)

	if not is_alive:
		return

	if is_stunned:
		return

	if not has_landed:
		return

	_process_special_mechanics(delta)


# ===== INITIALIZATION =====

func _initialize_from_data() -> void:
	max_hp = enemy_data.hp
	current_hp = max_hp
	entity_id = "enemy_%s_%d" % [enemy_data.id, randi()]


func initialize(data: EnemyData, spawn_point: Vector2i, difficulty: int = Constants.Difficulty.NORMAL, wave_num: int = 1) -> void:
	enemy_data = data
	entry_point = spawn_point
	tile_position = spawn_point

	var scaled = data.get_scaled_stats(difficulty, wave_num)
	max_hp = scaled["hp"]
	current_hp = max_hp

	entity_id = "enemy_%s_%d" % [data.id, randi()]


# ===== SPECIAL MECHANICS DISPATCHER =====

func _process_special_mechanics(delta: float) -> void:
	if enemy_data == null:
		return

	# Flag-based mechanic dispatch (uses EnemyData flags)
	if enemy_data.is_sniper:
		_process_sniper(delta)

	if enemy_data.can_hack:
		_process_hacker(delta)

	if enemy_data.spawns_drones:
		_process_drone_carrier(delta)

	if enemy_data.self_destructs:
		_process_storm_creature(delta)

	if enemy_data.provides_shield:
		_process_shield_generator(delta)

	if enemy_data.throws_grenade:
		_process_grenade(delta)

	if enemy_data.is_boss:
		_process_boss(delta)

	# Storm Core 환경 위험
	if enemy_data.id == "storm_core":
		_process_storm_core(delta)


# ===== SNIPER MECHANICS =====

func _process_sniper(delta: float) -> void:
	if _sniper_aim_target == null:
		_find_sniper_target()
		return

	if not is_instance_valid(_sniper_aim_target) or not _sniper_aim_target.is_alive:
		_sniper_aim_target = null
		_sniper_aim_timer = 0.0
		return

	# Moving resets aim
	if current_state == Constants.EntityState.MOVING:
		_sniper_aim_timer = 0.0
		return

	_sniper_aim_timer += delta

	if _sniper_aim_timer >= sniper_aim_time:
		_fire_sniper_shot()


func _find_sniper_target() -> void:
	var crews = get_tree().get_nodes_in_group("crews")
	if crews.is_empty():
		return

	var closest: Node = null
	var closest_dist := INF

	for crew in crews:
		if crew.is_alive:
			var dist := global_position.distance_to(crew.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = crew

	_sniper_aim_target = closest
	_sniper_aim_timer = 0.0


func _fire_sniper_shot() -> void:
	if _sniper_aim_target == null:
		return

	# Instant kill damage
	var damage := 9999
	_sniper_aim_target.take_damage(damage, Constants.DamageType.PHYSICAL, self)

	special_ability_used.emit("sniper_shot")
	EventBus.show_floating_text.emit("SNIPER!", global_position, Color.RED)

	_sniper_aim_target = null
	_sniper_aim_timer = 0.0


func get_sniper_aim_progress() -> float:
	return _sniper_aim_timer / sniper_aim_time


func get_sniper_target() -> Node:
	return _sniper_aim_target


# ===== HACKER MECHANICS =====

func _process_hacker(delta: float) -> void:
	if _hacker_hack_target == null:
		_find_hack_target()
		return

	if not is_instance_valid(_hacker_hack_target):
		_hacker_hack_target = null
		_hacker_hack_progress = 0.0
		return

	# Check hack range
	var dist := global_position.distance_to(_hacker_hack_target.global_position)
	if dist > hacker_hack_range:
		_hacker_hack_target = null
		_hacker_hack_progress = 0.0
		return

	_hacker_hack_progress += delta

	if _hacker_hack_progress >= hacker_hack_time:
		_complete_hack()


func _find_hack_target() -> void:
	var turrets := get_tree().get_nodes_in_group("turrets")

	for turret in turrets:
		if turret.has_method("is_hacked") and not turret.is_hacked():
			var dist := global_position.distance_to(turret.global_position)
			if dist <= DEFAULT_HACKER_DETECT_RANGE:
				_hacker_hack_target = turret
				_hacker_hack_progress = 0.0
				return


func _complete_hack() -> void:
	if _hacker_hack_target and _hacker_hack_target.has_method("complete_hack"):
		_hacker_hack_target.complete_hack()
		EventBus.turret_hacked.emit(_hacker_hack_target, self)

	special_ability_used.emit("hack_complete")
	_hacker_hack_target = null
	_hacker_hack_progress = 0.0


func get_hack_progress() -> float:
	return _hacker_hack_progress / hacker_hack_time


func get_hack_target() -> Node:
	return _hacker_hack_target


# ===== DRONE CARRIER MECHANICS =====

func _process_drone_carrier(delta: float) -> void:
	# Remove dead drones
	_spawned_drones = _spawned_drones.filter(func(d): return is_instance_valid(d) and d.is_alive)

	# Check max drones
	var max_drones := enemy_data.max_drones if enemy_data else 6
	if _spawned_drones.size() >= max_drones:
		return

	_drone_spawn_timer += delta

	if _drone_spawn_timer >= drone_spawn_interval:
		_spawn_drones()
		_drone_spawn_timer = 0.0


func _spawn_drones() -> void:
	var drone_data: EnemyData = Constants.get_enemy("attack_drone")
	if drone_data == null:
		push_warning("EnemyUnit._spawn_drones: attack_drone data not found")
		return

	for i in range(2):
		var drone := _create_enemy_child(drone_data)
		if drone:
			_spawned_drones.append(drone)

	special_ability_used.emit("spawn_drones")


func _create_enemy_child(data: EnemyData) -> EnemyUnit:
	var scene_path := "res://src/entities/enemy/EnemyUnit.tscn"
	if not ResourceLoader.exists(scene_path):
		push_warning("EnemyUnit._create_enemy_child: scene not found")
		return null

	var scene: PackedScene = load(scene_path)
	var enemy: EnemyUnit = scene.instantiate()
	enemy.initialize(data, tile_position)
	enemy.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	enemy.has_landed = true

	get_parent().add_child(enemy)
	return enemy


func _on_drone_carrier_died() -> void:
	for drone in _spawned_drones:
		if is_instance_valid(drone) and drone.is_alive:
			drone._die()


# ===== STORM CREATURE (SELF-DESTRUCT) =====

func _process_storm_creature(_delta: float) -> void:
	var crews := get_tree().get_nodes_in_group("crews")
	var closest_dist := INF

	for crew in crews:
		if crew.is_alive:
			var dist := global_position.distance_to(crew.global_position)
			if dist < closest_dist:
				closest_dist = dist

	if closest_dist <= self_destruct_range:
		_self_destruct()


func _self_destruct() -> void:
	var damage: int = enemy_data.explosion_damage if enemy_data else 20

	var all_entities := get_tree().get_nodes_in_group("crews") + get_tree().get_nodes_in_group("enemies")

	for entity in all_entities:
		if entity == self:
			continue
		var dist := global_position.distance_to(entity.global_position)
		if dist <= explosion_range:
			entity.take_damage(damage, Constants.DamageType.EXPLOSIVE, self)

	special_ability_used.emit("self_destruct")
	EventBus.show_floating_text.emit("BOOM!", global_position, Color.ORANGE)
	_die()


# ===== SHIELD GENERATOR MECHANICS =====

func _process_shield_generator(_delta: float) -> void:
	if _shield_generator_active:
		_apply_shield_to_nearby()


func _apply_shield_to_nearby() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == self:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= shield_aoe_range:
			if enemy.has_method("apply_shield_buff"):
				enemy.apply_shield_buff()


func apply_shield_buff() -> void:
	special_state["shielded"] = true


func remove_shield_buff() -> void:
	special_state["shielded"] = false


func is_shielded() -> bool:
	return special_state.get("shielded", false)


func _on_shield_generator_died() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= shield_aoe_range:
			if enemy.has_method("remove_shield_buff"):
				enemy.remove_shield_buff()


# ===== GRENADE MECHANICS (Heavy Trooper) =====

var _grenade_cooldown: float = 0.0

func _process_grenade(delta: float) -> void:
	if _grenade_cooldown > 0:
		_grenade_cooldown -= delta


func can_throw_grenade() -> bool:
	return enemy_data and enemy_data.throws_grenade and _grenade_cooldown <= 0


func throw_grenade(target_pos: Vector2) -> void:
	if not can_throw_grenade():
		return

	var cooldown := enemy_data.grenade_cooldown if enemy_data else 8.0
	_grenade_cooldown = cooldown

	# Grenade delay before explosion
	get_tree().create_timer(0.5).timeout.connect(_explode_grenade.bind(target_pos))
	special_ability_used.emit("grenade_throw")


func _explode_grenade(target_pos: Vector2) -> void:
	var damage := enemy_data.grenade_damage if enemy_data else 15
	var radius := (enemy_data.grenade_radius * Constants.TILE_SIZE) if enemy_data else 48.0

	var crews := get_tree().get_nodes_in_group("crews")
	for crew in crews:
		var dist := target_pos.distance_to(crew.global_position)
		if dist <= radius:
			crew.take_damage(damage, Constants.DamageType.EXPLOSIVE, self)

	special_ability_used.emit("grenade_explode")
	EventBus.show_floating_text.emit("BOOM!", target_pos, Color.ORANGE)


# ===== BOSS MECHANICS =====

var _boss_pulse_timer: float = 0.0
var _boss_summon_timer: float = 0.0

func _process_boss(delta: float) -> void:
	if not enemy_data.is_boss:
		return

	# Pulse damage
	if enemy_data.pulse_interval > 0:
		_boss_pulse_timer += delta
		if _boss_pulse_timer >= enemy_data.pulse_interval:
			_boss_pulse()
			_boss_pulse_timer = 0.0

	# Summon minions
	if enemy_data.summon_interval > 0:
		_boss_summon_timer += delta
		if _boss_summon_timer >= enemy_data.summon_interval:
			_boss_summon()
			_boss_summon_timer = 0.0

	# Buff allies (Pirate Captain)
	if enemy_data.buff_allies:
		_apply_captain_buff()


func _boss_pulse() -> void:
	var damage := enemy_data.pulse_damage
	var crews := get_tree().get_nodes_in_group("crews")

	for crew in crews:
		if crew.is_alive:
			crew.take_damage(damage, Constants.DamageType.ENERGY, self)

	special_ability_used.emit("boss_pulse")


func _boss_summon() -> void:
	if enemy_data.summon_type.is_empty():
		return

	for i in enemy_data.summon_count:
		special_ability_used.emit("boss_summon_" + enemy_data.summon_type)


func _apply_captain_buff() -> void:
	var buff_range := DEFAULT_CAPTAIN_BUFF_RANGE
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == self:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= buff_range:
			enemy.special_state["captain_buff"] = true
			enemy.special_state["damage_bonus"] = enemy_data.buff_damage_bonus


# ===== JUMPER MECHANICS =====

func can_jump() -> bool:
	if enemy_data == null:
		return false
	return enemy_data.ability_id == "jumper" and not special_state.get("jump_cooldown", false)


func perform_jump(target_pos: Vector2i) -> void:
	tile_position = target_pos
	global_position = Vector2(target_pos.x * Constants.TILE_SIZE, target_pos.y * Constants.TILE_SIZE)

	special_state["jump_cooldown"] = true

	get_tree().create_timer(3.0).timeout.connect(func():
		special_state["jump_cooldown"] = false
	)

	special_ability_used.emit("jump")


# ===== BRUTE MECHANICS =====

func get_knockback_force() -> float:
	if enemy_data and enemy_data.ability_id == "brute":
		return 3.0
	return 1.0


func has_frontal_shield() -> bool:
	if enemy_data == null:
		return false
	return enemy_data.id in ["shield_trooper", "heavy_trooper"]


# ===== BOSS: PIRATE CAPTAIN =====

func _process_pirate_captain(delta: float) -> void:
	_captain_charge_cooldown = max(0.0, _captain_charge_cooldown - delta)

	if not _captain_buff_active:
		_activate_captain_buff()


func _activate_captain_buff() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == self:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= DEFAULT_CAPTAIN_BUFF_RANGE:
			enemy.special_state["captain_buff"] = true

	_captain_buff_active = true


func captain_charge_attack(direction: Vector2) -> bool:
	if _captain_charge_cooldown > 0:
		return false

	# Charge attack logic - S08 implements actual movement
	_captain_charge_cooldown = DEFAULT_CAPTAIN_CHARGE_COOLDOWN
	special_ability_used.emit("captain_charge")
	return true


func captain_summon_reinforcements() -> void:
	var rusher_data: EnemyData = Constants.get_enemy("rusher")
	if rusher_data == null:
		return

	for i in range(5):
		_create_enemy_child(rusher_data)

	special_ability_used.emit("summon_reinforcements")


# ===== STORM CORE (ENVIRONMENTAL HAZARD BOSS) =====

signal hazard_zone_created(position: Vector2, radius: float, duration: float)
signal storm_pulse_fired(damage: int)

var _storm_hazard_timer: float = 0.0
var _storm_pulse_timer: float = 0.0
var _active_hazard_zones: Array[Dictionary] = []

const STORM_HAZARD_INTERVAL: float = 8.0
const STORM_PULSE_INTERVAL: float = 5.0
const STORM_HAZARD_DURATION: float = 4.0
const STORM_HAZARD_RADIUS: float = 64.0  # 2 tiles
const STORM_PULSE_DAMAGE: int = 3


func _process_storm_core(delta: float) -> void:
	# Storm Core는 이동하지 않고 환경 위험만 생성

	# 위험 지역 생성 타이머
	_storm_hazard_timer += delta
	if _storm_hazard_timer >= STORM_HAZARD_INTERVAL:
		_create_hazard_zone()
		_storm_hazard_timer = 0.0

	# 전역 펄스 데미지 타이머
	_storm_pulse_timer += delta
	if _storm_pulse_timer >= STORM_PULSE_INTERVAL:
		_storm_global_pulse()
		_storm_pulse_timer = 0.0

	# 활성 위험 지역 처리
	_process_hazard_zones(delta)


func _create_hazard_zone() -> void:
	# 시설 우선 타겟팅
	var target_pos := _find_hazard_target()

	var hazard := {
		"position": target_pos,
		"radius": STORM_HAZARD_RADIUS,
		"duration": STORM_HAZARD_DURATION,
		"remaining": STORM_HAZARD_DURATION,
		"damage_per_tick": 5,
		"tick_interval": 0.5,
		"tick_timer": 0.0
	}

	_active_hazard_zones.append(hazard)
	hazard_zone_created.emit(target_pos, STORM_HAZARD_RADIUS, STORM_HAZARD_DURATION)
	special_ability_used.emit("storm_hazard")

	EventBus.show_floating_text.emit("HAZARD!", target_pos, Color.PURPLE)


func _find_hazard_target() -> Vector2:
	# 시설 우선 타겟팅
	var facilities := get_tree().get_nodes_in_group("facilities")
	if not facilities.is_empty():
		var target = facilities[randi() % facilities.size()]
		return target.global_position

	# 시설 없으면 크루 타겟팅
	var crews := get_tree().get_nodes_in_group("crews")
	if not crews.is_empty():
		var alive_crews := crews.filter(func(c): return c.is_alive)
		if not alive_crews.is_empty():
			var target = alive_crews[randi() % alive_crews.size()]
			return target.global_position

	# 랜덤 위치
	return global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))


func _process_hazard_zones(delta: float) -> void:
	var zones_to_remove: Array[int] = []

	for i in range(_active_hazard_zones.size()):
		var hazard: Dictionary = _active_hazard_zones[i]
		hazard["remaining"] -= delta
		hazard["tick_timer"] += delta

		# 시간 만료
		if hazard["remaining"] <= 0:
			zones_to_remove.append(i)
			continue

		# 틱 데미지
		if hazard["tick_timer"] >= hazard["tick_interval"]:
			_apply_hazard_damage(hazard)
			hazard["tick_timer"] = 0.0

	# 만료된 위험 지역 제거 (역순)
	for i in range(zones_to_remove.size() - 1, -1, -1):
		_active_hazard_zones.remove_at(zones_to_remove[i])


func _apply_hazard_damage(hazard: Dictionary) -> void:
	var pos: Vector2 = hazard["position"]
	var radius: float = hazard["radius"]
	var damage: int = hazard["damage_per_tick"]

	# 크루에게 데미지
	var crews := get_tree().get_nodes_in_group("crews")
	for crew in crews:
		if not crew.is_alive:
			continue
		var dist := pos.distance_to(crew.global_position)
		if dist <= radius:
			crew.take_damage(damage, Constants.DamageType.ENERGY, self)

	# 시설에게 데미지
	var facilities := get_tree().get_nodes_in_group("facilities")
	for facility in facilities:
		if facility.has_method("take_damage"):
			var dist := pos.distance_to(facility.global_position)
			if dist <= radius:
				facility.take_damage(damage, Constants.DamageType.ENERGY, self)


func _storm_global_pulse() -> void:
	# 전체 크루에게 약한 데미지
	var crews := get_tree().get_nodes_in_group("crews")
	for crew in crews:
		if crew.is_alive:
			crew.take_damage(STORM_PULSE_DAMAGE, Constants.DamageType.ENERGY, self)

	storm_pulse_fired.emit(STORM_PULSE_DAMAGE)
	special_ability_used.emit("storm_pulse")
	EventBus.screen_flash.emit(Color(0.5, 0.1, 0.8, 0.3), 0.2)


func get_active_hazard_zones() -> Array[Dictionary]:
	return _active_hazard_zones


func is_storm_core() -> bool:
	return enemy_data and enemy_data.id == "storm_core"


# ===== BOSS CHECK =====

func is_boss() -> bool:
	if enemy_data == null:
		return false
	return enemy_data.is_boss or enemy_data.tier == Constants.EnemyTier.BOSS


# ===== LANDING SYSTEM =====

func start_landing() -> void:
	_set_state(Constants.EntityState.MOVING)


func complete_landing() -> void:
	has_landed = true
	_set_state(Constants.EntityState.IDLE)
	landing_completed.emit()
	EventBus.enemy_spawned.emit(self, entry_point)


# ===== DAMAGE OVERRIDE =====

func _calculate_actual_damage(amount: int, damage_type: Constants.DamageType, source: Node) -> int:
	var damage := amount

	# Storm Core는 파괴 불가 - 모든 데미지 무효
	if is_storm_core():
		return 0

	# Shield Trooper / Heavy Trooper frontal defense
	if has_frontal_shield():
		if damage_type == Constants.DamageType.ENERGY:
			damage = int(damage * 0.5)

	# Shield Generator buff - immune to energy
	if is_shielded():
		if damage_type == Constants.DamageType.ENERGY:
			damage = 0

	# Knockback resistance
	if enemy_data and enemy_data.knockback_resistance > 0:
		# Applied in knockback logic, not damage
		pass

	return damage


# ===== DEATH OVERRIDE =====

func _die() -> void:
	# Special death handling
	if enemy_data:
		match enemy_data.ability_id:
			"drone_carrier":
				_on_drone_carrier_died()
			"shield_generator":
				_on_shield_generator_died()

	super._die()


# ===== TARGET MANAGEMENT =====

func set_target(target: Node) -> void:
	if current_target != target:
		current_target = target
		target_changed.emit(target)


func get_target() -> Node:
	return current_target


func clear_target() -> void:
	current_target = null
	target_changed.emit(null)


# ===== BEHAVIOR TREE HELPERS =====

## 유효한 타겟이 있는지 확인
func has_valid_target() -> bool:
	if current_target == null:
		return false
	if not is_instance_valid(current_target):
		return false
	if current_target.has_method("is_alive") and not current_target.is_alive:
		return false
	return true


## 타겟이 공격 범위 내인지 확인
func is_target_in_range() -> bool:
	if not has_valid_target():
		return false
	var attack_range_pixels: float = (enemy_data.attack_range if enemy_data else 1.0) * Constants.TILE_SIZE
	var dist: float = global_position.distance_to(current_target.global_position)
	return dist <= attack_range_pixels


## 공격 실행
func attack(target: Node) -> void:
	if target == null:
		return

	var damage: int = enemy_data.base_damage if enemy_data else 5

	if target.has_method("take_damage"):
		target.take_damage(damage, Constants.DamageType.PHYSICAL, self)

	# 브루트 넉백
	if enemy_data and enemy_data.ability_id == "brute":
		if target.has_method("apply_knockback"):
			var dir: Vector2 = (target.global_position - global_position).normalized()
			target.apply_knockback(dir, get_knockback_force())

	special_ability_used.emit("attack")


# ===== UTILITY =====

func get_display_name() -> String:
	if enemy_data:
		return enemy_data.display_name
	return "Unknown Enemy"


func get_tier() -> int:
	if enemy_data:
		return enemy_data.tier
	return Constants.EnemyTier.TIER_1


func get_wave_cost() -> int:
	if enemy_data:
		return enemy_data.wave_cost
	return 1
