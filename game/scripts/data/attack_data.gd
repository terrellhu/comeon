class_name AttackData
extends Resource

@export var attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
@export var damage: float = 10.0
## 0.0 = use AttackType global default; >0 = override this attack's telegraph duration
@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0
