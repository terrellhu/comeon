extends GutTest

## Unit tests for HealthDamageSystem — Story 006: HUD Segment Display.
##
## Covers TR-HDS-012: get_displayed_segments() returns the number of filled HP
## segments for the HUD using ceili(current_player_hp / hp_per_segment), with
## an explicit HP=0 guard that returns 0 before the formula runs.
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
# AC-1: HP above a segment boundary — ceili rounds up to the next segment
# ---------------------------------------------------------------------------

func test_get_displayed_segments_above_boundary_returns_4() -> void:
	# Arrange — 61/100 with 5 segments: hp_per_segment=20, ceil(61/20)=ceil(3.05)=4
	_system.current_player_hp = 61.0

	# Act
	var result: int = _system.get_displayed_segments()

	# Assert
	assert_eq(
		result,
		4,
		"get_displayed_segments() at 61 HP must return 4 (ceili rounds up, not down)"
	)

# ---------------------------------------------------------------------------
# AC-2: HP exactly on a segment boundary — integer boundary, no rounding up
# ---------------------------------------------------------------------------

func test_get_displayed_segments_at_boundary_returns_3() -> void:
	# Arrange — 60/100 with 5 segments: hp_per_segment=20, ceil(60/20)=ceil(3.0)=3
	# Boundary value: segment drops at exactly 60, NOT at 61
	_system.current_player_hp = 60.0

	# Act
	var result: int = _system.get_displayed_segments()

	# Assert
	assert_eq(
		result,
		3,
		"get_displayed_segments() at exactly 60 HP must return 3, not 4 (boundary drops at 60)"
	)

# ---------------------------------------------------------------------------
# AC-3: HP = 0 — explicit guard returns 0 before formula runs
# ---------------------------------------------------------------------------

func test_get_displayed_segments_zero_hp_returns_0() -> void:
	# Arrange — HP=0 triggers the explicit guard (required by GDD for clarity)
	_system.current_player_hp = 0.0

	# Act
	var result: int = _system.get_displayed_segments()

	# Assert
	assert_eq(
		result,
		0,
		"get_displayed_segments() at 0 HP must return 0 via the explicit guard"
	)

# ---------------------------------------------------------------------------
# AC-4: Trace HP (1.0) — always shows 1 segment, never 0
# ---------------------------------------------------------------------------

func test_get_displayed_segments_trace_hp_returns_1() -> void:
	# Arrange — 1/100 with 5 segments: ceil(1/20)=ceil(0.05)=1 (not 0)
	_system.current_player_hp = 1.0

	# Act
	var result: int = _system.get_displayed_segments()

	# Assert
	assert_eq(
		result,
		1,
		"get_displayed_segments() at 1 HP must return 1 — trace HP must show a segment"
	)

# ---------------------------------------------------------------------------
# AC-5: Full HP — all segments filled
# ---------------------------------------------------------------------------

func test_get_displayed_segments_full_hp_returns_5() -> void:
	# Arrange — init_battle sets current_player_hp = player_max_hp = 100.0
	# ceil(100/20)=ceil(5.0)=5

	# Act
	var result: int = _system.get_displayed_segments()

	# Assert
	assert_eq(
		result,
		5,
		"get_displayed_segments() at full HP (100.0) must return 5 (all segments filled)"
	)
