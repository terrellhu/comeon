# Story 004: Retry Reset — _execute_retry_reset + RetryContext

> **Epic**: InstantRetrySystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/instant-retry-system.md` — Core Rules 3, 6; TR-IRS-005 to 009
**Requirements**: `TR-IRS-005`, `TR-IRS-006`, `TR-IRS-007`, `TR-IRS-008`, `TR-IRS-009`

**ADR Governing Implementation**:
- ADR-0003: `_execute_retry_reset()` called during FADE_TO_GREY (200–600ms); calls each system's `reset_for_retry(ctx)` in dependency order: HealthDamageSystem → PlayerController → BossStateMachine → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem
- ADR-0003: `RetryContext.save_context(boss_hp, boss_phase, death_count+1)` called in RED_FLASH phase (0–200ms)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Test by injecting all 6 system references as mocks (GDScript duck-typing). Verify call order by tracking call timestamps or index.

**Control Manifest Rules (Feature Layer)**:
- In-place reset < 100ms wall-clock (not verifiable in GUT headless; marked pending for Profiler)
- Reset order: Foundation → Core → Feature (HealthDamage → PlayerController → BossStateMachine → ParryTelegraph → CounterAttackCombo → HUDSystem)

---

## Acceptance Criteria

### AC-IRS-save-context: RetryContext.save_context called during RED_FLASH
- Given: player_died received; health_system.current_boss_hp = 750; boss_phase = 1; RetryContext.session_death_count = 2
- When: System enters RED_FLASH
- Then: `RetryContext.save_context(750.0, 1, 3)` called (death_count incremented)

### AC-IRS-reset-order: reset_for_retry called on all 6 systems in correct order
- Given: All 6 system references injected as mocks with call-order tracking
- When: `_execute_retry_reset()` called
- Then: Call order: HealthDamageSystem → PlayerController → BossStateMachine → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem

### AC-08 (TR-IRS-008): Boss HP after reset = preserved_boss_hp
- Given: RetryContext.preserved_boss_hp = 600.0
- When: `_execute_retry_reset()` calls `health_system.reset_for_retry(ctx)`
- Then: ctx["boss_hp"] = 600.0 passed to health_system

### AC-IRS-ctx-loaded: RetryContext.load_context used as ctx dict
- Given: RetryContext contains preserved data
- When: `_execute_retry_reset()` runs
- Then: `ctx = RetryContext.load_context()` called; same dict passed to all 6 systems

## Test Evidence Path

`game/tests/integration/instant_retry_system/test_irs_reset.gd`

## Out of Scope

- Wall-clock < 100ms measurement (native Godot Profiler — marked pending)
- Visual rendering of death screen phases

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `_execute_retry_reset()` implemented with correct dependency order
- [ ] `_save_retry_context()` implemented calling RetryContext.save_context
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
