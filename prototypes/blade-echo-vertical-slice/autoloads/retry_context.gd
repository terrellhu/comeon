# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0003 — Autoload registered as "RetryContext"

class_name RetryContextNode
extends Node

## -1.0 = fresh start (no saved context)
var preserved_boss_hp: float = -1.0
var preserved_boss_phase: int = 0
var session_death_count: int = 0

func save_context(boss_hp: float, boss_phase: int, death_count: int) -> void:
	preserved_boss_hp = boss_hp
	preserved_boss_phase = boss_phase
	session_death_count = death_count

func load_context() -> Dictionary:
	return {
		"boss_hp": preserved_boss_hp,
		"boss_phase": preserved_boss_phase,
		"death_count": session_death_count,
	}

func clear_context() -> void:
	preserved_boss_hp = -1.0
	preserved_boss_phase = 0
	# session_death_count persists across boss fights in a session

func is_fresh_start() -> bool:
	return preserved_boss_hp < 0.0
