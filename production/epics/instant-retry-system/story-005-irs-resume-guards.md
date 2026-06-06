# Story 005: Resume + boss_defeated Priority Guard

> **Epic**: InstantRetrySystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/instant-retry-system.md` — Core Rules 4, 7; Edge Cases (boss_defeated priority)
**Requirements**: `TR-IRS-010`, `TR-IRS-011`, `TR-IRS-013`, `TR-IRS-015`

**ADR Governing Implementation**:
- ADR-0003: `SceneTree.paused = false` on resume; `retry_death_count_changed` emitted via EventBus
- ADR-0003: `boss_defeated` → `RetryContext.clear_context()`; if boss_defeated fires before player_died, skip the death sequence

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

### AC-IRS-resume: RESUMING state unpauses game and emits count signal
- Given: System in RESUMING state
- When: `_resume_game()` called
- Then: `get_tree().paused == false`; `EventBus.retry_death_count_changed.emit(RetryContext.session_death_count)` called

### AC-10 (TR-IRS-010): boss_defeated → RetryContext.clear_context()
- Given: System in ACTIVE state (no death screen active)
- When: `boss_defeated` signal received
- Then: `RetryContext.clear_context()` called; `preserved_boss_hp == -1.0`

### AC-13 (TR-IRS-013): boss_defeated before player_died — death screen skipped
- Given: System in ACTIVE state
- When: `boss_defeated` received then `player_died` received in same frame
- Then: Death screen NOT triggered; system remains in ACTIVE; `get_tree().paused` NOT set to true

### AC-IRS-context-clear-next: After clear_context, next battle Boss starts full HP
- Given: RetryContext cleared after boss_defeated
- When: Next battle calls `RetryContext.is_fresh_start()`
- Then: Returns true; `preserved_boss_hp < 0`

## Test Evidence Path

`game/tests/integration/instant_retry_system/test_irs_resume_guards.gd`

## Out of Scope

- retry_invuln timer on PlayerController (PlayerController story 006 already implemented this)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `_resume_game()` implemented
- [ ] boss_defeated priority guard implemented
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
