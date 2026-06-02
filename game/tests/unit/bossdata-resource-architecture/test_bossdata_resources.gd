extends GutTest

const AttackData = preload("res://scripts/data/attack_data.gd")
const PhaseData = preload("res://scripts/data/phase_data.gd")
const BossData = preload("res://scripts/data/boss_data.gd")
const GameEnums = preload("res://scripts/data/game_enums.gd")

# AC-5 (no literals) verified at story-done via grep — not a runtime test


# AC-4: All three types preload-accessible in headless GUT
func test_attack_data_preload_returns_non_null_instance() -> void:
	assert_not_null(AttackData.new(), "AttackData.new() must return a non-null instance")


func test_phase_data_preload_returns_non_null_instance() -> void:
	assert_not_null(PhaseData.new(), "PhaseData.new() must return a non-null instance")


func test_boss_data_preload_returns_non_null_instance() -> void:
	assert_not_null(BossData.new(), "BossData.new() must return a non-null instance")


# AC-1: AttackData has correct @export fields with correct defaults
func test_attack_data_default_attack_type_is_light() -> void:
	var attack := AttackData.new()
	assert_eq(attack.attack_type, GameEnums.AttackType.LIGHT,
		"AttackData.attack_type default must be LIGHT (0)")


func test_attack_data_default_damage_is_ten() -> void:
	var attack := AttackData.new()
	assert_eq(attack.damage, 10.0, "AttackData.damage default must be 10.0")


func test_attack_data_default_telegraph_duration_override_is_zero() -> void:
	var attack := AttackData.new()
	assert_eq(attack.telegraph_duration_override, 0.0,
		"AttackData.telegraph_duration_override default must be 0.0")


# AC-2: PhaseData has correct @export fields with correct defaults
func test_phase_data_default_phase_index_is_zero() -> void:
	var phase := PhaseData.new()
	assert_eq(phase.phase_index, 0, "PhaseData.phase_index default must be 0")


func test_phase_data_default_attack_sequence_is_empty() -> void:
	var phase := PhaseData.new()
	assert_eq(phase.attack_sequence.size(), 0,
		"PhaseData.attack_sequence must be empty by default")


func test_phase_data_default_idle_duration_after_attack_is_half_second() -> void:
	var phase := PhaseData.new()
	assert_eq(phase.idle_duration_after_attack, 0.5,
		"PhaseData.idle_duration_after_attack default must be 0.5")


func test_phase_data_default_phase_transition_anim_is_empty_string_name() -> void:
	var phase := PhaseData.new()
	assert_eq(phase.phase_transition_anim, &"",
		"PhaseData.phase_transition_anim default must be &\"\"")


# AC-3: BossData has correct @export fields with correct defaults
func test_boss_data_default_boss_id_is_empty_string_name() -> void:
	var boss := BossData.new()
	assert_eq(boss.boss_id, &"", "BossData.boss_id default must be &\"\"")


func test_boss_data_default_boss_max_hp_is_one_thousand() -> void:
	var boss := BossData.new()
	assert_eq(boss.boss_max_hp, 1000.0, "BossData.boss_max_hp default must be 1000.0")


func test_boss_data_default_phases_is_empty() -> void:
	var boss := BossData.new()
	assert_eq(boss.phases.size(), 0, "BossData.phases must be empty by default")


# AC-5: Array[AttackData] assignment works
func test_phase_data_attack_sequence_accepts_attack_data_instance() -> void:
	var attack := AttackData.new()
	var phase := PhaseData.new()
	phase.attack_sequence = [attack]
	assert_eq(phase.attack_sequence.size(), 1,
		"PhaseData.attack_sequence must accept an AttackData instance (size 1)")


# Bonus: BossData.phases accepts PhaseData instances
func test_boss_data_phases_accepts_phase_data_instance() -> void:
	var phase := PhaseData.new()
	var boss := BossData.new()
	boss.phases = [phase]
	assert_eq(boss.phases.size(), 1,
		"BossData.phases must accept a PhaseData instance (size 1)")
