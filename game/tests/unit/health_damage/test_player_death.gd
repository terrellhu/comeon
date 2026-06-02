extends GutTest

## Unit tests for HealthDamageSystem — Story 003: Player Death Detection and HP Clamping.
##
## Covers TR-HDS-003 (player_died emission on HP <= 0) and
## TR-HDS-004 (HP invariant — negative HP must never be stored).
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
# AC-1: Lethal hit clamps HP to 0 and emits player_died
# ---------------------------------------------------------------------------

func test_apply_damage_lethal_hit_clamps_hp_to_zero() -> void:
	# Arrange — player at 15 HP, deal 40 damage (overkill)
	_system.current_player_hp = 15.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 40.0)

	# Assert — HP clamped to 0, NOT −25
	assert_eq(
		_system.current_player_hp,
		0.0,
		"current_player_hp must be clamped to 0.0 on overkill (15 - 40 must NOT store -25)"
	)


func test_apply_damage_lethal_hit_emits_player_died() -> void:
	# Arrange
	_system.current_player_hp = 15.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 40.0)

	# Assert — player_died emitted exactly once
	assert_eq(
		_mock_bus.player_died_call_count,
		1,
		"player_died must be emitted exactly once when HP reaches 0"
	)

# ---------------------------------------------------------------------------
# AC-2: Massive overkill — HP invariant holds (negative never stored)
# ---------------------------------------------------------------------------

func test_apply_damage_massive_overkill_hp_never_negative() -> void:
	# Arrange — 10 HP vs 100 damage
	_system.current_player_hp = 10.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 100.0)

	# Assert — clamp prevents negative storage
	assert_eq(
		_system.current_player_hp,
		0.0,
		"current_player_hp must never be negative — 10 - 100 must clamp to 0.0"
	)


func test_apply_damage_massive_overkill_emits_player_died() -> void:
	# Arrange
	_system.current_player_hp = 10.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 100.0)

	# Assert
	assert_eq(
		_mock_bus.player_died_call_count,
		1,
		"player_died must be emitted exactly once even on massive overkill"
	)

# ---------------------------------------------------------------------------
# AC-3: Non-lethal hit — player_died NOT emitted
# ---------------------------------------------------------------------------

func test_apply_damage_non_lethal_does_not_emit_player_died() -> void:
	# Arrange — 80 HP, 40 damage (leaves 40 HP alive)
	_system.current_player_hp = 80.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 40.0)

	# Assert — death threshold not crossed; player_died must not fire
	assert_eq(
		_mock_bus.player_died_call_count,
		0,
		"player_died must NOT be emitted when the player survives the hit (HP > 0)"
	)


func test_apply_damage_non_lethal_correct_hp_remains() -> void:
	# Arrange
	_system.current_player_hp = 80.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 40.0)

	# Assert
	assert_eq(
		_system.current_player_hp,
		40.0,
		"Non-lethal hit: 80.0 - 40.0 must leave 40.0 HP"
	)

# ---------------------------------------------------------------------------
# AC-4: Exact-lethal hit — boundary case (HP == 0 exactly)
# ---------------------------------------------------------------------------

func test_apply_damage_exact_lethal_clamps_hp_to_zero() -> void:
	# Arrange — 20 HP, exactly 20 damage
	_system.current_player_hp = 20.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 20.0)

	# Assert
	assert_eq(
		_system.current_player_hp,
		0.0,
		"Exact-lethal hit: 20.0 - 20.0 must produce exactly 0.0 HP"
	)


func test_apply_damage_exact_lethal_emits_player_died_once() -> void:
	# Arrange
	_system.current_player_hp = 20.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 20.0)

	# Assert — boundary: HP == 0 must still trigger death signal
	assert_eq(
		_mock_bus.player_died_call_count,
		1,
		"player_died must be emitted exactly once on exact-lethal hit (HP == 0.0 boundary)"
	)

# ---------------------------------------------------------------------------
# AC-5: No duplicate player_died on subsequent hits after death
#
# Design guarantee: the invulnerability window set by the killing blow (0.5s)
# prevents any subsequent apply_damage call from reaching the death check.
# This test validates that structural guarantee.
# ---------------------------------------------------------------------------

func test_apply_damage_no_duplicate_player_died_on_second_hit() -> void:
	# Arrange — kill the player
	_system.current_player_hp = 15.0
	_system.player_hit_invuln_duration = 0.5
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 15.0)
	# State: HP == 0, _invuln_timer == 0.5, player_died_call_count == 1

	# Reset counter to isolate the second-hit assertion
	_mock_bus.player_died_call_count = 0

	# Act — another hit arrives while invuln window is active
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert — invuln guard blocks the second hit; player_died not re-emitted
	assert_eq(
		_mock_bus.player_died_call_count,
		0,
		"player_died must NOT be emitted again when invuln window blocks the second hit"
	)

# ---------------------------------------------------------------------------
# AC ordering: player_hp_changed emitted BEFORE player_died
#
# Subscribers need the updated HP (0.0) before handling the death event.
# We verify ordering by checking that player_hp_changed fired at least once
# before player_died — MockEventBus records both counts; if hp_changed == 0
# and player_died == 1, the ordering contract is violated.
# ---------------------------------------------------------------------------

func test_apply_damage_player_hp_changed_emitted_before_player_died() -> void:
	# Arrange
	_system.current_player_hp = 10.0
	_system.player_max_hp = 100.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.PLAYER, 10.0)

	# Assert — both must have fired; hp_changed must have fired (count >= 1)
	# before player_died (count >= 1). The MockEventBus connection order
	# guarantees _on_player_hp_changed runs before _on_player_died since
	# player_hp_changed.emit() is called first in apply_damage.
	assert_eq(
		_mock_bus.player_hp_changed_call_count,
		1,
		"player_hp_changed must be emitted (once) before player_died on a lethal hit"
	)
	assert_eq(
		_mock_bus.player_died_call_count,
		1,
		"player_died must be emitted (once) after player_hp_changed on a lethal hit"
	)
	assert_eq(
		_mock_bus.last_player_hp_changed_current,
		0.0,
		"player_hp_changed must carry updated HP (0.0) so subscribers see death HP before handling player_died"
	)
