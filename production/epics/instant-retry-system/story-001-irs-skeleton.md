# Story 001: InstantRetrySystem Skeleton + player_died Subscription

> **Epic**: InstantRetrySystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/instant-retry-system.md` — Core Rules 1–2, States
**Requirements**: `TR-IRS-001`, `TR-IRS-003`

**ADR Governing Implementation**:
- ADR-0001: `player_died` subscribed via EventBus; `retry_death_count_changed` emitted via EventBus
- ADR-0003: `process_mode = PROCESS_MODE_ALWAYS`; `SceneTree.paused = true` on player_died

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `SceneTree.paused = true` stops all PROCESS_MODE_PAUSEABLE nodes. InstantRetrySystem MUST set `process_mode = PROCESS_MODE_ALWAYS` explicitly in `_ready()` or scene tree, else it stops too. GUT headless: `get_tree().paused` can be set/read in tests; restore to false in `after_each`.

**Control Manifest Rules (Feature Layer)**:
- `process_mode = PROCESS_MODE_ALWAYS` required (ADR-0003)
- Only InstantRetrySystem may set `SceneTree.paused` (ADR-0003)

---

## Acceptance Criteria

### AC-01-setup: System subscribes to player_died and transitions to RED_FLASH state
- Given: System initialized with EventBus
- When: `player_died` emitted
- Then: `system_state == RED_FLASH`; `get_tree().paused == true`; `RetryContext.save_context` called once

### AC-01-process-mode: System continues running during SceneTree.paused
- Given: InstantRetrySystem added to scene, `get_tree().paused = true`
- When: `_process(delta)` or `_unhandled_input` check
- Then: Node is NOT paused (process_mode = PROCESS_MODE_ALWAYS); node processes normally

### AC-IRS-state-machine: State transitions exist for all 6 states
- Given: System initialized
- When: States are inspected
- Then: ACTIVE, RED_FLASH, FADE_TO_GREY, PHASE_SYMBOL, SYMBOL_FADE_OUT, RESUMING states are defined; initial state = ACTIVE

## Test Evidence Path

`game/tests/integration/instant_retry_system/test_irs_skeleton.gd`

## Out of Scope

- Death screen animation phases (Story 002)
- Skip detection via _unhandled_input (Story 003)
- Retry reset (Story 004)
- Resume + guards (Story 005)

## Definition of Done

- [ ] All ACs pass in GUT headless (restore `get_tree().paused = false` in after_each)
- [ ] `instant_retry_system.gd` created in `game/scripts/feature/`
- [ ] `process_mode = PROCESS_MODE_ALWAYS` set
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
