class_name HealthDamageSystem
extends Node

## HealthDamageSystem — Core Layer
##
## Single authority for all HP mutation in the game. Owns the player HP pool
## and the Boss HP pool. Stories 002–007 add the remaining behaviour.
##
## Story 001: HP initialization and BossData contract.
## Story 002: Player damage application and invulnerability window.
## Story 003: Player death detection and HP clamping.
## Story 005: Boss HP deduction, phase detection, and defeat emission.
##
## [b]Usage (production):[/b]
## [codeblock]
## health_damage_system.initialize()        # uses global EventBus Autoload
## health_damage_system.init_battle(boss_data)
## [/codeblock]
##
## [b]Usage (GUT tests):[/b]
## [codeblock]
## health_damage_system.initialize(mock_bus) # injects mock, no global Autoload needed
## health_damage_system.init_battle(_make_test_boss())
## [/codeblock]
##
## [b]Source:[/b] ADR-0001, ADR-0002, TR-HDS-001, TR-HDS-002, TR-HDS-003,
## TR-HDS-004, TR-HDS-005, TR-HDS-006, TR-HDS-009, TR-HDS-010, TR-HDS-011,
## TR-HDS-013, TR-HDS-014, TR-HDS-015,
## Story 001, Story 002, Story 003, Story 004, Story 005

# ---------------------------------------------------------------------------
# Export vars — player-side tuning knobs (no gameplay literals in logic)
# ---------------------------------------------------------------------------

## Maximum player HP. All healing is clamped to this value.
@export var player_max_hp: float = 100.0

## Number of visual HP segments shown in the HUD.
@export var player_hp_segments: int = 5

## Duration of the post-hit invulnerability window in seconds.
@export var player_hit_invuln_duration: float = 0.5

# ---------------------------------------------------------------------------
# Public state (read-only — write only via apply_damage / apply_healing)
# ---------------------------------------------------------------------------

## Current player HP. Range: [0, player_max_hp].
var current_player_hp: float = 0.0

## Current boss HP. Range: [0, boss_max_hp]. Loaded from BossData on init_battle().
var current_boss_hp: float = 0.0

## Boss max HP from the active BossData asset. 0.0 until init_battle() is called.
var boss_max_hp: float = 0.0

## Current boss phase index. Starts at 1 (Phase 1) after init_battle(); increments as
## thresholds are crossed. Read-only — written only by _check_phase_transitions().
var current_boss_phase: int = 0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Injected or global EventBus reference. Set by initialize().
## Typed as Node to allow MockEventBus injection in GUT tests — EventBus has no
## class_name, so @warning_ignore("unsafe_property_access") is required on emit sites.
var _event_bus: Node = null

## BossData asset active for the current battle. Set by init_battle().
var _boss_data: BossData = null

## Remaining seconds of post-hit invulnerability. > 0 means INVULNERABLE.
## Decremented every physics tick. Never reset while already > 0.
var _invuln_timer: float = 0.0

## Tracks which phase thresholds have already been crossed, keyed by 0-based
## threshold array index. Prevents re-emission of boss_phase_changed for the
## same threshold (e.g. after a heal-then-damage cycle).
var _entered_phases: Dictionary[int, bool] = {}

## Set to true the moment boss_defeated is emitted. Any further
## apply_damage(BOSS, …) calls become a complete no-op while this is true.
var _is_boss_defeated: bool = false

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func _ready() -> void:
	if _event_bus == null:
		initialize()


## Stores the EventBus reference for signal emission.
##
## Call before [method init_battle]. In GUT tests, pass [param event_bus] as a
## MockEventBus instance; in production, omit the argument to use the global
## EventBus Autoload.
func initialize(event_bus: Node = null) -> void:
	if event_bus != null:
		_event_bus = event_bus
	else:
		_event_bus = EventBus as Node


## Initializes both HP pools from [param boss_data].
##
## [param boss_data] must not be null and must have [code]boss_max_hp > 0[/code].
## Call after [method initialize].
func init_battle(boss_data: BossData) -> void:
	assert(boss_data != null, "HealthDamageSystem.init_battle: boss_data must not be null")
	assert(boss_data.boss_max_hp > 0.0, "HealthDamageSystem.init_battle: boss_max_hp must be > 0")

	_boss_data = boss_data
	boss_max_hp = boss_data.boss_max_hp
	current_boss_hp = boss_data.boss_max_hp
	current_boss_phase = 1

	_entered_phases = {}
	_is_boss_defeated = false

	current_player_hp = player_max_hp
	_invuln_timer = 0.0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

## Ticks the invulnerability timer. Uses physics_process for deterministic cadence.
func _physics_process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)

# ---------------------------------------------------------------------------
# Public — damage API (Story 002)
# ---------------------------------------------------------------------------

## Applies [param amount] of damage to [param target].
##
## Guards (applied in order):
## 1. If [param amount] <= 0.0: no-op — no HP change, no signal, no invuln window.
## 2. (PLAYER only) If [member _invuln_timer] > 0.0: damage ignored, timer NOT reset.
##
## On a successful hit (PLAYER):
## - Subtracts [param amount] from [member current_player_hp], clamped to 0.0
##   (negative HP is never stored).
## - Sets [member _invuln_timer] = [member player_hit_invuln_duration].
## - Emits [signal EventBus.player_hp_changed] exactly once.
## - If HP reaches 0, emits [signal EventBus.player_died] immediately after
##   [signal EventBus.player_hp_changed] — same call stack, no frame gap.
##
## Damage formula: flat deduction, no scaling, no rounding (Story 002 contract).
##
## [b]Source:[/b] TR-HDS-002, TR-HDS-003, TR-HDS-004, TR-HDS-011, TR-HDS-013,
## TR-HDS-015
@warning_ignore("unsafe_property_access")
func apply_damage(target: GameEnums.Target, amount: float) -> void:
	assert(_event_bus != null, "HealthDamageSystem.apply_damage: call initialize() before use")
	# Guard 1 — zero or negative amount is always a no-op
	if amount <= 0.0:
		return

	if target == GameEnums.Target.PLAYER:
		# Guard 2 — already invulnerable; do NOT reset the timer
		if _invuln_timer > 0.0:
			return

		current_player_hp = maxf(current_player_hp - amount, 0.0)
		_invuln_timer = player_hit_invuln_duration
		_event_bus.player_hp_changed.emit(current_player_hp, player_max_hp)

		# Death check — emit after player_hp_changed so subscribers see updated HP first.
		# The invuln window (set above) prevents duplicate player_died on subsequent hits.
		if current_player_hp <= 0.0:
			_event_bus.player_died.emit()

	elif target == GameEnums.Target.BOSS:
		# Guard 2 — boss already defeated; all further hits are no-ops
		if _is_boss_defeated:
			return

		current_boss_hp = maxf(current_boss_hp - amount, 0.0)
		_event_bus.boss_hp_changed.emit(current_boss_hp, boss_max_hp, current_boss_phase)

		# Phase detection — must run before defeat check so the final phase transition
		# (if any) fires before boss_defeated.
		_check_phase_transitions()

		# Defeat check — guard ensures boss_defeated emits exactly once
		if current_boss_hp <= 0.0:
			_is_boss_defeated = true
			_event_bus.boss_defeated.emit()

# ---------------------------------------------------------------------------
# Public — healing API (Story 004)
# ---------------------------------------------------------------------------

## Restores [param amount] of HP to [param target], clamped to [member player_max_hp].
##
## Emits [signal EventBus.player_hp_changed] on every call, including when already
## at full HP (heal at full is not an error — AC-3).
## BOSS target is not used in MVP; logs a warning and returns.
##
## Healing does NOT clear or modify [member _invuln_timer].
##
## [b]Source:[/b] TR-HDS-008, ADR-0001, Story 004
@warning_ignore("unsafe_property_access")
func apply_healing(target: GameEnums.Target, amount: float) -> void:
	assert(_event_bus != null, "HealthDamageSystem.apply_healing: call initialize() before use")
	if target == GameEnums.Target.PLAYER:
		current_player_hp = minf(current_player_hp + amount, player_max_hp)
		_event_bus.player_hp_changed.emit(current_player_hp, player_max_hp)
	else:
		push_warning("apply_healing: BOSS healing not implemented in MVP — ignoring")

# ---------------------------------------------------------------------------
# Public — inspection helpers
# ---------------------------------------------------------------------------

## Returns the remaining invulnerability time in seconds (>= 0.0).
## Intended for GUT tests and HUD reads. Do not write to [member _invuln_timer] directly.
func get_invuln_timer() -> float:
	return _invuln_timer

# ---------------------------------------------------------------------------
# Private — boss phase detection (Story 005)
# ---------------------------------------------------------------------------

## Iterates [member _boss_data.phase_threshold_pct] in ascending index order.
## For each threshold not yet in [member _entered_phases], checks whether
## [code]current_boss_hp / boss_max_hp[/code] has fallen to or below that
## threshold. When crossed, emits [signal EventBus.boss_phase_changed] with
## the old and new phase indices, increments [member current_boss_phase], and
## records the threshold index in [member _entered_phases].
##
## Iterating the full threshold array on every call is O(threshold_count) —
## with 2 thresholds this is O(1) in practice and within TR-HDS-015 budget.
##
## [b]Source:[/b] TR-HDS-005, TR-HDS-006, Story 005 Implementation Notes
@warning_ignore("unsafe_property_access")
func _check_phase_transitions() -> void:
	if boss_max_hp == 0.0:
		return
	var thresholds: Array[float] = _boss_data.phase_threshold_pct
	var hp_fraction: float = current_boss_hp / boss_max_hp

	for i: int in range(thresholds.size()):
		if _entered_phases.has(i):
			continue
		if hp_fraction <= thresholds[i]:
			var from_phase: int = current_boss_phase
			current_boss_phase += 1
			_entered_phases[i] = true
			_event_bus.boss_phase_changed.emit(from_phase, current_boss_phase)
