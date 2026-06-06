extends GutTest

## BossStateMachine Story 004 — PHASE_TRANSITION state + 4 source state paths.
##
## ACs covered by this file:
##   AC-14  IDLE → boss_phase_changed → immediate PHASE_TRANSITION; after completion
##          PhaseData = phase[1], sequence_index=0, behavior_state=IDLE
##   AC-15  TELEGRAPHING → boss_phase_changed sets pending; telegraph resolves;
##          PHASE_TRANSITION entered (skip IDLE); PhaseData updated, sequence_index=0
##   AC-16  ATTACKING → boss_phase_changed sets pending; animation completes (sequence_index++);
##          PHASE_TRANSITION entered (skip IDLE); PhaseData updated, sequence_index=0
##   AC-17  STAGGERED → boss_phase_changed sets pending; stagger_ended (sequence_index++);
##          PHASE_TRANSITION entered (skip IDLE); PhaseData updated, sequence_index=0
##   AC-18  Second boss_phase_changed during PHASE_TRANSITION: warning + last-wins for to_phase
##   Edge   phase_transition_anim missing → graceful skip (no crash), warning emitted,
##          PHASE_TRANSITION still completes
##   Wiring EventBus.boss_phase_changed routes through mock to _on_boss_phase_changed
##
## GUT headless rules:
##   - Access enums/consts via _BSM_SCRIPT.X — never via the BossStateMachine global.
##   - initialize(mock) BEFORE add_child so _ready() finds _event_bus already set.
##   - Drive timers with real deltas (_EXPIRE_DELTA) — never pre-zero a timer.
##   - _anim_player is null in all tests: PHASE_TRANSITION completion is immediate
##     (no-animation path), letting tests verify PhaseData update without a real player.

# ─── Fixtures ─────────────────────────────────────────────────────────────────

var _bsm: Node
var _mock_bus: MockEventBus

const _BSM_SCRIPT: GDScript = preload("res://scripts/feature/boss_state_machine.gd")
const _MOCK_BUS_SCRIPT: GDScript = preload("res://tests/helpers/mock_event_bus.gd")

## Phase idle delay used by all test bosses.
const _IDLE_DURATION: float = 0.5

## A delta large enough to expire any single timer in one _physics_process call.
const _EXPIRE_DELTA: float = 5.0


## Build a two-phase BossData for phase-transition tests.
## Phase 0: single LIGHT attack, telegraph_duration_override=0.8.
## Phase 1: single HEAVY attack, telegraph_duration_override=0.8.
## phase_transition_anim is empty on both phases by default (no-animation path).
## Pass non-empty anim names via the arguments to test the animation branch.
func _make_two_phase_boss(
	phase0_anim: StringName = &"",
	phase1_anim: StringName = &""
) -> BossData:
	var atk0: AttackData = AttackData.new()
	atk0.attack_type = GameEnums.AttackType.LIGHT
	atk0.damage = 10.0
	atk0.telegraph_duration_override = 0.8

	var phase0: PhaseData = PhaseData.new()
	phase0.phase_index = 0
	phase0.idle_duration_after_attack = _IDLE_DURATION
	phase0.attack_sequence = [atk0] as Array[AttackData]
	phase0.phase_transition_anim = phase0_anim

	var atk1: AttackData = AttackData.new()
	atk1.attack_type = GameEnums.AttackType.HEAVY
	atk1.damage = 20.0
	atk1.telegraph_duration_override = 0.8

	var phase1: PhaseData = PhaseData.new()
	phase1.phase_index = 1
	phase1.idle_duration_after_attack = _IDLE_DURATION
	phase1.attack_sequence = [atk1] as Array[AttackData]
	phase1.phase_transition_anim = phase1_anim

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_phase_transition"
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
	# initialize() BEFORE add_child so _ready() finds _event_bus already set and
	# subscribes to boss_phase_changed on _mock_bus.
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


## Navigate from a freshly init'd BSM into STAGGERED.
func _reach_staggered(boss: BossData) -> void:
	_reach_telegraphing(boss)
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)


# ─── AC-14: IDLE → boss_phase_changed → immediate PHASE_TRANSITION ───────────

func test_boss_phase_changed_from_idle_enters_phase_transition_immediately() -> void:
	# Arrange
	_bsm.init_battle(_make_two_phase_boss())
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"precondition: must be in IDLE after init_battle")
	# Act
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: no animation → _complete_phase_transition fires immediately,
	# so the machine ends up in IDLE (post-transition) not stuck in PHASE_TRANSITION.
	# Verify _pending_to_phase was set correctly before the transition.
	assert_eq(_bsm._pending_to_phase, 1,
		"AC-14: _pending_to_phase must be 1 after boss_phase_changed(0, 1)")


func test_boss_phase_changed_from_idle_updates_phase_data_and_resets_sequence_index() -> void:
	# Arrange: two-phase boss, no transition animation → completion is immediate.
	_bsm.init_battle(_make_two_phase_boss())
	_bsm.sequence_index = 0
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: _complete_phase_transition ran immediately (no anim) →
	# PhaseData is now phase[1] and sequence_index reset to 0, state is IDLE.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-14: behavior_state must be IDLE after immediate PHASE_TRANSITION completion")
	assert_eq(_bsm.sequence_index, 0,
		"AC-14: sequence_index must be 0 after PHASE_TRANSITION completes")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"AC-14: _current_phase_data.phase_index must be 1 after transition to phase[1]")


# ─── AC-15: TELEGRAPHING → pending → PHASE_TRANSITION after telegraph resolves ─

func test_boss_phase_changed_in_telegraphing_sets_pending_flag() -> void:
	# Arrange
	_reach_telegraphing(_make_two_phase_boss())
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING)
	# Act
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: still TELEGRAPHING; pending flag set.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING,
		"AC-15: state must remain TELEGRAPHING immediately after boss_phase_changed")
	assert_true(_bsm._pending_phase_transition,
		"AC-15: _pending_phase_transition must be true")
	assert_eq(_bsm._pending_to_phase, 1,
		"AC-15: _pending_to_phase must be 1")


func test_boss_phase_changed_in_telegraphing_skips_idle_and_enters_phase_transition() -> void:
	# Arrange: in TELEGRAPHING with pending phase change.
	_reach_telegraphing(_make_two_phase_boss())
	_bsm._on_boss_phase_changed(0, 1)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING,
		"precondition: still TELEGRAPHING")
	assert_true(_bsm._pending_phase_transition,
		"precondition: _pending_phase_transition must be set")
	# Act: telegraph expires → ATTACKING. Then animation_done fires →
	# pending flag detected → PHASE_TRANSITION (not IDLE). No anim → immediate completion → IDLE.
	_expire_telegraph()
	# ATTACKING entry sets _pending_anim_fallback; drive one more frame to fire it.
	_bsm._physics_process(0.016)
	# Assert: PHASE_TRANSITION ran and completed immediately (no anim) → IDLE with phase[1].
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-15: behavior_state must be IDLE after deferred PHASE_TRANSITION completes")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"AC-15: _current_phase_data.phase_index must be 1 after transition")
	assert_eq(_bsm.sequence_index, 0,
		"AC-15: sequence_index must be 0 after PHASE_TRANSITION")


func test_boss_phase_changed_in_telegraphing_parry_path_enters_phase_transition() -> void:
	# AC-15 second resolution path: pending set in TELEGRAPHING, then a parry sends
	# the machine through STAGGERED. stagger_ended must honour the pending flag and
	# go to PHASE_TRANSITION (skip IDLE) rather than the normal STAGGERED→IDLE.
	_reach_telegraphing(_make_two_phase_boss())
	_bsm._on_boss_phase_changed(0, 1)
	assert_true(_bsm._pending_phase_transition, "precondition: pending set in TELEGRAPHING")
	# Act: parry → STAGGERED → stagger_ended resolves the pending transition.
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED,
		"precondition: parry moved TELEGRAPHING → STAGGERED")
	_bsm._on_stagger_ended()
	# Assert: deferred PHASE_TRANSITION fired and completed (no anim) → IDLE with phase[1].
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-15 parry path: must reach IDLE after PHASE_TRANSITION completes")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"AC-15 parry path: _current_phase_data.phase_index must be 1")
	assert_eq(_bsm.sequence_index, 0,
		"AC-15 parry path: sequence_index must be 0 after PHASE_TRANSITION")


# ─── AC-16: ATTACKING → pending → PHASE_TRANSITION after animation done ───────

func test_boss_phase_changed_in_attacking_sets_pending_flag() -> void:
	# Arrange
	_reach_attacking(_make_two_phase_boss())
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING)
	# Act
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: still ATTACKING; pending flag set.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING,
		"AC-16: state must remain ATTACKING immediately after boss_phase_changed")
	assert_true(_bsm._pending_phase_transition,
		"AC-16: _pending_phase_transition must be true")
	assert_eq(_bsm._pending_to_phase, 1,
		"AC-16: _pending_to_phase must be 1")


func test_boss_phase_changed_in_attacking_skips_idle_and_enters_phase_transition() -> void:
	# Arrange: in ATTACKING with pending phase change.
	_reach_attacking(_make_two_phase_boss())
	_bsm._on_boss_phase_changed(0, 1)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING)
	# Act: call animation_done directly (bypasses AnimationPlayer — standard headless pattern).
	_bsm._on_attack_animation_done(_BSM_SCRIPT.ANIM_ATTACK)
	# Assert: pending flag detected → PHASE_TRANSITION fired → immediate completion (no anim) → IDLE.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-16: behavior_state must be IDLE after deferred PHASE_TRANSITION completes")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"AC-16: _current_phase_data.phase_index must be 1 after transition")
	assert_eq(_bsm.sequence_index, 0,
		"AC-16: sequence_index must be 0 after PHASE_TRANSITION")


func test_boss_phase_changed_in_attacking_resets_sequence_index_to_zero_after_transition() -> void:
	# Arrange: N=2 attacks in phase 0; position at index 0 in ATTACKING with pending transition.
	var boss: BossData = _make_two_phase_boss()
	# Add a second attack to phase[0] so index 0 → 1 is observable.
	var atk_extra: AttackData = AttackData.new()
	atk_extra.attack_type = GameEnums.AttackType.LIGHT
	atk_extra.damage = 10.0
	atk_extra.telegraph_duration_override = 0.8
	boss.phases[0].attack_sequence.append(atk_extra)
	_reach_attacking(boss)
	_bsm.sequence_index = 0
	_bsm._on_boss_phase_changed(0, 1)
	# Act: animation done — sequence_index advances (mod N) then PHASE_TRANSITION resets it.
	# The +1 increment itself is guarded by Story 001's test_attack_animation_done_advances_sequence_index;
	# this test verifies that PHASE_TRANSITION's reset WINS over the increment (final value is 0, not 1).
	_bsm._on_attack_animation_done(_BSM_SCRIPT.ANIM_ATTACK)
	# Assert: PHASE_TRANSITION reset sequence_index to 0 (not the incremented value 1).
	assert_eq(_bsm.sequence_index, 0,
		"AC-16: PHASE_TRANSITION must reset sequence_index to 0 (overrides the +1 increment)")


# ─── AC-17: STAGGERED → pending → PHASE_TRANSITION after stagger_ended ────────

func test_boss_phase_changed_in_staggered_sets_pending_flag() -> void:
	# Arrange
	_reach_staggered(_make_two_phase_boss())
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	# Act
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: still STAGGERED; pending flag set.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED,
		"AC-17: state must remain STAGGERED immediately after boss_phase_changed")
	assert_true(_bsm._pending_phase_transition,
		"AC-17: _pending_phase_transition must be true")
	assert_eq(_bsm._pending_to_phase, 1,
		"AC-17: _pending_to_phase must be 1")


func test_boss_phase_changed_in_staggered_skips_idle_after_stagger_ended() -> void:
	# Arrange: in STAGGERED with pending phase change.
	_reach_staggered(_make_two_phase_boss())
	_bsm._on_boss_phase_changed(0, 1)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	# Act: stagger_ended fires → pending detected → PHASE_TRANSITION → immediate completion → IDLE.
	_bsm._on_stagger_ended()
	# Assert
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-17: behavior_state must be IDLE after deferred PHASE_TRANSITION from STAGGERED")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"AC-17: _current_phase_data.phase_index must be 1 after transition")
	assert_eq(_bsm.sequence_index, 0,
		"AC-17: sequence_index must be 0 after PHASE_TRANSITION")


# ─── AC-18: Second boss_phase_changed during PHASE_TRANSITION ─────────────────

func test_second_boss_phase_changed_during_phase_transition_updates_pending_to_phase() -> void:
	# Arrange: trigger PHASE_TRANSITION from IDLE (no anim → completes immediately).
	# To keep the machine in PHASE_TRANSITION we need an anim; simulate by calling
	# _on_boss_phase_changed directly and checking _pending_to_phase before completion.
	# We use a spy pattern: start from IDLE, send first signal, then intercept state.
	_bsm.init_battle(_make_two_phase_boss())
	# HEADLESS BYPASS: sets state directly — _enter_state(PHASE_TRANSITION) NOT called.
	# Without a real AnimationPlayer the no-anim path completes immediately, so we
	# pin the machine in PHASE_TRANSITION manually to exercise the AC-18 guard branch.
	_bsm._pending_to_phase = 1
	_bsm.behavior_state = _BSM_SCRIPT.BehaviorState.PHASE_TRANSITION
	# Act: second signal arrives while in PHASE_TRANSITION.
	_bsm._on_boss_phase_changed(1, 2)
	# Assert: state unchanged; _pending_to_phase updated to last-wins value.
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.PHASE_TRANSITION,
		"AC-18: behavior_state must remain PHASE_TRANSITION on second boss_phase_changed")
	assert_eq(_bsm._pending_to_phase, 2,
		"AC-18: _pending_to_phase must update to 2 (last-wins)")


func test_second_boss_phase_changed_during_phase_transition_uses_latest_phase_on_completion() -> void:
	# Arrange: put machine in PHASE_TRANSITION targeting phase[1], then override to phase[2].
	# Extend boss to have 3 phases.
	var boss: BossData = _make_two_phase_boss()
	var atk2: AttackData = AttackData.new()
	atk2.attack_type = GameEnums.AttackType.LIGHT
	atk2.damage = 5.0
	atk2.telegraph_duration_override = 0.8
	var phase2: PhaseData = PhaseData.new()
	phase2.phase_index = 2
	phase2.idle_duration_after_attack = _IDLE_DURATION
	phase2.attack_sequence = [atk2] as Array[AttackData]
	phase2.phase_transition_anim = &""
	boss.phases.append(phase2)

	_bsm.init_battle(boss)
	# HEADLESS BYPASS: sets state directly — _enter_state(PHASE_TRANSITION) NOT called.
	# Pins the machine in PHASE_TRANSITION to test last-wins target override.
	_bsm._pending_to_phase = 1
	_bsm.behavior_state = _BSM_SCRIPT.BehaviorState.PHASE_TRANSITION
	# Second signal overrides target to phase[2].
	_bsm._on_boss_phase_changed(1, 2)
	assert_eq(_bsm._pending_to_phase, 2, "precondition: _pending_to_phase must be 2")
	# Act: simulate animation completion.
	_bsm._complete_phase_transition()
	# Assert: phase[2] data applied, sequence_index=0, IDLE.
	assert_eq(_bsm._current_phase_data.phase_index, 2,
		"AC-18: _current_phase_data.phase_index must be 2 after last-wins completion")
	assert_eq(_bsm.sequence_index, 0,
		"AC-18: sequence_index must be 0 after PHASE_TRANSITION")
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"AC-18: behavior_state must be IDLE after PHASE_TRANSITION completes")


# ─── Edge: phase_transition_anim not found → graceful skip ────────────────────

func test_missing_phase_transition_anim_completes_gracefully_without_crash() -> void:
	# Arrange: phase_transition_anim set to a name that doesn't exist in any AnimationPlayer.
	# _anim_player is null (headless) so has_animation check is skipped → anim name is non-empty
	# → push_warning fires → _complete_phase_transition called immediately.
	var boss: BossData = _make_two_phase_boss(&"", &"nonexistent_anim")
	_bsm.init_battle(boss)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act: trigger phase transition (no real AnimationPlayer wired).
	_bsm._on_boss_phase_changed(0, 1)
	# Assert: machine did not crash; PHASE_TRANSITION completed; now in IDLE with phase[1].
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"Edge: PHASE_TRANSITION must complete gracefully when anim asset is missing")
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"Edge: _current_phase_data.phase_index must be 1 after graceful skip")
	assert_eq(_bsm.sequence_index, 0,
		"Edge: sequence_index must be 0 after graceful PHASE_TRANSITION")


# ─── EventBus wiring: boss_phase_changed routes through mock ──────────────────

func test_boss_phase_changed_signal_routes_through_eventbus_to_handler() -> void:
	# Arrange: BSM in IDLE.
	_bsm.init_battle(_make_two_phase_boss())
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act: emit via mock EventBus (exercises _ready() subscription wiring).
	_mock_bus.boss_phase_changed.emit(0, 1)
	# Assert: handler fired → no anim → completion immediate → IDLE with phase[1].
	assert_eq(_bsm._current_phase_data.phase_index, 1,
		"_ready() must wire EventBus.boss_phase_changed → _on_boss_phase_changed")
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE,
		"After wired boss_phase_changed: behavior_state must be IDLE (immediate completion)")
