class_name AttackData
extends Resource

@export var attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
@export var damage: float = 10.0
## 0.0 = use type default (LIGHT=0.8 HEAVY=1.2 SWEEP=1.5); >0 = override telegraph duration
@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0
## 0.0 = use type default (LIGHT=0.30 HEAVY=0.35 SWEEP=0.45); >0 = override parry window width
@export_range(0.0, 2.0) var window_width_override: float = 0.0
## 0.0 = use global default (0.50); >0 = fraction of telegraph at which window opens
@export_range(0.0, 1.0) var window_open_fraction_override: float = 0.0
## 0.0 = use type default (LIGHT=1.0 HEAVY=1.5 SWEEP=2.0); >0 = override boss stagger duration
@export_range(0.0, 10.0) var stagger_duration_override: float = 0.0
