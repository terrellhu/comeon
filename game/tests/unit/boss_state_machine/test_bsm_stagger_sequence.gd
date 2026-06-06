extends GutTest

## BossStateMachine Story 002 — STAGGERED state + sequence index formula.
##
## ACs covered by this file:
##   AC-02  parry_succeeded (TELEGRAPHING) → STAGGERED; telegraph cancelled
##   AC-05  stagger_ended (STAGGERED) → sequence_index++ → IDLE
##   AC-07  sequence wrap-around via ATTACKING exit (N=3, index=2)
##   AC-08  sequence wrap-around via STAGGERED exit (N=3, index=2)
##   AC-13  parry_failed during ATTACKING: state unchanged
##
## Pre-condition test (tech-debt from Story 001 code review):
##   _pending_anim_fallback must be cleared in _exit_state(ATTACKING)
##
## GUT headless rules:
##   - Access enums/consts via _BSM_SCRIPT.X — never via the BossStateMachine global.
##   - initialize(mock) BEFORE add_child so _ready() finds a non-null _event_bus.
##   - Drive timers with real deltas (_EXPIRE_DELTA) — never pre-zero a timer.

# ─── Fixtures ─────────────────────────────────────────────────────────────────

var _bsm: Node
var _mock_bus: MockEventBus

const _BSM_SCRIPT: GDScript = preload("res://scripts/feature/boss_state_machine.gd")
const _MOCK_BUS_SCRIPT: GDScript = preload("res://tests/helpers/mock_event_bus.gd")

## Phase idle delay used by all test bosses.
const _IDLE_DURATION: float = 0.5

## A delta large enough to expire any single timer in one _physics_process call.
const _EXPIRE_DELTA: float = 5.0


## Build a BossData with N attacks in sequence (all LIGHT, telegraph override 0.8).
## telegraph_duration_override > 0 so the Story 003 fallback is never triggered.
func _make_sequence_boss(n: int) -> BossData:
	assert(n >= 1, "_make_sequence_boss: n must be >= 1")
	var sequence: Array[AttackData] = []
	for i: int in range(n):
		var atk: AttackData = AttackData.new()
		atk.attack_type = GameEnums.AttackType.LIGHT
		atk.damage = 10.0
		atk.telegraph_duration_override = 0.8
		sequence.append(atk)

	var phase: PhaseData = PhaseData.new()
	phase.phase_index = 0
	phase.idle_duration_after_attack = _IDLE_DURATION
	phase.attack_sequence = sequence

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_stagger"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = []
	boss.phases = [phase]
	return boss


func before_each() -> void:
	_mock_bus = _MOCK_BUS_SCRIPT.new()
	add_child_autofree(_mock_bus)

	_bsm = _BSM_SCRIPT.new()
	# initialize() BEFORE add_child so _ready() finds _event_bus already set and
	# subscribes to parry_succeeded / stagger_ended / parry_failed on _mock_bus.
	_bsm.initialize(_mock_bus)
	add_child_autofree(_bsm)


# ─── Navigation helpers ───────────────────────────────────────────────────────

## Expire idle_timer → IDLE transitions to TELEGRAPHING.
func _expire_idle() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


## Expire telegraph timer → TELEGRAPHING transitions to ATTACKING.
func _expire_telegraph() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


## Navigate from a freshly init'd BSM into TELEGRAPHING.
func _reach_telegraphing(boss: BossData) -> void:
	_bsm.init_battle(boss)
	_expire_idle()


## Navigate from a freshly init'd BSM into ATTACKING.
func _reach_attacking(boss: BossData) -> void:
	_reach_telegraphing(boss)
	_expire_telegraph()


## Set sequence_index directly via the public field (bypasses _transition_to).
## Used to position the state machine at a specific index before exercising
## wrap-around tests without cycling through N-1 full attack loops.
func _set_sequence_index(idx: int) -> void:
	_bsm.sequence_index = idx


# ─── Pre-condition: _pending_anim_fallback cleared on ATTACKING exit ──────────
# Tech-debt item from Story 001 code review — must pass before Story 002 is valid.

func test_exit_attacking_clears_pending_anim_fallback() -> void:
	# Arrange: navigate to ATTACKING without an AnimationPlayer so the fallback
	# flag is set on _enter_state(ATTACKING).
	_bsm.init_battle(_make_sequence_boss(1))
	_expire_idle()
	_expire_telegraph()
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"precondition: must be in ATTACKING"
	)
	# Precondition: flag must be true — _enter_state(ATTACKING) sets it when
	# _anim_player is null. If this fails, _enter_state(ATTACKING) is broken.
	assert_true(
		_bsm._pending_anim_fallback,
		"precondition: _pending_anim_fallback must be set on ATTACKING entry (no AnimationPlayer)"
	)
	# Act: call animation_done directly to exit ATTACKING (calls _exit_state).
	_bsm._on_attack_animation_done(_BSM_SCRIPT.ANIM_ATTACK)
	# Assert: flag must be cleared after exiting ATTACKING.
	assert_false(
		_bsm._pending_anim_fallback,
		"_pending_anim_fallback must be false after _exit_state(ATTACKING)"
	)


# ─── AC-02: parry_succeeded → STAGGERED; telegraph cancelled ─────────────────

func test_parry_succeeded_in_telegraphing_transitions_to_staggered() -> void:
	# Arrange
	_reach_telegraphing(_make_sequence_boss(1))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING)
	_mock_bus.attack_telegraphed_call_count = 0
	# Act
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	# Assert: state and AC-02 "no further attack_telegraphed" contract
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.STAGGERED,
		"AC-02: parry_succeeded in TELEGRAPHING must transition to STAGGERED"
	)
	assert_eq(
		_mock_bus.attack_telegraphed_call_count,
		0,
		"AC-02: attack_telegraphed must not fire after entering STAGGERED"
	)


func test_parry_succeeded_in_telegraphing_cancels_telegraph_timer() -> void:
	# Arrange
	_reach_telegraphing(_make_sequence_boss(1))
	assert_gt(_bsm.internal_telegraph_timer, 0.0, "precondition: timer must be running")
	# Act
	_bsm._on_parry_succeeded(GameEnums.AttackType.HEAVY)
	# Assert: _exit_state(TELEGRAPHING) zeros the timer.
	assert_almost_eq(
		_bsm.internal_telegraph_timer,
		0.0,
		0.001,
		"AC-02: internal_telegraph_timer must be 0 after parry cancels telegraph"
	)


func test_parry_succeeded_outside_telegraphing_is_ignored() -> void:
	# Arrange: BSM is in IDLE (not TELEGRAPHING).
	_bsm.init_battle(_make_sequence_boss(1))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	# Assert: state unchanged — parry_succeeded is only meaningful in TELEGRAPHING.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"AC-02 edge: parry_succeeded outside TELEGRAPHING must not change state"
	)


# ─── AC-05: stagger_ended → sequence_index++ → IDLE ─────────────────────────

func test_stagger_ended_advances_sequence_index_and_enters_idle() -> void:
	# Arrange: N=3, start at index 1.
	_reach_telegraphing(_make_sequence_boss(3))
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	_set_sequence_index(1)
	# Act
	_bsm._on_stagger_ended()
	# Assert
	assert_eq(
		_bsm.sequence_index,
		2,
		"AC-05: sequence_index must advance from 1 to 2 after stagger_ended"
	)
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"AC-05: behavior_state must be IDLE after stagger_ended"
	)
	assert_gt(
		_bsm.idle_timer,
		0.0,
		"AC-05: idle_timer must be primed after stagger_ended → IDLE"
	)


func test_stagger_ended_outside_staggered_is_ignored() -> void:
	# Arrange: BSM is in IDLE.
	_bsm.init_battle(_make_sequence_boss(1))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	var idx_before: int = _bsm.sequence_index
	# Act
	_bsm._on_stagger_ended()
	# Assert: state guard prevents any change.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"stagger_ended state guard: must remain IDLE"
	)
	assert_eq(
		_bsm.sequence_index,
		idx_before,
		"stagger_ended state guard: sequence_index must not change"
	)


# ─── AC-07: sequence wrap-around via ATTACKING exit (N=3, index=2) ───────────

func test_attacking_exit_wraps_sequence_index_at_end() -> void:
	# Arrange: N=3, position at index 2 (last), ATTACKING.
	_reach_attacking(_make_sequence_boss(3))
	_set_sequence_index(2)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING)
	# Act
	_bsm._on_attack_animation_done(_BSM_SCRIPT.ANIM_ATTACK)
	# Assert: (2+1) mod 3 = 0.
	assert_eq(
		_bsm.sequence_index,
		0,
		"AC-07: sequence_index must wrap to 0 after last attack in sequence (N=3, idx=2)"
	)


# ─── AC-08: sequence wrap-around via STAGGERED exit (N=3, index=2) ───────────

func test_stagger_ended_wraps_sequence_index_at_end() -> void:
	# Arrange: N=3, enter STAGGERED, position at index 2 (last).
	_reach_telegraphing(_make_sequence_boss(3))
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	_set_sequence_index(2)
	# Act
	_bsm._on_stagger_ended()
	# Assert: (2+1) mod 3 = 0.
	assert_eq(
		_bsm.sequence_index,
		0,
		"AC-08: sequence_index must wrap to 0 after stagger_ended at last index (N=3, idx=2)"
	)


# ─── AC-13: parry_failed during ATTACKING: state unchanged ───────────────────

func test_parry_failed_during_attacking_does_not_change_state() -> void:
	# Arrange
	_reach_attacking(_make_sequence_boss(1))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING)
	var idx_before: int = _bsm.sequence_index
	# Act
	_bsm._on_parry_failed(GameEnums.AttackType.LIGHT)
	# Assert: AC-13 — state and index completely unchanged.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"AC-13: parry_failed must not change state during ATTACKING"
	)
	assert_eq(
		_bsm.sequence_index,
		idx_before,
		"AC-13: parry_failed must not change sequence_index during ATTACKING"
	)


# ─── EventBus wiring: _ready() subscription path ─────────────────────────────
# These tests verify that _ready() correctly wires EventBus signals to handlers.
# Direct handler invocations above test logic; these test the wiring.

func test_parry_succeeded_signal_routes_through_eventbus_to_staggered() -> void:
	# Arrange: BSM in TELEGRAPHING, emit parry_succeeded through mock EventBus.
	_reach_telegraphing(_make_sequence_boss(1))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING)
	# Act: emit via EventBus (exercises _ready() subscription wiring)
	_mock_bus.parry_succeeded.emit(GameEnums.AttackType.LIGHT)
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.STAGGERED,
		"_ready() must wire EventBus.parry_succeeded → _on_parry_succeeded"
	)


func test_stagger_ended_signal_routes_through_eventbus_to_idle() -> void:
	# Arrange: BSM in STAGGERED, emit stagger_ended through mock EventBus.
	_reach_telegraphing(_make_sequence_boss(1))
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	# Act: emit via EventBus
	_mock_bus.stagger_ended.emit()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"_ready() must wire EventBus.stagger_ended → _on_stagger_ended"
	)
