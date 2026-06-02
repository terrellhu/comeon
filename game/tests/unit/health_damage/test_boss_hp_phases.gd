extends GutTest

## Unit tests for HealthDamageSystem — Story 005: Boss HP, Phase Detection, and Defeat.
##
## Covers TR-HDS-005 (phase transition signals), TR-HDS-006 (phase idempotency),
## TR-HDS-009 (boss defeated emission), TR-HDS-013 (signal routing via EventBus),
## TR-HDS-014 (no literal HP values in logic).
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

## Returns a BossData with boss_max_hp=1000.0 and phase_threshold_pct=[0.6, 0.3].
## Constructed entirely in code — no filesystem I/O.
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
	boss.boss_max_hp = 1000.0
	boss.phase_threshold_pct = [0.6, 0.3]
	boss.phases = [phase]
	return boss

# ---------------------------------------------------------------------------
# AC-1: Single threshold crossing emits boss_phase_changed(1, 2) once
# ---------------------------------------------------------------------------

func test_apply_damage_boss_crosses_phase1_threshold_emits_phase_changed() -> void:
	# Arrange — boss at 650 HP; 60% threshold = 600 HP; 75 damage crosses it
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — boss_phase_changed emitted exactly once
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		1,
		"boss_phase_changed must be emitted exactly once when 60% threshold is first crossed"
	)


func test_apply_damage_boss_crosses_phase1_threshold_correct_args() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — from_phase=1, to_phase=2
	assert_eq(
		_mock_bus.boss_phase_changed_history.size(),
		1,
		"Exactly one phase transition must be recorded"
	)
	var transition: Array = _mock_bus.boss_phase_changed_history[0]
	assert_eq(transition[0], 1, "from_phase must be 1 (Phase 1 was active)")
	assert_eq(transition[1], 2, "to_phase must be 2 (entering Phase 2)")


func test_apply_damage_boss_crosses_phase1_threshold_hp_correct() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act — 650 - 75 = 575
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — HP deduction is flat, no rounding
	assert_eq(
		_system.current_boss_hp,
		575.0,
		"current_boss_hp must be 575.0 after 650 - 75"
	)


func test_apply_damage_boss_crosses_phase1_threshold_phase_index_updated() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — current_boss_phase updated to 2
	assert_eq(
		_system.current_boss_phase,
		2,
		"current_boss_phase must be 2 after crossing the 60% threshold"
	)

# ---------------------------------------------------------------------------
# AC-2: Phase transition is idempotent (heal-then-damage does NOT re-trigger)
# ---------------------------------------------------------------------------

func test_apply_damage_boss_phase_change_not_reemitted_on_recross() -> void:
	# Arrange — cross Phase 2 threshold first
	_system.current_boss_hp = 650.0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)
	# State: HP = 575 (< 60%), Phase 2 entered, boss_phase_changed fired once

	# Simulate heal above 60% threshold, then deal damage below it again
	_system.current_boss_hp = 650.0   # manually reset above threshold (no healing API yet)
	# Note: current_boss_phase is now 2 (not 1) — _entered_phases[0] is set.
	# The subsequent apply_damage checks the guard, not the phase index.
	_mock_bus.boss_phase_changed_call_count = 0
	_mock_bus.boss_phase_changed_history.clear()

	# Act — drop below 60% again
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — entered_phases guard must prevent re-emission
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		0,
		"boss_phase_changed must NOT re-emit for Phase 2 when threshold is crossed a second time"
	)

# ---------------------------------------------------------------------------
# AC-3: Single apply_damage crossing two thresholds fires two transitions in order
# ---------------------------------------------------------------------------

func test_apply_damage_boss_crosses_both_thresholds_emits_two_transitions() -> void:
	# Arrange — boss at 650 HP; 400 damage lands at 250 HP, below both 60% and 30%
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 400.0)

	# Assert — two boss_phase_changed emissions
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		2,
		"boss_phase_changed must be emitted twice when a single hit crosses both thresholds"
	)


func test_apply_damage_boss_crosses_both_thresholds_first_transition_correct() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 400.0)

	# Assert — first emission: (1, 2)
	assert_eq(
		_mock_bus.boss_phase_changed_history.size(),
		2,
		"History must contain exactly 2 transition records"
	)
	var first: Array = _mock_bus.boss_phase_changed_history[0]
	assert_eq(first[0], 1, "First transition from_phase must be 1")
	assert_eq(first[1], 2, "First transition to_phase must be 2")


func test_apply_damage_boss_crosses_both_thresholds_second_transition_correct() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 400.0)

	# Assert — second emission: (2, 3)
	var second: Array = _mock_bus.boss_phase_changed_history[1]
	assert_eq(second[0], 2, "Second transition from_phase must be 2")
	assert_eq(second[1], 3, "Second transition to_phase must be 3")


func test_apply_damage_boss_crosses_both_thresholds_hp_correct() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act — 650 - 400 = 250
	_system.apply_damage(GameEnumsClass.Target.BOSS, 400.0)

	# Assert
	assert_eq(
		_system.current_boss_hp,
		250.0,
		"current_boss_hp must be 250.0 after 650 - 400"
	)

# ---------------------------------------------------------------------------
# AC-4: Defeat — HP reaches 0, boss_defeated emitted exactly once
# ---------------------------------------------------------------------------

func test_apply_damage_boss_lethal_clamps_hp_to_zero() -> void:
	# Arrange — boss at 30 HP, deal 30
	_system.current_boss_hp = 30.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 30.0)

	# Assert — HP clamped to 0
	assert_eq(
		_system.current_boss_hp,
		0.0,
		"current_boss_hp must be 0.0 on a lethal hit (never negative)"
	)


func test_apply_damage_boss_lethal_emits_boss_defeated_once() -> void:
	# Arrange
	_system.current_boss_hp = 30.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 30.0)

	# Assert
	assert_eq(
		_mock_bus.boss_defeated_call_count,
		1,
		"boss_defeated must be emitted exactly once when boss HP reaches 0"
	)

# ---------------------------------------------------------------------------
# AC-5: Post-defeat no-op — boss_defeated not re-emitted; HP stays at 0
# ---------------------------------------------------------------------------

func test_apply_damage_boss_post_defeat_hp_stays_zero() -> void:
	# Arrange — defeat the boss
	_system.current_boss_hp = 30.0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 30.0)
	# State: HP = 0, boss_defeated emitted once

	# Reset counter to isolate the follow-up assertion
	_mock_bus.boss_defeated_call_count = 0

	# Act — residual attack frame
	_system.apply_damage(GameEnumsClass.Target.BOSS, 20.0)

	# Assert — HP must not go below 0
	assert_eq(
		_system.current_boss_hp,
		0.0,
		"current_boss_hp must stay 0.0 after boss is already defeated"
	)


func test_apply_damage_boss_post_defeat_boss_defeated_not_reemitted() -> void:
	# Arrange
	_system.current_boss_hp = 30.0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 30.0)
	_mock_bus.boss_defeated_call_count = 0
	_mock_bus.boss_hp_changed_call_count = 0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 20.0)

	# Assert — _is_boss_defeated guard makes the second call a complete no-op
	assert_eq(
		_mock_bus.boss_defeated_call_count,
		0,
		"boss_defeated must NOT be emitted again after the boss is already defeated"
	)


func test_apply_damage_boss_post_defeat_no_signals_emitted() -> void:
	# Arrange
	_system.current_boss_hp = 30.0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 30.0)
	_mock_bus.boss_hp_changed_call_count = 0
	_mock_bus.boss_phase_changed_call_count = 0
	_mock_bus.boss_defeated_call_count = 0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 20.0)

	# Assert — zero signals of any boss kind
	assert_eq(
		_mock_bus.boss_hp_changed_call_count,
		0,
		"boss_hp_changed must NOT be emitted when the boss is already defeated"
	)
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		0,
		"boss_phase_changed must NOT be emitted when the boss is already defeated"
	)

# ---------------------------------------------------------------------------
# AC-6: CAC formula amounts (16 + 22 + 32 = 70 total deducted) — flat deduction
# ---------------------------------------------------------------------------

func test_apply_damage_boss_cac_combo_amounts_deducted_correctly() -> void:
	# Arrange — boss at full HP (1000)
	# Counter-attack combo: 0.8× 20 = 16, 1.1× 20 = 22, 1.6× 20 = 32 (CAC formula 1)

	# Act — three sequential calls with pre-calculated amounts
	_system.apply_damage(GameEnumsClass.Target.BOSS, 16.0)
	_system.apply_damage(GameEnumsClass.Target.BOSS, 22.0)
	_system.apply_damage(GameEnumsClass.Target.BOSS, 32.0)

	# Assert — total deducted = 70; HP = 1000 - 70 = 930
	assert_eq(
		_system.current_boss_hp,
		930.0,
		"Three CAC hits (16+22+32=70) must deduct 70 total from boss HP (no special handling)"
	)

# ---------------------------------------------------------------------------
# AC-7: boss_hp_changed is emitted with correct args on each damage call
# ---------------------------------------------------------------------------

func test_apply_damage_boss_emits_boss_hp_changed_with_current_hp() -> void:
	# Arrange
	_system.current_boss_hp = 650.0

	# Act — non-threshold crossing hit; 650 - 50 = 600 (exactly at 60%)
	# 600 / 1000 = 0.6 which equals threshold[0]=0.6, so phase change also fires here.
	# Use a smaller amount to stay above the 60% threshold.
	_system.apply_damage(GameEnumsClass.Target.BOSS, 10.0)

	# Assert — boss_hp_changed carries current=640, max=1000, phase=1
	assert_eq(
		_mock_bus.last_boss_hp_changed_current,
		640.0,
		"boss_hp_changed must carry updated current HP (650 - 10 = 640)"
	)
	assert_eq(
		_mock_bus.last_boss_hp_changed_max,
		1000.0,
		"boss_hp_changed must carry max_hp from BossData (1000)"
	)
	assert_eq(
		_mock_bus.last_boss_hp_changed_phase,
		1,
		"boss_hp_changed must carry the phase active at the time of emission (Phase 1)"
	)


func test_apply_damage_boss_emits_boss_hp_changed_once_per_call() -> void:
	# Arrange
	_system.current_boss_hp = 800.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 50.0)

	# Assert
	assert_eq(
		_mock_bus.boss_hp_changed_call_count,
		1,
		"boss_hp_changed must be emitted exactly once per apply_damage(BOSS, …) call"
	)

# ---------------------------------------------------------------------------
# AC-8: Zero-amount guard — no boss signals for zero damage
# ---------------------------------------------------------------------------

func test_apply_damage_boss_zero_amount_is_noop() -> void:
	# Arrange
	_system.current_boss_hp = 500.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 0.0)

	# Assert — HP unchanged, no signals
	assert_eq(
		_system.current_boss_hp,
		500.0,
		"Zero damage must not change current_boss_hp"
	)
	assert_eq(
		_mock_bus.boss_hp_changed_call_count,
		0,
		"boss_hp_changed must NOT be emitted for zero damage"
	)

# ---------------------------------------------------------------------------
# Overkill: single hit crosses a remaining threshold AND defeats boss
# ---------------------------------------------------------------------------

func test_apply_damage_boss_overkill_fires_phase_change_then_defeat() -> void:
	# Arrange — cross only the 60% threshold (Phase 2 entered), leaving 30% untouched.
	# 650 - 75 = 575 HP (57.5%): below 60%, above 30%.
	_system.current_boss_hp = 650.0
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)
	# State: HP = 575, Phase 2 entered, Phase 3 threshold (30%) NOT yet entered.
	_mock_bus.boss_phase_changed_history.clear()
	_mock_bus.boss_phase_changed_call_count = 0
	_mock_bus.boss_defeated_call_count = 0

	# Act — 800 damage overkill: 575 → 0, crosses the 30% threshold on the way down.
	_system.apply_damage(GameEnumsClass.Target.BOSS, 800.0)

	# Assert — one phase change (30% threshold) fires, then boss_defeated
	assert_eq(
		_mock_bus.boss_phase_changed_call_count,
		1,
		"One phase transition (30% threshold) must fire on the overkill hit"
	)
	assert_eq(
		_mock_bus.boss_phase_changed_history[0],
		[2, 3],
		"The phase transition on overkill must be (2, 3)"
	)
	assert_eq(
		_mock_bus.boss_defeated_call_count,
		1,
		"boss_defeated must fire exactly once on the overkill hit"
	)
	assert_eq(
		_system.current_boss_hp,
		0.0,
		"current_boss_hp must be 0.0 after overkill"
	)

# ---------------------------------------------------------------------------
# boss_hp_changed phase arg is old phase on threshold-crossing frame
# ---------------------------------------------------------------------------

func test_apply_damage_boss_hp_changed_carries_old_phase_on_threshold_frame() -> void:
	# Arrange — boss at 650 HP; 75 damage crosses 60% threshold
	_system.current_boss_hp = 650.0

	# Act
	_system.apply_damage(GameEnumsClass.Target.BOSS, 75.0)

	# Assert — boss_hp_changed is emitted BEFORE _check_phase_transitions runs,
	# so the phase arg reflects the phase at emission time (Phase 1, not 2).
	assert_eq(
		_mock_bus.last_boss_hp_changed_phase,
		1,
		"boss_hp_changed phase arg must be 1 (old phase) on the frame the 60% threshold is crossed"
	)

# ---------------------------------------------------------------------------
# AC-7: No literal 1000.0 in health_damage_system.gd logic section
# ---------------------------------------------------------------------------

func test_health_damage_system_has_no_boss_max_hp_literal() -> void:
	# AC-7: The literal 1000.0 must not appear in the logic section of the source file.
	# Values must come from BossData, not be hardcoded.
	var f: FileAccess = FileAccess.open(
		"res://scripts/core/health_damage_system.gd",
		FileAccess.READ
	)
	assert_not_null(f, "health_damage_system.gd must be readable from res://")
	if f == null:
		return

	var found_literal: bool = false
	while not f.eof_reached():
		var line: String = f.get_line()
		# Skip comment lines — literals in doc comments are acceptable
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped.begins_with("##"):
			continue
		if "1000.0" in line:
			found_literal = true
			break
	f.close()

	assert_false(
		found_literal,
		"Literal '1000.0' must not appear in non-comment lines of health_damage_system.gd (TR-HDS-010)"
	)
