extends GutTest

# Integration tests for PlayerController Story 003: Parry Signal Contract.
# Covers: parry_input_pressed emission, exit_parry_state() timer setup,
# timer countdown in _process_state, state transitions on timer expiry,
# velocity locking during PARRYING, and _can_parry() guard enforcement.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent type: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.
#   - Input.is_action_just_pressed() always returns false in GUT headless — ACs that
#     require a real parry button press are deferred and marked with pending().
#   - is_on_floor() always returns false in GUT headless.
#
# ACs deferred to physics-scene integration tests:
#   AC-parry-enter           — requires Input.is_action_just_pressed(&"parry") = true
#   AC-parry-priority        — requires simultaneous parry+dodge press
#   AC-parry-isolation-jump  — requires jump input press while in PARRYING

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


# ─── Signal emission: _enter_state(PARRYING) ──────────────────────────────────

func test_enter_parrying_emits_parry_input_pressed_signal() -> void:
	# Arrange: start from IDLE (the canonical parry-entry state)
	_pc.player_state = GameEnums.PlayerState.IDLE
	watch_signals(_pc)
	# Act
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	# Assert
	assert_signal_emitted(
		_pc, "parry_input_pressed",
		"_enter_state(PARRYING) must emit parry_input_pressed (AC-parry-enter signal contract)"
	)
	assert_eq(
		_pc.velocity.x,
		0.0,
		"_enter_state(PARRYING) must zero velocity.x"
	)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.PARRYING,
		"player_state must be PARRYING after transition"
	)


func test_enter_parrying_from_running_emits_signal() -> void:
	# Arrange: start from RUNNING — also a valid parry-entry state
	_pc.player_state = GameEnums.PlayerState.RUNNING
	watch_signals(_pc)
	# Act
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	# Assert
	assert_signal_emitted(
		_pc, "parry_input_pressed",
		"Parry from RUNNING must also emit parry_input_pressed"
	)
	assert_eq(
		_pc.velocity.x,
		0.0,
		"velocity.x must be zeroed on PARRYING entry from RUNNING"
	)


func test_enter_parrying_from_airborne_emits_signal() -> void:
	# AC-airborne-parry: air parry is explicitly allowed; velocity.y must be preserved.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.velocity.y = -300.0   # simulate upward movement mid-air
	watch_signals(_pc)
	# Act
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	# Assert
	assert_signal_emitted(
		_pc, "parry_input_pressed",
		"Air parry must emit parry_input_pressed (AC-airborne-parry)"
	)
	assert_eq(
		_pc.velocity.x,
		0.0,
		"velocity.x must be zeroed on airborne PARRYING entry"
	)
	assert_almost_eq(
		_pc.velocity.y,
		-300.0,
		0.001,
		"velocity.y must be unchanged when entering PARRYING from AIRBORNE (gravity continues)"
	)


func test_parry_input_pressed_signal_not_emitted_from_other_states() -> void:
	# Transitioning to RUNNING must NOT emit parry_input_pressed.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.IDLE
	watch_signals(_pc)
	# Act: transition to RUNNING, not PARRYING
	_pc._transition_to(GameEnums.PlayerState.RUNNING)
	# Assert
	assert_signal_not_emitted(
		_pc, "parry_input_pressed",
		"parry_input_pressed must only be emitted when entering PARRYING, not other states"
	)


# ─── _can_parry() guard enforcement ───────────────────────────────────────────

func test_can_parry_false_during_dodging() -> void:
	# AC-parry-isolation-dodge: DODGING is not in _can_parry()'s allowed list.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.DODGING
	watch_signals(_pc)
	# Assert guard
	assert_false(
		_pc._can_parry(),
		"_can_parry() must return false when state is DODGING (AC-parry-isolation-dodge)"
	)
	# Also confirm state does not change after _handle_input() — no parry input active
	# in headless, so the guard cannot be triggered via input. Verify state stability.
	_pc._handle_input()
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DODGING,
		"State must stay DODGING after _handle_input() when no parry input is active"
	)
	assert_signal_not_emitted(
		_pc, "parry_input_pressed",
		"parry_input_pressed must NOT be emitted while in DODGING state"
	)


# ─── exit_parry_state() public method ────────────────────────────────────────

func test_exit_parry_state_sets_timer() -> void:
	# AC-parry-exit: calling exit_parry_state(duration) must set the backing timer.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	# Act
	_pc.exit_parry_state(0.40)
	# Assert
	assert_almost_eq(
		_pc.parry_exit_timer,
		0.40,
		0.001,
		"exit_parry_state(0.40) must set parry_exit_timer to 0.40"
	)


# ─── Timer countdown in _process_state(PARRYING) ─────────────────────────────

func test_parry_exit_timer_counts_down() -> void:
	# Verify the timer decrements correctly across two _process_state calls.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.exit_parry_state(0.50)
	# Act: first step
	_pc._process_state(0.20)
	# Assert: 0.50 - 0.20 = 0.30
	assert_almost_eq(
		_pc.parry_exit_timer,
		0.30,
		0.001,
		"parry_exit_timer must decrement by delta on each _process_state call (step 1)"
	)
	# Act: second step
	_pc._process_state(0.20)
	# Assert: 0.30 - 0.20 = 0.10
	assert_almost_eq(
		_pc.parry_exit_timer,
		0.10,
		0.001,
		"parry_exit_timer must continue decrementing (step 2)"
	)


func test_parry_exits_to_idle_when_timer_expires() -> void:
	# AC-parry-exit: when the timer reaches zero, state must transition to IDLE
	# (no move input active in headless → IDLE, not RUNNING).
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.exit_parry_state(0.05)
	# Act: delta (0.10) exceeds remaining timer (0.05)
	_pc._process_state(0.10)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"PARRYING must transition to IDLE when exit timer expires and no move input is held"
	)


func test_parry_velocity_x_locked_during_parrying() -> void:
	# Any external velocity.x set while PARRYING must be zeroed by _process_state.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.velocity.x = 500.0   # simulate an external force applied
	# Act: one frame with no active exit timer
	_pc._process_state(0.016)
	# Assert: velocity.x must be locked at 0.0
	assert_eq(
		_pc.velocity.x,
		0.0,
		"velocity.x must be locked to 0.0 each frame while in PARRYING state"
	)


func test_parry_velocity_x_locked_while_timer_active() -> void:
	# Confirm velocity.x stays 0.0 even while the exit timer is counting down.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.exit_parry_state(0.50)
	_pc.velocity.x = 300.0
	# Act: one frame — timer is still active, no transition yet
	_pc._process_state(0.016)
	# Assert
	assert_eq(
		_pc.velocity.x,
		0.0,
		"velocity.x must remain 0.0 during PARRYING even with an active exit timer"
	)


func test_parry_exit_timer_zero_on_exit_state() -> void:
	# _exit_state(PARRYING) must reset _parry_exit_timer to 0.0.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.parry_exit_timer = 0.30
	# Act: transition away from PARRYING triggers _exit_state(PARRYING)
	_pc._transition_to(GameEnums.PlayerState.IDLE)
	# Assert
	assert_eq(
		_pc.parry_exit_timer,
		0.0,
		"_exit_state(PARRYING) must reset parry_exit_timer to 0.0"
	)


func test_parry_timer_does_not_count_when_zero() -> void:
	# With no exit timer set, _process_state must not decrement below zero or
	# trigger a spurious state transition.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.parry_exit_timer = 0.0   # explicit: timer never started
	# Act
	_pc._process_state(0.016)
	# Assert: state still PARRYING, timer still 0.0
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.PARRYING,
		"PARRYING must not self-transition when exit timer is 0.0 (timer never started)"
	)
	assert_eq(
		_pc.parry_exit_timer,
		0.0,
		"parry_exit_timer must remain 0.0 when it was not started"
	)


# ─── Deferred: acceptance criteria requiring Input injection ──────────────────
# These stubs document the gap and prevent the story from being marked Done
# without physics-scene integration test coverage.

# Names the future physics-scene integration test file that covers Input-dependent ACs.
# This file does not yet exist — create it as part of the PlayerController integration test story.
const INTEGRATION_FILE: String = \
	"game/tests/integration/player_controller/test_pc_parry_physics.gd"


func test_ac_parry_enter_from_idle_via_input_pending() -> void:
	pending(
		"AC-parry-enter: full entry via Input.is_action_just_pressed(&'parry') " +
		"returns false in GUT headless. Integration test must assert: " +
		"(1) state = PARRYING, (2) velocity.x = 0.0, " +
		"(3) parry_input_pressed emitted same frame as input, " +
		"(4) move_left/move_right held same frame → velocity.x remains 0.0 (move input ignored). " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_parry_priority_same_frame_parry_dodge_pending() -> void:
	pending(
		"AC-parry-priority: verifying parry beats dodge on same frame requires " +
		"both Input.is_action_just_pressed(&'parry') and (&'dodge') to return true " +
		"simultaneously — impossible in GUT headless. Integration test must assert: " +
		"(1) state = PARRYING, (2) parry_input_pressed emitted, " +
		"(3) dodge_input_pressed NOT emitted. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_parry_isolation_jump_blocked_pending() -> void:
	pending(
		"AC-parry-isolation-jump: verifying jump is blocked while PARRYING requires " +
		"Input.is_action_just_pressed(&'jump') to return true. " +
		"Integration test must assert: state stays PARRYING, velocity.y unchanged, " +
		"jump_buffer_timer unchanged. " +
		"Deferred to: " + INTEGRATION_FILE
	)
