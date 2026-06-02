# Story 006: HUD Segment Count Formula

> **Epic**: HealthDamageSystem
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-06-01
> **Last Updated**: —

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

*QL-STORY-READY skipped — Lean mode. Run `/qa-plan health-damage-system` to generate full test specifications.*

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
