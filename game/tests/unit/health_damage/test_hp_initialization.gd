extends GutTest

## Unit tests for HealthDamageSystem — Story 001: HP Initialization and BossData Contract.
##
## Covers TR-HDS-001 (player HP initialized to player_max_hp) and
## TR-HDS-010 (boss HP comes from BossData asset, not hardcoded literals).
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

# ---------------------------------------------------------------------------
# Factory helper — ADR-0002 _make_test_boss() pattern; no .tres I/O in tests
# ---------------------------------------------------------------------------

## Returns a minimal valid BossData constructed entirely in code.
## Values: boss_id=&"test_boss", boss_max_hp=500.0, 1 phase, 1 LIGHT attack.
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
# AC-1: Player HP initialized to player_max_hp
# ---------------------------------------------------------------------------

func test_init_battle_player_hp_equals_player_max_hp() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.current_player_hp,
		_system.player_max_hp,
		"current_player_hp must equal player_max_hp after init_battle"
	)


func test_init_battle_player_hp_equals_export_default_100() -> void:
	# Arrange — default @export value is 100.0
	var boss: BossData = _make_test_boss()
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.current_player_hp,
		100.0,
		"Default player_max_hp export is 100.0; current_player_hp must match"
	)


func test_init_battle_player_hp_reflects_custom_max_hp() -> void:
	# Arrange — override @export to verify generic contract (not a hardcoded 100)
	var boss: BossData = _make_test_boss()
	_system.player_max_hp = 80.0
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.current_player_hp,
		80.0,
		"current_player_hp must equal custom player_max_hp (80.0)"
	)

# ---------------------------------------------------------------------------
# AC-1 (HUD segment count contract)
# ---------------------------------------------------------------------------

func test_player_hp_segments_export_default_equals_5() -> void:
	# Arrange / Assert — no battle needed; segment count is a static export
	assert_eq(
		_system.player_hp_segments,
		5,
		"Default player_hp_segments export must be 5"
	)


func test_hud_segment_count_formula_full_hp() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()
	_system.init_battle(boss)

	# Act — formula: ceil(current_hp / hp_per_segment); hp_per_segment = max_hp / segments
	var hp_per_segment: float = _system.player_max_hp / float(_system.player_hp_segments)
	var segment_count: int = ceili(_system.current_player_hp / hp_per_segment)

	# Assert — full HP → all 5 segments
	assert_eq(segment_count, 5, "Full HP must yield 5 HUD segments")

# ---------------------------------------------------------------------------
# AC-2: Boss HP initialized from BossData asset, not hardcoded
# ---------------------------------------------------------------------------

func test_init_battle_boss_hp_equals_boss_data_max_hp() -> void:
	# Arrange
	var boss: BossData = _make_test_boss(500.0)
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.current_boss_hp,
		500.0,
		"current_boss_hp must equal boss_data.boss_max_hp (500.0)"
	)


func test_init_battle_boss_max_hp_stored_from_asset() -> void:
	# Arrange
	var boss: BossData = _make_test_boss(750.0)
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.boss_max_hp,
		750.0,
		"boss_max_hp field must be copied from BossData asset (750.0)"
	)


func test_init_battle_different_boss_max_hp_reflects_correctly() -> void:
	# Arrange — use the canonical boss_01 value from game/data/bosses/boss_01.tres
	var boss: BossData = _make_test_boss(1000.0)
	# Act
	_system.init_battle(boss)

	# Assert
	assert_eq(
		_system.current_boss_hp,
		1000.0,
		"current_boss_hp must equal 1000.0 when BossData.boss_max_hp is 1000.0"
	)

# ---------------------------------------------------------------------------
# AC-2: Initial boss phase is 1 (Phase 1 is the opening phase)
# ---------------------------------------------------------------------------

func test_init_battle_boss_phase_starts_at_one() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()
	# Act
	_system.init_battle(boss)

	# Assert — Phase 1 is the pre-first-threshold state; boss_phase_changed(1,2)
	# is the first transition signal, which requires current_boss_phase = 1 initially.
	assert_eq(
		_system.current_boss_phase,
		1,
		"current_boss_phase must be 1 at battle start (Phase 1 is the opening phase)"
	)

# ---------------------------------------------------------------------------
# AC-3: No numeric literals in logic — export values are the sole source
# ---------------------------------------------------------------------------

func test_player_hp_equals_max_hp_not_literal() -> void:
	# Arrange — set a non-default max to prove current_player_hp tracks the export
	var boss: BossData = _make_test_boss()
	_system.player_max_hp = 200.0
	# Act
	_system.init_battle(boss)

	# Assert — if current_player_hp were hardcoded to 100, this would fail
	assert_eq(
		_system.current_player_hp,
		200.0,
		"current_player_hp must come from player_max_hp export, not a literal 100.0"
	)


func test_boss_hp_equals_asset_value_not_literal() -> void:
	# Arrange — use an unusual value to rule out any hardcoded literal
	var boss: BossData = _make_test_boss(333.0)
	# Act
	_system.init_battle(boss)

	# Assert — if current_boss_hp were hardcoded to 1000, this would fail
	assert_eq(
		_system.current_boss_hp,
		333.0,
		"current_boss_hp must come from BossData.boss_max_hp, not a hardcoded literal"
	)
