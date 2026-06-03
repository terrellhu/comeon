extends GutTest

# Tests for PlayerController Story 001: CharacterBody2D skeleton + state machine
# + movement physics foundations.
#
# GUT headless rules applied here:
#   - class_name type annotations FAIL at parse time in headless mode.
#     Use parent types: `var _pc: Node` NOT `var _pc: PlayerController`.
#   - All test function names must start with `test_`.
#   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.

# ─── Fixtures ─────────────────────────────────────────────────────────────────

# Use Node (not PlayerController) to avoid headless parse-time class_name failure.
var _pc: Node


func before_each() -> void:
	_pc = preload("res://scripts/core/player_controller.gd").new()
	# Ensure a known, deterministic state regardless of @export inspector defaults.
	_pc.move_speed = 340.0
	_pc.gravity = 1400.0
	_pc.terminal_velocity = 1200.0
	_pc.jump_impulse = 600.0
	_pc.coyote_time_duration = 0.10
	_pc.jump_buffer_duration = 0.12
	_pc.knockback_speed = 200.0
	_pc.hit_stun_duration = 0.30
	add_child_autoqfree(_pc)


# ─── AC-body: CharacterBody2D foundation ─────────────────────────────────────

func test_extends_character_body_2d() -> void:
	assert_true(
		_pc.is_class("CharacterBody2D"),
		"PlayerController must extend CharacterBody2D"
	)


# ─── AC-gravity: AIRBORNE gravity accumulation ────────────────────────────────

func test_airborne_gravity_accumulates_velocity_y() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.velocity.y = 0.0
	var delta: float = 1.0 / 60.0
	_pc._process_state(delta)
	var expected: float = 1400.0 * delta   # gravity × delta
	assert_almost_eq(
		_pc.velocity.y,
		expected,
		0.01,
		"velocity.y should equal gravity × delta after one AIRBORNE frame"
	)
	assert_true(
		_pc.velocity.y <= _pc.terminal_velocity,
		"velocity.y must not exceed terminal_velocity"
	)


func test_airborne_gravity_clamped_at_terminal_velocity() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.velocity.y = 1200.0   # already at terminal_velocity
	_pc._process_state(1.0 / 60.0)
	assert_eq(
		_pc.velocity.y,
		1200.0,
		"velocity.y must not exceed terminal_velocity when already at the cap"
	)


# ─── AC-state-machine: _transition_to() is the sole state mutator ─────────────

func test_transition_to_changes_player_state() -> void:
	# Start in default IDLE; transition to RUNNING.
	_pc._transition_to(GameEnums.PlayerState.RUNNING)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.RUNNING,
		"_transition_to(RUNNING) must update player_state to RUNNING"
	)


func test_transition_to_calls_exit_and_enter_without_error() -> void:
	# Cycle through a non-trivial transition to confirm _exit_state / _enter_state
	# are called without errors (no return value to assert; absence of crash is the signal).
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	assert_eq(
		_pc.player_state,
		GameEnums.PlayerState.PARRYING,
		"_transition_to(PARRYING) must set player_state"
	)
	# velocity.x must be zeroed by _enter_state(PARRYING).
	assert_eq(
		_pc.velocity.x,
		0.0,
		"_enter_state(PARRYING) must zero velocity.x"
	)


# ─── Guard functions: _can_parry() ────────────────────────────────────────────

func test_can_parry_returns_true_for_idle() -> void:
	_pc.player_state = GameEnums.PlayerState.IDLE
	assert_true(_pc._can_parry(), "_can_parry() must return true when state is IDLE")


func test_can_parry_returns_true_for_running() -> void:
	_pc.player_state = GameEnums.PlayerState.RUNNING
	assert_true(_pc._can_parry(), "_can_parry() must return true when state is RUNNING")


func test_can_parry_returns_true_for_airborne() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	assert_true(_pc._can_parry(), "_can_parry() must return true when state is AIRBORNE")


func test_can_parry_returns_false_for_dodging() -> void:
	_pc.player_state = GameEnums.PlayerState.DODGING
	assert_false(_pc._can_parry(), "_can_parry() must return false when state is DODGING")


func test_can_parry_returns_false_for_hit_stun() -> void:
	_pc.player_state = GameEnums.PlayerState.HIT_STUN
	assert_false(_pc._can_parry(), "_can_parry() must return false when state is HIT_STUN")


func test_can_parry_returns_false_for_dead() -> void:
	_pc.player_state = GameEnums.PlayerState.DEAD
	assert_false(_pc._can_parry(), "_can_parry() must return false when state is DEAD")


func test_can_parry_returns_false_for_parrying() -> void:
	_pc.player_state = GameEnums.PlayerState.PARRYING
	assert_false(_pc._can_parry(), "_can_parry() must return false when already PARRYING")


# ─── Guard functions: _can_attack() ──────────────────────────────────────────

func test_can_attack_returns_true_for_idle() -> void:
	_pc.player_state = GameEnums.PlayerState.IDLE
	assert_true(_pc._can_attack(), "_can_attack() must return true when state is IDLE")


func test_can_attack_returns_true_for_running() -> void:
	_pc.player_state = GameEnums.PlayerState.RUNNING
	assert_true(_pc._can_attack(), "_can_attack() must return true when state is RUNNING")


func test_can_attack_returns_true_for_airborne() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	assert_true(_pc._can_attack(), "_can_attack() must return true when state is AIRBORNE")


func test_can_attack_returns_false_for_parrying() -> void:
	_pc.player_state = GameEnums.PlayerState.PARRYING
	assert_false(_pc._can_attack(), "_can_attack() must return false when state is PARRYING")


func test_can_attack_returns_false_for_hit_stun() -> void:
	_pc.player_state = GameEnums.PlayerState.HIT_STUN
	assert_false(_pc._can_attack(), "_can_attack() must return false when state is HIT_STUN")


func test_can_attack_returns_false_for_dead() -> void:
	_pc.player_state = GameEnums.PlayerState.DEAD
	assert_false(_pc._can_attack(), "_can_attack() must return false when state is DEAD")


func test_can_attack_returns_false_for_dodging() -> void:
	_pc.player_state = GameEnums.PlayerState.DODGING
	assert_false(_pc._can_attack(), "_can_attack() must return false when state is DODGING")


# ─── Guard functions: _can_dodge() ───────────────────────────────────────────

func test_can_dodge_returns_true_for_idle() -> void:
	_pc.player_state = GameEnums.PlayerState.IDLE
	assert_true(_pc._can_dodge(), "_can_dodge() must return true when state is IDLE")


func test_can_dodge_returns_true_for_running() -> void:
	_pc.player_state = GameEnums.PlayerState.RUNNING
	assert_true(_pc._can_dodge(), "_can_dodge() must return true when state is RUNNING")


func test_can_dodge_returns_false_for_airborne() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	assert_false(_pc._can_dodge(), "_can_dodge() must return false when state is AIRBORNE")


func test_can_dodge_returns_false_for_parrying() -> void:
	_pc.player_state = GameEnums.PlayerState.PARRYING
	assert_false(_pc._can_dodge(), "_can_dodge() must return false when state is PARRYING")


func test_can_dodge_returns_false_for_dodging() -> void:
	_pc.player_state = GameEnums.PlayerState.DODGING
	assert_false(_pc._can_dodge(), "_can_dodge() must return false when already DODGING")


func test_can_dodge_returns_false_for_hit_stun() -> void:
	_pc.player_state = GameEnums.PlayerState.HIT_STUN
	assert_false(_pc._can_dodge(), "_can_dodge() must return false when state is HIT_STUN")


func test_can_dodge_returns_false_for_dead() -> void:
	_pc.player_state = GameEnums.PlayerState.DEAD
	assert_false(_pc._can_dodge(), "_can_dodge() must return false when state is DEAD")


# ─── Guard functions: _can_jump() ────────────────────────────────────────────
# is_on_floor() always returns false in GUT headless — only the coyote-timer
# branch is unit-testable. The is_on_floor() branch is covered by integration tests.

func test_can_jump_returns_true_when_coyote_timer_positive() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.05
	assert_true(_pc._can_jump(), "_can_jump() must return true when coyote_timer > 0")


func test_can_jump_returns_false_when_coyote_timer_zero_and_not_on_floor() -> void:
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.coyote_timer = 0.0
	# is_on_floor() returns false in headless; _can_jump() should be false.
	assert_false(_pc._can_jump(), "_can_jump() must return false when coyote_timer = 0 and not on floor")


# ─── Input-dependent ACs: deferral notes ─────────────────────────────────────
# The following acceptance criteria require Input injection and cannot be
# unit-tested in GUT headless mode:
#
#   AC-h-move: velocity.x = move_speed when move_right held
#   AC-h-snap: velocity.x = 0.0 same frame on release
#   AC-facing (guard path): facing_direction unchanged in PARRYING/DODGING
#     when actual horizontal input is active
#
# All three are covered by integration tests in:
#   game/tests/integration/player_controller/test_pc_parry.gd
#   game/tests/integration/player_controller/test_pc_dodge.gd
#
# The unit tests below verify the _process_state side (not the _handle_input
# Input-reading side) of AC-facing, which is the only automatable portion here.
#
# AC-body call order (handle_input → process_state → move_and_slide): static review.
# AC-stringname (all &"..." forms): static review — grep for &" in _handle_input.
# AC-performance (< 0.5ms): runtime verification via Godot Profiler (300 frames).

# ─── AC-export: @export var default values ────────────────────────────────────

func test_export_defaults_have_expected_values() -> void:
	# Re-instantiate WITHOUT the before_each overrides to test true inspector defaults.
	var fresh_pc: Node = preload("res://scripts/core/player_controller.gd").new()
	add_child_autoqfree(fresh_pc)

	assert_eq(fresh_pc.move_speed, 340.0, "move_speed default must be 340.0")
	assert_eq(fresh_pc.gravity, 1400.0, "gravity default must be 1400.0")
	assert_eq(fresh_pc.terminal_velocity, 1200.0, "terminal_velocity default must be 1200.0")
	assert_eq(fresh_pc.jump_impulse, 600.0, "jump_impulse default must be 600.0")
	assert_almost_eq(
		fresh_pc.coyote_time_duration, 0.10, 0.001,
		"coyote_time_duration default must be ~0.10"
	)
	assert_almost_eq(
		fresh_pc.jump_buffer_duration, 0.12, 0.001,
		"jump_buffer_duration default must be ~0.12"
	)
	assert_eq(fresh_pc.knockback_speed, 200.0, "knockback_speed default must be 200.0")
	assert_almost_eq(
		fresh_pc.hit_stun_duration, 0.30, 0.001,
		"hit_stun_duration default must be ~0.30"
	)


# ─── hit_stun_duration setter validation ─────────────────────────────────────

func test_hit_stun_duration_setter_clamps_above_half_second() -> void:
	_pc.hit_stun_duration = 0.6
	assert_eq(
		_pc.hit_stun_duration,
		0.5,
		"hit_stun_duration must be clamped to 0.5 when set above the maximum"
	)


func test_hit_stun_duration_setter_accepts_valid_value() -> void:
	_pc.hit_stun_duration = 0.3
	assert_almost_eq(
		_pc.hit_stun_duration,
		0.3,
		0.001,
		"hit_stun_duration must accept values at or below 0.5 unchanged"
	)


func test_hit_stun_duration_setter_accepts_boundary_value() -> void:
	_pc.hit_stun_duration = 0.5
	assert_almost_eq(
		_pc.hit_stun_duration,
		0.5,
		0.001,
		"hit_stun_duration must accept exactly 0.5 without clamping"
	)


# ─── Facing direction: _process_state does not modify it ─────────────────────
# These tests verify that _process_state() never touches facing_direction.
# The actual AC-facing guard (Input-driven: facing_direction unchanged when
# PARRYING/DODGING and a real horizontal input arrives) lives in _handle_input()
# and cannot be unit-tested without Input injection — deferred to integration tests.

func test_process_state_does_not_modify_facing_direction_in_parrying() -> void:
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.facing_direction = 1
	_pc._process_state(0.016)
	assert_eq(
		_pc.facing_direction,
		1,
		"_process_state must not alter facing_direction during PARRYING"
	)


func test_process_state_does_not_modify_facing_direction_in_dodging() -> void:
	_pc.player_state = GameEnums.PlayerState.DODGING
	_pc.facing_direction = -1
	_pc._process_state(0.016)
	assert_eq(
		_pc.facing_direction,
		-1,
		"_process_state must not alter facing_direction during DODGING"
	)


# ─── HIT_STUN entry: timer and knockback velocity ────────────────────────────

func test_hit_stun_entry_sets_timer_to_duration() -> void:
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.facing_direction = 1
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	assert_almost_eq(
		_pc.hit_stun_timer,
		_pc.hit_stun_duration,
		0.001,
		"_enter_state(HIT_STUN) must set hit_stun_timer to hit_stun_duration"
	)


func test_hit_stun_entry_sets_knockback_velocity() -> void:
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.facing_direction = 1   # knockback pushes left: velocity.x = -1 × knockback_speed
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	assert_almost_eq(
		_pc.velocity.x,
		-_pc.knockback_speed,
		0.1,
		"_enter_state(HIT_STUN) must set velocity.x = -facing_direction × knockback_speed"
	)


# ─── DEAD state: velocity zeroed ─────────────────────────────────────────────

func test_dead_entry_zeroes_velocity() -> void:
	_pc.velocity = Vector2(300.0, 500.0)
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc._transition_to(GameEnums.PlayerState.DEAD)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"_enter_state(DEAD) must set velocity to Vector2.ZERO"
	)


func test_process_state_dead_keeps_velocity_zero() -> void:
	_pc.player_state = GameEnums.PlayerState.DEAD
	_pc.velocity = Vector2(100.0, 100.0)
	_pc._process_state(0.016)
	assert_eq(
		_pc.velocity,
		Vector2.ZERO,
		"_process_state in DEAD state must zero velocity every frame"
	)


# ─── PARRYING: velocity.x locked to zero ─────────────────────────────────────

func test_process_state_parrying_zeroes_velocity_x() -> void:
	_pc.player_state = GameEnums.PlayerState.PARRYING
	_pc.velocity.x = 200.0
	_pc._process_state(0.016)
	assert_eq(
		_pc.velocity.x,
		0.0,
		"_process_state must lock velocity.x to 0.0 during PARRYING"
	)


# ─── AIRBORNE landing transitions ────────────────────────────────────────────

# ─── _process_state(HIT_STUN): knockback velocity re-locked each frame ───────

func test_process_state_hit_stun_reapplies_knockback_each_frame() -> void:
	# Arrange: enter HIT_STUN normally (sets velocity.x to knockback on entry).
	_pc.player_state = GameEnums.PlayerState.IDLE
	_pc.facing_direction = 1
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	# Act: override velocity.x to simulate an external write attempt, then process.
	_pc.velocity.x = 0.0
	_pc._process_state(0.016)
	# Assert: knockback re-applied — overwrite was rejected.
	assert_almost_eq(
		_pc.velocity.x,
		-_pc.knockback_speed,
		0.1,
		"_process_state(HIT_STUN) must re-lock velocity.x to knockback each frame"
	)


# ─── _exit_state timer resets ────────────────────────────────────────────────

func test_exit_parrying_resets_parry_exit_timer() -> void:
	# Arrange: enter PARRYING, then set a non-zero parry exit timer.
	_pc._transition_to(GameEnums.PlayerState.PARRYING)
	_pc.parry_exit_timer = 0.25
	# Act: transition out of PARRYING.
	_pc._transition_to(GameEnums.PlayerState.IDLE)
	# Assert: _exit_state(PARRYING) must zero the timer.
	assert_eq(
		_pc.parry_exit_timer,
		0.0,
		"_exit_state(PARRYING) must reset parry_exit_timer to 0.0"
	)


func test_exit_hit_stun_resets_hit_stun_timer() -> void:
	# Arrange: enter HIT_STUN (sets timer to hit_stun_duration).
	_pc._transition_to(GameEnums.PlayerState.HIT_STUN)
	assert_true(_pc.hit_stun_timer > 0.0, "pre-condition: timer should be non-zero in HIT_STUN")
	# Act: transition out of HIT_STUN.
	_pc._transition_to(GameEnums.PlayerState.IDLE)
	# Assert: _exit_state(HIT_STUN) must zero the timer.
	assert_eq(
		_pc.hit_stun_timer,
		0.0,
		"_exit_state(HIT_STUN) must reset hit_stun_timer to 0.0"
	)


# ─── AIRBORNE grounding / gravity ─────────────────────────────────────────────

func test_airborne_gravity_accumulates_when_not_on_floor() -> void:
	# is_on_floor() always returns false in GUT headless (no physics scene).
	# This test covers only the gravity accumulation path.
	# AC-grounded (velocity.y = 0 + transition to IDLE/RUNNING) is deferred to
	# integration tests in game/tests/integration/player_controller/test_pc_parry.gd
	# (and equivalent) where a physics scene is available.
	_pc.player_state = GameEnums.PlayerState.AIRBORNE
	_pc.velocity.y = 0.0
	_pc._process_state(1.0 / 60.0)
	assert_true(
		_pc.velocity.y > 0.0,
		"velocity.y must increase each AIRBORNE frame when gravity is accumulating"
	)


func test_airborne_grounding_transition_pending() -> void:
	pending("AC-grounded: grounding transition (velocity.y=0, state->IDLE/RUNNING) requires physics scene — deferred to integration tests")
