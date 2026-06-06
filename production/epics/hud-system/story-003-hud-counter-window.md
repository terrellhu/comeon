# Story 003: Counter Window HUD — Time Bar + Combo Count + Bonus Stagger

> **Epic**: HUDSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/hud-system.md` — Element 4, Formula 4, AC-HUD-15 to 22
**Requirements**: `TR-HUD-007`, `TR-HUD-009`

**ADR Governing Implementation**:
- ADR-0001: `counter_window_updated(hit_count, time_remaining, state)` and `counter_full_combo_completed` subscribed via EventBus
- GAP-03 OPEN: Counter bar follows player world position — MVP: fixed screen position (CanvasLayer anchor near player spawn); world-tracking deferred

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `counter_window_updated` fires every physics frame during COUNTER_WINDOW_OPEN/BONUS_STAGGER. Tween for fade-out: use `create_tween().tween_property(node, "modulate:a", 0.0, 0.2)`.

---

## Acceptance Criteria

### AC-HUD-15: COUNTER_WINDOW_OPEN → bar visible, fill correct, not gold
- Given: `counter_window_updated(2, 0.6, COUNTER_WINDOW_OPEN)` for LIGHT
- When: Handler processed
- Then: Bar visible; `fill_ratio = 0.6` (0.6/1.0); bar color = cool blue; text shows "hit 2/3"

### AC-HUD-16: Full window (time_remaining == base) → fill = 1.0
- Given: `counter_window_updated(1, 1.5, COUNTER_WINDOW_OPEN)` for HEAVY
- When: Handler processed
- Then: `fill_ratio = 1.0` (1.5/1.5)

### AC-HUD-17: BONUS_STAGGER → bar gold color
- Given: `counter_window_updated(3, 0.8, BONUS_STAGGER)`
- When: Handler processed
- Then: Bar color = gold; bar still visible

### AC-HUD-18: counter_full_combo_completed → FULL COMBO text 0.5s
- Given: `counter_full_combo_completed` received
- When: Handled
- Then: "FULL COMBO" text visible for 0.5s then disappears

### AC-HUD-19: Window close → 0.2s fade-out
- Given: Counter bar was visible; state transitions to IDLE (not BONUS_STAGGER)
- When: State change signaled
- Then: Bar fades to transparent over 0.2s, not instantly

### AC-HUD-20: IDLE state → bar invisible
- Given: `counter_window_updated(0, 0.0, IDLE)` received
- When: Handled
- Then: Bar invisible; combo text hidden

### AC-HUD-21: HP flicker + telegraph WINDOW_OPEN → independent rendering
- Given: Player HP = 1 (segment flickering) and `telegraph_updated(0.8, true, LIGHT)` active
- When: Both signals fire same frame
- Then: HP segment 1 continues flicker; telegraph bar shows WINDOW_OPEN; no interference

### AC-HUD-22: Counter bar + telegraph bar same frame
- Given: `counter_window_updated` and `telegraph_updated` both active
- When: Both fire in same physics frame
- Then: Both bars render correctly; no z-order conflict or value corruption

## Test Evidence Path

`game/tests/unit/hud_system/test_hud_counter_window.gd`

## Out of Scope

- World-coordinate tracking of counter bar (GAP-03 — pending ADR)
- Art Bible color palette validation (Visual QA)

## Definition of Done

- [ ] Signal handler logic ACs pass in GUT headless
- [ ] FULL COMBO text timer implemented (0.5s)
- [ ] Fade-out tween implemented (0.2s)
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
