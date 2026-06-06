# Story 001: HP Bars — Player Segments + Boss Fill + Phase Lines

> **Epic**: HUDSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/hud-system.md` — Elements 1 + 2, Formulas 1 + 2, AC-HUD-01 to 09
**Requirements**: `TR-HUD-001`, `TR-HUD-002`, `TR-HUD-003`, `TR-HUD-004`

**ADR Governing Implementation**:
- ADR-0001: `player_hp_changed(current, max)` and `boss_hp_changed(current, max, phase)` subscribed via EventBus
- ADR-0001: HUDSystem is pure subscriber — never emits signals, never calls apply_damage

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CanvasLayer z-index ensures HUD renders above game world regardless of camera. `Control` node HP segment: use `modulate.a` for visibility. GUT headless can test signal handler logic (segment count calculation) but not visual rendering.

**Control Manifest Rules (Presentation Layer)**:
- HUD must be hosted on a CanvasLayer
- HUD per-frame signal handlers must be O(1) with no per-frame allocation
- HUDSystem never emits signals or mutates game state

---

## Acceptance Criteria

### AC-HUD-01: player_hp_changed → correct segment count
- Given: `player_hp_changed(60, 100)` received
- When: Segment update processed
- Then: `displayed_segments = 3` (ceil(60/20)); segments 1–3 lit; segments 4–5 dark

### AC-HUD-02: HP = 1 → last segment flickers at 0.5 Hz
- Given: `player_hp_changed(1, 100)` received
- When: Update processed
- Then: `displayed_segments = 1`; segment 1 enters 0.5 Hz flicker (period = 2s)

### AC-HUD-03: HP = 20 (exact boundary) → 1 segment lit, no flicker
- Given: `player_hp_changed(20, 100)` received
- When: Update processed
- Then: `displayed_segments = 1` (ceil(20/20)=1); no flicker (not critical = exactly 1)

### AC-HUD-04: HP = 0 → all segments dark, no flicker
- Given: `player_hp_changed(0, 100)` received
- When: Update processed
- Then: `displayed_segments = 0`; all 5 segments dark; no flicker

### AC-HUD-05: HP = 21 → 2 segments lit, no flicker
- Given: `player_hp_changed(21, 100)` received
- When: Update processed
- Then: `displayed_segments = 2`; no flicker

### AC-HUD-06: boss_hp_changed → fill ratio correct
- Given: `boss_hp_changed(300, 1000, 1)` received
- When: Update processed
- Then: `boss_fill_ratio = 0.3` (300/1000)

### AC-HUD-07: boss_max = 0 → empty bar + warning, no crash
- Given: `boss_hp_changed(0, 0, 1)` received
- When: Update processed
- Then: Bar shows empty; no division by zero; `push_warning` called; UI does not crash

### AC-HUD-08: Phase separator lines rendered at correct positions
- Given: `phase_threshold_pct = [0.6, 0.3]` from BossData
- When: Battle initialized and HP bar first rendered
- Then: Two separator nodes at 60% and 30% positions; positions do not change as HP decreases

### AC-HUD-09: Phase crossing triggers 0.5s color transition
- Given: Boss HP crosses 60% threshold (phase 1→2)
- When: `boss_hp_changed` with updated phase received
- Then: Separator at 60% begins color transition animation; transition completes in 0.5s

## Test Evidence Path

`game/tests/unit/hud_system/test_hud_hp_bars.gd`

*Note: AC-HUD-02 flicker timing and AC-HUD-09 visual transition require manual visual QA — automated tests verify signal handler logic (segment count, fill ratio, separator position values).*

## Out of Scope

- Visual colors, art assets, actual rendering (Visual QA in production/qa/evidence/)
- Telegraph progress bar (Story 002)
- Counter window (Story 003)

## Definition of Done

- [ ] Signal handler logic ACs pass in GUT headless
- [ ] Visual ACs documented in `production/qa/evidence/hud-visual-[date].md` (advisory)
- [ ] `hud_system.gd` created in `game/scripts/feature/` with CanvasLayer
- [ ] HUDSystem.gd contains zero `EventBus.*emit` calls (grep check)
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
