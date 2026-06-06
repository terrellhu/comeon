class_name MockEventBus
extends Node

## Reusable test double for EventBus.
## Declares all 13 signals so GUT's watch_signals() can observe them.
## Also records emission counts and last-seen values for key signals so that
## tests can assert directly without relying on GUT's watch_signals internals.
##
## Add this node as a child in before_each() (use add_child_autofree).
## Reset counters inside a test with [code]_mock_bus.player_hp_changed_call_count = 0[/code].

# ─── Combat telegraph lifecycle ──────────────────────────────────────────────
signal attack_telegraphed(attack_type: GameEnums.AttackType, damage: float)
signal parry_succeeded(attack_type: GameEnums.AttackType)
signal parry_failed(attack_type: GameEnums.AttackType)
signal stagger_ended()
signal counter_full_combo_completed(attack_type: GameEnums.AttackType)

# ─── Player state ─────────────────────────────────────────────────────────────
signal player_died()
signal player_hp_changed(current: float, max_hp: float)

# ─── Boss state ───────────────────────────────────────────────────────────────
signal boss_defeated()
signal boss_phase_changed(from_phase: int, to_phase: int)
signal boss_hp_changed(current: float, max_hp: float, phase: int)

# ─── Per-frame stream ─────────────────────────────────────────────────────────
signal telegraph_updated(progress: float, window_open: bool, attack_type: GameEnums.AttackType)
signal counter_window_updated(hit_count: int, time_remaining: float, state: GameEnums.ComboState)

# ─── Retry system ─────────────────────────────────────────────────────────────
signal retry_death_count_changed(count: int)

# ─── Emission recording — player_hp_changed ───────────────────────────────────

## Incremented each time player_hp_changed is emitted.
var player_hp_changed_call_count: int = 0

## Current HP from the most recent player_hp_changed emission.
var last_player_hp_changed_current: float = 0.0

## Max HP from the most recent player_hp_changed emission.
var last_player_hp_changed_max: float = 0.0

# ─── Emission recording — player_died ─────────────────────────────────────────

## Incremented each time player_died is emitted.
var player_died_call_count: int = 0

# ─── Emission recording — boss_hp_changed ─────────────────────────────────────

## Incremented each time boss_hp_changed is emitted.
var boss_hp_changed_call_count: int = 0

## Current HP from the most recent boss_hp_changed emission.
var last_boss_hp_changed_current: float = 0.0

## Max HP from the most recent boss_hp_changed emission.
var last_boss_hp_changed_max: float = 0.0

## Phase from the most recent boss_hp_changed emission.
var last_boss_hp_changed_phase: int = 0

# ─── Emission recording — boss_phase_changed ──────────────────────────────────

## Incremented each time boss_phase_changed is emitted.
var boss_phase_changed_call_count: int = 0

## Ordered list of (from_phase, to_phase) pairs recorded in emission order.
## Each element is an Array[int] of size 2: [from_phase, to_phase].
var boss_phase_changed_history: Array = []

# ─── Emission recording — boss_defeated ───────────────────────────────────────

## Incremented each time boss_defeated is emitted.
var boss_defeated_call_count: int = 0

# ─── Emission recording — attack_telegraphed ──────────────────────────────────

## Incremented each time attack_telegraphed is emitted.
var attack_telegraphed_call_count: int = 0

## AttackType from the most recent attack_telegraphed emission.
var last_attack_telegraphed_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT

## Damage from the most recent attack_telegraphed emission.
var last_attack_telegraphed_damage: float = 0.0

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	player_hp_changed.connect(_on_player_hp_changed)
	player_died.connect(_on_player_died)
	boss_hp_changed.connect(_on_boss_hp_changed)
	boss_phase_changed.connect(_on_boss_phase_changed)
	boss_defeated.connect(_on_boss_defeated)
	attack_telegraphed.connect(_on_attack_telegraphed)


func _on_player_hp_changed(current: float, max_hp: float) -> void:
	player_hp_changed_call_count += 1
	last_player_hp_changed_current = current
	last_player_hp_changed_max = max_hp


func _on_player_died() -> void:
	player_died_call_count += 1


func _on_boss_hp_changed(current: float, max_hp: float, phase: int) -> void:
	boss_hp_changed_call_count += 1
	last_boss_hp_changed_current = current
	last_boss_hp_changed_max = max_hp
	last_boss_hp_changed_phase = phase


func _on_boss_phase_changed(from_phase: int, to_phase: int) -> void:
	boss_phase_changed_call_count += 1
	boss_phase_changed_history.append([from_phase, to_phase])


func _on_boss_defeated() -> void:
	boss_defeated_call_count += 1


func _on_attack_telegraphed(attack_type: GameEnums.AttackType, damage: float) -> void:
	attack_telegraphed_call_count += 1
	last_attack_telegraphed_type = attack_type
	last_attack_telegraphed_damage = damage
