# Story 002: Death Screen Animation — 4-Phase Sequence

> **Epic**: InstantRetrySystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/instant-retry-system.md` — States table, Core Rule 2, AC-02
**Requirements**: `TR-IRS-012`

**ADR Governing Implementation**:
- ADR-0003: AnimationPlayer.process_mode = PROCESS_MODE_ALWAYS; 4-phase sequence timing
- ADR-0005: AnimationPlayer animation_finished connection; never `await animation_finished` — use callback

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `AnimationPlayer.stop()` does NOT emit `animation_finished` (Godot 4 spec). Use `CONNECT_ONE_SHOT` for phase-end callbacks OR use AnimationPlayer tracks with Call Method tracks for phase transitions. `process_mode = PROCESS_MODE_ALWAYS` must be set on the AnimationPlayer node as well.

**Control Manifest Rules (Presentation Layer)**:
- Animation names must be StringName constants, never string literals
- AnimationPlayer.process_mode = PROCESS_MODE_ALWAYS required
- Never use `await anim_player.animation_finished`

---

## Acceptance Criteria

### AC-02: 4-phase sequence total = 1.5s (±16.6ms per phase)
- Given: player_died triggers death screen
- When: Full sequence plays without skip
- Then: RED_FLASH = 0.2s; FADE_TO_GREY = 0.4s; PHASE_SYMBOL = 0.6s; SYMBOL_FADE_OUT = 0.3s; total = 1.5s
- Note: GUT headless cannot measure real wall-clock time; test verifies state machine transitions at correct delta accumulation

### AC-02b: State machine progresses through all 4 phases in order
- Given: System in RED_FLASH
- When: Simulated delta = 0.2s passed
- Then: State = FADE_TO_GREY; when 0.4s more passes → PHASE_SYMBOL; when 0.6s more → SYMBOL_FADE_OUT; when 0.3s more → RESUMING

### AC-02-anim: AnimationPlayer has PROCESS_MODE_ALWAYS
- Given: death_screen_anim AnimationPlayer node
- When: Inspected during SceneTree.paused = true
- Then: `anim_player.process_mode == Node.PROCESS_MODE_ALWAYS`

### AC-IRS-phase-symbol: Phase symbol from PhaseData
- Given: RetryContext.preserved_boss_phase = 1; PhaseData[1] has phase_symbol texture
- When: PHASE_SYMBOL state entered
- Then: Correct texture displayed (or node reference set to correct PhaseData.phase_symbol)

## Test Evidence Path

`game/tests/integration/instant_retry_system/test_irs_death_screen.gd`

## Out of Scope

- Skip detection (Story 003)
- Actual visual rendering (deferred to Visual QA + native build)
- Precise ±16.6ms wall-clock verification (native build required)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] Animation phase state machine implemented with delta accumulation
- [ ] AnimationPlayer node process_mode = PROCESS_MODE_ALWAYS
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
