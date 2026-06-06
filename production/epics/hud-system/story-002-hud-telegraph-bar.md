# Story 002: Telegraph Progress Bar

> **Epic**: HUDSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/hud-system.md` — Element 3, Formula 3, AC-HUD-10 to 14
**Requirements**: `TR-HUD-005`, `TR-HUD-006`

**ADR Governing Implementation**:
- ADR-0001: `telegraph_updated(progress: float, window_open: bool, attack_type: AttackType)` subscribed via EventBus (per-physics-frame signal)
- HUD per-frame handler must be O(1) — no allocation (ADR-0001)

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

### AC-HUD-10: No active telegraph → progress bar invisible
- Given: No `telegraph_updated` signal active (system in IDLE)
- When: HUD rendered
- Then: Telegraph bar `modulate.a == 0` (transparent/hidden)

### AC-HUD-11: PRE_WINDOW state — progress 0.75, window_open=false → darkened color
- Given: `telegraph_updated(0.75, false, SWEEP)` received
- When: Handler processed
- Then: `bar_fill_ratio == 0.75`; bar color = PRE_WINDOW palette

### AC-HUD-12: WINDOW_OPEN state → bright color
- Given: `telegraph_updated(1.0, true, HEAVY)` received
- When: Handler processed
- Then: `bar_fill_ratio == 1.0`; bar color = WINDOW_OPEN bright palette

### AC-HUD-13: POST_WINDOW (window_open=false, late) → dark red color
- Given: `telegraph_updated(0.5, false, LIGHT)` received (after window has closed)
- When: Handler processed
- Then: `bar_fill_ratio == 0.5`; bar color = POST_WINDOW dark red palette

### AC-HUD-14: progress > 1.0 clamped
- Given: `telegraph_updated(1.5, true, HEAVY)` received (out-of-range)
- When: Handler processed
- Then: `bar_fill_ratio == 1.0` (clamped); bar does not overflow

## Test Evidence Path

`game/tests/unit/hud_system/test_hud_telegraph_bar.gd`

*Note: Color palette validation requires visual QA — automated tests verify fill ratio calculation and clamp logic.*

## Out of Scope

- Color palette details (visual QA)
- WINDOW_OPEN height expansion animation (Visual QA)

## Definition of Done

- [ ] Signal handler logic ACs pass in GUT headless
- [ ] O(1) handler confirmed (no allocation in `_on_telegraph_updated`)
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
