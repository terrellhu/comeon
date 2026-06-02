extends Node

# ─── Combat telegraph lifecycle ───────────────────────────────────────────────
signal attack_telegraphed(attack_type: GameEnums.AttackType, damage: float)
signal parry_succeeded(attack_type: GameEnums.AttackType)
signal parry_failed(attack_type: GameEnums.AttackType)
signal stagger_ended()
signal counter_full_combo_completed(attack_type: GameEnums.AttackType)

# ─── Player state ───────────────────────────────────────────────────────────
signal player_died()
signal player_hp_changed(current: float, max_hp: float)

# ─── Boss state ──────────────────────────────────────────────────────────────
signal boss_defeated()
signal boss_phase_changed(from_phase: int, to_phase: int)
signal boss_hp_changed(current: float, max_hp: float, phase: int)

# ─── Per-frame stream (emitted every _physics_process) ────────────────────
signal telegraph_updated(progress: float, window_open: bool, attack_type: GameEnums.AttackType)
signal counter_window_updated(hit_count: int, time_remaining: float, state: GameEnums.ComboState)

# ─── Retry system ───────────────────────────────────────────────────────────
signal retry_death_count_changed(count: int)
