extends GutTest

# Integration tests for PlayerController Story 006: Attack Input Forwarding + Retry Reset.
# Covers: attack_input_pressed emission from allowed states (IDLE/RUNNING/AIRBORNE),
# attack blocked from PARRYING/DODGING/HIT_STUN/DEAD, no state change on attack,
# reset_for_retry() full variable reset, and retry-no-invuln contract.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent type: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.
#   - Input.is_action_just_pressed() always returns false in GUT headless — attack signal
#     emission tests use watch_signals + direct emit to verify the signal contract.
#   - is_on_floor() always returns false in GUT headless.
#
# ACs deferred to physics-scene integration tests:
#   AC-attack-idle    — requires Input.is_action_just_pressed(&"attack") = true
#   AC-attack-running — requires Input.is_action_just_pressed(&"attack") + move input
#   AC-attack-airborne — requires Input.is_action_just_pressed(&"attack") in AIRBORNE

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


# ─── _can_attack() guard: allowed states ──────────────────────────────────────

func test_can_attack_true_from_idle() -> void:
	# _can_attack() must return true from IDLE.
	# Arrange: player starts IDLE by default
	# Assert
	assert_true(
		_pc._can_attack(),
		"_can_attack() must return true when state is IDLE (AC-attack-idle)"
	)


func test_can_attack_true_from_running() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.RUNNING
	# Assert
	assert_true(
		_pc._can_attack(),
		"_can_attack() must return true when state is RUNNING (AC-attack-running)"
	)


func test_can_attack_true_from_airborne() -> void:
	# Arrange
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	# Assert
	assert_true(
		_pc._can_attack(),
		"_can_attack() must return true when state is AIRBORNE (AC-attack-airborne)"
	)


# ─── _can_attack() guard: blocked states ──────────────────────────────────────

func test_can_attack_false_from_parrying() -> void:
	# AC-attack-blocked-parrying: attack must not fire while PARRYING.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	# Assert
	assert_false(
		_pc._can_attack(),
		"_can_attack() must return false when state is PARRYING (AC-attack-blocked-parrying)"
	)


func test_can_attack_false_from_dodging() -> void:
	# AC-attack-blocked-dodging: attack must not fire while DODGING.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.DODGING
	# Assert
	assert_false(
		_pc._can_attack(),
		"_can_attack() must return false when state is DODGING (AC-attack-blocked-dodging)"
	)


func test_can_attack_false_from_hit_stun() -> void:
	# AC-attack-blocked-hit-stun: attack must not fire while HIT_STUN.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	# Assert
	assert_false(
		_pc._can_attack(),
		"_can_attack() must return false when state is HIT_STUN (AC-attack-blocked-hit-stun)"
	)


func test_can_attack_false_from_dead() -> void:
	# AC-attack-blocked-dead: DEAD is also excluded from _can_attack() for self-documentation.
	# (DEAD already hits the early return in _handle_input() before _can_attack() is checked.)
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Assert
	assert_false(
		_pc._can_attack(),
		"_can_attack() must return false when state is DEAD (AC-attack-blocked-dead)"
	)


# ─── AC-attack-blocked: handle_input() + watch_signals: no emission in blocked states ──

func test_attack_no_signal_in_parrying_via_handle_input() -> void:
	# Headless: Input.is_action_just_pressed always false — handle_input() never fires attack.
	# Verify that even if it ran, the guard prevents emission. Test by calling handle_input()
	# directly and confirming attack_input_pressed is NOT emitted.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.PARRYING
	watch_signals(_pc)
	# Act
	_pc._handle_input()
	# Assert
	assert_signal_not_emitted(
		_pc, "attack_input_pressed",
		"attack_input_pressed must NOT be emitted while in PARRYING (AC-attack-blocked-parrying)"
	)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.PARRYING,
		"State must remain PARRYING after _handle_input() with no input (AC-attack-blocked)"
	)


func test_attack_no_signal_in_dodging_via_handle_input() -> void:
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DODGING)
	watch_signals(_pc)
	# Act
	_pc._handle_input()
	# Assert
	assert_signal_not_emitted(
		_pc, "attack_input_pressed",
		"attack_input_pressed must NOT be emitted while in DODGING (AC-attack-blocked-dodging)"
	)


func test_attack_no_signal_in_dead_via_handle_input() -> void:
	# DEAD early-return in _handle_input() prevents ALL processing including attack.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	watch_signals(_pc)
	# Act
	_pc._handle_input()
	# Assert
	assert_signal_not_emitted(
		_pc, "attack_input_pressed",
		"attack_input_pressed must NOT be emitted while in DEAD (AC-attack-blocked-dead)"
	)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.DEAD,
		"State must remain DEAD after _handle_input() in DEAD state"
	)


func test_attack_no_signal_in_hit_stun_via_handle_input() -> void:
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	watch_signals(_pc)
	# Act
	_pc._handle_input()
	# Assert
	assert_signal_not_emitted(
		_pc, "attack_input_pressed",
		"attack_input_pressed must NOT be emitted while in HIT_STUN (AC-attack-blocked-hit-stun)"
	)


# ─── Attack signal contract: direct emit verification ─────────────────────────

func test_attack_signal_exists_and_is_emittable() -> void:
	# Verify attack_input_pressed signal is declared on PlayerController and can be emitted.
	# This confirms the signal declaration is present and the emit() path works.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.IDLE
	watch_signals(_pc)
	# Act: direct emit simulates what _handle_input() would do on a real attack keypress
	_pc.attack_input_pressed.emit()
	# Assert
	assert_signal_emitted(
		_pc, "attack_input_pressed",
		"attack_input_pressed signal must be declared and emittable from IDLE"
	)


func test_attack_signal_no_state_change() -> void:
	# AC-attack-idle: attack must NOT cause a state change.
	# Emit directly and confirm state is unchanged — state machine must not react to attack.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.velocity.x = 0.0
	watch_signals(_pc)
	# Act
	_pc.attack_input_pressed.emit()
	# Assert: state and velocity both unchanged
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"attack_input_pressed emission must NOT change player_state (AC-attack-idle)"
	)
	assert_almost_eq(
		_pc.velocity.x,
		0.0,
		0.001,
		"attack_input_pressed emission must NOT modify velocity (AC-attack-idle)"
	)


func test_attack_signal_no_state_change_from_running() -> void:
	# AC-attack-running: attack from RUNNING must preserve state and velocity.x.
	# Arrange
	_pc.player_state = GameEnums.PlayerState.RUNNING
	_pc.velocity.x = 340.0   # move_speed
	watch_signals(_pc)
	# Act
	_pc.attack_input_pressed.emit()
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.RUNNING,
		"attack must not change state from RUNNING (AC-attack-running)"
	)
	assert_almost_eq(
		_pc.velocity.x,
		340.0,
		0.001,
		"velocity.x must remain move_speed after attack from RUNNING (AC-attack-running)"
	)


# ─── AC-retry-reset: full variable reset ──────────────────────────────────────

func test_retry_reset_restores_idle_state() -> void:
	# AC-retry-reset: player_state must be IDLE after reset.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"reset_for_retry() must set player_state to IDLE (AC-retry-reset)"
	)


func test_retry_reset_zeroes_velocity() -> void:
	# AC-retry-reset: velocity must be Vector2.ZERO.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.velocity = Vector2(150.0, -200.0)
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"reset_for_retry() must set velocity = Vector2.ZERO (AC-retry-reset)"
	)


func test_retry_reset_restores_spawn_position() -> void:
	# AC-retry-reset: position must be restored to spawn_position.
	# Arrange: set a specific spawn_position and a different current position.
	_pc.spawn_position = Vector2(0.0, 0.0)
	_pc.position = Vector2(300.0, 100.0)
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_eq(
		_pc.position,
		Vector2(0.0, 0.0),
		"reset_for_retry() must restore position to spawn_position (AC-retry-reset)"
	)


func test_retry_reset_restores_facing_direction() -> void:
	# AC-retry-reset: facing_direction must reset to 1 (right).
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.facing_direction = -1
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_eq(
		_pc.facing_direction,
		1,
		"reset_for_retry() must set facing_direction to 1 (AC-retry-reset)"
	)


func test_retry_reset_zeroes_coyote_timer() -> void:
	# AC-retry-reset: coyote_timer must be 0.0.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.coyote_timer = 0.08
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_almost_eq(
		_pc.coyote_timer,
		0.0,
		0.001,
		"reset_for_retry() must set coyote_timer to 0.0 (AC-retry-reset)"
	)


func test_retry_reset_zeroes_jump_buffer_timer() -> void:
	# AC-retry-reset: jump_buffer_timer must be 0.0.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.jump_buffer_timer = 0.10
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_almost_eq(
		_pc.jump_buffer_timer,
		0.0,
		0.001,
		"reset_for_retry() must set jump_buffer_timer to 0.0 (AC-retry-reset)"
	)


func test_retry_reset_zeroes_hit_stun_timer() -> void:
	# AC-retry-reset: hit_stun_timer must be 0.0.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.hit_stun_timer = 0.20
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_almost_eq(
		_pc.hit_stun_timer,
		0.0,
		0.001,
		"reset_for_retry() must set hit_stun_timer to 0.0 (AC-retry-reset)"
	)


func test_retry_reset_zeroes_parry_exit_timer() -> void:
	# AC-retry-reset: parry_exit_timer must be 0.0.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.parry_exit_timer = 0.30
	# Act
	_pc.reset_for_retry({})
	# Assert
	assert_almost_eq(
		_pc.parry_exit_timer,
		0.0,
		0.001,
		"reset_for_retry() must set parry_exit_timer to 0.0 (AC-retry-reset)"
	)


func test_retry_reset_full_dirty_state() -> void:
	# AC-retry-reset combined: all dirty values reset in one call — matches story QA case exactly.
	# Arrange: dirty state
	_pc.spawn_position = Vector2(0.0, 0.0)
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	_pc.velocity = Vector2(150.0, -200.0)
	_pc.position = Vector2(300.0, 0.0)
	_pc.facing_direction = -1
	_pc.coyote_timer = 0.08
	_pc.jump_buffer_timer = 0.10
	_pc.hit_stun_timer = 0.20
	_pc.parry_exit_timer = 0.30
	# Act
	_pc.reset_for_retry({})
	# Assert all in one block
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"player_state must be IDLE after full dirty reset"
	)
	assert_eq(_pc.velocity, Vector2.ZERO, "velocity must be Vector2.ZERO after reset")
	assert_eq(_pc.position, Vector2(0.0, 0.0), "position must be spawn_position after reset")
	assert_eq(_pc.facing_direction, 1, "facing_direction must be 1 after reset")
	assert_almost_eq(_pc.coyote_timer, 0.0, 0.001, "coyote_timer must be 0.0 after reset")
	assert_almost_eq(_pc.jump_buffer_timer, 0.0, 0.001, "jump_buffer_timer must be 0.0 after reset")
	assert_almost_eq(_pc.hit_stun_timer, 0.0, 0.001, "hit_stun_timer must be 0.0 after reset")
	assert_almost_eq(_pc.parry_exit_timer, 0.0, 0.001, "parry_exit_timer must be 0.0 after reset")


# ─── AC-retry-no-invuln: PlayerController must not set any invuln timer ───────

func test_retry_reset_does_not_set_invuln_timer() -> void:
	# AC-retry-no-invuln: PlayerController has no invuln field — InstantRetrySystem owns invuln.
	# Verify reset_for_retry() completes without introducing any invuln-like timer field.
	# Arrange
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	# Act
	_pc.reset_for_retry({})
	# Assert: state is IDLE, no new timer fields beyond the documented ones
	# (this test documents the contract; if an invuln field is ever added, update it)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.IDLE,
		"AC-retry-no-invuln: state is IDLE post-reset; no invuln handling in PlayerController"
	)
	assert_almost_eq(
		_pc.coyote_timer,
		0.0,
		0.001,
		"AC-retry-no-invuln: coyote_timer is 0.0 — no invuln timer shares this field"
	)


# ─── Deferred: acceptance criteria requiring Input injection ──────────────────
# These stubs document the gap and prevent the story from being marked Done
# without physics-scene integration test coverage.

# Names the future physics-scene integration test file that covers Input-dependent ACs.
const INTEGRATION_FILE: String = \
	"game/tests/integration/player_controller/test_pc_attack_retry_physics.gd"


func test_ac_attack_idle_via_input_pending() -> void:
	pending(
		"AC-attack-idle: full emission via Input.is_action_just_pressed(&'attack') " +
		"returns false in GUT headless. Integration test must assert: " +
		"(1) attack_input_pressed emitted exactly once per press, " +
		"(2) player_state stays IDLE, (3) velocity unchanged. " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_attack_running_preserves_velocity_via_input_pending() -> void:
	pending(
		"AC-attack-running: attack + move same frame requires real Input. " +
		"Integration test must assert: " +
		"(1) attack_input_pressed emitted, (2) velocity.x = move_speed (unchanged). " +
		"Deferred to: " + INTEGRATION_FILE
	)


func test_ac_attack_airborne_via_input_pending() -> void:
	pending(
		"AC-attack-airborne: attack while AIRBORNE requires real Input. " +
		"Integration test must assert: " +
		"(1) attack_input_pressed emitted, (2) state stays AIRBORNE, " +
		"(3) velocity.y continues accumulating gravity next frame. " +
		"Deferred to: " + INTEGRATION_FILE
	)
