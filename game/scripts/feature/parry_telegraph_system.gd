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
## Depends on: EventBus autoload (injectable for GUT), GameEnums.AttackType,
##             AttackData resource (injectable for GUT — Story 002+).
##
## ADR-0001: all cross-system signals go through EventBus.
## initialize() MUST be called before add_child() so _event_bus is set
## when _ready() fires (same contract as BossStateMachine).

# ─── Constants ────────────────────────────────────────────────────────────────

## Default telegraph durations (seconds) — GDD Formula 1 baseline values.
## Story 002: these feed _get_effective_telegraph_duration(); no literal appears
## in logic code outside this const block (AC-23).
const _DEFAULT_DURATION_LIGHT: float = 0.8
const _DEFAULT_DURATION_HEAVY: float = 1.2
const _DEFAULT_DURATION_SWEEP: float = 1.5

## Default parry window widths (seconds) — GDD Formula 1 baseline values.
const _DEFAULT_WINDOW_WIDTH_LIGHT: float = 0.30
const _DEFAULT_WINDOW_WIDTH_HEAVY: float = 0.35
const _DEFAULT_WINDOW_WIDTH_SWEEP: float = 0.45

## Default window-open fraction — fraction of telegraph_duration at which the
## parry window opens (GDD Formula 1: window_open_time = duration × fraction).
const _DEFAULT_WINDOW_OPEN_FRACTION: float = 0.50

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
## Set from AttackData on TELEGRAPHING entry (Story 002+).
var telegraph_duration: float = 0.0

## Absolute time (from telegraph start) at which the parry window opens (seconds).
## Computed by _compute_window_times() on TELEGRAPHING entry.
var window_open_time: float = 0.0

## Absolute time (from telegraph start) at which the parry window closes (seconds).
## Computed by _compute_window_times() on TELEGRAPHING entry.
var window_close_time: float = 0.0

## Whether the parry input window is currently open.
## Recomputed each _physics_process from timer vs window_open_time/window_close_time.
var window_open: bool = false

## Set to true when a duplicate attack_telegraphed arrives while TELEGRAPHING.
## Used by tests to assert the discard/warn path (AC-16).
var _warned_duplicate: bool = false

# ─── Private state ────────────────────────────────────────────────────────────

var _event_bus: Node = null

## AttackData for the current telegraphed attack.
## Set in _on_attack_telegraphed; consumed by _enter_state(TELEGRAPHING).
## Allows tests to inject custom AttackData via _get_effective_* methods directly.
var _current_attack_data: AttackData = null

# ─── Built-in virtual methods ─────────────────────────────────────────────────

func _ready() -> void:
	assert(_event_bus != null, "ParryTelegraphSystem: call initialize() before add_child()")
	@warning_ignore("unsafe_property_access")
	_event_bus.attack_telegraphed.connect(_on_attack_telegraphed)


func _physics_process(delta: float) -> void:
	if system_state != ParryState.TELEGRAPHING:
		return
	telegraph_timer = minf(telegraph_timer + delta, telegraph_duration)
	window_open = telegraph_timer >= window_open_time and telegraph_timer <= window_close_time
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


## Returns the effective telegraph duration for the given AttackData.
## Uses override when > 0; falls back to type-default const (no literals in call sites).
func _get_effective_telegraph_duration(attack_data: AttackData) -> float:
	if attack_data == null:
		return _get_default_duration(GameEnums.AttackType.LIGHT)
	if attack_data.telegraph_duration_override > 0.0:
		return attack_data.telegraph_duration_override
	return _get_default_duration(attack_data.attack_type)


## Returns the effective parry window width for the given AttackData.
func _get_effective_window_width(attack_data: AttackData) -> float:
	if attack_data == null:
		return _get_default_window_width(GameEnums.AttackType.LIGHT)
	if attack_data.window_width_override > 0.0:
		return attack_data.window_width_override
	return _get_default_window_width(attack_data.attack_type)


## Returns the effective window-open fraction for the given AttackData.
func _get_effective_window_open_fraction(attack_data: AttackData) -> float:
	if attack_data == null:
		return _DEFAULT_WINDOW_OPEN_FRACTION
	if attack_data.window_open_fraction_override > 0.0:
		return attack_data.window_open_fraction_override
	return _DEFAULT_WINDOW_OPEN_FRACTION


## Computes window_open_time and window_close_time from the given AttackData.
## GDD Formula 1:
##   window_open_time  = telegraph_duration × window_open_fraction
##   window_close_time = window_open_time + window_width
## Must be called after telegraph_duration is set (on TELEGRAPHING entry).
func _compute_window_times(attack_data: AttackData) -> void:
	var fraction: float = _get_effective_window_open_fraction(attack_data)
	var width: float = _get_effective_window_width(attack_data)
	window_open_time = telegraph_duration * fraction
	window_close_time = window_open_time + width
	if window_close_time > telegraph_duration:
		push_warning(
			"ParryTelegraphSystem: window_close_time (%f) > telegraph_duration (%f) — clamping (fix AttackData)" \
			% [window_close_time, telegraph_duration]
		)
		window_close_time = telegraph_duration

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
			telegraph_duration = _get_effective_telegraph_duration(_current_attack_data)
			assert(telegraph_duration > 0.0, "ParryTelegraphSystem: telegraph_duration must be > 0 on TELEGRAPHING entry")
			_compute_window_times(_current_attack_data)


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


## Returns the default window width for the given attack type.
func _get_default_window_width(attack_type: GameEnums.AttackType) -> float:
	match attack_type:
		GameEnums.AttackType.HEAVY:
			return _DEFAULT_WINDOW_WIDTH_HEAVY
		GameEnums.AttackType.SWEEP:
			return _DEFAULT_WINDOW_WIDTH_SWEEP
		_:
			return _DEFAULT_WINDOW_WIDTH_LIGHT


## Called when telegraph_timer reaches telegraph_duration with no successful parry.
## Returns system to IDLE. Story 004 will add apply_damage + parry_failed here.
func _handle_telegraph_timeout() -> void:
	_transition_to(ParryState.IDLE)

# ─── Signal callbacks ─────────────────────────────────────────────────────────

## EventBus.attack_telegraphed callback.
## IDLE → TELEGRAPHING: stores attack_type and damage, builds default AttackData,
## resets timer, computes window times.
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
	# Build a minimal AttackData from defaults so _enter_state can use override paths.
	# Story 003+ will inject the real AttackData from BossData.
	var ad: AttackData = AttackData.new()
	ad.attack_type = attack_type
	_current_attack_data = ad
	_transition_to(ParryState.TELEGRAPHING)
