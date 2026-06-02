# HitpauseManager unit tests — guard behavior only
#
# class_name intentionally omitted: headless GUT can conflict with
# class_name declarations in test files, causing false parse errors.
#
# AC-timing, AC-timer-verify, and AC-independence require a real SceneTree
# and must be verified at runtime (see Story 002 QA notes and ADR-0005).
# Those ACs are marked pending() below.
#
# Source: Story 002, ADR-0005

extends GutTest

const HitpauseManagerClass = preload("res://autoloads/hitpause_manager.gd")

var _sut: HitpauseManagerNode

func before_each() -> void:
	Engine.time_scale = 1.0
	_sut = HitpauseManagerClass.new()
	add_child(_sut)


func after_each() -> void:
	_sut._active = false      # ensure guard is clear before queue_free
	Engine.time_scale = 1.0   # guarantee time_scale is restored even on test failure
	_sut.queue_free()


# ---------------------------------------------------------------------------
# AC-reentrance — re-entrancy guard blocks nested calls
# ---------------------------------------------------------------------------

## When _active starts false, a single trigger_hitpause call sets _active = true.
## (Cannot await the full coroutine in unit tests; we verify flag state synchronously
## by checking that _active becomes true immediately after the call enters the function.)
func test_active_flag_is_false_on_init() -> void:
	assert_false(_sut._active, "_active must be false before any trigger_hitpause call")


## When _active is already true, trigger_hitpause must return immediately without
## setting Engine.time_scale to 0.0 (the guard fires before any state change).
func test_reentrance_guard_blocks_when_active() -> void:
	Engine.time_scale = 1.0
	_sut._active = true  # simulate an in-progress hitpause

	_sut.trigger_hitpause(0.080)

	assert_eq(Engine.time_scale, 1.0,
		"Engine.time_scale must remain 1.0 when guard blocks the nested call")
	assert_true(_sut._active,
		"_active must still be true after a blocked nested call")


## When _active is already true, trigger_hitpause with a different duration must
## also be blocked — guard is unconditional.
func test_reentrance_guard_blocks_any_duration_when_active() -> void:
	Engine.time_scale = 1.0
	_sut._active = true

	_sut.trigger_hitpause(0.030)   # shortest combo hitpause
	assert_eq(Engine.time_scale, 1.0,
		"Engine.time_scale must remain 1.0 regardless of duration when guard blocks")

	_sut.trigger_hitpause(0.500)   # long hitpause (simulates slow-motion call)
	assert_eq(Engine.time_scale, 1.0,
		"Engine.time_scale must remain 1.0 for long-duration blocked call")


## When _active is false, trigger_hitpause sets Engine.time_scale = 0.0 before
## the first await point — verifiable synchronously.
func test_time_scale_set_to_zero_on_trigger() -> void:
	assert_false(_sut._active)
	assert_eq(Engine.time_scale, 1.0)

	# trigger_hitpause is a coroutine; we do NOT await — we only check synchronous
	# state change that happens before the first `await timer.timeout`
	_sut.trigger_hitpause(999.0)   # long duration so we can inspect mid-hitpause state

	assert_eq(Engine.time_scale, 0.0,
		"Engine.time_scale must be 0.0 immediately after trigger_hitpause sets it")
	assert_true(_sut._active,
		"_active must be true once trigger_hitpause has started")

	# Cleanup: restore state manually since we didn't await completion
	_sut._active = false
	Engine.time_scale = 1.0


# ---------------------------------------------------------------------------
# AC-timing / AC-timer-verify / AC-independence — runtime only
# ---------------------------------------------------------------------------

## AC-timing: requires real-time measurement; cannot verify in headless unit test.
func test_ac_timing_requires_runtime_verification() -> void:
	pending("AC-timing: trigger_hitpause(0.060) must restore time_scale within " +
		"60ms +/- 16.6ms — verify manually at runtime per ADR-0005 and Story 002 QA notes.")


## AC-timer-verify: SceneTree.create_timer real-time behavior at time_scale=0 must
## be confirmed on target hardware.
func test_ac_timer_verify_requires_runtime() -> void:
	pending("AC-timer-verify: confirm create_timer(0.060, true, false, true) counts " +
		"real time at Engine.time_scale=0.0 — run the verification scene and log result.")


## AC-independence: SceneTree.paused + Engine.time_scale orthogonality requires
## real scene state to test reliably.
func test_ac_independence_requires_integration_scene() -> void:
	pending("AC-independence: set SceneTree.paused=true during active hitpause and " +
		"confirm Engine.time_scale is restored to 1.0 after timer fires — verify manually.")
