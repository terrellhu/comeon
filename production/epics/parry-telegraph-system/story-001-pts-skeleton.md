# Story 001: ParryTelegraphSystem Skeleton

> **Epic**: ParryTelegraphSystem
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/parry-telegraph-system.md`
**Requirements**: `TR-PTS-001`, `TR-PTS-009`, `TR-PTS-012`

**ADR Governing Implementation**:
- ADR-0001: EventBus signal routing + initialize(mock) injection pattern
- ADR-0002: AttackData provides attack_type + damage; override fields resolved (GAP-02)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_physics_process(delta)` receives delta in seconds; CharacterBody2D physics run at engine tick rate. `signal.connect(callable)` is the correct Godot 4 API. `push_warning()` is stable.

**Control Manifest Rules (Feature Layer)**:
- All systems accept `initialize(event_bus)` injection for GUT testability
- All Feature-layer systems default to `PROCESS_MODE_PAUSEABLE`
- No gameplay literal values in .gd logic files — use @export or const

---

## Acceptance Criteria

### AC-01: attack_telegraphed triggers IDLE → TELEGRAPHING
- Given: System is IDLE, initialized with mock EventBus
- When: `attack_telegraphed(HEAVY, 25.0)` emitted
- Then: `system_state == TELEGRAPHING`; `current_attack_type == HEAVY`; `current_damage == 25.0`; `telegraph_timer == 0.0`

### AC-13 (partial): telegraph_updated emitted every physics frame
- Given: System is TELEGRAPHING
- When: `_physics_process(delta)` called N times
- Then: `telegraph_updated` emitted exactly N times; `progress` is in [0.0, 1.0]; `telegraph_timer` advances by delta each frame and does not exceed `telegraph_duration`

### AC-16: Second attack_telegraphed during TELEGRAPHING is discarded
- Given: System is TELEGRAPHING
- When: A second `attack_telegraphed` emitted
- Then: Current timer unchanged; `push_warning` called; `current_attack_type` unchanged

### AC-24 (skeleton path): System returns to IDLE after attack lands
- Given: System is TELEGRAPHING with no parry input
- When: `telegraph_timer` reaches `telegraph_duration`
- Then: State returns to IDLE; no lingering state

## Test Evidence Path

`game/tests/unit/parry_system/test_pts_skeleton.gd`

## Out of Scope

- Window timing formula (Story 002)
- Path A success (Story 003)
- Path B/C failure (Story 004)
- reset_for_retry, player_died/boss_defeated guards (Story 005)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `parry_telegraph_system.gd` created in `game/scripts/feature/`
- [ ] `initialize(event_bus)` injection pattern implemented
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
