extends GutTest

## ParryTelegraphSystem Story 002 — Window Timing Formula + AttackData Override Lookup.
##
## ACs covered:
##   AC-02   Default telegraph durations from AttackData (no literals): LIGHT=0.8, HEAVY=1.2, SWEEP=1.5
##   AC-12   Window open/close times computed correctly for all three types
##   AC-02b  AttackData override applied when > 0
##   AC-23   No literal timing values in logic code (grep check documented below)

const _PTS_SCRIPT: GDScript = preload("res://scripts/feature/parry_telegraph_system.gd")

var _pts: ParryTelegraphSystem
var _mock_bus: MockEventBus


func before_each() -> void:
	_mock_bus = MockEventBus.new()
	add_child_autofree(_mock_bus)
	_pts = _PTS_SCRIPT.new()
	_pts.initialize(_mock_bus)
	add_child_autofree(_pts)


func after_each() -> void:
	pass  # autofree handles cleanup


# ─── Helper: build AttackData with all overrides = 0 (use defaults) ──────────

func _make_default_attack_data(attack_type: GameEnums.AttackType) -> AttackData:
	var ad: AttackData = AttackData.new()
	ad.attack_type = attack_type
	# leave all _override fields at their exported defaults (0.0 = use system defaults)
	return ad


# ─── AC-02: Default telegraph durations from AttackData ──────────────────────

func test_pts_get_effective_duration_light_default_is_0_8s() -> void:
	# Arrange
	var ad: AttackData = _make_default_attack_data(GameEnums.AttackType.LIGHT)

	# Act
	var duration: float = _pts._get_effective_telegraph_duration(ad)

	# Assert
	assert_almost_eq(
		duration,
		0.8,
		0.001,
		"AC-02: LIGHT default telegraph_duration must be 0.8s"
	)


func test_pts_get_effective_duration_heavy_default_is_1_2s() -> void:
	# Arrange
	var ad: AttackData = _make_default_attack_data(GameEnums.AttackType.HEAVY)

	# Act
	var duration: float = _pts._get_effective_telegraph_duration(ad)

	# Assert
	assert_almost_eq(
		duration,
		1.2,
		0.001,
		"AC-02: HEAVY default telegraph_duration must be 1.2s"
	)


func test_pts_get_effective_duration_sweep_default_is_1_5s() -> void:
	# Arrange
	var ad: AttackData = _make_default_attack_data(GameEnums.AttackType.SWEEP)

	# Act
	var duration: float = _pts._get_effective_telegraph_duration(ad)

	# Assert
	assert_almost_eq(
		duration,
		1.5,
		0.001,
		"AC-02: SWEEP default telegraph_duration must be 1.5s"
	)


# ─── AC-12: Window open/close times computed correctly ───────────────────────

func test_pts_compute_window_times_light_default() -> void:
	# Arrange: put system in TELEGRAPHING via LIGHT attack so telegraph_duration is set.
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.LIGHT, 10.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")

	# Assert window times computed from GDD Formula 1:
	#   window_open_time  = 0.8 × 0.50 = 0.40s
	#   window_close_time = 0.40 + 0.30 = 0.70s
	assert_almost_eq(
		_pts.window_open_time,
		0.40,
		0.001,
		"AC-12: LIGHT window_open_time must be 0.40s"
	)
	assert_almost_eq(
		_pts.window_close_time,
		0.70,
		0.001,
		"AC-12: LIGHT window_close_time must be 0.70s"
	)


func test_pts_compute_window_times_heavy_default() -> void:
	# Arrange
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")

	# Assert:
	#   window_open_time  = 1.2 × 0.50 = 0.60s
	#   window_close_time = 0.60 + 0.35 = 0.95s
	assert_almost_eq(
		_pts.window_open_time,
		0.60,
		0.001,
		"AC-12: HEAVY window_open_time must be 0.60s"
	)
	assert_almost_eq(
		_pts.window_close_time,
		0.95,
		0.001,
		"AC-12: HEAVY window_close_time must be 0.95s"
	)


func test_pts_compute_window_times_sweep_default() -> void:
	# Arrange
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.SWEEP, 30.0)
	assert_eq(_pts.system_state, _PTS_SCRIPT.ParryState.TELEGRAPHING, "precondition: TELEGRAPHING")

	# Assert:
	#   window_open_time  = 1.5 × 0.50 = 0.75s
	#   window_close_time = 0.75 + 0.45 = 1.20s
	assert_almost_eq(
		_pts.window_open_time,
		0.75,
		0.001,
		"AC-12: SWEEP window_open_time must be 0.75s"
	)
	assert_almost_eq(
		_pts.window_close_time,
		1.20,
		0.001,
		"AC-12: SWEEP window_close_time must be 1.20s"
	)


# ─── AC-12 live: window_open toggled correctly by _physics_process ────────────

func test_pts_window_open_becomes_true_during_window_heavy() -> void:
	# Arrange: HEAVY telegraph (window: 0.60s–0.95s)
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)
	assert_almost_eq(_pts.window_open_time, 0.60, 0.001, "precondition: window opens at 0.60s")

	# Advance to just before window — should be closed.
	_pts._physics_process(0.55)
	assert_false(_pts.window_open, "AC-12 live: window_open must be false at t=0.55s (PRE_WINDOW)")

	# Advance into window.
	_pts._physics_process(0.10)  # t = 0.65s — within [0.60, 0.95]
	assert_true(_pts.window_open, "AC-12 live: window_open must be true at t=0.65s (WINDOW_OPEN)")

	# Advance past window.
	_pts._physics_process(0.35)  # t = 1.00s — past 0.95s
	assert_false(_pts.window_open, "AC-12 live: window_open must be false at t=1.00s (POST_WINDOW)")


func test_pts_window_open_at_exact_open_boundary_heavy() -> void:
	# AC-12 + GDD closed-interval: timer == window_open_time → window_open = true
	# Arrange
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)

	# Drive timer to exactly window_open_time in one step.
	# telegraph_timer starts at 0.0; advance exactly 0.60s.
	_pts._physics_process(0.60)

	assert_almost_eq(_pts.telegraph_timer, 0.60, 0.001, "precondition: timer at 0.60s")
	assert_true(
		_pts.window_open,
		"AC-12: window_open must be true at exactly window_open_time (closed interval)"
	)


func test_pts_window_open_at_exact_close_boundary_heavy() -> void:
	# AC-12 + GDD closed-interval: timer == window_close_time → window_open = true
	_mock_bus.attack_telegraphed.emit(GameEnums.AttackType.HEAVY, 25.0)

	# Advance to exactly window_close_time = 0.95s.
	_pts._physics_process(0.95)

	assert_almost_eq(_pts.telegraph_timer, 0.95, 0.001, "precondition: timer at 0.95s")
	assert_true(
		_pts.window_open,
		"AC-12: window_open must be true at exactly window_close_time (closed interval)"
	)


# ─── AC-02b: AttackData override applied when > 0 ────────────────────────────

func test_pts_get_effective_duration_uses_override_when_positive() -> void:
	# Arrange: AttackData with override = 2.0
	var ad: AttackData = AttackData.new()
	ad.attack_type = GameEnums.AttackType.HEAVY
	ad.telegraph_duration_override = 2.0
	ad.window_width_override = 0.5
	ad.window_open_fraction_override = 0.6

	# Act
	var duration: float = _pts._get_effective_telegraph_duration(ad)

	# Assert: override wins over type default (1.2s)
	assert_almost_eq(
		duration,
		2.0,
		0.001,
		"AC-02b: telegraph_duration_override = 2.0 must be returned (not 1.2 default)"
	)


func test_pts_compute_window_times_with_overrides() -> void:
	# AC-02b: given override duration=2.0, fraction=0.6, width=0.5
	#   window_open_time  = 2.0 × 0.6 = 1.2s
	#   window_close_time = 1.2 + 0.5 = 1.7s

	# Arrange: inject custom AttackData directly into _current_attack_data
	# then set telegraph_duration manually (as _enter_state would), then call _compute_window_times.
	var ad: AttackData = AttackData.new()
	ad.attack_type = GameEnums.AttackType.HEAVY
	ad.telegraph_duration_override = 2.0
	ad.window_width_override = 0.5
	ad.window_open_fraction_override = 0.6

	_pts._current_attack_data = ad
	_pts.telegraph_duration = _pts._get_effective_telegraph_duration(ad)
	_pts._compute_window_times(ad)

	# Assert
	assert_almost_eq(
		_pts.telegraph_duration,
		2.0,
		0.001,
		"AC-02b: telegraph_duration must be 2.0 (override)"
	)
	assert_almost_eq(
		_pts.window_open_time,
		1.2,
		0.001,
		"AC-02b: window_open_time must be 2.0 × 0.6 = 1.2s"
	)
	assert_almost_eq(
		_pts.window_close_time,
		1.7,
		0.001,
		"AC-02b: window_close_time must be 1.2 + 0.5 = 1.7s"
	)


func test_pts_window_width_override_used_when_positive() -> void:
	# Arrange
	var ad: AttackData = AttackData.new()
	ad.attack_type = GameEnums.AttackType.LIGHT
	ad.window_width_override = 0.60  # overrides default 0.30

	# Act
	var width: float = _pts._get_effective_window_width(ad)

	# Assert
	assert_almost_eq(
		width,
		0.60,
		0.001,
		"AC-02b: window_width_override = 0.60 must be returned (not 0.30 default)"
	)


func test_pts_window_open_fraction_override_used_when_positive() -> void:
	# Arrange
	var ad: AttackData = AttackData.new()
	ad.attack_type = GameEnums.AttackType.LIGHT
	ad.window_open_fraction_override = 0.70  # overrides default 0.50

	# Act
	var fraction: float = _pts._get_effective_window_open_fraction(ad)

	# Assert
	assert_almost_eq(
		fraction,
		0.70,
		0.001,
		"AC-02b: window_open_fraction_override = 0.70 must be returned (not 0.50 default)"
	)


# ─── AC-23: No literal timing values in logic — structural documentation ──────
#
# AC-23 requires that the values 0.8, 1.2, 1.5, 0.30, 0.35, 0.45, 0.50 do NOT
# appear as floating-point literals in the _logic_ paths of
# parry_telegraph_system.gd.  They exist only inside the `const` block, which
# is the approved exception stated in the story spec.
#
# This is verified at CI time by grep (or rg).  The test below is an
# implementation-presence check: if the const symbols are reachable, the
# logic-path constraint is implicitly satisfied by the code review gate.

func test_pts_default_duration_consts_accessible_and_correct() -> void:
	# Verify the const block values are exactly the GDD baseline numbers.
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_DURATION_LIGHT,
		0.8,
		0.001,
		"AC-23 const check: _DEFAULT_DURATION_LIGHT must equal 0.8"
	)
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_DURATION_HEAVY,
		1.2,
		0.001,
		"AC-23 const check: _DEFAULT_DURATION_HEAVY must equal 1.2"
	)
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_DURATION_SWEEP,
		1.5,
		0.001,
		"AC-23 const check: _DEFAULT_DURATION_SWEEP must equal 1.5"
	)


func test_pts_default_window_width_consts_accessible_and_correct() -> void:
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_WINDOW_WIDTH_LIGHT,
		0.30,
		0.001,
		"AC-23 const check: _DEFAULT_WINDOW_WIDTH_LIGHT must equal 0.30"
	)
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_WINDOW_WIDTH_HEAVY,
		0.35,
		0.001,
		"AC-23 const check: _DEFAULT_WINDOW_WIDTH_HEAVY must equal 0.35"
	)
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_WINDOW_WIDTH_SWEEP,
		0.45,
		0.001,
		"AC-23 const check: _DEFAULT_WINDOW_WIDTH_SWEEP must equal 0.45"
	)


func test_pts_default_window_open_fraction_const_accessible_and_correct() -> void:
	assert_almost_eq(
		_PTS_SCRIPT._DEFAULT_WINDOW_OPEN_FRACTION,
		0.50,
		0.001,
		"AC-23 const check: _DEFAULT_WINDOW_OPEN_FRACTION must equal 0.50"
	)
