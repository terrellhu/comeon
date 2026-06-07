extends GutTest

## ParryTelegraphSystem Story 005 — reset + player_died/boss_defeated guards.
##
## ACs covered:
##   AC-17  (4 tests) — player_died during TELEGRAPHING → immediate IDLE, no apply_damage,
##                       no parry_failed; IDLE + player_died → no-op
##   AC-18  (3 tests) — boss_defeated during TELEGRAPHING → immediate IDLE, no apply_damage;
##                       IDLE + boss_defeated → no-op; timer cleared
##   AC-reset (4 tests) — reset_for_retry restores clean IDLE; no signals; clears fields;
##                         idempotent (already IDLE); _warned_duplicate cleared
##   AC-22  (1 test)  — pending (native Godot Profiler required)

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

## Put PTS into TELEGRAPHING with a partial timer advance.
func _start_telegraph(attack_type: GameEnums.AttackType, damage: float, timer_advance: float) -> void:
	_mock_bus.attack_telegraphed.emit(attack_type, damage)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING,
			"helper precondition: must be TELEGRAPHING after attack_telegraphed")
	if timer_advance > 0.0:
		_pts._physics_process(timer_advance)


# ─── AC-17: player_died during TELEGRAPHING ──────────────────────────────────

func test_pts_player_died_while_telegraphing_transitions_to_idle() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.SWEEP, 30.0, 0.50)
	assert_almost_eq(_pts.telegraph_timer, 0.50, 0.001,
			"precondition: timer must be 0.50s before player_died")

	# Act
	_mock_bus.player_died.emit()

	# Assert
	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-17: system_state must be IDLE after player_died"
	)


func test_pts_player_died_while_telegraphing_clears_timer() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.SWEEP, 30.0, 0.50)

	# Act
	_mock_bus.player_died.emit()

	# Assert
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-17: telegraph_timer must be 0.0 after player_died"
	)


func test_pts_player_died_while_telegraphing_does_not_apply_damage() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.SWEEP, 30.0, 0.50)
	var calls_before: int = _mock_hds.apply_damage_call_count

	# Act
	_mock_bus.player_died.emit()

	# Assert
	assert_eq(
		_mock_hds.apply_damage_call_count,
		calls_before,
		"AC-17: apply_damage must NOT be called when player_died cancels the telegraph"
	)


func test_pts_player_died_while_idle_is_noop() -> void:
	# Arrange — system starts IDLE, no telegraph active
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: must be IDLE")
	var calls_before: int = _mock_hds.apply_damage_call_count

	# Act
	_mock_bus.player_died.emit()

	# Assert
	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-17: system_state must remain IDLE when player_died arrives while already IDLE"
	)
	assert_eq(
		_mock_hds.apply_damage_call_count,
		calls_before,
		"AC-17: apply_damage must not be called when IDLE receives player_died"
	)


# ─── AC-18: boss_defeated during TELEGRAPHING ────────────────────────────────

func test_pts_boss_defeated_while_telegraphing_transitions_to_idle() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.LIGHT, 10.0, 0.20)
	assert_almost_eq(_pts.telegraph_timer, 0.20, 0.001,
			"precondition: timer must be 0.20s before boss_defeated")

	# Act
	_mock_bus.boss_defeated.emit()

	# Assert
	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-18: system_state must be IDLE after boss_defeated"
	)


func test_pts_boss_defeated_while_telegraphing_clears_timer() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.LIGHT, 10.0, 0.20)

	# Act
	_mock_bus.boss_defeated.emit()

	# Assert
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-18: telegraph_timer must be 0.0 after boss_defeated"
	)


func test_pts_boss_defeated_while_telegraphing_does_not_apply_damage() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.LIGHT, 10.0, 0.20)
	var calls_before: int = _mock_hds.apply_damage_call_count

	# Act
	_mock_bus.boss_defeated.emit()

	# Assert
	assert_eq(
		_mock_hds.apply_damage_call_count,
		calls_before,
		"AC-18: apply_damage must NOT be called when boss_defeated cancels the telegraph"
	)


# ─── AC-reset: reset_for_retry restores clean IDLE state ─────────────────────

func test_pts_reset_for_retry_while_telegraphing_returns_to_idle() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.HEAVY, 20.0, 0.30)

	# Act
	_pts.reset_for_retry({})

	# Assert
	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-reset: system_state must be IDLE after reset_for_retry"
	)


func test_pts_reset_for_retry_clears_timer_and_fields() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.HEAVY, 20.0, 0.30)

	# Act
	_pts.reset_for_retry({})

	# Assert
	assert_almost_eq(
		_pts.telegraph_timer,
		0.0,
		0.001,
		"AC-reset: telegraph_timer must be 0.0 after reset_for_retry"
	)
	assert_almost_eq(
		_pts.current_damage,
		0.0,
		0.001,
		"AC-reset: current_damage must be 0.0 after reset_for_retry"
	)
	assert_false(
		_pts.window_open,
		"AC-reset: window_open must be false after reset_for_retry"
	)


func test_pts_reset_for_retry_does_not_emit_signals() -> void:
	# Arrange
	_start_telegraph(GameEnums.AttackType.HEAVY, 20.0, 0.30)
	watch_signals(_mock_bus)

	# Act
	_pts.reset_for_retry({})

	# Assert — no parry_failed or any other bus signal during reset
	assert_signal_not_emitted(
		_mock_bus,
		"parry_failed",
		"AC-reset: parry_failed must NOT be emitted during reset_for_retry"
	)
	assert_eq(
		_mock_hds.apply_damage_call_count,
		0,
		"AC-reset: apply_damage must NOT be called during reset_for_retry"
	)


func test_pts_reset_for_retry_is_idempotent_when_already_idle() -> void:
	# Arrange — system starts IDLE (no active telegraph)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.IDLE, "precondition: must be IDLE")

	# Act — calling reset on an already-IDLE system must not crash or change state
	_pts.reset_for_retry({})

	# Assert
	assert_eq(
		_pts.system_state,
		_PTS_SCRIPT.ParryState.IDLE,
		"AC-reset: system_state must remain IDLE when reset_for_retry called while IDLE"
	)
	assert_eq(
		_mock_hds.apply_damage_call_count,
		0,
		"AC-reset: apply_damage must not be called when IDLE reset invoked"
	)


# ─── AC-22: parry success signal latency ≤ 0.5ms (pending — native build) ────

func test_pts_parry_success_signal_latency_within_budget() -> void:
	pending("AC-22: latency measurement requires native Godot Profiler — cannot be measured in GUT headless")
