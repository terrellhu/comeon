# Story 001: CounterAttackComboSystem Skeleton

> **Epic**: CounterAttackComboSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/counter-attack-combo.md` — Core Rules 1–4, States
**Requirements**: `TR-CAC-001`, `TR-CAC-008`

**ADR Governing Implementation**:
- ADR-0001: `parry_succeeded` subscribed via EventBus; `counter_window_updated` emitted every physics frame; `attack_input_pressed` from PlayerController direct signal

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_physics_process(delta)` counts per frame; GUT headless runs at constant tick rate.

**Control Manifest Rules (Feature Layer)**:
- `initialize(event_bus)` injection required
- `PROCESS_MODE_PAUSEABLE` default
- No literals for base_counter_window values (1.0/1.5/2.0) — use @export

---

## Acceptance Criteria

### AC-01: parry_succeeded → COUNTER_WINDOW_OPEN state initialized
- Given: System IDLE, initialized with mock EventBus
- When: `parry_succeeded(HEAVY)` emitted
- Then: State = COUNTER_WINDOW_OPEN; `window_timer = 1.5`; `current_hit_count = 0`; `hit_cooldown_active = false`

### AC-01b: IDLE state does not accept attack_input_pressed
- Given: System IDLE
- When: `attack_input_pressed` emitted
- Then: `apply_damage` NOT called; state remains IDLE

### AC-15: counter_window_updated emitted every physics frame during COUNTER_WINDOW_OPEN
- Given: System COUNTER_WINDOW_OPEN
- When: `_physics_process(delta)` called N times
- Then: `counter_window_updated` emitted N times; `state = COUNTER_WINDOW_OPEN`; `time_remaining` strictly decreases each frame

## Test Evidence Path

`game/tests/unit/counter_attack_combo/test_cac_skeleton.gd`

## Out of Scope

- Combo hit processing with apply_damage (Story 002)
- Full combo + bonus stagger (Story 003)
- Guards (player_died/boss_defeated) and reset (Story 004)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `counter_attack_combo_system.gd` created in `game/scripts/feature/`
- [ ] `initialize(event_bus)` implemented; IDLE/COUNTER_WINDOW_OPEN/BONUS_STAGGER enum defined
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
