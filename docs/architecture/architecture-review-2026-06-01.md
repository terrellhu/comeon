# Architecture Review Report

| Field | Value |
|-------|-------|
| Date | 2026-06-01 |
| Mode | full |
| Engine | Godot 4.6 |
| GDDs Reviewed | 7 (all MVP) |
| ADRs Reviewed | 5 (all Accepted) |
| Verdict | **CONCERNS** |

---

## Traceability Summary

- Total technical requirements: **92**
- ✅ Covered: **86 (93%)**
- ⚠️ Partial: **4**
- ❌ Gap: **2**

All Foundation/Core layer requirements are covered — **no FAIL-level blocking gaps**.
Exceptions are concentrated in Feature/Presentation parameter-storage definition and one
design↔ADR contract conflict. Full per-requirement mapping in
`docs/architecture/requirements-traceability.md`; stable IDs in `docs/architecture/tr-registry.yaml`.

| System | TRs | ✅ | ⚠️ | ❌ |
|--------|-----|----|----|----|
| health-damage-system | 15 | 15 | 0 | 0 |
| player-controller-system | 14 | 14 | 0 | 0 |
| parry-telegraph-system | 14 | 13 | 1 | 0 |
| boss-state-machine | 12 | 12 | 0 | 0 |
| counter-attack-combo | 13 | 10 | 3 | 0 |
| instant-retry-system | 15 | 14 | 0 | 1 |
| hud-system | 9 | 8 | 0 | 1 |

---

## Coverage Gaps & Partials

### ⚠️ TR-PTS-011 — Parry timing override storage undefined
parry GDD formula 1 declares `window_open_fraction` and `window_width` as
"Boss 数据资产可覆盖", and AC-23 forbids them as literals. ADR-0002's `AttackData` schema
only contains `telegraph_duration_override` — no field for these. No ADR decides whether they
are `@export` globals on ParryTelegraphSystem or per-attack overrides in `AttackData`.
- Suggested action: resolve in `/create-control-manifest` or extend ADR-0002 schema.
- Domain: Scripting / Data · Engine Risk: LOW

### ⚠️ TR-CAC-002 / TR-CAC-003 / TR-CAC-006 — Counter combo tuning storage undefined
reback GDD AC-12 requires `counter_base_damage`, `multiplier[n]`, `bonus_ratio`,
`hit_animation_duration`, `base_counter_window` to be "通过数据资产注入". `BossData`
contains none of these. AC-12 validates via a "mock 数据资产" whose schema is unspecified by
any ADR — likely `@export` on CounterAttackComboSystem, but undecided.
- Suggested action: same as above — codify in control manifest or extend ADR-0002.
- Domain: Scripting / Data · Engine Risk: LOW

### ❌ TR-HUD-008 — Counter-bar world-coordinate following unresolved
HUD GDD Open Q1 + architecture.md QQ-04 route this to "ADR-0004 or UX spec", but ADR-0004
(player state machine) does not address world→screen transform. Still open.
- Suggested action: resolve in `/ux-design hud` UX spec, or a small dedicated ADR.
- Domain: UI / Rendering · Engine Risk: LOW (note 4.6 dual-focus is a separate testing concern)

---

## Cross-ADR Conflicts

### 🔴 CONFLICT-01 — ADR-0003 skip guard vs instant-retry AC-03
- **Type**: Integration / Testability
- **ADR-0003 claims** (Risk mitigation): skip input is only listened for after RED_FLASH ends
  (200ms); a 200ms guard prevents residual death-frame input from skipping.
- **instant-retry GDD claims** (AC-03 + skip-logic section): player may skip on ANY frame,
  explicitly including RED_FLASH (0–200ms).
- **Impact**: A test written to AC-03 ("press during RED_FLASH +50ms → immediate skip") FAILS
  against the ADR-0003 implementation. ADR-0003 is also internally inconsistent — its `_process`
  code sample contains no 200ms guard.
- **Resolution options**:
  1. **GDD yields** (recommended): AC-03 → "skippable after RED_FLASH ends (≥200ms)"; update the
     skip-logic description. RED_FLASH is only 0.2s, so the perceptual cost is negligible and the
     200ms anti-misfire guard is sound engineering.
  2. **ADR yields**: remove the guard; rely on same-frame consumption of the death input;
     make ADR-0003 Risk table and `_process` sample consistent (no guard).

### No other conflicts
- ADR-0003 (`SceneTree.paused`) vs ADR-0005 (`Engine.time_scale`): coordinated — ADR-0005
  explicitly proves independence and handles the hitpause→player_died ordering. ✅
- ADR-0001 EventBus vs ADR-0004 direct 1:1 signals: ADR-0001 documents the exception. ✅
- ADR-0003 `reset_for_retry` direct coupling vs ADR-0001 decoupling: documented Negative. ✅
- Single-ownership of `stagger_ended` (CounterAttackComboSystem): consistent across ADR-0001,
  architecture principle 3, and all three relevant GDDs. ✅

---

## ADR Dependency Order

```
Foundation: ADR-0001 Signal Routing       (no deps)
Core data:  ADR-0002 BossData             (requires ADR-0001)
Core flow:  ADR-0003 RetryContext         (requires ADR-0001, ADR-0002)
Core input: ADR-0004 Player State Machine (requires ADR-0001, ADR-0003)
Feature:    ADR-0005 Animation Boundary   (requires ADR-0004)
```
✅ No dependency cycles. All 5 Accepted. No ADR depends on a Proposed/missing ADR.

---

## GDD Revision Flags
**None** — no HIGH RISK engine finding; all GDD assumptions are consistent with verified
Godot 4.6 behaviour.

---

## Engine Compatibility Issues

```
Engine: Godot 4.6
ADRs with Engine Compatibility section: 5 / 5
Version consistency: all ADRs target Godot 4.6 ✅
Deprecated API references: 0 (validation criteria grep for connect("/emit(" string API = 0) ✅
Post-Cutoff API usage:
  - ADR-0002: duplicate_deep() (Godot 4.5) — correctly cited; used only if needed; not MVP ✅
  - ADR-0005: AnimationMixer base-class moves (4.3, in training data) ✅
Post-Cutoff API conflicts between ADRs: none
```

**Minor wording (non-blocking)**: ADR-0005 states `AnimationPlayer.playback_active →
AnimationPlayer.active`; deprecated-apis.md is more precise — the property moved to base class
`AnimationMixer.active` (4.3). Functionally correct since AnimationPlayer extends AnimationMixer.

**MEDIUM-risk tuning/testing items (not API blockers, already noted in architecture.md)**:
D3D12 default + glow-before-tonemapping (4.6) affects death-screen RED_FLASH and HUD glow —
tune on actual D3D12 build; 4.6 dual-focus system — HUD/menu gamepad focus must be tested with
both input methods.

### Runtime verifications carried by ADRs (appropriate — not doc-checkable)
- ADR-0003/0005: `SceneTree.create_timer(d, true, false, true)` counts in real time while
  `Engine.time_scale = 0`.
- ADR-0005: `AnimationPlayer.stop()` does NOT emit `animation_finished` (validates the
  CONNECT_ONE_SHOT + `_exit_state` disconnect interrupt safety).
- ADR-0004: `Input.is_action_just_pressed()` fires once per press in `_physics_process` at 60fps.

---

## Architecture Document Coverage

- `architecture.md` covers all 7 GDD systems + 3 Foundation modules (EventBus, RetryContext,
  BossDataLoader); every systems-index MVP system appears in the layer map. ✅
- **ℹ️ DOC-01 (stale, non-blocking)**: "ADR Audit: No existing ADRs", "ADRs Referenced: None yet",
  and "Required ADRs … Not yet written" no longer hold — ADR-0001..0005 are all Accepted.
  Update the header and those two sections to reference the accepted ADRs.

---

## Verdict: CONCERNS

No blocking gaps (Foundation/Core fully covered, no FAIL). One design↔ADR conflict and four
parameter-storage ambiguities should be clarified before the affected systems enter
implementation. The verdict is advisory — the user decides whether to proceed.

### Should-resolve items (before Production, not strictly blocking)
1. **CONFLICT-01** — reconcile ADR-0003 200ms guard with instant-retry AC-03; sync both docs.
2. **GAP-02** (TR-PTS-011 / TR-CAC-002/003/006) — define parry & counter tuning storage boundary
   (system @export vs Resource override). Best carried by `/create-control-manifest`.
3. **GAP-03** (TR-HUD-008) — resolve counter-bar world-coordinate tracking via UX spec or ADR.
4. **DOC-01** — refresh architecture.md ADR references.

### Required new ADRs
None mandatory. Items 2/3 can be handled by the control manifest or a minor ADR-0002 extension.
