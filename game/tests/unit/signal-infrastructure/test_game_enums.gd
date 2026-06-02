extends GutTest


# AC-1: GameEnums plain class is accessible and constructible
func test_game_enums_class_is_accessible() -> void:
	var instance: GameEnums = GameEnums.new()
	assert_not_null(instance, "GameEnums.new() should return a non-null instance")


# AC-2a: AttackType ordinal stability
func test_attack_type_light_equals_zero() -> void:
	assert_eq(GameEnums.AttackType.LIGHT, 0, "AttackType.LIGHT must be 0")


func test_attack_type_heavy_equals_one() -> void:
	assert_eq(GameEnums.AttackType.HEAVY, 1, "AttackType.HEAVY must be 1")


func test_attack_type_sweep_equals_two() -> void:
	assert_eq(GameEnums.AttackType.SWEEP, 2, "AttackType.SWEEP must be 2")


# AC-2b: ComboState ordinal stability
func test_combo_state_idle_equals_zero() -> void:
	assert_eq(GameEnums.ComboState.IDLE, 0, "ComboState.IDLE must be 0")


func test_combo_state_counter_window_open_equals_one() -> void:
	assert_eq(GameEnums.ComboState.COUNTER_WINDOW_OPEN, 1, "ComboState.COUNTER_WINDOW_OPEN must be 1")


func test_combo_state_bonus_stagger_equals_two() -> void:
	assert_eq(GameEnums.ComboState.BONUS_STAGGER, 2, "ComboState.BONUS_STAGGER must be 2")


# AC-2c: Target ordinal stability
func test_target_player_equals_zero() -> void:
	assert_eq(GameEnums.Target.PLAYER, 0, "Target.PLAYER must be 0")


func test_target_boss_equals_one() -> void:
	assert_eq(GameEnums.Target.BOSS, 1, "Target.BOSS must be 1")


# AC-2d: PlayerState ordinal stability
func test_player_state_idle_equals_zero() -> void:
	assert_eq(GameEnums.PlayerState.IDLE, 0, "PlayerState.IDLE must be 0")


func test_player_state_running_equals_one() -> void:
	assert_eq(GameEnums.PlayerState.RUNNING, 1, "PlayerState.RUNNING must be 1")


func test_player_state_airborne_equals_two() -> void:
	assert_eq(GameEnums.PlayerState.AIRBORNE, 2, "PlayerState.AIRBORNE must be 2")


func test_player_state_parrying_equals_three() -> void:
	assert_eq(GameEnums.PlayerState.PARRYING, 3, "PlayerState.PARRYING must be 3")


func test_player_state_dodging_equals_four() -> void:
	assert_eq(GameEnums.PlayerState.DODGING, 4, "PlayerState.DODGING must be 4")


func test_player_state_hit_stun_equals_five() -> void:
	assert_eq(GameEnums.PlayerState.HIT_STUN, 5, "PlayerState.HIT_STUN must be 5")


func test_player_state_dead_equals_six() -> void:
	assert_eq(GameEnums.PlayerState.DEAD, 6, "PlayerState.DEAD must be 6")


# AC-6: Enum value count matches expected
func test_attack_type_has_exactly_three_values() -> void:
	assert_eq(GameEnums.AttackType.keys().size(), 3, "AttackType must have exactly 3 values")


func test_combo_state_has_exactly_three_values() -> void:
	assert_eq(GameEnums.ComboState.keys().size(), 3, "ComboState must have exactly 3 values")


func test_target_has_exactly_two_values() -> void:
	assert_eq(GameEnums.Target.keys().size(), 2, "Target must have exactly 2 values")


func test_player_state_has_exactly_seven_values() -> void:
	assert_eq(GameEnums.PlayerState.keys().size(), 7, "PlayerState must have exactly 7 values")
