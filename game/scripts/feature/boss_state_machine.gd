class_name BossStateMachine
extends Node

## Boss behaviour state machine for Stories 001–005 (IDLE/TELEGRAPHING/ATTACKING/
## STAGGERED/PHASE_TRANSITION/DEFEATED).
##
## Depends on: BossData resource, EventBus autoload (injectable for GUT),
##             AnimationPlayer reference (@export, nullable for tests).
##
## ADR-0004: all state changes go through _transition_to().
## ADR-0005: ATTACKING→IDLE driven by AnimationPlayer.animation_finished
##           with CONNECT_ONE_SHOT; no await; no separate Timer node.
##           Same pattern used for PHASE_TRANSITION animation.
## ADR-0001: attack_telegraphed emitted via EventBus before telegraph_timer starts.
##           boss_phase_changed received via EventBus subscription.
## ADR-0003: reset_for_retry restores IDLE state for in-place retry without side-effects.

# ─── Constants ────────────────────────────────────────────────────────────────

## Animation name for the boss attack. Referenced by StringName to avoid
## string literals in logic code (ADR-0005 / control-manifest Presentation rules).
const ANIM_ATTACK: StringName = &"attack"

## Minimum valid telegraph duration (seconds). Values below _SUBFRAME_THRESHOLD
## are clamped to this value (Story 005 / AC-22 / ADR-0002 tuning knob).
const MIN_TELEGRAPH_DURATION: float = 0.1

## Sub-frame threshold: durations shorter than one frame at 60 fps.
## Used by _get_effective_telegraph_duration to detect invalid overrides (AC-22).
const _SUBFRAME_THRESHOLD: float = 0.016

# ─── Enums ────────────────────────────────────────────────────────────────────

enum BehaviorState {
	IDLE,
	TELEGRAPHING,
	ATTACKING,
	STAGGERED,         # Story 002
	PHASE_TRANSITION,  # Story 004
	DEFEATED,          # Story 003
}

# ─── Signals ──────────────────────────────────────────────────────────────────
# No direct 1:N signals — all cross-system signals go through EventBus (ADR-0001).

# ─── Export variables ─────────────────────────────────────────────────────────

## AnimationPlayer reference. Nullable — when null a fallback flag drives
## ATTACKING→IDLE so unit tests can run without a real AnimationPlayer in the tree.
## Production scenes must assign a real AnimationPlayer.
@export var _anim_player: AnimationPlayer = null

# ─── Public state ─────────────────────────────────────────────────────────────

## Current behaviour state. Read externally; mutate only via _transition_to().
var behavior_state: BehaviorState = BehaviorState.IDLE

## Index of the current attack within the active phase's attack_sequence.
var sequence_index: int = 0

## Countdown to IDLE expiry (seconds remaining). Decremented in _physics_process.
var idle_timer: float = 0.0

## Countdown to telegraph expiry (seconds remaining). Decremented in _physics_process.
var internal_telegraph_timer: float = 0.0

# ─── Private state ────────────────────────────────────────────────────────────

## Injected EventBus (real or mock). Assigned by initialize().
var _event_bus: Node = null

## Active BossData resource. Assigned by init_battle(). Retained for phase transition
## lookup (TR-BSM-004: boss_phase_changed) and reset_for_retry in Story 005.
var _boss_data: BossData = null

## The PhaseData for the currently active phase.
var _current_phase_data: PhaseData = null

## When _anim_player is null, this flag stands in for animation_finished.
## Set to true in _enter_state(ATTACKING); _physics_process detects it and
## calls _on_attack_animation_done directly.
var _pending_anim_fallback: bool = false

## True when a boss_phase_changed signal arrived while the machine was in
## TELEGRAPHING, ATTACKING, or STAGGERED. The transition is deferred until the
## current action resolves, then goes directly to PHASE_TRANSITION (skip IDLE).
var _pending_phase_transition: bool = false

## The target phase index for the next PHASE_TRANSITION completion.
## Written by _on_boss_phase_changed; read by _complete_phase_transition.
## "Last wins" when multiple boss_phase_changed signals arrive before completion.
var _pending_to_phase: int = 0

# ─── Built-in virtual methods ─────────────────────────────────────────────────

## Subscribes to EventBus signals (Stories 002, 003, 004).
## initialize() MUST be called before add_child() so _event_bus is already set
## when _ready() fires. The test harness (Story 001 pattern) guarantees this order.
func _ready() -> void:
	@warning_ignore("unsafe_property_access")
	_event_bus.parry_succeeded.connect(_on_parry_succeeded)
	@warning_ignore("unsafe_property_access")
	_event_bus.stagger_ended.connect(_on_stagger_ended)
	@warning_ignore("unsafe_property_access")
	_event_bus.parry_failed.connect(_on_parry_failed)
	@warning_ignore("unsafe_property_access")
	_event_bus.boss_defeated.connect(_on_boss_defeated)
	@warning_ignore("unsafe_property_access")
	_event_bus.boss_phase_changed.connect(_on_boss_phase_changed)


func _physics_process(delta: float) -> void:
	match behavior_state:
		BehaviorState.IDLE:
			if idle_timer > 0.0:
				idle_timer = maxf(0.0, idle_timer - delta)
				if idle_timer <= 0.0:
					_transition_to(BehaviorState.TELEGRAPHING)

		BehaviorState.TELEGRAPHING:
			if internal_telegraph_timer > 0.0:
				internal_telegraph_timer = maxf(0.0, internal_telegraph_timer - delta)
				if internal_telegraph_timer <= 0.0:
					_transition_to(BehaviorState.ATTACKING)

		BehaviorState.ATTACKING:
			# When no real AnimationPlayer is wired (test/null case), simulate
			# animation_finished by triggering the handler on the next frame after entry.
			if _pending_anim_fallback:
				_pending_anim_fallback = false
				_on_attack_animation_done(ANIM_ATTACK)

# ─── Public methods ───────────────────────────────────────────────────────────

## Dependency injection for EventBus. Call before init_battle().
## Pass a MockEventBus in GUT tests; omit (or pass null) for production
## to fall back to the global EventBus autoload.
func initialize(event_bus: Node = null) -> void:
	if event_bus != null:
		_event_bus = event_bus
	else:
		_event_bus = EventBus


## Sets up the state machine for a new battle.
## Must be called after initialize(). Resets all runtime state.
## Story 005 / ADR-0002: validates all phases at load time.
##   - Empty attack_sequence: push_error + early return (refuses init; production-safe).
##   - idle_duration_after_attack <= 0.0: clamped to 0.1s + push_warning.
func init_battle(boss_data: BossData) -> void:
	assert(boss_data != null, "BossStateMachine.init_battle: boss_data must not be null")
	assert(
		boss_data.phases.size() > 0,
		"BossStateMachine.init_battle: boss_data must have at least one PhaseData"
	)
	# Validate all phases before mutating any runtime state (AC-20, AC-21).
	for phase_data: PhaseData in boss_data.phases:
		if phase_data.attack_sequence.size() == 0:
			push_error(
				"BossStateMachine.init_battle: phase[%d].attack_sequence is empty — refusing init" \
				% phase_data.phase_index
			)
			return  # Early return: do NOT set behavior_state=IDLE (AC-20).
		if phase_data.idle_duration_after_attack <= 0.0:
			push_warning(
				"BossStateMachine: phase[%d].idle_duration_after_attack=%.3f — clamping to 0.1s (AC-21)" \
				% [phase_data.phase_index, phase_data.idle_duration_after_attack]
			)
			phase_data.idle_duration_after_attack = 0.1
	_boss_data = boss_data
	_current_phase_data = boss_data.phases[0]
	sequence_index = 0
	idle_timer = _current_phase_data.idle_duration_after_attack
	internal_telegraph_timer = 0.0
	_pending_anim_fallback = false
	_pending_phase_transition = false
	_pending_to_phase = 0
	# Directly assign to IDLE — no _transition_to here because there is no
	# previous state to exit. _enter_state(IDLE) would start the idle_timer
	# which is already set above.
	behavior_state = BehaviorState.IDLE


## Resets all runtime state for an in-place retry (ADR-0003).
## Called by InstantRetrySystem in dependency order: HealthDamageSystem →
## PlayerController → BossStateMachine → ParryTelegraphSystem → CounterAttackComboSystem.
## Does NOT call _transition_to() — direct assignment bypasses _enter_state side-effects.
func reset_for_retry(ctx: Dictionary) -> void:
	assert(ctx.has("boss_phase"), "BossStateMachine.reset_for_retry: ctx must contain 'boss_phase'")
	# Disconnect any pending animation callbacks to prevent stale signals after reset.
	if _anim_player != null:
		if _anim_player.animation_finished.is_connected(_on_attack_animation_done):
			_anim_player.animation_finished.disconnect(_on_attack_animation_done)
		if _anim_player.animation_finished.is_connected(_on_phase_transition_done):
			_anim_player.animation_finished.disconnect(_on_phase_transition_done)
	behavior_state = BehaviorState.IDLE
	sequence_index = 0
	idle_timer = 0.0
	internal_telegraph_timer = 0.0
	_pending_anim_fallback = false
	_pending_phase_transition = false
	_pending_to_phase = 0
	var phase_idx: int = ctx.get("boss_phase", 0) as int
	assert(
		phase_idx >= 0 and phase_idx < _boss_data.phases.size(),
		"BossStateMachine.reset_for_retry: ctx['boss_phase'] %d out of range [0, %d)" \
		% [phase_idx, _boss_data.phases.size()]
	)
	_current_phase_data = _boss_data.phases[phase_idx]

# ─── Private methods ──────────────────────────────────────────────────────────

## Central state transition dispatcher. The ONLY place behavior_state is assigned
## outside of init_battle() and reset_for_retry().
func _transition_to(new_state: BehaviorState) -> void:
	_exit_state(behavior_state)
	behavior_state = new_state
	_enter_state(new_state)


## Per-state setup logic called immediately after entering a new state.
func _enter_state(state: BehaviorState) -> void:
	match state:
		BehaviorState.IDLE:
			idle_timer = _current_phase_data.idle_duration_after_attack

		BehaviorState.TELEGRAPHING:
			var current_attack: AttackData = _current_phase_data.attack_sequence[sequence_index]
			# AC-12: signal emitted BEFORE telegraph_timer starts.
			# @warning_ignore is needed because _event_bus is typed Node (duck-typing).
			@warning_ignore("unsafe_property_access")
			_event_bus.attack_telegraphed.emit(current_attack.attack_type, current_attack.damage)
			internal_telegraph_timer = _get_effective_telegraph_duration(current_attack)

		BehaviorState.ATTACKING:
			if _anim_player != null:
				_anim_player.play(ANIM_ATTACK)
				_anim_player.animation_finished.connect(
					_on_attack_animation_done,
					CONNECT_ONE_SHOT
				)
			else:
				# No AnimationPlayer wired — set fallback flag; _physics_process
				# will call _on_attack_animation_done on the next frame.
				_pending_anim_fallback = true

		BehaviorState.STAGGERED:
			# Stagger duration is owned entirely by CounterAttackComboSystem.
			# BossStateMachine only waits for stagger_ended (ADR-0001, Story 002
			# control-manifest: no hardcoded duration literals here).
			pass

		BehaviorState.PHASE_TRANSITION:
			# Retrieve the animation name from the target phase.
			var anim_name: StringName = _boss_data.phases[_pending_to_phase].phase_transition_anim
			# _anim_player may be null in headless tests — check before access (ADR-0005 pattern).
			if _anim_player != null and not anim_name.is_empty() and _anim_player.has_animation(anim_name):
				_anim_player.play(anim_name)
				_anim_player.animation_finished.connect(
					_on_phase_transition_done,
					CONNECT_ONE_SHOT
				)
			else:
				# Warn when an anim name is set but not found; silent skip when empty or no player.
				if not anim_name.is_empty():
					push_warning(
						"BossStateMachine: phase_transition_anim '%s' not found — graceful skip" % anim_name
					)
				# Immediate completion when no animation can play.
				_complete_phase_transition()

		BehaviorState.DEFEATED:
			# Terminal state — zero out both timers so no in-flight timer can
			# re-trigger a transition. Signal cleanup for ATTACKING→DEFEATED is
			# handled by _exit_state(ATTACKING) (ADR-0005). Do NOT re-attempt
			# disconnect here — _anim_player may be null in tests.
			idle_timer = 0.0
			internal_telegraph_timer = 0.0


## Per-state teardown logic called immediately before leaving a state.
func _exit_state(state: BehaviorState) -> void:
	match state:
		BehaviorState.IDLE:
			idle_timer = 0.0

		BehaviorState.TELEGRAPHING:
			internal_telegraph_timer = 0.0

		BehaviorState.ATTACKING:
			# Disconnect if not yet consumed — guards against boss_defeated interruption.
			if _anim_player != null:
				if _anim_player.animation_finished.is_connected(_on_attack_animation_done):
					_anim_player.animation_finished.disconnect(_on_attack_animation_done)
			_pending_anim_fallback = false

		BehaviorState.STAGGERED:
			pass  # No teardown required — stagger_ended callback owns exit logic.

		BehaviorState.PHASE_TRANSITION:
			# Disconnect phase-transition animation callback if not yet consumed.
			# Guards against boss_defeated interrupting mid-transition (ADR-0005 pattern).
			if _anim_player != null:
				if _anim_player.animation_finished.is_connected(_on_phase_transition_done):
					_anim_player.animation_finished.disconnect(_on_phase_transition_done)

		BehaviorState.DEFEATED:
			pass  # Terminal state — no exit condition (ADR-0004 / control-manifest).


## Returns the effective telegraph duration for a given attack.
## If telegraph_duration_override > 0.0: use the override (data-driven, AC-10).
## If override == 0.0: look up T_default from BossData.default_telegraph_durations (AC-11).
## Story 005 / AC-22: durations below _SUBFRAME_THRESHOLD (< 1 frame @ 60fps) are
## clamped to MIN_TELEGRAPH_DURATION and a warning is pushed.
func _get_effective_telegraph_duration(attack: AttackData) -> float:
	var duration: float
	if attack.telegraph_duration_override > 0.0:
		duration = attack.telegraph_duration_override
	else:
		duration = _boss_data.get_default_telegraph_duration(attack.attack_type)
	if duration < _SUBFRAME_THRESHOLD:
		push_warning(
			"BossStateMachine: telegraph_duration for '%s' (%.4fs) < 1 frame — clamping to %.1fs (AC-22)" \
			% [GameEnums.AttackType.keys()[attack.attack_type], duration, MIN_TELEGRAPH_DURATION]
		)
		return MIN_TELEGRAPH_DURATION
	return duration


## Applies the pending phase change: updates PhaseData, resets sequence_index,
## clears the pending flag, then transitions to IDLE.
## Called from _on_phase_transition_done (animation path), directly from
## _enter_state(PHASE_TRANSITION) (no-animation path), and directly by tests
## when _anim_player is null. Keep the contract stable for the headless pattern.
func _complete_phase_transition() -> void:
	# Defensive bounds check — _pending_to_phase originates from a cross-system
	# signal (HealthDamageSystem). BossData load validation is Story 005's job;
	# this guard surfaces a bad to_phase at the source rather than as an opaque
	# Array-out-of-bounds error at access time.
	assert(
		_pending_to_phase >= 0 and _pending_to_phase < _boss_data.phases.size(),
		"BossStateMachine: _pending_to_phase %d out of range [0, %d)" % [
			_pending_to_phase, _boss_data.phases.size()
		]
	)
	_current_phase_data = _boss_data.phases[_pending_to_phase]
	sequence_index = 0
	_pending_phase_transition = false
	_transition_to(BehaviorState.IDLE)

# ─── Signal callbacks ─────────────────────────────────────────────────────────

## AnimationPlayer.animation_finished callback (CONNECT_ONE_SHOT).
## Also called directly from tests (bypassing AnimationPlayer) to verify handler logic.
## AC-04: advance sequence_index, transition to IDLE (or PHASE_TRANSITION if pending).
func _on_attack_animation_done(_anim_name: StringName) -> void:
	# State guard — handles the edge case where disconnect is delayed by one frame
	# after boss_defeated interrupts ATTACKING. (ADR-0005 / control-manifest)
	if behavior_state != BehaviorState.ATTACKING:
		return
	sequence_index = (sequence_index + 1) % _current_phase_data.attack_sequence.size()
	# AC-16: if a phase transition is pending, skip IDLE and go directly to PHASE_TRANSITION.
	if _pending_phase_transition:
		_pending_phase_transition = false
		_transition_to(BehaviorState.PHASE_TRANSITION)
	else:
		_transition_to(BehaviorState.IDLE)


## AnimationPlayer.animation_finished callback for the phase-transition animation
## (CONNECT_ONE_SHOT). Delegates to _complete_phase_transition().
func _on_phase_transition_done(_anim_name: StringName) -> void:
	# State guard (ADR-0005) — consistent with _on_attack_animation_done; handles
	# the edge case where disconnect is delayed after a boss_defeated interruption.
	if behavior_state != BehaviorState.PHASE_TRANSITION:
		return
	_complete_phase_transition()


## EventBus.parry_succeeded callback — Story 002 / AC-02.
## Transitions TELEGRAPHING → STAGGERED. Ignored in all other states because
## parry_succeeded received outside TELEGRAPHING has no defined BSM effect.
func _on_parry_succeeded(_attack_type: GameEnums.AttackType) -> void:
	if behavior_state != BehaviorState.TELEGRAPHING:
		return
	_transition_to(BehaviorState.STAGGERED)


## EventBus.stagger_ended callback — Story 002 / AC-05, AC-08.
## Advances sequence_index and transitions STAGGERED → IDLE
## (or PHASE_TRANSITION if pending — AC-17).
## Stagger duration is fully owned by CounterAttackComboSystem — BSM only reacts.
func _on_stagger_ended() -> void:
	if behavior_state != BehaviorState.STAGGERED:
		return
	sequence_index = (sequence_index + 1) % _current_phase_data.attack_sequence.size()
	# AC-17: if a phase transition is pending, skip IDLE and go directly to PHASE_TRANSITION.
	if _pending_phase_transition:
		_pending_phase_transition = false
		_transition_to(BehaviorState.PHASE_TRANSITION)
	else:
		_transition_to(BehaviorState.IDLE)


## EventBus.parry_failed callback — Story 002 / AC-13.
## Informational only — BossStateMachine does not change state on parry failure.
func _on_parry_failed(_attack_type: GameEnums.AttackType) -> void:
	pass


## EventBus.boss_defeated callback — Story 003 / AC-06.
## Transitions immediately to DEFEATED from ANY state. Terminal — no exit.
## HealthDamageSystem is the sole emitter of boss_defeated (ADR-0001).
func _on_boss_defeated() -> void:
	_transition_to(BehaviorState.DEFEATED)


## EventBus.boss_phase_changed callback — Story 004 / AC-14–AC-18.
## Behaviour depends on current state:
##   IDLE           → immediate PHASE_TRANSITION (AC-14)
##   TELEGRAPHING / ATTACKING / STAGGERED → pend; deferred skip-idle (AC-15/16/17)
##   PHASE_TRANSITION → discard second signal, update _pending_to_phase (AC-18)
##   DEFEATED       → silently ignored
func _on_boss_phase_changed(_from_phase: int, to_phase: int) -> void:
	if behavior_state == BehaviorState.DEFEATED:
		return

	if behavior_state == BehaviorState.PHASE_TRANSITION:
		# AC-18: discard second signal — let current animation finish,
		# but update target so the latest phase wins.
		push_warning(
			"BossStateMachine: boss_phase_changed received during PHASE_TRANSITION — discarding, will use latest to_phase=%d" % to_phase
		)
		_pending_to_phase = to_phase
		return

	if behavior_state == BehaviorState.IDLE:
		# AC-14: immediate transition — no pending flag needed.
		_pending_to_phase = to_phase
		_transition_to(BehaviorState.PHASE_TRANSITION)
	else:
		# TELEGRAPHING, ATTACKING, STAGGERED: defer until current action completes.
		# AC-15, AC-16, AC-17.
		_pending_phase_transition = true
		_pending_to_phase = to_phase
