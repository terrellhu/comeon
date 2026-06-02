class_name BossDataLoader
extends Node

## BossDataLoader — Foundation Layer
##
## Loads BossData resources from [code]res://data/bosses/{boss_id}.tres[/code],
## validates them at load time, and caches the result for O(1) subsequent access.
##
## [b]Usage:[/b]
## [codeblock]
## var loader := BossDataLoader.new()
## var data: BossData = loader.get_boss_data(&"boss_01")
## [/codeblock]
##
## Validation enforces correctness contracts on load so that combat systems
## receive only well-formed data. Invalid data crashes loudly in Debug builds
## (assert) or clamps + warns for non-fatal issues (push_warning + clamp).
##
## [b]Source:[/b] ADR-0002, TR-BSM-009, Story 002

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Minimum permitted value for idle_duration_after_attack and
## telegraph_duration_override.  Matches the GDD 0.1 s minimum.
const MIN_DURATION: float = 0.1

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the [BossData] resource for the given [param boss_id].
##
## On first call the resource is loaded from
## [code]res://data/bosses/{boss_id}.tres[/code], validated, and cached.
## Subsequent calls return the cached reference in O(1).
##
## [b]Thread safety:[/b] not thread-safe — call from the main thread only.
func get_boss_data(boss_id: StringName) -> BossData:
	if _cache.has(boss_id):
		return _cache[boss_id] as BossData

	var path: String = "res://data/bosses/%s.tres" % boss_id
	assert(ResourceLoader.exists(path), "BossData not found: %s" % path)

	var data: BossData = ResourceLoader.load(path) as BossData
	assert(data != null, "Resource at '%s' is not a BossData — wrong type or corrupt sub-resource" % path)
	_validate(data)
	_cache[boss_id] = data
	return data

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates [param data] against all BossData correctness contracts.
##
## Fatal errors use [code]assert()[/code] — they crash in Debug builds and
## must be fixed before shipping.  Non-fatal issues are clamped to the nearest
## valid value and reported via [code]push_warning()[/code].
##
## Called automatically by [method get_boss_data]; may also be called directly
## in GUT tests using [code]BossData.new()[/code] instances.
func _validate(data: BossData) -> void:
	# --- Top-level BossData checks ---
	assert(data.boss_id != &"", "BossData.boss_id must not be empty")
	assert(data.boss_max_hp > 0.0, "BossData.boss_max_hp must be > 0")
	assert(data.phases.size() > 0, "BossData.phases must not be empty")

	# --- Per-phase checks ---
	for phase: PhaseData in data.phases:
		assert(
			phase.attack_sequence.size() > 0,
			"PhaseData.attack_sequence must not be empty (phase_index %d)" % phase.phase_index
		)

		# idle_duration_after_attack: clamp if <= 0 or < MIN_DURATION
		# Intentional in-place mutation: ADR-0002 defers duplicate_deep() to Alpha.
		# Invariant: exactly one BossDataLoader may load a given boss_id per process.
		if phase.idle_duration_after_attack <= 0.0:
			push_warning(
				"PhaseData.idle_duration_after_attack <= 0 on phase_index %d — clamped to %s s"
					% [phase.phase_index, MIN_DURATION]
			)
			phase.idle_duration_after_attack = MIN_DURATION
		elif phase.idle_duration_after_attack < MIN_DURATION:
			push_warning(
				"PhaseData.idle_duration_after_attack %.4f < %.4f s on phase_index %d — clamped to %.4f s"
					% [phase.idle_duration_after_attack, MIN_DURATION, phase.phase_index, MIN_DURATION]
			)
			phase.idle_duration_after_attack = MIN_DURATION

		# --- Per-attack checks ---
		for attack: AttackData in phase.attack_sequence:
			if attack.telegraph_duration_override > 0.0 and attack.telegraph_duration_override < MIN_DURATION:
				push_warning(
					"AttackData.telegraph_duration_override %.4f < %.4f s — clamped to %s s"
						% [attack.telegraph_duration_override, MIN_DURATION, MIN_DURATION]
				)
				attack.telegraph_duration_override = MIN_DURATION

	# --- phase_threshold_pct must be strictly descending ---
	for i: int in range(1, data.phase_threshold_pct.size()):
		assert(
			data.phase_threshold_pct[i] < data.phase_threshold_pct[i - 1],
			(
				"BossData.phase_threshold_pct must be in strictly descending order "
				+ "(index %d: %.4f >= index %d: %.4f)"
					% [i, data.phase_threshold_pct[i], i - 1, data.phase_threshold_pct[i - 1]]
			)
		)
