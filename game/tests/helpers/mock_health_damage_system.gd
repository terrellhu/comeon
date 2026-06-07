class_name MockHealthDamageSystem
extends Node

## Minimal test double for HealthDamageSystem.
## Records apply_damage() calls for assertion in GUT tests.
## Does NOT replicate HP logic — tests that need real HP behaviour
## should use a live HealthDamageSystem via init_battle().
##
## Usage:
##   var _mock_hds := MockHealthDamageSystem.new()
##   add_child_autofree(_mock_hds)
##   _pts.initialize(_mock_bus, _mock_hds)

# ─── Emission recording — apply_damage ───────────────────────────────────────

## Incremented each time apply_damage() is called.
var apply_damage_call_count: int = 0

## Target from the most recent apply_damage() call.
var last_apply_damage_target: GameEnums.Target = GameEnums.Target.BOSS

## Amount from the most recent apply_damage() call.
var last_apply_damage_amount: float = 0.0

## Ordered call history. Each element is an Array of size 2: [target, amount].
var apply_damage_history: Array = []

# ─── Method stubs ─────────────────────────────────────────────────────────────

## Records the call; mirrors HealthDamageSystem.apply_damage(target, amount).
## Does not mutate any HP state — pure recording stub.
func apply_damage(target: GameEnums.Target, amount: float) -> void:
	apply_damage_call_count += 1
	last_apply_damage_target = target
	last_apply_damage_amount = amount
	apply_damage_history.append([target, amount])
