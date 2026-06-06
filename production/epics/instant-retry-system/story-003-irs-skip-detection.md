# Story 003: Skip Detection via _unhandled_input

> **Epic**: InstantRetrySystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/instant-retry-system.md` — Core Rule 5; States table skip logic
**Requirements**: `TR-IRS-004`

**ADR Governing Implementation**:
- ADR-0003 REVISED (S002-I01 2026-06-06): Use `_unhandled_input(event)` + `event.is_pressed() and not event.is_echo()` — NO 200ms delay; responds to fresh presses only, active in all death-screen states including RED_FLASH

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_unhandled_input(event: InputEvent)` fires on PROCESS_MODE_ALWAYS nodes even during SceneTree.paused = true. `event.is_pressed()` = true for key/button down; `event.is_echo()` = true for held-key repeat events. Test by calling `_unhandled_input(fake_event)` directly in GUT.

**Control Manifest Rules (Feature Layer)**:
- Use `_unhandled_input(event)` NOT `Input.is_anything_pressed()` (CONFLICT-01 resolved)
- Skip active in ALL death-screen states (no 200ms delay)

---

## Acceptance Criteria

### AC-IRS-skip-fresh: Fresh key press during RED_FLASH skips to RESUMING
- Given: System in RED_FLASH state (SceneTree.paused = true)
- When: `_unhandled_input` called with `InputEventKey { pressed=true, echo=false }`
- Then: `death_screen_anim.stop()` called; state transitions to RESUMING; `get_tree().paused = false`

### AC-IRS-skip-held: Held key (echo) does NOT skip
- Given: System in PHASE_SYMBOL state
- When: `_unhandled_input` called with `InputEventKey { pressed=true, echo=true }` (held)
- Then: State remains PHASE_SYMBOL; animation not stopped

### AC-IRS-skip-any-state: Skip works in all death-screen states
- Given: System in each of RED_FLASH / FADE_TO_GREY / PHASE_SYMBOL / SYMBOL_FADE_OUT
- When: Fresh key press `_unhandled_input(event)` called
- Then: Each state transitions to RESUMING immediately

### AC-IRS-skip-gamepad: Gamepad button also triggers skip
- Given: System in FADE_TO_GREY
- When: `_unhandled_input` called with `InputEventJoypadButton { pressed=true }`
- Then: State transitions to RESUMING

## Test Evidence Path

`game/tests/integration/instant_retry_system/test_irs_skip.gd`

## Out of Scope

- Actual InputEvent injection via Input system (test calls `_unhandled_input` directly with fabricated events)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `_unhandled_input(event)` implemented with `event.is_pressed() and not event.is_echo()` check
- [ ] 200ms delay code absent
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
