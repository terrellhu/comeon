extends GutTest

# Integration tests for PlayerController Story 004: HIT_STUN + DEAD State.
# Covers: EventBus-triggered HIT_STUN entry, timer countdown, timer reset on re-hit,
# HIT_STUN exit to IDLE/RUNNING, DEAD entry from all states, DEAD priority over
# DODGING/PARRYING, DEAD blocking all input, and hit_stun_duration clamping.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent type: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.
#   - Input.is_action_just_pressed() always returns false in GUT headless.
#   - is_on_floor() always returns false in GUT headless.
#   - EventBus is a registered Autoload — available in headless as /root/EventBus.
#     Handler methods are called directly rather than through signal emission
#     so tests remain deterministic and independent of signal routing.

# ─── Fixtures ─────────────────────────────────────────────────────────────────

# Use Node (not PlayerController) to avoid headless parse-time class_name failure.
var _pc: Node
# Tracks which InputMap actions THIS fixture added so after_each() only erases
# those — never erases actions that existed before (from project.godot or other tests).
var _added_actions: Array[String] = []


func before_each() -> void:
	# Register dummy InputMap actions so _handle_input() does not log engine errors
	# in headless mode. Only add each action if it does not already exist.
	_added_actions.clear()
	for action: String in ["parry", "dodge", "jump", "attack", "move_left", "move_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_added_actions.append(action)

	_pc = preload("res://scripts/core/player_controller.gd").new()
	_pc.move_speed = 340.0
	_pc.gravity = 1400.0
	_pc.terminal_velocity = 1200.0
	_pc.jump_impulse = 600.0
	_pc.knockback_speed = 200.0
	_pc.hit_stun_duration = 0.30
	_pc.coyote_time_duration = 0.10
	_pc.jump_buffer_duration = 0.12
	add_child_autoqfree(_pc)


func after_each() -> void:
	# Only erase actions that before_each() added — do not clobber pre-existing ones.
	for action: String in _added_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_added_actions.clear()


# ─── AC-hit-stun-enter ────────────────────────────────────────────────────────

func test_hit_stun_entered_on_hp_decrease() -> void:
	# Given: player in IDLE, facing right, standard defaults.
	# When: HP decreases from 100 to 50.
	# Then: state = HIT_STUN, velocity.x = -200.0, hit_stun_timer ≈ 0.30.
	# Arrange (player starts at IDLE by default — no state assignment needed)
	_pc.facing_direction = 1
	_pc._prev_hp = 100.0
	# Act
	_pc._on_player_hp_changed(50.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.HIT_STUN,
		"HP decrease from IDLE must enter HIT_STUN (AC-hit-stun-enter)"
	)
	assert_almost_eq(
		_pc.velocity.x,
		-200.0,
		0.001,
		"velocity.x must be -knockback_speed when facing right on HIT_STUN entry"
	)
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.30,
		0.001,
		"hit_stun_timer must equal hit_stun_duration on HIT_STUN entry"
	)


func test_hit_stun_not_entered_on_hp_increase() -> void:
	# Given: player in IDLE; HP increases (healing).
	# Then: no state change.
	# Arrange
	_pc._prev_hp = 50.0
	# Act
	_pc._on_player_hp_changed(80.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"HP increase (healing) must NOT enter HIT_STUN (AC-hit-stun-enter edge case)"
	)


func test_hit_stun_not_entered_on_hp_unchanged() -> void:
	# Given: player in IDLE; HP value identical to _prev_hp.
	# Then: no state change.
	# Arrange
	_pc._prev_hp = 100.0
	# Act
	_pc._on_player_hp_changed(100.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"Unchanged HP must NOT enter HIT_STUN (AC-hit-stun-enter edge case)"
	)


func test_hit_stun_not_entered_when_already_dead() -> void:
	# Given: player already DEAD.
	# When: HP decrease signal received.
	# Then: state stays DEAD — DEAD guard blocks HIT_STUN entry.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc._prev_hp = 100.0
	# Act
	_pc._on_player_hp_changed(50.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"DEAD guard must prevent HIT_STUN entry when player is already dead (AC-hit-stun-enter edge case)"
	)


# ─── AC-hit-stun-reset ────────────────────────────────────────────────────────

func test_hit_stun_timer_resets_on_rehit() -> void:
	# Given: player in HIT_STUN with timer half-elapsed.
	# When: second HP decrease received.
	# Then: hit_stun_timer resets to hit_stun_duration.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	_pc.hit_stun_timer = 0.15  # override to simulate half-elapsed
	_pc._prev_hp = 50.0
	# Act
	_pc._on_player_hp_changed(30.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.HIT_STUN,
		"Re-hit during HIT_STUN must stay in HIT_STUN (AC-hit-stun-reset)"
	)
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.30,
		0.001,
		"Re-hit must reset hit_stun_timer to full hit_stun_duration (AC-hit-stun-reset)"
	)


# ─── AC-hit-stun-exit ─────────────────────────────────────────────────────────

func test_hit_stun_exits_to_idle_on_timer_expiry() -> void:
	# Given: player in HIT_STUN, timer nearly expired.
	# When: _process_state called with delta > remaining timer.
	# Then: state transitions to IDLE (no move input in headless).
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	_pc.hit_stun_timer = 0.01  # override to nearly expired
	# Act: delta exceeds remaining timer
	_pc._process_state(0.02)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"HIT_STUN must transition to IDLE when timer expires and no move input (AC-hit-stun-exit)"
	)
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.0,
		0.001,
		"hit_stun_timer must be 0.0 after timer expiry"
	)


func test_hit_stun_timer_counts_down() -> void:
	# Given: player in HIT_STUN, full timer.
	# When: _process_state called with partial delta.
	# Then: timer decremented by delta; state unchanged.
	# Arrange (_enter_state sets _hit_stun_timer = 0.30 — no override needed)
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	# Act
	_pc._process_state(0.10)
	# Assert
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.20,
		0.001,
		"hit_stun_timer must decrement by delta each _process_state call (AC-hit-stun-exit)"
	)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.HIT_STUN,
		"State must remain HIT_STUN while timer is still positive"
	)


# ─── AC-dead-enter ────────────────────────────────────────────────────────────

func test_dead_entered_from_idle_on_player_died() -> void:
	# Given: player in IDLE.
	# When: player_died handler called.
	# Then: state = DEAD, velocity = Vector2.ZERO.
	# Arrange (player starts at IDLE by default)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from IDLE must enter DEAD (AC-dead-enter)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed on DEAD entry from IDLE"
	)


func test_dead_entered_from_running_on_player_died() -> void:
	# Given: player in RUNNING.
	# When: player_died handler called.
	# Then: state = DEAD.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.RUNNING)
	_pc.velocity.x = 340.0
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from RUNNING must enter DEAD (AC-dead-enter)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed on DEAD entry from RUNNING"
	)


func test_dead_entered_from_airborne_on_player_died() -> void:
	# Given: player in AIRBORNE (mid-air).
	# When: player_died handler called.
	# Then: state = DEAD, velocity = Vector2.ZERO.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	_pc.velocity = Vector2(200.0, -300.0)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from AIRBORNE must enter DEAD (AC-dead-enter)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed on DEAD entry from AIRBORNE"
	)


func test_dead_velocity_zeroed_on_entry() -> void:
	# Given: player with non-zero velocity in IDLE.
	# When: player_died handler called.
	# Then: velocity is exactly Vector2.ZERO same frame.
	# Arrange (player starts at IDLE by default)
	_pc.velocity = Vector2(300.0, -200.0)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"_enter_state(DEAD) must set velocity = Vector2.ZERO immediately (AC-dead-enter)"
	)


# ─── AC-dead-priority ─────────────────────────────────────────────────────────

func test_dead_entered_from_dodging_immediately() -> void:
	# Given: player in DODGING (dodge timer still running).
	# When: player_died received.
	# Then: DEAD entered immediately — no waiting for dodge_ended.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from DODGING must enter DEAD immediately (AC-dead-priority)"
	)


func test_dead_entered_from_parrying_immediately() -> void:
	# Given: player in PARRYING with a non-zero parry exit timer.
	# When: player_died received.
	# Then: DEAD entered immediately — parry_exit_timer is irrelevant.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	_pc.parry_exit_timer = 0.40  # override to simulate active parry window
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from PARRYING must enter DEAD immediately (AC-dead-priority)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed when dying from PARRYING"
	)


# ─── AC-dead-input ────────────────────────────────────────────────────────────

func test_dead_blocks_all_input_no_state_change() -> void:
	# Given: player is DEAD.
	# When: _handle_input() called (simulating a physics frame).
	# Then: state stays DEAD, velocity stays Vector2.ZERO, no signals emitted.
	# Note: Input actions all return false in headless — this verifies the DEAD guard
	# prevents any processing even when called, matching the AC intent.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.velocity = Vector2.ZERO
	watch_signals(_pc)
	# Act
	_pc._handle_input()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"DEAD guard must prevent any state change in _handle_input() (AC-dead-input)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must remain Vector2.ZERO after _handle_input() in DEAD state"
	)
	assert_signal_not_emitted(
		_pc, "parry_input_pressed",
		"No signals must be emitted while in DEAD state"
	)
	assert_signal_not_emitted(
		_pc, "attack_input_pressed",
		"No signals must be emitted while in DEAD state"
	)


# ─── AC-hit-stun-duration-constraint ─────────────────────────────────────────

func test_hit_stun_duration_clamped_above_max() -> void:
	# Given: hit_stun_duration set above the 0.5s maximum.
	# Then: value is clamped to 0.5 and a warning is pushed.
	# Arrange + Act
	_pc.hit_stun_duration = 0.51
	# Assert
	assert_almost_eq(
		_pc.hit_stun_duration,
		0.50,
		0.001,
		"hit_stun_duration must be clamped to 0.50 when set to 0.51 (AC-hit-stun-duration-constraint)"
	)


func test_hit_stun_duration_at_max_accepted() -> void:
	# Given: hit_stun_duration set to exactly the maximum 0.5s.
	# Then: value is accepted unchanged.
	# Arrange + Act
	_pc.hit_stun_duration = 0.50
	# Assert
	assert_almost_eq(
		_pc.hit_stun_duration,
		0.50,
		0.001,
		"hit_stun_duration of exactly 0.50 must be accepted without clamping (AC-hit-stun-duration-constraint)"
	)


# ─── Additional edge cases ────────────────────────────────────────────────────

func test_hit_stun_knockback_reversed_on_left_facing() -> void:
	# AC-hit-stun-reset edge: re-hit with facing_direction = -1 → velocity.x = +knockback_speed.
	# Arrange
	_pc.facing_direction = -1
	_pc._prev_hp = 100.0
	# Act
	_pc._on_player_hp_changed(50.0, 100.0)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.HIT_STUN,
		"HP decrease must enter HIT_STUN regardless of facing direction"
	)
	assert_almost_eq(
		_pc.velocity.x,
		200.0,
		0.001,
		"velocity.x must be +knockback_speed when facing left (facing_direction = -1)"
	)


func test_hit_stun_exits_on_exact_boundary() -> void:
	# AC-hit-stun-exit edge: timer == delta → transitions (boundary condition).
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	_pc.hit_stun_timer = 0.10
	# Act: delta exactly equals remaining timer
	_pc._process_state(0.10)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"HIT_STUN must transition to IDLE when delta == hit_stun_timer (exact boundary)"
	)


func test_dead_entered_from_hit_stun() -> void:
	# AC-dead-enter: player_died while in HIT_STUN → DEAD immediately.
	# Also verifies _exit_state(HIT_STUN) resets hit_stun_timer to 0.0.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died from HIT_STUN must enter DEAD immediately (AC-dead-enter)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed on DEAD entry from HIT_STUN"
	)
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.0,
		0.001,
		"_exit_state(HIT_STUN) must reset hit_stun_timer to 0.0"
	)


func test_player_died_while_already_dead_is_idempotent() -> void:
	# AC-dead-enter edge: player_died while already DEAD is safe and idempotent.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.velocity = Vector2.ZERO
	# Act: fire player_died again
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"Repeated player_died while already DEAD must keep state DEAD (idempotent)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must remain Vector2.ZERO after repeated player_died in DEAD state"
	)


func test_hit_stun_duration_zero_accepted() -> void:
	# AC-hit-stun-duration-constraint edge: 0.0 is the minimum valid value (degenerate stun).
	# Arrange + Act
	_pc.hit_stun_duration = 0.0
	# Assert
	assert_almost_eq(
		_pc.hit_stun_duration,
		0.0,
		0.001,
		"hit_stun_duration of 0.0 must be accepted as valid (minimum degenerate stun)"
	)
