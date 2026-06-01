# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0005 — Autoload registered as "HitpauseManager"
# Hitpause = Engine.time_scale = 0 + real-time timer.
# NEVER use SceneTree.paused for hitpause — that mechanism is reserved for death screen.

class_name HitpauseManagerNode
extends Node

var _active: bool = false  ## re-entrancy guard: first hitpause wins

## Call without await — fire and forget.
## player hit = 0.060, parry success = 0.060, 3rd counter hit = 0.080, full combo = 0.030
func trigger_hitpause(duration_secs: float) -> void:
	if _active:
		return
	_active = true
	Engine.time_scale = 0.0
	# ignore_time_scale=true: timer counts in real time at time_scale=0
	await get_tree().create_timer(duration_secs, true, false, true).timeout
	Engine.time_scale = 1.0
	_active = false
