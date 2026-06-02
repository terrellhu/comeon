extends GutTest

## Unit tests for BossDataLoader._validate() and caching behaviour.
##
## All tests operate on BossData.new() instances — no .tres file I/O required.
## This satisfies the ADR-0002 GUT testability constraint and Story 002 AC.
##
## Assert tests (empty attack_sequence, non-descending phase_threshold_pct,
## empty boss_id, zero boss_max_hp) crash the GUT runner process because
## GDScript assert() is not catchable.  Those cases are marked pending()
## until a GUT error-handler integration is available.

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
# Factory helpers
# ---------------------------------------------------------------------------

## Returns a fully valid BossData instance that passes _validate() with no
## warnings or asserts.
func _make_valid_boss() -> BossData:
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
# AC-1: Valid BossData passes validation without assert or warning
# ---------------------------------------------------------------------------

func test_valid_boss_passes_validation() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()

	# Act + Assert — _validate() must not crash or emit any warning.
	# If an assert fires the runner dies, which is itself evidence of failure.
	_loader._validate(boss)
	assert_true(true, "Valid BossData must pass _validate() without crashing")

# ---------------------------------------------------------------------------
# AC: boss_id empty triggers assert
# ---------------------------------------------------------------------------

func test_empty_boss_id_asserts() -> void:
	# NOTE: assert() crash cannot be caught in GUT headless runner.
	# TODO: assert testing requires GUT error handler
	pending("assert() crash cannot be caught in headless GUT — manual Debug run required")

# ---------------------------------------------------------------------------
# AC: boss_max_hp <= 0 triggers assert
# ---------------------------------------------------------------------------

func test_zero_boss_max_hp_asserts() -> void:
	# NOTE: assert() crash cannot be caught in GUT headless runner.
	# TODO: assert testing requires GUT error handler
	pending("assert() crash cannot be caught in headless GUT — manual Debug run required")

# ---------------------------------------------------------------------------
# AC: empty phases triggers assert
# ---------------------------------------------------------------------------

func test_empty_phases_asserts() -> void:
	# NOTE: assert() crash cannot be caught in GUT headless runner.
	# TODO: assert testing requires GUT error handler
	pending("assert() crash cannot be caught in headless GUT — manual Debug run required")

# ---------------------------------------------------------------------------
# AC-2: Empty attack_sequence triggers assert
# ---------------------------------------------------------------------------

func test_empty_attack_sequence_asserts() -> void:
	# NOTE: GDScript assert() cannot be caught; running _validate() with an
	# empty attack_sequence would crash the GUT process.  This test is marked
	# pending until a GUT error-handler approach is available.
	# TODO: assert testing requires GUT error handler
	pending("assert() crash cannot be caught in headless GUT — manual Debug run required")

# ---------------------------------------------------------------------------
# AC-3: idle_duration_after_attack == 0.0 is clamped to 0.1
# ---------------------------------------------------------------------------

func test_idle_duration_zero_clamped() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	var phase: PhaseData = boss.phases[0]
	phase.idle_duration_after_attack = 0.0

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		phase.idle_duration_after_attack,
		0.1,
		"idle_duration_after_attack = 0.0 must be clamped to 0.1"
	)

# ---------------------------------------------------------------------------
# AC-3b: idle_duration_after_attack below MIN_DURATION but > 0 is clamped
# ---------------------------------------------------------------------------

func test_idle_duration_below_min_clamped() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	var phase: PhaseData = boss.phases[0]
	phase.idle_duration_after_attack = 0.05

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		phase.idle_duration_after_attack,
		0.1,
		"idle_duration_after_attack = 0.05 must be clamped to 0.1"
	)

# ---------------------------------------------------------------------------
# AC-4: telegraph_duration_override below MIN_DURATION (but > 0) is clamped
# ---------------------------------------------------------------------------

func test_telegraph_override_below_min_clamped() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	var attack: AttackData = boss.phases[0].attack_sequence[0]
	attack.telegraph_duration_override = 0.005

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		attack.telegraph_duration_override,
		0.1,
		"telegraph_duration_override = 0.005 must be clamped to 0.1"
	)

# ---------------------------------------------------------------------------
# AC-4b: telegraph_duration_override == 0.0 (disabled) is NOT clamped
# ---------------------------------------------------------------------------

func test_telegraph_override_zero_not_clamped() -> void:
	# Arrange — 0.0 means "use AttackType default"; must not be touched
	var boss: BossData = _make_valid_boss()
	var attack: AttackData = boss.phases[0].attack_sequence[0]
	attack.telegraph_duration_override = 0.0

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		attack.telegraph_duration_override,
		0.0,
		"telegraph_duration_override = 0.0 (disabled) must NOT be clamped"
	)

# ---------------------------------------------------------------------------
# AC-4c: telegraph_duration_override >= 0.1 is NOT clamped
# ---------------------------------------------------------------------------

func test_telegraph_override_at_min_not_clamped() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	var attack: AttackData = boss.phases[0].attack_sequence[0]
	attack.telegraph_duration_override = 0.1

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		attack.telegraph_duration_override,
		0.1,
		"telegraph_duration_override = 0.1 (at boundary) must NOT be clamped"
	)

# ---------------------------------------------------------------------------
# AC-5: phase_threshold_pct not descending triggers assert
# ---------------------------------------------------------------------------

func test_phase_threshold_pct_not_descending_asserts() -> void:
	# NOTE: [0.3, 0.6] is ascending (wrong order) and must trigger assert().
	# GDScript assert() cannot be caught; running this would crash the GUT
	# process.  Marked pending until a GUT error-handler approach is available.
	# TODO: assert testing requires GUT error handler
	pending("assert() crash cannot be caught in headless GUT — manual Debug run required")

# ---------------------------------------------------------------------------
# AC-5b: phase_threshold_pct in valid descending order passes
# ---------------------------------------------------------------------------

func test_phase_threshold_pct_descending_passes_validation() -> void:
	# Arrange — [0.6, 0.3] is descending (correct)
	var boss: BossData = _make_valid_boss()
	boss.phase_threshold_pct = [0.6, 0.3]

	# Act + Assert
	_loader._validate(boss)
	assert_true(true, "Descending phase_threshold_pct must pass _validate()")

# ---------------------------------------------------------------------------
# AC-5c: single-element phase_threshold_pct passes (no pair to compare)
# ---------------------------------------------------------------------------

func test_phase_threshold_pct_single_element_passes_validation() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	boss.phase_threshold_pct = [0.5]

	# Act + Assert
	_loader._validate(boss)
	assert_true(true, "Single-element phase_threshold_pct must pass _validate()")

# ---------------------------------------------------------------------------
# AC-6: Caching — same boss_id returns same object reference
# ---------------------------------------------------------------------------

func test_caching_returns_same_reference() -> void:
	# Arrange — inject a pre-built BossData directly into the loader's cache
	# so get_boss_data() never calls ResourceLoader.load() (no .tres needed).
	var boss: BossData = _make_valid_boss()
	_loader._cache[&"test_boss_cached"] = boss

	# Act — call get_boss_data() twice with the same key
	var result_a: BossData = _loader.get_boss_data(&"test_boss_cached")
	var result_b: BossData = _loader.get_boss_data(&"test_boss_cached")

	# Assert — both must be the exact same object (identity, not equality)
	assert_true(
		result_a is BossData,
		"First call must return a BossData"
	)
	assert_same(
		result_a,
		result_b,
		"Both calls must return the identical cached reference"
	)

# ---------------------------------------------------------------------------
# AC-6b: Different boss_ids do not share cache entries
# ---------------------------------------------------------------------------

func test_caching_different_ids_are_independent() -> void:
	# Arrange
	var boss_a: BossData = _make_valid_boss()
	boss_a.boss_id = &"boss_a"
	var boss_b: BossData = _make_valid_boss()
	boss_b.boss_id = &"boss_b"

	_loader._cache[&"boss_a"] = boss_a
	_loader._cache[&"boss_b"] = boss_b

	# Act
	var result_a: BossData = _loader.get_boss_data(&"boss_a")
	var result_b: BossData = _loader.get_boss_data(&"boss_b")

	# Assert
	assert_not_same(
		result_a,
		result_b,
		"Different boss_ids must not share cache entries"
	)

# ---------------------------------------------------------------------------
# AC-3/4 boundary: negative idle_duration_after_attack is also clamped
# ---------------------------------------------------------------------------

func test_idle_duration_negative_clamped() -> void:
	# Arrange
	var boss: BossData = _make_valid_boss()
	var phase: PhaseData = boss.phases[0]
	phase.idle_duration_after_attack = -1.0

	# Act
	_loader._validate(boss)

	# Assert
	assert_eq(
		phase.idle_duration_after_attack,
		0.1,
		"idle_duration_after_attack = -1.0 must be clamped to 0.1"
	)
