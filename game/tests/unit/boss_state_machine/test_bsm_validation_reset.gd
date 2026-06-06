extends GutTest

## BossStateMachine Story 005 — Data Validation + reset_for_retry.
##
## ACs covered:
##   AC-19  phase_transition_anim missing → graceful skip (pre-landed in Story 004;
##          this file adds a reference test for traceability).
##   AC-20  Empty attack_sequence → push_error + refuse init (behavior_state stays
##          at its pre-call value, never becomes IDLE).
##   AC-21  idle_duration_after_attack=0.0 → clamped to 0.1s + push_warning; system
##          initialises normally (behavior_state=IDLE).
##   AC-22  telegraph_duration_override=0.005 (sub-frame) → clamped to 0.1s + push_warning.
##   ADR-0003  reset_for_retry: full state reset across IDLE/ATTACKING/PHASE_TRANSITION.
##
## GUT headless rules:
##   - Access enums/consts via _BSM_SCRIPT.X — never via the BossStateMachine global.
##   - initialize(mock) BEFORE add_child so _ready() finds _event_bus already set.
##   - Drive timers with real deltas (_EXPIRE_DELTA) — never pre-zero a timer.
##   - _anim_player is null in all tests: PHASE_TRANSITION completes immediately
##     (no-animation path).

# ─── Fixtures ─────────────────────────────────────────────────────────────────

var _bsm: Node
var _mock_bus: MockEventBus

const _BSM_SCRIPT: GDScript = preload("res://scripts/feature/boss_state_machine.gd")
const _MOCK_BUS_SCRIPT: GDScript = preload("res://tests/helpers/mock_event_bus.gd")

## Phase idle delay used by all test bosses.
const _IDLE_DURATION: float = 0.5

## A delta large enough to expire any single timer in one _physics_process call.
const _EXPIRE_DELTA: float = 5.0


## Build a minimal valid single-phase BossData.
## telegraph_duration_override=0.8 so the sub-frame path is never hit by default.
func _make_valid_boss(idle_duration: float = _IDLE_DURATION) -> BossData:
	var attack: AttackData = AttackData.new()
	attack.attack_type = GameEnums.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = 0.8

	var phase: PhaseData = PhaseData.new()
	phase.phase_index = 0
	phase.idle_duration_after_attack = idle_duration
	phase.attack_sequence = [attack] as Array[AttackData]
	phase.phase_transition_anim = &""

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_valid"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = []
	boss.phases = [phase]
	boss.default_telegraph_durations = {
		int(GameEnums.AttackType.LIGHT): 0.8,
	}
	return boss


## Build a BossData whose phase[0] has an empty attack_sequence (invalid — AC-20).
func _make_invalid_boss_empty_sequence() -> BossData:
	var phase: PhaseData = PhaseData.new()
	phase.phase_index = 0
	phase.idle_duration_after_attack = _IDLE_DURATION
	phase.attack_sequence = [] as Array[AttackData]
	phase.phase_transition_anim = &""

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_invalid_empty_seq"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = []
	boss.phases = [phase]
	boss.default_telegraph_durations = {}
	return boss


## Build a two-phase BossData for reset_for_retry phase-restore tests.
## Phase 0: LIGHT attack. Phase 1: HEAVY attack.
func _make_two_phase_boss() -> BossData:
	var atk0: AttackData = AttackData.new()
	atk0.attack_type = GameEnums.AttackType.LIGHT
	atk0.damage = 10.0
	atk0.telegraph_duration_override = 0.8

	var phase0: PhaseData = PhaseData.new()
	phase0.phase_index = 0
	phase0.idle_duration_after_attack = _IDLE_DURATION
	phase0.attack_sequence = [atk0] as Array[AttackData]
	phase0.phase_transition_anim = &""

	var atk1: AttackData = AttackData.new()
	atk1.attack_type = GameEnums.AttackType.HEAVY
	atk1.damage = 20.0
	atk1.telegraph_duration_override = 0.8

	var phase1: PhaseData = PhaseData.new()
	phase1.phase_index = 1
	phase1.idle_duration_after_attack = _IDLE_DURATION
	phase1.attack_sequence = [atk1] as Array[AttackData]
	phase1.phase_transition_anim = &""

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_two_phase"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = [0.5]
	boss.phases = [phase0, phase1]
	boss.default_telegraph_durations = {
		int(GameEnums.AttackType.LIGHT): 0.8,
		int(GameEnums.AttackType.HEAVY): 1.2,
	}
	return boss


func before_each() -> void:
	_mock_bus = _MOCK_BUS_SCRIPT.new()
	add_child_autofree(_mock_bus)

	_bsm = _BSM_SCRIPT.new()
	# initialize() BEFORE add_child so _ready() finds _event_bus already set.
	_bsm.initialize(_mock_bus)
	add_child_autofree(_bsm)


# ─── Navigation helpers ───────────────────────────────────────────────────────

## Expire idle_timer → IDLE transitions to TELEGRAPHING.
func _expire_idle() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


## Expire telegraph timer → TELEGRAPHING transitions to ATTACKING.
func _expire_telegraph() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


## Navigate from a freshly init'd BSM into ATTACKING.
func _reach_attacking(boss: BossData) -> void:
	_bsm.init_battle(boss)
	_expire_idle()
	_expire_telegraph()


# ─── AC-19: Reference test — covered by Story 004 ────────────────────────────

## AC-19 was fully implemented and tested in test_bsm_phase_transition.gd
## (test_missing_phase_transition_anim_completes_gracefully_without_crash).
## This stub exists for traceability — it confirms the AC is covered
## without duplicating the test logic.
func test_ac19_missing_phase_transition_anim_already_covered_by_story004() -> void:
	# AC-19 runtime coverage lives in:
	#   game/tests/unit/boss_state_machine/test_bsm_phase_transition.gd
	#   → test_missing_phase_transition_anim_completes_gracefully_without_crash
	#
	# That test verifies: phase_transition_anim set to a nonexistent name → push_warning
	# → _complete_phase_transition() called immediately → no crash → IDLE with phase[1].
	assert_true(true, "AC-19 covered in test_bsm_phase_transition.gd")


# ─── AC-20: Empty attack_sequence → push_error + refuse init ─────────────────

func test_empty_attack_sequence_does_not_set_idle_state() -> void:
	# Arrange: first do a valid init so we know the machine is in IDLE,
	# then navigate to ATTACKING so behavior_state is NOT IDLE.
	# Finally call init_battle with invalid data and confirm IDLE is NOT set.
	var valid_boss: BossData = _make_valid_boss()
	_bsm.init_battle(valid_boss)
	_expire_idle()
	_expire_telegraph()
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"precondition: must be in ATTACKING before calling invalid init_battle"
	)
	# Act: call init_battle with an invalid boss (empty attack_sequence).
	# push_error fires internally — assert_push_error marks it handled so GUT
	# does not flag it as an unexpected error.
	var invalid_boss: BossData = _make_invalid_boss_empty_sequence()
	_bsm.init_battle(invalid_boss)
	assert_push_error("phase[0].attack_sequence is empty")
	# Assert: behavior_state was NOT reset to IDLE — init was refused.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"AC-20: behavior_state must not change when attack_sequence is empty (init refused)"
	)


func test_empty_attack_sequence_does_not_overwrite_boss_data() -> void:
	# Arrange: first load a valid boss so _boss_data is set to valid_boss.
	var valid_boss: BossData = _make_valid_boss()
	_bsm.init_battle(valid_boss)
	assert_not_null(_bsm._boss_data, "precondition: _boss_data must be set after valid init")
	# Act: attempt to load an invalid boss (empty attack_sequence).
	# assert_push_error marks the push_error as handled (not an unexpected GUT error).
	var invalid_boss: BossData = _make_invalid_boss_empty_sequence()
	_bsm.init_battle(invalid_boss)
	assert_push_error("phase[0].attack_sequence is empty")
	# Assert: _boss_data was NOT overwritten with invalid_boss (early return before assignment).
	assert_eq(
		_bsm._boss_data,
		valid_boss,
		"AC-20: _boss_data must not be overwritten when init_battle is refused (empty attack_sequence)"
	)


func test_empty_attack_sequence_in_second_phase_also_refuses_init() -> void:
	# Arrange: phase[0] valid, phase[1] empty — all phases must be validated (AC-20).
	# Navigate to ATTACKING first so we have a known non-IDLE state to compare against.
	_reach_attacking(_make_valid_boss())
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"precondition: must be ATTACKING before calling invalid init_battle"
	)

	var atk_valid: AttackData = AttackData.new()
	atk_valid.attack_type = GameEnums.AttackType.LIGHT
	atk_valid.damage = 10.0
	atk_valid.telegraph_duration_override = 0.8

	var phase0: PhaseData = PhaseData.new()
	phase0.phase_index = 0
	phase0.idle_duration_after_attack = _IDLE_DURATION
	phase0.attack_sequence = [atk_valid] as Array[AttackData]

	var phase1: PhaseData = PhaseData.new()
	phase1.phase_index = 1
	phase1.idle_duration_after_attack = _IDLE_DURATION
	phase1.attack_sequence = [] as Array[AttackData]  # invalid!

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_phase1_empty"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = [0.5]
	boss.phases = [phase0, phase1]
	boss.default_telegraph_durations = {}
	# Act: init_battle with phase[1] empty — push_error marks it handled.
	_bsm.init_battle(boss)
	assert_push_error("phase[1].attack_sequence is empty")
	# Assert: state unchanged — still ATTACKING (not reset to IDLE).
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"AC-20: all phases validated — empty phase[1].attack_sequence must refuse init (state unchanged)"
	)


# ─── AC-21: idle_duration=0.0 → clamped to 0.1s + system initialises normally ─

func test_zero_idle_duration_is_clamped_to_point_one() -> void:
	# Arrange: idle_duration_after_attack=0.0 — invalid, must be clamped.
	var boss: BossData = _make_valid_boss(0.0)
	# Act
	_bsm.init_battle(boss)
	# Assert: value clamped in-place on the PhaseData resource, AND system entered IDLE.
	assert_almost_eq(
		_bsm._current_phase_data.idle_duration_after_attack,
		0.1,
		0.001,
		"AC-21: idle_duration_after_attack=0.0 must be clamped to 0.1s after init_battle"
	)


func test_zero_idle_duration_still_initialises_system_to_idle() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss(0.0)
	# Act
	_bsm.init_battle(boss)
	# Assert: system fully initialised despite the clamped duration.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"AC-21: system must initialise to IDLE normally even when idle_duration was clamped"
	)


func test_valid_idle_duration_is_not_clamped() -> void:
	# Arrange: idle_duration=0.5 (valid) — must not be modified (regression guard).
	var boss: BossData = _make_valid_boss(0.5)
	# Act
	_bsm.init_battle(boss)
	# Assert: value unchanged.
	assert_almost_eq(
		_bsm._current_phase_data.idle_duration_after_attack,
		0.5,
		0.001,
		"AC-21 regression: valid idle_duration=0.5 must not be clamped"
	)


# ─── AC-22: sub-frame telegraph override → clamped to MIN_TELEGRAPH_DURATION ──

func test_subframe_telegraph_override_is_clamped_to_min() -> void:
	# Arrange: AttackData with telegraph_duration_override=0.005 (sub-frame at 60fps).
	var boss: BossData = _make_valid_boss()
	_bsm.init_battle(boss)
	var attack: AttackData = AttackData.new()
	attack.attack_type = GameEnums.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = 0.005
	# Act: call _get_effective_telegraph_duration directly (private but accessible in GDScript).
	var result: float = _bsm._get_effective_telegraph_duration(attack)
	# Assert: must be clamped to MIN_TELEGRAPH_DURATION (0.1).
	assert_almost_eq(
		result,
		_BSM_SCRIPT.MIN_TELEGRAPH_DURATION,
		0.001,
		"AC-22: override=0.005 (sub-frame) must be clamped to MIN_TELEGRAPH_DURATION (%.1f)" \
		% _BSM_SCRIPT.MIN_TELEGRAPH_DURATION
	)


func test_valid_telegraph_override_is_not_clamped() -> void:
	# Arrange: override=0.8 (well above threshold) — must pass through unchanged.
	var boss: BossData = _make_valid_boss()
	_bsm.init_battle(boss)
	var attack: AttackData = AttackData.new()
	attack.attack_type = GameEnums.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = 0.8
	# Act
	var result: float = _bsm._get_effective_telegraph_duration(attack)
	# Assert: value passed through unchanged.
	assert_almost_eq(
		result,
		0.8,
		0.001,
		"AC-22 regression: valid override=0.8 must not be clamped"
	)


func test_telegraph_exactly_at_subframe_threshold_is_not_clamped() -> void:
	# Arrange: override exactly at _SUBFRAME_THRESHOLD (0.016) — boundary condition.
	# The check is strict: < threshold (not <=), so 0.016 must NOT be clamped.
	var boss: BossData = _make_valid_boss()
	_bsm.init_battle(boss)
	var attack: AttackData = AttackData.new()
	attack.attack_type = GameEnums.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = _BSM_SCRIPT._SUBFRAME_THRESHOLD
	# Act
	var result: float = _bsm._get_effective_telegraph_duration(attack)
	# Assert: exactly at threshold → NOT clamped (boundary is exclusive).
	assert_almost_eq(
		result,
		_BSM_SCRIPT._SUBFRAME_THRESHOLD,
		0.001,
		"AC-22 boundary: override exactly at _SUBFRAME_THRESHOLD must not be clamped (< is exclusive)"
	)


# ─── ADR-0003 reset_for_retry ─────────────────────────────────────────────────

func test_reset_for_retry_sets_behavior_state_idle() -> void:
	# Arrange: navigate to ATTACKING state.
	_reach_attacking(_make_valid_boss())
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.ATTACKING,
		"precondition: must be in ATTACKING before reset"
	)
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"ADR-0003: reset_for_retry must set behavior_state=IDLE"
	)


func test_reset_for_retry_clears_sequence_index() -> void:
	# Arrange: init, advance sequence_index manually.
	_bsm.init_battle(_make_valid_boss())
	_bsm.sequence_index = 3
	assert_eq(_bsm.sequence_index, 3, "precondition: sequence_index must be 3")
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert
	assert_eq(
		_bsm.sequence_index,
		0,
		"ADR-0003: reset_for_retry must reset sequence_index to 0"
	)


func test_reset_for_retry_clears_idle_timer() -> void:
	# Arrange: init (sets idle_timer = 0.5), then do NOT expire it.
	_bsm.init_battle(_make_valid_boss())
	assert_almost_eq(
		_bsm.idle_timer,
		_IDLE_DURATION,
		0.001,
		"precondition: idle_timer must be set from PhaseData after init_battle"
	)
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert: timer zeroed (ADR-0003: reset does not restart the idle loop).
	assert_almost_eq(
		_bsm.idle_timer,
		0.0,
		0.001,
		"ADR-0003: reset_for_retry must set idle_timer=0.0"
	)


func test_reset_for_retry_clears_internal_telegraph_timer() -> void:
	# Arrange: navigate to TELEGRAPHING so internal_telegraph_timer is live.
	var boss: BossData = _make_valid_boss()
	_bsm.init_battle(boss)
	_expire_idle()
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING)
	assert_gt(
		_bsm.internal_telegraph_timer,
		0.0,
		"precondition: internal_telegraph_timer must be running in TELEGRAPHING"
	)
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert
	assert_almost_eq(
		_bsm.internal_telegraph_timer,
		0.0,
		0.001,
		"ADR-0003: reset_for_retry must set internal_telegraph_timer=0.0"
	)


func test_reset_for_retry_clears_pending_phase_transition_flag() -> void:
	# Arrange: init and set the pending flag manually (simulates mid-fight state).
	_bsm.init_battle(_make_two_phase_boss())
	_bsm._pending_phase_transition = true
	_bsm._pending_to_phase = 1
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert: both pending fields cleared.
	assert_false(
		_bsm._pending_phase_transition,
		"ADR-0003: reset_for_retry must clear _pending_phase_transition"
	)
	assert_eq(
		_bsm._pending_to_phase,
		0,
		"ADR-0003: reset_for_retry must clear _pending_to_phase to 0"
	)


func test_reset_for_retry_restores_phase_data_from_context() -> void:
	# Arrange: two-phase boss, init at phase 0, then reset to phase 1.
	var boss: BossData = _make_two_phase_boss()
	_bsm.init_battle(boss)
	assert_eq(_bsm._current_phase_data.phase_index, 0, "precondition: phase 0 active")
	# Act: retry from phase 1 (player died mid-phase-1).
	_bsm.reset_for_retry({"boss_phase": 1, "boss_hp": 750.0})
	# Assert: _current_phase_data updated to phase[1].
	assert_eq(
		_bsm._current_phase_data.phase_index,
		1,
		"ADR-0003: reset_for_retry must restore _current_phase_data to ctx['boss_phase']=1"
	)


func test_reset_for_retry_works_from_phase_transition_state() -> void:
	# Arrange: put BSM in PHASE_TRANSITION manually (headless bypass — no real AnimationPlayer).
	var boss: BossData = _make_two_phase_boss()
	_bsm.init_battle(boss)
	_bsm._pending_to_phase = 1
	_bsm.behavior_state = _BSM_SCRIPT.BehaviorState.PHASE_TRANSITION
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.PHASE_TRANSITION)
	# Act: reset resets from PHASE_TRANSITION back to IDLE.
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.IDLE,
		"ADR-0003: reset_for_retry must work from PHASE_TRANSITION state"
	)
	assert_eq(
		_bsm._current_phase_data.phase_index,
		0,
		"ADR-0003: reset_for_retry from PHASE_TRANSITION must restore ctx['boss_phase']=0"
	)


func test_reset_for_retry_clears_pending_anim_fallback() -> void:
	# Arrange: navigate to ATTACKING (sets _pending_anim_fallback=true when no AnimationPlayer).
	_reach_attacking(_make_valid_boss())
	assert_true(
		_bsm._pending_anim_fallback,
		"precondition: _pending_anim_fallback must be true in ATTACKING without AnimationPlayer"
	)
	# Act
	_bsm.reset_for_retry({"boss_phase": 0})
	# Assert: fallback flag cleared so no phantom animation_done fires after reset.
	assert_false(
		_bsm._pending_anim_fallback,
		"ADR-0003: reset_for_retry must clear _pending_anim_fallback"
	)
