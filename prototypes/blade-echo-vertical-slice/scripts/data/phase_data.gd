# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0002

class_name PhaseData
extends Resource

@export var phase_index: int = 0
@export var attack_sequence: Array[AttackData] = []
@export_range(0.0, 5.0) var idle_duration_after_attack: float = 0.5
## Animation name to play on entering this phase (empty = skip transition anim)
@export var phase_transition_anim: StringName = &""
## VS: leave null — phase symbol for death screen (Art Bible 7.5)
@export var phase_symbol: Texture2D
