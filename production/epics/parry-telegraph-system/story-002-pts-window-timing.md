# Story 002: Window Timing Formula + AttackData Override Lookup

> **Epic**: ParryTelegraphSystem
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/parry-telegraph-system.md` — Formulas 1–4
**Requirements**: `TR-PTS-002`, `TR-PTS-003`, `TR-PTS-011`

**ADR Governing Implementation**:
- ADR-0002: AttackData provides `telegraph_duration_override`, `window_width_override`, `window_open_fraction_override`, `stagger_duration_override` (≤0 → use GDD defaults)
- GAP-02 RESOLVED (S002-I02 2026-06-06): all four override fields now in AttackData

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Float comparison tolerance ±0.001s for timing; use `absf()` not `abs()` for float comparison in GDScript.

**Control Manifest Rules (Feature Layer)**:
- No literals 0.8, 1.2, 1.5, 0.30, 0.35, 0.45, 0.50 in logic code — read from AttackData
- All timing values from BossData resource injection (ADR-0002)

---

## Acceptance Criteria

### AC-02: Default telegraph durations from AttackData (no literals)
- Given: Three AttackData instances with all overrides = 0 (use defaults)
- When: System reads effective telegraph duration for LIGHT/HEAVY/SWEEP
- Then: LIGHT=0.8s, HEAVY=1.2s, SWEEP=1.5s (tolerance ±0.001s); no literal appears in .gd file

### AC-12: Window open/close times computed correctly (all three types)
- Given: AttackData instances with all overrides = 0
- When: System computes `window_open_time` and `window_close_time`
- Then: LIGHT: open=0.40s, close=0.70s; HEAVY: open=0.60s, close=0.95s; SWEEP: open=0.75s, close=1.20s (tolerance ±0.001s)

### AC-02b: AttackData override applied when > 0
- Given: AttackData with `telegraph_duration_override = 2.0`, `window_width_override = 0.5`, `window_open_fraction_override = 0.6`
- When: System computes window timing
- Then: `telegraph_duration = 2.0`; `window_open_time = 2.0 × 0.6 = 1.2s`; `window_close_time = 1.2 + 0.5 = 1.7s`

### AC-23: No literal timing values in parry_telegraph_system.gd
- Given: Implementation file `game/scripts/feature/parry_telegraph_system.gd`
- When: grep for 0.8, 1.2, 1.5, 0.30, 0.35, 0.45, 0.50 in logic lines
- Then: Zero matches in core logic (constants defined in const block referencing GDD values are allowed)

## Test Evidence Path

`game/tests/unit/parry_system/test_pts_window_timing.gd`

## Out of Scope

- Parry input handling (Story 003/004)
- telegraph_updated per-frame emission verified in Story 001

## Definition of Done

- [x] All ACs pass in GUT headless (0 failing)
- [x] `_get_effective_telegraph_duration(attack_data)` and `_compute_window_times()` implemented
- [x] `/code-review` APPROVED
- [x] `/story-done` run and Status → Complete

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: Logic — `game/tests/unit/parry_system/test_pts_window_timing.gd` (16/16 PASS)
**Code Review**: Complete — APPROVED after CR-1 (null guard early-return) + CR-2 (assert→push_warning+clamp) fixes applied
