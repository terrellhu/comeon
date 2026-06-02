# Story 003: Player Death Detection and HP Clamping

> **Epic**: HealthDamageSystem
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-003`, `TR-HDS-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture (primary)
**ADR Decision Summary**: `player_died` is a typed signal on `EventBus`. It must be emitted synchronously (same call stack as the killing `apply_damage` call) — Godot signal emission is synchronous, so this is guaranteed. Four subscribers connect to it: InstantRetrySystem, PlayerController, ParryTelegraphSystem, CounterAttackComboSystem.

**Engine**: Godot 4.6 | **Risk**: LOW (signal emission is synchronous and stable)
**Engine Notes**: Godot typed signal calls fire all connected callbacks before the emit line returns. `player_died` subscribers will have run before `apply_damage` returns. Design depends on this guarantee.

**Control Manifest Rules (Core Layer)**:
- Required: Emit `player_died()` via EventBus when `current_player_hp <= 0`
- Required: HP invariant — `current_player_hp` must always be in `[0, player_max_hp]`; negative HP must never be stored
- Forbidden: No buffer, delay, or frame gap between HP hitting 0 and `player_died` emission

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [x] **GIVEN** player ALIVE, `current_player_hp = 15.0`, **WHEN** `apply_damage(PLAYER, 40)`, **THEN** `current_player_hp` is clamped to 0.0 (NOT −25.0), and `player_died` is emitted the same frame with no buffer
- [x] **GIVEN** player ALIVE, `current_player_hp = 10.0`, **WHEN** `apply_damage(PLAYER, 100)`, **THEN** `current_player_hp` == 0.0; negative value never written to HP field
- [x] **GIVEN** player ALIVE, `current_player_hp = 80.0`, **WHEN** `apply_damage(PLAYER, 40)`, **THEN** `current_player_hp` == 40.0 and `player_died` is NOT emitted (death threshold not crossed)
- [x] **GIVEN** player ALIVE, `current_player_hp = 20.0`, **WHEN** `apply_damage(PLAYER, 20.0)` (exact lethal), **THEN** `current_player_hp` == 0.0 and `player_died` emitted once (boundary case)
- [x] **GIVEN** player has already died (`current_player_hp == 0` and `player_died` already emitted), **WHEN** another `apply_damage(PLAYER, 10)` arrives, **THEN** `player_died` is NOT emitted again (no duplicate; invuln window from prior hit handles this in most cases — but the DEAD state also guards)

---

## Implementation Notes

*Derived from ADR-0001 and GDD Detailed Design:*

- Death check runs inside `apply_damage` after the damage deduction and clamp:
  ```gdscript
  current_player_hp = maxf(0.0, current_player_hp - amount)
  _event_bus.player_hp_changed.emit(current_player_hp, player_max_hp)
  if current_player_hp <= 0.0:
      _event_bus.player_died.emit()
  ```
- The `player_hp_changed` signal is emitted BEFORE `player_died` (subscribers need the updated HP before handling death).
- No state flag needed to suppress duplicate `player_died` — the invulnerability window (0.5s from Story 002) prevents re-entry naturally. Confirm this is sufficient or add an explicit `_is_dead: bool` guard if edge cases emerge.
- HP clamp: `current_player_hp = maxf(0.0, current_player_hp - amount)` — use `maxf`, not a conditional, for clarity and single-line guarantee.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Invulnerability window (which prevents re-entry in most post-death scenarios)
- Story 007: `reset_for_retry` — restoring HP after death is part of the retry contract

---

## QA Test Cases

*QL-STORY-READY skipped — Lean mode. Run `/qa-plan health-damage-system` to generate full test specifications.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_player_death.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class.

**Status**: [x] `game/tests/unit/health_damage/test_player_death.gd` — 10/10 PASS (36/36 total suite, 2026-06-02)

---

## Dependencies

- Depends on: Story 002 (player damage + invuln) must be DONE
- Unlocks: Story 004 (healing), Story 007 (retry reset)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 5/5 passing (plus 1 bonus signal-ordering test)
**Deviations**: OUT OF SCOPE — `mock_event_bus.gd` modified with additive `player_died_call_count` tracking; backward-compatible, accepted. ADVISORY — post-invuln-expiry duplicate `player_died` is an untested design assumption (SceneTree.paused prevents it in normal gameplay via ADR-0003 / InstantRetrySystem); zero-invuln-duration edge case also untested.
**Test Evidence**: Logic — `game/tests/unit/health_damage/test_player_death.gd` — 10/10 PASS (36/36 total suite)
**Code Review**: Complete — APPROVED (0 required changes; 3 advisory suggestions noted)
