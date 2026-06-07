extends GutTest

## ParryTelegraphSystem Story 003 — Path A: Parry Success.
##
## ACs covered:
##   AC-03   Window-in parry succeeds: parry_succeeded + exit_parry_state + IDLE
##   AC-07   exit_parry_state always emitted on parry input (any state/path)
##   AC-08   Signal order: parry_succeeded before exit_parry_state; apply_damage = 0
##   AC-09   System returns to IDLE after Path A — no STAGGERING; stagger_ended not emitted
##   AC-14   Boundary: timer exactly at window_open_time counts as success (closed interval)
##   AC-14b  Boundary: timer exactly at window_close_time counts as success (closed interval)
##   AC-15   parry_succeeded carries correct attack_type for LIGHT/HEAVY/SWEEP
##   AC-20   Same-frame boundary: parry input wins when timeout would also fire

const _PTS_SCRIPT: GDScript = preload("res://scripts/feature/parry_telegraph_system.gd")

var _pts: ParryTelegraphSystem
var _mock_bus: MockEventBus


func before_each() -> void:
	_mock_bus = MockEventBus.new()
	add_child_autofree(_mock_bus)
	_pts = _PTS_SCRIPT.new()
	_pts.initialize(_mock_bus)
	add_child_autofree(_pts)


func after_each() -> void:
	pass  # autofree handles cleanup


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _start_heavy_telegraph() -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	assert_almost_eq(_pts.window_open_time, 0.60, 0.001, "precondition: HEAVY window_open=0.60s")
	assert_almost_eq(_pts.window_close_time, 0.95, 0.001, "precondition: HEAVY window_close=0.95s")


# ─── AC-03: Window-in parry succeeds — Path A ────────────────────────────────

func test_pts_path_a_in_window_emits_parry_succeeded() -> void:
	# Arrange: HEAVY telegraph, advance to t=0.72s (inside [0.60, 0.95])
	_start_heavy_telegraph()
	_pts._physics_process(0.72)
	assert_true(_pts.window_open, "precondition: window_open at 0.72s")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: parry_succeeded(HEAVY) emitted on EventBus (AC-03)
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-03: parry_succeeded must be emitted")
	# Verify payload separately via signal watcher parameters
	var params: Array = get_signal_parameters(_mock_bus, "parry_succeeded")
	assert_eq(params[0], GameEnums.AttackType.HEAVY, "AC-03: parry_succeeded payload must be HEAVY")


func test_pts_path_a_in_window_emits_exit_parry_state() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.72)
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: exit_parry_state emitted on PTS itself (1:1 direct signal)
	assert_signal_emitted(_pts, "exit_parry_state", "AC-03: exit_parry_state must be emitted")


func test_pts_path_a_in_window_returns_to_idle() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.72)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-03: state must be IDLE after Path A")


func test_pts_path_a_in_window_clears_timer() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.72)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: _exit_state(TELEGRAPHING) resets telegraph_timer to 0.0
	assert_almost_eq(_pts.telegraph_timer, 0.0, 0.001, "AC-03: telegraph_timer must be cleared after Path A")


# ─── AC-07: exit_parry_state always emitted on parry input ───────────────────

func test_pts_exit_parry_state_emitted_when_idle() -> void:
	# Arrange: system starts IDLE (no telegraph)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: IDLE")
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: Path C — exit_parry_state still emitted once
	assert_signal_emitted(_pts, "exit_parry_state", "AC-07: exit_parry_state must be emitted even when IDLE")


func test_pts_exit_parry_state_emitted_when_telegraphing_outside_window() -> void:
	# Arrange: TELEGRAPHING but timer = 0 (window not open yet)
	_start_heavy_telegraph()
	assert_false(_pts.window_open, "precondition: window closed at t=0")
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: Path B — exit_parry_state still emitted
	assert_signal_emitted(_pts, "exit_parry_state", "AC-07: exit_parry_state must be emitted when window closed")


func test_pts_exit_parry_state_emitted_exactly_once_on_path_a() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.72)
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: exactly one emission
	assert_signal_emit_count(_pts, "exit_parry_state", 1, "AC-07: exit_parry_state must be emitted exactly once")


func test_pts_exit_parry_state_emitted_exactly_once_on_path_c() -> void:
	# Arrange: IDLE
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emit_count(_pts, "exit_parry_state", 1, "AC-07: exit_parry_state must be emitted exactly once on Path C")


# ─── AC-08: Signal order: parry_succeeded before exit_parry_state ────────────

func test_pts_path_a_parry_succeeded_emitted_before_exit_parry_state() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.72)

	var sequence: Array[String] = []
	_mock_bus.parry_succeeded.connect(func(_at: GameEnums.AttackType) -> void:
		sequence.append("parry_succeeded")
	)
	_pts.exit_parry_state.connect(func(_d: float) -> void:
		sequence.append("exit_parry_state")
	)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: both fired in correct order
	assert_eq(sequence.size(), 2, "AC-08: both signals must fire")
	assert_eq(sequence[0], "parry_succeeded", "AC-08: parry_succeeded must fire first")
	assert_eq(sequence[1], "exit_parry_state", "AC-08: exit_parry_state must fire second")


func test_pts_path_a_apply_damage_not_called() -> void:
	# Arrange: Path A — parry in window. PTS never emits parry_failed on Path A.
	_start_heavy_telegraph()
	_pts._physics_process(0.72)
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_not_emitted(_mock_bus, "parry_failed", "AC-08: parry_failed must NOT be emitted on Path A")
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-08: parry_succeeded must be emitted on Path A")


# ─── AC-09: System returns to IDLE after Path A; no STAGGERING ───────────────

func test_pts_path_a_sweep_returns_to_idle_no_stagger_ended() -> void:
	# Arrange: SWEEP (duration=1.5s, window=0.75–1.20s)
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.SWEEP, 30.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	_pts._physics_process(0.90)  # t=0.90s inside [0.75, 1.20]
	assert_true(_pts.window_open, "precondition: window open at 0.90s")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-09: state must be IDLE after SWEEP Path A")
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-09: parry_succeeded must be emitted")
	assert_signal_not_emitted(_mock_bus, "stagger_ended",
		"AC-09: stagger_ended must NOT be emitted by PTS (owned by CounterAttackComboSystem)")


# ─── AC-14: Boundary — timer exactly at window_open_time counts as success ───

func test_pts_path_a_boundary_at_window_open_time_succeeds() -> void:
	# Arrange: HEAVY — window opens at exactly 0.60s (closed interval lower bound)
	_start_heavy_telegraph()
	_pts._physics_process(0.60)
	assert_almost_eq(_pts.telegraph_timer, 0.60, 0.001, "precondition: timer = 0.60s = window_open_time")
	assert_true(_pts.window_open, "precondition: window_open must be true at lower boundary")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_mock_bus, "parry_succeeded",
		"AC-14: parry at exactly window_open_time must succeed (closed interval)")
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-14: state must be IDLE")


# ─── AC-14b: Boundary — timer exactly at window_close_time counts as success ─

func test_pts_path_a_boundary_at_window_close_time_succeeds() -> void:
	# Arrange: HEAVY — window closes at exactly 0.95s (closed interval upper bound)
	_start_heavy_telegraph()
	_pts._physics_process(0.95)
	assert_almost_eq(_pts.telegraph_timer, 0.95, 0.001, "precondition: timer = 0.95s = window_close_time")
	assert_true(_pts.window_open, "precondition: window_open must be true at upper boundary")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_mock_bus, "parry_succeeded",
		"AC-14b: parry at exactly window_close_time must succeed (closed interval)")
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-14b: state must be IDLE")


# ─── AC-15: parry_succeeded carries correct attack_type ──────────────────────

func test_pts_path_a_parry_succeeded_payload_light() -> void:
	# Arrange: LIGHT (duration=0.8s, window=0.40–0.70s)
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.LIGHT, 10.0)
	_pts._physics_process(0.55)  # inside [0.40, 0.70]
	assert_true(_pts.window_open, "precondition: LIGHT window open at 0.55s")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-15: parry_succeeded must be emitted for LIGHT")
	var params: Array = get_signal_parameters(_mock_bus, "parry_succeeded")
	assert_eq(params[0], GameEnums.AttackType.LIGHT, "AC-15: parry_succeeded must carry LIGHT")


func test_pts_path_a_parry_succeeded_payload_heavy() -> void:
	# Arrange: HEAVY (duration=1.2s, window=0.60–0.95s)
	_start_heavy_telegraph()
	_pts._physics_process(0.72)
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-15: parry_succeeded must be emitted for HEAVY")
	var params: Array = get_signal_parameters(_mock_bus, "parry_succeeded")
	assert_eq(params[0], GameEnums.AttackType.HEAVY, "AC-15: parry_succeeded must carry HEAVY")


func test_pts_path_a_parry_succeeded_payload_sweep() -> void:
	# Arrange: SWEEP (duration=1.5s, window=0.75–1.20s)
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.SWEEP, 30.0)
	_pts._physics_process(0.90)  # inside [0.75, 1.20]
	assert_true(_pts.window_open, "precondition: SWEEP window open at 0.90s")
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-15: parry_succeeded must be emitted for SWEEP")
	var params: Array = get_signal_parameters(_mock_bus, "parry_succeeded")
	assert_eq(params[0], GameEnums.AttackType.SWEEP, "AC-15: parry_succeeded must carry SWEEP")


# ─── AC-20: Same-frame boundary — parry input wins when timeout also fires ───

func test_pts_path_a_parry_wins_over_timeout_on_boundary_frame() -> void:
	# Arrange: advance to 0.94s (inside HEAVY window [0.60, 0.95]).
	# Parry input arrives before the next physics frame would push timer past duration.
	# Once parry succeeds and state is IDLE, subsequent _physics_process calls are no-ops.
	_start_heavy_telegraph()
	_pts._physics_process(0.94)
	assert_true(_pts.window_open, "precondition: in window at 0.94s")
	watch_signals(_mock_bus)

	# Act: parry input arrives first (before any more physics frames)
	_pts._on_parry_input_pressed()

	# Assert: Path A wins
	assert_signal_emitted(_mock_bus, "parry_succeeded", "AC-20: parry_succeeded must be emitted")
	assert_signal_not_emitted(_mock_bus, "parry_failed", "AC-20: parry_failed must NOT be emitted")
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-20: state must be IDLE after parry")

	# Confirm: large delta physics has no effect (system already IDLE)
	_pts._physics_process(0.5)  # would exceed duration if still TELEGRAPHING
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "AC-20: state must remain IDLE — no double-trigger")
