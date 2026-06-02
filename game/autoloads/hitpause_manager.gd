class_name HitpauseManagerNode
extends Node

## HitpauseManager — Foundation Layer Autoload
##
## Freezes game time for a fixed real-time duration to sell impact on hit, parry,
## and counter-attack events. Uses [code]Engine.time_scale = 0.0[/code] + a
## real-time [SceneTree] timer so the countdown is immune to time-scale freeze.
##
## [b]Autoload name:[/b] "HitpauseManager"
## [b]Registration order:[/b] EventBus → RetryContext → HitpauseManager
##
## [b]Usage (production):[/b]
## [codeblock]
## HitpauseManager.trigger_hitpause(0.060)   # player hit / parry success
## HitpauseManager.trigger_hitpause(0.080)   # counter 3rd hit
## HitpauseManager.trigger_hitpause(0.030)   # full-combo BONUS_STAGGER entry
## [/codeblock]
##
## [b]Source:[/b] ADR-0005, TR-IRS-006, Story 002

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Re-entrancy guard. [code]true[/code] while a hitpause is in progress.
## Nested [method trigger_hitpause] calls are silently dropped while this is set.
var _active: bool = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Triggers a hitpause of [param duration_secs] real-time seconds.
##
## Sets [code]Engine.time_scale = 0.0[/code] immediately, then waits for
## [param duration_secs] of **real time** (unaffected by [code]time_scale[/code])
## before restoring [code]Engine.time_scale = 1.0[/code].
##
## If a hitpause is already in progress ([member _active] is [code]true[/code]),
## this call returns immediately without effect — first request wins.
##
## [b]Independence note:[/b] [code]SceneTree.paused[/code] (death screen) and
## [code]Engine.time_scale[/code] (hitpause) are independent mechanisms per ADR-0003.
## If [code]player_died[/code] fires during an active hitpause, the real-time timer
## still completes naturally and restores [code]Engine.time_scale = 1.0[/code]; the
## death screen then runs with [code]SceneTree.paused = true[/code] as expected.
##
## [b]Source:[/b] ADR-0005
func trigger_hitpause(duration_secs: float) -> void:
	if _active:
		return  # first hitpause wins; nested requests dropped silently
	_active = true
	Engine.time_scale = 0.0
	# process_always=true  (2nd arg): timer runs even when SceneTree is paused
	# process_in_physics=false (3rd arg): idle process, not physics process
	# ignore_time_scale=true (4th arg): counts real time even at Engine.time_scale=0
	var timer: SceneTreeTimer = get_tree().create_timer(duration_secs, true, false, true)
	await timer.timeout
	Engine.time_scale = 1.0
	_active = false
