# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
#
# Central signal registry. All 1:N cross-module signals live here.
# 1:1 signals (parry_input_pressed, attack_input_pressed) live on PlayerController directly.
# Production: keep identical — source: ADR-0001

extends Node

# ─── Combat telegraph lifecycle ─────────────────────────────────────────────
signal attack_telegraphed(attack_type: GameEnums.AttackType, damage: float)
signal parry_succeeded(attack_type: GameEnums.AttackType)
signal parry_failed(attack_type: GameEnums.AttackType)
signal stagger_ended()
signal counter_full_combo_completed(attack_type: GameEnums.AttackType)

# ─── Player state ────────────────────────────────────────────────────────────
signal player_died()
signal player_hp_changed(current: float, max_hp: float)

# ─── Boss state ──────────────────────────────────────────────────────────────
signal boss_defeated()
signal boss_phase_changed(from_phase: int, to_phase: int)
signal boss_hp_changed(current: float, max_hp: float, phase: int)

# ─── Per-frame stream data ───────────────────────────────────────────────────
signal telegraph_updated(progress: float, window_open: bool, attack_type: GameEnums.AttackType)
signal counter_window_updated(hit_count: int, time_remaining: float, state: GameEnums.ComboState)

# ─── Retry ───────────────────────────────────────────────────────────────────
signal retry_death_count_changed(count: int)

# ─── Parry boundary (exit_parry_state goes via EventBus for VS simplicity) ──
# Note: In production, exit_parry_state is a direct 1:1 signal on ParryTelegraphSystem
# For VS, broadcasting via EventBus is acceptable since it's still effectively 1:1.
signal exit_parry_state(duration: float)
