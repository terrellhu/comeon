# Story 003: Path A — Parry Success

> **Epic**: ParryTelegraphSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/parry-telegraph-system.md` — Core Rules 8, Formula 3
**Requirements**: `TR-PTS-004`, `TR-PTS-005`, `TR-PTS-008`

**ADR Governing Implementation**:
- ADR-0001: `parry_succeeded(attack_type)` emitted via EventBus; `exit_parry_state(duration)` is PlayerController direct signal

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: In GUT, use signal spies (`watch_signals`) to verify both emission and payload. `_on_parry_input_pressed()` must be callable from test without PhysicsServer.

**Control Manifest Rules (Feature Layer)**:
- No literals in logic files
- `parry_succeeded` and `parry_failed` are EventBus signals (1:N)
- `exit_parry_state` is PlayerController's own 1:1 signal (ADR-0001 exception)

---

## Acceptance Criteria

### AC-03: Window-in parry succeeds — Path A
- Given: System TELEGRAPHING (HEAVY), `telegraph_timer = 0.72s` (window 0.60–0.95s)
- When: `parry_input_pressed` emitted
- Then: `parry_succeeded(HEAVY)` emitted; `exit_parry_state(parry_animation_duration)` emitted; `apply_damage` NOT called; state returns to IDLE; `telegraph_timer` cleared

### AC-07: exit_parry_state always emitted on parry input
- Given: Any system state (IDLE or TELEGRAPHING)
- When: `parry_input_pressed` emitted
- Then: `exit_parry_state` emitted exactly once in the same frame

### AC-08: Signal order is parry_succeeded first, then exit_parry_state; apply_damage count = 0
- Given: TELEGRAPHING with timer in window
- When: parry_input_pressed
- Then: Spy records parry_succeeded before exit_parry_state; apply_damage call count = 0

### AC-09: System returns to IDLE after Path A — no STAGGERING state
- Given: SWEEP parry succeeded
- When: Path A complete
- Then: `system_state == IDLE`; `parry_succeeded(SWEEP)` emitted; `stagger_ended` NOT emitted by this system

### AC-14: Boundary — timer exactly at window_open_time counts as success
- Given: HEAVY, `telegraph_timer` exactly = `window_open_time` (0.60s)
- When: `parry_input_pressed`
- Then: `parry_success = true`; `parry_succeeded(HEAVY)` emitted

### AC-14b: Boundary — timer exactly at window_close_time counts as success
- Given: HEAVY, `telegraph_timer` exactly = `window_close_time` (0.95s)
- When: `parry_input_pressed`
- Then: `parry_success = true`; `parry_succeeded(HEAVY)` emitted

### AC-20: Same-frame boundary — parry checked before attack lands
- Given: HEAVY, `telegraph_timer` will exceed `telegraph_duration` this frame AND timer is in window
- When: `_physics_process(delta)` runs
- Then: Parry succeeds (Path A); `apply_damage` NOT called (parry wins on boundary frame)

### AC-15: parry_succeeded carries correct attack_type
- Given: LIGHT/HEAVY/SWEEP parry each succeed
- When: `parry_succeeded` emitted for each
- Then: Signal payload `attack_type` matches the attack type that triggered the telegraph

## Test Evidence Path

`game/tests/unit/parry_system/test_pts_path_a.gd`

## Out of Scope

- Path B (early press, no window) — Story 004
- Path C (empty parry, IDLE) — Story 004
- Attack landing / apply_damage path — Story 004

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `_on_parry_input_pressed()` handler implemented for Path A
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
