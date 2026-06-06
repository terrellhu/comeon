# Story 004: boss_defeated Guard + reset_for_retry + Death Counter

> **Epic**: HUDSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/hud-system.md` — Edge Cases (boss_defeated boundary), AC-HUD-23
**Requirements**: `TR-HUD-010`, `TR-HUD-011`

**ADR Governing Implementation**:
- ADR-0003: `reset_for_retry(ctx: Dictionary)` — HUD pass is valid; signals will re-populate state after resume
- ADR-0001: `boss_defeated` → unsubscribe or ignore per-frame signals

---

## Acceptance Criteria

### AC-HUD-23: boss_defeated → per-frame signals stop updating HUD
- Given: boss_defeated received while telegraph_updated and counter_window_updated active
- When: Further telegraph_updated or counter_window_updated signals arrive
- Then: HUD does not update (elements frozen/hidden); no new rendering calls triggered

### AC-HUD-reset: reset_for_retry is a pass (signals will re-populate after resume)
- Given: System in any state
- When: `reset_for_retry({})` called
- Then: No error; function returns cleanly; HUD state cleared to initial (bars may show 0/empty until signals arrive)

### AC-HUD-death-counter: retry_death_count_changed → death counter updated
- Given: `retry_death_count_changed(3)` received
- When: Handled
- Then: Internal death count = 3 (MVP: stored but not displayed; interface reserved)

### AC-HUD-no-emit: HUDSystem.gd never emits signals
- Given: hud_system.gd source file
- When: grep for `EventBus.*emit` or `signal_name.emit(`
- Then: Zero matches (pure subscriber)

## Test Evidence Path

`game/tests/integration/hud_system/test_hud_reset_guards.gd`

## Out of Scope

- Visual death counter display (MVP: reserved, not displayed)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `reset_for_retry(ctx)` implemented (pass + state clear)
- [ ] boss_defeated guard prevents further signal updates
- [ ] grep confirms zero emit calls in hud_system.gd
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
