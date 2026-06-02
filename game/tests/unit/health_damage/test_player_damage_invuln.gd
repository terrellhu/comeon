extends GutTest

## Unit tests for HealthDamageSystem — Story 002: Player Damage Application and
## Invulnerability Window.
##
## Covers TR-HDS-002 (damage deduction), TR-HDS-011 (invuln guard),
## TR-HDS-013 (zero/negative guard), TR-HDS-015 (flat formula).
##
## GUT naming rule: file prefix is "test_" — do NOT add class_name in headless mode.

# ---------------------------------------------------------------------------
# Preloads — explicit paths; no class_name reliance (headless-safe)
# ---------------------------------------------------------------------------

const HealthDamageSystemClass = preload("res://scripts/core/health_damage_system.gd")
const BossDataClass = preload("res://scripts/data/boss_data.gd")
const PhaseDataClass = preload("res://scripts/data/phase_data.gd")
const AttackDataClass = preload("res://scripts/data/attack_data.gd")
const GameEnumsClass = preload("res://scripts/data/game_enums.gd")
const MockEventBusClass = preload("res://tests/helpers/mock_event_bus.gd")

# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

var _system: Node   # typed as Node; class_name not resolved by GUT parser in headless
var _mock_bus: Node # MockEventBus injected via initialize() — isolates from global Autoload

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	_mock_bus = MockEventBusClass.new()
	add_child_autofree(_mock_bus)
	_system = HealthDamageSystemClass.new()
	_system.initialize(_mock_bus)
	add_child_autofree(_system)
	_system.init_battle(_make_test_boss())

# ---------------------------------------------------------------------------
# Factory helper — ADR-0002 _make_test_boss() pattern; no .tres I/O in tests
# ---------------------------------------------------------------------------

## Returns a minimal valid BossData constructed entirely in code.
func _make_test_boss(boss_max_hp: float = 500.0) -> BossData:
	var attack: AttackData = AttackDataClass.new()
	attack.attack_type = GameEnumsClass.AttackType.LIGHT
	attack.damage = 10.0
	attack.telegraph_duration_override = 0.0

	var phase: PhaseData = PhaseDataClass.new()
	phase.phase_index = 0
	phase.attack_sequence = [attack]
	phase.idle_duration_after_attack = 0.5

	var boss: BossData = BossDataClass.new()
	boss.boss_id = &"test_boss"
	boss.boss_max_hp = boss_max_hp
	boss.phase_threshold_pct = [0.6, 0.3]
	boss.phases = [phase]
	return boss

# ---------------------------------------------------------------------------
# AC: Normal hit — HP deducted and signal emitted once
# ---------------------------------------------------------------------------

func test_apply_damage_player_alive_reduces_hp_by_amount() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert
	assert_eq(
		_system.current_player_hp,
		90.0,
		"current_player_hp must be 90.0 after 10.0 damage on 100.0 HP"
	)


func test_apply_damage_emits_player_hp_changed_once() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert — MockEventBus records how many times player_hp_changed was called
	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		1,
		"player_hp_changed must be emitted exactly once on a valid hit"
	)


func test_apply_damage_emits_correct_hp_values() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert — last recorded emission carries (90.0, 100.0)
	assert_eq(
		_mock_bus.last_player_hp_changed_current,
		90.0,
		"Emitted current HP must be 90.0"
	)
	assert_eq(
		_mock_bus.last_player_hp_changed_max,
		100.0,
		"Emitted max HP must be 100.0"
	)

# ---------------------------------------------------------------------------
# AC: Invulnerability window set after a valid hit
# ---------------------------------------------------------------------------

func test_apply_damage_sets_invuln_timer_after_hit() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.player_hit_invuln_duration = 0.5

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert — timer must be set to the configured duration
	assert_eq(
		_system.get_invuln_timer(),
		0.5,
		"invuln_timer must be set to player_hit_invuln_duration (0.5s) after a valid hit"
	)

# ---------------------------------------------------------------------------
# AC: Second hit during invuln window is ignored; timer NOT reset
# ---------------------------------------------------------------------------

func test_apply_damage_during_invuln_window_is_ignored() -> void:
	# Arrange — first hit starts the invuln window
	_system.current_player_hp = 100.0
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)
	# HP is now 90.0; invuln_timer = 0.5

	# Simulate 0.3s elapsed (timer should be ≈0.2s remaining)
	# We manipulate the timer directly to avoid real-time dependency
	# (tests must be deterministic — no await get_tree().create_timer())
	_system._invuln_timer = 0.2  # 0.3s already passed; 0.2s remain

	var hp_before_second_hit: float = _system.current_player_hp

	# Act — second hit during invuln window
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 20.0)

	# Assert — HP unchanged
	assert_eq(
		_system.current_player_hp,
		hp_before_second_hit,
		"HP must not change during the invulnerability window"
	)


func test_apply_damage_during_invuln_does_not_emit_signal() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)
	_mock_bus.player_hp_changed_call_count = 0  # reset counter after first hit

	_system._invuln_timer = 0.2

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 20.0)

	# Assert — no additional signal
	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		0,
		"player_hp_changed must NOT be emitted when hit is blocked by invuln window"
	)


func test_apply_damage_during_invuln_does_not_reset_timer() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)
	_system._invuln_timer = 0.2  # simulate partial timer remaining

	# Act — a second hit must not extend the timer back to 0.5
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 20.0)

	# Assert — timer must remain ≈ 0.2 (not reset to 0.5)
	assert_eq(
		_system.get_invuln_timer(),
		0.2,
		"invuln_timer must NOT be reset when a hit is blocked by the invuln window"
	)

# ---------------------------------------------------------------------------
# AC: Zero and negative damage are complete no-ops
# ---------------------------------------------------------------------------

func test_apply_damage_zero_amount_does_not_change_hp() -> void:
	# Arrange
	_system.current_player_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 0.0)

	# Assert — HP unchanged
	assert_eq(
		_system.current_player_hp,
		100.0,
		"Zero damage must not change current_player_hp"
	)


func test_apply_damage_zero_amount_does_not_emit_signal() -> void:
	# Arrange
	_system.current_player_hp = 100.0
	_mock_bus.player_hp_changed_call_count = 0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 0.0)

	# Assert
	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		0,
		"Zero damage must not emit player_hp_changed"
	)


func test_apply_damage_zero_amount_does_not_start_invuln_window() -> void:
	# Arrange
	_system.current_player_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 0.0)

	# Assert — invuln window must NOT be consumed by a zero-damage call
	assert_eq(
		_system.get_invuln_timer(),
		0.0,
		"Zero damage must not start the invulnerability window"
	)


func test_apply_damage_negative_amount_does_not_change_hp() -> void:
	# Arrange
	_system.current_player_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, -10.0)

	# Assert
	assert_eq(
		_system.current_player_hp,
		100.0,
		"Negative damage must not change current_player_hp"
	)


func test_apply_damage_negative_amount_does_not_start_invuln_window() -> void:
	# Arrange
	_system.current_player_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, -10.0)

	# Assert
	assert_eq(
		_system.get_invuln_timer(),
		0.0,
		"Negative damage must not start the invulnerability window"
	)

# ---------------------------------------------------------------------------
# AC: Flat damage formula — no scaling, no multiplier
# ---------------------------------------------------------------------------

func test_apply_damage_flat_formula_25_damage_from_100_hp() -> void:
	# Arrange
	_system.current_player_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 25.0)

	# Assert — flat deduction: 100 - 25 = 75
	assert_eq(
		_system.current_player_hp,
		75.0,
		"Flat damage formula: 100.0 - 25.0 must equal 75.0"
	)


func test_apply_damage_flat_formula_40_damage_from_80_hp() -> void:
	# Arrange
	_system.current_player_hp = 80.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 40.0)

	# Assert — flat deduction: 80 - 40 = 40
	assert_eq(
		_system.current_player_hp,
		40.0,
		"Flat damage formula: 80.0 - 40.0 must equal 40.0"
	)

# ---------------------------------------------------------------------------
# AC-8: Performance — per-call processing time < 1.0ms
# ---------------------------------------------------------------------------

func test_apply_damage_performance_under_1ms_per_call() -> void:
	# Arrange — reset to a known clean state before measuring
	_system.current_player_hp = _system.player_max_hp

	var start_us: int = Time.get_ticks_usec()

	# Act — 1000 calls; reset HP and invuln between each so all calls hit the
	# damage path (not the early-exit invuln guard)
	for _i: int in 1000:
		_system._invuln_timer = 0.0
		_system.current_player_hp = _system.player_max_hp
		_system.apply_damage(GameEnumsClass.Target.PLAYER, 1.0)

	var elapsed_us: int = Time.get_ticks_usec() - start_us
	var per_call_us: float = float(elapsed_us) / 1000.0

	# Assert — 1.0ms = 1000µs
	assert_lt(
		per_call_us,
		1000.0,
		"apply_damage must complete in < 1.0ms per call (measured: %.1f µs)" % per_call_us
	)
