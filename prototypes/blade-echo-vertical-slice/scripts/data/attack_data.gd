# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0002

class_name AttackData
extends Resource

@export var attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
@export var damage: float = 10.0
## 0.0 = use AttackType global default; >0 overrides the telegraph duration for this attack
@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0
## How long the attack animation lasts (ATTACKING state duration)
@export_range(0.1, 3.0) var attack_anim_duration: float = 0.5
