# Story 001: RetryContext Autoload

> **Epic**: Retry Context & Hitpause Infrastructure
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2–3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/instant-retry-system.md`
**Requirements**:
- `TR-IRS-005` — RetryContext saves preserved_boss_hp, preserved_boss_phase, session_death_count
- `TR-IRS-010` — boss_defeated clears preserved_boss_hp; next entry starts Boss at full HP
- `TR-IRS-011` — session_death_count increments per player_died; HUD receives retry_death_count_changed(count)
- `TR-IRS-003` — (partial) Autoload setup enables death-screen pause flow; full verification in InstantRetrySystem epic

**ADR Governing Implementation**: [ADR-0003: RetryContext and Scene Reset Strategy](../../../docs/architecture/adr-0003-retrycontext-scene-reset.md)
**ADR Decision Summary**: RetryContext implemented as a Godot Autoload (`class_name RetryContextNode`) with `save_context / load_context / clear_context / is_fresh_start` methods; in-place reset via ordered `reset_for_retry(ctx)` calls (no scene reload).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `SceneTree.paused`, `Node.process_mode`, and Autoload singleton patterns are stable since Godot 4.0. No post-cutoff breaking changes. Verify at runtime: `Input.is_action_just_pressed()` returns correct values during `SceneTree.paused = true` with `process_mode = PROCESS_MODE_ALWAYS`.

**Control Manifest Rules (Foundation Layer)**:
- Required: RetryContext must be a Godot Autoload registered as "RetryContext" (`autoloads/retry_context.gd`, `class_name RetryContextNode`)
- Required: Autoload registration order — EventBus → RetryContext → HitpauseManager
- Required: Every resettable system must implement `reset_for_retry(ctx: Dictionary) -> void` (interface contract documented here; per-system implementations live in their own epics)
- Required: All systems accept optional EventBus injection for GUT testability
- Forbidden: `get_tree().set_meta()` for RetryContext — less type-safe than Autoload; string key lookup is error-prone

---

## Acceptance Criteria

*From GDD `design/gdd/instant-retry-system.md`, scoped to this story:*

- [ ] **AC-04** — RetryContext stores `preserved_boss_hp` (Boss HP at death), `preserved_boss_phase`, and `session_death_count = N + 1`; values survive in-place reset and are readable when the new scene frame begins
- [ ] **AC-10** — On `boss_defeated` signal, `clear_context()` resets `preserved_boss_hp = -1.0`; `is_fresh_start()` returns `true`; next fight Boss starts at full HP (no stale preserved value)
- [ ] **AC-13** — 调用 `save_context(boss_hp, boss_phase, N+1)` 后，`session_death_count = N + 1` 存入 RetryContext；`load_context()["death_count"]` 返回更新后的值。（`retry_death_count_changed` 信号发送由 InstantRetrySystem 史诗负责。）
- [ ] **AC-is_fresh_start** — `is_fresh_start()` returns `true` when `preserved_boss_hp < 0.0` (no prior save); returns `false` after `save_context()` is called; returns `true` again after `clear_context()`
- [ ] **Autoload registered** — `RetryContext` registered as Autoload in Project Settings in the correct order: EventBus → RetryContext → HitpauseManager
- [ ] **reset_for_retry contract documented** — A doc comment in `retry_context.gd` defines the `reset_for_retry(ctx: Dictionary) -> void` interface that all resettable systems must implement (per ADR-0003); the contract specifies reset ordering: HealthDamageSystem → PlayerController → BossStateMachine → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

Create `game/autoloads/retry_context.gd`:

```gdscript
class_name RetryContextNode
extends Node

var preserved_boss_hp: float = -1.0      # -1 = fresh start (no saved context)
var preserved_boss_phase: int = 0
var session_death_count: int = 0

func save_context(boss_hp: float, boss_phase: int, death_count: int) -> void:
    preserved_boss_hp = boss_hp
    preserved_boss_phase = boss_phase
    session_death_count = death_count

func load_context() -> Dictionary:
    return {
        "boss_hp": preserved_boss_hp,
        "boss_phase": preserved_boss_phase,
        "death_count": session_death_count
    }

func clear_context() -> void:
    # Called on boss_defeated — clears preserved HP so next fight starts fresh
    preserved_boss_hp = -1.0
    preserved_boss_phase = 0
    # session_death_count intentionally NOT cleared — accumulates across fights in session

func is_fresh_start() -> bool:
    return preserved_boss_hp < 0.0
```

**reset_for_retry interface contract** (document as a doc comment in the file, below the class definition):

```gdscript
## reset_for_retry(ctx: Dictionary) -> void
## Contract: every resettable game system must implement this method.
## Called by InstantRetrySystem._execute_retry_reset() in this order:
##   HealthDamageSystem → PlayerController → BossStateMachine
##   → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem
## ctx keys: "boss_hp" (float), "boss_phase" (int), "death_count" (int)
## Each system resets ALL its stateful variables to post-death-screen initial values.
## Missing a variable here is a latent gameplay bug.
```

**Registration**: Add to Project Settings → Autoload **after** EventBus and **before** HitpauseManager. Name must be exactly "RetryContext".

**EventBus signal**: `retry_death_count_changed` must already exist on EventBus (owned by signal-infrastructure epic). Emit via `EventBus.retry_death_count_changed.emit(count)` in the InstantRetrySystem (this story only defines the Autoload API — signal emission on retry occurs in the InstantRetrySystem feature story).

**session_death_count**: `save_context()` receives the already-incremented count. The caller (InstantRetrySystem) computes `RetryContext.session_death_count + 1` before calling. This keeps RetryContext a pure data store with no arithmetic logic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: HitpauseManager Autoload (`trigger_hitpause()`, `Engine.time_scale = 0`)
- [InstantRetrySystem epic]: `SceneTree.paused = true` on `player_died`; ordering the `reset_for_retry()` call chain; emitting `retry_death_count_changed`; the full death-screen state machine
- [Per-system epics]: Concrete `reset_for_retry(ctx)` implementations in HealthDamageSystem, PlayerController, BossStateMachine, etc.

---

## QA Test Cases

*Logic story — automated test specs.*

**File**: `game/tests/unit/retry_context/retry_context_test.gd`

- **AC-04**: save→load round-trip
  - Given: RetryContext Autoload is freshly initialized (`preserved_boss_hp = -1.0`)
  - When: `save_context(350.0, 1, 3)` is called
  - Then: `load_context()` returns `{"boss_hp": 350.0, "boss_phase": 1, "death_count": 3}` — exact values, no rounding
  - Edge cases: save with `boss_hp = 0.0` (Phase 1 hit to zero); save with `boss_phase = 2` (Phase 2 preserved)

- **AC-10**: clear_context resets preserved HP only
  - Given: `save_context(100.0, 2, 7)` was called
  - When: `clear_context()` is called
  - Then: `preserved_boss_hp == -1.0`; `preserved_boss_phase == 0`; `session_death_count == 7` (NOT cleared)
  - Edge cases: `is_fresh_start()` returns `true` after clear; calling `clear_context()` on a never-saved Autoload is a no-op (no crash)

- **AC-13**: session_death_count stored correctly
  - Given: `session_death_count = 0` (initial)
  - When: `save_context(200.0, 0, 1)` called (caller computed count+1 externally)
  - Then: `load_context()["death_count"] == 1`
  - Edge cases: N = 50 (no truncation, no cap)

- **AC-is_fresh_start**: fresh start detection
  - Given: Autoload just initialized
  - When: `is_fresh_start()` called
  - Then: returns `true`
  - When: `save_context(100.0, 0, 1)` called, then `is_fresh_start()` called
  - Then: returns `false`
  - When: `clear_context()` called, then `is_fresh_start()` called
  - Then: returns `true`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `game/tests/unit/retry_context/retry_context_test.gd` — must exist and pass in CI

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: [signal-infrastructure Epic] — `EventBus` Autoload must be registered first; `retry_death_count_changed` signal must exist on EventBus
- Unlocks: Story 002 (HitpauseManager can register after RetryContext); InstantRetrySystem feature epic (calls RetryContext API)

---

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 6/6 passing
**Deviations**: None
**Test Evidence**: Logic — `game/tests/unit/retry_context/retry_context_test.gd` 13/13 passed (0.479s)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (test naming minor improvement noted, no blocking issues)
