---
name: project-sprint-foundation-core
description: Foundation + Core Layer Sprint QA outcome — 21 stories, 5 epics, verdict, and open deferred items
metadata:
  type: project
---

Sprint "Foundation + Core Layer" closed 2026-06-04 with verdict APPROVED WITH CONDITIONS.

- 21 stories across 5 epics: signal-infrastructure, bossdata-resource-architecture, retry-context, health-damage-system, player-controller
- Smoke check PASS: 307/331 passing, 24 pending (all pre-documented headless deferrals), 0 failing
- No bugs filed; no S1/S2 open

**Four conditions to clear before Pre-Production gate exit:**
1. `production/qa/evidence/bossdata-assert-debug-[date].md` — BD-002 assert() edge cases (5 paths); Debug run in Godot editor; sign-off: lead-programmer
2. `production/qa/evidence/hitpause-runtime-[date].md` — RC-002 timing verification (3 tests); native Windows build + logging scene; sign-off: lead-programmer
3. `game/tests/integration/player_controller/test_pc_jump_integration.gd` — 9 physics integration tests for PC-002/003/005/006; requires CharacterBody2D + collision shape scene
4. `get_entered_phases() -> Dictionary` accessor on HealthDamageSystem — replace signal-count proxy in HD-007 AC-3 with structural assertion

**Why:** Engine-constraint deferrals: headless GUT cannot catch assert() crashes or freeze-time timing; is_on_floor() requires a live physics scene. These are not code defects.

**How to apply:** When the next sprint begins, prioritize `test_pc_jump_integration.gd` first (closes 9 tests across 4 stories in one scene setup). Check whether any of the four conditions have been cleared before running `/gate-check`.
