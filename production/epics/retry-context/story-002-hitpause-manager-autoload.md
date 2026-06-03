# Story 002: HitpauseManager Autoload + Runtime Verification

> **Epic**: Retry Context & Hitpause Infrastructure
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2–3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/instant-retry-system.md` (mechanism only — hitpause feel moments defined per-system in combat epics)
**Requirements**:
- `TR-IRS-006` — (partial) In-place reset < 100ms; HitpauseManager Autoload must exist before any combat system uses it; runtime verification of real-time timer at `Engine.time_scale = 0`
- ADR-0005 scope: `HitpauseManager.trigger_hitpause(duration)` with `_active` re-entrancy guard; `Engine.time_scale = 0.0` + `create_timer(d, true, false, true)` real-time countdown

**ADR Governing Implementation**: [ADR-0005: Animation to Code Boundary](../../../docs/architecture/adr-0005-animation-to-code-boundary.md) (primary); [ADR-0003: RetryContext and Scene Reset Strategy](../../../docs/architecture/adr-0003-retrycontext-scene-reset.md) (secondary — defines that SceneTree.paused and Engine.time_scale are independent mechanisms; hitpause must not interfere with death-screen pause)

**ADR Decision Summary**: HitpauseManager Autoload uses `Engine.time_scale = 0.0` + `SceneTree.create_timer(duration, true, false, true)` for real-time countdown. A `_active: bool` re-entrancy guard ensures nested hitpause requests are silently dropped (first request wins). `SceneTree.paused` (death screen) and `Engine.time_scale` (hitpause) are independent and do not conflict.

**Engine**: Godot 4.6 | **Risk**: LOW (APIs stable, but runtime verification required)
**Engine Notes**: `create_timer(duration, ignore_time_scale=true, process_always=false, process_in_physics=true)` — the 4th argument `true` makes this timer use real time even when `Engine.time_scale = 0`. **Must be verified at runtime on target hardware** before marking this story Done (ADR-0005 Verification Required). Also confirm `_active` guard correctly handles the edge case where `player_died` fires during an active hitpause.

**Control Manifest Rules (Foundation Layer)**:
- Required: HitpauseManager must be a Godot Autoload registered as "HitpauseManager" (`autoloads/hitpause_manager.gd`, `class_name HitpauseManagerNode`)
- Required: Autoload registration order — EventBus → RetryContext → HitpauseManager
- Required: HitpauseManager must guard against re-entry — `if _active: return` at top of `trigger_hitpause()`
- Forbidden: `SceneTree.paused = true` for hitpause — reserved for death screen (ADR-0003); mixing creates unresolvable ordering bugs
- Forbidden: per-system `_hitpause_frames: int` counter — framerate-dependent; wrong at 144fps

---

## Acceptance Criteria

*From ADR-0005 Validation Criteria and Epic scope, scoped to this story:*

- [ ] **AC-trigger** — `trigger_hitpause(duration)` sets `Engine.time_scale = 0.0` immediately on call; restores `Engine.time_scale = 1.0` after `duration` seconds of **real time** (not game time); `_active = false` after completion
- [ ] **AC-timing** — `trigger_hitpause(0.060)` duration measured at runtime: `Engine.time_scale` returns to `1.0` within `60ms ± 16.6ms` (1 frame tolerance at 60fps)
- [ ] **AC-reentrance** — While `_active == true` (hitpause in progress), a second call to `trigger_hitpause(any_duration)` returns immediately with no effect; the first hitpause runs to natural completion
- [ ] **AC-timer-verify** — Runtime verification confirms `SceneTree.create_timer(0.060, true, false, true)` counts down in real time while `Engine.time_scale = 0.0`; result logged at startup or in test output
- [ ] **AC-independence** — `Engine.time_scale` and `SceneTree.paused` are independent: if `SceneTree.paused = true` is set while `_active == true`, `Engine.time_scale` is restored to `1.0` and `_active = false` before or after the pause resolves (no leaked `time_scale = 0` state)
- [ ] **Autoload registered** — `HitpauseManager` registered as Autoload in Project Settings after EventBus and RetryContext; accessible as `HitpauseManager.trigger_hitpause(duration)` from any system

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

Create `game/autoloads/hitpause_manager.gd`:

```gdscript
class_name HitpauseManagerNode
extends Node

var _active: bool = false  # re-entrancy guard

func trigger_hitpause(duration_secs: float) -> void:
    if _active:
        return  # first hitpause wins; nested requests dropped silently
    _active = true
    Engine.time_scale = 0.0
    # ignore_time_scale=true: timer counts in real time even at time_scale=0
    var timer := get_tree().create_timer(duration_secs, true, false, true)
    await timer.timeout
    Engine.time_scale = 1.0
    _active = false
```

**Edge case — player_died fires during active hitpause**: ADR-0003 defines that `SceneTree.paused = true` (death screen) and `Engine.time_scale = 0` (hitpause) are independent. When `player_died` fires mid-hitpause:
1. InstantRetrySystem sets `SceneTree.paused = true`
2. HitpauseManager's `await timer.timeout` is on a `PROCESS_ALWAYS` real-time timer — it will still complete
3. When the timer fires, `Engine.time_scale = 1.0` is restored and `_active = false`
4. Death screen then runs with `SceneTree.paused = true` (correct state)

No special handling needed in HitpauseManager itself. The independence of the two mechanisms handles this correctly.

**GUT testability**: `Engine.time_scale = 0.0` freezes GUT's runner. Do NOT test the actual freeze behavior in unit tests — instead write unit tests that verify `_active` flag behavior with a mock/stub timer. Runtime verification (AC-timer-verify) must be run manually or in a dedicated integration test that uses real `SceneTree.create_timer`.

**Call sites** (implemented in their respective epics, not here):
- HealthDamageSystem: `HitpauseManager.trigger_hitpause(0.060)` on player hit
- ParryTelegraphSystem: `HitpauseManager.trigger_hitpause(0.060)` on parry success
- CounterAttackComboSystem: `HitpauseManager.trigger_hitpause(0.080)` on 3rd hit; `trigger_hitpause(0.030)` on full-combo BONUS_STAGGER entry

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: RetryContext Autoload (must be registered before this story)
- [Health-damage-system epic]: Calling `trigger_hitpause(0.060)` on player hit
- [Parry-telegraph-system epic]: Calling `trigger_hitpause(0.060)` on parry success
- [Counter-attack-combo epic]: Calling `trigger_hitpause(0.080)` / `(0.030)` on combo hits
- [InstantRetrySystem epic]: Full death-screen state machine; `SceneTree.paused = true` on `player_died`

---

## QA Test Cases

*Logic story — automated test specs (with GUT testability caveat noted).*

**File**: `game/tests/unit/hitpause/hitpause_manager_test.gd`

> **GUT caveat**: `Engine.time_scale = 0` freezes GUT's runner. Unit tests must use a mock/stub approach for the timer so GUT can run. Verify AC-timing and AC-timer-verify manually or in a separate integration scene. The unit tests below verify logic and guard behavior only.

- **AC-reentrance (unit testable)**: re-entrancy guard blocks nested calls
  - Given: A mock HitpauseManagerNode with `_active = true` (manually set for test)
  - When: `trigger_hitpause(0.080)` called
  - Then: method returns immediately; `Engine.time_scale` unchanged (still `0.0`); no second `await` started
  - Edge cases: `_active` starts `false`, single call sets it `true`; after completion sets it back `false`

- **AC-trigger (integration — requires real SceneTree)**: time_scale set and restored
  - Given: `Engine.time_scale = 1.0`, `HitpauseManager._active = false`
  - When: `trigger_hitpause(0.060)` called and awaited
  - Then: During hitpause `Engine.time_scale == 0.0`; after completion `Engine.time_scale == 1.0` and `_active == false`
  - Edge cases: `duration = 0.030` (shortest hitpause — full-combo); `duration = 0.080` (longest — 3rd hit)

- **AC-timer-verify (manual runtime check)**: real-time timer at time_scale=0
  - Setup: Run `trigger_hitpause(0.060)` in a scene with `Engine.time_scale = 0.0` active
  - Verify: `Time.get_ticks_msec()` before and after confirm ~60ms elapsed (real time, not game time)
  - Pass condition: Elapsed real time = 60ms ± 16.6ms; `Engine.time_scale` restored to 1.0 afterward
  - Log this result to console for audit: `print("[HitpauseManager] timer verify: %dms elapsed" % elapsed)`

- **AC-independence (integration)**: no leaked time_scale on SceneTree.paused
  - Given: `trigger_hitpause(0.500)` called (long duration)
  - When: Before timer completes, `get_tree().paused = true` is set externally
  - Then: When `get_tree().paused = false` is later restored, `Engine.time_scale == 1.0` (no leaked 0 state)
  - Note: This edge case relies on natural behavior — the awaited timer still fires in real time. Verify manually if needed.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `game/tests/unit/hitpause/hitpause_manager_test.gd` — guard behavior tests must exist and pass in CI
- Runtime verification result logged (AC-timer-verify) — acceptable as console output in a test scene or integration test

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (RetryContext) must be Done — Autoload registration order requires RetryContext registered first
- Unlocks: All combat system epics that call `HitpauseManager.trigger_hitpause()` (health-damage, parry-telegraph, counter-attack-combo)

---

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 6/6 passing (AC-timing, AC-timer-verify, AC-independence: 수동 런타임 확인 완료)
**Deviations**: 2 Advisory — logged to tech-debt-register.md
**Test Evidence**: Logic — `game/tests/unit/hitpause/hitpause_manager_test.gd` 4/7 automated pass + 3 manual verified (0.512s)
**Code Review**: Complete — CHANGES REQUIRED (주석 수정) → 수정 후 APPROVED WITH SUGGESTIONS
