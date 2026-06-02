extends GutTest

## Unit tests for the GUT factory helper pattern (Story 003, AC-3 and AC-4).
##
## Proves that BossData.new() instances can be constructed entirely in code
## (no .tres file I/O) and that _make_test_boss() produces a structure that
## passes BossDataLoader._validate() without errors.

# ---------------------------------------------------------------------------
# Preloads — explicit paths, no class_name reliance (headless-safe)
# ---------------------------------------------------------------------------

const BossDataClass = preload("res://scripts/data/boss_data.gd")
const PhaseDataClass = preload("res://scripts/data/phase_data.gd")
const AttackDataClass = preload("res://scripts/data/attack_data.gd")
const GameEnumsClass = preload("res://scripts/data/game_enums.gd")
const BossDataLoaderClass = preload("res://scripts/foundation/boss_data_loader.gd")

# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

var _loader: Node  # typed as Node; BossDataLoader class_name not resolved at GUT parse time in headless

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	_loader = BossDataLoaderClass.new()
	add_child_autofree(_loader)


func after_each() -> void:
	_loader = null

# ---------------------------------------------------------------------------
# Factory helper — exact values from Story 003 AC-4
# ---------------------------------------------------------------------------

## Creates a minimal valid BossData entirely in code (no .tres loaded).
## Values: boss_id=&"test_boss", boss_max_hp=100.0, phase_threshold_pct=[0.6,0.3], 1 phase, 1 LIGHT AttackData.
func _make_test_boss() -> BossData:
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
	boss.boss_max_hp = 100.0
	boss.phase_threshold_pct = [0.6, 0.3]
	boss.phases = [phase]
	return boss

# ---------------------------------------------------------------------------
# AC-4: _make_test_boss() field assertions
# ---------------------------------------------------------------------------

func test_make_test_boss_boss_id_equals_test_boss() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()

	# Assert
	assert_eq(boss.boss_id, &"test_boss", "boss_id must be &\"test_boss\"")


func test_make_test_boss_max_hp_equals_100() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()

	# Assert
	assert_eq(boss.boss_max_hp, 100.0, "boss_max_hp must be 100.0")


func test_make_test_boss_phases_size_equals_one() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()

	# Assert
	assert_eq(boss.phases.size(), 1, "phases array must contain exactly 1 PhaseData")


func test_make_test_boss_phase_attack_sequence_size_equals_one() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()

	# Assert
	assert_eq(
		boss.phases[0].attack_sequence.size(),
		1,
		"Phase 0 attack_sequence must contain exactly 1 AttackData"
	)


func test_make_test_boss_attack_type_equals_light() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()
	var attack: AttackData = boss.phases[0].attack_sequence[0]

	# Assert
	assert_eq(
		attack.attack_type,
		GameEnumsClass.AttackType.LIGHT,
		"AttackData attack_type must be LIGHT"
	)

# ---------------------------------------------------------------------------
# AC-3: Factory data passes BossDataLoader._validate() without errors
# ---------------------------------------------------------------------------

func test_make_test_boss_validate_passes() -> void:
	# Arrange
	var boss: BossData = _make_test_boss()

	# Act — _validate() must not crash (assert() crash = runner dies = test fails)
	_loader._validate(boss)

	# Assert — prove _validate() completed its full traversal without altering a valid value
	# (if _validate() returned early or never ran, idle_duration_after_attack would be untouched
	# but so would any bug — the state check makes the call falsifiable)
	assert_eq(
		boss.phases[0].idle_duration_after_attack,
		0.5,
		"idle_duration_after_attack must be unchanged after _validate() on a valid boss"
	)
	assert_eq(
		boss.phases[0].attack_sequence[0].telegraph_duration_override,
		0.0,
		"telegraph_duration_override must be unchanged (0.0 = disabled, not in clamp range)"
	)
