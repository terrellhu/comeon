# Story 004: Guards (boss_defeated/player_died) + reset_for_retry

> **Epic**: CounterAttackComboSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/counter-attack-combo.md` — Edge Cases (boss_defeated, player_died)
**Requirements**: `TR-CAC-010`, `TR-CAC-011`

**ADR Governing Implementation**:
- ADR-0001: boss_defeated/player_died subscribed via EventBus; stagger_ended NOT emitted on interrupt
- ADR-0003: reset_for_retry contract — state=IDLE, hit_count=0, timers=0.0

---

## Acceptance Criteria

### AC-10: boss_defeated → silent IDLE (no stagger_ended)
- Given: COUNTER_WINDOW_OPEN (or BONUS_STAGGER)
- When: `boss_defeated` signal received
- Then: state = IDLE; `stagger_ended` NOT emitted; `apply_damage` NOT called; all timers = 0.0

### AC-11: player_died → silent IDLE (no stagger_ended)
- Given: COUNTER_WINDOW_OPEN
- When: `player_died` signal received
- Then: state = IDLE; `stagger_ended` NOT emitted; all timers = 0.0

### AC-09: Duplicate parry_succeeded during window → discard + warning
- Given: COUNTER_WINDOW_OPEN (window already open)
- When: `parry_succeeded(HEAVY)` received again
- Then: window_timer NOT reset; hit_count NOT reset; `push_warning` called

### AC-reset: reset_for_retry restores clean IDLE state
- Given: System in COUNTER_WINDOW_OPEN with hit_count=2
- When: `reset_for_retry({})` called
- Then: state = IDLE; hit_count = 0; window_timer = 0.0; hit_cooldown_active = false; no signals emitted

## Test Evidence Path

`game/tests/unit/counter_attack_combo/test_cac_guards_reset.gd`

## Out of Scope

- sole-emitter grep check covered at /code-review for Story 003

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `reset_for_retry(ctx: Dictionary)` implemented
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
