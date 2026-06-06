# Story 004: Path B/C — Parry Failure + Empty Parry + Attack Landing

> **Epic**: ParryTelegraphSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/parry-telegraph-system.md` — Core Rules 5, 9, 10; Formulas 1–3
**Requirements**: `TR-PTS-006`, `TR-PTS-007`, `TR-PTS-008`

**ADR Governing Implementation**:
- ADR-0001: `apply_damage(PLAYER, damage)` called on HealthDamageSystem reference (injected); `parry_failed(type)` via EventBus
- ADR-0002: damage value from AttackData

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Use MockEventBus pattern from `game/tests/helpers/mock_event_bus.gd` to spy on `parry_failed` emissions.

---

## Acceptance Criteria

### AC-04: Path B early press — window preserved
- Given: HEAVY TELEGRAPHING, `telegraph_timer = 0.30s` (before window_open_time 0.60s)
- When: `parry_input_pressed`
- Then: `exit_parry_state` emitted; telegraph_timer continues; window NOT consumed; no `parry_succeeded`; no `apply_damage`

### AC-05: Path B late press — after window, no success possible
- Given: HEAVY TELEGRAPHING, `telegraph_timer = 1.10s` (after window_close_time 0.95s)
- When: `parry_input_pressed`
- Then: `exit_parry_state` emitted; telegraph continues to `telegraph_duration`; at 1.2s: `apply_damage(PLAYER, damage)` called; `parry_failed(HEAVY)` emitted

### AC-06: Path C — empty parry (IDLE state)
- Given: System is IDLE
- When: `parry_input_pressed`
- Then: `exit_parry_state(parry_animation_duration)` emitted ONLY; no `parry_succeeded`; no `apply_damage`; no `parry_failed`; state remains IDLE

### AC-11: Attack landing — apply_damage and parry_failed emitted
- Given: LIGHT TELEGRAPHING (damage=10), no parry input
- When: `telegraph_timer` reaches 0.8s (telegraph_duration)
- Then: `apply_damage(PLAYER, 10.0)` called exactly once; `parry_failed(LIGHT)` emitted; state returns IDLE

### AC-19: Zero-damage attack still calls apply_damage(PLAYER, 0.0)
- Given: LIGHT TELEGRAPHING, damage=0, no parry input
- When: telegraph expires
- Then: `apply_damage(PLAYER, 0.0)` called; `parry_failed(LIGHT)` emitted; state → IDLE

### AC-24: All three paths end in IDLE state
- Given: Path A, B (late, attack lands), C each run to completion
- When: All timers/events complete
- Then: All three paths leave `system_state == IDLE`; no path causes state hang

## Test Evidence Path

`game/tests/unit/parry_system/test_pts_path_bc.gd`

## Out of Scope

- parry_animation_duration precise timing (needs physics scene)
- Visual feedback (Audio/VFX — post-MVP)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `_handle_telegraph_timeout()` and attack landing logic implemented
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
