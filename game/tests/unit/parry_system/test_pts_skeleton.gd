extends GutTest

## ParryTelegraphSystem Story 001 — skeleton: IDLE/TELEGRAPHING state machine.
##
## ACs covered:
##   AC-01   IDLE → TELEGRAPHING on attack_telegraphed; state/type/damage/timer verified
##   AC-13p  TELEGRAPHING: _physics_process advances timer; telegraph_updated emitted per frame
##   AC-16   Duplicate attack_telegraphed while TELEGRAPHING discarded + _warned_duplicate set
##   AC-24s  TELEGRAPHING → IDLE when timer reaches telegraph_duration (no-input timeout)

const _PTS_SCRIPT: GDScript = preload("res://scripts/feature/parry_telegraph_system.gd")

var _pts: ParryTelegraphSystem
var _mock_bus: MockEventBus
var _mock_hds: MockHealthDamageSystem


func before_each() -> void:
	_mock_bus = MockEventBus.new()
	add_child_autofree(_mock_bus)
	_mock_hds = MockHealthDamageSystem.new()
	add_child_autofree(_mock_hds)
	_pts = _PTS_SCRIPT.new()
	_pts.initialize(_mock_bus, _mock_hds)
	add_child_autofree(_pts)


func after_each() -> void:
	pass  # autofree handles cleanup


# ─── AC-01: IDLE → TELEGRAPHING on attack_telegraphed ────────────────────────

func test_pts_attack_telegraphed_heavy_transitions_to_telegraphing() -> void:
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: must start IDLE")

	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)

	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.TELEGRAPHING,
		"AC-01: system_state must be TELEGRAPHING after attack_telegraphed"
	)
	assert_eq(
		_pts.current_attack_type,
		GameEnums.AttackType.HEAVY,
		"AC-01: current_attack_type must be HEAVY"
	)
	assert_almost_eq(
		_pts.current_damage,
		25.0,
		0.001,
		"AC-01: current_damage must be 25.0"
	)
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-01: telegraph_timer must be 0.0 on TELEGRAPHING entry"
	)


# ─── AC-13 partial: per-frame timer advance and signal emission ───────────────

func test_pts_physics_process_advances_timer_and_emits_signal_each_frame() -> void:
	# Arrange: put system into TELEGRAPHING (precondition for _physics_process to run).
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	# watch_signals MUST come before the actions that emit the watched signal.
	watch_signals(_mock_bus)

	# Act: three physics frames of 0.05s each.
	_pts._physics_process(0.05)
	_pts._physics_process(0.05)
	_pts._physics_process(0.05)

	# Assert: signal count and timer value.
	assert_signal_emit_count(
		_mock_bus,
		"telegraph_updated",
		3,
		"AC-13p: telegraph_updated must be emitted once per _physics_process call"
	)
	assert_almost_eq(
		_pts.telegraph_timer,
		0.15,
		0.001,
		"AC-13p: telegraph_timer must advance by 0.15s after three 0.05s steps"
	)
	var expected_progress: float = 0.15 / _pts.telegraph_duration
	assert_gt(expected_progress, 0.0, "AC-13p: progress must be > 0")
	assert_lt(expected_progress, 1.0, "AC-13p: progress must be < 1 (not yet expired)")


func test_pts_telegraph_timer_resets_to_zero_after_timeout() -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.LIGHT, 10.0)
	assert_almost_eq(_pts.telegraph_duration, 0.8, 0.001, "precondition: LIGHT duration = 0.8")

	_pts._physics_process(0.5)
	assert_almost_eq(_pts.telegraph_timer, 0.5, 0.001, "partial advance: 0.5s")

	# Advance past duration — _exit_state resets timer to 0.0
	_pts._physics_process(0.4)

	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-13p clamp: must have transitioned to IDLE after timeout"
	)
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-13p clamp: timer reset to 0.0 in _exit_state"
	)


# ─── AC-16: duplicate attack_telegraphed while TELEGRAPHING ──────────────────

func test_pts_duplicate_attack_telegraphed_discarded_while_telegraphing() -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")

	var timer_before: float = _pts.telegraph_timer
	var type_before: GameEnums.AttackType = _pts.current_attack_type

	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.LIGHT, 5.0)

	assert_almost_eq(
		_pts.telegraph_timer,
		timer_before,
		0.001,
		"AC-16: telegraph_timer must not change on duplicate signal"
	)
	assert_eq(
		_pts.current_attack_type,
		type_before,
		"AC-16: current_attack_type must not change on duplicate signal"
	)
	assert_true(
		_pts._warned_duplicate,
		"AC-16: _warned_duplicate must be true when duplicate is discarded"
	)


# ─── AC-24 skeleton: TELEGRAPHING → IDLE on timer expiry ─────────────────────

func test_pts_telegraph_timeout_returns_to_idle() -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.SWEEP, 30.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	assert_almost_eq(_pts.telegraph_duration, 1.5, 0.001, "precondition: SWEEP duration 1.5s")

	_pts._physics_process(5.0)  # well past 1.5s duration

	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-24s: system_state must be IDLE after telegraph timeout"
	)
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-24s: telegraph_timer must be 0.0 after returning to IDLE"
	)
	assert_false(
		_pts.window_open,
		"AC-24s: window_open must be false after timeout"
	)
