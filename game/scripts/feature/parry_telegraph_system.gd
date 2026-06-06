class_name ParryTelegraphSystem
extends Node

## Parry telegraph system — manages the boss attack telegraph window.
##
## Tracks whether an incoming attack is being telegraphed (TELEGRAPHING) or
## the system is idle (IDLE). Receives attack_telegraphed from EventBus and
## drives the per-frame telegraph_updated stream.
##
## Stories: 001 (skeleton), 002 (window timing), 003 (parry success),
##          004 (parry failure / apply_damage), 005 (retry/reset).
##
## Depends on: EventBus autoload (injectable for GUT), GameEnums.AttackType.
##
## ADR-0001: all cross-system signals go through EventBus.
## initialize() MUST be called before add_child() so _event_bus is set
## when _ready() fires (same contract as BossStateMachine).

# ─── Constants ────────────────────────────────────────────────────────────────

## Default telegraph duration for LIGHT attacks (seconds).
## Story 002 will replace these with a data-driven AttackData lookup.
const _DEFAULT_DURATION_LIGHT: float = 0.8

## Default telegraph duration for HEAVY attacks (seconds).
const _DEFAULT_DURATION_HEAVY: float = 1.2

## Default telegraph duration for SWEEP attacks (seconds).
const _DEFAULT_DURATION_SWEEP: float = 1.5

# ─── Enums ────────────────────────────────────────────────────────────────────

enum ParryState {
	IDLE,
	TELEGRAPHING,
}

# ─── Public state ─────────────────────────────────────────────────────────────

## Current parry state. Read externally; mutate only via _transition_to().
var system_state: ParryState = ParryState.IDLE

## Attack type currently being telegraphed. Valid only in TELEGRAPHING state.
var current_attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT

## Damage value for the current telegraphed attack.
var current_damage: float = 0.0

## Time elapsed since the current telegraph started (seconds).
## Reset to 0.0 on TELEGRAPHING entry; advanced by delta each _physics_process.
var telegraph_timer: float = 0.0

## Duration of the current telegraph window (seconds).
## Set from the _DEFAULT_DURATION_* consts on TELEGRAPHING entry.
## Story 002 will replace this with an AttackData lookup.
var telegraph_duration: float = 0.0

## Whether the parry input window is currently open.
## Story 002 will compute open/close timing; skeleton always false.
var window_open: bool = false

## Set to true when a duplicate attack_telegraphed arrives while TELEGRAPHING.
## Used by tests to assert the discard/warn path (AC-16).
var _warned_duplicate: bool = false

# ─── Private state ────────────────────────────────────────────────────────────

var _event_bus: Node = null

# ─── Built-in virtual methods ─────────────────────────────────────────────────

func _ready() -> void:
	@warning_ignore("unsafe_property_access")
	_event_bus.attack_telegraphed.connect(_on_attack_telegraphed)


func _physics_process(delta: float) -> void:
	if system_state != ParryState.TELEGRAPHING:
		return
	telegraph_timer = minf(telegraph_timer + delta, telegraph_duration)
	@warning_ignore("unsafe_property_access")
	_event_bus.telegraph_updated.emit(
		telegraph_timer / telegraph_duration,
		window_open,
		current_attack_type
	)
	if telegraph_timer >= telegraph_duration:
		_handle_telegraph_timeout()

# ─── Public methods ───────────────────────────────────────────────────────────

## Dependency injection for EventBus. Call before add_child().
## Pass a MockEventBus in GUT tests; omit (or pass null) for production
## to fall back to the global EventBus autoload.
func initialize(event_bus: Node = null) -> void:
	if event_bus != null:
		_event_bus = event_bus
	else:
		_event_bus = EventBus

# ─── Private methods ──────────────────────────────────────────────────────────

func _transition_to(new_state: ParryState) -> void:
	_exit_state(system_state)
	system_state = new_state
	_enter_state(new_state)


func _enter_state(state: ParryState) -> void:
	match state:
		ParryState.IDLE:
			pass

		ParryState.TELEGRAPHING:
			telegraph_timer = 0.0
			window_open = false
			telegraph_duration = _get_default_duration(current_attack_type)


func _exit_state(state: ParryState) -> void:
	match state:
		ParryState.IDLE:
			pass

		ParryState.TELEGRAPHING:
			telegraph_timer = 0.0
			window_open = false


## Returns the default telegraph duration for the given attack type.
## Uses named consts — no literals in logic code (ADR-0002).
func _get_default_duration(attack_type: GameEnums.AttackType) -> float:
	match attack_type:
		GameEnums.AttackType.HEAVY:
			return _DEFAULT_DURATION_HEAVY
		GameEnums.AttackType.SWEEP:
			return _DEFAULT_DURATION_SWEEP
		_:
			return _DEFAULT_DURATION_LIGHT


## Called when telegraph_timer reaches telegraph_duration with no successful parry.
## Returns system to IDLE. Story 004 will add apply_damage + parry_failed here.
func _handle_telegraph_timeout() -> void:
	_transition_to(ParryState.IDLE)

# ─── Signal callbacks ─────────────────────────────────────────────────────────

## EventBus.attack_telegraphed callback.
## IDLE → TELEGRAPHING: stores attack_type and damage, resets timer.
## Already TELEGRAPHING: warns and discards (sets _warned_duplicate for tests).
func _on_attack_telegraphed(attack_type: GameEnums.AttackType, damage: float) -> void:
	if system_state == ParryState.TELEGRAPHING:
		push_warning(
			"ParryTelegraphSystem: attack_telegraphed received while already TELEGRAPHING — discarding (attack_type=%s)" \
			% GameEnums.AttackType.keys()[attack_type]
		)
		_warned_duplicate = true
		return
	current_attack_type = attack_type
	current_damage = damage
	_transition_to(ParryState.TELEGRAPHING)
