extends GutTest

# Tests for PlayerController Story 002: Jump system — coyote time + jump buffer.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent types: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.
#   - is_on_floor() always returns false in GUT headless (no physics scene). Any
#     acceptance criterion that requires a true grounding check is deferred to
#     integration tests and marked with pending().
#   - Input.is_action_just_pressed() always returns false in GUT headless. Any
#     acceptance criterion that requires actual jump-button press is deferred and
#     marked with pending().
#
# ACs deferred to integration tests (game/tests/integration/player_controller/):
#   AC-jump           — full ground jump (Input press + is_on_floor)
#   AC-coyote-success — coyote jump via real jump press
#   AC-coyote-expired — no jump after coyote expires, via real jump press
#   AC-buffer-success — buffer fires on landing (requires is_on_floor = true)
#   AC-buffer-expired — normal landing when buffer gone (requires is_on_floor = true)
#   AC-no-double-jump — double-jump blocked, buffer set (requires Input press)

# ─── Fixtures ─────────────────────────────────────────────────────────────────

# Use Node (not PlayerController) to avoid headless parse-time class_name failure.
var _pc: Node
# Tracks which InputMap actions THIS fixture added so after_each() only erases
# those — never erases actions that existed before (from project.godot or other tests).
var _added_actions: Array[String] = []


func before_each() -> void:
	# Register dummy InputMap actions so _handle_input() does not log engine errors
	# in headless mode. Only add each action if it doesn't already exist.
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
	_pc.coyote_time_duration = 0.10
	_pc.jump_buffer_duration = 0.12
	add_child_autoqfree(_pc)


func after_each() -> void:
	# Only erase actions that before_each() added — do not clobber pre-existing ones.
	for action: String in _added_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_added_actions.clear()


# ─── AC-jump / AC-coyote-success: _can_jump() guard ──────────────────────────

func test_can_jump_returns_true_when_coyote_timer_active() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.05   # half-expired; still within window
	# Act / Assert
	assert_true(
		_pc._can_jump(),
		"_can_jump() must return true when coyote_timer > 0.0 (AC-coyote-success)"
	)


func test_can_jump_returns_true_when_coyote_timer_full() -> void:
	# Arrange: fresh coyote window (just walked off edge)
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.10
	# Act / Assert
	assert_true(
		_pc._can_jump(),
		"_can_jump() must return true at the start of the coyote window"
	)


func test_can_jump_returns_true_when_coyote_timer_nearly_expired() -> void:
	# Edge case: coyote_timer = 0.001 — still counts as active
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.001
	assert_true(
		_pc._can_jump(),
		"_can_jump() must return true even at 0.001s remaining in coyote window"
	)


func test_can_jump_returns_false_when_coyote_timer_zero_and_airborne() -> void:
	# Arrange: expired coyote window + not on floor (headless always not on floor)
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.0
	# Act / Assert
	assert_false(
		_pc._can_jump(),
		"_can_jump() must return false when coyote_timer = 0.0 and not on floor (AC-coyote-expired)"
	)


# ─── Timer decrement: coyote_timer ────────────────────────────────────────────

func test_coyote_timer_decrements_each_process_state_call() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.10
	var delta: float = 0.05
	# Act
	_pc._process_state(delta)
	# Assert: timer should have decreased by delta (gravity also accumulates, that's fine)
	assert_almost_eq(
		_pc.coyote_timer,
		0.05,
		0.001,
		"coyote_timer must decrement by delta each _process_state call"
	)


func test_coyote_timer_clamps_to_zero_not_negative() -> void:
	# Arrange: timer smaller than delta
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.01
	var delta: float = 0.05   # larger than timer
	# Act
	_pc._process_state(delta)
	# Assert: must not go below zero
	assert_eq(
		_pc.coyote_timer,
		0.0,
		"coyote_timer must clamp to 0.0 when delta exceeds remaining time, never negative"
	)


# ─── Timer decrement: jump_buffer_timer ───────────────────────────────────────

func test_jump_buffer_timer_decrements_each_process_state_call() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.jump_buffer_timer = 0.12
	var delta: float = 0.05
	# Act
	_pc._process_state(delta)
	# Assert
	assert_almost_eq(
		_pc.jump_buffer_timer,
		0.07,
		0.001,
		"jump_buffer_timer must decrement by delta each _process_state call"
	)


func test_jump_buffer_timer_clamps_to_zero_not_negative() -> void:
	# Arrange: timer smaller than delta
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.jump_buffer_timer = 0.01
	var delta: float = 0.05
	# Act
	_pc._process_state(delta)
	# Assert
	assert_eq(
		_pc.jump_buffer_timer,
		0.0,
		"jump_buffer_timer must clamp to 0.0 when delta exceeds remaining time, never negative"
	)


func test_jump_buffer_timer_does_not_decrement_when_zero() -> void:
	# Arrange: already zeroed — the decrement branch is guarded by > 0.0
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.jump_buffer_timer = 0.0
	# Act
	_pc._process_state(0.016)
	# Assert: stays exactly 0.0
	assert_eq(
		_pc.jump_buffer_timer,
		0.0,
		"jump_buffer_timer must remain 0.0 when it was already at 0.0"
	)


func test_coyote_timer_does_not_decrement_when_zero() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.0
	# Act
	_pc._process_state(0.016)
	# Assert
	assert_eq(
		_pc.coyote_timer,
		0.0,
		"coyote_timer must remain 0.0 when it was already at 0.0"
	)


# ─── AC-coyote-no-reset: coyote timer starts on first departure only ──────────

func test_exit_idle_starts_coyote_timer_when_not_jumped() -> void:
	# Arrange: standing on nothing (headless), no active coyote window, no jump
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = false
	# Act: _transition_to(AIRBORNE) calls _exit_state(IDLE) internally
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert: coyote window should have been opened
	assert_almost_eq(
		_pc.coyote_timer,
		_pc.coyote_time_duration,
		0.001,
		"_exit_state(IDLE) must start coyote_timer when leaving without a jump"
	)


func test_exit_running_starts_coyote_timer_when_not_jumped() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.RUNNING
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = false
	# Act
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert
	assert_almost_eq(
		_pc.coyote_timer,
		_pc.coyote_time_duration,
		0.001,
		"_exit_state(RUNNING) must start coyote_timer when leaving without a jump"
	)


func test_exit_idle_does_not_restart_coyote_timer_if_already_active() -> void:
	# AC-coyote-no-reset: if coyote_timer is already running, do not restart it.
	# This prevents a second departure (brief re-grounding then off again) from
	# resetting the window — only the initial departure starts the clock.
	# Arrange: coyote window already partially elapsed
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.coyote_timer = 0.05   # already active
	_pc._jumped_this_frame = false
	# Act
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert: timer stays at 0.05, NOT reset to coyote_time_duration (0.10)
	assert_almost_eq(
		_pc.coyote_timer,
		0.05,
		0.001,
		"_exit_state(IDLE) must NOT restart coyote_timer if it is already active (AC-coyote-no-reset)"
	)


func test_exit_running_does_not_restart_coyote_timer_if_already_active() -> void:
	# Same AC-coyote-no-reset test but from RUNNING state
	_pc.player_state = GameEnums.PlayerState.RUNNING
	_pc.coyote_timer = 0.09
	_pc._jumped_this_frame = false
	# Act
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert
	assert_almost_eq(
		_pc.coyote_timer,
		0.09,
		0.001,
		"_exit_state(RUNNING) must NOT restart coyote_timer if it is already active (AC-coyote-no-reset)"
	)


func test_exit_idle_does_not_start_coyote_timer_when_jumped() -> void:
	# _jumped_this_frame = true means this was an intentional jump, not a fall.
	# Coyote must NOT start — the player jumped, not walked off.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = true
	# Act: transition as if jump execution triggered it
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert: coyote_timer stays 0.0 despite transitioning to AIRBORNE
	assert_eq(
		_pc.coyote_timer,
		0.0,
		"_exit_state(IDLE) must NOT start coyote_timer when the player intentionally jumped"
	)


func test_exit_running_does_not_start_coyote_timer_when_jumped() -> void:
	# Same as above but from RUNNING
	_pc.player_state = GameEnums.PlayerState.RUNNING
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = true
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	assert_eq(
		_pc.coyote_timer,
		0.0,
		"_exit_state(RUNNING) must NOT start coyote_timer when the player intentionally jumped"
	)


# ─── Fall detection: IDLE and RUNNING → AIRBORNE when not on floor ────────────
# is_on_floor() always returns false in GUT headless — these tests exercise the
# `else: _transition_to(AIRBORNE)` branch directly.

func test_process_state_idle_transitions_to_airborne_when_not_on_floor() -> void:
	# Arrange: in IDLE, not on floor (guaranteed in headless)
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = false
	# Act
	_pc._process_state(0.016)
	# Assert: must have transitioned to AIRBORNE (ledge fall detection)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.AIRBORNE,
		"IDLE fall detection must transition to AIRBORNE when is_on_floor() returns false"
	)


func test_process_state_idle_fall_detection_starts_coyote_timer() -> void:
	# The same fall that transitions to AIRBORNE should start the coyote window
	# (because _exit_state(IDLE) fires with _jumped_this_frame = false, coyote_timer = 0.0).
	# Note: timer decrements run BEFORE the match block, so when _exit_state(IDLE) sets
	# coyote_timer = coyote_time_duration, the decrement for that frame has already run.
	# Result: coyote_timer equals coyote_time_duration exactly (not minus one delta).
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = false
	# Act
	_pc._process_state(0.016)
	# Assert: coyote window opened at full duration (decrement ran before match block)
	assert_almost_eq(
		_pc.coyote_timer,
		_pc.coyote_time_duration,
		0.001,
		"Fall-detection transition must set coyote_timer to full coyote_time_duration"
	)


func test_process_state_running_transitions_to_airborne_when_not_on_floor() -> void:
	# Arrange: in RUNNING, not on floor
	_pc.player_state = GameEnums.PlayerState.RUNNING
	_pc.coyote_timer = 0.0
	_pc._jumped_this_frame = false
	# Act
	_pc._process_state(0.016)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.AIRBORNE,
		"RUNNING fall detection must transition to AIRBORNE when is_on_floor() returns false"
	)


# ─── Jump buffer in AIRBORNE: no fire when not on floor ──────────────────────
# The buffer fires only when is_on_floor() = true, which headless cannot provide.
# This test confirms the buffer value is preserved while airborne (does not fire spuriously).

func test_jump_buffer_does_not_fire_while_airborne_and_not_on_floor() -> void:
	# Arrange: AIRBORNE with an active buffer
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.jump_buffer_timer = 0.08
	_pc.velocity.y = 0.0
	# Act: one physics frame — is_on_floor() returns false in headless so buffer should not fire
	_pc._process_state(0.016)
	# Assert: state should still be AIRBORNE (buffer did not trigger a re-jump)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.AIRBORNE,
		"jump buffer must NOT fire while airborne (is_on_floor false) — only fires on landing"
	)


# ─── _jumped_this_frame resets at start of _handle_input ─────────────────────

func test_jumped_this_frame_resets_to_false_each_handle_input_call() -> void:
	# Arrange: manually set the flag to true to verify it resets
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc._jumped_this_frame = true
	# Act: call _handle_input — DEAD guard does not fire (state is IDLE),
	# no Input actions are active in headless, so the reset at the top is the
	# only thing that happens to this flag.
	_pc._handle_input()
	# Assert
	assert_false(
		_pc._jumped_this_frame,
		"_jumped_this_frame must be reset to false at the start of every _handle_input call"
	)


# ─── Deferred: acceptance criteria requiring Input injection or physics ────────
# These tests are stubs. They are included to document the gap and prevent
# the story from being marked Done without integration test coverage.

const INTEGRATION_FILE: String = \
	"game/tests/integration/player_controller/test_pc_jump_integration.gd"


func test_ac_jump_ground_jump_sets_velocity_and_state_pending() -> void:
	pending(
		"AC-jump: full ground jump (velocity.y = -jump_impulse, state -> AIRBORNE) " +
		"requires Input.is_action_just_pressed to return true AND is_on_floor() = true. " +
		"Integration test must also assert: (1) velocity.y = -jump_impulse, " +
		"(2) state = AIRBORNE, (3) _can_jump() returned true from floor check. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_coyote_success_jump_within_window_pending() -> void:
	pending(
		"AC-coyote-success: coyote jump execution requires real jump button press. " +
		"Integration test must assert: (1) velocity.y = -jump_impulse, " +
		"(2) state = AIRBORNE, (3) coyote_timer = 0.0 after jump (timer zeroed on execution). " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_coyote_expired_no_jump_pending() -> void:
	pending(
		"AC-coyote-expired: verifying jump does NOT execute when coyote_timer = 0 " +
		"requires Input.is_action_just_pressed to return true. " +
		"Integration test must assert: velocity.y unchanged, jump_buffer_timer set. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_buffer_success_fires_on_landing_pending() -> void:
	pending(
		"AC-buffer-success: buffer firing on landing requires is_on_floor() = true " +
		"(impossible in GUT headless). " +
		"Integration test must assert: (1) velocity.y = -jump_impulse, " +
		"(2) jump_buffer_timer = 0.0, (3) _jumped_this_frame = true (prevents spurious coyote). " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_buffer_expired_normal_landing_pending() -> void:
	pending(
		"AC-buffer-expired: verifying no auto-jump on landing when buffer = 0 " +
		"requires is_on_floor() = true. " +
		"Integration test must assert: state = IDLE/RUNNING, velocity.y = 0.0. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_no_double_jump_buffer_only_pending() -> void:
	pending(
		"AC-no-double-jump: verifying second airborne jump press fills buffer only " +
		"(velocity unchanged) requires Input injection. " +
		"Integration test must assert: velocity.y unchanged, jump_buffer_timer = jump_buffer_duration. " +
		"Deferred to: " + INTEGRATION_FILE
	)
