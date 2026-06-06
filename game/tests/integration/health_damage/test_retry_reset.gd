extends GutTest

## Integration tests for HealthDamageSystem — Story 007: Retry Reset Contract.
##
## Covers TR-HDS-007 (reset_for_retry contract), ADR-0003 (retry reset protocol),
## and the full integration path through RetryContext (AC-5).
##
## GUT headless rules applied here:
##   - class_name type annotations FAIL at parse time in headless mode.
##     Use parent type: `var _system: Node` NOT `var _system: HealthDamageSystem`.
##   - Autoloads are NOT auto-registered in GUT headless mode.
##     RetryContextNode is instantiated and added as a child manually.
##   - All test function names must start with `test_`.
##   - File must be named `test_*.gd` (prefix). GUT silently skips suffix-named files.

# ---------------------------------------------------------------------------
# Preloads — explicit paths; no class_name reliance (headless-safe)
# ---------------------------------------------------------------------------

const HealthDamageSystemClass = preload("res://scripts/core/health_damage_system.gd")
const BossDataClass = preload("res://scripts/data/boss_data.gd")
const PhaseDataClass = preload("res://scripts/data/phase_data.gd")
const AttackDataClass = preload("res://scripts/data/attack_data.gd")
const GameEnumsClass = preload("res://scripts/data/game_enums.gd")
const MockEventBusClass = preload("res://tests/helpers/mock_event_bus.gd")
const RetryContextClass = preload("res://autoloads/retry_context.gd")

# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

## HealthDamageSystem under test — typed as Node (class_name unsafe in headless).
var _system: Node

## MockEventBus injected via initialize() — isolates from global Autoload.
var _mock_bus: Node

## RetryContextNode instance — manually added because Autoloads are not
## auto-registered in GUT headless mode.
var _retry_ctx: Node

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	_mock_bus = MockEventBusClass.new()
	add_child_autofree(_mock_bus)

	_retry_ctx = RetryContextClass.new()
	_retry_ctx.name = "RetryContext"
	add_child_autofree(_retry_ctx)

	_system = HealthDamageSystemClass.new()
	_system.initialize(_mock_bus)
	add_child_autofree(_system)
	_system.init_battle(_make_test_boss())

# ---------------------------------------------------------------------------
# Factory helper — consistent with ADR-0002 _make_test_boss() pattern
# ---------------------------------------------------------------------------

## Returns a BossData with boss_max_hp=1000.0 and phase_threshold_pct=[0.6, 0.3].
## Two phases: threshold 0 at 60% HP, threshold 1 at 30% HP.
## Constructed entirely in code — no filesystem I/O.
## Return type is Resource (not BossData) to avoid class_name resolution at parse time in headless mode.
func _make_test_boss() -> Resource:
	var attack := AttackDataClass.new()
	attack.attack_type = GameEnumsClass.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = 0.0

	var phase := PhaseDataClass.new()
	phase.phase_index = 0
	phase.attack_sequence = [attack] as Array[AttackData]
	phase.idle_duration_after_attack = 0.5

	var boss := BossDataClass.new()
	boss.boss_id = &"test_boss"
	boss.boss_max_hp = 1000.0
	boss.phase_threshold_pct = [0.6, 0.3] as Array[float]
	boss.phases = [phase] as Array[PhaseData]
	return boss

# ---------------------------------------------------------------------------
# AC-1 (partial): reset_for_retry restores player HP to max
# ---------------------------------------------------------------------------

func test_reset_restores_player_hp_to_max() -> void:
	# AC-1: After reset, current_player_hp must equal player_max_hp.
	# Arrange — deal lethal damage so player HP is 0
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 100.0)
	assert_almost_eq(_system.current_player_hp, 0.0, 0.001,
		"Precondition: player must be dead before reset")

	var ctx: Dictionary = {"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)

	# Assert
	assert_almost_eq(
		_system.current_player_hp,
		_system.player_max_hp,
		0.001,
		"reset_for_retry() must restore current_player_hp to player_max_hp (AC-1)"
	)

# ---------------------------------------------------------------------------
# AC-1: reset_for_retry preserves boss HP from context
# ---------------------------------------------------------------------------

func test_reset_preserves_boss_hp_from_context() -> void:
	# AC-1: current_boss_hp must equal ctx["boss_hp"] = 750.0 after reset.
	# Arrange — reduce boss HP to a mid-fight value
	_system.apply_damage(GameEnumsClass.Target.BOSS, 250.0)
	# boss HP is now 750.0 (1000 - 250)

	var ctx: Dictionary = {"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)

	# Assert
	assert_almost_eq(
		_system.current_boss_hp,
		750.0,
		0.001,
		"reset_for_retry() must set current_boss_hp to ctx['boss_hp'] = 750.0 (AC-1)"
	)

# ---------------------------------------------------------------------------
# AC-1 (negative): boss HP must NOT be reset to boss_max_hp
# ---------------------------------------------------------------------------

func test_reset_does_not_reset_boss_hp_to_max() -> void:
	# AC-1 negative: current_boss_hp must be 750.0, not boss_max_hp (1000.0), after reset.
	# Arrange
	_system.apply_damage(GameEnumsClass.Target.BOSS, 250.0)
	var ctx: Dictionary = {"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)

	# Assert
	assert_ne(
		_system.current_boss_hp,
		_system.boss_max_hp,
		"reset_for_retry() must NOT reset current_boss_hp to boss_max_hp (AC-1 negative)"
	)

# ---------------------------------------------------------------------------
# AC-2: reset_for_retry clears the invulnerability timer
# ---------------------------------------------------------------------------

func test_reset_clears_invuln_timer() -> void:
	# AC-2: _invuln_timer must be 0.0 after reset, even if it was active at death.
	# Arrange — deal non-lethal damage to trigger the invuln window
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 30.0)
	# Invuln timer is now > 0.0 (player_hit_invuln_duration = 0.5)
	assert_true(
		_system.get_invuln_timer() > 0.0,
		"Precondition: invuln timer must be active after a hit"
	)

	var ctx: Dictionary = {"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)

	# Assert
	assert_almost_eq(
		_system.get_invuln_timer(),
		0.0,
		0.001,
		"reset_for_retry() must clear _invuln_timer to 0.0 (AC-2)"
	)

# ---------------------------------------------------------------------------
# AC-3: reset_for_retry preserves entered_phases (no re-emission on retry)
# ---------------------------------------------------------------------------

func test_reset_preserves_entered_phases() -> void:
	# AC-3: After reset, a small Boss damage call must NOT re-emit boss_phase_changed
	# for thresholds already crossed before the reset.
	#
	# Arrange — cross Phase 1 threshold (60% = 600 HP; deal 450 from full 1000)
	_system.apply_damage(GameEnumsClass.Target.BOSS, 450.0)
	# Boss HP is now 550 (55% — below 60% threshold; Phase 2 entered)
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		1,
		"Precondition: boss_phase_changed must have fired once for Phase 2 entry"
	)

	var ctx: Dictionary = {"boss_hp": 550.0, "boss_phase": 2, "death_count": 1}

	# Reset counters so we can observe post-reset emissions only
	_mock_bus.boss_phase_changed_call_count = 0
	_mock_bus.boss_phase_changed_history.clear()

	# Act — reset then apply a small hit (must not re-trigger Phase 2 transition)
	_system.reset_for_retry(ctx)
	_system.apply_damage(GameEnumsClass.Target.BOSS, 10.0)

	# Assert — no phase change re-emitted; entered_phases guard is still active
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		0,
		"boss_phase_changed must NOT re-emit after reset_for_retry when threshold was already crossed (AC-3)"
	)

# ---------------------------------------------------------------------------
# AC-4: reset_for_retry clears _is_boss_defeated
# ---------------------------------------------------------------------------

func test_reset_clears_is_boss_defeated_flag() -> void:
	# AC-4: After reset, apply_damage(BOSS, ...) must reduce current_boss_hp,
	# proving that _is_boss_defeated was cleared and the no-op guard is inactive.
	#
	# Arrange — defeat the boss completely
	_system.apply_damage(GameEnumsClass.Target.BOSS, 1000.0)
	assert_eq(
		_mock_bus.boss_defeated_call_count,
		1,
		"Precondition: boss must be defeated before reset"
	)
	assert_almost_eq(_system.current_boss_hp, 0.0, 0.001,
		"Precondition: boss HP must be 0 after defeat")

	# Reset boss HP context to a non-zero value so we can detect further deduction
	var ctx: Dictionary = {"boss_hp": 500.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)
	_mock_bus.boss_hp_changed_call_count = 0
	_mock_bus.boss_defeated_call_count = 0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 10.0)

	# Assert — damage applied means _is_boss_defeated was false after reset
	assert_almost_eq(
		_system.current_boss_hp,
		490.0,
		0.001,
		"apply_damage(BOSS, 10) must reduce boss HP after reset_for_retry clears _is_boss_defeated (AC-4)"
	)

# ---------------------------------------------------------------------------
# AC-4 (normal flow): reset_for_retry does not flip _is_boss_defeated when boss was alive at death
# ---------------------------------------------------------------------------

func test_reset_is_boss_defeated_stays_false_when_boss_was_alive() -> void:
	# AC-4 normal flow: when player dies but Boss is still alive (_is_boss_defeated = false),
	# reset_for_retry must leave the defeat flag false — Boss must still take damage afterward.
	#
	# Arrange — deal non-lethal boss damage and lethal player damage
	_system.apply_damage(GameEnumsClass.Target.BOSS, 250.0)
	# boss HP = 750, _is_boss_defeated = false
	assert_eq(_mock_bus.boss_defeated_call_count, 0,
		"Precondition: boss must NOT be defeated")
	var ctx: Dictionary = {"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)
	_mock_bus.boss_hp_changed_call_count = 0

	# Assert — Boss still takes damage, proving _is_boss_defeated was false and was not accidentally set
	_system.apply_damage(GameEnumsClass.Target.BOSS, 10.0)
	assert_almost_eq(
		_system.current_boss_hp,
		740.0,
		0.001,
		"apply_damage(BOSS, 10) must deduct HP when boss was alive at death — _is_boss_defeated must stay false (AC-4 normal flow)"
	)
	assert_eq(
		_mock_bus.boss_hp_changed_call_count,
		1,
		"boss_hp_changed must be emitted once — confirms damage was not blocked by defeat guard (AC-4 normal flow)"
	)

# ---------------------------------------------------------------------------
# Edge case: ctx["boss_hp"] = 0.0 (boundary — boss was at death blow on player death)
# ---------------------------------------------------------------------------

func test_reset_boss_hp_zero_in_context() -> void:
	# Edge case: ctx["boss_hp"] = 0.0 is a valid (if unusual) boundary value.
	# The system must accept it and not clamp or modify it.
	# Arrange
	assert_almost_eq(_system.current_boss_hp, 1000.0, 0.001,
		"Precondition: boss HP must be at full before reset")
	var ctx: Dictionary = {"boss_hp": 0.0, "boss_phase": 1, "death_count": 1}

	# Act
	_system.reset_for_retry(ctx)

	# Assert
	assert_almost_eq(
		_system.current_boss_hp,
		0.0,
		0.001,
		"reset_for_retry() must set current_boss_hp to 0.0 when ctx['boss_hp'] = 0.0 (boundary)"
	)
	assert_almost_eq(
		_system.current_player_hp,
		_system.player_max_hp,
		0.001,
		"reset_for_retry() must restore player HP to max regardless of boss_hp boundary value"
	)

# ---------------------------------------------------------------------------
# AC-5 (full integration): apply_damage → player_died → save_context → reset
# ---------------------------------------------------------------------------

func test_full_integration_path() -> void:
	# AC-5: Full path — apply lethal damage → player_died fired → RetryContext.save_context()
	# called → reset_for_retry(RetryContext.load_context()) → system in consistent state.
	#
	# Arrange — reduce boss HP first so context preserves a non-max value
	_system.apply_damage(GameEnumsClass.Target.BOSS, 250.0)
	# Boss HP is now 750.0
	var boss_hp_at_death: float = _system.current_boss_hp

	# Trigger player death
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 100.0)
	assert_eq(
		_mock_bus.player_died_call_count,
		1,
		"AC-5 precondition: player_died must be emitted exactly once"
	)

	# Simulate InstantRetrySystem response: save context via RetryContext
	_retry_ctx.save_context(
		boss_hp_at_death,
		_system.current_boss_phase,
		_retry_ctx.session_death_count + 1
	)

	# Load context and reset
	var ctx: Dictionary = _retry_ctx.load_context()
	_system.reset_for_retry(ctx)

	# Assert — system is in a consistent post-death-screen state
	assert_almost_eq(
		_system.current_player_hp,
		_system.player_max_hp,
		0.001,
		"AC-5: player_hp must equal player_max_hp after reset"
	)
	assert_almost_eq(
		_system.current_boss_hp,
		boss_hp_at_death,
		0.001,
		"AC-5: boss_hp must equal the value preserved in RetryContext (not boss_max_hp)"
	)
	assert_almost_eq(
		_system.get_invuln_timer(),
		0.0,
		0.001,
		"AC-5: invuln_timer must be 0.0 after reset"
	)
	# entered_phases: verify the Phase 2 threshold is still recorded if it was crossed.
	# boss HP was 750 (above both 60% and 30% thresholds), so no phase was crossed —
	# boss_phase_changed_call_count should be 0 throughout this test.
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		0,
		"AC-5: no phase transition should have occurred (boss stayed above both thresholds)"
	)
