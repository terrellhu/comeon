extends GutTest

## ParryTelegraphSystem Story 004 — Path B/C: Parry Failure + Empty Parry + Attack Landing.
##
## ACs covered:
##   AC-04   Path B early press — window preserved; no apply_damage; no parry_failed
##   AC-05   Path B late press — attack still lands on timeout
##   AC-06   Path C empty parry (IDLE) — exit_parry_state only; no side effects
##   AC-11   Attack landing on timeout — apply_damage(PLAYER, damage) + parry_failed emitted
##   AC-19   Zero-damage attack still calls apply_damage(PLAYER, 0.0)
##   AC-24   All three paths end in IDLE state

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


# ─── Helpers ─────────────────────────────────────────────────────────────────

## Starts a HEAVY telegraph (duration=1.2s, window=[0.60, 0.95]).
func _start_heavy_telegraph() -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	assert_almost_eq(_pts.window_open_time, 0.60, 0.001, "precondition: HEAVY window_open=0.60s")
	assert_almost_eq(_pts.window_close_time, 0.95, 0.001, "precondition: HEAVY window_close=0.95s")


## Starts a LIGHT telegraph (duration=0.8s, window=[0.40, 0.70]).
func _start_light_telegraph(damage: float = 10.0) -> void:
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.LIGHT, damage)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")
	assert_almost_eq(_pts.telegraph_duration, 0.8, 0.001, "precondition: LIGHT duration=0.8s")


# ─── AC-04: Path B early press — window preserved; no side effects ────────────

func test_pts_path_b_early_press_emits_exit_parry_state() -> void:
	# Arrange: HEAVY, advance to t=0.30s (before window_open_time 0.60s)
	_start_heavy_telegraph()
	_pts._physics_process(0.30)
	assert_false(_pts.window_open, "precondition: window closed at 0.30s")
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: exit_parry_state always emitted (AC-07 contract preserved)
	assert_signal_emitted(_pts, "exit_parry_state",
		"AC-04: exit_parry_state must be emitted on early Path B press")


func test_pts_path_b_early_press_does_not_emit_parry_succeeded() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.30)
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_not_emitted(_mock_bus, "parry_succeeded",
		"AC-04: parry_succeeded must NOT be emitted on early Path B press")


func test_pts_path_b_early_press_does_not_call_apply_damage() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.30)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_eq(_mock_hds.apply_damage_call_count, 0,
		"AC-04: apply_damage must NOT be called on early Path B press")


func test_pts_path_b_early_press_does_not_emit_parry_failed() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.30)
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_not_emitted(_mock_bus, "parry_failed",
		"AC-04: parry_failed must NOT be emitted on early Path B press")


func test_pts_path_b_early_press_preserves_telegraph_timer() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.30)
	var timer_before: float = _pts.telegraph_timer

	# Act
	_pts._on_parry_input_pressed()

	# Assert: timer not reset — telegraph continues
	assert_almost_eq(_pts.telegraph_timer, timer_before, 0.001,
		"AC-04: telegraph_timer must not change on early Path B press")


func test_pts_path_b_early_press_state_remains_telegraphing() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(0.30)

	# Act
	_pts._on_parry_input_pressed()

	# Assert: still TELEGRAPHING — attack will land on timeout
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING,
		"AC-04: system_state must remain TELEGRAPHING after early Path B press")


func test_pts_path_b_early_press_window_still_opens_later() -> void:
	# Arrange: early press at t=0.30s, then advance into the HEAVY window
	_start_heavy_telegraph()
	_pts._physics_process(0.30)
	_pts._on_parry_input_pressed()

	# Act: advance to t=0.72s (inside HEAVY window [0.60, 0.95])
	_pts._physics_process(0.42)

	# Assert: window opens correctly — early press must not corrupt window timing
	assert_true(_pts.window_open,
		"AC-04: window must open at t=0.72s after an early press at t=0.30s")


# ─── AC-05: Path B late press — attack still lands on timeout ────────────────

func test_pts_path_b_late_press_does_not_call_apply_damage_immediately() -> void:
	# Arrange: HEAVY, advance past window_close_time (0.95s) to 1.10s
	_start_heavy_telegraph()
	_pts._physics_process(1.10)
	assert_false(_pts.window_open, "precondition: window closed at 1.10s")

	# Act: late parry input
	_pts._on_parry_input_pressed()

	# Assert: no immediate apply_damage — it fires on timeout, not on button press
	assert_eq(_mock_hds.apply_damage_call_count, 0,
		"AC-05: apply_damage must NOT be called immediately on late Path B press")


func test_pts_path_b_late_press_apply_damage_called_on_timeout() -> void:
	# Arrange: HEAVY, advance to 1.10s (late press), then let timeout fire
	_start_heavy_telegraph()
	_pts._physics_process(1.10)
	_pts._on_parry_input_pressed()

	# Act: advance past telegraph_duration (1.2s)
	_pts._physics_process(0.20)  # total = 1.30s > 1.2s

	# Assert: apply_damage called exactly once when timer expired
	assert_eq(_mock_hds.apply_damage_call_count, 1,
		"AC-05: apply_damage must be called exactly once when HEAVY telegraph expires")
	assert_eq(_mock_hds.last_apply_damage_target, GameEnums.Target.PLAYER,
		"AC-05: apply_damage target must be PLAYER")
	assert_almost_eq(_mock_hds.last_apply_damage_amount, 25.0, 0.001,
		"AC-05: apply_damage amount must be current_damage (25.0)")


func test_pts_path_b_late_press_parry_failed_emitted_on_timeout() -> void:
	# Arrange: HEAVY, late press at 1.10s
	_start_heavy_telegraph()
	_pts._physics_process(1.10)
	_pts._on_parry_input_pressed()
	watch_signals(_mock_bus)

	# Act: advance to timeout
	_pts._physics_process(0.20)

	# Assert
	assert_signal_emitted(_mock_bus, "parry_failed",
		"AC-05: parry_failed must be emitted when HEAVY telegraph expires after late press")
	var params: Array = get_signal_parameters(_mock_bus, "parry_failed")
	assert_eq(params[0], GameEnums.AttackType.HEAVY,
		"AC-05: parry_failed payload must be HEAVY")


func test_pts_path_b_late_press_returns_to_idle_on_timeout() -> void:
	# Arrange
	_start_heavy_telegraph()
	_pts._physics_process(1.10)
	_pts._on_parry_input_pressed()

	# Act
	_pts._physics_process(0.20)

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-05: state must be IDLE after timeout following late Path B press")


func test_pts_path_b_late_press_emits_exit_parry_state() -> void:
	# Arrange: HEAVY, advance past window_close_time (0.95s) to 1.10s
	_start_heavy_telegraph()
	_pts._physics_process(1.10)
	assert_false(_pts.window_open, "precondition: window closed at 1.10s")
	watch_signals(_pts)

	# Act: late parry input
	_pts._on_parry_input_pressed()

	# Assert: exit_parry_state fires immediately on the press (not deferred to timeout)
	assert_signal_emitted(_pts, "exit_parry_state",
		"AC-05: exit_parry_state must be emitted immediately on late Path B press")


# ─── AC-06: Path C — empty parry in IDLE state ───────────────────────────────

func test_pts_path_c_idle_emits_exit_parry_state() -> void:
	# Arrange: system starts IDLE (no telegraph)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: IDLE")
	watch_signals(_pts)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_emitted(_pts, "exit_parry_state",
		"AC-06: exit_parry_state must be emitted on Path C (IDLE)")


func test_pts_path_c_idle_does_not_emit_parry_succeeded() -> void:
	# Arrange
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_not_emitted(_mock_bus, "parry_succeeded",
		"AC-06: parry_succeeded must NOT be emitted on Path C")


func test_pts_path_c_idle_does_not_call_apply_damage() -> void:
	# Arrange + Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_eq(_mock_hds.apply_damage_call_count, 0,
		"AC-06: apply_damage must NOT be called on Path C")


func test_pts_path_c_idle_does_not_emit_parry_failed() -> void:
	# Arrange
	watch_signals(_mock_bus)

	# Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_signal_not_emitted(_mock_bus, "parry_failed",
		"AC-06: parry_failed must NOT be emitted on Path C")


func test_pts_path_c_idle_state_remains_idle() -> void:
	# Arrange + Act
	_pts._on_parry_input_pressed()

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-06: state must remain IDLE after Path C")


# ─── AC-11: Attack landing — apply_damage + parry_failed on timeout ──────────

func test_pts_attack_landing_calls_apply_damage_player() -> void:
	# Arrange: LIGHT, damage=10, no parry input
	_start_light_telegraph(10.0)

	# Act: advance past telegraph_duration (0.8s)
	_pts._physics_process(1.0)

	# Assert: apply_damage called once with PLAYER target and correct amount
	assert_eq(_mock_hds.apply_damage_call_count, 1,
		"AC-11: apply_damage must be called exactly once when telegraph expires")
	assert_eq(_mock_hds.last_apply_damage_target, GameEnums.Target.PLAYER,
		"AC-11: apply_damage target must be PLAYER")
	assert_almost_eq(_mock_hds.last_apply_damage_amount, 10.0, 0.001,
		"AC-11: apply_damage amount must match current_damage (10.0)")


func test_pts_attack_landing_emits_parry_failed_light() -> void:
	# Arrange
	_start_light_telegraph(10.0)
	watch_signals(_mock_bus)

	# Act
	_pts._physics_process(1.0)

	# Assert
	assert_signal_emitted(_mock_bus, "parry_failed",
		"AC-11: parry_failed must be emitted when LIGHT telegraph expires")
	var params: Array = get_signal_parameters(_mock_bus, "parry_failed")
	assert_eq(params[0], GameEnums.AttackType.LIGHT,
		"AC-11: parry_failed payload must be LIGHT")


func test_pts_attack_landing_returns_to_idle() -> void:
	# Arrange
	_start_light_telegraph(10.0)

	# Act
	_pts._physics_process(1.0)

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-11: state must be IDLE after LIGHT telegraph expires")



func test_pts_attack_landing_apply_damage_called_exactly_once() -> void:
	# Arrange: advance well past duration
	_start_light_telegraph(10.0)

	# Act
	_pts._physics_process(5.0)

	# Assert: exactly one call — no repeat on subsequent physics frames in IDLE
	assert_eq(_mock_hds.apply_damage_call_count, 1,
		"AC-11: apply_damage must be called exactly once even when delta > duration")


# ─── AC-19: Zero-damage attack still calls apply_damage(PLAYER, 0.0) ─────────

func test_pts_zero_damage_attack_calls_apply_damage_with_zero() -> void:
	# Arrange: LIGHT telegraph, damage=0.0
	_start_light_telegraph(0.0)
	assert_almost_eq(_pts.current_damage, 0.0, 0.001, "precondition: current_damage = 0.0")

	# Act: telegraph expires with no parry
	_pts._physics_process(1.0)

	# Assert: apply_damage called with 0.0 — HealthDamageSystem's own guard handles it
	assert_eq(_mock_hds.apply_damage_call_count, 1,
		"AC-19: apply_damage must still be called even when damage = 0.0")
	assert_almost_eq(_mock_hds.last_apply_damage_amount, 0.0, 0.001,
		"AC-19: apply_damage amount must be 0.0")
	assert_eq(_mock_hds.last_apply_damage_target, GameEnums.Target.PLAYER,
		"AC-19: apply_damage target must be PLAYER for zero-damage attack")


func test_pts_zero_damage_attack_emits_parry_failed() -> void:
	# Arrange
	_start_light_telegraph(0.0)
	watch_signals(_mock_bus)

	# Act
	_pts._physics_process(1.0)

	# Assert: parry_failed still emitted regardless of damage amount
	assert_signal_emitted(_mock_bus, "parry_failed",
		"AC-19: parry_failed must be emitted even when damage = 0.0")


func test_pts_zero_damage_attack_returns_to_idle() -> void:
	# Arrange
	_start_light_telegraph(0.0)

	# Act
	_pts._physics_process(1.0)

	# Assert
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-19: state must be IDLE after zero-damage telegraph expires")


# ─── AC-24: All three paths end in IDLE state ─────────────────────────────────

func test_pts_path_a_ends_in_idle() -> void:
	# Path A: parry inside window
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	_pts._physics_process(0.72)  # inside HEAVY window [0.60, 0.95]
	assert_true(_pts.window_open, "precondition: window open at 0.72s")

	_pts._on_parry_input_pressed()

	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-24: Path A must end in IDLE")


func test_pts_path_b_late_ends_in_idle_after_timeout() -> void:
	# Path B (late): parry after window, then let attack land
	_start_heavy_telegraph()
	_pts._physics_process(1.10)  # past window_close
	_pts._on_parry_input_pressed()
	_pts._physics_process(0.20)  # push past duration

	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-24: Path B (late) must end in IDLE after timeout")


func test_pts_path_c_ends_in_idle() -> void:
	# Path C: parry while IDLE
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: IDLE")

	_pts._on_parry_input_pressed()

	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE,
		"AC-24: Path C must leave system in IDLE")
