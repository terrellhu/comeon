class_name RetryContextNode
extends Node

## RetryContext — Foundation Layer Autoload
##
## Pure data store for cross-retry persistence. Holds Boss HP and phase at the
## moment of player death so InstantRetrySystem can restore them after reset.
##
## [b]Autoload name:[/b] "RetryContext"
## [b]Registration order:[/b] EventBus → RetryContext → HitpauseManager
##
## [b]Usage (production):[/b]
## [codeblock]
## RetryContext.save_context(health_system.current_boss_hp, health_system.current_boss_phase, RetryContext.session_death_count + 1)
## var ctx := RetryContext.load_context()   # keys: "boss_hp", "boss_phase", "death_count"
## RetryContext.clear_context()             # on boss_defeated
## [/codeblock]
##
## [b]Source:[/b] ADR-0003, TR-IRS-005, TR-IRS-010, TR-IRS-011, Story 001

# ---------------------------------------------------------------------------
# reset_for_retry contract
# ---------------------------------------------------------------------------
## reset_for_retry(ctx: Dictionary) -> void
## Contract: every resettable game system must implement this method.
## Called by InstantRetrySystem._execute_retry_reset() in this order:
##   HealthDamageSystem → PlayerController → BossStateMachine
##   → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem
## ctx keys: "boss_hp" (float), "boss_phase" (int), "death_count" (int)
## Each system resets ALL its stateful variables to post-death-screen initial values.
## Missing a variable here is a latent gameplay bug.

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Boss HP at the moment of player death. -1.0 means no saved context (fresh start).
var preserved_boss_hp: float = -1.0

## Boss phase index at the moment of player death. 0 means no saved context.
var preserved_boss_phase: int = 0

## Total player deaths in this session. Accumulates across boss fights; never cleared
## by clear_context() — use session_death_count to drive the HUD death counter.
var session_death_count: int = 0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Saves the retry context from the current death event.
##
## [param boss_hp] — Boss HP at the moment of player death (may be 0.0 on edge kill).
## [param boss_phase] — Boss phase index at death (1-based, matches BossStateMachine).
## [param death_count] — Already-incremented death count (caller computes
##   [code]RetryContext.session_death_count + 1[/code] before calling).
##
## [b]Source:[/b] TR-IRS-005
func save_context(boss_hp: float, boss_phase: int, death_count: int) -> void:
	preserved_boss_hp = boss_hp
	preserved_boss_phase = boss_phase
	session_death_count = death_count


## Returns a snapshot of the current retry context.
##
## Keys:
## - [code]"boss_hp"[/code] (float) — preserved Boss HP; -1.0 if fresh start.
## - [code]"boss_phase"[/code] (int) — preserved Boss phase; 0 if fresh start.
## - [code]"death_count"[/code] (int) — session death count.
##
## [b]Source:[/b] TR-IRS-005
func load_context() -> Dictionary:
	return {
		"boss_hp": preserved_boss_hp,
		"boss_phase": preserved_boss_phase,
		"death_count": session_death_count
	}


## Clears the preserved Boss context on boss defeat.
##
## Called when [signal EventBus.boss_defeated] fires so the next fight begins at
## full Boss HP. [member session_death_count] is intentionally NOT cleared — it
## accumulates across all boss fights for the session lifetime.
##
## After this call [method is_fresh_start] returns [code]true[/code].
##
## [b]Source:[/b] TR-IRS-010
func clear_context() -> void:
	preserved_boss_hp = -1.0
	preserved_boss_phase = 0
	# session_death_count intentionally NOT cleared — accumulates across fights in session


## Returns [code]true[/code] when no retry context has been saved yet.
##
## Uses [member preserved_boss_hp] [code]< 0.0[/code] as the sentinel:
## a real Boss HP value is always >= 0.0, so -1.0 is unambiguous.
##
## Returns [code]false[/code] after [method save_context] and [code]true[/code]
## again after [method clear_context].
func is_fresh_start() -> bool:
	return preserved_boss_hp < 0.0
