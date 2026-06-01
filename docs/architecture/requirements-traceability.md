# Architecture Traceability Index

> Last Updated: 2026-06-01
> Engine: Godot 4.6
> Source: /architecture-review (full mode)

## Coverage Summary

- Total requirements: 92
- ✅ Covered: 86 (93%)
- ⚠️ Partial: 4
- ❌ Gap: 2

Verdict: **CONCERNS** — no Foundation/Core gaps; exceptions are Feature/Presentation
parameter-storage ambiguities and one design↔ADR conflict (see Known Gaps).

## Per-System Coverage

| System | TRs | ✅ | ⚠️ | ❌ | Governing ADRs |
|--------|-----|----|----|----|----------------|
| health-damage-system (HDS) | 15 | 15 | 0 | 0 | ADR-0001, ADR-0002 |
| player-controller-system (PC) | 14 | 14 | 0 | 0 | ADR-0004, ADR-0001, ADR-0003 |
| parry-telegraph-system (PTS) | 14 | 13 | 1 | 0 | ADR-0001, ADR-0002, ADR-0005 |
| boss-state-machine (BSM) | 12 | 12 | 0 | 0 | ADR-0002, ADR-0005, ADR-0001 |
| counter-attack-combo (CAC) | 13 | 10 | 3 | 0 | ADR-0001, ADR-0002, ADR-0005 |
| instant-retry-system (IRS) | 15 | 14 | 0 | 1 | ADR-0003, ADR-0001, ADR-0002 |
| hud-system (HUD) | 9 | 8 | 0 | 1 | ADR-0001 |

## Full Matrix

Covered requirements are mapped to their governing ADR. Only non-Covered rows are
detailed individually below; all other TR-IDs in each system are ✅ Covered by the
listed governing ADR(s).

### health-damage-system — all ✅
TR-HDS-001..003, 011 → ADR-0001 (apply_damage signal contracts, no-op rules) ·
TR-HDS-004, 005, 006, 009, 013 → ADR-0001 (signal definitions on EventBus) ·
TR-HDS-007 → ADR-0003 (entered_phases persists; reset_for_retry keeps as-is) ·
TR-HDS-008, 012 → ADR-0001 (healing/segment signal outputs) ·
TR-HDS-010 → ADR-0002 (boss_max_hp + phase_threshold_pct from BossData) ·
TR-HDS-014 → ADR-0002 (counter multiplier injection) · TR-HDS-015 → ADR-0001 (perf).

### player-controller-system — all ✅
TR-PC-001, 008, 012 → ADR-0004 (CharacterBody2D + _process_state) ·
TR-PC-002, 004 → ADR-0004 (enum SM + parry-priority early return) ·
TR-PC-003, 011 → ADR-0004 (@export params, StringName actions) ·
TR-PC-005 → ADR-0004 (coyote/jump-buffer timers) ·
TR-PC-006, 007, 013 → ADR-0001 + ADR-0004 (direct 1:1 signals) ·
TR-PC-009 → ADR-0004 (HIT_STUN knockback) ·
TR-PC-010 → ADR-0004 + ADR-0003 (DEAD exits only via reset_for_retry) ·
TR-PC-014 → ADR-0004 (perf).

### parry-telegraph-system — 13 ✅ / 1 ⚠️
TR-PTS-001, 005, 006, 007, 008, 012, 013 → ADR-0001 (signal routing) ·
TR-PTS-009 → ADR-0001 (per-frame telegraph_updated) ·
TR-PTS-002, 003, 004, 014 → covered by GDD formulas; signal/timer pattern via ADR-0001 ·
TR-PTS-010 → ADR-0001 + GDD (STAGGERING removed, lifecycle to CAC).
- ⚠️ **TR-PTS-011** PARTIAL → ADR-0002 provides `AttackData.telegraph_duration_override`
  only. `window_open_fraction`, `window_width`, `stagger_duration` per-Boss override
  (GDD formula 1 "Boss 数据资产可覆盖") have NO schema field and no ADR defining whether
  they live as @export on ParryTelegraphSystem or in AttackData.

### boss-state-machine — all ✅
TR-BSM-001, 004, 007, 011 → ADR-0004 pattern reused (enum + _transition_to) ·
TR-BSM-002, 003, 009 → ADR-0002 (BossData/PhaseData/AttackData + _validate) ·
TR-BSM-005, 008 → ADR-0005 (CONNECT_ONE_SHOT + _exit_state disconnect; boss_defeated terminal) ·
TR-BSM-006, 012 → ADR-0001 (attack_telegraphed emit order, decoupled signals) ·
TR-BSM-010 → ADR-0005 (animation_finished-driven ATTACKING→IDLE; StringName anim consts).

### counter-attack-combo — 10 ✅ / 3 ⚠️
TR-CAC-001, 007, 008, 010, 011, 013 → ADR-0001 (signal routing; sole stagger_ended emitter) ·
TR-CAC-004 → ADR-0005 (hit cooldown / hitpause coordination) ·
TR-CAC-005 → ADR-0001 + ADR-0005 (full-combo signal + 30ms hitpause) ·
TR-CAC-009 → ADR-0001 (apply_damage calls) · TR-CAC-012 → covered by GDD load-time clamp.
- ⚠️ **TR-CAC-002** PARTIAL → `base_counter_window[type]` storage location undefined by any ADR.
- ⚠️ **TR-CAC-003** PARTIAL → `counter_base_damage` + `multiplier[n]` injection source undefined
  (BossData has no such fields; AC-12 uses a "mock data asset" whose schema is unspecified).
- ⚠️ **TR-CAC-006** PARTIAL → `bonus_ratio` storage location undefined by any ADR.

### instant-retry-system — 14 ✅ / 1 ❌
TR-IRS-001, 011, 013 → ADR-0001 (player_died/boss_defeated routing; retry_death_count_changed) ·
TR-IRS-002 → ADR-0002 (phase_symbol from PhaseData) ·
TR-IRS-003, 004, 005, 006, 007, 008, 009, 010 → ADR-0003 (pause, RetryContext, in-place reset) ·
TR-IRS-012, 014, 015 → GDD + Art Bible 7.5 (death-screen sequence, no-UI rule).
- ❌ **TR-IRS-004** CONFLICT → ADR-0003 Risk mitigation introduces a 200ms input-blackout
  before skip is accepted; GDD AC-03 requires skip on ANY frame including RED_FLASH (0–200ms).
  See Known Gaps / CONFLICT-01. (Requirement itself is covered; the implementation contract conflicts.)

### hud-system — 8 ✅ / 1 ❌
TR-HUD-001, 002, 003, 004, 005, 006, 007, 009 → ADR-0001 (pure-subscriber routing; per-frame perf).
- ❌ **TR-HUD-008** GAP → counter-bar world-coordinate following deferred to "ADR-0004 or
  UX spec" but ADR-0004 (player state machine) does not address it. Unresolved.

## Known Gaps & Conflicts

### 🔴 CONFLICT-01 — ADR-0003 200ms skip guard vs instant-retry AC-03
ADR-0003 (Risk table) blocks skip input for the first 200ms (RED_FLASH) to avoid residual
death-frame input; instant-retry GDD AC-03 + skip-logic require skip on any frame including
RED_FLASH. A test written to AC-03 fails against the ADR implementation. ADR-0003's own code
sample (`_process`) has no guard, so the ADR is also internally inconsistent.
**Resolution (pick one):** (A) GDD AC-03 → "skippable after RED_FLASH ends (≥200ms)" [recommended];
(B) ADR-0003 drops the guard and relies on same-frame player_died input consumption.

### ⚠️ GAP-02 — Parry & counter tuning parameter storage undefined
ADR-0002 BossData/AttackData schema covers `damage` and `telegraph_duration_override` only.
It does NOT define where these live: parry `window_open_fraction` / `window_width` /
`stagger_duration` overrides, and counter `counter_base_damage` / `multiplier[n]` /
`bonus_ratio` / `hit_animation_duration` / `base_counter_window`.
**Resolution:** Codify storage (system @export vs Resource override) in `/create-control-manifest`,
or extend ADR-0002's schema. Affects TR-PTS-011, TR-CAC-002/003/006.

### ⚠️ GAP-03 — HUD counter-bar world-coordinate tracking (TR-HUD-008)
Unresolved; route to `/ux-design hud` UX spec or a small new ADR. Priority: low (Presentation).

### ℹ️ DOC-01 — architecture.md stale
"ADR Audit: No existing ADRs", "ADRs Referenced: None yet", and "Required ADRs … Not yet written"
are stale now that ADR-0001..0005 are all Accepted. Update references. Non-blocking.

## ADR Dependency Order (topological)

```
Foundation: ADR-0001 Signal Routing (no deps)
Core data:  ADR-0002 BossData            (needs 0001)
Core flow:  ADR-0003 RetryContext        (needs 0001, 0002)
Core input: ADR-0004 Player State Machine(needs 0001, 0003)
Feature:    ADR-0005 Animation Boundary  (needs 0004)
```
No cycles. All 5 Accepted. No dangling references to Proposed ADRs.

## Superseded Requirements
None. Initial registry population — no requirements reworded or removed since ADR authoring.
