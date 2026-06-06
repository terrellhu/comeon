class_name BossData
extends Resource

@export var boss_id: StringName = &""
@export_range(1.0, 10000.0) var boss_max_hp: float = 1000.0
## phase_threshold_pct[0] = first phase transition HP threshold (descending order)
@export var phase_threshold_pct: Array[float] = [0.6, 0.3]
@export var phases: Array[PhaseData] = []
## Default telegraph duration per AttackType. Key: int(GameEnums.AttackType), value: float (seconds).
## Set all AttackType entries in the .tres asset — missing keys fall back to 0.1 s.
## Example: { 0: 0.8, 1: 1.2, 2: 1.5 }  (LIGHT=0.8, HEAVY=1.2, SWEEP=1.5)
@export var default_telegraph_durations: Dictionary[int, float] = {}


## Look up the default telegraph duration for a given AttackType.
## Returns 0.1 s if the type is not found (should not happen in production).
func get_default_telegraph_duration(type: GameEnums.AttackType) -> float:
	return default_telegraph_durations.get(int(type), 0.1)
