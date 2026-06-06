# Story 006: HUD Segment Count Formula

> **Epic**: HealthDamageSystem
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure formula, no architectural pattern required. The formula is fully specified by the GDD and requires no cross-module signal or data-layer decision.
**ADR Decision Summary**: N/A

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ceili()` (integer result) vs `ceil()` (float result) — use `ceili()` if the return type is `int`, or cast `int(ceil(...))`. Confirm which is cleaner in GDScript 4. The GDD specifies `ceil()`.

**Control Manifest Rules (Core Layer)**:
- Required: HP invariant — the formula input must always use the clamped `current_player_hp` (never negative)
- Forbidden: No hardcoded segment count or HP-per-segment literals in logic

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [ ] **GIVEN** `player_max_hp = 100.0`, `player_hp_segments = 5`, `current_player_hp = 61.0`, **WHEN** `get_displayed_segments()` called, **THEN** returns `4` (`ceil(61/20) = ceil(3.05) = 4`)
- [ ] **GIVEN** `current_player_hp = 60.0`, **WHEN** `get_displayed_segments()` called, **THEN** returns `3` (`ceil(60/20) = ceil(3.0) = 3` — integer boundary triggers the segment drop)
- [ ] **GIVEN** `current_player_hp = 0.0`, **WHEN** `get_displayed_segments()` called, **THEN** returns `0` — the special-case guard fires before the formula, not relying on `ceil(0/20) = 0`
- [ ] **GIVEN** `current_player_hp = 1.0`, **WHEN** `get_displayed_segments()` called, **THEN** returns `1` (`ceil(1/20) = ceil(0.05) = 1` — even trace HP shows 1 segment, never 0 while alive)
- [ ] **GIVEN** `current_player_hp = 100.0` (full HP), **WHEN** `get_displayed_segments()` called, **THEN** returns `5` (full bar)

---

## Implementation Notes

*Derived from GDD Formula 4:*

```gdscript
func get_displayed_segments() -> int:
    if current_player_hp <= 0.0:
        return 0
    var hp_per_segment: float = player_max_hp / float(player_hp_segments)
    return ceili(current_player_hp / hp_per_segment)
```

- The HP=0 guard must come before the formula (special case, as documented in GDD).
- `hp_per_segment` is derived from `@export var` fields — not a constant.
- This method is called by HUDSystem when it receives `player_hp_changed`. HUDSystem calls it directly or uses the signal value — the exact call site is up to the HUD story. Expose `get_displayed_segments()` as a public helper.
- The GDD chose `ceil()` to "high-estimate" remaining HP (players see slightly more health than precise value until the segment drops). Do not change this to `floor()` or `round()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD rendering (HUD System epic — Presentation layer)
- `boss_hp_changed` signal and Boss blood bar display

---

## QA Test Cases

**Test file**: `game/tests/unit/health_damage/test_hud_segments.gd` — 5/5 PASS (2026-06-02)

**GDD formula**: F-04 `displayed_segments = (current_player_hp ≤ 0) ? 0 : ceil(current_player_hp / hp_per_segment)`
where `hp_per_segment = player_max_hp / player_hp_segments` (100 / 5 = 20.0)

| current_player_hp | Formula | Expected |
|-------------------|---------|----------|
| 100.0 | ceil(100/20) = ceil(5.0) | **5** (full bar) |
| 61.0 | ceil(61/20) = ceil(3.05) | **4** (above integer boundary) |
| 60.0 | ceil(60/20) = ceil(3.0) | **3** (exact boundary drops segment) |
| 1.0 | ceil(1/20) = ceil(0.05) | **1** (trace HP shows 1) |
| 0.0 | special-case guard | **0** (not ceil(0) coincidence — explicit branch) |

- **Edge cases**: `hp` slightly above boundary (e.g. 60.001) → 4; `hp < 0` → 0 (treat as dead)
- **Design rationale**: `ceil()` chosen over `floor()` to avoid "feels dead" when player has HP remaining

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_hud_segments.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HP initialization — `player_max_hp` and `player_hp_segments` must be exported)
- Unlocks: HUD System stories (Presentation layer)

## Completion Notes

**Completed**: 2026-06-02
**Criteria**: 5/5 passing (all ACs auto-verified by unit tests)
**Deviations**: OUT OF SCOPE (ADVISORY) — `init_battle()` gained `assert(player_hp_segments > 0)` not in story scope; added during code review to back the doc comment's divide-by-zero protection claim. Backward-compatible.
**Test Evidence**: Logic — `game/tests/unit/health_damage/test_hud_segments.gd` (5 tests covering all ACs)
**Code Review**: Complete — `/code-review` verdict APPROVED (2 rounds: fixed inaccurate doc comment + added init_battle assert)
