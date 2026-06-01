# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0002

class_name BossData
extends Resource

@export var boss_id: StringName = &""
@export_range(1.0, 10000.0) var boss_max_hp: float = 1000.0
## Descending order: [0.6, 0.3] = Phase 2 triggers at 60% HP, Phase 3 at 30%
@export var phase_threshold_pct: Array[float] = [0.6, 0.3]
@export var phases: Array[PhaseData] = []
