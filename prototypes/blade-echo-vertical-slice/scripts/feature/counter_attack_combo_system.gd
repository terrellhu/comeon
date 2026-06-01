# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0001 (stagger_ended sole emitter), ADR-0003 (reset), counter-attack-combo GDD

class_name CounterAttackComboSystem
extends Node

@export var max_hits: int = 3
@export var hit_animation_duration: float = 0.25
@export var bonus_ratio: float = 0.5
@export var counter_base_damage: float = 20.0
@export var multiplier_1: float = 0.8
@export var multiplier_2: float = 1.1
@export var multiplier_3: float = 1.6
## Base counter window per attack type
@export var base_window_light: float = 1.0
@export var base_window_heavy: float = 1.5
@export var base_window_sweep: float = 2.0

var _combo_state: GameEnums.ComboState = GameEnums.ComboState.IDLE
var _current_attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
var _hit_count: int = 0
var _window_timer: float = 0.0
var _hit_cooldown_timer: float = 0.0
var _hit_cooldown_active: bool = false
var _base_window: float = 0.0

## Injected by arena
var _health_system: HealthDamageSystem

func _ready() -> void:
	EventBus.parry_succeeded.connect(_on_parry_succeeded)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_died.connect(_on_player_died)
	_validate_config()

func _physics_process(delta: float) -> void:
	if _combo_state == GameEnums.ComboState.IDLE:
		return
	if _hit_cooldown_active:
		_hit_cooldown_timer = maxf(_hit_cooldown_timer - delta, 0.0)
		if _hit_cooldown_timer <= 0.0:
			_hit_cooldown_active = false
	_window_timer = maxf(_window_timer - delta, 0.0)
	EventBus.counter_window_updated.emit(_hit_count, _window_timer, _combo_state)
	if _window_timer <= 0.0:
		_on_window_expired()

## Called by PlayerController via 1:1 signal connection
func on_attack_input_pressed() -> void:
	if _combo_state != GameEnums.ComboState.COUNTER_WINDOW_OPEN:
		return
	if _hit_count >= max_hits or _hit_cooldown_active:
		return
	_hit_count += 1
	var dmg := counter_base_damage * _get_multiplier(_hit_count)
	if _health_system:
		_health_system.apply_damage(GameEnums.Target.BOSS, dmg)
		if _hit_count == max_hits:
			HitpauseManager.trigger_hitpause(0.080)
		# 3rd hit bonus hitpause handled above; full combo has its own in _on_full_combo
	_hit_cooldown_active = true
	_hit_cooldown_timer = hit_animation_duration
	if _hit_count >= max_hits:
		_on_full_combo()

func _on_parry_succeeded(attack_type: GameEnums.AttackType) -> void:
	_current_attack_type = attack_type
	_combo_state = GameEnums.ComboState.COUNTER_WINDOW_OPEN
	_hit_count = 0
	_hit_cooldown_active = false
	_hit_cooldown_timer = 0.0
	_base_window = _get_base_window(attack_type)
	_window_timer = _base_window

func _on_full_combo() -> void:
	EventBus.counter_full_combo_completed.emit(_current_attack_type)
	HitpauseManager.trigger_hitpause(0.030)
	var bonus := _base_window * bonus_ratio
	_window_timer = bonus
	_combo_state = GameEnums.ComboState.BONUS_STAGGER

func _on_window_expired() -> void:
	if _combo_state == GameEnums.ComboState.IDLE:
		return
	_combo_state = GameEnums.ComboState.IDLE
	EventBus.stagger_ended.emit()  ## SOLE emitter of stagger_ended — ADR-0001

func _on_boss_defeated() -> void:
	_combo_state = GameEnums.ComboState.IDLE  ## do NOT emit stagger_ended — boss is dead

func _on_player_died() -> void:
	_combo_state = GameEnums.ComboState.IDLE  ## do NOT emit stagger_ended — retry system takes over

func _get_multiplier(n: int) -> float:
	match n:
		1: return multiplier_1
		2: return multiplier_2
		3: return multiplier_3
	return multiplier_1

func _get_base_window(attack_type: GameEnums.AttackType) -> float:
	match attack_type:
		GameEnums.AttackType.LIGHT: return base_window_light
		GameEnums.AttackType.HEAVY: return base_window_heavy
		GameEnums.AttackType.SWEEP: return base_window_sweep
	return base_window_light

func _validate_config() -> void:
	var max_time := 3.0 * hit_animation_duration + 0.08  ## 0.08s input buffer
	if max_time > base_window_light:
		push_warning("CounterAttack: 3xhit_animation_duration exceeds LIGHT window — clamping hit_animation_duration")
		hit_animation_duration = (base_window_light - 0.08) / 3.0
	if bonus_ratio > 0.8:
		push_warning("CounterAttack: bonus_ratio > 0.8 clamped")
		bonus_ratio = 0.8

func reset_for_retry(_ctx: Dictionary) -> void:
	_combo_state = GameEnums.ComboState.IDLE
	_hit_count = 0
	_window_timer = 0.0
	_hit_cooldown_timer = 0.0
	_hit_cooldown_active = false

func set_health_system(hs: HealthDamageSystem) -> void:
	_health_system = hs
