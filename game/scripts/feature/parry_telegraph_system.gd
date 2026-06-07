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
##             AttackData resource (injectable for GUT — Story 002+),
##             HealthDamageSystem (injectable for GUT — Story 004+).
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

## Duration of the parry animation (seconds) — GDD Tuning Knob baseline.
## Emitted with exit_parry_state(duration) on every parry input (TR-PTS-008).
const _DEFAULT_PARRY_ANIMATION_DURATION: float = 0.4

# ─── Enums ────────────────────────────────────────────────────────────────────

enum ParryState {
	IDLE,
	TELEGRAPHING,
}

# ─── Signals ─────────────────────────────────────────────────────────────────

## 1:1 direct signal to PlayerController (ADR-0001 exception — not on EventBus).
## Emitted every time parry_input_pressed is received, regardless of state (AC-07).
## GameRoot connects: _pts.exit_parry_state.connect(_player_controller._on_exit_parry_state)
signal exit_parry_state(duration: float)

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

## HealthDamageSystem reference. Typed as Node to allow MockHealthDamageSystem injection
## in GUT tests (same pattern as _event_bus). Production assigns the real node.
## Set before add_child() (same contract as _event_bus).
var _health_damage_system: Node = null

## AttackData for the current telegraphed attack.
## Set in _on_attack_telegraphed; consumed by _enter_state(TELEGRAPHING).
## Allows tests to inject custom AttackData via _get_effective_* methods directly.
var _current_attack_data: AttackData = null

# ─── Built-in virtual methods ─────────────────────────────────────────────────

func _ready() -> void:
	assert(_event_bus != null, "ParryTelegraphSystem: call initialize() before add_child()")
	@warning_ignore("unsafe_property_access")
	_event_bus.attack_telegraphed.connect(_on_attack_telegraphed)
	@warning_ignore("unsafe_property_access")
	_event_bus.player_died.connect(_on_player_died)
	@warning_ignore("unsafe_property_access")
	_event_bus.boss_defeated.connect(_on_boss_defeated)


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

## Dependency injection for EventBus and HealthDamageSystem. Call before add_child().
## Pass MockEventBus / MockHealthDamageSystem in GUT tests; omit for production
## to fall back to global EventBus autoload.
## [param health_damage_system] — must not be null in production; null is tolerated
## in unit tests that do not exercise apply_damage paths (Stories 001–003).
func initialize(event_bus: Node = null, health_damage_system: Node = null) -> void:
	if event_bus != null:
		_event_bus = event_bus
	else:
		_event_bus = EventBus
	_health_damage_system = health_damage_system


## ADR-0003 reset contract: restores clean IDLE state for the retry loop.
## Cancels any in-progress telegraph without applying damage or emitting parry_failed.
## [param ctx] — RetryContext dictionary (ignored by PTS; accepted for uniform contract).
## Called by InstantRetrySystem before scene re-entry (AC-reset).
func reset_for_retry(_ctx: Dictionary) -> void:
	if system_state == ParryState.TELEGRAPHING:
		# _exit_state clears telegraph_timer and window_open without side effects.
		_exit_state(ParryState.TELEGRAPHING)
	system_state = ParryState.IDLE
	current_attack_type = GameEnums.AttackType.LIGHT
	current_damage = 0.0
	_current_attack_data = null
	_warned_duplicate = false


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
## GDD Core Rules 5/9 (attack landing):
##   1. apply_damage(PLAYER, current_damage) on HealthDamageSystem (AC-11, AC-19)
##   2. EventBus.parry_failed(current_attack_type) emitted (AC-11)
##   3. Transition to IDLE (AC-24)
## Order: apply_damage → parry_failed → _transition_to(IDLE) so subscribers
## see the damage and failure signal while PTS is still TELEGRAPHING, then
## receive the IDLE transition atomically. Matches Path A order (AC-08 analogy).
func _handle_telegraph_timeout() -> void:
	assert(_health_damage_system != null,
		"ParryTelegraphSystem: _handle_telegraph_timeout called but _health_damage_system is null — call initialize(event_bus, health_damage_system) before add_child()")
	@warning_ignore("unsafe_method_access")
	_health_damage_system.apply_damage(GameEnums.Target.PLAYER, current_damage)
	@warning_ignore("unsafe_property_access")
	_event_bus.parry_failed.emit(current_attack_type)
	_transition_to(ParryState.IDLE)

# ─── Signal callbacks ─────────────────────────────────────────────────────────

## Called when PlayerController emits parry_input_pressed (1:1 direct signal).
## Routes to one of three paths (GDD Core Rules 5–10):
##   Path A — TELEGRAPHING + window open : parry_succeeded → IDLE → exit_parry_state
##   Path B — TELEGRAPHING + window closed: exit_parry_state only (Story 004)
##   Path C — IDLE                       : exit_parry_state only (Story 004)
##
## Story 003 implements Path A. Paths B/C call exit_parry_state as a stub.
## exit_parry_state ALWAYS emitted last (AC-07 / TR-PTS-008).
func _on_parry_input_pressed() -> void:
	# Path A — GDD Formula 3: success = TELEGRAPHING AND timer in closed interval.
	# Raw timer check (not window_open bool): input may arrive before _physics_process
	# updates window_open this frame, so the bool could be stale.
	if system_state == ParryState.TELEGRAPHING \
			and telegraph_timer >= window_open_time \
			and telegraph_timer <= window_close_time:
		# parry_succeeded first (AC-08), then transition so PTS is IDLE when
		# PlayerController receives exit_parry_state.
		@warning_ignore("unsafe_property_access")
		_event_bus.parry_succeeded.emit(current_attack_type)
		_transition_to(ParryState.IDLE)
		exit_parry_state.emit(_DEFAULT_PARRY_ANIMATION_DURATION)
		return
	# Paths B and C — no parry_failed / apply_damage on early/late/empty press
	# (GDD Core Rules 9/10). Telegraph continues; attack will land on timeout
	# (via _handle_telegraph_timeout → apply_damage → parry_failed).
	exit_parry_state.emit(_DEFAULT_PARRY_ANIMATION_DURATION)


## EventBus.player_died callback (AC-17).
## Immediately cancels any in-progress telegraph without applying damage or emitting
## parry_failed — the player is already dead; no further damage processing needed.
func _on_player_died() -> void:
	if system_state == ParryState.TELEGRAPHING:
		_exit_state(ParryState.TELEGRAPHING)
		system_state = ParryState.IDLE


## EventBus.boss_defeated callback (AC-18).
## Immediately cancels any in-progress telegraph without applying damage — the
## fight is over; the final hit has already been processed by BossStateMachine.
func _on_boss_defeated() -> void:
	if system_state == ParryState.TELEGRAPHING:
		_exit_state(ParryState.TELEGRAPHING)
		system_state = ParryState.IDLE


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
