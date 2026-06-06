extends GutTest

## BossStateMachine Story 003 — DEFEATED terminal state + BossData T_default lookup.
##
## ACs covered by this file:
##   AC-06  boss_defeated from any state → immediate DEFEATED; timers cleared
##   AC-10  telegraph_duration_override > 0 wins over T_default (override=0.6, T_default=0.8)
##   AC-11  override == 0 → T_default from BossData.default_telegraph_durations (HEAVY=1.2 s)
##   AC-23  Same-frame STAGGERED: boss_defeated preempts stagger_ended; sequence_index unchanged
##   AC-24  DEFEATED ignores stagger_ended, parry_succeeded, parry_failed
##
## GUT headless rules:
##   - Access enums/consts via _BSM_SCRIPT.X — never via the BossStateMachine global.
##   - initialize(mock) BEFORE add_child so _ready() finds _event_bus already set.
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

## Override value used in AC-10 (wins over T_default[LIGHT]=0.8).
const _OVERRIDE_DURATION: float = 0.6

## T_default[LIGHT] set in test boss fixture — must differ from _OVERRIDE_DURATION.
const _TDEFAULT_LIGHT: float = 0.8

## T_default[HEAVY] set in test boss fixture — used for AC-11.
const _TDEFAULT_HEAVY: float = 1.2


## Build a single-attack BossData.
## telegraph_duration_override == 0.0 unless explicitly set by the caller so that
## T_default fallback path (AC-11) can be exercised without interference.
func _make_boss(
	attack_type: GameEnums.AttackType,
	telegraph_override: float
) -> BossData:
	var atk: AttackData = AttackData.new()
	atk.attack_type = attack_type
	atk.damage = 10.0
	atk.telegraph_duration_override = telegraph_override

	var phase: PhaseData = PhaseData.new()
	phase.phase_index = 0
	phase.idle_duration_after_attack = _IDLE_DURATION
	phase.attack_sequence = [atk] as Array[AttackData]

	var boss: BossData = BossData.new()
	boss.boss_id = &"test_boss_defeated"
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = []
	boss.phases = [phase]
	# Populate both AttackType defaults so every test has a well-formed fixture.
	boss.default_telegraph_durations = {
		int(GameEnums.AttackType.LIGHT): _TDEFAULT_LIGHT,
		int(GameEnums.AttackType.HEAVY): _TDEFAULT_HEAVY,
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

func _expire_idle() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


func _expire_telegraph() -> void:
	_bsm._physics_process(_EXPIRE_DELTA)


func _reach_telegraphing(boss: BossData) -> void:
	_bsm.init_battle(boss)
	_expire_idle()


func _reach_attacking(boss: BossData) -> void:
	_reach_telegraphing(boss)
	_expire_telegraph()


func _reach_staggered(boss: BossData) -> void:
	_reach_telegraphing(boss)
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)


# ─── AC-06: boss_defeated from IDLE → DEFEATED + timers cleared ──────────────

func test_boss_defeated_from_idle_transitions_to_defeated() -> void:
	# Arrange
	_bsm.init_battle(_make_boss(GameEnums.AttackType.LIGHT, 0.8))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act
	_bsm._on_boss_defeated()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-06: boss_defeated from IDLE must enter DEFEATED"
	)


func test_boss_defeated_from_idle_clears_timers() -> void:
	# Arrange
	_bsm.init_battle(_make_boss(GameEnums.AttackType.LIGHT, 0.8))
	assert_gt(_bsm.idle_timer, 0.0, "precondition: idle_timer must be primed after init_battle")
	# Act
	_bsm._on_boss_defeated()
	# Assert
	assert_almost_eq(_bsm.idle_timer, 0.0, 0.001,
		"AC-06: idle_timer must be 0 after DEFEATED entry from IDLE")
	assert_almost_eq(_bsm.internal_telegraph_timer, 0.0, 0.001,
		"AC-06: internal_telegraph_timer must be 0 after DEFEATED entry from IDLE")


func test_boss_defeated_from_telegraphing_clears_telegraph_timer() -> void:
	# Arrange: enter TELEGRAPHING so internal_telegraph_timer is running.
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_reach_telegraphing(boss)
	assert_gt(_bsm.internal_telegraph_timer, 0.0,
		"precondition: internal_telegraph_timer must be running in TELEGRAPHING")
	# Act
	_bsm._on_boss_defeated()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-06: boss_defeated from TELEGRAPHING must enter DEFEATED"
	)
	assert_almost_eq(_bsm.idle_timer, 0.0, 0.001,
		"AC-06: idle_timer must be 0 after DEFEATED entry from TELEGRAPHING")
	assert_almost_eq(_bsm.internal_telegraph_timer, 0.0, 0.001,
		"AC-06: internal_telegraph_timer must be 0 after DEFEATED entry from TELEGRAPHING")


func test_boss_defeated_from_attacking_transitions_to_defeated() -> void:
	# Arrange
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_reach_attacking(boss)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.ATTACKING,
		"precondition: must be in ATTACKING")
	# Act
	_bsm._on_boss_defeated()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-06: boss_defeated from ATTACKING must enter DEFEATED"
	)
	assert_almost_eq(_bsm.idle_timer, 0.0, 0.001,
		"AC-06: idle_timer must be 0 after DEFEATED entry from ATTACKING")
	assert_almost_eq(_bsm.internal_telegraph_timer, 0.0, 0.001,
		"AC-06: internal_telegraph_timer must be 0 after DEFEATED entry from ATTACKING")
	assert_false(_bsm._pending_anim_fallback,
		"AC-06: _pending_anim_fallback must be cleared when boss_defeated interrupts ATTACKING")


func test_boss_defeated_from_staggered_transitions_to_defeated() -> void:
	# Arrange
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_reach_staggered(boss)
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED,
		"precondition: must be in STAGGERED")
	# Act
	_bsm._on_boss_defeated()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-06: boss_defeated from STAGGERED must enter DEFEATED"
	)
	assert_almost_eq(_bsm.idle_timer, 0.0, 0.001,
		"AC-06: idle_timer must be 0 after DEFEATED entry from STAGGERED")
	assert_almost_eq(_bsm.internal_telegraph_timer, 0.0, 0.001,
		"AC-06: internal_telegraph_timer must be 0 after DEFEATED entry from STAGGERED")


func test_boss_defeated_no_attack_telegraphed_emitted_afterwards() -> void:
	# Arrange: enter DEFEATED, then attempt to drive the timer forward.
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_bsm.init_battle(boss)
	_bsm._on_boss_defeated()
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.DEFEATED)
	_mock_bus.attack_telegraphed_call_count = 0
	# Act: drive _physics_process for 3 simulated seconds.
	_bsm._physics_process(_EXPIRE_DELTA)
	_bsm._physics_process(_EXPIRE_DELTA)
	_bsm._physics_process(_EXPIRE_DELTA)
	# Assert: DEFEATED has no timer → no TELEGRAPHING → no attack_telegraphed.
	assert_eq(
		_mock_bus.attack_telegraphed_call_count,
		0,
		"AC-06: attack_telegraphed must not fire after entering DEFEATED (timers dead)"
	)


# ─── AC-10: telegraph_duration_override wins over T_default ──────────────────

func test_telegraph_override_wins_over_tdefault_when_set() -> void:
	# Arrange: attack_type=LIGHT, override=0.6, T_default[LIGHT]=0.8.
	# If override wins → timer = 0.6; if default wins → timer = 0.8.
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, _OVERRIDE_DURATION)
	_bsm.init_battle(boss)
	_expire_idle()
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING,
		"precondition: must enter TELEGRAPHING after idle expires")
	# Assert: override (0.6) must be used, not T_default (0.8).
	assert_almost_eq(
		_bsm.internal_telegraph_timer,
		_OVERRIDE_DURATION,
		0.001,
		"AC-10: internal_telegraph_timer must equal override=0.6, not T_default=0.8"
	)


# ─── AC-11: override == 0 → T_default from BossData ─────────────────────────

func test_tdefault_used_when_override_is_zero() -> void:
	# Arrange: attack_type=HEAVY, override=0.0 → T_default[HEAVY]=1.2.
	var boss: BossData = _make_boss(GameEnums.AttackType.HEAVY, 0.0)
	_bsm.init_battle(boss)
	_expire_idle()
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.TELEGRAPHING,
		"precondition: must enter TELEGRAPHING after idle expires")
	# Assert: T_default (1.2) must be used, not any fallback.
	assert_almost_eq(
		_bsm.internal_telegraph_timer,
		_TDEFAULT_HEAVY,
		0.001,
		"AC-11: internal_telegraph_timer must equal T_default[HEAVY]=1.2 when override=0"
	)


# ─── AC-23: Same-frame STAGGERED: boss_defeated preempts stagger_ended ───────

func test_boss_defeated_preempts_stagger_ended_same_frame() -> void:
	# Arrange: STAGGERED, sequence_index=1.
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_reach_staggered(boss)
	_bsm.sequence_index = 1
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.STAGGERED)
	# Act: boss_defeated fires first, then stagger_ended fires same frame.
	_bsm._on_boss_defeated()
	_bsm._on_stagger_ended()
	# Assert: DEFEATED wins; sequence_index must not advance.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-23: behavior_state must be DEFEATED after same-frame boss_defeated + stagger_ended"
	)
	assert_eq(
		_bsm.sequence_index,
		1,
		"AC-23: sequence_index must not advance — stagger_ended must be ignored in DEFEATED"
	)


# ─── AC-24: DEFEATED ignores all subsequent signals ──────────────────────────

func test_defeated_ignores_stagger_ended_parry_succeeded_parry_failed() -> void:
	# Arrange: enter DEFEATED.
	var boss: BossData = _make_boss(GameEnums.AttackType.LIGHT, 0.8)
	_bsm.init_battle(boss)
	_bsm._on_boss_defeated()
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.DEFEATED,
		"precondition: must be in DEFEATED")
	_mock_bus.attack_telegraphed_call_count = 0
	# Act: fire all signals that have state guards.
	_bsm._on_stagger_ended()
	_bsm._on_parry_succeeded(GameEnums.AttackType.LIGHT)
	_bsm._on_parry_failed(GameEnums.AttackType.LIGHT)
	# Assert: state unchanged; no attack_telegraphed emitted.
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"AC-24: all signals must be ignored — state must remain DEFEATED"
	)
	assert_eq(
		_mock_bus.attack_telegraphed_call_count,
		0,
		"AC-24: attack_telegraphed must not fire after signals received in DEFEATED"
	)


# ─── EventBus wiring: boss_defeated signal routes through mock ───────────────

func test_boss_defeated_signal_routes_through_eventbus_to_defeated() -> void:
	# Arrange
	_bsm.init_battle(_make_boss(GameEnums.AttackType.LIGHT, 0.8))
	assert_eq(_bsm.behavior_state, _BSM_SCRIPT.BehaviorState.IDLE)
	# Act: emit via mock EventBus (exercises _ready() subscription wiring).
	_mock_bus.boss_defeated.emit()
	# Assert
	assert_eq(
		_bsm.behavior_state,
		_BSM_SCRIPT.BehaviorState.DEFEATED,
		"_ready() must wire EventBus.boss_defeated → _on_boss_defeated"
	)
