class_name BossData
extends Resource

@export var boss_id: StringName = &""
@export_range(1.0, 10000.0) var boss_max_hp: float = 1000.0
## phase_threshold_pct[0] = first phase transition HP threshold (descending order)
@export var phase_threshold_pct: Array[float] = [0.6, 0.3]
@export var phases: Array[PhaseData] = []
