extends GutTest

## Unit tests for HealthDamageSystem — Story 004: Healing Application and Over-Heal Guard.
##
## Covers TR-HDS-008: apply_healing(PLAYER, amount) clamps to player_max_hp;
## player_hp_changed is emitted on every call, including when already at full HP.
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

var _system: HealthDamageSystem
var _mock_bus: MockEventBus

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


func _make_test_boss() -> BossData:
	var attack: AttackData = AttackDataClass.new()
	attack.attack_type = GameEnumsClass.AttackType.LIGHT
	attack.damage = 10.0

	var phase: PhaseData = PhaseDataClass.new()
	phase.phase_index = 0
	phase.attack_sequence = [attack]
	phase.idle_duration_after_attack = 0.5

	var boss: BossData = BossDataClass.new()
	boss.boss_id = &"test_boss"
	boss.boss_max_hp = 500.0
	boss.phase_threshold_pct = [0.6, 0.3]
	boss.phases = [phase]
	return boss

# ---------------------------------------------------------------------------
# AC-1: Partial heal clamps to player_max_hp; player_hp_changed emitted
# ---------------------------------------------------------------------------

func test_apply_healing_player_partial_heal_clamps_to_max() -> void:
	# Arrange — 80 + 30 = 110, must clamp to 100
	_system.current_player_hp = 80.0

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 30.0)

	assert_eq(
		_system.current_player_hp,
		100.0,
		"apply_healing(PLAYER, 30) from 80 HP must clamp to 100.0, not 110.0"
	)


func test_apply_healing_player_partial_heal_emits_player_hp_changed() -> void:
	_system.current_player_hp = 80.0

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 30.0)

	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		1,
		"player_hp_changed must be emitted exactly once"
	)
	assert_eq(_mock_bus.last_player_hp_changed_current, 100.0,
		"player_hp_changed current arg must be 100.0")
	assert_eq(_mock_bus.last_player_hp_changed_max, 100.0,
		"player_hp_changed max_hp arg must be 100.0")

# ---------------------------------------------------------------------------
# AC-2: Over-heal — value above max is never stored
# ---------------------------------------------------------------------------

func test_apply_healing_player_overheal_clamps_to_max() -> void:
	# Arrange — 80 + 40 = 120, must clamp to 100
	_system.current_player_hp = 80.0

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 40.0)

	assert_eq(
		_system.current_player_hp,
		100.0,
		"Over-heal of 40 from 80 HP must clamp to 100.0, never store 120.0"
	)

# ---------------------------------------------------------------------------
# AC-3: Heal at full HP — HP unchanged; player_hp_changed still emitted
# ---------------------------------------------------------------------------

func test_apply_healing_player_at_full_hp_stays_at_max() -> void:
	# init_battle sets current_player_hp = player_max_hp = 100.0

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 20.0)

	assert_eq(
		_system.current_player_hp,
		100.0,
		"Healing at full HP must leave current_player_hp at 100.0"
	)


func test_apply_healing_player_at_full_hp_still_emits_signal() -> void:
	# AC-3: heal at full is not an error — signal must still fire

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 20.0)

	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		1,
		"player_hp_changed must be emitted even when HP is already full"
	)
	assert_eq(_mock_bus.last_player_hp_changed_current, 100.0,
		"player_hp_changed current must be 100.0")
	assert_eq(_mock_bus.last_player_hp_changed_max, 100.0,
		"player_hp_changed max_hp must be 100.0")

# ---------------------------------------------------------------------------
# Guard: zero / negative amount — no-op, no signal
# ---------------------------------------------------------------------------

func test_apply_healing_player_negative_amount_is_noop() -> void:
	# amount <= 0.0 guard — mirrors apply_damage guard for symmetry
	_system.current_player_hp = 80.0

	_system.apply_healing(GameEnumsClass.Target.PLAYER, -10.0)

	assert_eq(
		_system.current_player_hp,
		80.0,
		"Negative amount must be a no-op — HP must not decrease"
	)
	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		0,
		"player_hp_changed must not emit for negative amount"
	)

# ---------------------------------------------------------------------------
# Invariant: healing does not modify _invuln_timer
# ---------------------------------------------------------------------------

func test_apply_healing_player_does_not_modify_invuln_timer() -> void:
	# Arrange — set invuln timer via damage, then heal
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)
	var timer_before: float = _system.get_invuln_timer()
	assert_gt(timer_before, 0.0, "Pre-condition: invuln timer must be active after damage")

	_system.apply_healing(GameEnumsClass.Target.PLAYER, 20.0)

	assert_eq(
		_system.get_invuln_timer(),
		timer_before,
		"apply_healing must not clear or modify the invuln timer"
	)
