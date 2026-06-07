# Story 005: Reset + player_died/boss_defeated Guards

> **Epic**: ParryTelegraphSystem
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/parry-telegraph-system.md` — Edge Cases (player_died, boss_defeated)
**Requirements**: `TR-PTS-013`

**Dependencies**: Story 004 (Complete) — `_handle_telegraph_timeout`, `_health_damage_system` injection pattern

**ADR Governing Implementation**:
- ADR-0003: `reset_for_retry(ctx)` contract — set `system_state = IDLE`, clear `telegraph_timer`

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Feature Layer)**:
- `reset_for_retry(ctx: Dictionary)` must restore `system_state=IDLE`, `telegraph_timer=0.0`

---

## Acceptance Criteria

### AC-17: player_died during TELEGRAPHING → immediate IDLE, no apply_damage
- Given: SWEEP TELEGRAPHING, `telegraph_timer = 0.50s`
- When: `player_died` signal received
- Then: `system_state == IDLE`; `telegraph_timer == 0.0`; `apply_damage` NOT called; `parry_failed` NOT emitted

### AC-18: boss_defeated during TELEGRAPHING → immediate IDLE, no apply_damage
- Given: LIGHT TELEGRAPHING, `telegraph_timer = 0.20s`
- When: `boss_defeated` signal received
- Then: `system_state == IDLE`; `telegraph_timer == 0.0`; `apply_damage` NOT called

### AC-reset: reset_for_retry restores clean IDLE state
- Given: System in TELEGRAPHING state
- When: `reset_for_retry({})` called
- Then: `system_state == IDLE`; `telegraph_timer == 0.0`; `current_attack_type` cleared; no signals emitted during reset

### AC-22 (advisory): parry success signal latency ≤ 0.5ms
- Given: System TELEGRAPHING with timer in window
- When: parry_input_pressed processed
- Then: Time from signal to all outputs emitted ≤ 0.5ms (defer to Godot Profiler on native build — GUT headless cannot measure this accurately)

## Test Evidence Path

`game/tests/unit/parry_system/test_pts_reset_guards.gd`

## Out of Scope

- AC-22 performance test (needs native build Godot Profiler — pending)

## Definition of Done

- [ ] AC-17, AC-18, AC-reset pass in GUT headless (0 failing)
- [ ] AC-22 marked pending (native build required)
- [ ] `reset_for_retry(ctx)` implemented
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
