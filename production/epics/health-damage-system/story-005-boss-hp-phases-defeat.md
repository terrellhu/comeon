# Story 005: Boss HP, Phase Detection, and Defeat

> **Epic**: HealthDamageSystem
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2–3 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-005`, `TR-HDS-006`, `TR-HDS-009`, `TR-HDS-013`, `TR-HDS-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture (primary); ADR-0002: BossData Resource Architecture (secondary)
**ADR Decision Summary**: Boss phase thresholds (`phase_threshold_pct[]`) and `boss_max_hp` come from `BossData` Resource loaded by BossDataLoader. Signals `boss_hp_changed`, `boss_phase_changed`, and `boss_defeated` are all emitted via EventBus. `entered_phases` is a `Dictionary[int, bool]` that prevents phase re-triggering.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary[int, bool]` is typed in GDScript 4; use `.has(key)` to check membership. `Array[float]` @export for `phase_threshold_pct` is stable. `duplicate_deep()` (Godot 4.5) is not needed for MVP single-Boss case.

**Control Manifest Rules (Core Layer)**:
- Required: `boss_max_hp` and `phase_threshold_pct[]` from BossData asset; never hardcoded
- Required: Emit `boss_hp_changed(current, max_hp, phase)`, `boss_phase_changed(from, to)`, `boss_defeated()` via EventBus
- Forbidden: No float literals for HP or phase thresholds in logic code
- Forbidden: `boss_defeated` must never re-emit after Boss HP has already reached 0

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [ ] **GIVEN** `boss_max_hp = 1000.0` from BossData, `phase_threshold_pct = [0.6, 0.3]`, Phase 2 not yet entered, `current_boss_hp = 650.0`, **WHEN** `apply_damage(BOSS, 75.0)` → hp = 575.0 (< 60% threshold), **THEN** `boss_phase_changed(1, 2)` emitted exactly once; Phase 2 added to `entered_phases`
- [ ] **GIVEN** same config, Phase 2 already in `entered_phases`, **WHEN** `current_boss_hp` drops below 60% again (e.g. via healing then damage), **THEN** `boss_phase_changed` NOT re-emitted for Phase 2
- [ ] **GIVEN** `current_boss_hp = 650.0`, both 60% and 30% thresholds not yet entered, **WHEN** `apply_damage(BOSS, 400.0)` → hp = 250.0 (crosses both thresholds), **THEN** `boss_phase_changed(1, 2)` emitted first, then `boss_phase_changed(2, 3)` emitted second — ascending order, no phase skipped
- [ ] **GIVEN** `current_boss_hp = 30.0`, **WHEN** `apply_damage(BOSS, 30.0)`, **THEN** `current_boss_hp = 0.0`; `boss_defeated` emitted exactly once
- [ ] **GIVEN** Boss already DEFEATED (`current_boss_hp = 0.0`, `boss_defeated` already emitted), **WHEN** `apply_damage(BOSS, 20.0)` (residual attack frame), **THEN** `current_boss_hp` stays 0.0; `boss_defeated` NOT emitted again; no signals
- [ ] **GIVEN** `counter_base_damage = 20`, **WHEN** three sequential `apply_damage(BOSS, ...)` calls with amounts 16.0, 22.0, 32.0 (multipliers 0.8×, 1.1×, 1.6× from CAC formula 1), **THEN** total Boss HP deducted is 70.0 (16+22+32); no special handling needed — system receives pre-calculated amounts and applies them flat
- [ ] **GIVEN** `boss_max_hp = 1000.0` in BossData, **WHEN** the `health_damage_system.gd` source file is inspected, **THEN** the literal `1000.0` does not appear in the logic section; value is read from BossData at init

---

## Implementation Notes

*Derived from ADR-0001, ADR-0002, and GDD Detailed Design:*

- `apply_damage(BOSS, amount)` flow:
  1. Guard: if `_is_boss_defeated`, return immediately (no-op)
  2. Deduct: `current_boss_hp = maxf(0.0, current_boss_hp - amount)`
  3. Emit: `_event_bus.boss_hp_changed.emit(current_boss_hp, _boss_max_hp, _current_phase_index)`
  4. Check phases: iterate `phase_threshold_pct[]` in ascending index order; for each threshold not in `entered_phases`, if `(current_boss_hp / _boss_max_hp) <= threshold_pct`, emit `boss_phase_changed(n, n+1)` and add to `entered_phases`
  5. Check defeat: if `current_boss_hp <= 0.0` and not `_is_boss_defeated`, set `_is_boss_defeated = true`, emit `boss_defeated()`
- Phase detection must iterate all thresholds in a single pass after each damage call — this handles the multi-threshold edge case automatically.
- `entered_phases: Dictionary[int, bool]` — key is phase index (0-based). Check with `.has(n)`.
- `_boss_max_hp` and `phase_threshold_pct[]` are stored from BossData at `init_battle(boss_data)`. Access them as local fields, not by re-reading BossData each call.
- `current_phase_index` can be updated when `boss_phase_changed` is emitted, or read from `entered_phases.size()`. Keep it simple — increment `_current_phase_index` as each phase is entered.
- **Performance**: Phase detection is O(threshold_count) per damage call — with 2 thresholds this is O(1) in practice. System budget: < 1.0ms per-frame under continuous load (TR-HDS-015).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: BossData loading and `current_boss_hp` initialization
- Story 007: `reset_for_retry` — restoring Boss HP after player death

---

## QA Test Cases

**Test file**: `game/tests/unit/health_damage/test_boss_hp_phases.gd` — 18/18 PASS (2026-06-02)

**GDD formulas**: F-02 `boss_damage_intake = counter_base_damage × multiplier[n]`; F-03 `phase_check_triggered = (hp / max) ≤ threshold AND phase NOT IN entered_phases`

- **Boss damage reduces HP**: `apply_damage(BOSS, 70.0)` → `current_boss_hp -= 70.0`; `boss_hp_changed(current, max, phase)` emitted
- **Phase trigger once**: HP crosses 60% → `boss_phase_changed(1, 2)` emitted exactly 1 time
- **Phase idempotency**: Re-crossing same threshold (boundary bounce) → no second `boss_phase_changed`
- **Boss defeat**: `current_boss_hp ≤ 0` → clamp to 0; `boss_defeated` emitted once
- **Post-defeat no-op**: `apply_damage(BOSS, 10)` after defeat → silent no-op; `boss_defeated` not re-emitted
- **Multi-threshold crossing**: Single damage crosses two thresholds → both `boss_phase_changed` signals emitted, lower phase number first (ascending order)
- **entered_phases persistence**: After simulated retry, previously entered phases still in `entered_phases` — not re-triggered
- **Edge cases** (GDD): `apply_damage(BOSS)` after `boss_defeated` → HP stays 0, no re-emit; phase signals fire in ascending order for multi-threshold hits

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_boss_hp_phases.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HP initialization) must be DONE
- Unlocks: Story 007 (retry reset contract)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 7/7 passing
**Deviations**:
- ADVISORY: `_event_bus` typed as `Node` (not `EventBus`) — EventBus autoload has no `class_name`; adding it breaks singleton in headless mode. `@warning_ignore("unsafe_property_access")` is the correct Godot 4 workaround. Documented in field doc comment.
- ADVISORY: `test_hp_initialization.gd` updated (phase assertion 0→1) to fix latent Story 001 bug surfaced by this story's `current_boss_phase = 1` contract.
**Test Evidence**: Logic — `game/tests/unit/health_damage/test_boss_hp_phases.gd` — 21/21 PASS (2026-06-02)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS; all suggestions applied
