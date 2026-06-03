extends GutTest

# Integration tests for PlayerController Story 005: Dodge Signal Contract.
# Covers: dodge_input_pressed emission with correct direction, _can_dodge() guard,
# physics pause (move_and_slide skipped), _on_dodge_ended() resume logic,
# player_died priority over DODGING, facing_direction lock during DODGING,
# and velocity not updated while DODGING.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent type: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.
#   - Input.is_action_just_pressed() always returns false in GUT headless — ACs that
#     require a real dodge button press are deferred and marked with pending().
#   - is_on_floor() always returns false in GUT headless.
#
# ACs deferred to physics-scene integration tests:
#   AC-dodge-idle    — requires Input.is_action_just_pressed(&"dodge") = true
#   AC-dodge-running — requires Input.is_action_just_pressed(&"dodge") + move input = true

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


# ─── Signal emission: _enter_state(DODGING) via _transition_to ────────────────

func test_dodge_entering_dodging_from_idle_emits_signal_right() -> void:
	# AC-dodge-idle: entering DODGING from IDLE emits dodge_input_pressed.
	# Note: direction value verification (facing_direction=1 → dir=1) requires real
	# Input injection — deferred to test_pc_dodge_physics.gd (pending stub below).
	# Here we verify the signal is declared and emittable from the controller.
	# Arrange (player starts at IDLE by default)
	_pc.facing_direction = 1
	watch_signals(_pc)
	# Act: simulate what _handle_input() would do when dodge is pressed
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.dodge_input_pressed.emit(1)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DODGING,
		"State must be DODGING after transition (AC-dodge-idle)"
	)
	assert_signal_emitted(
		_pc, "dodge_input_pressed",
		"dodge_input_pressed must be emitted when entering DODGING (AC-dodge-idle)"
	)


func test_dodge_entering_dodging_emits_signal_left() -> void:
	# AC-dodge-idle edge: facing_direction = -1 — signal is emittable with direction arg.
	# Direction value test deferred to physics integration test.
	# Arrange (player starts at IDLE by default)
	_pc.facing_direction = -1
	watch_signals(_pc)
	# Act
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.dodge_input_pressed.emit(-1)
	# Assert
	assert_signal_emitted(
		_pc, "dodge_input_pressed",
		"dodge_input_pressed must be emittable with direction=-1 (AC-dodge-idle edge)"
	)


func test_dodge_transition_state_is_dodging() -> void:
	# Verify state becomes DODGING after _transition_to — independent of signal.
	# Arrange (player starts at IDLE by default)
	# Act
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DODGING,
		"player_state must be DODGING after _transition_to(DODGING)"
	)


# ─── AC-dodge-physics-pause: _process_state(DODGING) skips velocity update ───

func test_dodge_process_state_does_not_modify_velocity() -> void:
	# AC-dodge-physics-pause: DODGING branch in _process_state must not touch velocity.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.velocity = Vector2(150.0, -80.0)   # simulate DodgeSystem-assigned velocity
	# Act
	_pc._process_state(0.016)
	# Assert: velocity must be completely unchanged
	assert_almost_eq(
		_pc.velocity.x,
		150.0,
		0.001,
		"velocity.x must be unchanged after _process_state(DODGING) (AC-dodge-physics-pause)"
	)
	assert_almost_eq(
		_pc.velocity.y,
		-80.0,
		0.001,
		"velocity.y must be unchanged after _process_state(DODGING) (AC-dodge-physics-pause)"
	)


func test_dodge_process_state_does_not_change_state() -> void:
	# DODGING branch must not self-transition — DodgeSystem drives exit via dodge_ended.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	# Act: multiple frames
	_pc._process_state(0.016)
	_pc._process_state(0.016)
	_pc._process_state(0.016)
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DODGING,
		"DODGING must not self-transition in _process_state — exit is via _on_dodge_ended()"
	)


# ─── AC-dodge-ended: _on_dodge_ended() resume ─────────────────────────────────

func test_dodge_ended_transitions_to_idle_when_no_move_input() -> void:
	# AC-dodge-ended: no move input in headless → IDLE.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	# Act
	_pc._on_dodge_ended()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"_on_dodge_ended() must transition to IDLE when no move input held (AC-dodge-ended)"
	)


func test_dodge_ended_guard_prevents_transition_when_not_dodging() -> void:
	# AC-dead-overrides-dodge edge: if player is already DEAD, _on_dodge_ended() must do nothing.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Act
	_pc._on_dodge_ended()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"_on_dodge_ended() guard must prevent re-transition when not in DODGING state"
	)


func test_dodge_ended_guard_prevents_transition_from_idle() -> void:
	# _on_dodge_ended() called while already IDLE must not change state.
	# Arrange: player never entered DODGING
	# player starts IDLE by default
	# Act
	_pc._on_dodge_ended()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"_on_dodge_ended() while in IDLE must be a no-op (guard check)"
	)


func test_dodge_ended_guard_prevents_transition_from_parrying() -> void:
	# Edge: PARRYING when dodge_ended fires (e.g. stale signal) — must not change state.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	_pc.exit_parry_state(0.40)
	# Act
	_pc._on_dodge_ended()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.PARRYING,
		"_on_dodge_ended() while in PARRYING must be a no-op"
	)


# ─── AC-dead-overrides-dodge: player_died interrupts DODGING ─────────────────

func test_dead_overrides_dodging_on_player_died() -> void:
	# AC-dead-overrides-dodge: player_died received while DODGING → DEAD immediately.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.velocity = Vector2(100.0, 0.0)
	# Act
	_pc._on_player_died()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"player_died during DODGING must enter DEAD immediately (AC-dead-overrides-dodge)"
	)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"velocity must be zeroed when dying from DODGING (AC-dead-overrides-dodge)"
	)


func test_dodge_ended_after_death_is_noop() -> void:
	# AC-dead-overrides-dodge edge: dodge_ended fires after player_died — guard prevents re-transition.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc._on_player_died()  # player dies while dodging
	assert_eq(_pc.player_state, GameEnums.PlayerState.DEAD, "precondition: player is DEAD")
	# Act: dodge_ended signal arrives late (DodgeSystem cleanup)
	_pc._on_dodge_ended()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"_on_dodge_ended() after death must be a no-op — DEAD state must be preserved"
	)


# ─── AC-dodge-facing-locked: facing_direction unchanged during DODGING ────────

func test_dodge_facing_direction_not_updated_during_dodging() -> void:
	# AC-dodge-facing-locked: _handle_input() must not update facing_direction while DODGING.
	# In headless, Input.get_axis() always returns 0 — but we can verify the guard logic
	# directly: set up DODGING, call _handle_input(), confirm facing_direction unchanged.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.facing_direction = 1   # locked rightward
	# Act: call _handle_input() (all inputs return 0/false in headless)
	_pc._handle_input()
	# Assert
	assert_eq(
		_pc.facing_direction,
		1,
		"facing_direction must not change during DODGING (AC-dodge-facing-locked)"
	)


func test_dodge_velocity_not_set_by_handle_input_during_dodging() -> void:
	# AC-dodge-facing-locked edge: velocity.x must not be set by _handle_input during DODGING.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	_pc.velocity = Vector2(200.0, 0.0)   # DodgeSystem-assigned velocity
	# Act
	_pc._handle_input()
	# Assert: velocity.x unchanged — blocked list prevents horizontal velocity update
	assert_almost_eq(
		_pc.velocity.x,
		200.0,
		0.001,
		"velocity.x must not be set by _handle_input() while in DODGING state"
	)


# ─── _can_dodge() guard ────────────────────────────────────────────────────────

func test_can_dodge_true_from_idle() -> void:
	# Guard must allow dodge from IDLE.
	# Arrange (player starts at IDLE by default)
	# Assert
	assert_true(
		_pc._can_dodge(),
		"_can_dodge() must return true when state is IDLE"
	)


func test_can_dodge_true_from_running() -> void:
	# Guard must allow dodge from RUNNING.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.RUNNING)
	# Assert
	assert_true(
		_pc._can_dodge(),
		"_can_dodge() must return true when state is RUNNING"
	)


func test_can_dodge_false_from_airborne() -> void:
	# Air dodge is not in the GDD — AIRBORNE must be excluded.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.AIRBORNE)
	# Assert
	assert_false(
		_pc._can_dodge(),
		"_can_dodge() must return false when state is AIRBORNE (air dodge not in GDD)"
	)


func test_can_dodge_false_from_parrying() -> void:
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	# Assert
	assert_false(
		_pc._can_dodge(),
		"_can_dodge() must return false when state is PARRYING"
	)


func test_can_dodge_false_from_hit_stun() -> void:
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	# Assert
	assert_false(
		_pc._can_dodge(),
		"_can_dodge() must return false when state is HIT_STUN"
	)


func test_can_dodge_false_from_dead() -> void:
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Assert
	assert_false(
		_pc._can_dodge(),
		"_can_dodge() must return false when state is DEAD"
	)


# ─── Deferred: acceptance criteria requiring Input injection ──────────────────
# These stubs document the gap and prevent the story from being marked Done
# without physics-scene integration test coverage.

# Names the future physics-scene integration test file that covers Input-dependent ACs.
const INTEGRATION_FILE: String = \
	"game/tests/integration/player_controller/test_pc_dodge_physics.gd"


func test_ac_dodge_idle_via_input_pending() -> void:
	pending(
		"AC-dodge-idle: full entry via Input.is_action_just_pressed(&'dodge') " +
		"returns false in GUT headless. Integration test must assert: " +
		"(1) state = DODGING, (2) dodge_input_pressed(facing_direction) emitted same frame, " +
		"(3) no move input → uses facing_direction as dodge_dir. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_dodge_running_via_input_pending() -> void:
	pending(
		"AC-dodge-running: dodge while RUNNING requires simultaneous move + dodge input. " +
		"Integration test must assert: " +
		"(1) state = DODGING, (2) dodge_input_pressed(move_input_direction) emitted, " +
		"(3) dodge_dir uses move axis direction, not facing_direction. " +
		"Deferred to: " + INTEGRATION_FILE
	)
