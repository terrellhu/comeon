extends GutTest

## Unit tests for RetryContextNode — Story 001: RetryContext Autoload.
##
## Covers:
##   AC-04   — save_context / load_context round-trip
##   AC-10   — clear_context resets preserved HP and phase; death_count preserved
##   AC-13   — session_death_count stored exactly as passed
##   AC-is_fresh_start — is_fresh_start() sentinel logic
##
## GUT naming rule: file prefix is "test_" (auto-detected by runner).
## Do NOT add class_name — headless GUT runner does not support it on test files.

# ---------------------------------------------------------------------------
# Preload — explicit path; no class_name reliance (headless-safe)
# ---------------------------------------------------------------------------

const RetryContextClass = preload("res://autoloads/retry_context.gd")

# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

var _ctx: RetryContextNode

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	_ctx = RetryContextClass.new()
	add_child_autofree(_ctx)

# ---------------------------------------------------------------------------
# AC-04: save_context / load_context round-trip
# ---------------------------------------------------------------------------

func test_retry_context_save_load_round_trip_returns_exact_values() -> void:
	# Arrange — freshly initialized; preserved_boss_hp == -1.0
	# Act
	_ctx.save_context(350.0, 1, 3)
	var result: Dictionary = _ctx.load_context()

	# Assert
	assert_eq(result["boss_hp"],    350.0, "load_context boss_hp must equal saved value exactly")
	assert_eq(result["boss_phase"], 1,     "load_context boss_phase must equal saved value exactly")
	assert_eq(result["death_count"], 3,    "load_context death_count must equal saved value exactly")


func test_retry_context_save_load_boss_hp_zero_edge_case() -> void:
	# Edge: boss_hp = 0.0 (Phase 1 hit to zero) must round-trip without becoming -1.0
	_ctx.save_context(0.0, 1, 1)

	var result: Dictionary = _ctx.load_context()

	assert_eq(result["boss_hp"], 0.0, "boss_hp = 0.0 must survive round-trip intact")


func test_retry_context_save_load_phase_two_preserved() -> void:
	# Edge: boss_phase = 2 (Phase 2 preserved across retry)
	_ctx.save_context(250.0, 2, 5)

	var result: Dictionary = _ctx.load_context()

	assert_eq(result["boss_phase"], 2, "boss_phase = 2 must survive round-trip intact")

# ---------------------------------------------------------------------------
# AC-10: clear_context resets preserved HP and phase; death_count NOT cleared
# ---------------------------------------------------------------------------

func test_retry_context_clear_resets_preserved_boss_hp() -> void:
	# Arrange
	_ctx.save_context(100.0, 2, 7)

	# Act
	_ctx.clear_context()

	# Assert
	assert_eq(_ctx.preserved_boss_hp, -1.0, "clear_context must reset preserved_boss_hp to -1.0")


func test_retry_context_clear_resets_preserved_boss_phase() -> void:
	_ctx.save_context(100.0, 2, 7)

	_ctx.clear_context()

	assert_eq(_ctx.preserved_boss_phase, 0, "clear_context must reset preserved_boss_phase to 0")


func test_retry_context_clear_preserves_session_death_count() -> void:
	# death_count must NOT be cleared — it accumulates across boss fights
	_ctx.save_context(100.0, 2, 7)

	_ctx.clear_context()

	assert_eq(_ctx.session_death_count, 7, "clear_context must NOT clear session_death_count")


func test_retry_context_clear_on_never_saved_is_noop_no_crash() -> void:
	# Edge: calling clear_context() when nothing was ever saved must not crash
	_ctx.clear_context()  # should be a no-op

	assert_eq(_ctx.preserved_boss_hp,   -1.0, "preserved_boss_hp must remain -1.0")
	assert_eq(_ctx.preserved_boss_phase, 0,   "preserved_boss_phase must remain 0")
	assert_eq(_ctx.session_death_count,  0,   "session_death_count must remain 0")

# ---------------------------------------------------------------------------
# AC-13: session_death_count stored correctly
# ---------------------------------------------------------------------------

func test_retry_context_save_stores_death_count_one() -> void:
	# Arrange — caller computes count+1 externally before calling save_context
	# Act
	_ctx.save_context(200.0, 0, 1)

	# Assert
	assert_eq(_ctx.load_context()["death_count"], 1,
		"death_count must be stored as-is (caller is responsible for incrementing)")


func test_retry_context_save_stores_death_count_fifty_no_truncation() -> void:
	# Edge: N = 50 — no cap, no truncation
	_ctx.save_context(400.0, 1, 50)

	assert_eq(_ctx.load_context()["death_count"], 50,
		"death_count = 50 must be stored without truncation or cap")

# ---------------------------------------------------------------------------
# AC-is_fresh_start: fresh start sentinel logic
# ---------------------------------------------------------------------------

func test_retry_context_fresh_start_returns_true_on_init() -> void:
	# A newly created RetryContextNode has no saved data
	assert_true(_ctx.is_fresh_start(),
		"is_fresh_start() must return true on a freshly initialized Autoload")


func test_retry_context_fresh_start_returns_false_after_save() -> void:
	_ctx.save_context(100.0, 0, 1)

	assert_false(_ctx.is_fresh_start(),
		"is_fresh_start() must return false after save_context() is called")


func test_retry_context_fresh_start_returns_true_after_clear() -> void:
	_ctx.save_context(100.0, 0, 1)
	_ctx.clear_context()

	assert_true(_ctx.is_fresh_start(),
		"is_fresh_start() must return true again after clear_context()")


func test_retry_context_fresh_start_boss_hp_zero_not_treated_as_fresh() -> void:
	# Edge: boss_hp = 0.0 is a valid saved value — must NOT be treated as fresh start
	# (only -1.0 is the sentinel)
	_ctx.save_context(0.0, 1, 2)

	assert_false(_ctx.is_fresh_start(),
		"boss_hp = 0.0 must not be treated as fresh start — sentinel is -1.0 only")
