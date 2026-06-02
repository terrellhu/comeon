# Story 007: Retry Reset Contract

> **Epic**: HealthDamageSystem
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2–3 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: —

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: RetryContext and Scene Reset Strategy (primary)
**ADR Decision Summary**: Each system exposes `reset_for_retry(ctx: Dictionary)`. InstantRetrySystem calls these in dependency order. HealthDamageSystem's contract: restore `current_player_hp` to `player_max_hp`; restore `current_boss_hp` from `ctx["boss_hp"]`; clear `invuln_timer`; preserve `entered_phases`. RetryContext is a Godot Autoload (`class_name RetryContextNode`).

**Engine**: Godot 4.6 | **Risk**: LOW (Dictionary API stable; Autoload pattern stable)
**Engine Notes**: `SceneTree.paused` is managed by InstantRetrySystem, not HealthDamageSystem. HealthDamageSystem's `reset_for_retry` is called while the tree is paused — it must complete synchronously and not depend on `_process` or signals firing.

**Control Manifest Rules (Core Layer)**:
- Required: `Every resettable system must implement reset_for_retry(ctx: Dictionary) -> void` and reset ALL stateful variables
- Required: `HealthDamageSystem.reset_for_retry` called by InstantRetrySystem in dependency order (first in the sequence)
- Forbidden: `Never let each system self-reset on player_died independently` — coordinate via InstantRetrySystem only

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [ ] **GIVEN** player died when `current_boss_hp = 750.0`, ctx = `{"boss_hp": 750.0, "boss_phase": 1, "death_count": 1}`, **WHEN** `reset_for_retry(ctx)` called, **THEN** `current_player_hp == player_max_hp` (100.0) and `current_boss_hp == 750.0` (NOT reset to boss_max_hp)
- [ ] **GIVEN** player was INVULNERABLE (`invuln_timer = 0.3`) at death, **WHEN** `reset_for_retry(ctx)` called, **THEN** `invuln_timer == 0.0` (residual invuln cleared)
- [ ] **GIVEN** Phase 2 was entered (`entered_phases` contains phase index 1), **WHEN** `reset_for_retry(ctx)` called, **THEN** `entered_phases` still contains phase index 1 — `boss_phase_changed` NOT re-emitted on retry
- [ ] **GIVEN** `_is_boss_defeated` was false at player death, **WHEN** `reset_for_retry(ctx)` called, **THEN** `_is_boss_defeated` stays false (reset does not change defeat flag if Boss was alive at death)
- [ ] **GIVEN** full integration: `apply_damage(PLAYER, 100.0)` triggers `player_died` → RetryContext saves `{boss_hp: current_boss_hp, ...}` → `reset_for_retry(RetryContext.load_context())` called, **THEN** system is in a consistent state: player_hp = 100, boss_hp = preserved, entered_phases intact

---

## Implementation Notes

*Derived from ADR-0003 Key Interfaces:*

```gdscript
func reset_for_retry(ctx: Dictionary) -> void:
    current_player_hp = player_max_hp       # full player HP restore
    current_boss_hp = ctx["boss_hp"]        # preserved Boss HP, not reset
    invuln_timer = 0.0                      # clear any leftover invuln
    _is_boss_defeated = false               # defensive — boss was alive at player death
    # entered_phases: intentionally NOT cleared — phase transitions up to
    # the preserved phase already occurred; re-triggering them would be incorrect.
    # InstantRetrySystem will set retry invuln via a separate call after paused=false.
```

- `entered_phases` must NOT be cleared. The GDD is explicit: phases entered before death stay entered. The Boss HP is restored to `ctx["boss_hp"]`, which is already past those thresholds.
- `_is_boss_defeated` should be set to false as a defensive reset (can't be dead on retry), though in normal flow it would always be false when `player_died` fires.
- The integration test should exercise the full path via `RetryContext` — do NOT mock RetryContext in the integration test. Use the real Autoload or inject a real instance.
- **GUT headless caveat**: Autoloads are not auto-registered in GUT headless mode. Add RetryContext as an Autoload-like node to the test scene manually (instantiate RetryContextNode and add_child it as "/root/RetryContext") — or inject directly via a parameter rather than the global path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- InstantRetrySystem death screen and scene pause logic (Feature layer epic)
- PlayerController `reset_for_retry` (player-controller epic, Story 007 equivalent)
- The `retry_invuln_duration = 2.0s` post-retry invulnerability (set by InstantRetrySystem after `paused = false`, not by this system)

---

## QA Test Cases

*QL-STORY-READY skipped — Lean mode. Run `/qa-plan health-damage-system` to generate full test specifications.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/health_damage/test_retry_reset.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class.
> Integration test may use a minimal scene with HealthDamageSystem + RetryContextNode (not full game scene).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001–005 (full HP system must be DONE); `retry-context` Foundation epic must be DONE (RetryContextNode Autoload)
- Unlocks: Feature layer epic — InstantRetrySystem can now wire the full retry flow
