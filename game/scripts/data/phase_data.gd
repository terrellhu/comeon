class_name PhaseData
extends Resource

@export var phase_index: int = 0
@export var attack_sequence: Array[AttackData] = []
@export_range(0.0, 5.0) var idle_duration_after_attack: float = 0.5
@export var phase_transition_anim: StringName = &""
@export var phase_symbol: Texture2D
