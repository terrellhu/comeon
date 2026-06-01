# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0001 (signal routing), ADR-0003 (reset), parry-telegraph-system GDD

class_name ParryTelegraphSystem
extends Node

# Default timing values (all @export — no literals in logic)
@export var telegraph_duration_light: float = 0.8
@export var telegraph_duration_heavy: float = 1.2
@export var telegraph_duration_sweep: float = 1.5
@export var window_open_fraction: float = 0.50
@export var window_width_light: float = 0.30
@export var window_width_heavy: float = 0.35
@export var window_width_sweep: float = 0.45
@export var stagger_duration_light: float = 1.0
@export var stagger_duration_heavy: float = 1.5
@export var stagger_duration_sweep: float = 2.0
@export var parry_animation_duration: float = 0.40

enum _State { IDLE, TELEGRAPHING }

var _system_state: _State = _State.IDLE
var _telegraph_timer: float = 0.0
var _current_attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
var _current_damage: float = 0.0
var _current_telegraph_duration: float = 0.0
var _window_open_time: float = 0.0
var _window_close_time: float = 0.0

func _ready() -> void:
	EventBus.attack_telegraphed.connect(_on_attack_telegraphed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)

func _physics_process(delta: float) -> void:
	if _system_state != _State.TELEGRAPHING:
		return
	_telegraph_timer = minf(_telegraph_timer + delta, _current_telegraph_duration)
	var progress := _telegraph_timer / _current_telegraph_duration
	var window_open := _telegraph_timer >= _window_open_time and _telegraph_timer <= _window_close_time
	EventBus.telegraph_updated.emit(progress, window_open, _current_attack_type)
	if _telegraph_timer >= _current_telegraph_duration:
		_on_telegraph_expired()

## Called by PlayerController via direct 1:1 signal connection
func on_parry_input_pressed() -> void:
	EventBus.exit_parry_state.emit(parry_animation_duration)
	if _system_state == _State.IDLE:
		return  ## Path C: empty parry
	var success := (_telegraph_timer >= _window_open_time and _telegraph_timer <= _window_close_time)
	if success:
		_on_parry_success()
	# else: Path B — miss. Keep telegraphing; parry_failed only fires when attack lands.

func _on_attack_telegraphed(attack_type: GameEnums.AttackType, damage: float) -> void:
	if _system_state == _State.TELEGRAPHING:
		push_warning("ParryTelegraphSystem: second attack_telegraphed rejected (still telegraphing)")
		return
	_current_attack_type = attack_type
	_current_damage = damage
	_current_telegraph_duration = _get_telegraph_duration(attack_type)
	_window_open_time = _current_telegraph_duration * window_open_fraction
	_window_close_time = _window_open_time + _get_window_width(attack_type)
	assert(_window_close_time <= _current_telegraph_duration,
		"window_close_time exceeds telegraph_duration — check window_width tuning")
	_telegraph_timer = 0.0
	_system_state = _State.TELEGRAPHING

func _on_parry_success() -> void:
	_system_state = _State.IDLE
	_telegraph_timer = 0.0
	HitpauseManager.trigger_hitpause(0.060)
	EventBus.parry_succeeded.emit(_current_attack_type)

func _on_telegraph_expired() -> void:
	if _system_state != _State.TELEGRAPHING:
		return
	_system_state = _State.IDLE
	EventBus.parry_failed.emit(_current_attack_type)
	# Forward damage to HealthDamageSystem via reference set by arena
	if _health_system:
		_health_system.apply_damage(GameEnums.Target.PLAYER, _current_damage)

func _on_player_died() -> void:
	_system_state = _State.IDLE
	_telegraph_timer = 0.0

func _on_boss_defeated() -> void:
	_system_state = _State.IDLE
	_telegraph_timer = 0.0

func _get_telegraph_duration(attack_type: GameEnums.AttackType) -> float:
	match attack_type:
		GameEnums.AttackType.LIGHT: return telegraph_duration_light
		GameEnums.AttackType.HEAVY: return telegraph_duration_heavy
		GameEnums.AttackType.SWEEP: return telegraph_duration_sweep
	return telegraph_duration_light

func _get_window_width(attack_type: GameEnums.AttackType) -> float:
	match attack_type:
		GameEnums.AttackType.LIGHT: return window_width_light
		GameEnums.AttackType.HEAVY: return window_width_heavy
		GameEnums.AttackType.SWEEP: return window_width_sweep
	return window_width_light

## ADR-0003 reset contract
func reset_for_retry(_ctx: Dictionary) -> void:
	_system_state = _State.IDLE
	_telegraph_timer = 0.0

## Injected by arena bootstrap (avoids circular dependency on Autoload)
var _health_system: HealthDamageSystem

func set_health_system(hs: HealthDamageSystem) -> void:
	_health_system = hs
